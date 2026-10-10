import QtQuick
import QtQuick.Controls.Basic
import QtMultimedia
import Drift

// Records the microphone, the screen or the camera straight into the project: the file is
// saved under Videos/Drift, imported, and laid on a new track where the playhead stood when
// recording began.
ThemedDialog {
    id: root

    // "mic" | "screen" | "camera"
    property string mode: "mic"
    property bool withMic: true
    // Timeline position the take will be placed at.
    property double startSeconds: 0
    readonly property bool recording: recorder.recorderState === MediaRecorder.RecordingState
    readonly property bool hasCamera: mediaDevices.videoInputs.length > 0
    readonly property bool hasMic: mediaDevices.audioInputs.length > 0

    title: qsTr("Record")
    showAccept: false
    rejectText: qsTr("Close")
    preferredWidth: Theme.dialogWidthMd
    // Closing mid-take would lose it silently; Stop first.
    closePolicy: recording ? Popup.NoAutoClose : (Popup.CloseOnEscape | Popup.CloseOnPressOutside)

    function openDialog() {
        mode = "mic"
        open()
    }

    function formatElapsed(ms) {
        const total = Math.floor(ms / 1000)
        const m = Math.floor(total / 60)
        const s = total % 60
        return (m < 10 ? "0" : "") + m + ":" + (s < 10 ? "0" : "") + s
    }

    function start() {
        startSeconds = EditorState.playheadSeconds
        EditorState.playing = false
        recorder.outputLocation = EditorState.newRecordingUrl(mode)
        if (mode === "screen") {
            // The capture has to be running before the recorder starts, or the file opens
            // with no picture to put in it. On Wayland this is also where the system asks
            // which screen to share.
            screenCapture.active = true
            armTimer.restart()
        } else {
            recorder.record()
        }
    }

    Timer {
        id: armTimer
        interval: 400
        onTriggered: recorder.record()
    }

    function stop() {
        armTimer.stop()
        recorder.stop()
        screenCapture.active = false
    }

    onClosed: {
        if (recording)
            stop()
        screenCapture.active = false
    }

    MediaDevices { id: mediaDevices }

    Camera {
        id: camera
        active: root.visible && root.mode === "camera"
    }
    ScreenCapture {
        id: screenCapture
        onErrorOccurred: (error, errorString) => {
            armTimer.stop()
            active = false
            Toasts.error(qsTr("The screen could not be captured: %1").arg(errorString))
        }
    }
    AudioInput { id: microphone }

    CaptureSession {
        id: session
        audioInput: (root.mode === "mic" || root.withMic) && root.hasMic ? microphone : null
        camera: root.mode === "camera" ? camera : null
        screenCapture: root.mode === "screen" ? screenCapture : null
        videoOutput: monitor
        recorder: MediaRecorder {
            id: recorder
            quality: MediaRecorder.HighQuality
            onRecorderStateChanged: {
                if (recorderState !== MediaRecorder.StoppedState)
                    return
                const file = actualLocation
                if (!file || file.toString().length === 0)
                    return
                // A take with nothing in it (the capture never delivered a frame) is thrown
                // away rather than imported as a broken clip.
                if (EditorState.discardEmptyRecording(file)) {
                    Toasts.error(qsTr("Nothing was captured, so no file was kept."))
                    return
                }
                // Stopped with something on disk: bring it in and lay it on the timeline.
                MediaImport.importUrls([file], true, function (added) {
                    if (added > 0) {
                        EditorState.addClipFromAssetOnNewTrack(AssetLibrary.count - 1, root.startSeconds)
                        Toasts.success(qsTr("Recording added to the timeline."))
                    } else {
                        Toasts.error(qsTr("The recording could not be imported."))
                    }
                })
            }
            onErrorOccurred: (error, errorString) => {
                screenCapture.active = false
                Toasts.error(qsTr("Recording failed: %1").arg(errorString))
            }
        }
    }

    contentItem: Column {
        spacing: Theme.spacingLg
        width: parent ? parent.width : 380

        Row {
            spacing: Theme.spacingSm
            Repeater {
                model: [
                    { id: "mic", label: qsTr("Microphone"), glyph: Theme.icons.audioLines },
                    { id: "screen", label: qsTr("Screen"), glyph: Theme.icons.monitor },
                    { id: "camera", label: qsTr("Camera"), glyph: Theme.icons.video }
                ]
                ThemedButton {
                    required property var modelData
                    text: modelData.label
                    glyph: modelData.glyph
                    variant: root.mode === modelData.id ? "primary" : "secondary"
                    enabled: !root.recording
                    onClicked: root.mode = modelData.id
                }
            }
        }

        Rectangle {
            width: parent.width
            height: visible ? Math.round(width * 9 / 16) : 0
            visible: root.mode !== "mic"
            radius: Theme.radiusSm
            color: Theme.overlayColor
            clip: true

            VideoOutput {
                id: monitor
                anchors.fill: parent
            }
            ThemedLabel {
                anchors.centerIn: parent
                width: parent.width - Theme.spacingXl * 2
                horizontalAlignment: Text.AlignHCenter
                wrapMode: Text.WordWrap
                visible: (root.mode === "camera" && !root.hasCamera) || (root.mode === "screen" && !root.recording)
                text: root.mode === "camera"
                      ? qsTr("No camera was found. In the Flatpak version the camera has to be allowed first.")
                      : qsTr("The screen appears here once recording starts. Your system may ask which screen or window to share.")
            }
        }

        ThemedCheckBox {
            visible: root.mode !== "mic"
            enabled: !root.recording && root.hasMic
            text: qsTr("Record the microphone too")
            checked: root.withMic
            onToggled: root.withMic = checked
        }

        ThemedLabel {
            width: parent.width
            visible: !root.hasMic
            wrapMode: Text.WordWrap
            color: Theme.warning
            text: qsTr("No microphone was found.")
        }

        Row {
            spacing: Theme.spacingLg

            ThemedButton {
                text: root.recording ? qsTr("Stop") : qsTr("Record")
                variant: root.recording ? "destructive" : "primary"
                glyph: root.recording ? Theme.icons.square : Theme.icons.video
                enabled: root.recording
                         || (root.mode === "mic" ? root.hasMic : (root.mode === "camera" ? root.hasCamera : true))
                onClicked: root.recording ? root.stop() : root.start()
            }
            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: root.formatElapsed(recorder.duration)
                color: root.recording ? Theme.destructive : Theme.mutedForeground
                font.family: Theme.monoFontFamily
                font.pixelSize: Theme.fontSizeBase
            }
        }

        ThemedLabel {
            width: parent.width
            opacity: 0.8
            wrapMode: Text.WordWrap
            text: qsTr("The take is saved in Videos/Drift and placed on a new track at the playhead.")
        }
    }
}
