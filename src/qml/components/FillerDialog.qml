import QtQuick
import QtQuick.Controls.Basic
import Drift

// "Remove filler words": the local AI marks verbal crutches, repeated words and abandoned
// starts in the captions; the ticked ones are cut out of every track in one undo step.
ThemedDialog {
    id: root

    readonly property var proposals: Fillers.proposals
    property var ticked: ({})
    property bool hasCaptions: false
    readonly property int tickedCount: {
        let n = 0
        for (let i = 0; i < proposals.length; ++i)
            if (ticked[i] !== false)
                ++n
        return n
    }

    title: qsTr("Remove filler words")
    preferredWidth: Theme.dialogWidthLg
    acceptText: qsTr("Cut %n stretch(es)", "", tickedCount)
    acceptEnabled: proposals.length > 0 && tickedCount > 0 && !Fillers.busy
    rejectText: Fillers.busy ? qsTr("Stop") : qsTr("Close")

    function openDialog() {
        hasCaptions = Fillers.hasTranscript()
        open()
    }

    function formatTime(seconds) {
        const s = Math.max(0, seconds)
        return Math.floor(s / 60) + ":" + (s % 60).toFixed(1).padStart(4, "0")
    }

    function kindLabel(kind) {
        if (kind === "retake")
            return qsTr("repeated take")
        if (kind === "false_start")
            return qsTr("false start")
        if (kind === "aside")
            return qsTr("aside")
        return qsTr("filler")
    }

    onProposalsChanged: {
        const next = ({})
        for (let i = 0; i < proposals.length; ++i)
            next[i] = proposals[i].checked !== false
        ticked = next
    }

    onAccepted: {
        const chosen = []
        for (let i = 0; i < proposals.length; ++i)
            if (ticked[i] !== false)
                chosen.push(i)
        Fillers.apply(chosen)
    }
    onRejected: if (Fillers.busy) Fillers.cancel()

    Connections {
        target: Fillers
        function onFinished(ok, message) {
            if (ok)
                Toasts.success(message)
            else
                Toasts.error(message)
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
                  ? qsTr("Finds repeated takes (the last one stays) and abandoned starts, and the local AI marks filler words (“é…”, “tipo”, “né”) and asides to the crew (those start unticked). What you keep ticked is cut from the video, the sound and the captions together. Listen with ▶ before cutting: word times are estimated.")
                  : qsTr("This project has no captions yet. Generate them first in the Captions tab: the AI finds the fillers in what is said.")
        }

        ThemedButton {
            visible: root.hasCaptions
            enabled: !Fillers.busy
            text: root.proposals.length > 0 ? qsTr("Search again") : qsTr("Find filler words")
            glyph: Theme.icons.sparkles
            variant: root.proposals.length > 0 ? "secondary" : "primary"
            onClicked: Fillers.find()
        }

        ThemedProgressBar {
            width: parent.width
            visible: Fillers.busy
            value: Fillers.progress
        }

        ListView {
            id: list
            width: parent.width
            height: Math.min(contentHeight, 380)
            visible: root.proposals.length > 0
            clip: true
            spacing: Theme.spacingMd
            model: root.proposals
            boundsBehavior: Flickable.StopAtBounds
            ScrollBar.vertical: AppScrollBar { }

            delegate: Row {
                required property var modelData
                required property int index
                width: list.width - Theme.spacingLg
                spacing: Theme.spacingMd

                ThemedCheckBox {
                    checked: root.ticked[index] !== false
                    onToggled: {
                        const next = Object.assign({}, root.ticked)
                        next[index] = checked
                        root.ticked = next
                    }
                }

                Column {
                    width: parent.width - 32 - listenButton.width - Theme.spacingMd * 2
                    spacing: Theme.spacingXs

                    Text {
                        width: parent.width
                        text: root.formatTime(modelData.start) + "  ·  " + root.kindLabel(modelData.kind)
                              + "  ·  " + qsTr("%1 s").arg((modelData.end - modelData.start).toFixed(1))
                              + (modelData.unsure ? "  ·  " + qsTr("listen first: no pause at an edge") : "")
                        color: Theme.accentOnPanel
                        font.family: Theme.monoFontFamily
                        font.pixelSize: Theme.fontSizeXs
                    }
                    // The caption with the marked words struck through.
                    Text {
                        width: parent.width
                        wrapMode: Text.Wrap
                        textFormat: Text.StyledText
                        color: Theme.panelForeground
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontSizeSm
                        function esc(s) { return String(s).replace(/&/g, "&amp;").replace(/</g, "&lt;").replace(/>/g, "&gt;") }
                        text: {
                            const line = modelData.line
                            const a = modelData.offset
                            const b = a + modelData.length
                            return esc(line.substring(0, a)) + "<s><font color=\"" + Theme.destructive + "\">"
                                   + esc(line.substring(a, b)) + "</font></s>" + esc(line.substring(b))
                        }
                    }
                }

                IconButton {
                    id: listenButton
                    glyph: Theme.icons.play
                    variant: "ghost"
                    tooltip: qsTr("Listen from just before")
                    onClicked: {
                        EditorState.playheadSeconds = Math.max(0, modelData.start - 1.5)
                        EditorState.playing = true
                    }
                }
            }
        }
    }
}
