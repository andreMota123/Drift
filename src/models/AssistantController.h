#pragma once

#include <QHash>
#include <QJsonArray>
#include <QJsonObject>
#include <QObject>
#include <QPointer>
#include <QString>
#include <QStringList>
#include <QUrl>
#include <QVariantList>

class AppController;
class QNetworkAccessManager;
class QNetworkReply;

// In-editor assistant: a chat panel backed by a local Ollama model that edits the open project
// through the same tools the MCP server gives external agents (search, toolbox, inspect, apply),
// called in-process. Nothing leaves the machine; when Ollama is not running the panel says so
// and the rest of the editor is unaffected.
class AssistantController : public QObject
{
    Q_OBJECT
    Q_PROPERTY(QVariantList messages READ messages NOTIFY messagesChanged)
    Q_PROPERTY(bool busy READ busy NOTIFY busyChanged)
    Q_PROPERTY(bool available READ available NOTIFY availabilityChanged)
    Q_PROPERTY(QString status READ status NOTIFY availabilityChanged)
    Q_PROPERTY(QString model READ model WRITE setModel NOTIFY modelChanged)
    Q_PROPERTY(QStringList installedModels READ installedModels NOTIFY availabilityChanged)
    Q_PROPERTY(bool awaitingConfirmation READ awaitingConfirmation NOTIFY confirmationChanged)
    Q_PROPERTY(QString confirmationText READ confirmationText NOTIFY confirmationChanged)

public:
    explicit AssistantController(AppController *controller, QObject *parent = nullptr);

    QVariantList messages() const { return m_messages; }
    bool busy() const { return m_busy; }
    bool available() const { return m_available; }
    QString status() const { return m_status; }
    QString model() const { return m_model; }
    void setModel(const QString &model);
    QStringList installedModels() const { return m_installedModels; }
    bool awaitingConfirmation() const { return !m_pendingCall.isEmpty(); }
    QString confirmationText() const { return m_confirmationText; }

    Q_INVOKABLE void send(const QString &text);
    Q_INVOKABLE void stop();
    Q_INVOKABLE void clear();
    Q_INVOKABLE void refreshAvailability();
    Q_INVOKABLE void confirm(bool allow);
    // Rolls the project back to where it was before the request at `messageIndex`.
    Q_INVOKABLE void undoRequest(int messageIndex);

    // Ops that touch files, settings or quota rather than the timeline. The assistant may still
    // run them, but only after the user says yes in the panel.
    static bool needsConfirmation(const QString &op);

signals:
    void messagesChanged();
    void busyChanged();
    void availabilityChanged();
    void modelChanged();
    void confirmationChanged();

private:
    QJsonObject callTool(const QString &name, const QJsonObject &args);
    QString toolText(const QJsonObject &result) const;
    QJsonArray toolDefinitions();
    QString systemPrompt();
    void requestNextStep();
    void handleReply(QNetworkReply *reply);
    void runToolCalls(const QJsonArray &calls, int from);
    void finishTurn(const QString &reply, bool failed = false);
    void appendMessage(const QString &role, const QString &text, const QVariantMap &extra = {});
    void setBusy(bool busy);
    int historyIndex();
    QString describeCall(const QString &name, const QJsonObject &args) const;
    QString cheatSheet();
    void recordOutcome(const QJsonObject &args, const QString &result);
    void unloadModel();

    AppController *m_controller = nullptr;
    QNetworkAccessManager *m_net = nullptr;
    QPointer<QNetworkReply> m_reply;
    QUrl m_baseUrl;
    QString m_model;
    QStringList m_installedModels;
    bool m_available = false;
    QString m_status;
    bool m_busy = false;
    QVariantList m_messages;

    // The conversation as the model sees it: past requests and answers only. Tool chatter of a
    // finished request is dropped, so a long session does not fill the context window.
    QJsonArray m_history;
    // The request in flight, including its tool calls and results.
    QJsonArray m_turn;
    QJsonArray m_tools;
    QString m_instructions;
    QString m_cheatSheet;
    int m_emptyReplies = 0;
    // Per op of the request in flight, whether its last run worked. Read when the request ends,
    // so the panel reports a failure even when the model's own summary does not.
    QHash<QString, bool> m_outcomes;
    QStringList m_outcomeOrder;
    int m_steps = 0;
    int m_turnHistoryIndex = -1;
    int m_turnMessageIndex = -1;

    QJsonArray m_pendingCalls;
    int m_pendingFrom = 0;
    QJsonObject m_pendingCall;
    QString m_confirmationText;
};
