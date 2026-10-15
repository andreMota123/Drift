import QtQuick
import QtQuick.Controls.Basic
import Drift

// "Shorts from this video": the local AI reads the captions and proposes self-contained
// moments; each one ticked becomes its own vertical project next to this one.
ThemedDialog {
    id: root

    readonly property var proposals: Shorts.proposals
    property var ticked: ({})
    property string doneFolder: ""
    // Read when the dialog opens: the captions can be generated while it is closed.
    property bool hasCaptions: false
    readonly property var counts: [3, 5, 8]
    readonly property var lengths: [30, 45, 60, 90]
    readonly property int tickedCount: {
        let n = 0
        for (let i = 0; i < proposals.length; ++i)
            if (ticked[i] !== false)
                ++n
        return n
    }

    title: qsTr("Shorts from this video")
    preferredWidth: Theme.dialogWidthLg
    acceptText: qsTr("Make %n short(s)", "", tickedCount)
    acceptEnabled: proposals.length > 0 && tickedCount > 0 && !Shorts.busy
    rejectText: Shorts.busy ? qsTr("Stop") : qsTr("Close")

    function openDialog() {
        doneFolder = ""
        hasCaptions = Shorts.hasTranscript()
        open()
    }

    function formatTime(seconds) {
        const s = Math.max(0, Math.floor(seconds))
        return Math.floor(s / 60) + ":" + String(s % 60).padStart(2, "0")
    }

    onProposalsChanged: ticked = ({})

    // Keep the dialog open while the shorts are made, so progress stays in view.
    onAccepted: {
        const chosen = []
        for (let i = 0; i < proposals.length; ++i)
            if (ticked[i] !== false)
                chosen.push(i)
        doneFolder = ""
        Shorts.createShorts(chosen)
        open()
    }
    onRejected: if (Shorts.busy) Shorts.cancel()

    Connections {
        target: Shorts
        function onFinished(ok, message, folder) {
            if (ok)
                Toasts.success(message)
            else
                Toasts.error(message)
            root.doneFolder = folder
        }
    }

    contentItem: Column {
        spacing: Theme.spacingLg
        width: parent ? parent.width : 600

        ThemedLabel {
            width: parent.width
            wrapMode: Text.Wrap
            color: Theme.mutedForeground
            text: root.hasCaptions
                  ? qsTr("The local AI reads the captions and picks moments that work on their own. Each one you keep becomes a vertical (9:16) project in a folder next to this one; this project is not changed.")
                  : qsTr("This project has no captions yet. Generate them first in the Captions tab: the AI picks the moments from what is said.")
        }

        Row {
            spacing: Theme.spacingMd
            enabled: !Shorts.busy && root.hasCaptions

            ThemedLabel { text: qsTr("How many"); anchors.verticalCenter: parent.verticalCenter }
            ThemedComboBox {
                id: countPicker
                width: 70
                model: root.counts
                currentIndex: 1
            }
            ThemedLabel { text: qsTr("Length"); anchors.verticalCenter: parent.verticalCenter }
            ThemedComboBox {
                id: lengthPicker
                width: 90
                model: root.lengths.map(s => qsTr("%1 s").arg(s))
                currentIndex: 1
            }
            ThemedButton {
                text: root.proposals.length > 0 ? qsTr("Search again") : qsTr("Find moments")
                glyph: Theme.icons.sparkles
                variant: root.proposals.length > 0 ? "secondary" : "primary"
                onClicked: Shorts.findShorts(root.counts[countPicker.currentIndex],
                                             root.lengths[lengthPicker.currentIndex])
            }
        }

        Column {
            width: parent.width
            spacing: Theme.spacingSm
            visible: Shorts.busy

            ThemedLabel { text: Shorts.stage; color: Theme.mutedForeground }
            ThemedProgressBar {
                width: parent.width
                value: Shorts.progress
            }
        }

        ListView {
            id: list
            width: parent.width
            height: Math.min(contentHeight, 380)
            visible: root.proposals.length > 0
            clip: true
            spacing: Theme.spacingLg
            model: root.proposals
            boundsBehavior: Flickable.StopAtBounds
            ScrollBar.vertical: AppScrollBar { }

            delegate: Row {
                required property var modelData
                required property int index
                width: list.width - Theme.spacingLg
                spacing: Theme.spacingMd

                ThemedCheckBox {
                    enabled: !Shorts.busy
                    checked: root.ticked[index] !== false
                    onToggled: {
                        const next = Object.assign({}, root.ticked)
                        next[index] = checked
                        root.ticked = next
                    }
                }

                Column {
                    width: parent.width - 32 - previewButton.width - Theme.spacingMd * 2
                    spacing: Theme.spacingXs

                    Text {
                        width: parent.width
                        text: modelData.title
                        wrapMode: Text.Wrap
                        color: Theme.panelForeground
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontSizeSm
                        font.weight: Font.DemiBold
                    }
                    Text {
                        width: parent.width
                        text: root.formatTime(modelData.start) + " – " + root.formatTime(modelData.end)
                              + "  ·  " + qsTr("%1 s").arg(Math.round(modelData.end - modelData.start))
                        color: Theme.accentOnPanel
                        font.family: Theme.monoFontFamily
                        font.pixelSize: Theme.fontSizeXs
                    }
                    Text {
                        width: parent.width
                        text: "“" + modelData.firstText + "”"
                        wrapMode: Text.Wrap
                        color: Theme.panelForeground
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontSizeXs
                        font.italic: true
                    }
                    Text {
                        width: parent.width
                        text: modelData.reason
                        wrapMode: Text.Wrap
                        color: Theme.mutedForeground
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontSizeXs
                    }
                }

                IconButton {
                    id: previewButton
                    glyph: Theme.icons.play
                    variant: "ghost"
                    tooltip: qsTr("Go to this moment")
                    onClicked: EditorState.playheadSeconds = modelData.start
                }
            }
        }

        Row {
            spacing: Theme.spacingMd
            visible: root.doneFolder !== "" && !Shorts.busy

            ThemedButton {
                text: qsTr("Open the shorts folder")
                glyph: Theme.icons.folder
                variant: "secondary"
                onClicked: Shorts.openOutputFolder()
            }
        }
    }
}
