#include "FillerRemover.h"

#include "AppController.h"
#include "AssistantController.h"

#include <QJsonArray>
#include <QJsonDocument>
#include <QJsonObject>
#include <QNetworkAccessManager>
#include <QNetworkReply>
#include <QNetworkRequest>
#include <QRegularExpression>
#include <QSet>
#include <QSettings>
#include <QUrl>

#include <algorithm>
#include <map>
#include <vector>

namespace {

constexpr int kBatchSize = 50;
// Retakes are looked for among the next few sentences: a take is redone right away.
constexpr int kRetakeLookahead = 8;
constexpr double kRetakeSimilarity = 0.7;
// A mark shorter than this is not worth a cut; one longer is more than a filler.
constexpr double kMinCutSeconds = 0.08;
constexpr double kMaxCutSeconds = 30.0;
constexpr double kSnapWindow = 0.2;
// Whole sentences usually end in a pause, which may sit a little further from the estimate.
constexpr double kSentenceSnapWindow = 0.5;

const QString kDefaultUrl = QStringLiteral("http://127.0.0.1:11434");
const QString kDefaultModel = QStringLiteral("qwen3:14b");
// Same model as the captions: on Portuguese speech it also caught repeated words that qwen3:14b
// let through (2026-10-15).
const QString kFillerModel = QStringLiteral("gemma4:12b-it-qat");

bool isEdgeChar(QChar c)
{
    return c.isSpace() || c.isPunct();
}

} // namespace

FillerRemover::FillerRemover(AppController *controller, QObject *parent)
    : QObject(parent)
    , m_controller(controller)
    , m_net(new QNetworkAccessManager(this))
{
}

QString FillerRemover::model() const
{
    if (!m_useAssistantModel)
        return QSettings().value(QStringLiteral("captions/model"), kFillerModel).toString();
    const QString chosen = QSettings().value(QStringLiteral("assistant/model"), kDefaultModel).toString();
    return chosen == AssistantController::claudeModelName() ? kDefaultModel : chosen;
}

QList<FillerRemover::Line> FillerRemover::transcript() const
{
    QList<Line> lines;
    if (!m_controller)
        return lines;
    const auto &tracks = m_controller->project()->tracks();
    // The bottom subtitle lane with captions is the original; a translation sits above it.
    for (int t = tracks.size() - 1; t >= 0 && lines.isEmpty(); --t) {
        for (const drift::Clip &clip : tracks.at(t).clips) {
            if (clip.type != drift::ClipType::Subtitle)
                continue;
            for (int i = 0; i < clip.subtitleCues.size(); ++i) {
                const drift::SubtitleCue &cue = clip.subtitleCues.at(i);
                if (cue.text.trimmed().isEmpty())
                    continue;
                lines.append(Line{clip.id, i, drift::usToSeconds(clip.timelineStart + cue.startUs),
                                  drift::usToSeconds(clip.timelineStart + cue.endUs), cue.text});
            }
        }
    }
    std::sort(lines.begin(), lines.end(), [](const Line &a, const Line &b) { return a.start < b.start; });
    return lines;
}

bool FillerRemover::hasTranscript() const
{
    return !transcript().isEmpty();
}

QPair<int, int> FillerRemover::locate(const QString &line, const QString &text)
{
    QString needle = text;
    int from = 0;
    while (from < needle.size() && isEdgeChar(needle.at(from)))
        ++from;
    int to = needle.size();
    while (to > from && isEdgeChar(needle.at(to - 1)))
        --to;
    needle = needle.mid(from, to - from);
    if (needle.isEmpty())
        return {-1, 0};
    // Whole words only: "é" must not match inside "você".
    const QRegularExpression word(QStringLiteral("(?<![\\p{L}\\p{N}])%1(?![\\p{L}\\p{N}])")
                                      .arg(QRegularExpression::escape(needle)),
                                  QRegularExpression::CaseInsensitiveOption | QRegularExpression::UseUnicodePropertiesOption);
    const QRegularExpressionMatch match = word.match(line);
    if (!match.hasMatch())
        return {-1, 0};
    return {int(match.capturedStart()), int(match.capturedLength())};
}

