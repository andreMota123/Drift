#pragma once

#include "core/Time.h"

#include <QImage>
#include <QString>

#include <functional>
#include <memory>

namespace Ort {
struct Session;
}

namespace drift {

// "Enhance quality": Real-ESRGAN general x4v3 (BSD-3-Clause, SRVGGNetCompact, ~4.6 MB ONNX),
// which restores and upscales 4x. Runs on whatever ONNX Runtime provider the app is set to (the
// NVIDIA addon makes it fast), falling back to CPU.
class Upscaler
{
public:
    static constexpr int kScale = 4;
    // Pinned download: the ONNX export of the official weights, checked by hash before use.
    static QString modelFileName();
    static QString modelUrl();
    static QByteArray modelSha256();

    Upscaler();
    ~Upscaler();

    bool load(const QString &modelPath, QString *errorOut);
    // `image` at four times its size. Runs in overlapping tiles so a large frame fits in memory;
    // the overlap is cropped away so tile seams do not show.
    QImage upscale(const QImage &image);

private:
    std::unique_ptr<Ort::Session> m_session;
};

// Writes [coverInUs, coverOutUs] of sourcePath's video, enhanced and scaled so it displays
// `targetHeight` pixels tall, to outPath (H.264, no audio). The first frame is at time 0, i.e.
// coverInUs of the source. The source's rotation flag is carried over, like the reverse proxy.
// Fails, writing nothing, when the source already displays at least targetHeight tall.
// onProgress gets 0..1 and returns false to cancel; on cancel or failure no file is left.
bool renderEnhanced(const QString &sourcePath, TimeUs coverInUs, TimeUs coverOutUs, int targetHeight,
                    const QString &modelPath, const QString &outPath, QString *errorOut,
                    const std::function<bool(double)> &onProgress);

} // namespace drift
