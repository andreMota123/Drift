import QtQuick
import QtQuick.Controls.Basic
import Drift

// "Smart suggestions": measures the project on this machine and offers the fixes that apply,
// each one to every affected clip at once and as a single undo step.
ThemedDialog {
    id: root

    // Loudness every clip is brought to, and how far off one may be before it is flagged.
    readonly property double targetLufs: -16
    readonly property double toleranceLu: 2
    readonly property double minPause: 0.5
    readonly property double maxPauseShare: 0.6

    property var queue: []          // clips to measure, as plain objects
    property int cursor: 0          // next one in the queue
    property int totalClips: 0
    property bool analysed: false
    property var loudClips: []      // [{ id, name, lufs }]
    property var pauseClips: []     // [{ id, name, count, seconds }]
    readonly property bool busy: cursor < queue.length
    readonly property int pauseCount: pauseClips.reduce(function (sum, c) { return sum + c.count }, 0)
    readonly property double pauseSeconds: pauseClips.reduce(function (sum, c) { return sum + c.seconds }, 0)

    title: qsTr("Smart suggestions")
    showAccept: false
    rejectText: qsTr("Close")
    preferredWidth: Theme.dialogWidthLg

    function openDialog() {
        analysed = false
        loudClips = []
        pauseClips = []
        queue = []
        cursor = 0
        open()
    }

    function analyse() {
        loudClips = []
        pauseClips = []
        analysed = false
        const clips = EditorState.soundClips()
        // Copied out of the list C++ hands over, so it is an ordinary array from here on.
        const plain = []
        for (let i = 0; i < clips.length; ++i)
            plain.push({ id: clips[i].id, track: clips[i].track, clip: clips[i].clip, name: clips[i].name,
                         duration: clips[i].duration })
        totalClips = plain.length
        cursor = 0
        queue = plain
        if (plain.length === 0)
            analysed = true
    }

    // One clip per pass through the event loop, so the progress line moves and Close stays
    // alive between clips. Single-shot and re-armed by hand: reading a clip's audio spins the
    // event loop while it waits, and a repeating timer would fire again inside that wait and
    // start the same clip on top of itself.
    property bool measuring: false
    // `visible`, not `opened`: the latter only turns true once the opening animation ends.
    onBusyChanged: if (busy && visible) stepTimer.start()
    Timer {
        id: stepTimer
        interval: 1
        repeat: false
        onTriggered: {
            if (root.measuring || !root.busy || !root.visible)
                return
            root.measuring = true
            const clip = root.queue[root.cursor]
            const loudness = EditorState.clipLoudness(clip.track, clip.clip)
            // Below -70 LUFS there is nothing to normalise: a video without sound, or silence.
            if (loudness.ok && loudness.lufs > -70) {
                if (Math.abs(loudness.lufs - root.targetLufs) > root.toleranceLu)
                    root.loudClips = root.loudClips.concat([{ id: clip.id, name: clip.name, lufs: loudness.lufs }])
                const pauses = EditorState.findPauses(clip.track, clip.clip, root.minPause)
                const ranges = (pauses.ok && pauses.ranges) || []
                let seconds = 0
                for (let i = 0; i < ranges.length; ++i)
                    seconds += ranges[i].end - ranges[i].start
                // "Silent" for most of its length means the clip is simply quiet, not that it
                // is full of pauses: cutting those would delete it. Normalise the volume first.
                if (ranges.length > 0 && seconds < clip.duration * root.maxPauseShare) {
                    root.pauseClips = root.pauseClips.concat(
                                [{ id: clip.id, name: clip.name, count: ranges.length, seconds: seconds }])
                }
            }
            root.measuring = false
            // The dialog may have been closed, or the analysis restarted, during the wait.
            if (!root.visible || root.cursor >= root.queue.length)
                return
            root.cursor = root.cursor + 1
            if (root.cursor >= root.queue.length)
                root.analysed = true
            else
                stepTimer.start()
        }
    }
    onClosed: {
        queue = []
        cursor = 0
    }

    component Card: Rectangle {
        id: card
        property string heading: ""
        property string detail: ""
        property string actionText: ""
        property var lines: []
        signal applyRequested()

        width: parent ? parent.width : 0
        height: cardBody.implicitHeight + Theme.spacingXl * 2
        radius: Theme.radiusMd
        color: Theme.panelAccent
        border.width: Theme.borderWidth
        border.color: Theme.panelBorder

        Column {
            id: cardBody
            x: Theme.spacingXl
            y: Theme.spacingXl
            width: parent.width - Theme.spacingXl * 2
            spacing: Theme.spacingSm

            Item {
                width: parent.width
                height: Math.max(cardHeading.implicitHeight, cardButton.height)
                ThemedLabel {
                    id: cardHeading
                    anchors.left: parent.left
                    anchors.right: cardButton.left
                    anchors.rightMargin: Theme.spacingLg
                    anchors.verticalCenter: parent.verticalCenter
                    text: card.heading
                    tone: "default"
                    size: "sm"
                    font.weight: Font.Medium
                    wrapMode: Text.WordWrap
                }
                ThemedButton {
                    id: cardButton
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    visible: card.actionText.length > 0
                    text: card.actionText
                    variant: "primary"
                    onClicked: card.applyRequested()
                }
            }
            ThemedLabel {
                width: parent.width
                visible: card.detail.length > 0
                text: card.detail
                wrapMode: Text.WordWrap
            }
            Repeater {
                // A long project should not turn the card into a wall of names.
                model: card.lines.slice(0, 6)
                Text {
                    required property string modelData
                    width: cardBody.width
                    text: modelData
                    elide: Text.ElideMiddle
                    color: Theme.mutedForeground
                    font.family: Theme.monoFontFamily
                    font.pixelSize: Theme.fontSizeXs
                }
            }
            ThemedLabel {
                visible: card.lines.length > 6
                text: qsTr("…and %1 more").arg(card.lines.length - 6)
            }
        }
    }

    contentItem: Column {
        spacing: Theme.spacingLg
        width: parent ? parent.width : 560

        ThemedLabel {
            width: parent.width
            size: "sm"
            wrapMode: Text.WordWrap
            text: qsTr("Your project is analysed on this computer; nothing is uploaded. Each fix "
                       + "applies to every clip listed and is undone with a single Ctrl+Z.")
        }

        Row {
            spacing: Theme.spacingLg
            ThemedButton {
                text: root.analysed ? qsTr("Analyse again") : qsTr("Analyse project")
                variant: root.analysed ? "secondary" : "primary"
                glyph: Theme.icons.search
                enabled: !root.busy
                onClicked: root.analyse()
            }
            ThemedLabel {
                anchors.verticalCenter: parent.verticalCenter
                visible: root.busy
                text: qsTr("Analysing clip %1 of %2…").arg(Math.min(root.cursor + 1, root.totalClips)).arg(root.totalClips)
            }
        }

        ThemedLabel {
            width: parent.width
            visible: root.analysed && root.loudClips.length === 0 && root.pauseClips.length === 0
            tone: "default"
            size: "sm"
            text: root.totalClips === 0 ? qsTr("There are no clips with sound to analyse.")
                                        : qsTr("Nothing to improve was found.")
        }

        Card {
            visible: root.analysed && root.loudClips.length > 0
            heading: qsTr("Even out the volume")
            detail: qsTr("%n clip(s) are louder or quieter than the rest. Bring them all to %1 LUFS.",
                         "", root.loudClips.length).arg(root.targetLufs)
            actionText: qsTr("Apply")
            lines: root.loudClips.map(function (c) { return c.lufs.toFixed(1) + " LUFS   " + c.name })
            onApplyRequested: {
                const changed = EditorState.normalizeClipsVolume(
                                  root.loudClips.map(function (c) { return c.id }), root.targetLufs)
                Toasts.success(qsTr("Volume adjusted on %n clip(s).", "", changed))
                root.loudClips = []
            }
        }

        Card {
            visible: root.analysed && root.pauseClips.length > 0
            heading: qsTr("Remove the pauses")
            detail: qsTr("%n pause(s) of %1 s or more, %2 s in all.", "", root.pauseCount)
                    .arg(root.minPause.toFixed(1)).arg(root.pauseSeconds.toFixed(1))
            actionText: qsTr("Apply")
            lines: root.pauseClips.map(function (c) { return c.count + " × " + c.seconds.toFixed(1) + " s   " + c.name })
            onApplyRequested: {
                const removed = EditorState.removePausesFromClips(
                                  root.pauseClips.map(function (c) { return c.id }), root.minPause)
                Toasts.success(qsTr("%n pause(s) removed.", "", removed))
                // Cutting moved things around; what was measured no longer describes the project.
                root.pauseClips = []
                root.loudClips = []
                root.analysed = false
            }
        }
    }
}
