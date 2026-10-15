#include "CaptionAi.h"

#include "AppController.h"
#include "AssistantController.h"

#include <QJsonArray>
#include <QJsonDocument>
#include <QJsonObject>
#include <QNetworkAccessManager>
#include <QNetworkReply>
#include <QNetworkRequest>
#include <QRegularExpression>
#include <QSettings>
#include <QUrl>

#include <algorithm>
#include <vector>

namespace {

constexpr int kBatchSize = 25;
constexpr int kContextLines = 3;
// Below this a "correction" rewrote the line rather than fixing it; the original is kept.
constexpr double kMinSimilarity = 0.55;

const QString kDefaultUrl = QStringLiteral("http://127.0.0.1:11434");
const QString kDefaultModel = QStringLiteral("qwen3:14b");
// Compared on Portuguese captions (2026-10-15): gemma4 fixed misheard words, accents, names and
// punctuation and translated more naturally than qwen3:14b, in less time.
const QString kCaptionModel = QStringLiteral("gemma4:12b-it-qat");

QString numbered(const QStringList &lines, int from, int to)
{
    QStringList out;
    for (int i = from; i < to; ++i)
        out.append(QStringLiteral("%1. %2").arg(i - from + 1).arg(lines.at(i)));
    return out.join(QLatin1Char('\n'));
}

} // namespace

CaptionAi::CaptionAi(AppController *controller, QObject *parent)
    : QObject(parent)
    , m_controller(controller)
    , m_net(new QNetworkAccessManager(this))
{
}

QString CaptionAi::model() const
{
    if (!m_useAssistantModel)
        return QSettings().value(QStringLiteral("captions/model"), kCaptionModel).toString();
    // Fallback: the assistant's model, unless that is Claude, since captions stay on this machine.
    const QString chosen = QSettings().value(QStringLiteral("assistant/model"), kDefaultModel).toString();
    return chosen == AssistantController::claudeModelName() ? kDefaultModel : chosen;
}

double CaptionAi::similarity(const QString &before, const QString &after)
{
    const QString a = before.toLower();
    const QString b = after.toLower();
    if (a == b)
        return 1.0;
    if (a.isEmpty() || b.isEmpty())
        return 0.0;
    std::vector<int> prev(b.size() + 1), cur(b.size() + 1);
    for (int j = 0; j <= b.size(); ++j)
        prev[j] = j;
    for (int i = 1; i <= a.size(); ++i) {
        cur[0] = i;
        for (int j = 1; j <= b.size(); ++j) {
            const int cost = a.at(i - 1) == b.at(j - 1) ? 0 : 1;
            cur[j] = std::min({prev[j] + 1, cur[j - 1] + 1, prev[j - 1] + cost});
        }
        std::swap(prev, cur);
    }
    return 1.0 - double(prev[b.size()]) / std::max(a.size(), b.size());
}

bool CaptionAi::start(const QString &task, int trackIndex, int clipIndex)
{
    if (busy() || !m_controller)
        return false;
    const auto &tracks = m_controller->project()->tracks();
    if (trackIndex < 0 || trackIndex >= tracks.size() || clipIndex < 0
        || clipIndex >= tracks.at(trackIndex).clips.size())
        return false;
    const drift::Clip &clip = tracks.at(trackIndex).clips.at(clipIndex);
    if (clip.type != drift::ClipType::Subtitle || clip.subtitleCues.isEmpty()) {
        emit finished(false, tr("Select a subtitle clip with captions first."));
        return false;
    }
    m_clipId = clip.id;
    m_source.clear();
    for (const drift::SubtitleCue &cue : clip.subtitleCues)
        m_source.append(cue.text);
    m_result.clear();
    m_done = 0;
    m_total = m_source.size();
    discardChanges();
    m_task = task;
    m_useAssistantModel = false;
    emit busyChanged();
    emit progressChanged();
    requestBatch();
    return true;
}

void CaptionAi::correct(int trackIndex, int clipIndex)
{
    start(QStringLiteral("correct"), trackIndex, clipIndex);
}

void CaptionAi::translate(int trackIndex, int clipIndex, const QString &language)
{
    if (language.trimmed().isEmpty())
        return;
    m_language = language.trimmed();
    start(QStringLiteral("translate"), trackIndex, clipIndex);
}

