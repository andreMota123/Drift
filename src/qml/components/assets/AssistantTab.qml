import QtQuick
import QtQuick.Controls.Basic
import Drift
import ".."

// Assistant tab: a chat with the local AI (Ollama) that edits the open project through the
// same tools external agents use. See models/AssistantController.h.
Item {
    id: root

    readonly property var messages: Assistant.messages

    onVisibleChanged: if (visible && !Assistant.available) Assistant.refreshAvailability()

    function sendDraft() {
        const text = input.text.trim()
        if (text.length === 0 || Assistant.busy)
            return
        Assistant.send(text)
        input.text = ""
    }

    Column {
        anchors.fill: parent
        spacing: 0

        // Status and model picker.
        Item {
            id: statusBar
            width: parent.width
            height: Theme.controlHeight + Theme.spacingMd * 2

            Row {
                anchors.left: parent.left
                anchors.leftMargin: Theme.pagePadding
                anchors.right: modelPicker.left
                anchors.rightMargin: Theme.spacingMd
                anchors.verticalCenter: parent.verticalCenter
                spacing: Theme.spacingSm

                Rectangle {
                    width: 8
                    height: 8
                    radius: 4
                    anchors.verticalCenter: parent.verticalCenter
                    color: Assistant.available ? Theme.constructive : Theme.warning
                }
                Text {
                    width: parent.width - 8 - Theme.spacingSm
                    anchors.verticalCenter: parent.verticalCenter
                    text: Assistant.available ? qsTr("Ready") : qsTr("Offline")

                    HoverHandler { id: statusHover }
                    ThemedToolTip {
                        visible: statusHover.hovered
                        text: Assistant.status
                    }
                    color: Theme.mutedForeground
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSizeXs
                    elide: Text.ElideRight
                }
            }

            ThemedComboBox {
                id: modelPicker
                anchors.right: clearButton.left
                anchors.rightMargin: Theme.spacingSm
                anchors.verticalCenter: parent.verticalCenter
                width: Math.min(180, root.width * 0.55)
                visible: Assistant.installedModels.length > 0
                enabled: !Assistant.busy
                model: Assistant.installedModels
                tooltip: qsTr("Model used by the assistant")
                currentIndex: Math.max(0, Assistant.installedModels.indexOf(Assistant.model))
                onActivated: function(index) { Assistant.model = Assistant.installedModels[index] }
            }

            IconButton {
                id: clearButton
                anchors.right: parent.right
                anchors.rightMargin: Theme.pagePadding
                anchors.verticalCenter: parent.verticalCenter
                glyph: Theme.icons.trash
                variant: "text"
                tooltip: qsTr("Clear the conversation and free the graphics memory")
                enabled: root.messages.length > 0
                onClicked: Assistant.clear()
            }
        }

        Rectangle {
            width: parent.width
            height: Theme.borderWidth
            color: Theme.panelBorder
        }

        Item {
            width: parent.width
            height: parent.height - statusBar.height - Theme.borderWidth - composer.height

            EmptyState {
                anchors.centerIn: parent
                width: Math.min(parent.width - Theme.pagePadding * 2, 320)
                visible: root.messages.length === 0
                glyph: Theme.icons.sparkles
                title: qsTr("Ask for an edit")
                hint: !Assistant.available ? Assistant.status : qsTr("For example: “cut at 12 seconds and delete up to 15”, “put the title ‘Natal 2026’ at the start for 3 seconds” or “lower the music to 40% and fade it out”. Everything runs on this computer.")
            }

            ListView {
                id: list
                anchors.fill: parent
                anchors.margins: Theme.pagePadding
                clip: true
                spacing: Theme.spacingMd
                model: root.messages
                visible: root.messages.length > 0
                boundsBehavior: Flickable.StopAtBounds
                ScrollBar.vertical: AppScrollBar { }
                onCountChanged: Qt.callLater(list.positionViewAtEnd)

                footer: Item {
                    width: list.width
                    height: Assistant.busy ? 28 : 0
                    visible: Assistant.busy
                    Row {
                        anchors.left: parent.left
                        anchors.bottom: parent.bottom
                        spacing: Theme.spacingSm
                        IconGlyph {
                            glyph: Theme.icons.spinner
                            spinning: true
                            iconSize: Theme.iconSizeMd
                            iconColor: Theme.mutedForeground
                            anchors.verticalCenter: parent.verticalCenter
                        }
                        Text {
                            text: Assistant.awaitingConfirmation ? qsTr("Waiting for your answer…")
                                                                 : qsTr("Working…")
                            color: Theme.mutedForeground
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fontSizeXs
                            anchors.verticalCenter: parent.verticalCenter
                        }
                    }
                }

                delegate: Item {
                    id: row
                    required property var modelData
                    required property int index
                    readonly property string role: modelData.role
                    width: list.width
                    readonly property bool isLine: role === "action" || role === "warning"
                    height: isLine ? actionRow.height : bubble.height

                    // Tool runs: one quiet line per batch of edits.
                    Row {
                        id: actionRow
                        visible: row.isLine
                        spacing: Theme.spacingSm
                        width: parent.width
                        IconGlyph {
                            glyph: row.role === "warning" ? Theme.icons.warning
                                 : (row.modelData.failed ? Theme.icons.x : Theme.icons.check)
                            iconSize: Theme.iconSizeSm
                            iconColor: row.role === "warning" ? Theme.warning
                                     : (row.modelData.failed ? Theme.destructive : Theme.accentOnPanel)
                            anchors.verticalCenter: parent.verticalCenter
                        }
                        Text {
                            width: parent.width - Theme.iconSizeSm - Theme.spacingSm
                            text: row.modelData.text
                            color: row.role === "warning" ? Theme.panelForeground : Theme.mutedForeground
                            font.family: row.role === "warning" ? Theme.fontFamily : Theme.monoFontFamily
                            font.pixelSize: Theme.fontSizeXs
                            wrapMode: row.role === "warning" ? Text.Wrap : Text.NoWrap
                            elide: row.role === "warning" ? Text.ElideNone : Text.ElideRight
                        }
                    }

                    Rectangle {
                        id: bubble
                        visible: !row.isLine
                        readonly property bool mine: row.role === "user"
                        anchors.right: mine ? parent.right : undefined
                        anchors.left: mine ? undefined : parent.left
                        width: Math.min(parent.width * 0.88, bubbleText.implicitWidth + Theme.spacingLg * 2)
                        height: bubbleColumn.implicitHeight + Theme.spacingMd * 2
                        radius: Theme.radiusMd
                        color: mine ? Theme.panelSecondaryBg
                                    : (row.modelData.failed ? Qt.rgba(Theme.destructive.r, Theme.destructive.g,
                                                                      Theme.destructive.b, 0.12)
                                                            : Theme.panelAccent)
                        border.width: mine ? Theme.borderWidth : 0
                        border.color: Theme.panelSecondaryBorder

                        Column {
                            id: bubbleColumn
                            anchors.left: parent.left
                            anchors.right: parent.right
                            anchors.top: parent.top
                            anchors.margins: Theme.spacingMd
                            anchors.leftMargin: Theme.spacingLg
                            anchors.rightMargin: Theme.spacingLg
                            spacing: Theme.spacingSm

                            Text {
                                id: bubbleText
                                width: Math.min(implicitWidth, list.width * 0.88 - Theme.spacingLg * 2)
                                text: row.modelData.text
                                wrapMode: Text.Wrap
                                textFormat: Text.PlainText
                                color: Theme.panelForeground
                                font.family: Theme.fontFamily
                                font.pixelSize: Theme.fontSizeSm
                            }

                            ThemedButton {
                                visible: row.role === "assistant" && row.modelData.changed === true
                                text: qsTr("Undo this request")
                                glyph: Theme.icons.undo
                                variant: "ghost"
                                enabled: !Assistant.busy
                                onClicked: Assistant.undoRequest(row.index)
                            }
                            Text {
                                visible: row.modelData.undone === true
                                text: qsTr("Undone.")
                                color: Theme.mutedForeground
                                font.family: Theme.fontFamily
                                font.pixelSize: Theme.fontSizeXs
                            }
                        }
                    }
                }
            }
        }

        // Composer: confirmation bar when the assistant asks, otherwise the text box.
        Rectangle {
            id: composer
            width: parent.width
            height: (Assistant.awaitingConfirmation ? confirmColumn.implicitHeight
                                                    : Math.min(140, Math.max(input.implicitHeight, Theme.controlHeight * 2)))
                    + Theme.spacingMd * 2 + Theme.borderWidth
            color: Theme.panelBackground

            Rectangle {
                width: parent.width
                height: Theme.borderWidth
                color: Theme.panelBorder
            }

            Column {
                id: confirmColumn
                visible: Assistant.awaitingConfirmation
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.top: parent.top
                anchors.margins: Theme.pagePadding
                anchors.topMargin: Theme.spacingMd + Theme.borderWidth
                spacing: Theme.spacingMd

                Text {
                    width: parent.width
                    text: Assistant.confirmationText
                    wrapMode: Text.Wrap
                    color: Theme.panelForeground
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSizeSm
                }
                Row {
                    spacing: Theme.spacingSm
                    ThemedButton {
                        text: qsTr("Allow")
                        variant: "primary"
                        onClicked: Assistant.confirm(true)
                    }
                    ThemedButton {
                        text: qsTr("Decline")
                        variant: "secondary"
                        onClicked: Assistant.confirm(false)
                    }
                }
            }

            Item {
                visible: !Assistant.awaitingConfirmation
                anchors.fill: parent
                anchors.margins: Theme.pagePadding
                anchors.topMargin: Theme.spacingMd + Theme.borderWidth
                anchors.bottomMargin: Theme.spacingMd

                ScrollView {
                    id: inputScroll
                    anchors.left: parent.left
                    anchors.right: sendButton.left
                    anchors.rightMargin: Theme.spacingSm
                    anchors.top: parent.top
                    anchors.bottom: parent.bottom

                    ThemedTextArea {
                        id: input
                        placeholderText: Assistant.available ? qsTr("What should I change?")
                                                             : qsTr("Not available right now: see the note above")
                        placeholderTextColor: Theme.mutedForeground
                        enabled: !Assistant.busy
                        Keys.onPressed: function(event) {
                            if ((event.key === Qt.Key_Return || event.key === Qt.Key_Enter)
                                    && !(event.modifiers & Qt.ShiftModifier)) {
                                root.sendDraft()
                                event.accepted = true
                            }
                        }
                    }
                }

                IconButton {
                    id: sendButton
                    anchors.right: parent.right
                    anchors.bottom: parent.bottom
                    glyph: Assistant.busy ? Theme.icons.square : Theme.icons.send
                    variant: "ghost"
                    active: !Assistant.busy && input.text.trim().length > 0
                    tooltip: Assistant.busy ? qsTr("Stop") : qsTr("Send (Enter)")
                    onClicked: Assistant.busy ? Assistant.stop() : root.sendDraft()
                }
            }
        }
    }
}
