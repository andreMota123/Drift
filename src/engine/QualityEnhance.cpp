#include "QualityEnhance.h"

#include "MediaProbe.h"
#include "OrtRuntime.h"
#include "OrtSupport.h"

#include <QCoreApplication>
#include <QFile>

#include <algorithm>
#include <array>
#include <cmath>
#include <vector>

extern "C" {
#include <libavcodec/avcodec.h>
#include <libavformat/avformat.h>
#include <libavutil/display.h>
#include <libavutil/opt.h>
#include <libswscale/swscale.h>
}

namespace drift {

namespace {

// Input pixels per tile side, plus the overlap each tile reads around it. 512 keeps one tile's
// activations around 70 MB on the GPU; the overlap hides the seam where two tiles meet.
constexpr int kTile = 512;
constexpr int kTilePad = 16;
// Keyframe often enough that scrubbing the enhanced file stays cheap.
constexpr int kGopSize = 12;

QString tr(const char *text)
{
    return QCoreApplication::translate("QualityEnhance", text);
}

int even(double v)
{
    return std::max(2, int(std::lround(v / 2.0)) * 2);
}

// Writes RGB images as H.264 at a fixed size. Same .part-then-rename discipline as the reverse
// proxy writer, so a cancelled or failed render leaves nothing behind.
class EnhancedWriter
{
public:
    ~EnhancedWriter() { abort(); }

    bool open(const QString &path, int width, int height, AVRational timeBase, AVRational frameRate,
              int rotationDegrees, const AVCodecContext *dec, QString *errorOut)
    {
        const auto fail = [&](const QString &message) {
            if (errorOut)
                *errorOut = message;
            teardown();
            return false;
        };
        m_path = path;
        m_tmpPath = path + QStringLiteral(".part");
        QFile::remove(m_tmpPath);
        const QByteArray tmp = m_tmpPath.toUtf8();
        avformat_alloc_output_context2(&m_fmt, nullptr, "mp4", tmp.constData());
        const AVCodec *codec = avcodec_find_encoder(AV_CODEC_ID_H264);
        if (!m_fmt || !codec)
            return fail(tr("H.264 encoder not available"));
        m_stream = avformat_new_stream(m_fmt, nullptr);
        m_ctx = avcodec_alloc_context3(codec);
        if (!m_stream || !m_ctx)
            return fail(tr("Could not set up the enhanced file"));
        m_ctx->width = width;
        m_ctx->height = height;
        m_ctx->pix_fmt = AV_PIX_FMT_YUV420P;
        m_ctx->time_base = timeBase;
        m_ctx->framerate = frameRate;
        m_ctx->gop_size = kGopSize;
        m_ctx->max_b_frames = 0;
        m_ctx->color_range = AVCOL_RANGE_MPEG;
        m_ctx->colorspace = dec->colorspace;
        m_ctx->color_primaries = dec->color_primaries;
        m_ctx->color_trc = dec->color_trc;
        if (m_fmt->oformat->flags & AVFMT_GLOBALHEADER)
            m_ctx->flags |= AV_CODEC_FLAG_GLOBAL_HEADER;
        av_opt_set(m_ctx->priv_data, "crf", "16", 0);
        av_opt_set(m_ctx->priv_data, "preset", "fast", 0);
        if (avcodec_open2(m_ctx, codec, nullptr) < 0)
            return fail(tr("Could not open the H.264 encoder"));
        avcodec_parameters_from_context(m_stream->codecpar, m_ctx);
        if (rotationDegrees != 0) {
            AVPacketSideData *sd = av_packet_side_data_new(&m_stream->codecpar->coded_side_data,
                                                           &m_stream->codecpar->nb_coded_side_data,
                                                           AV_PKT_DATA_DISPLAYMATRIX, sizeof(int32_t) * 9, 0);
            if (sd)
                av_display_rotation_set(reinterpret_cast<int32_t *>(sd->data), rotationDegrees);
        }
        m_stream->time_base = timeBase;
        m_stream->avg_frame_rate = frameRate;
        m_stream->r_frame_rate = frameRate;
        if (!(m_fmt->oformat->flags & AVFMT_NOFILE) && avio_open(&m_fmt->pb, tmp.constData(), AVIO_FLAG_WRITE) < 0)
            return fail(tr("Could not write the enhanced file"));
        if (avformat_write_header(m_fmt, nullptr) < 0)
            return fail(tr("Could not write the enhanced file"));
        m_pkt = av_packet_alloc();
        m_frame = av_frame_alloc();
        if (!m_pkt || !m_frame)
            return fail(tr("Out of memory"));
        m_frame->format = AV_PIX_FMT_YUV420P;
        m_frame->width = width;
        m_frame->height = height;
        if (av_frame_get_buffer(m_frame, 0) < 0)
            return fail(tr("Out of memory"));
        return true;
    }

