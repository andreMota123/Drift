#include "AssistantController.h"

#include "AppController.h"
#include "mcp/McpProtocol.h"
#include "mcp/McpServer.h"

#include <QJsonDocument>
#include <QNetworkAccessManager>
#include <QNetworkReply>
#include <QNetworkRequest>
#include <QFile>
#include <QSettings>
#include <QStandardPaths>
#include <QSet>
#include <QTimer>

namespace {

constexpr int kMaxStepsPerRequest = 14;
constexpr int kToolResultLimit = 8000;
constexpr int kProjectSummaryLimit = 4000;
constexpr int kRequestTimeoutMs = 300000;

const QString kDefaultUrl = QStringLiteral("http://127.0.0.1:11434");
const QString kDefaultModel = QStringLiteral("qwen3:14b");
const QUrl kPonteUrl(QStringLiteral("http://127.0.0.1:11500"));

// Ops the bridged Claude may not run: there is no way to ask the user mid-request, so they are
// refused and Claude is told to leave them to the user.
QSet<QString> claudeBlockedOps()
{
    static const QStringList ops = {
        QStringLiteral("remove_asset"), QStringLiteral("replace_asset"), QStringLiteral("relink_media"),
        QStringLiteral("export_asset_image"), QStringLiteral("save_project"), QStringLiteral("load_project"),
        QStringLiteral("new_project"), QStringLiteral("package_project"), QStringLiteral("export_video"),
        QStringLiteral("export_with_preset"), QStringLiteral("export_selected_clips"),
        QStringLiteral("restore_snapshot"), QStringLiteral("market_download"), QStringLiteral("install_addon"),
        QStringLiteral("set_theme"), QStringLiteral("set_shortcut"), QStringLiteral("reset_shortcuts"),
        QStringLiteral("set_beat_layers"), QStringLiteral("delete_user_text_preset"),
        QStringLiteral("delete_text_animation_preset"), QStringLiteral("export_user_text_preset"),
        QStringLiteral("export_text_animation_preset"), QStringLiteral("import_user_text_preset"),
        QStringLiteral("import_text_animation_preset"), QStringLiteral("take_snapshot"),
    };
    return QSet<QString>(ops.begin(), ops.end());
}

// The homepage tools the model gets. capture/frames return images, which a text model cannot
// read, and catalog is a large dump that search answers better.
const QSet<QString> kModelTools = {QStringLiteral("search"), QStringLiteral("toolbox"),
                                   QStringLiteral("inspect"), QStringLiteral("apply")};

// The ops most requests need, given to the model up front with their exact argument names so it
// does not have to search for them (and guess names when it does not).
const QStringList kCommonOps = {
    QStringLiteral("split_clip"), QStringLiteral("delete_clip"), QStringLiteral("cut_time_range"),
    QStringLiteral("close_gap"), QStringLiteral("close_all_gaps"), QStringLiteral("move_clip"),
    QStringLiteral("set_trim"), QStringLiteral("set_duration"), QStringLiteral("duplicate_clip"),
    QStringLiteral("place_clip"), QStringLiteral("move_to_track"), QStringLiteral("add_track"),
    QStringLiteral("add_text"), QStringLiteral("set_text"), QStringLiteral("set_clip_speed"),
    QStringLiteral("set_clip_reverse"), QStringLiteral("set_volume"), QStringLiteral("set_fade"),
    QStringLiteral("set_transform"), QStringLiteral("add_transition"), QStringLiteral("list_transitions"),
    QStringLiteral("add_effect"), QStringLiteral("list_effects"), QStringLiteral("apply_makeup_look"),
    QStringLiteral("set_animation"),
    QStringLiteral("freeze_frame"), QStringLiteral("separate_audio"), QStringLiteral("select_clip"),
    QStringLiteral("generate_subtitles"), QStringLiteral("remove_silence"), QStringLiteral("add_bookmark"),
    QStringLiteral("seek"), QStringLiteral("save_project"), QStringLiteral("list_export_presets"),
    QStringLiteral("export_with_preset"),
};

QString compactJson(const QJsonValue &value)
{
    if (value.isObject())
        return QString::fromUtf8(QJsonDocument(value.toObject()).toJson(QJsonDocument::Compact));
    if (value.isArray())
        return QString::fromUtf8(QJsonDocument(value.toArray()).toJson(QJsonDocument::Compact));
    return value.toVariant().toString();
}

} // namespace

AssistantController::AssistantController(AppController *controller, QObject *parent)
    : QObject(parent)
    , m_controller(controller)
    , m_net(new QNetworkAccessManager(this))
{
    QSettings settings;
    m_baseUrl = QUrl(settings.value(QStringLiteral("assistant/url"), kDefaultUrl).toString());
    m_model = settings.value(QStringLiteral("assistant/model"), kDefaultModel).toString();
    m_status = tr("Checking the local AI…");
    refreshAvailability();
}

