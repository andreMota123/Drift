#include "ShortsMaker.h"

#include "AppController.h"
#include "AssistantController.h"

#include <QCoreApplication>
#include <QDesktopServices>
#include <QDir>
#include <QFileInfo>
#include <QJsonArray>
#include <QJsonDocument>
#include <QNetworkAccessManager>
#include <QNetworkReply>
#include <QNetworkRequest>
#include <QProcess>
#include <QProcessEnvironment>
#include <QRegularExpression>
#include <QSettings>
#include <QStandardPaths>
#include <QTimer>
#include <QUrl>
#include <QUuid>

#include <QFile>

#include <algorithm>
#include <memory>

namespace {

const QString kDefaultUrl = QStringLiteral("http://127.0.0.1:11434");
const QString kDefaultModel = QStringLiteral("qwen3:14b");
constexpr int kTargetW = 1080;
constexpr int kTargetH = 1920;
// Long transcripts are merged into blocks of at least this many seconds before they go to the
// model, so an hour of talk still fits its context window.
constexpr int kMaxLinesForModel = 400;
constexpr double kMergedBlockSeconds = 8.0;

QString mmss(double seconds)
{
    const int s = qMax(0, int(seconds));
    return QStringLiteral("%1:%2").arg(s / 60).arg(s % 60, 2, 10, QLatin1Char('0'));
}

QString safeFileName(QString name)
{
    name.replace(QRegularExpression(QStringLiteral("[\\\\/:*?\"<>|\\n\\r\\t]")), QStringLiteral(" "));
    name = name.simplified();
    return name.left(60);
}

QJsonObject textPayload(const QJsonObject &result)
{
    const QJsonArray content = result.value(QStringLiteral("content")).toArray();
    if (content.isEmpty())
        return result;
    return QJsonDocument::fromJson(content.first().toObject().value(QStringLiteral("text")).toString().toUtf8())
        .object();
}

} // namespace

ShortsMaker::ShortsMaker(AppController *controller, QObject *parent)
    : QObject(parent)
    , m_controller(controller)
    , m_net(new QNetworkAccessManager(this))
{
}

void ShortsMaker::setStage(const QString &stage, double progress)
{
    m_stage = stage;
    m_progress = progress;
    emit stateChanged();
}

QList<ShortsMaker::Line> ShortsMaker::transcript() const
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
            for (const drift::SubtitleCue &cue : clip.subtitleCues) {
                if (cue.text.trimmed().isEmpty())
                    continue;
                lines.append(Line{drift::usToSeconds(clip.timelineStart + cue.startUs),
                                  drift::usToSeconds(clip.timelineStart + cue.endUs), cue.text.simplified()});
            }
        }
    }
    std::sort(lines.begin(), lines.end(), [](const Line &a, const Line &b) { return a.start < b.start; });
    if (lines.size() <= kMaxLinesForModel)
        return lines;
    QList<Line> merged;
    for (const Line &line : lines) {
        if (!merged.isEmpty() && merged.last().end - merged.last().start < kMergedBlockSeconds) {
            merged.last().end = line.end;
            merged.last().text += QLatin1Char(' ') + line.text;
        } else {
            merged.append(line);
        }
    }
    return merged;
}

bool ShortsMaker::hasTranscript() const
{
    return !transcript().isEmpty();
}

