#pragma once

#include <QObject>
#include <QPointer>
#include <QString>
#include <QStringList>
#include <QVariantList>

class AppController;
class QNetworkAccessManager;
class QNetworkReply;

// Caption tools backed by the local Ollama model the assistant uses: correcting what Whisper
// misheard (reviewed before anything changes) and translating a subtitle clip into a second,
// bilingual lane. Times are never touched: the model only ever sees and returns line texts,
// one per cue, and a batch whose count does not match is dropped rather than guessed at.
class CaptionAi : public QObject
{
    Q_OBJECT
    Q_PROPERTY(bool busy READ busy NOTIFY busyChanged)
    Q_PROPERTY(double progress READ progress NOTIFY progressChanged)
    Q_PROPERTY(QString task READ task NOTIFY busyChanged)
    // [{index, before, after}] waiting for review after a correction run.
    Q_PROPERTY(QVariantList pendingChanges READ pendingChanges NOTIFY pendingChanged)

public:
    explicit CaptionAi(AppController *controller, QObject *parent = nullptr);

    bool busy() const { return !m_task.isEmpty(); }
    double progress() const { return m_total > 0 ? double(m_done) / m_total : 0.0; }
    QString task() const { return m_task; }
    QVariantList pendingChanges() const { return m_pending; }

    Q_INVOKABLE void correct(int trackIndex, int clipIndex);
    Q_INVOKABLE void translate(int trackIndex, int clipIndex, const QString &language);
    Q_INVOKABLE void cancel();
    // Applies the reviewed corrections whose cue indexes are listed, in one undo step.
    Q_INVOKABLE void applyChanges(const QVariantList &acceptedIndexes);
    Q_INVOKABLE void discardChanges();

    // 0..1: how much of `before` survives in `after` (1 - edit distance / longer length).
    static double similarity(const QString &before, const QString &after);

signals:
    void busyChanged();
    void progressChanged();
    void pendingChanged();
    void finished(bool ok, const QString &message);

private:
    bool start(const QString &task, int trackIndex, int clipIndex);
    void requestBatch();
    void handleBatch(QNetworkReply *reply);
    void complete();
    void fail(const QString &message);
    QString model() const;

    AppController *m_controller = nullptr;
    QNetworkAccessManager *m_net = nullptr;
    QPointer<QNetworkReply> m_reply;

    QString m_task;      // "correct" | "translate" while running
    QString m_language;  // translation target
    QString m_clipId;
    QStringList m_source;
    QStringList m_result;
    int m_done = 0;
    int m_total = 0;
    QVariantList m_pending;
    bool m_useAssistantModel = false;
};