void AssistantController::setModel(const QString &model)
{
    if (model.isEmpty() || model == m_model)
        return;
    if (!usingClaude())
        unloadModel();
    m_claudeSession.clear();
    m_model = model;
    QSettings settings;
    settings.setValue(QStringLiteral("assistant/model"), m_model);
    emit modelChanged();
    refreshAvailability();
}

bool AssistantController::needsConfirmation(const QString &op)
{
    static const QSet<QString> ops = {
        QStringLiteral("remove_asset"), QStringLiteral("replace_asset"), QStringLiteral("relink_media"),
        QStringLiteral("export_asset_image"), QStringLiteral("save_project"), QStringLiteral("load_project"),
        QStringLiteral("new_project"), QStringLiteral("package_project"), QStringLiteral("export_video"),
        QStringLiteral("export_with_preset"), QStringLiteral("export_selected_clips"),
        QStringLiteral("restore_snapshot"), QStringLiteral("undo_to"), QStringLiteral("market_download"),
        QStringLiteral("install_addon"), QStringLiteral("set_theme"), QStringLiteral("set_shortcut"),
        QStringLiteral("reset_shortcuts"), QStringLiteral("set_beat_layers"),
        QStringLiteral("delete_user_text_preset"), QStringLiteral("delete_text_animation_preset"),
        QStringLiteral("export_user_text_preset"), QStringLiteral("export_text_animation_preset"),
        QStringLiteral("import_user_text_preset"), QStringLiteral("import_text_animation_preset"),
        QStringLiteral("remove_track"),
    };
    return ops.contains(op);
}

// --- Tools -------------------------------------------------------------------------------

QJsonObject AssistantController::callTool(const QString &name, const QJsonObject &args)
{
    drift::mcp::McpServer *server = m_controller ? m_controller->mcpServer() : nullptr;
    if (!server)
        return {};
    const QJsonObject request{{QStringLiteral("jsonrpc"), QStringLiteral("2.0")},
                              {QStringLiteral("id"), 1},
                              {QStringLiteral("method"), QStringLiteral("tools/call")},
                              {QStringLiteral("params"), QJsonObject{{QStringLiteral("name"), name},
                                                                     {QStringLiteral("arguments"), args}}}};
    const QJsonObject response = server->handleRpc(QString(), request).toObject();
    if (response.contains(QStringLiteral("error")))
        return QJsonObject{{QStringLiteral("content"),
                            QJsonArray{QJsonObject{{QStringLiteral("type"), QStringLiteral("text")},
                                                   {QStringLiteral("text"),
                                                    compactJson(response.value(QStringLiteral("error")))}}}}};
    return response.value(QStringLiteral("result")).toObject();
}

QString AssistantController::toolText(const QJsonObject &result) const
{
    QStringList parts;
    for (const QJsonValue &item : result.value(QStringLiteral("content")).toArray()) {
        const QJsonObject block = item.toObject();
        if (block.value(QStringLiteral("type")).toString() == QLatin1String("text"))
            parts.append(block.value(QStringLiteral("text")).toString());
    }
    return parts.join(QLatin1Char('\n'));
}

QJsonArray AssistantController::toolDefinitions()
{
    if (!m_tools.isEmpty())
        return m_tools;
    for (const QJsonValue &value : drift::mcp::toolsForEndpoint(QString())) {
        const QJsonObject tool = value.toObject();
        const QString name = tool.value(QStringLiteral("name")).toString();
        if (!kModelTools.contains(name))
            continue;
        QJsonObject parameters = tool.value(QStringLiteral("inputSchema")).toObject();
        if (parameters.isEmpty())
            parameters = QJsonObject{{QStringLiteral("type"), QStringLiteral("object")},
                                     {QStringLiteral("properties"), QJsonObject{}}};
        m_tools.append(QJsonObject{
            {QStringLiteral("type"), QStringLiteral("function")},
            {QStringLiteral("function"),
             QJsonObject{{QStringLiteral("name"), name},
                         {QStringLiteral("description"), tool.value(QStringLiteral("description")).toString()},
                         {QStringLiteral("parameters"), parameters}}}});
    }
    return m_tools;
}