void ShortsMaker::findShorts(int count, int targetSeconds)
{
    if (busy())
        return;
    const QList<Line> lines = transcript();
    if (lines.isEmpty()) {
        emit finished(false, tr("This project has no captions yet. Generate them first (Captions tab)."), QString());
        return;
    }
    if (lines.last().end - lines.first().start < targetSeconds * 1.5) {
        emit finished(false, tr("The video is too short to cut into shorts of this length."), QString());
        return;
    }
    count = qBound(1, count, 10);
    targetSeconds = qBound(15, targetSeconds, 180);
    m_proposals.clear();
    emit proposalsChanged();
    setStage(tr("Choosing the best moments…"), 0.2);

    QStringList numbered;
    for (int i = 0; i < lines.size(); ++i)
        numbered.append(QStringLiteral("%1. [%2] %3").arg(i + 1).arg(mmss(lines.at(i).start), lines.at(i).text));
    const QString system =
        QStringLiteral(
            "You are a video editor who turns a long video into short vertical clips for TikTok, Reels and "
            "Shorts. From the numbered transcript lines (with start times), choose up to %1 segments of about "
            "%2 seconds each (between %3 and %4 seconds). Each segment must work on its own: its first line hooks "
            "the viewer without needing earlier context, it covers one complete idea, and it ends where a thought "
            "ends. Prefer the most useful, surprising or emotional moments; skip greetings, housekeeping and calls "
            "to action. Segments must not overlap. For each give first_line and last_line (line numbers), a short "
            "catchy title and a one-sentence reason, both in the transcript's language.")
            .arg(count)
            .arg(targetSeconds)
            .arg(int(targetSeconds * 0.6))
            .arg(int(targetSeconds * 1.5));
    const QJsonObject item{
        {QStringLiteral("type"), QStringLiteral("object")},
        {QStringLiteral("properties"),
         QJsonObject{{QStringLiteral("first_line"), QJsonObject{{QStringLiteral("type"), QStringLiteral("integer")}}},
                     {QStringLiteral("last_line"), QJsonObject{{QStringLiteral("type"), QStringLiteral("integer")}}},
                     {QStringLiteral("title"), QJsonObject{{QStringLiteral("type"), QStringLiteral("string")}}},
                     {QStringLiteral("reason"), QJsonObject{{QStringLiteral("type"), QStringLiteral("string")}}}}},
        {QStringLiteral("required"), QJsonArray{QStringLiteral("first_line"), QStringLiteral("last_line"),
                                                QStringLiteral("title"), QStringLiteral("reason")}}};
    const QJsonObject schema{
        {QStringLiteral("type"), QStringLiteral("object")},
        {QStringLiteral("properties"),
         QJsonObject{{QStringLiteral("shorts"), QJsonObject{{QStringLiteral("type"), QStringLiteral("array")},
                                                            {QStringLiteral("maxItems"), count},
                                                            {QStringLiteral("items"), item}}}}},
        {QStringLiteral("required"), QJsonArray{QStringLiteral("shorts")}}};
    const QString transcriptText = numbered.join(QLatin1Char('\n'));
    // Rough token count (~4 characters each) plus room for the answer.
    const int context = qBound(8192, int(transcriptText.size() / 3) + 4096, 32768);

    QString model = QSettings().value(QStringLiteral("assistant/model"), kDefaultModel).toString();
    if (model == AssistantController::claudeModelName())
        model = kDefaultModel;
    const QJsonObject body{
        {QStringLiteral("model"), model},
        {QStringLiteral("stream"), false},
        {QStringLiteral("think"), false},
        {QStringLiteral("keep_alive"), QStringLiteral("10m")},
        {QStringLiteral("format"), schema},
        {QStringLiteral("messages"),
         QJsonArray{QJsonObject{{QStringLiteral("role"), QStringLiteral("system")}, {QStringLiteral("content"), system}},
                    QJsonObject{{QStringLiteral("role"), QStringLiteral("user")},
                                {QStringLiteral("content"), QStringLiteral("Transcript:\n") + transcriptText}}}},
        {QStringLiteral("options"), QJsonObject{{QStringLiteral("temperature"), 0}, {QStringLiteral("num_ctx"), context}}}};
    const QUrl base(QSettings().value(QStringLiteral("assistant/url"), kDefaultUrl).toString());
    QNetworkRequest request(base.resolved(QUrl(QStringLiteral("/api/chat"))));
    request.setHeader(QNetworkRequest::ContentTypeHeader, QStringLiteral("application/json"));
    request.setTransferTimeout(600000);
    m_reply = m_net->post(request, QJsonDocument(body).toJson(QJsonDocument::Compact));
    QNetworkReply *reply = m_reply;
    connect(reply, &QNetworkReply::finished, this,
            [this, reply, count, targetSeconds] { handleProposals(reply, count, targetSeconds); });
}

