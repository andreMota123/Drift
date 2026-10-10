import QtQuick
import QtQuick.Controls.Basic
import Drift

// "Remove pauses": finds the stretches of the selected clip where nobody is speaking, shows
// them for review, and cuts them out in one undo step, closing the gaps.
ThemedDialog {
    id: root

    property int trackIndex: -1
    property int clipIndex: -1
    property string clipName: ""
    // [{ start, end }] in timeline seconds, from the last search; null before the first one.
    property var ranges: null
    property double minPause: 0.5
    readonly property double totalSeconds: {
        let sum = 0
        const list = ranges || []
        for (let i = 0; i < list.length; ++i)
            sum += list[i].end - list[i].start
        return sum
    }

    title: qsTr("Remove pauses")
    acceptText: qsTr("Remove")
    preferredWidth: Theme.dialogWidthMd

    function openDialog() {
        const clip = EditorState.selectedClipData
        if (!clip || !clip.path || (clip.kind !== "video" && clip.kind !== "audio")) {
            Toasts.info(qsTr("Select a video or audio clip first."))
            return
        }
        trackIndex = EditorState.selectedTrack
        clipIndex = EditorState.selectedClip
        clipName = clip.name || ""
        ranges = null
        open()
    }

    function formatTime(seconds) {
        const m = Math.floor(seconds / 60)
        const s = seconds - m * 60
        return m + ":" + (s < 10 ? "0" : "") + s.toFixed(1)
    }

    function search() {
        const result = EditorState.findPauses(trackIndex, clipIndex, minPause)
        if (!result.ok) {
            Toasts.error(qsTr("Could not analyse this clip's audio."))
            ranges = []
            return
        }
        ranges = result.ranges || []
    }

    onAccepted: {
        if (!ranges || ranges.length === 0)
            return
        const result = EditorState.removePauses(trackIndex, clipIndex, minPause)
        if (result.ok)
            Toasts.success(qsTr("%n pause(s) removed.", "", (result.removed || []).length))
        else
            Toasts.error(qsTr("Could not remove the pauses."))
    }

    contentItem: Column {
        spacing: Theme.spacingLg
        width: parent ? parent.width : 380

        ThemedLabel {
            width: parent.width
            size: "sm"
            text: qsTr("Cuts the silent stretches out of “%1” and closes the gaps. One undo brings everything back.")
                  .arg(root.clipName)
        }

        Row {
            width: parent.width
            spacing: Theme.spacingLg

            Column {
                spacing: Theme.spacingXs
                ThemedLabel { text: qsTr("Minimum pause") }
                Row {
                    spacing: Theme.spacingSm
                    ThemedTextField {
                        id: minField
                        width: 88
                        height: 26
                        text: root.minPause.toFixed(1)
                        validator: DoubleValidator { bottom: 0.1; top: 100.0; decimals: 1; notation: DoubleValidator.StandardNotation }
                        onEditingFinished: {
                            const v = parseFloat(text.replace(",", "."))
                            root.minPause = Math.max(0.1, Math.min(100, isNaN(v) ? 0.5 : v))
                            text = root.minPause.toFixed(1)
                            root.ranges = null
                        }
                    }
                    ThemedLabel {
                        anchors.verticalCenter: parent.verticalCenter
                        text: qsTr("s")
                    }
                }
            }

            ThemedButton {
                anchors.bottom: parent.bottom
                text: qsTr("Find pauses")
                variant: "secondary"
                glyph: Theme.icons.search
                onClicked: {
                    minField.editingFinished()
                    root.search()
                }
            }
        }

        ThemedLabel {
            width: parent.width
            visible: root.ranges !== null
            tone: "default"
            size: "sm"
            text: root.ranges && root.ranges.length > 0
                  ? qsTr("%n pause(s) found", "", root.ranges.length) + " · "
                    + qsTr("%1 s will be cut").arg(root.totalSeconds.toFixed(1))
                  : qsTr("No pauses this long were found.")
        }

        Rectangle {
            width: parent.width
            height: Math.min(200, list.contentHeight + 2)
            visible: root.ranges !== null && root.ranges.length > 0
            radius: Theme.radiusSm
            color: Theme.panelAccent
            border.width: Theme.borderWidth
            border.color: Theme.panelBorder

            ListView {
                id: list
                anchors.fill: parent
                anchors.margins: 1
                clip: true
                model: root.ranges || []
                ScrollBar.vertical: AppScrollBar { }

                delegate: Item {
                    id: line
                    required property int index
                    required property var modelData
                    width: ListView.view ? ListView.view.width : 0
                    height: 26

                    MouseArea {
                        id: lineMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        // Jump there so the pause can be heard before it goes.
                        onClicked: EditorState.playheadSeconds = line.modelData.start
                    }
                    Rectangle {
                        anchors.fill: parent
                        color: lineMouse.containsMouse ? Theme.popoverHover : "transparent"
                    }
                    Text {
                        anchors.left: parent.left
                        anchors.leftMargin: Theme.spacingLg
                        anchors.verticalCenter: parent.verticalCenter
                        text: root.formatTime(line.modelData.start) + "  →  " + root.formatTime(line.modelData.end)
                        color: Theme.panelForeground
                        font.family: Theme.monoFontFamily
                        font.pixelSize: Theme.fontSizeXs
                    }
                    Text {
                        anchors.right: parent.right
                        anchors.rightMargin: Theme.spacingLg + 8
                        anchors.verticalCenter: parent.verticalCenter
                        text: (line.modelData.end - line.modelData.start).toFixed(1) + " " + qsTr("s")
                        color: Theme.mutedForeground
                        font.family: Theme.monoFontFamily
                        font.pixelSize: Theme.fontSizeXs
                    }
                }
            }
        }
    }
}