void CaptionAi::requestBatch()
{
    const int from = m_result.size();
    const int to = std::min(from + kBatchSize, int(m_source.size()));
    const int count = to - from;

    QString system;
    QString user;
    if (m_task == QLatin1String("correct")) {
        system = QStringLiteral(
            "You fix captions produced by automatic speech recognition. For each numbered line: fix "
            "spelling and accents, fix words that were obviously misheard, start each sentence with a "
            "capital letter, capitalise names of people, places, brands and courses, and add the commas "
            "and final punctuation the speech clearly has. Use the surrounding lines as context. Keep "
            "the wording and the language: do not rephrase, translate, summarise, merge or split lines. "
            "A line that is already right is returned unchanged. Return exactly one line per input line, "
            "in order.");
        const int contextFrom = std::max(0, from - kContextLines);
        if (contextFrom < from)
            user += QStringLiteral("Previous lines, already corrected (context only, do not return):\n%1\n\n")
                        .arg(numbered(m_result, contextFrom, from));
        user += QStringLiteral("Lines to fix (%1):\n%2").arg(count).arg(numbered(m_source, from, to));
    } else {
        system = QStringLiteral(
                     "You translate video captions into %1. Translate each numbered line on its own, in a "
                     "natural, concise subtitle style, keeping names as they are. Do not merge or split "
                     "lines. Return exactly one line per input line, in order.")
                     .arg(m_language);
        const int contextFrom = std::max(0, from - kContextLines);
        if (contextFrom < from)
            user += QStringLiteral("Previous lines (context only, do not return):\n%1\n\n")
                        .arg(numbered(m_source, contextFrom, from));
        user += QStringLiteral("Lines to translate (%1):\n%2").arg(count).arg(numbered(m_source, from, to));
    }

    // Structured output: the server only lets the model produce {lines:[…]} of the exact length.
    const QJsonObject schema{
        {QStringLiteral("type"), QStringLiteral("object")},
        {QStringLiteral("properties"),
         QJsonObject{{QStringLiteral("lines"),
                      QJsonObject{{QStringLiteral("type"), QStringLiteral("array")},
                                  {QStringLiteral("items"), QJsonObject{{QStringLiteral("type"), QStringLiteral("string")}}},
                                  {QStringLiteral("minItems"), count},
                                  {QStringLiteral("maxItems"), count}}}}},
        {QStringLiteral("required"), QJsonArray{QStringLiteral("lines")}}};
    const QJsonObject body{
        {QStringLiteral("model"), model()},
        {QStringLiteral("stream"), false},
        {QStringLiteral("think"), false},
        {QStringLiteral("keep_alive"), QStringLiteral("10m")},
        {QStringLiteral("format"), schema},
        {QStringLiteral("messages"),
         QJsonArray{QJsonObject{{QStringLiteral("role"), QStringLiteral("system")}, {QStringLiteral("content"), system}},
                    QJsonObject{{QStringLiteral("role"), QStringLiteral("user")}, {QStringLiteral("content"), user}}}},
        {QStringLiteral("options"), QJsonObject{{QStringLiteral("temperature"), 0}, {QStringLiteral("num_ctx"), 8192}}}};

    const QUrl base(QSettings().value(QStringLiteral("assistant/url"), kDefaultUrl).toString());
    QNetworkRequest request(base.resolved(QUrl(QStringLiteral("/api/chat"))));
    request.setHeader(QNetworkRequest::ContentTypeHeader, QStringLiteral("application/json"));
    request.setTransferTimeout(300000);
    m_reply = m_net->post(request, QJsonDocument(body).toJson(QJsonDocument::Compact));
    QNetworkReply *reply = m_reply;
    connect(reply, &QNetworkReply::finished, this, [this, reply] { handleBatch(reply); });
}

void CaptionAi::handleBatch(QNetworkReply *reply)
{
    reply->deleteLater();
    if (reply != m_reply || !busy())
        return;
    m_reply = nullptr;
    if (reply->error() == QNetworkReply::ContentNotFoundError && !m_useAssistantModel) {
        // The caption model is not installed: carry on with the assistant's.
        m_useAssistantModel = true;
        requestBatch();
        return;
    }
    if (reply->error() != QNetworkReply::NoError) {
        fail(reply->error() == QNetworkReply::ConnectionRefusedError
                 ? tr("Ollama is not answering. Open Ollama and try again.")
                 : tr("The local AI failed: %1").arg(reply->errorString()));
        return;
    }

    const int from = m_result.size();
    const int count = std::min(kBatchSize, int(m_source.size()) - from);
    const QString content = QJsonDocument::fromJson(reply->readAll())
                                .object()
                                .value(QStringLiteral("message"))
                                .toObject()
                                .value(QStringLiteral("content"))
                                .toString();
    const QJsonArray lines = QJsonDocument::fromJson(content.toUtf8()).object().value(QStringLiteral("lines")).toArray();
    const bool usable = lines.size() == count;
    for (int i = 0; i < count; ++i) {
        const QString original = m_source.at(from + i);
        QString line = usable ? lines.at(i).toString().trimmed() : QString();
        // A numbered echo ("3. text") is the model copying the input format.
        static const QRegularExpression echo(QStringLiteral("^\\d+\\.\\s+"));
        line.remove(echo);
        if (line.isEmpty())
            line = original;
        if (m_task == QLatin1String("correct") && similarity(original, line) < kMinSimilarity)
            line = original;
        m_result.append(line);
    }
    m_done = m_result.size();
    emit progressChanged();

    if (m_result.size() < m_source.size())
        requestBatch();
    else
        complete();
}