void ShortsMaker::handleProposals(QNetworkReply *reply, int count, int targetSeconds)
{
    reply->deleteLater();
    if (reply != m_reply)
        return;
    m_reply = nullptr;
    setStage(QString(), 0);
    if (reply->error() != QNetworkReply::NoError) {
        emit finished(false,
                      reply->error() == QNetworkReply::ConnectionRefusedError
                          ? tr("Ollama is not answering. Open Ollama and try again.")
                          : tr("The local AI failed: %1").arg(reply->errorString()),
                      QString());
        return;
    }
    const QList<Line> lines = transcript();
    const QString content = QJsonDocument::fromJson(reply->readAll())
                                .object()
                                .value(QStringLiteral("message"))
                                .toObject()
                                .value(QStringLiteral("content"))
                                .toString();
    const QJsonArray shorts = QJsonDocument::fromJson(content.toUtf8()).object().value(QStringLiteral("shorts")).toArray();

    const double minLen = targetSeconds * 0.6;
    const double maxLen = targetSeconds * 1.5;
    QList<QPair<double, double>> taken;
    QVariantList proposals;
    for (const QJsonValue &value : shorts) {
        const QJsonObject s = value.toObject();
        int first = s.value(QStringLiteral("first_line")).toInt() - 1;
        int last = s.value(QStringLiteral("last_line")).toInt() - 1;
        if (first < 0 || first >= lines.size() || last < first)
            continue;
        last = qMin(last, int(lines.size()) - 1);
        // Hold the length to the asked range by moving the end a line at a time.
        while (last + 1 < lines.size() && lines.at(last).end - lines.at(first).start < minLen)
            ++last;
        while (last > first && lines.at(last).end - lines.at(first).start > maxLen)
            --last;
        const double start = lines.at(first).start;
        const double end = lines.at(last).end;
        if (end - start < minLen * 0.75)
            continue;
        bool overlaps = false;
        for (const auto &range : taken)
            overlaps = overlaps || (start < range.second && end > range.first);
        if (overlaps)
            continue;
        taken.append({start, end});
        proposals.append(QVariantMap{{QStringLiteral("start"), start},
                                     {QStringLiteral("end"), end},
                                     {QStringLiteral("title"), s.value(QStringLiteral("title")).toString().trimmed()},
                                     {QStringLiteral("reason"), s.value(QStringLiteral("reason")).toString().trimmed()},
                                     {QStringLiteral("firstText"), lines.at(first).text}});
        if (proposals.size() >= count)
            break;
    }
    std::sort(proposals.begin(), proposals.end(), [](const QVariant &a, const QVariant &b) {
        return a.toMap().value(QStringLiteral("start")).toDouble() < b.toMap().value(QStringLiteral("start")).toDouble();
    });
    for (int i = 0; i < proposals.size(); ++i) {
        QVariantMap p = proposals.at(i).toMap();
        p.insert(QStringLiteral("index"), i);
        proposals[i] = p;
    }
    m_proposals = proposals;
    emit proposalsChanged();
    if (m_proposals.isEmpty())
        emit finished(false, tr("The local AI did not find usable moments. Try another length."), QString());
}

// --- Making the shorts ------------------------------------------------------------------