QString AssistantController::systemPrompt()
{
    if (m_instructions.isEmpty() && m_controller && m_controller->mcpServer()) {
        const QJsonObject init{{QStringLiteral("jsonrpc"), QStringLiteral("2.0")},
                               {QStringLiteral("id"), 1},
                               {QStringLiteral("method"), QStringLiteral("initialize")},
                               {QStringLiteral("params"), QJsonObject{}}};
        m_instructions = m_controller->mcpServer()
                             ->handleRpc(QString(), init)
                             .toObject()
                             .value(QStringLiteral("result"))
                             .toObject()
                             .value(QStringLiteral("instructions"))
                             .toString();
    }
    const QString summary = toolText(callTool(QStringLiteral("inspect"),
                                              QJsonObject{{QStringLiteral("clips"), true}}))
                                .left(kProjectSummaryLimit);
    return QStringLiteral(
               "You are the assistant inside the Drift video editor, working on the project the user has "
               "open. Do what the user asks by calling the tools; never ask for permission and never ask "
               "questions you can answer with inspect. Work on one part of the request at a time: one apply "
               "with a single op, read its result, then the next part. The common ops and their exact "
               "arguments are listed below (* = required); for anything else use search({q, schema:true}) "
               "with one plain English keyword. Read every result: if it has "
               "\"ok\":false or lists \"ignored\" arguments, the edit did not happen as intended, so look "
               "up the right argument names with search and do it again. Use clip uuids from "
               "inspect({clips:true}), never asset ids. For a title at a given time use add_text with at, "
               "duration and new_track:true. To remove a stretch of time (\"delete up to 2 s\", \"cut 10 to 15\") "
               "use one cut_time_range({start, end}) rather than split and delete. Do each part exactly once, "
               "then stop. When you are done, reply in the user's language "
               "in one or two short sentences saying what you changed. Only claim what a result "
               "confirmed; if something failed, say so plainly.\n\nCommon ops:\n%3\n\nDrift rules: %1\n\n"
               "Current project:\n%2")
        .arg(m_instructions, summary, cheatSheet())
        + (m_controller && m_controller->magneticMainTrack()
               ? QStringLiteral("\n\nThe main track magnet is ON: on the bottom video track, deleting or "
                                "trimming a clip closes the gap, so the clips after it move left. After a "
                                "removal, times of later clips change; do not delete again because something "
                                "now starts earlier.")
               : QString());
}

QString AssistantController::cheatSheet()
{
    if (!m_cheatSheet.isEmpty())
        return m_cheatSheet;
    QJsonArray ops;
    for (const QString &op : kCommonOps)
        ops.append(op);
    const QJsonObject payload =
        QJsonDocument::fromJson(toolText(callTool(QStringLiteral("toolbox"), QJsonObject{{QStringLiteral("ops"), ops}}))
                                    .toUtf8())
            .object();
    QStringList lines;
    for (const QJsonValue &value : payload.value(QStringLiteral("tools")).toArray()) {
        const QJsonObject tool = value.toObject();
        const QJsonObject schema = tool.value(QStringLiteral("inputSchema")).toObject();
        QSet<QString> required;
        for (const QJsonValue &r : schema.value(QStringLiteral("required")).toArray())
            required.insert(r.toString());
        QStringList args;
        const QJsonObject props = schema.value(QStringLiteral("properties")).toObject();
        for (auto it = props.begin(); it != props.end(); ++it) {
            const QJsonValue type = it.value().toObject().value(QStringLiteral("type"));
            args.append(QStringLiteral("%1%2:%3")
                            .arg(it.key(), required.contains(it.key()) ? QStringLiteral("*") : QString(),
                                 type.isString() ? type.toString() : QStringLiteral("any")));
        }
        QString when = tool.value(QStringLiteral("description")).toString();
        when.remove(QStringLiteral("When: "));
        when = when.section(QStringLiteral(". "), 0, 0);
        lines.append(QStringLiteral("%1(%2) — %3")
                         .arg(tool.value(QStringLiteral("name")).toString(), args.join(QStringLiteral(", ")), when));
    }
    m_cheatSheet = lines.join(QLatin1Char('\n'));
    return m_cheatSheet;
}

void AssistantController::recordOutcome(const QJsonObject &args, const QString &result)
{
    const QJsonObject reply = QJsonDocument::fromJson(result.toUtf8()).object();
    const auto mark = [this](const QString &op, bool worked) {
        if (op.isEmpty())
            return;
        if (!m_outcomes.contains(op))
            m_outcomeOrder.append(op);
        m_outcomes.insert(op, worked);
    };
    for (const QJsonValue &value : reply.value(QStringLiteral("done")).toArray()) {
        const QJsonObject done = value.toObject();
        const QJsonObject r = done.value(QStringLiteral("result")).toObject();
        // A clip asked for at one time and put at another (the spot was taken) did not do what
        // was asked either.
        const bool moved = r.contains(QStringLiteral("requested")) && r.contains(QStringLiteral("placed"))
                           && qAbs(r.value(QStringLiteral("requested")).toDouble()
                                   - r.value(QStringLiteral("placed")).toDouble()) > 0.001;
        mark(done.value(QStringLiteral("tool")).toString(), r.value(QStringLiteral("ok")).toBool(true) && !moved);
    }
    if (reply.value(QStringLiteral("ok")).toBool(true) == false) {
        QString failed = reply.value(QStringLiteral("tool")).toString();
        if (failed.isEmpty()) {
            const QJsonArray ops = args.value(QStringLiteral("ops")).toArray();
            if (!ops.isEmpty())
                failed = ops.first().toObject().value(QStringLiteral("tool")).toString();
        }
        mark(failed, false);
    }
}

