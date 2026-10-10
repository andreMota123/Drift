import QtQuick
import QtQuick.Controls.Basic
import Drift
import ".."

// The Adjust tab: the basic colour controls of a clip, edited in place. Behind it is one
// "Color Adjust" effect (adjust.basic) on the clip, created by the first slider that moves and
// removed again by Reset — so a clip nobody graded carries no effect at all.
Item {
    id: root

    property int revision: 0
    readonly property var values: {
        void revision
        return EditorState.clipColorAdjust(EditorState.selectedTrack, EditorState.selectedClip)
    }
    readonly property bool hasEffect: values.index !== undefined && values.index >= 0

    height: contentCol.height
    implicitHeight: contentCol.height

    Connections {
        target: EditorState
        function onSelectionChanged() { root.revision++ }
        function onSelectedClipDataChanged() { root.revision++ }
        function onTracksChanged() { root.revision++ }
    }

    readonly property var groups: [
        { title: qsTr("Color"), rows: [
            { key: "temperature", label: qsTr("Temperature"), from: -1 },
            { key: "tint", label: qsTr("Tint"), from: -1 },
            { key: "saturation", label: qsTr("Saturation"), from: -1 } ] },
        { title: qsTr("Lightness"), rows: [
            { key: "exposure", label: qsTr("Exposure"), from: -1 },
            { key: "brightness", label: qsTr("Brightness"), from: -1 },
            { key: "contrast", label: qsTr("Contrast"), from: -1 },
            { key: "highlights", label: qsTr("Highlights"), from: -1 },
            { key: "shadows", label: qsTr("Shadows"), from: -1 },
            { key: "whites", label: qsTr("Whites"), from: -1 },
            { key: "blacks", label: qsTr("Blacks"), from: -1 } ] },
        { title: qsTr("Effects"), rows: [
            { key: "fade", label: qsTr("Fade"), from: 0 },
            { key: "vignette", label: qsTr("Vignette"), from: -1 } ] }
    ]

    Column {
        id: contentCol
        width: root.width
        spacing: Theme.spacingXl

        Repeater {
            model: root.groups

            delegate: Column {
                id: groupCol
                required property var modelData
                width: contentCol.width
                spacing: Theme.spacingLg

                Text {
                    text: groupCol.modelData.title
                    color: Theme.panelForeground
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSizeSm
                    font.weight: Font.DemiBold
                }

                Repeater {
                    model: groupCol.modelData.rows

                    delegate: Column {
                        id: rowCol
                        required property var modelData
                        width: groupCol.width
                        spacing: Theme.spacingXs

                        readonly property real stored: {
                            const v = root.values[rowCol.modelData.key]
                            return v === undefined ? 0 : v
                        }

                        Item {
                            width: parent.width
                            height: nameText.implicitHeight

                            Text {
                                id: nameText
                                text: rowCol.modelData.label
                                color: Math.abs(rowCol.stored) > 0.0005 ? Theme.panelForeground
                                                                        : Theme.mutedForeground
                                font.family: Theme.fontFamily
                                font.pixelSize: Theme.fontSizeXs
                            }

                            // Double-click the name to put the value back to neutral.
                            TapHandler {
                                acceptedButtons: Qt.LeftButton
                                onDoubleTapped: {
                                    if (Math.abs(rowCol.stored) > 0.0005)
                                        EditorState.setClipColorAdjust(
                                            EditorState.selectedTrack, EditorState.selectedClip,
                                            rowCol.modelData.key, 0)
                                }
                            }

                            Text {
                                anchors.right: parent.right
                                text: Math.round((slider.pressed ? slider.value : rowCol.stored) * 100)
                                color: Theme.panelForeground
                                font.family: Theme.monoFontFamily
                                font.pixelSize: Theme.fontSizeXs
                            }
                        }

                        ThemedSlider {
                            id: slider
                            width: parent.width
                            from: rowCol.modelData.from
                            to: 1
                            label: rowCol.modelData.label
                            valueFormatter: function (v) { return Math.round(v * 100).toString() }

                            // Whether the effect existed when the drag began: a drag on an
                            // existing effect previews live and commits once; the first drag on
                            // an ungraded clip has nothing to preview and commits on release.
                            property bool previewing: false

                            Binding on value {
                                when: !slider.pressed
                                value: rowCol.stored
                                restoreMode: Binding.RestoreNone
                            }

                            onMoved: {
                                if (previewing)
                                    EditorState.previewClipColorAdjust(
                                        EditorState.selectedTrack, EditorState.selectedClip,
                                        rowCol.modelData.key, value)
                            }

                            onPressedChanged: {
                                if (pressed) {
                                    previewing = root.hasEffect
                                    if (previewing)
                                        EditorState.beginPreviewDrag(
                                            qsTr("Edit %1").arg(rowCol.modelData.label))
                                } else if (previewing) {
                                    EditorState.commitPreviewDrag()
                                    previewing = false
                                } else {
                                    EditorState.setClipColorAdjust(
                                        EditorState.selectedTrack, EditorState.selectedClip,
                                        rowCol.modelData.key, value)
                                }
                            }
                        }
                    }
                }
            }
        }

        ThemedButton {
            text: qsTr("Reset")
            enabled: root.hasEffect
            onClicked: EditorState.resetClipColorAdjust(EditorState.selectedTrack,
                                                        EditorState.selectedClip)
        }
    }
}
