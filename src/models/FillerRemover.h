#pragma once

#include <QObject>
#include <QPointer>
#include <QString>
#include <QVariantList>

class AppController;
class QNetworkAccessManager;
class QNetworkReply;

// "Remove filler words": the captions are joined and split into sentences. Retakes (a sentence
// said again a little later almost the same way: the earlier attempts go, the last stays) and
// false starts (a sentence that is the opening of one right after it) are found by comparing the
// sentences' words. The local model then marks verbal crutches ("é…", "tipo", "né") inside
// sentences and asides to the crew. Each mark becomes a stretch of time, words timed by their
// share of their caption and both ends moved to the quietest point nearby, that the user reviews
// before anything is cut. The cut runs on every track, so picture, sound and captions stay in
// sync, and the caption text loses the words too.
class FillerRemover : public QObject
{
    Q_OBJECT
    Q_PROPERTY(bool busy READ busy NOTIFY stateChanged)
    Q_PROPERTY(double progress READ progress NOTIFY stateChanged)
    // [{index, start, end, kind, line, offset, length, checked}]
    Q_PROPERTY(QVariantList proposals READ proposals NOTIFY proposalsChanged)

public:
    explicit FillerRemover(AppController *controller, QObject *parent = nullptr);

    bool busy() const { return m_busy; }
    double progress() const { return m_total > 0 ? double(m_done) / m_total : 0.0; }
    QVariantList proposals() const { return m_proposals; }

    Q_INVOKABLE bool hasTranscript() const;
    Q_INVOKABLE void find();
    Q_INVOKABLE void cancel();
    // Cuts the listed proposals, in one undo step. Returns how many stretches were cut.
    Q_INVOKABLE int apply(const QVariantList &proposalIndexes);

    // `line` without `removed` (first match, any case), with the commas and spaces around the gap
    // tidied. Public for the tests.
    static QString removeSpan(const QString &line, int offset, int length);
    // Where `text` sits in `line`, ignoring case and the punctuation and spaces at its ends;
    // {-1, 0} when it is not there.
    static QPair<int, int> locate(const QString &line, const QString &text);
    // For each sentence, "retake" or "false_start" when a later sentence nearby repeats or
    // completes it; empty otherwise.
    static QStringList retakes(const QStringList &sentences);

signals:
    void stateChanged();
    void proposalsChanged();
    void finished(bool ok, const QString &message);

private:
    struct Line {
        QString clipId;
        int cue = -1;
        double start = 0;
        double end = 0;
        QString text;
    };
    // One character of the joined, normalised transcript: which caption it came from and where
    // in that caption's own text (-1 cue for the separators between captions).
    struct CharRef {
        int line = -1;
        int offset = 0;
    };
    struct Sentence {
        int from = 0; // in m_joined
        int to = 0;
        QString text;
    };

    QList<Line> transcript() const;
    void buildSentences();
    double timeAt(int joinedIndex, bool end) const;
    void requestBatch();
    void handleBatch(QNetworkReply *reply);
    void complete();
    QString model() const;

    AppController *m_controller = nullptr;
    QNetworkAccessManager *m_net = nullptr;
    QPointer<QNetworkReply> m_reply;
    bool m_busy = false;
    bool m_useAssistantModel = false;
    QList<Line> m_lines;
    QString m_joined;
    QList<CharRef> m_refs;
    QList<Sentence> m_sentences;
    int m_done = 0;
    int m_total = 0;
    // A mark on a sentence: offset and length inside its text, kind.
    struct Mark {
        int sentence = -1;
        int offset = 0;
        int length = 0;
        QString kind;
    };
    QList<Mark> m_marks;
    QVariantList m_proposals;
};