void CaptionAi::complete()
{
    const QString task = m_task;
    m_task.clear();
    emit busyChanged();

    const QPair<int, int> loc = m_controller->mcpLocateClip(m_clipId);
    if (loc.first < 0) {
        emit finished(false, tr("The subtitle clip is gone; nothing was changed."));
        return;
    }

    if (task == QLatin1String("correct")) {
        for (int i = 0; i < m_source.size(); ++i) {
            if (m_result.at(i) != m_source.at(i))
                m_pending.append(QVariantMap{{QStringLiteral("index"), i},
                                             {QStringLiteral("before"), m_source.at(i)},
                                             {QStringLiteral("after"), m_result.at(i)}});
        }
        emit pendingChanged();
        if (m_pending.isEmpty())
            emit finished(true, tr("No corrections needed."));
        return;
    }

    const drift::Clip &clip = m_controller->project()->tracks().at(loc.first).clips.at(loc.second);
    if (clip.subtitleCues.size() != m_result.size()) {
        emit finished(false, tr("The captions changed while translating; nothing was added."));
        return;
    }
    QVariantList cues;
    for (int i = 0; i < clip.subtitleCues.size(); ++i) {
        const drift::SubtitleCue &cue = clip.subtitleCues.at(i);
        cues.append(QVariantMap{{QStringLiteral("start"), drift::usToSeconds(cue.startUs)},
                                {QStringLiteral("end"), drift::usToSeconds(cue.endUs)},
                                {QStringLiteral("text"), m_result.at(i)}});
    }
    const QString id = m_controller->addSubtitleTranslation(loc.first, loc.second, cues);
    emit finished(!id.isEmpty(), id.isEmpty() ? tr("Could not add the translated captions.")
                                              : tr("Translation added on a new subtitle lane, above the original."));
}

void CaptionAi::applyChanges(const QVariantList &acceptedIndexes)
{
    const QPair<int, int> loc = m_controller->mcpLocateClip(m_clipId);
    if (loc.first < 0 || m_pending.isEmpty()) {
        discardChanges();
        return;
    }
    const drift::Clip &clip = m_controller->project()->tracks().at(loc.first).clips.at(loc.second);
    if (clip.subtitleCues.size() != m_source.size()) {
        discardChanges();
        emit finished(false, tr("The captions changed meanwhile; nothing was applied."));
        return;
    }
    QVariantList cues;
    for (const drift::SubtitleCue &cue : clip.subtitleCues)
        cues.append(QVariantMap{{QStringLiteral("start"), drift::usToSeconds(cue.startUs)},
                                {QStringLiteral("end"), drift::usToSeconds(cue.endUs)},
                                {QStringLiteral("text"), cue.text}});
    int applied = 0;
    for (const QVariant &value : acceptedIndexes) {
        const int index = value.toInt();
        if (index < 0 || index >= cues.size())
            continue;
        QVariantMap cue = cues.at(index).toMap();
        cue.insert(QStringLiteral("text"), m_result.at(index));
        cues[index] = cue;
        ++applied;
    }
    discardChanges();
    if (applied > 0) {
        m_controller->setSubtitleCues(loc.first, loc.second, cues);
        emit finished(true, tr("%n caption(s) corrected. Ctrl+Z undoes it.", "", applied));
    }
}

void CaptionAi::discardChanges()
{
    if (m_pending.isEmpty())
        return;
    m_pending.clear();
    emit pendingChanged();
}

void CaptionAi::cancel()
{
    if (!busy())
        return;
    if (m_reply) {
        QNetworkReply *reply = m_reply;
        m_reply = nullptr;
        reply->abort();
    }
    m_task.clear();
    emit busyChanged();
}

void CaptionAi::fail(const QString &message)
{
    m_task.clear();
    emit busyChanged();
    emit finished(false, message);
}
