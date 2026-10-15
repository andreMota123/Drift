#pragma once

#include <QFutureWatcher>
#include <QObject>
#include <QPointer>
#include <QString>

#include <atomic>

class AppController;
class QNetworkAccessManager;
class QNetworkReply;

// "Enhance quality" for a video clip: renders the stretch of its source the clip uses through
// the Real-ESRGAN model (see engine/QualityEnhance.h) up to the project's height, then points the
// clip's picture at that render. The original file is untouched and the sound keeps coming from
// it; removing the enhancement points the picture back. The model (4.6 MB) is downloaded on first
// use from a pinned address and checked by hash.
class QualityEnhancer : public QObject
{
    Q_OBJECT
    Q_PROPERTY(bool busy READ busy NOTIFY stateChanged)
    Q_PROPERTY(double progress READ progress NOTIFY stateChanged)
    Q_PROPERTY(QString clipId READ clipId NOTIFY stateChanged)
    Q_PROPERTY(QString status READ status NOTIFY stateChanged)

public:
    explicit QualityEnhancer(AppController *controller, QObject *parent = nullptr);

    bool busy() const { return !m_clipId.isEmpty(); }
    double progress() const { return m_progress; }
    QString clipId() const { return m_clipId; }
    QString status() const { return m_status; }

    Q_INVOKABLE void enhance(int trackIndex, int clipIndex);
    Q_INVOKABLE void remove(int trackIndex, int clipIndex);
    Q_INVOKABLE void cancel();

    static QString modelPath();

signals:
    void stateChanged();
    void finished(bool ok, const QString &message);

private:
    void downloadModel();
    void startRender();
    void setState(const QString &status, double progress);
    void done(bool ok, const QString &message);

    AppController *m_controller = nullptr;
    QNetworkAccessManager *m_net = nullptr;
    QPointer<QNetworkReply> m_download;
    QFutureWatcher<QString> m_watcher; // empty string = success, else the error
    std::atomic_bool m_cancel{false};

    QString m_clipId;
    QString m_source;
    QString m_output;
    double m_inSeconds = 0;
    double m_outSeconds = 0;
    int m_targetHeight = 0;
    double m_progress = 0;
    QString m_status;
};
