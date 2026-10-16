import QtQuick
import QtQuick.Controls.Basic
import Drift
import ".."

// One-tap makeup looks. A look writes the beauty effects (Face Retouch, eyeliner, eyeshadow, …)
// onto the clip's effect stack; the slider scales every amount in it together, the way a beauty
// filter does. Fine-tuning stays in those effects on the clip's effect lane.
Item {
    id: root

    property int revision: 0
    readonly property var looks: EditorState.makeupLooks()
    readonly property var current: {
        void revision
        return EditorState.clipMakeupLook(EditorState.selectedTrack, EditorState.selectedClip)
    }
    readonly property string currentLook: (current && current.look) ? current.look : ""
    readonly property real currentIntensity: (current && current.intensity !== undefined)
                                             ? current.intensity : 1.0

    height: contentCol.height
    implicitHeight: contentCol.height

    function refreshFields() { root.revision++ }

    function apply(lookId, intensity) {
        EditorState.applyMakeupLook(EditorState.selectedTrack, EditorState.selectedClip,
                                    lookId, intensity)
        root.revision++
    }

    Connections {
        target: EditorState
        function onSelectionChanged() { root.revision++ }
        function onSelectedClipDataChanged() { root.revision++ }
        function onTracksChanged() { root.revision++ }
    }

    Column {
        id: contentCol
        width: root.width
        spacing: Theme.spacingXl

        Text {
            width: parent.width
            wrapMode: Text.WordWrap
            text: qsTr("Pick a look to apply makeup to the face in this clip. The intensity slider turns the whole look up or down together. Faces are detected the first time.")
            color: Theme.mutedForeground
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontSizeXs
        }

        Grid {
            id: lookGrid
            width: parent.width
            columns: 3
            spacing: Theme.spacingMd
            readonly property real cellWidth: (width - spacing * (columns - 1)) / columns

            Repeater {
                model: root.looks

                Rectangle {
                    id: card
                    required property var modelData
                    readonly property bool selected: root.currentLook === modelData.id
                    width: lookGrid.cellWidth
                    height: 78
                    radius: Theme.radiusSm
                    color: cardArea.containsMouse ? Theme.popoverHover : Theme.panelAccent
                    border.width: selected ? 2 : Theme.borderWidth
                    border.color: selected ? Theme.primary : Theme.panelSecondaryBorder
                    opacity: modelData.available ? 1.0 : 0.45

                    Row {
                        anchors.horizontalCenter: parent.horizontalCenter
                        anchors.top: parent.top
                        anchors.topMargin: 12
                        spacing: -6

                        Repeater {
                            model: card.modelData.swatch
                            Rectangle {
                                required property string modelData
                                width: 24
                                height: 24
                                radius: 12
                                color: modelData
                                border.width: 2
                                border.color: Theme.panelBackground
                            }
                        }
                    }

                    Text {
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.bottom: parent.bottom
                        anchors.bottomMargin: 10
                        anchors.leftMargin: 4
                        anchors.rightMargin: 4
                        horizontalAlignment: Text.AlignHCenter
                        elide: Text.ElideRight
                        text: card.modelData.label
                        color: card.selected ? Theme.primary : Theme.panelForeground
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontSizeXs
                        font.weight: card.selected ? Font.DemiBold : Font.Normal
                    }

                    MouseArea {
                        id: cardArea
                        anchors.fill: parent
                        hoverEnabled: true
                        enabled: card.modelData.available
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.apply(card.modelData.id,
                                              root.currentLook.length > 0 ? root.currentIntensity : 1.0)
                    }
                }
            }
        }

        Column {
            width: parent.width
            spacing: Theme.spacingMd
            visible: root.currentLook.length > 0

            Text {
                text: qsTr("Intensity")
                color: Theme.mutedForeground
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSizeXs
                font.weight: Font.Medium
            }

            ThemedSlider {
                id: intensitySlider
                label: qsTr("Intensity")
                width: parent.width
                from: 0
                to: 100
                stepSize: 1
                valueFormatter: function (v) { return Math.round(v) + "%" }
                Binding on value {
                    when: !intensitySlider.pressed
                    value: Math.round(root.currentIntensity * 100)
                }
                onPressedChanged: {
                    if (!pressed && root.currentLook.length > 0)
                        root.apply(root.currentLook, value / 100)
                }
            }

            ThemedButton {
                width: parent.width
                text: qsTr("Remove makeup")
                glyph: Theme.icons.undo
                variant: "secondary"
                onClicked: {
                    EditorState.removeMakeupLook(EditorState.selectedTrack, EditorState.selectedClip)
                    root.revision++
                }
            }

            Text {
                width: parent.width
                wrapMode: Text.WordWrap
                text: qsTr("To fine-tune lipstick colour, eyeliner or skin smoothing, select the clip's effect lane: the look is made of those effects.")
                color: Theme.mutedForeground
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSizeXs
            }
        }
    }
}
