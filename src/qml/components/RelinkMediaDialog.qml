import QtQuick
import QtQuick.Controls.Basic
import Drift

// Media the project points at but that is no longer on disk. Offered once when such a project
// opens, and from the media panel afterwards. Linking one file can bring the rest of its folder
// back with it; clips keep their place, trim and effects — only the path changes.
ThemedDialog {
    id: root

    // [{ id, name, path, duration, kind, linked }] — rows stay listed (ticked) once linked, so
    // the list reads as progress rather than emptying under the pointer.
    property var rows: []
    property int selectedRow: -1
    property bool linkSiblings: true
    readonly property int linkedCount: rows.filter(function (r) { return r.linked }).length

    title: qsTr("Link media")
    showAccept: false
    rejectText: qsTr("Close")
    preferredWidth: Theme.dialogWidthLg

    function openForMissing() {
        const list = EditorState.missingMedia()
        for (let i = 0; i < list.length; ++i)
            list[i].linked = false
        rows = list
        selectedRow = list.length > 0 ? 0 : -1
        if (list.length > 0)
            open()
    }

    function formatDuration(seconds) {
        if (!(seconds > 0))
            return "—"
        const total = Math.round(seconds)
        const m = Math.floor(total / 60)
        const s = total % 60
        return m + ":" + (s < 10 ? "0" : "") + s
    }

    function linkRow(index) {
        if (index < 0 || index >= rows.length || rows[index].linked)
            return
        const url = FileDialogs.openFile(qsTr("Find “%1”").arg(rows[index].name),
                                         [AssetLibrary.mediaNameFilter()])
        if (url == "")
            return
        const linked = EditorState.relinkMedia(rows[index].path, url, root.linkSiblings)
        if (linked <= 0) {
            Toasts.error(qsTr("Could not link the selected file."))
            return
        }
        refreshRows()
        Toasts.success(linked === 1 ? qsTr("Media linked.")
                                    : qsTr("%n media files linked.", "", linked))
        if (linkedCount === rows.length)
            close()
    }

    // Whatever is no longer missing has been linked — by this dialog, by undo/redo, or by the
    // file simply coming back.
    function refreshRows() {
        const still = ({})
        const missing = EditorState.missingMedia()
        for (let i = 0; i < missing.length; ++i)
            still[missing[i].id] = true
        const next = []
        for (let j = 0; j < rows.length; ++j) {
            const row = Object.assign({}, rows[j])
            row.linked = !still[row.id]
            next.push(row)
        }
        rows = next
    }

    Connections {
        target: EditorState
        enabled: root.opened
        function onTracksChanged() { root.refreshRows() }
    }

    contentItem: Column {
        spacing: Theme.spacingLg
        width: parent ? parent.width : 520

        ThemedLabel {
            width: parent.width
            size: "sm"
            text: qsTr("Some of this project's media files could not be found. They may have been "
                       + "moved, renamed or be on a drive that is not connected. Pick a file to "
                       + "link it again.")
        }

        // Header
        Row {
            width: parent.width
            spacing: Theme.spacingLg
            leftPadding: Theme.spacingLg

            ThemedLabel { width: parent.width * 0.30; text: qsTr("Name") }
            ThemedLabel { width: parent.width * 0.48; text: qsTr("Last location") }
            ThemedLabel { text: qsTr("Duration") }
        }

        Rectangle {
            width: parent.width
            height: Math.min(300, Math.max(34 * 3, list.contentHeight + 2))
            radius: Theme.radiusSm
            color: Theme.panelAccent
            border.width: Theme.borderWidth
            border.color: Theme.panelBorder

            ListView {
                id: list
                anchors.fill: parent
                anchors.margins: 1
                clip: true
                model: root.rows
                ScrollBar.vertical: AppScrollBar { }

                delegate: Rectangle {
                    id: line
                    required property int index
                    required property var modelData

                    width: ListView.view ? ListView.view.width : 0
                    height: 34
                    color: index === root.selectedRow ? Theme.panelMuted
                                                      : (lineMouse.containsMouse ? Theme.popoverHover : "transparent")

                    MouseArea {
                        id: lineMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        onClicked: root.selectedRow = line.index
                        onDoubleClicked: {
                            root.selectedRow = line.index
                            root.linkRow(line.index)
                        }
                    }

                    Row {
                        anchors.fill: parent
                        anchors.leftMargin: Theme.spacingLg
                        anchors.rightMargin: Theme.spacingLg
                        spacing: Theme.spacingLg

                        Row {
                            width: (line.width - Theme.spacingLg * 2) * 0.30
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: Theme.spacingSm

                            IconGlyph {
                                anchors.verticalCenter: parent.verticalCenter
                                glyph: line.modelData.linked ? Theme.icons.check : Theme.icons.warning
                                iconSize: Theme.iconSizeSm
                                iconColor: line.modelData.linked ? Theme.constructive : Theme.warning
                            }
                            Text {
                                width: parent.width - Theme.iconSizeSm - Theme.spacingSm
                                anchors.verticalCenter: parent.verticalCenter
                                text: line.modelData.name
                                elide: Text.ElideMiddle
                                color: Theme.panelForeground
                                font.family: Theme.fontFamily
                                font.pixelSize: Theme.fontSizeSm
                            }
                        }
                        Text {
                            width: (line.width - Theme.spacingLg * 2) * 0.48
                            anchors.verticalCenter: parent.verticalCenter
                            text: line.modelData.path
                            elide: Text.ElideLeft
                            color: Theme.mutedForeground
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fontSizeXs
                        }
                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            text: root.formatDuration(line.modelData.duration)
                            color: Theme.mutedForeground
                            font.family: Theme.monoFontFamily
                            font.pixelSize: Theme.fontSizeXs
                        }
                    }
                }
            }
        }

        Item {
            width: parent.width
            height: Math.max(linkButton.height, siblingsBox.height)

            ThemedCheckBox {
                id: siblingsBox
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                text: qsTr("Also link other missing media found in the same folder")
                checked: root.linkSiblings
                onToggled: root.linkSiblings = checked
            }

            Row {
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                spacing: Theme.spacingLg

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: root.linkedCount + "/" + root.rows.length
                    color: Theme.mutedForeground
                    font.family: Theme.monoFontFamily
                    font.pixelSize: Theme.fontSizeXs
                }
                ThemedButton {
                    id: linkButton
                    text: qsTr("Link media…")
                    variant: "primary"
                    enabled: root.selectedRow >= 0 && root.selectedRow < root.rows.length
                             && !root.rows[root.selectedRow].linked
                    onClicked: root.linkRow(root.selectedRow)
                }
            }
        }
    }
}