void ShortsMaker::createShorts(const QVariantList &proposalIndexes)
{
    if (busy() || proposalIndexes.isEmpty() || !m_controller)
        return;
    m_sourceJson = QDir(QStandardPaths::writableLocation(QStandardPaths::TempLocation))
                       .filePath(QStringLiteral("drift-cortes-%1.json")
                                     .arg(QUuid::createUuid().toString(QUuid::WithoutBraces)));
    m_controller->saveProjectJson(QUrl::fromLocalFile(m_sourceJson));
    if (!QFileInfo::exists(m_sourceJson)) {
        emit finished(false, tr("Could not write a copy of the project."), QString());
        return;
    }

    QString name = m_controller->projectName().trimmed();
    if (name.isEmpty())
        name = tr("Project");
    const QString projectPath = m_controller->currentProjectPath();
    const QString baseDir = projectPath.isEmpty()
                                ? QDir(QStandardPaths::writableLocation(QStandardPaths::MoviesLocation)).filePath(QStringLiteral("Drift"))
                                : QFileInfo(projectPath).absolutePath();
    m_folder = QDir(baseDir).filePath(safeFileName(tr("%1 - shorts").arg(name)));
    QDir().mkpath(m_folder);

    m_jobs.clear();
    for (const QVariant &value : proposalIndexes) {
        const int index = value.toInt();
        if (index < 0 || index >= m_proposals.size())
            continue;
        const QVariantMap p = m_proposals.at(index).toMap();
        const QString file = QStringLiteral("%1 - %2.drift")
                                 .arg(m_jobs.size() + 1, 2, 10, QLatin1Char('0'))
                                 .arg(safeFileName(p.value(QStringLiteral("title")).toString()));
        m_jobs.append(Job{p.value(QStringLiteral("start")).toDouble(), p.value(QStringLiteral("end")).toDouble(),
                          QDir(m_folder).filePath(file)});
    }
    m_jobIndex = -1;
    m_made = 0;
    startNextJob();
}

void ShortsMaker::startNextJob()
{
    ++m_jobIndex;
    if (m_jobIndex >= m_jobs.size()) {
        finishAll();
        return;
    }
    setStage(tr("Making short %1 of %2…").arg(m_jobIndex + 1).arg(m_jobs.size()),
             double(m_jobIndex) / m_jobs.size());

    m_buffer.clear();
    m_pending.clear();
    m_process = new QProcess(this);
    QProcessEnvironment env = QProcessEnvironment::systemEnvironment();
    env.insert(QStringLiteral("QT_QPA_PLATFORM"), QStringLiteral("offscreen"));
    env.remove(QStringLiteral("DRIFT_MCP_AUTOSTART"));
    m_process->setProcessEnvironment(env);
    m_process->setProcessChannelMode(QProcess::SeparateChannels);
    connect(m_process, &QProcess::readyReadStandardOutput, this, &ShortsMaker::readProcess);
    QProcess *process = m_process;
    connect(m_process, &QProcess::finished, this, [this, process] {
        process->deleteLater();
        if (process == m_process) {
            m_process = nullptr;
            finishJob(false); // ended before the short was saved
        }
    });
    m_process->start(QCoreApplication::applicationFilePath(),
                     {QStringLiteral("--headless"), QStringLiteral("--mcp-stdio"), m_sourceJson});

    const Job job = m_jobs.at(m_jobIndex);
    call(QStringLiteral("initialize"),
         QJsonObject{{QStringLiteral("protocolVersion"), QStringLiteral("2024-11-05")},
                     {QStringLiteral("capabilities"), QJsonObject{}},
                     {QStringLiteral("clientInfo"), QJsonObject{{QStringLiteral("name"), QStringLiteral("drift-shorts")},
                                                                {QStringLiteral("version"), QStringLiteral("1")}}}},
         [this, job](const QJsonObject &) {
    tool(QStringLiteral("inspect"), {}, [this, job](const QJsonObject &info) {
        m_oldW = info.value(QStringLiteral("w")).toDouble(1920);
        m_oldH = info.value(QStringLiteral("h")).toDouble(1080);
        m_fps = info.value(QStringLiteral("fps")).toInt(30);
        const double dur = info.value(QStringLiteral("dur")).toDouble();
        QJsonArray ops;
        // Cut the tail first so the start of the range does not move before it is cut.
        if (job.end < dur - 0.05)
            ops.append(QJsonObject{{QStringLiteral("tool"), QStringLiteral("cut_time_range")},
                                   {QStringLiteral("args"), QJsonObject{{QStringLiteral("start"), job.end},
                                                                        {QStringLiteral("end"), dur}}}});
        if (job.start > 0.05)
            ops.append(QJsonObject{{QStringLiteral("tool"), QStringLiteral("cut_time_range")},
                                   {QStringLiteral("args"), QJsonObject{{QStringLiteral("start"), 0.0},
                                                                        {QStringLiteral("end"), job.start}}}});
        const auto afterCuts = [this](const QJsonObject &cut) {
            if (cut.value(QStringLiteral("ok")).toBool(true) == false) {
                finishJob(false);
                return;
            }
            tool(QStringLiteral("inspect"), QJsonObject{{QStringLiteral("clips"), true}}, [this](const QJsonObject &layout) {
                QList<QJsonObject> clips;
                for (const QJsonValue &t : layout.value(QStringLiteral("tracks")).toArray()) {
                    for (const QJsonValue &item : t.toObject().value(QStringLiteral("items")).toArray()) {
                        const QString kind = item.toObject().value(QStringLiteral("kind")).toString();
                        if (kind != QLatin1String("audio"))
                            clips.append(item.toObject());
                    }
                }
                // Read every clip's box on the old canvas first, then resize, then place.
                layoutClips(clips, 0, [this] {
                    tool(QStringLiteral("save_project"),
                         QJsonObject{{QStringLiteral("path"), m_jobs.at(m_jobIndex).path}},
                         [this](const QJsonObject &saved) {
                             if (saved.value(QStringLiteral("ok")).toBool() == false) {
                                 finishJob(false);
                                 return;
                             }
                             tool(QStringLiteral("inspect"), {}, [this](const QJsonObject &check) {
                                 const bool ok = check.value(QStringLiteral("path")).toString()
                                                     == m_jobs.at(m_jobIndex).path
                                                 && !check.value(QStringLiteral("dirty")).toBool(true);
                                 finishJob(ok);
                             });
                         });
                });
            });
        };
        if (ops.isEmpty())
            afterCuts(QJsonObject{{QStringLiteral("ok"), true}});
        else
            tool(QStringLiteral("apply"), QJsonObject{{QStringLiteral("ops"), ops}}, afterCuts);
    });
         });
}