int AssistantController::historyIndex()
{
    const QJsonDocument doc = QJsonDocument::fromJson(
        toolText(callTool(QStringLiteral("list_history"), QJsonObject{{QStringLiteral("limit"), 1}})).toUtf8());
    return doc.object().value(QStringLiteral("total")).toInt(0) - 1;
}

QString AssistantController::describeCall(const QString &name, const QJsonObject &args) const
{
    if (name != QLatin1String("apply"))
        return name;
    QStringList ops;
    for (const QJsonValue &op : args.value(QStringLiteral("ops")).toArray())
        ops.append(op.toObject().value(QStringLiteral("tool")).toString());
    return ops.join(QStringLiteral(", "));
}

// --- Conversation ------------------------------------------------------------------------

void AssistantController::send(const QString &text)
{
    const QString request = text.trimmed();
    if (request.isEmpty() || m_busy)
        return;
    if (!m_available)
        refreshAvailability();
    if (usingClaude()) {
        sendViaClaude(request);
        return;
    }
    appendMessage(QStringLiteral("user"), request);
    m_turnMessageIndex = m_messages.size() - 1;
    m_turnHistoryIndex = historyIndex();
    m_turn = QJsonArray{QJsonObject{{QStringLiteral("role"), QStringLiteral("user")},
                                    {QStringLiteral("content"), request}}};
    m_steps = 0;
    m_emptyReplies = 0;
    m_outcomes.clear();
    m_outcomeOrder.clear();
    setBusy(true);
    requestNextStep();
}

void AssistantController::requestNextStep()
{
    if (!m_busy)
        return;
    if (++m_steps > kMaxStepsPerRequest) {
        finishTurn(tr("I stopped: this request needed too many steps. Try asking for one thing at a time."),
                   true);
        return;
    }

    QJsonArray messages{QJsonObject{{QStringLiteral("role"), QStringLiteral("system")},
                                    {QStringLiteral("content"), systemPrompt()}}};
    for (const QJsonValue &message : m_history)
        messages.append(message);
    for (const QJsonValue &message : m_turn)
        messages.append(message);

    const QJsonObject body{
        {QStringLiteral("model"), m_model},
        {QStringLiteral("stream"), false},
        {QStringLiteral("think"), false},
        {QStringLiteral("keep_alive"), QStringLiteral("10m")},
        {QStringLiteral("messages"), messages},
        {QStringLiteral("tools"), toolDefinitions()},
        {QStringLiteral("options"),
         QJsonObject{{QStringLiteral("num_ctx"), 16384}, {QStringLiteral("temperature"), 0}}}};

    QNetworkRequest request(m_baseUrl.resolved(QUrl(QStringLiteral("/api/chat"))));
    request.setHeader(QNetworkRequest::ContentTypeHeader, QStringLiteral("application/json"));
    request.setTransferTimeout(kRequestTimeoutMs);
    m_reply = m_net->post(request, QJsonDocument(body).toJson(QJsonDocument::Compact));
    QNetworkReply *reply = m_reply;
    connect(reply, &QNetworkReply::finished, this, [this, reply] { handleReply(reply); });
}

void AssistantController::handleReply(QNetworkReply *reply)
{
    reply->deleteLater();
    if (reply != m_reply || !m_busy)
        return; // stopped, or a stale reply
    m_reply = nullptr;

    if (reply->error() != QNetworkReply::NoError) {
        if (reply->error() == QNetworkReply::OperationCanceledError)
            return;
        const QByteArray payload = reply->readAll();
        const QString detail = QJsonDocument::fromJson(payload).object().value(QStringLiteral("error")).toString();
        m_available = reply->error() != QNetworkReply::ConnectionRefusedError;
        m_status = m_available ? tr("The local AI answered with an error.")
                               : tr("Ollama is not answering at %1. Open Ollama and try again.")
                                     .arg(m_baseUrl.toString());
        emit availabilityChanged();
        finishTurn(detail.isEmpty() ? m_status : tr("The local AI failed: %1").arg(detail), true);
        return;
    }

    const QJsonObject message =
        QJsonDocument::fromJson(reply->readAll()).object().value(QStringLiteral("message")).toObject();
    const QJsonArray calls = message.value(QStringLiteral("tool_calls")).toArray();
    if (calls.isEmpty() && message.value(QStringLiteral("content")).toString().trimmed().isEmpty()
        && m_emptyReplies < 2) {
        // Seen with qwen3 after a search: an empty turn, usually a tool call the server could not
        // parse. Asking again for one small call gets it moving.
        ++m_emptyReplies;
        m_turn.append(QJsonObject{{QStringLiteral("role"), QStringLiteral("user")},
                                  {QStringLiteral("content"),
                                   QStringLiteral("Continue: make the next tool call now (one apply with one op), "
                                                  "or answer if everything is done.")}});
        QTimer::singleShot(0, this, &AssistantController::requestNextStep);
        return;
    }
    if (calls.isEmpty()) {
        QString content = message.value(QStringLiteral("content")).toString().trimmed();
        if (content.isEmpty())
            content = tr("Done.");
        finishTurn(content);
        return;
    }
    m_turn.append(message);
    runToolCalls(calls, 0);
}