    bool write(const QImage &rgb, int64_t pts, QString *errorOut)
    {
        m_sws = sws_getCachedContext(m_sws, rgb.width(), rgb.height(), AV_PIX_FMT_RGB24, m_ctx->width,
                                     m_ctx->height, AV_PIX_FMT_YUV420P, SWS_BICUBIC, nullptr, nullptr, nullptr);
        if (!m_sws || av_frame_make_writable(m_frame) < 0) {
            if (errorOut)
                *errorOut = tr("Could not convert an enhanced frame");
            return false;
        }
        const uint8_t *src[1] = {rgb.constBits()};
        const int stride[1] = {int(rgb.bytesPerLine())};
        sws_scale(m_sws, src, stride, 0, rgb.height(), m_frame->data, m_frame->linesize);
        if (pts <= m_lastPts)
            pts = m_lastPts + 1;
        m_lastPts = pts;
        m_frame->pts = pts;
        if (avcodec_send_frame(m_ctx, m_frame) < 0) {
            if (errorOut)
                *errorOut = tr("The encoder rejected a frame");
            return false;
        }
        return drain(errorOut);
    }

    bool finish(QString *errorOut)
    {
        if (avcodec_send_frame(m_ctx, nullptr) < 0 || !drain(errorOut) || av_write_trailer(m_fmt) < 0) {
            if (errorOut && errorOut->isEmpty())
                *errorOut = tr("Could not finish the enhanced file");
            return false;
        }
        teardown();
        QFile::remove(m_path);
        if (!QFile::rename(m_tmpPath, m_path)) {
            if (errorOut)
                *errorOut = tr("Could not move the enhanced file into place");
            return false;
        }
        m_done = true;
        return true;
    }

    void abort()
    {
        if (m_done)
            return;
        teardown();
        if (!m_tmpPath.isEmpty())
            QFile::remove(m_tmpPath);
    }

private:
    bool drain(QString *errorOut)
    {
        for (;;) {
            const int rc = avcodec_receive_packet(m_ctx, m_pkt);
            if (rc == AVERROR(EAGAIN) || rc == AVERROR_EOF)
                return true;
            if (rc < 0) {
                if (errorOut)
                    *errorOut = tr("The encoder failed");
                return false;
            }
            av_packet_rescale_ts(m_pkt, m_ctx->time_base, m_stream->time_base);
            m_pkt->stream_index = m_stream->index;
            const int wrc = av_interleaved_write_frame(m_fmt, m_pkt);
            av_packet_unref(m_pkt);
            if (wrc < 0) {
                if (errorOut)
                    *errorOut = tr("Could not write the enhanced file");
                return false;
            }
        }
    }

    void teardown()
    {
        if (m_sws) {
            sws_freeContext(m_sws);
            m_sws = nullptr;
        }
        if (m_frame)
            av_frame_free(&m_frame);
        if (m_pkt)
            av_packet_free(&m_pkt);
        if (m_ctx)
            avcodec_free_context(&m_ctx);
        if (m_fmt) {
            if (m_fmt->pb && !(m_fmt->oformat->flags & AVFMT_NOFILE))
                avio_closep(&m_fmt->pb);
            avformat_free_context(m_fmt);
            m_fmt = nullptr;
        }
        m_stream = nullptr;
    }