void ShortsMaker::layoutClips(const QList<QJsonObject> &clips, int index, std::function<void()> done)
{
    // Phase 1 (index < size): read each clip's box with select_clip, stored on the list copy.
    // Phase 2: resize the canvas, then write every box for the vertical frame.
    if (index < clips.size()) {
        const QString id = clips.at(index).value(QStringLiteral("id")).toString();
        tool(QStringLiteral("select_clip"), QJsonObject{{QStringLiteral("clip"), id}},
             [this, clips, index, done](const QJsonObject &box) {
                 QList<QJsonObject> next = clips;
                 for (const QString &key : {QStringLiteral("x"), QStringLiteral("y"), QStringLiteral("w"), QStringLiteral("h")})
                     next[index].insert(key, box.value(key));
                 layoutClips(next, index + 1, done);
             });
        return;
    }

    const auto place = std::make_shared<std::function<void(int)>>();
    *place = [this, clips, done, place](int i) {
        if (i >= clips.size()) {
            done();
            return;
        }
        const QJsonObject c = clips.at(i);
        const QString kind = c.value(QStringLiteral("kind")).toString();
        const double x = c.value(QStringLiteral("x")).toDouble();
        const double y = c.value(QStringLiteral("y")).toDouble();
        const double w = c.value(QStringLiteral("w")).toDouble();
        const double h = c.value(QStringLiteral("h")).toDouble();
        if (w <= 0 || h <= 0) {
            (*place)(i + 1);
            return;
        }
        double nx, ny, nw, nh;
        const bool fullFrame = (kind == QLatin1String("video") || kind == QLatin1String("image"))
                               && (w >= m_oldW * 0.95 || h >= m_oldH * 0.95);
        if (fullFrame) {
            // Fill the vertical frame and crop the sides, centred.
            const double scale = std::max(kTargetW / w, kTargetH / h);
            nw = w * scale;
            nh = h * scale;
            nx = (kTargetW - nw) / 2;
            ny = (kTargetH - nh) / 2;
        } else if (kind == QLatin1String("text") || kind == QLatin1String("subtitle")) {
            // Full width, same height, same relative height on screen.
            nx = 0;
            nw = kTargetW;
            nh = h;
            ny = y / m_oldH * kTargetH;
        } else {
            const double f = double(kTargetW) / m_oldW;
            nw = w * f;
            nh = h * f;
            nx = x * f;
            ny = y / m_oldH * kTargetH;
        }
        tool(QStringLiteral("set_transform"),
             QJsonObject{{QStringLiteral("clip"), c.value(QStringLiteral("id"))},
                         {QStringLiteral("x"), nx}, {QStringLiteral("y"), ny},
                         {QStringLiteral("w"), nw}, {QStringLiteral("h"), nh}},
             [place, i](const QJsonObject &) { (*place)(i + 1); });
    };
    tool(QStringLiteral("apply"),
         QJsonObject{{QStringLiteral("ops"),
                      QJsonArray{QJsonObject{{QStringLiteral("tool"), QStringLiteral("set_project_setup")},
                                             {QStringLiteral("args"), QJsonObject{{QStringLiteral("width"), kTargetW},
                                                                                  {QStringLiteral("height"), kTargetH},
                                                                                  {QStringLiteral("fps"), m_fps}}}}}}},
         [this, place](const QJsonObject &) { (*place)(0); });
}

