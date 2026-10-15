#include "QualityEnhancer.h"

#include "AppController.h"
#include "engine/QualityEnhance.h"

#include <QCryptographicHash>
#include <QDateTime>
#include <QDir>
#include <QFile>
#include <QNetworkAccessManager>
#include <QNetworkReply>
#include <QNetworkRequest>
#include <QStandardPaths>
#include <QtConcurrent/QtConcurrentRun>

namespace {

// Margin rendered either side of the stretch the clip uses, so a small trim later still shows
// the enhanced picture.
constexpr double kCoverMarginSeconds = 1.0;

QString dataDir(const QString &sub)
{
    const QString dir = QDir(QStandardPaths::writableLocation(QStandardPaths::AppDataLocation)).filePath(sub);
    QDir().mkpath(dir);
    return dir;
}

} // namespace

QualityEnhancer::QualityEnhancer(AppController *controller, QObject *parent)
    : QObject(parent)
    , m_controller(controller)
    , m_net(new QNetworkAccessManager(this))
{
    connect(&m_watcher, &QFutureWatcher<QString>::finished, this, [this] {
        const QString error = m_watcher.result();
        if (!error.isEmpty()) {
            QFile::remove(m_output);
            done(false, error);
            return;
        }
        const bool linked = m_controller->setClipEnhancement(m_clipId, m_output, m_inSeconds, m_outSeconds);
        done(linked, linked ? tr("Quality enhanced. The original file is unchanged; you can remove it any time.")
                            : tr("The clip is gone; the enhanced video was not used."));
    });
}

QString QualityEnhancer::modelPath()
{
    return QDir(dataDir(QStringLiteral("models"))).filePath(drift::Upscaler::modelFileName());
}

void QualityEnhancer::setState(const QString &status, double progress)
{
    m_status = status;
    m_progress = progress;
    emit stateChanged();
}

void QualityEnhancer::done(bool ok, const QString &message)
{
    m_clipId.clear();
    m_status.clear();
    m_progress = 0;
    emit stateChanged();
    emit finished(ok, message);
}

void QualityEnhancer::enhance(int trackIndex, int clipIndex)
{
    if (busy() || !m_controller)
        return;
    const auto &tracks = m_controller->project()->tracks();
    if (trackIndex < 0 || trackIndex >= tracks.size() || clipIndex < 0
        || clipIndex >= tracks.at(trackIndex).clips.size())
        return;
    const drift::Clip &clip = tracks.at(trackIndex).clips.at(clipIndex);
    if (clip.type != drift::ClipType::Video || clip.path.isEmpty()) {
        emit finished(false, tr("Select a video clip first."));
        return;
    }
    m_clipId = clip.id;
    m_source = clip.path;
    m_inSeconds = std::max(0.0, drift::usToSeconds(clip.srcIn) - kCoverMarginSeconds);
    m_outSeconds = drift::usToSeconds(clip.srcOut) + kCoverMarginSeconds;
    m_targetHeight = m_controller->project()->height();
    m_output = QDir(dataDir(QStringLiteral("enhanced")))
                   .filePath(QStringLiteral("%1-%2.mp4").arg(clip.id).arg(QDateTime::currentMSecsSinceEpoch()));
    m_cancel = false;
    if (QFile::exists(modelPath()))
        startRender();
    else
        downloadModel();
}

void QualityEnhancer::downloadModel()
{
    setState(tr("Downloading the enhancement model (4.6 MB)…"), 0);
    QNetworkRequest request{QUrl(drift::Upscaler::modelUrl())};
    request.setAttribute(QNetworkRequest::RedirectPolicyAttribute, QNetworkRequest::NoLessSafeRedirectPolicy);
    request.setTransferTimeout(120000);
    m_download = m_net->get(request);
    QNetworkReply *reply = m_download;
    connect(reply, &QNetworkReply::downloadProgress, this, [this](qint64 got, qint64 total) {
        if (total > 0)
            setState(m_status, double(got) / total);
    });
    connect(reply, &QNetworkReply::finished, this, [this, reply] {
        reply->deleteLater();
        if (reply != m_download)
            return;
        m_download = nullptr;
        if (reply->error() != QNetworkReply::NoError) {
            done(false, tr("Could not download the enhancement model: %1").arg(reply->errorString()));
            return;
        }
        const QByteArray data = reply->readAll();
        if (QCryptographicHash::hash(data, QCryptographicHash::Sha256).toHex() != drift::Upscaler::modelSha256()) {
            done(false, tr("The downloaded model did not match its checksum and was discarded."));
            return;
        }
        QFile file(modelPath());
        if (!file.open(QIODevice::WriteOnly) || file.write(data) != data.size()) {
            done(false, tr("Could not save the enhancement model."));
            return;
        }
        file.close();
        startRender();
    });
}

void QualityEnhancer::startRender()
{
    setState(tr("Enhancing… the first frames take a moment"), 0);
    const QString source = m_source;
    const QString output = m_output;
    const QString model = modelPath();
    const drift::TimeUs in = drift::secondsToUs(m_inSeconds);
    const drift::TimeUs out = drift::secondsToUs(m_outSeconds);
    const int target = m_targetHeight;
    m_watcher.setFuture(QtConcurrent::run([this, source, output, model, in, out, target]() -> QString {
        QString error;
        const bool ok = drift::renderEnhanced(source, in, out, target, model, output, &error, [this](double p) {
            QMetaObject::invokeMethod(this, [this, p] {
                if (busy())
                    setState(tr("Enhancing… %1%").arg(int(p * 100)), p);
            }, Qt::QueuedConnection);
            return !m_cancel.load();
        });
        return ok ? QString() : (error.isEmpty() ? tr("The enhancement failed.") : error);
    }));
}

void QualityEnhancer::cancel()
{
    m_cancel = true;
    if (m_download) {
        QNetworkReply *reply = m_download;
        m_download = nullptr;
        reply->abort();
        done(false, tr("Cancelled"));
    }
}

void QualityEnhancer::remove(int trackIndex, int clipIndex)
{
    const auto &tracks = m_controller->project()->tracks();
    if (trackIndex < 0 || trackIndex >= tracks.size() || clipIndex < 0
        || clipIndex >= tracks.at(trackIndex).clips.size())
        return;
    // The file stays on disk: undo brings the enhancement back.
    m_controller->setClipEnhancement(tracks.at(trackIndex).clips.at(clipIndex).id, QString(), 0, 0);
}