QString FillerRemover::removeSpan(const QString &line, int offset, int length)
{
    QString left = line.left(offset);
    QString right = line.mid(offset + length);
    // Drop the separator that belonged to the removed words: one comma or ellipsis after them,
    // or before them when they ended the sentence.
    static const QRegularExpression leadingSep(QStringLiteral("^\\s*(,|\\.\\.\\.|…)"));
    static const QRegularExpression trailingSep(QStringLiteral("(,|\\.\\.\\.|…)\\s*$"));
    if (right.contains(leadingSep))
        right.remove(leadingSep);
    else if (right.trimmed().isEmpty() || right.trimmed().front().isPunct())
        left.remove(trailingSep);
    QString out = (left.trimmed() + QLatin1Char(' ') + right.trimmed()).simplified();
    out.replace(QRegularExpression(QStringLiteral("\\s+([,.!?…])")), QStringLiteral("\\1"));
    out.remove(QRegularExpression(QStringLiteral("^[,.…?!\\s]+")));
    // A sentence that lost its first word keeps a capital start.
    if (offset == 0 && !out.isEmpty() && line.front().isUpper())
        out[0] = out.at(0).toUpper();
    return out;
}

QStringList FillerRemover::retakes(const QStringList &sentences)
{
    static const QRegularExpression wordRe(QStringLiteral("[\\p{L}\\p{N}]+"),
                                           QRegularExpression::UseUnicodePropertiesOption);
    QList<QStringList> words;
    for (const QString &s : sentences) {
        QStringList w;
        auto it = wordRe.globalMatch(s.toLower());
        while (it.hasNext())
            w.append(it.next().captured());
        words.append(w);
    }
    const auto lcs = [](const QStringList &a, const QStringList &b) {
        std::vector<int> prev(b.size() + 1, 0), cur(b.size() + 1, 0);
        for (int i = 1; i <= a.size(); ++i) {
            for (int j = 1; j <= b.size(); ++j)
                cur[j] = a.at(i - 1) == b.at(j - 1) ? prev[j - 1] + 1 : std::max(prev[j], cur[j - 1]);
            std::swap(prev, cur);
        }
        return prev[b.size()];
    };
    QStringList kinds;
    for (int i = 0; i < sentences.size(); ++i) {
        QString kind;
        const QStringList &a = words.at(i);
        for (int j = i + 1; a.size() > 0 && kind.isEmpty() && j < std::min(int(sentences.size()), i + 1 + kRetakeLookahead); ++j) {
            const QStringList &b = words.at(j);
            if (b.isEmpty())
                continue;
            // Said again almost the same way: an earlier take.
            if (a.size() >= 3 && 2.0 * lcs(a, b) / (a.size() + b.size()) >= kRetakeSimilarity) {
                kind = QStringLiteral("retake");
                break;
            }
            // The opening of a longer sentence that follows: started, dropped, started over.
            int k = 0;
            while (k < std::min(a.size(), b.size()) && a.at(k) == b.at(k))
                ++k;
            if (b.size() > a.size() && k >= std::max(2, int(a.size() * 0.8)))
                kind = QStringLiteral("false_start");
        }
        kinds.append(kind);
    }
    return kinds;
}