void AssistantController::runToolCalls(const QJsonArray &calls, int from)
{
    for (int i = from; i < calls.size(); ++i) {
        if (!m_busy)
            return;
        const QJsonObject function = calls.at(i).toObject().value(QStringLiteral("function")).toObject();
        const QString name = function.value(QStringLiteral("name")).toString();
        QJsonObject args = function.value(QStringLiteral("arguments")).toObject();
        if (function.value(QStringLiteral("arguments")).isString())
            args = QJsonDocument::fromJson(function.value(QStringLiteral("arguments")).toString().toUtf8()).object();

        if (name == QLatin1String("apply")) {
            QStringList sensitive;
            for (const QJsonValue &op : args.value(QStringLiteral("ops")).toArray()) {
                const QString tool = op.toObject().value(QStringLiteral("tool")).toString();
                if (needsConfirmation(tool))
                    sensitive.append(tool);
            }
            if (!sensitive.isEmpty() && m_pendingCall.isEmpty()) {
                m_pendingCalls = calls;
                m_pendingFrom = i;
                m_pendingCall = QJsonObject{{QStringLiteral("name"), name}, {QStringLiteral("arguments"), args}};
                m_confirmationText = tr("The assistant wants to run %1. This touches files, settings or "
                                        "downloads rather than just the timeline. Allow it?")
                                         .arg(sensitive.join(QStringLiteral(", ")));
                emit confirmationChanged();
                return;
            }
        }

        QString text = kModelTools.contains(name)
                           ? toolText(callTool(name, args))
                           : QStringLiteral("{\"ok\":false,\"error\":\"unknown_tool\",\"detail\":\"Only search, "
                                            "toolbox, inspect and apply are available.\"}");
        const bool failed = text.contains(QLatin1String("\"ok\":false"));
        if (text.contains(QLatin1String("\"ignored\"")))
            text += QStringLiteral("\n\nWARNING: some arguments were ignored because their names are wrong, "
                                   "so this edit did not do what was asked. Check the exact names with "
                                   "search({q, schema:true}) and apply again.");
        if (name == QLatin1String("apply")) {
            recordOutcome(args, text);
            appendMessage(QStringLiteral("action"), describeCall(name, args),
                          QVariantMap{{QStringLiteral("failed"), failed}});
        }
        m_turn.append(QJsonObject{{QStringLiteral("role"), QStringLiteral("tool")},
                                  {QStringLiteral("tool_name"), name},
                                  {QStringLiteral("content"), text.left(kToolResultLimit)}});
    }
    // Back to the event loop first, so the panel paints the actions before the next wait.
    QTimer::singleShot(0, this, &AssistantController::requestNextStep);
}

void AssistantController::confirm(bool allow)
{
    if (m_pendingCall.isEmpty())
        return;
    const QJsonArray calls = m_pendingCalls;
    const int index = m_pendingFrom;
    const QString name = m_pendingCall.value(QStringLiteral("name")).toString();
    const QJsonObject args = m_pendingCall.value(QStringLiteral("arguments")).toObject();
    m_pendingCalls = {};
    m_pendingCall = {};
    m_confirmationText.clear();
    emit confirmationChanged();

    QString text;
    if (allow) {
        text = toolText(callTool(name, args));
        recordOutcome(args, text);
        appendMessage(QStringLiteral("action"), describeCall(name, args),
                      QVariantMap{{QStringLiteral("failed"), text.contains(QLatin1String("\"ok\":false"))}});
    } else {
        text = QStringLiteral("{\"ok\":false,\"error\":\"denied_by_user\",\"detail\":\"The user declined these "
                              "operations. Do not try them again; tell the user what you did instead.\"}");
        appendMessage(QStringLiteral("action"), describeCall(name, args) + QStringLiteral(" — ") + tr("declined"),
                      QVariantMap{{QStringLiteral("failed"), true}});
    }
    m_turn.append(QJsonObject{{QStringLiteral("role"), QStringLiteral("tool")},
                              {QStringLiteral("tool_name"), name},
                              {QStringLiteral("content"), text.left(kToolResultLimit)}});
    runToolCalls(calls, index + 1);
}

