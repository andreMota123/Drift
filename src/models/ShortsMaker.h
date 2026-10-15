#pragma once

#include <QJsonObject>
#include <QObject>
#include <QPointer>
#include <QString>
#include <QVariantList>

#include <functional>
#include <map>

class AppController;
class QNetworkAccessManager;
class QNetworkReply;
class QProcess;

// "Long video into shorts": the local model reads the project's captions and proposes the
// strongest self-contained stretches; each one the user keeps becomes its own vertical project
// (cut to that stretch, 9:16, footage centre-cropped, titles and captions laid out for the new
// width), written next to the project. The open project is never touched: every short is made by
// a headless Drift working on a JSON copy, through the same agent ops external tools use.
class ShortsMaker : public QObject
{
    Q_OBJECT
    Q_PROPERTY(bool busy READ busy NOTIFY stateChanged)
    Q_PROPERTY(QString stage READ stage NOTIFY stateChanged)
    Q_PROPERTY(double progress READ progress NOTIFY stateChanged)
    // [{index, start, end, title, reason, firstText}] from the last search.
    Q_PROPERTY(QVariantList proposals READ proposals NOTIFY proposalsChanged)

public:
    explicit ShortsMaker(AppController *controller, QObject *parent = nullptr);

    bool busy() const { return !m_stage.isEmpty(); }
    QString stage() const { return m_stage; }
    double progress() const { return m_progress; }
    QVariantList proposals() const { return m_proposals; }

    // Whether the timeline has captions to read; the dialog offers to generate them otherwise.
    Q_INVOKABLE bool hasTranscript() const;
    Q_INVOKABLE void findShorts(int count, int targetSeconds);
    Q_INVOKABLE void createShorts(const QVariantList &proposalIndexes);
    Q_INVOKABLE void cancel();
    Q_INVOKABLE void openOutputFolder();

signals:
    void stateChanged();
    void proposalsChanged();
    // ok, message; folder is where the shorts went (empty on failure).
    void finished(bool ok, const QString &message, const QString &folder);

private:
    struct Line {
        double start = 0;
        double end = 0;
        QString text;
    };
    struct Job {
        double start = 0;
        double end = 0;
        QString path;
    };

    QList<Line> transcript() const;
    void handleProposals(QNetworkReply *reply, int count, int targetSeconds);
    void setStage(const QString &stage, double progress);

    // Headless session driving one short.
    void startNextJob();
    void call(const QString &method, const QJsonObject &params, std::function<void(const QJsonObject &)> done);
    void tool(const QString &name, const QJsonObject &args, std::function<void(const QJsonObject &)> done);
    void readProcess();
    void layoutClips(const QList<QJsonObject> &clips, int index, std::function<void()> done);
    void finishJob(bool ok);
    void finishAll();

    AppController *m_controller = nullptr;
    QNetworkAccessManager *m_net = nullptr;
    QPointer<QNetworkReply> m_reply;
    QString m_stage;
    double m_progress = 0;
    QVariantList m_proposals;

    QList<Job> m_jobs;
    int m_jobIndex = -1;
    int m_made = 0;
    QString m_sourceJson;
    QString m_folder;
    QProcess *m_process = nullptr;
    QByteArray m_buffer;
    int m_nextId = 0;
    std::map<int, std::function<void(const QJsonObject &)>> m_pending;
    // Canvas of the source project, read before the headless copy is resized.
    double m_oldW = 0;
    double m_oldH = 0;
    int m_fps = 30;
};