void FillerRemover::buildSentences()
{
    // Join the captions into one text, normalising as it goes ("..." to "…", a space after a
    // sentence mark the transcriber glued to the next word) while remembering, for every
    // character, which caption it came from and where in that caption's own text.
    m_joined.clear();
    m_refs.clear();
    m_sentences.clear();
    const auto put = [this](QChar c, int line, int offset) {
        m_joined.append(c);
        m_refs.append(CharRef{line, offset});
    };
    for (int l = 0; l < m_lines.size(); ++l) {
        const QString &t = m_lines.at(l).text;
        for (int p = 0; p < t.size(); ++p) {
            QChar c = t.at(p);
            if (c == QLatin1Char('.') && t.mid(p, 3) == QStringLiteral("...")) {
                put(QChar(0x2026), l, p);
                p += 2;
                c = QChar(0x2026);
            } else {
                put(c, l, p);
            }
            const bool mark = c == QLatin1Char('.') || c == QLatin1Char('!') || c == QLatin1Char('?') || c == QChar(0x2026);
            if (mark && p + 1 < t.size() && t.at(p + 1).isLetter())
                put(QLatin1Char(' '), l, p + 1);
        }
        put(QLatin1Char(' '), l, t.size());
    }
    static const QRegularExpression end(QStringLiteral("[.!?…]+(\\s+|$)"));
    static const QRegularExpression letter(QStringLiteral("\\p{L}"), QRegularExpression::UseUnicodePropertiesOption);
    int from = 0;
    while (from < m_joined.size()) {
        const QRegularExpressionMatch m = end.match(m_joined, from);
        int to = m.hasMatch() ? int(m.capturedStart() + m.captured().trimmed().size()) : int(m_joined.size());
        int next = m.hasMatch() ? int(m.capturedEnd()) : int(m_joined.size());
        while (from < to && m_joined.at(from).isSpace())
            ++from;
        const QString text = m_joined.mid(from, to - from);
        if (text.contains(letter))
            m_sentences.append(Sentence{from, to, text});
        from = std::max(next, from + 1);
    }
}

double FillerRemover::timeAt(int joinedIndex, bool end) const
{
    joinedIndex = std::clamp(joinedIndex, 0, int(m_refs.size()) - 1);
    const CharRef ref = m_refs.at(joinedIndex);
    const Line &line = m_lines.at(ref.line);
    const double len = std::max(1, int(line.text.size()));
    const double share = std::clamp((ref.offset + (end ? 1 : 0)) / len, 0.0, 1.0);
    return line.start + (line.end - line.start) * share;
}

void FillerRemover::find()
{
    if (m_busy)
        return;
    m_lines = transcript();
    if (m_lines.isEmpty()) {
        emit finished(false, tr("This project has no captions yet. Generate them first (Captions tab)."));
        return;
    }
    buildSentences();
    m_marks.clear();
    QStringList texts;
    for (const Sentence &s : std::as_const(m_sentences))
        texts.append(s.text);
    const QStringList kinds = retakes(texts);
    for (int i = 0; i < kinds.size(); ++i) {
        if (!kinds.at(i).isEmpty())
            m_marks.append(Mark{i, 0, int(m_sentences.at(i).text.size()), kinds.at(i)});
    }
    m_proposals.clear();
    emit proposalsChanged();
    m_done = 0;
    m_total = m_sentences.size();
    m_busy = true;
    m_useAssistantModel = false;
    emit stateChanged();
    requestBatch();
}