void ShortsMaker::call(const QString &method, const QJsonObject &params, std::function<void(const QJsonObject &)> done)
{
    if (!m_process)
        return;
    const int id = ++m_nextId;
    m_pending[id] = std::move(done);
    const QJsonObject request{{QStringLiteral("jsonrpc"), QStringLiteral("2.0")},
                              {QStringLiteral("id"), id},
                              {QStringLiteral("method"), method},
                              {QStringLiteral("params"), params}};
    m_process->write(QJsonDocument(request).toJson(QJsonDocument::Compact) + '\n');
}

void ShortsMaker::tool(const QString &name, const QJsonObject &args, std::function<void(const QJsonObject &)> done)
{
    call(QStringLiteral("tools/call"),
         QJsonObject{{QStringLiteral("name"), name}, {QStringLiteral("arguments"), args}},
         [done](const QJsonObject &result) { done(textPayload(result)); });
}

void ShortsMaker::readProcess()
{
    if (!m_process)
        return;
    m_buffer += m_process->readAllStandardOutput();
    int newline;
    while ((newline = m_buffer.indexOf('\n')) >= 0) {
        const QJsonObject message = QJsonDocument::fromJson(m_buffer.left(newline)).object();
        m_buffer.remove(0, newline + 1);
        const int id = message.value(QStringLiteral("id")).toInt(-1);
        auto it = m_pending.find(id);
        if (it == m_pending.end())
            continue;
        auto callback = std::move(it->second);
        m_pending.erase(it);
        callback(message.value(QStringLiteral("result")).toObject());
    }
}

void ShortsMaker::finishJob(bool ok)
{
    if (ok)
        ++m_made;
    m_pending.clear();
    if (QProcess *process = m_process) {
        m_process = nullptr;
        process->closeWriteChannel();
        if (!process->waitForFinished(5000))
            process->kill();
    }
    QTimer::singleShot(0, this, &ShortsMaker::startNextJob);
}

void ShortsMaker::finishAll()
{
    QFile::remove(m_sourceJson);
    const int wanted = m_jobs.size();
    m_jobs.clear();
    setStage(QString(), 0);
    if (m_made == 0)
        emit finished(false, tr("No short could be made."), QString());
    else if (m_made < wanted)
        emit finished(true, tr("%1 of %2 shorts made, in %3").arg(m_made).arg(wanted).arg(m_folder), m_folder);
    else
        emit finished(true, tr("%n short(s) made, in %1", "", m_made).arg(m_folder), m_folder);
}

void ShortsMaker::cancel()
{
    if (m_reply) {
        QNetworkReply *reply = m_reply;
        m_reply = nullptr;
        reply->abort();
    }
    m_jobs.clear();
    m_jobIndex = 0;
    m_pending.clear();
    if (QProcess *process = m_process) {
        m_process = nullptr;
        process->kill();
    }
    if (!m_sourceJson.isEmpty())
        QFile::remove(m_sourceJson);
    setStage(QString(), 0);
}

void ShortsMaker::openOutputFolder()
{
    if (!m_folder.isEmpty())
        QDesktopServices::openUrl(QUrl::fromLocalFile(m_folder));
}