void AssistantController::finishTurn(const QString &reply, bool failed)
{
    if (!m_pendingCall.isEmpty()) {
        m_pendingCalls = {};
        m_pendingCall = {};
        m_confirmationText.clear();
        emit confirmationChanged();
    }
    QStringList notDone;
    for (const QString &op : m_outcomeOrder) {
        if (!m_outcomes.value(op))
            notDone.append(op);
    }
    if (!notDone.isEmpty() && !failed) {
        appendMessage(QStringLiteral("warning"),
                      tr("Check the result: %1 did not work as asked.").arg(notDone.join(QStringLiteral(", "))));
    }
    const bool changed = m_turnHistoryIndex >= 0 && historyIndex() != m_turnHistoryIndex;
    appendMessage(QStringLiteral("assistant"), reply,
                  QVariantMap{{QStringLiteral("failed"), failed},
                              {QStringLiteral("changed"), changed},
                              {QStringLiteral("undoIndex"), m_turnHistoryIndex}});
    if (!m_turn.isEmpty()) {
        m_history.append(m_turn.first());
        m_history.append(QJsonObject{{QStringLiteral("role"), QStringLiteral("assistant")},
                                     {QStringLiteral("content"), reply}});
    }
    m_turn = {};
    if (m_controller && m_controller->mcpServer())
        m_controller->mcpServer()->setBlockedOps({});
    setBusy(false);
}

void AssistantController::stop()
{
    if (!m_busy)
        return;
    if (usingClaude()) {
        QNetworkRequest request(kPonteUrl.resolved(QUrl(QStringLiteral("/stop"))));
        request.setHeader(QNetworkRequest::ContentTypeHeader, QStringLiteral("application/json"));
        request.setRawHeader("X-Ponte-Token", ponteToken());
        QNetworkReply *stopReply = m_net->post(request, QByteArrayLiteral("{}"));
        connect(stopReply, &QNetworkReply::finished, stopReply, &QObject::deleteLater);
    }
    if (m_reply) {
        QNetworkReply *reply = m_reply;
        m_reply = nullptr;
        reply->abort();
    }
    finishTurn(tr("Stopped."), true);
}

void AssistantController::clear()
{
    stop();
    m_messages.clear();
    m_history = {};
    m_claudeSession.clear();
    emit messagesChanged();
    if (!usingClaude())
        unloadModel();
}

void AssistantController::undoRequest(int messageIndex)
{
    if (m_busy || messageIndex < 0 || messageIndex >= m_messages.size())
        return;
    QVariantMap message = m_messages.at(messageIndex).toMap();
    const int index = message.value(QStringLiteral("undoIndex"), -1).toInt();
    if (index < 0 || !message.value(QStringLiteral("changed")).toBool())
        return;
    const QString text = toolText(callTool(QStringLiteral("undo_to"), QJsonObject{{QStringLiteral("index"), index}}));
    message.insert(QStringLiteral("changed"), false);
    message.insert(QStringLiteral("undone"), !text.contains(QLatin1String("\"ok\":false")));
    m_messages[messageIndex] = message;
    emit messagesChanged();
}

// --- Plumbing ----------------------------------------------------------------------------

void AssistantController::refreshAvailability()
{
    QNetworkRequest request(m_baseUrl.resolved(QUrl(QStringLiteral("/api/tags"))));
    request.setTransferTimeout(4000);
    QNetworkReply *reply = m_net->get(request);
    connect(reply, &QNetworkReply::finished, this, [this, reply] {
        reply->deleteLater();
        m_installedModels.clear();
        if (reply->error() != QNetworkReply::NoError) {
            m_installedModels.append(claudeModelName());
            if (usingClaude()) {
                checkPonte();
                return;
            }
            m_available = false;
            m_status = tr("Ollama is not answering at %1. Open Ollama and try again.").arg(m_baseUrl.toString());
            emit availabilityChanged();
            return;
        }
        for (const QJsonValue &value :
             QJsonDocument::fromJson(reply->readAll()).object().value(QStringLiteral("models")).toArray()) {
            const QJsonObject info = value.toObject();
            const QString family = info.value(QStringLiteral("details")).toObject().value(QStringLiteral("family")).toString();
            if (family == QLatin1String("bert") || family.contains(QLatin1String("embed")))
                continue; // embedding models cannot chat
            m_installedModels.append(info.value(QStringLiteral("name")).toString());
        }
        m_installedModels.append(claudeModelName());
        if (usingClaude()) {
            checkPonte();
            return;
        }
        m_available = m_installedModels.contains(m_model);
        m_status = m_available ? tr("Local AI ready: %1").arg(m_model)
                               : tr("The model %1 is not installed in Ollama. Pick another one.").arg(m_model);
        emit availabilityChanged();
    });
}

void AssistantController::unloadModel()
{
    // Hand the graphics memory back to preview and export.
    QNetworkRequest request(m_baseUrl.resolved(QUrl(QStringLiteral("/api/generate"))));
    request.setHeader(QNetworkRequest::ContentTypeHeader, QStringLiteral("application/json"));
    request.setTransferTimeout(4000);
    const QJsonObject body{{QStringLiteral("model"), m_model}, {QStringLiteral("keep_alive"), 0}};
    QNetworkReply *reply = m_net->post(request, QJsonDocument(body).toJson(QJsonDocument::Compact));
    connect(reply, &QNetworkReply::finished, reply, &QObject::deleteLater);
}