void FillerRemover::requestBatch()
{
    const int from = m_done;
    const int to = std::min(from + kBatchSize, int(m_sentences.size()));
    const QString system = QStringLiteral(
        "You clean up a spoken transcript for video editing, one numbered sentence per line. Mark only two "
        "things. 'filler': verbal crutches inside a sentence that can go without changing the meaning (é, ã, "
        "ãh, hum, tipo, né, pô, sabe, assim or então when they add nothing, and their equivalents in other "
        "languages); copy the exact words from the sentence, the smallest span. Never mark words that carry "
        "meaning, like 'que tipo de papel'. 'aside': a whole sentence that is not part of the content, said "
        "to the crew or to oneself ('pode ir?', 'ok', 'isso', 'ai, vem cá', 'deixa eu ver'); give the whole "
        "sentence. Leave everything else alone, including repeated sentences.");
    QStringList numbered;
    for (int i = from; i < to; ++i)
        numbered.append(QStringLiteral("%1. %2").arg(i - from + 1).arg(m_sentences.at(i).text));
    const QJsonObject item{
        {QStringLiteral("type"), QStringLiteral("object")},
        {QStringLiteral("properties"),
         QJsonObject{{QStringLiteral("sentence"), QJsonObject{{QStringLiteral("type"), QStringLiteral("integer")}}},
                     {QStringLiteral("text"), QJsonObject{{QStringLiteral("type"), QStringLiteral("string")}}},
                     {QStringLiteral("kind"), QJsonObject{{QStringLiteral("type"), QStringLiteral("string")},
                                                          {QStringLiteral("enum"),
                                                           QJsonArray{QStringLiteral("filler"), QStringLiteral("aside")}}}}}},
        {QStringLiteral("required"),
         QJsonArray{QStringLiteral("sentence"), QStringLiteral("text"), QStringLiteral("kind")}}};
    const QJsonObject schema{
        {QStringLiteral("type"), QStringLiteral("object")},
        {QStringLiteral("properties"),
         QJsonObject{{QStringLiteral("items"),
                      QJsonObject{{QStringLiteral("type"), QStringLiteral("array")}, {QStringLiteral("items"), item}}}}},
        {QStringLiteral("required"), QJsonArray{QStringLiteral("items")}}};
    const QJsonObject body{
        {QStringLiteral("model"), model()},
        {QStringLiteral("stream"), false},
        {QStringLiteral("think"), false},
        {QStringLiteral("keep_alive"), QStringLiteral("10m")},
        {QStringLiteral("format"), schema},
        {QStringLiteral("messages"),
         QJsonArray{QJsonObject{{QStringLiteral("role"), QStringLiteral("system")}, {QStringLiteral("content"), system}},
                    QJsonObject{{QStringLiteral("role"), QStringLiteral("user")},
                                {QStringLiteral("content"), numbered.join(QLatin1Char('\n'))}}}},
        {QStringLiteral("options"), QJsonObject{{QStringLiteral("temperature"), 0}, {QStringLiteral("num_ctx"), 8192}}}};
    const QUrl base(QSettings().value(QStringLiteral("assistant/url"), kDefaultUrl).toString());
    QNetworkRequest request(base.resolved(QUrl(QStringLiteral("/api/chat"))));
    request.setHeader(QNetworkRequest::ContentTypeHeader, QStringLiteral("application/json"));
    request.setTransferTimeout(300000);
    m_reply = m_net->post(request, QJsonDocument(body).toJson(QJsonDocument::Compact));
    QNetworkReply *reply = m_reply;
    connect(reply, &QNetworkReply::finished, this, [this, reply] { handleBatch(reply); });
}