    AVFormatContext *m_fmt = nullptr;
    AVCodecContext *m_ctx = nullptr;
    AVStream *m_stream = nullptr;
    AVFrame *m_frame = nullptr;
    AVPacket *m_pkt = nullptr;
    SwsContext *m_sws = nullptr;
    QString m_path;
    QString m_tmpPath;
    int64_t m_lastPts = INT64_MIN;
    bool m_done = false;
};

struct Source
{
    AVFormatContext *fmt = nullptr;
    AVCodecContext *dec = nullptr;
    SwsContext *sws = nullptr;
    int stream = -1;

    ~Source()
    {
        if (sws)
            sws_freeContext(sws);
        if (dec)
            avcodec_free_context(&dec);
        if (fmt)
            avformat_close_input(&fmt);
    }
};

} // namespace

// --- Upscaler --------------------------------------------------------------------------------

QString Upscaler::modelFileName()
{
    return QStringLiteral("realesr-general-x4v3.onnx");
}

QString Upscaler::modelUrl()
{
    return QStringLiteral("https://huggingface.co/CoderViking/realesr-general-x4v3-onnx/resolve/"
                          "c6a971706797c7502945a2b4c4274fce4900d4ab/realesr-general-x4v3.onnx");
}

QByteArray Upscaler::modelSha256()
{
    return QByteArrayLiteral("1940a93ee08283a0a7286183186357b1688fe9fa8ede74604b424586aaddf112");
}

Upscaler::Upscaler() = default;
Upscaler::~Upscaler() = default;

bool Upscaler::load(const QString &modelPath, QString *errorOut)
{
    if (!ort::ensureLoaded(errorOut))
        return false;
    // A convolution net over whole frames: on auto, prefer the NVIDIA provider when the runtime has
    // it, even over a registered plugin EP — WebGPU ran this model about a frame a second here.
    const std::vector<std::string> providers = Ort::GetAvailableProviders();
    if (!ort::variantExplicit()
        && std::find(providers.begin(), providers.end(), "CUDAExecutionProvider") != providers.end()) {
        try {
            Ort::SessionOptions opts;
            opts.SetIntraOpNumThreads(std::max(1, QThread::idealThreadCount()));
            OrtCUDAProviderOptions cuda;
            cuda.arena_extend_strategy = 1;
            opts.AppendExecutionProvider_CUDA(cuda);
            m_session = std::make_unique<Ort::Session>(ort::env(), ort::ortPath(modelPath).c_str(), opts);
            return true;
        } catch (const Ort::Exception &e) {
            qInfo("[upscale] CUDA could not be used (%s); trying the default provider.", e.what());
        }
    }
    QString error;
    const bool ok = ort::buildSessions(ort::env(), "upscale", false, &error, [&](Ort::SessionOptions &opts) {
        m_session = std::make_unique<Ort::Session>(ort::env(), ort::ortPath(modelPath).c_str(), opts);
    });
    if (!ok && errorOut)
        *errorOut = tr("Could not load the enhancement model: %1").arg(error);
    return ok;
}

QImage Upscaler::upscale(const QImage &image)
{
    const QImage src = image.convertToFormat(QImage::Format_RGB888);
    const int w = src.width();
    const int h = src.height();
    QImage out(w * kScale, h * kScale, QImage::Format_RGB888);
    if (!m_session || w <= 0 || h <= 0)
        return {};
    const char *inputNames[] = {"input"};
    const char *outputNames[] = {"output"};
    std::vector<float> input;

    for (int ty = 0; ty < h; ty += kTile) {
        for (int tx = 0; tx < w; tx += kTile) {
            const int x0 = std::max(0, tx - kTilePad);
            const int y0 = std::max(0, ty - kTilePad);
            const int x1 = std::min(w, tx + kTile + kTilePad);
            const int y1 = std::min(h, ty + kTile + kTilePad);
            const int tw = x1 - x0;
            const int th = y1 - y0;
            input.assign(size_t(3) * tw * th, 0.0f);
            const size_t plane = size_t(tw) * th;
            for (int y = 0; y < th; ++y) {
                const uchar *row = src.constScanLine(y0 + y) + x0 * 3;
                for (int x = 0; x < tw; ++x) {
                    const size_t i = size_t(y) * tw + x;
                    input[i] = row[x * 3] / 255.0f;
                    input[plane + i] = row[x * 3 + 1] / 255.0f;
                    input[2 * plane + i] = row[x * 3 + 2] / 255.0f;
                }
            }
            const std::array<int64_t, 4> shape{1, 3, th, tw};
            Ort::Value tensor = Ort::Value::CreateTensor<float>(ort::cpuMemory(), input.data(), input.size(),
                                                                shape.data(), shape.size());
            std::vector<Ort::Value> result =
                m_session->Run(Ort::RunOptions{nullptr}, inputNames, &tensor, 1, outputNames, 1);
            const float *o = result.front().GetTensorData<float>();
            const int ow = tw * kScale;
            const size_t oplane = size_t(ow) * th * kScale;
            // Copy the tile's own area, dropping the overlap.
            const int innerW = std::min(kTile, w - tx) * kScale;
            const int innerH = std::min(kTile, h - ty) * kScale;
            const int offX = (tx - x0) * kScale;
            const int offY = (ty - y0) * kScale;
            for (int y = 0; y < innerH; ++y) {
                uchar *dst = out.scanLine(ty * kScale + y) + tx * kScale * 3;
                const size_t rowStart = size_t(offY + y) * ow + offX;
                for (int x = 0; x < innerW; ++x) {
                    const size_t i = rowStart + x;
                    dst[x * 3] = uchar(std::clamp(o[i] * 255.0f + 0.5f, 0.0f, 255.0f));
                    dst[x * 3 + 1] = uchar(std::clamp(o[oplane + i] * 255.0f + 0.5f, 0.0f, 255.0f));
                    dst[x * 3 + 2] = uchar(std::clamp(o[2 * oplane + i] * 255.0f + 0.5f, 0.0f, 255.0f));
                }
            }
        }
    }
    return out;
}

// --- Rendering a clip ------------------------------------------------------------------------

bool renderEnhanced(const QString &sourcePath, TimeUs coverInUs, TimeUs coverOutUs, int targetHeight,
                    const QString &modelPath, const QString &outPath, QString *errorOut,
                    const std::function<bool(double)> &onProgress)
{
    const auto fail = [&](const QString &message) {
        if (errorOut)
            *errorOut = message;
        return false;
    };
    if (coverOutUs <= coverInUs)
        return fail(tr("Nothing to enhance"));

    Source source;
    const QByteArray pathUtf8 = sourcePath.toUtf8();
    if (avformat_open_input(&source.fmt, pathUtf8.constData(), nullptr, nullptr) < 0
        || avformat_find_stream_info(source.fmt, nullptr) < 0)
        return fail(tr("Could not open the clip"));
    source.stream = av_find_best_stream(source.fmt, AVMEDIA_TYPE_VIDEO, -1, -1, nullptr, 0);
    if (source.stream < 0)
        return fail(tr("The clip has no video"));
    AVStream *stream = source.fmt->streams[source.stream];
    const AVCodec *codec = avcodec_find_decoder(stream->codecpar->codec_id);
    if (!codec)
        return fail(tr("No decoder for this clip"));
    source.dec = avcodec_alloc_context3(codec);
    if (!source.dec || avcodec_parameters_to_context(source.dec, stream->codecpar) < 0)
        return fail(tr("Could not configure the decoder"));
    source.dec->thread_count = 0;
    if (avcodec_open2(source.dec, codec, nullptr) < 0 || source.dec->width <= 0 || source.dec->height <= 0)
        return fail(tr("Could not open the decoder"));

    // Sizes in the decoded (unrotated) orientation; the rotation flag is copied across.
    const int rotation = displayRotationOf(stream);
    const bool sideways = std::abs(rotation) % 180 == 90;
    const int srcW = source.dec->width;
    const int srcH = source.dec->height;
    const int displayedH = sideways ? srcW : srcH;
    if (displayedH >= targetHeight)
        return fail(tr("This clip is already at least as sharp as the project (%1 px tall).").arg(displayedH));
    const double factor = std::min(double(Upscaler::kScale), double(targetHeight) / displayedH);
    const int outW = even(srcW * factor);
    const int outH = even(srcH * factor);

    Upscaler upscaler;
    if (!upscaler.load(modelPath, errorOut))
        return false;

    AVRational frameRate = stream->avg_frame_rate;
    if (frameRate.num <= 0 || frameRate.den <= 0)
        frameRate = stream->r_frame_rate;
    if (frameRate.num <= 0 || frameRate.den <= 0)
        frameRate = AVRational{30, 1};
    const AVRational timeBase = stream->time_base;
    const int64_t coverInTs = av_rescale_q(coverInUs, {1, AV_TIME_BASE}, timeBase);
    const int64_t coverOutTs = av_rescale_q(coverOutUs, {1, AV_TIME_BASE}, timeBase);

    EnhancedWriter writer;
    if (!writer.open(outPath, outW, outH, timeBase, frameRate, rotation, source.dec, errorOut))
        return false;

    AVFrame *frame = av_frame_alloc();
    AVPacket *packet = av_packet_alloc();
    const auto cleanup = [&] {
        av_frame_free(&frame);
        av_packet_free(&packet);
    };
    if (!frame || !packet) {
        cleanup();
        writer.abort();
        return fail(tr("Out of memory"));
    }
    av_seek_frame(source.fmt, source.stream, coverInTs, AVSEEK_FLAG_BACKWARD);
    avcodec_flush_buffers(source.dec);

    QImage rgb(srcW, srcH, QImage::Format_RGB888);
    bool finished = false;
    bool failed = false;
    QString error;
    const auto handle = [&](AVFrame *f) {
        const int64_t pts = f->best_effort_timestamp != AV_NOPTS_VALUE ? f->best_effort_timestamp : f->pts;
        if (pts == AV_NOPTS_VALUE || pts < coverInTs)
            return;
        if (pts > coverOutTs) {
            finished = true;
            return;
        }
        source.sws = sws_getCachedContext(source.sws, f->width, f->height, AVPixelFormat(f->format), srcW, srcH,
                                          AV_PIX_FMT_RGB24, SWS_BICUBIC, nullptr, nullptr, nullptr);
        uint8_t *dst[1] = {rgb.bits()};
        const int stride[1] = {int(rgb.bytesPerLine())};
        sws_scale(source.sws, f->data, f->linesize, 0, f->height, dst, stride);
        QImage big;
        try {
            big = upscaler.upscale(rgb);
        } catch (const Ort::Exception &e) {
            error = tr("The enhancement model failed: %1").arg(QString::fromUtf8(e.what()));
            failed = true;
            return;
        }
        // The model always gives 4x; the writer brings it to the size asked for.
        if (!writer.write(big, pts - coverInTs, &error)) {
            failed = true;
            return;
        }
        if (onProgress && !onProgress(double(pts - coverInTs) / std::max<int64_t>(1, coverOutTs - coverInTs))) {
            error = tr("Cancelled");
            failed = true;
        }
    };

    while (!finished && !failed) {
        const int rc = av_read_frame(source.fmt, packet);
        if (rc < 0) {
            avcodec_send_packet(source.dec, nullptr);
        } else if (packet->stream_index != source.stream) {
            av_packet_unref(packet);
            continue;
        } else {
            avcodec_send_packet(source.dec, packet);
            av_packet_unref(packet);
        }
        while (!finished && !failed) {
            const int frc = avcodec_receive_frame(source.dec, frame);
            if (frc == AVERROR(EAGAIN))
                break;
            if (frc < 0) {
                finished = true;
                break;
            }
            handle(frame);
            av_frame_unref(frame);
        }
        if (rc < 0)
            finished = true;
    }
    cleanup();
    if (failed) {
        writer.abort();
        return fail(error);
    }
    if (!writer.finish(errorOut))
        return false;
    if (onProgress)
        onProgress(1.0);
    return true;
}

} // namespace drift