void AssistantController::appendMessage(const QString &role, const QString &text, const QVariantMap &extra)
{
    QVariantMap message = extra;
    message.insert(QStringLiteral("role"), role);
    message.insert(QStringLiteral("text"), text);
    m_messages.append(message);
    emit messagesChanged();
}

void AssistantController::setBusy(bool busy)
{
    if (m_busy == busy)
        return;
    m_busy = busy;
    emit busyChanged();
}

// --- Claude through the bridge -----------------------------------------------------------

QByteArray AssistantController::ponteToken() const
{
    QFile file(QStandardPaths::writableLocation(QStandardPaths::GenericConfigLocation)
               + QStringLiteral("/drift-claude-ponte.token"));
    if (!file.open(QIODevice::ReadOnly))
        return {};
    return file.readAll().trimmed();
}

void AssistantController::checkPonte()
{
    const QByteArray token = ponteToken();
    if (token.isEmpty()) {
        m_available = false;
        m_status = tr("The Claude bridge is not installed. See docs/13-ponte-claude.md in the project folder.");
        emit availabilityChanged();
        return;
    }
    QNetworkRequest request(kPonteUrl.resolved(QUrl(QStringLiteral("/status"))));
    request.setRawHeader("X-Ponte-Token", token);
    request.setTransferTimeout(30000);
    QNetworkReply *reply = m_net->get(request);
    connect(reply, &QNetworkReply::finished, this, [this, reply] {
        reply->deleteLater();
        if (reply->error() != QNetworkReply::NoError) {
            m_available = false;
            m_status = tr("The Claude bridge is not running. Start it with: systemctl --user start drift-claude-ponte");
        } else if (!QJsonDocument::fromJson(reply->readAll()).object().value(QStringLiteral("loggedIn")).toBool()) {
            m_available = false;
            m_status = tr("Claude Code is not signed in. Run in a terminal: claude auth login");
        } else {
            m_available = true;
            m_status = tr("Claude ready, through your Claude account");
        }
        emit availabilityChanged();
    });
}

void AssistantController::sendViaClaude(const QString &text)
{
    drift::mcp::McpServer *server = m_controller ? m_controller->mcpServer() : nullptr;
    if (!server) {
        appendMessage(QStringLiteral("assistant"), tr("Agent access is not available in this build."),
                      QVariantMap{{QStringLiteral("failed"), true}});
        return;
    }
    // Claude reaches the project through Drift's own agent access, so it has to be on.
    if (!server->running() && !server->start()) {
        appendMessage(QStringLiteral("assistant"), tr("Could not turn on agent access: %1").arg(server->error()),
                      QVariantMap{{QStringLiteral("failed"), true}});
        return;
    }
    server->setBlockedOps(claudeBlockedOps());

    appendMessage(QStringLiteral("user"), text);
    m_turnMessageIndex = m_messages.size() - 1;
    m_turnHistoryIndex = historyIndex();
    m_turn = QJsonArray{QJsonObject{{QStringLiteral("role"), QStringLiteral("user")},
                                    {QStringLiteral("content"), text}}};
    m_outcomes.clear();
    m_outcomeOrder.clear();
    m_claudeBuffer.clear();
    m_claudeCallArgs.clear();
    m_claudeCallMessage.clear();
    m_claudeAnswered = false;
    setBusy(true);

    QJsonObject body{{QStringLiteral("prompt"), text},
                     {QStringLiteral("mcpUrl"), server->url()},
                     {QStringLiteral("mcpToken"), server->token()}};
    if (!m_claudeSession.isEmpty())
        body.insert(QStringLiteral("sessionId"), m_claudeSession);
    QNetworkRequest request(kPonteUrl.resolved(QUrl(QStringLiteral("/run"))));
    request.setHeader(QNetworkRequest::ContentTypeHeader, QStringLiteral("application/json"));
    request.setRawHeader("X-Ponte-Token", ponteToken());
    request.setTransferTimeout(0);
    m_reply = m_net->post(request, QJsonDocument(body).toJson(QJsonDocument::Compact));
    QNetworkReply *reply = m_reply;
    connect(reply, &QNetworkReply::readyRead, this, &AssistantController::readClaudeStream);
    connect(reply, &QNetworkReply::finished, this, [this, reply] { finishClaude(reply); });
}

void AssistantController::readClaudeStream()
{
    if (!m_reply)
        return;
    m_claudeBuffer += m_reply->readAll();
    int newline;
    while ((newline = m_claudeBuffer.indexOf('\n')) >= 0) {
        const QByteArray line = m_claudeBuffer.left(newline).trimmed();
        m_claudeBuffer.remove(0, newline + 1);
        if (!line.isEmpty())
            handleClaudeEvent(QJsonDocument::fromJson(line).object());
    }
}