void FillerRemover::handleBatch(QNetworkReply *reply)
{
    reply->deleteLater();
    if (reply != m_reply || !m_busy)
        return;
    m_reply = nullptr;
    if (reply->error() == QNetworkReply::ContentNotFoundError && !m_useAssistantModel) {
        m_useAssistantModel = true;
        requestBatch();
        return;
    }
    if (reply->error() != QNetworkReply::NoError) {
        // The retakes need no model; offer those alone rather than nothing.
        if (!m_marks.isEmpty()) {
            m_done = m_sentences.size();
            complete();
            emit finished(false, tr("The local AI did not answer, so only repeated takes are listed."));
            return;
        }
        m_busy = false;
        emit stateChanged();
        emit finished(false, reply->error() == QNetworkReply::ConnectionRefusedError
                                 ? tr("Ollama is not answering. Open Ollama and try again.")
                                 : tr("The local AI failed: %1").arg(reply->errorString()));
        return;
    }
    const int from = m_done;
    const int to = std::min(from + kBatchSize, int(m_sentences.size()));
    QSet<int> taken;
    for (const Mark &m : std::as_const(m_marks))
        if (m.length >= m_sentences.at(m.sentence).text.size())
            taken.insert(m.sentence);
    const QString content = QJsonDocument::fromJson(reply->readAll())
                                .object()
                                .value(QStringLiteral("message"))
                                .toObject()
                                .value(QStringLiteral("content"))
                                .toString();
    for (const QJsonValue &value :
         QJsonDocument::fromJson(content.toUtf8()).object().value(QStringLiteral("items")).toArray()) {
        const QJsonObject item = value.toObject();
        const int sentence = from + item.value(QStringLiteral("sentence")).toInt() - 1;
        if (sentence < from || sentence >= to || taken.contains(sentence))
            continue;
        const QString kind = item.value(QStringLiteral("kind")).toString();
        const QString &text = m_sentences.at(sentence).text;
        if (kind == QLatin1String("aside")) {
            m_marks.append(Mark{sentence, 0, int(text.size()), kind});
            taken.insert(sentence);
            continue;
        }
        const QPair<int, int> at = locate(text, item.value(QStringLiteral("text")).toString());
        if (at.first >= 0)
            m_marks.append(Mark{sentence, at.first, at.second, kind});
    }
    m_done = to;
    emit stateChanged();
    if (m_done < m_sentences.size())
        requestBatch();
    else
        complete();
}

void FillerRemover::complete()
{
    QVariantList proposals;
    double lastEnd = -1;
    std::sort(m_marks.begin(), m_marks.end(), [](const Mark &a, const Mark &b) {
        return a.sentence != b.sentence ? a.sentence < b.sentence : a.offset < b.offset;
    });
    for (const Mark &mark : std::as_const(m_marks)) {
        const Sentence &s = m_sentences.at(mark.sentence);
        const bool whole = mark.offset == 0 && mark.length >= s.text.size();
        const int a = s.from + mark.offset;
        const int b = s.from + mark.offset + mark.length - 1;
        double start = timeAt(a, false);
        double end = timeAt(b, true);
        // Move the edges between words: a sentence edge into the pause around it, a word edge to
        // the quietest point next to it.
        const double window = whole ? kSentenceSnapWindow : kSnapWindow;
        bool startInPause = false;
        bool endInPause = false;
        start = m_controller->quietestPointNear(start, window, &startInPause);
        end = m_controller->quietestPointNear(end, window, &endInPause);
        // An edge with no pause near it may clip a word: listen first.
        const bool unsure = !startInPause || !endInPause;
        // Neighbouring marks meet at one point rather than overlap.
        if (start < lastEnd)
            start = lastEnd;
        if (end - start < kMinCutSeconds || end - start > kMaxCutSeconds)
            continue;
        lastEnd = end;
        proposals.append(QVariantMap{
            {QStringLiteral("start"), start},
            {QStringLiteral("end"), end},
            {QStringLiteral("kind"), mark.kind},
            {QStringLiteral("line"), s.text},
            {QStringLiteral("offset"), mark.offset},
            {QStringLiteral("length"), mark.length},
            {QStringLiteral("sentence"), mark.sentence},
            {QStringLiteral("unsure"), unsure},
            // Asides are the least sure call, and an edge outside a pause may clip a word: the
            // user opts in to those.
            {QStringLiteral("checked"), mark.kind != QLatin1String("aside") && !unsure}});
    }
    for (int i = 0; i < proposals.size(); ++i) {
        QVariantMap p = proposals.at(i).toMap();
        p.insert(QStringLiteral("index"), i);
        proposals[i] = p;
    }
    m_proposals = proposals;
    m_busy = false;
    emit stateChanged();
    emit proposalsChanged();
    if (m_proposals.isEmpty())
        emit finished(true, tr("No filler words or repeated takes found."));
}

