import QtQuick
import QtQuick.Controls.Basic
import Drift

// "Export selected clips": one file per selected clip, numbered after a shared title. Encoding
// follows the settings of the last normal export, so the usual dialog stays the one place where
// codec and quality are chosen.
ThemedDialog {
    id: root

    property int clipCount: 0
    property url folder: ""
    property bool clipOnly: true
    readonly property var settings: {
        const remembered = EditorState.lastExportSettings()
        return remembered && Object.keys(remembered).length > 0 ? remembered
                                                               : EditorState.exportDefaultSettings()
    }

    title: qsTr("Export selected clips")
    acceptText: qsTr("Export")
    preferredWidth: Theme.dialogWidthMd

    function openDialog() {
        clipCount = EditorState.exportableSelectionCount()
        if (clipCount <= 0) {
            Toasts.info(qsTr("Select the clips to export first."))
            return
        }
        titleField.text = EditorState.projectName
        const last = EditorState.lastExportFolder()
        folder = last && last.length > 0 ? Qt.resolvedUrl("file://" + last) : ""
        open()
    }

    function localPath(url) {
        const text = url.toString()
        return text.indexOf("file://") === 0 ? decodeURIComponent(text.substring(7)) : text
    }

    onAccepted: {
        if (root.folder.toString().length === 0) {
            Toasts.warning(qsTr("Choose a folder to save the clips in."))
            return
        }
        EditorState.exportSelectedClips(root.folder, titleField.text, root.settings, root.clipOnly)
    }

    contentItem: Column {
        spacing: Theme.spacingLg
        width: parent ? parent.width : 380

        ThemedLabel {
            width: parent.width
            size: "sm"
            text: qsTr("%n clip(s) will be exported, each as its own file.", "", root.clipCount)
        }

        Column {
            width: parent.width
            spacing: Theme.spacingXs
            ThemedLabel { text: qsTr("Title") }
            ThemedTextField {
                id: titleField
                width: parent.width
                maximumLength: 50
            }
            ThemedLabel {
                width: parent.width
                opacity: 0.8
                text: qsTr("Files are named with this title followed by a number.")
            }
        }

        Column {
            width: parent.width
            spacing: Theme.spacingXs
            ThemedLabel { text: qsTr("Save in") }
            Row {
                width: parent.width
                spacing: Theme.spacingSm
                ThemedTextField {
                    width: parent.width - folderButton.width - parent.spacing
                    readOnly: true
                    text: root.localPath(root.folder)
                    placeholderText: qsTr("No folder chosen")
                }
                IconButton {
                    id: folderButton
                    glyph: Theme.icons.folder
                    tooltip: qsTr("Choose folder")
                    onClicked: {
                        const url = FileDialogs.openDirectory(qsTr("Save clips in"), root.folder)
                        if (url != "")
                            root.folder = url
                    }
                }
            }
        }

        ThemedCheckBox {
            text: qsTr("Only the clip itself, without the other tracks")
            checked: root.clipOnly
            onToggled: root.clipOnly = checked
        }

        ThemedLabel {
            width: parent.width
            opacity: 0.8
            text: qsTr("Resolution, codec and quality follow your last export.")
        }
    }
}