void AssistantController::handleClaudeEvent(const QJsonObject &event)
{
    const QString type = event.value(QStringLiteral("type")).toString();
    if (event.contains(QStringLiteral("session_id")))
        m_claudeSession = event.value(QStringLiteral("session_id")).toString();

    if (type == QLatin1String("assistant")) {
        for (const QJsonValue &value :
             event.value(QStringLiteral("message")).toObject().value(QStringLiteral("content")).toArray()) {
            const QJsonObject block = value.toObject();
            if (block.value(QStringLiteral("type")).toString() != QLatin1String("tool_use"))
                continue;
            QString name = block.value(QStringLiteral("name")).toString();
            name.remove(QStringLiteral("mcp__drift__"));
            const QJsonObject input = block.value(QStringLiteral("input")).toObject();
            // Reading tools are the model looking around; only edits get a line in the panel.
            if (kModelTools.contains(name) && name != QLatin1String("apply"))
                continue;
            if (QSet<QString>{QStringLiteral("catalog"), QStringLiteral("capture"), QStringLiteral("frames"),
                              QStringLiteral("activity")}
                    .contains(name))
                continue;
            const QJsonObject asApply = name == QLatin1String("apply")
                                            ? input
                                            : QJsonObject{{QStringLiteral("ops"),
                                                           QJsonArray{QJsonObject{{QStringLiteral("tool"), name},
                                                                                  {QStringLiteral("args"), input}}}}};
            const QString id = block.value(QStringLiteral("id")).toString();
            m_claudeCallArgs.insert(id, asApply);
            appendMessage(QStringLiteral("action"), describeCall(QStringLiteral("apply"), asApply),
                          QVariantMap{{QStringLiteral("failed"), false}});
            m_claudeCallMessage.insert(id, m_messages.size() - 1);
        }
        return;
    }

    if (type == QLatin1String("user")) {
        for (const QJsonValue &value :
             event.value(QStringLiteral("message")).toObject().value(QStringLiteral("content")).toArray()) {
            const QJsonObject block = value.toObject();
            const QString id = block.value(QStringLiteral("tool_use_id")).toString();
            if (block.value(QStringLiteral("type")).toString() != QLatin1String("tool_result")
                || !m_claudeCallArgs.contains(id))
                continue;
            QString text;
            const QJsonValue content = block.value(QStringLiteral("content"));
            if (content.isString()) {
                text = content.toString();
            } else {
                for (const QJsonValue &part : content.toArray())
                    text += part.toObject().value(QStringLiteral("text")).toString();
            }
            const QJsonObject args = m_claudeCallArgs.value(id);
            QJsonObject reply = QJsonDocument::fromJson(text.toUtf8()).object();
            if (!reply.contains(QStringLiteral("done"))) {
                // A toolbox op called directly answers with its own result; shape it like apply.
                const QString op = args.value(QStringLiteral("ops")).toArray().first().toObject()
                                       .value(QStringLiteral("tool")).toString();
                reply = QJsonObject{{QStringLiteral("ok"), reply.value(QStringLiteral("ok")).toBool(true)},
                                    {QStringLiteral("tool"), op},
                                    {QStringLiteral("done"), reply.value(QStringLiteral("ok")).toBool(true)
                                                                 ? QJsonArray{QJsonObject{{QStringLiteral("tool"), op},
                                                                                          {QStringLiteral("result"), reply}}}
                                                                 : QJsonArray{}}};
            }
            const QString shaped = QString::fromUtf8(QJsonDocument(reply).toJson(QJsonDocument::Compact));
            recordOutcome(args, shaped);
            const bool failed = block.value(QStringLiteral("is_error")).toBool()
                                || shaped.contains(QLatin1String("\"ok\":false"));
            const int index = m_claudeCallMessage.value(id, -1);
            if (failed && index >= 0 && index < m_messages.size()) {
                QVariantMap message = m_messages.at(index).toMap();
                message.insert(QStringLiteral("failed"), true);
                m_messages[index] = message;
                emit messagesChanged();
            }
        }
        return;
    }

    if (type == QLatin1String("result")) {
        m_claudeAnswered = true;
        QString text = event.value(QStringLiteral("result")).toString().trimmed();
        const bool failed = event.value(QStringLiteral("is_error")).toBool();
        if (text.isEmpty())
            text = failed ? tr("Claude could not finish this request.") : tr("Done.");
        finishTurn(text, failed);
        return;
    }

    if (type == QLatin1String("ponte_error")) {
        m_claudeAnswered = true;
        finishTurn(tr("Claude Code stopped with an error: %1")
                       .arg(event.value(QStringLiteral("stderr")).toString().trimmed().right(300)),
                   true);
    }
}

void AssistantController::finishClaude(QNetworkReply *reply)
{
    reply->deleteLater();
    if (reply != m_reply)
        return;
    readClaudeStream();
    m_reply = nullptr;
    if (!m_busy || m_claudeAnswered)
        return;
    if (reply->error() == QNetworkReply::OperationCanceledError)
        return;
    const QString detail = reply->error() == QNetworkReply::NoError ? tr("the bridge closed without an answer")
                                                                    : reply->errorString();
    finishTurn(tr("Could not reach Claude: %1").arg(detail), true);
}