int FillerRemover::apply(const QVariantList &proposalIndexes)
{
    if (m_busy || !m_controller)
        return 0;
    QList<QVariantMap> chosen;
    for (const QVariant &value : proposalIndexes) {
        const int index = value.toInt();
        if (index >= 0 && index < m_proposals.size())
            chosen.append(m_proposals.at(index).toMap());
    }
    if (chosen.isEmpty())
        return 0;

    // Which characters of which caption each chosen mark covers, in that caption's own text.
    std::map<int, QList<QPair<int, int>>> spansByLine;
    for (const QVariantMap &p : std::as_const(chosen)) {
        const Sentence &s = m_sentences.at(p.value(QStringLiteral("sentence")).toInt());
        const int a = s.from + p.value(QStringLiteral("offset")).toInt();
        const int b = a + p.value(QStringLiteral("length")).toInt();
        std::map<int, QPair<int, int>> perLine;
        for (int k = a; k < b && k < m_refs.size(); ++k) {
            const CharRef ref = m_refs.at(k);
            auto it = perLine.find(ref.line);
            if (it == perLine.end())
                perLine[ref.line] = {ref.offset, ref.offset + 1};
            else
                it->second.second = std::max(it->second.second, ref.offset + 1);
        }
        for (const auto &[line, span] : perLine)
            spansByLine[line].append(span);
    }

    m_controller->mcpBeginBatch();
    // Caption text first, while the clips are where the marks were taken; right to left inside a
    // caption so the offsets stay valid.
    std::map<QString, std::map<int, QString>> newText; // clip id -> cue -> text
    for (auto &[line, spans] : spansByLine) {
        const Line &l = m_lines.at(line);
        std::sort(spans.begin(), spans.end(), [](const auto &x, const auto &y) { return x.first > y.first; });
        QString text = l.text;
        for (const auto &span : spans) {
            const int length = std::min(span.second, int(text.size())) - span.first;
            if (span.first >= 0 && length > 0)
                text = removeSpan(text, span.first, length);
        }
        newText[l.clipId][l.cue] = text;
    }
    for (const auto &[clipId, cues] : newText) {
        const QPair<int, int> loc = m_controller->mcpLocateClip(clipId);
        if (loc.first < 0)
            continue;
        const drift::Clip &clip = m_controller->project()->tracks().at(loc.first).clips.at(loc.second);
        QVariantList list;
        for (int i = 0; i < clip.subtitleCues.size(); ++i) {
            const drift::SubtitleCue &cue = clip.subtitleCues.at(i);
            const auto it = cues.find(i);
            list.append(QVariantMap{{QStringLiteral("start"), drift::usToSeconds(cue.startUs)},
                                    {QStringLiteral("end"), drift::usToSeconds(cue.endUs)},
                                    {QStringLiteral("text"), it != cues.end() ? it->second : cue.text}});
        }
        m_controller->setSubtitleCues(loc.first, loc.second, list);
    }
    // Then the time, latest first so the earlier stretches have not moved yet.
    std::sort(chosen.begin(), chosen.end(), [](const QVariantMap &a, const QVariantMap &b) {
        return a.value(QStringLiteral("start")).toDouble() > b.value(QStringLiteral("start")).toDouble();
    });
    int cut = 0;
    for (const QVariantMap &p : std::as_const(chosen)) {
        if (m_controller->cutTimeRange(p.value(QStringLiteral("start")).toDouble(),
                                       p.value(QStringLiteral("end")).toDouble()))
            ++cut;
    }
    m_controller->mergeTouchingSubtitleClips();
    m_controller->mcpEndBatch(tr("Filler words removed"), true);
    m_proposals.clear();
    emit proposalsChanged();
    emit finished(cut > 0, cut > 0 ? tr("%n stretch(es) cut. Ctrl+Z brings them back.", "", cut)
                                   : tr("Nothing could be cut. Is a track locked?"));
    return cut;
}

void FillerRemover::cancel()
{
    if (m_reply) {
        QNetworkReply *reply = m_reply;
        m_reply = nullptr;
        reply->abort();
    }
    if (m_busy) {
        m_busy = false;
        emit stateChanged();
    }
}
