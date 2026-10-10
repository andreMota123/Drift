import QtQuick
import Drift

// Rulers along the top and left of the preview, and the guides pulled out of them. Fills the
// viewport; `frame` is the item showing the project frame, whose geometry (pan and zoom
// included) maps guide positions — fractions of the frame — to the screen.
Item {
    id: root

    required property Item frame
    readonly property real rulerSize: 16
    readonly property bool rulersOn: EditorState.rulersVisible
    readonly property bool linesOn: EditorState.referenceLinesVisible
    readonly property int projectW: Math.max(1, EditorState.projectWidth())
    readonly property int projectH: Math.max(1, EditorState.projectHeight())

    // A guide being pulled out of a ruler, before it exists: -1 when none.
    property real pendingPos: -1
    property bool pendingVertical: false

    function fracX(px) { return (px - frame.x) / Math.max(1, frame.width) }
    function fracY(py) { return (py - frame.y) / Math.max(1, frame.height) }
    function inFrame(frac) { return frac >= 0 && frac <= 1 }
    function label(vertical, frac) {
        return (vertical ? "X " : "Y ") + Math.round(frac * (vertical ? projectW : projectH))
    }

    // ---- Guides ---------------------------------------------------------------------
    component GuideLine: Item {
        id: line
        required property int index
        required property real modelData
        property bool vertical: true
        // While dragged the line follows the pointer; the model catches up on release, so a
        // drag that leaves the frame can still be seen before it deletes the guide.
        property real livePos: modelData
        readonly property real pos: dragArea.pressed ? livePos : modelData

        x: vertical ? root.frame.x + pos * root.frame.width - 3 : 0
        y: vertical ? 0 : root.frame.y + pos * root.frame.height - 3
        width: vertical ? 7 : root.width
        height: vertical ? root.height : 7

        Rectangle {
            anchors.centerIn: parent
            width: line.vertical ? 1 : parent.width
            height: line.vertical ? parent.height : 1
            color: Theme.primary
            opacity: root.inFrame(line.pos) ? 1 : 0.35
        }

        MouseArea {
            id: dragArea
            anchors.fill: parent
            hoverEnabled: true
            acceptedButtons: Qt.LeftButton | Qt.RightButton
            cursorShape: EditorState.referenceLinesLocked
                         ? Qt.ArrowCursor : (line.vertical ? Qt.SizeHorCursor : Qt.SizeVerCursor)
            preventStealing: true
            onPressed: (mouse) => {
                if (mouse.button === Qt.RightButton) {
                    guideMenu.popup()
                    return
                }
                if (EditorState.referenceLinesLocked)
                    Toasts.info(qsTr("Guides are locked."))
                line.livePos = line.modelData
            }
            onPositionChanged: (mouse) => {
                if (!(pressedButtons & Qt.LeftButton) || EditorState.referenceLinesLocked)
                    return
                const p = mapToItem(root, mouse.x, mouse.y)
                line.livePos = line.vertical ? root.fracX(p.x) : root.fracY(p.y)
            }
            onReleased: (mouse) => {
                if (mouse.button !== Qt.LeftButton || EditorState.referenceLinesLocked)
                    return
                // Dropped outside the frame: the guide goes away, as in any drawing program.
                if (root.inFrame(line.livePos))
                    EditorState.moveReferenceLine(line.vertical, line.index, line.livePos)
                else
                    EditorState.removeReferenceLine(line.vertical, line.index)
            }

            ThemedContextMenu {
                id: guideMenu
                ThemedMenuItem {
                    text: qsTr("Delete guide")
                    icon.name: Theme.icons.trash
                    enabled: !EditorState.referenceLinesLocked
                    onTriggered: EditorState.removeReferenceLine(line.vertical, line.index)
                }
                ThemedMenuItem {
                    text: EditorState.referenceLinesLocked ? qsTr("Unlock guides") : qsTr("Lock guides")
                    icon.name: EditorState.referenceLinesLocked ? Theme.icons.lockOpen : Theme.icons.lock
                    onTriggered: EditorState.referenceLinesLocked = !EditorState.referenceLinesLocked
                }
                ThemedMenuItem {
                    text: qsTr("Clear guides")
                    icon.name: Theme.icons.x
                    onTriggered: EditorState.clearReferenceLines()
                }
            }
        }

        // Position readout beside the pointer while hovering or dragging.
        Rectangle {
            visible: dragArea.containsMouse || dragArea.pressed
            x: line.vertical ? 10 : Math.min(root.width - width - 4, dragArea.mouseX + 12)
            y: line.vertical ? Math.min(root.height - height - 4, dragArea.mouseY + 12) : 10
            width: tip.implicitWidth + 10
            height: tip.implicitHeight + 6
            radius: 4
            color: Theme.scrimStrong
            Text {
                id: tip
                anchors.centerIn: parent
                text: root.label(line.vertical, line.pos)
                color: Theme.onMedia
                font.family: Theme.monoFontFamily
                font.pixelSize: Theme.fontSizeTiny
            }
        }
    }

    Repeater {
        model: root.linesOn ? EditorState.referenceLinesV : []
        GuideLine { vertical: true }
    }
    Repeater {
        model: root.linesOn ? EditorState.referenceLinesH : []
        GuideLine { vertical: false }
    }

    // The guide being pulled out of a ruler.
    Rectangle {
        visible: root.pendingPos > -1
        x: root.pendingVertical ? root.frame.x + root.pendingPos * root.frame.width : 0
        y: root.pendingVertical ? 0 : root.frame.y + root.pendingPos * root.frame.height
        width: root.pendingVertical ? 1 : root.width
        height: root.pendingVertical ? root.height : 1
        color: Theme.primary
        opacity: root.inFrame(root.pendingPos) ? 1 : 0.35
    }

    // ---- Rulers ---------------------------------------------------------------------
    component Ruler: Rectangle {
        id: ruler
        property bool vertical: false
        // Pulling from the top ruler makes a horizontal guide; from the left one, a vertical.
        readonly property bool makesVertical: vertical

        visible: root.rulersOn
        color: Theme.panelBackground

        Canvas {
            id: ticks
            anchors.fill: parent
            readonly property real origin: ruler.vertical ? root.frame.y - ruler.y : root.frame.x - ruler.x
            readonly property real scale: ruler.vertical ? root.frame.height / root.projectH
                                                         : root.frame.width / root.projectW
            readonly property color ink: Theme.mutedForeground
            onOriginChanged: requestPaint()
            onScaleChanged: requestPaint()
            onInkChanged: requestPaint()
            onWidthChanged: requestPaint()
            onHeightChanged: requestPaint()

            onPaint: {
                const ctx = getContext("2d")
                ctx.clearRect(0, 0, width, height)
                if (!(scale > 0))
                    return
                // Labelled marks at least 56 screen px apart, on a 1-2-5 step.
                const steps = [1, 2, 5, 10, 20, 50, 100, 200, 500, 1000, 2000, 5000]
                let step = steps[steps.length - 1]
                for (let i = 0; i < steps.length; ++i) {
                    if (steps[i] * scale >= 56) {
                        step = steps[i]
                        break
                    }
                }
                const length = ruler.vertical ? height : width
                const first = Math.floor((0 - origin) / scale / step) * step
                ctx.fillStyle = ink
                ctx.strokeStyle = ink
                ctx.lineWidth = 1
                ctx.font = "9px sans-serif"
                for (let v = first; (v * scale + origin) <= length; v += step / 5) {
                    const at = Math.round(v * scale + origin) + 0.5
                    if (at < 0)
                        continue
                    const major = Math.abs(v / step - Math.round(v / step)) < 1e-6
                    const tick = major ? root.rulerSize : 4
                    ctx.beginPath()
                    if (ruler.vertical) {
                        ctx.moveTo(root.rulerSize - tick, at)
                        ctx.lineTo(root.rulerSize, at)
                    } else {
                        ctx.moveTo(at, root.rulerSize - tick)
                        ctx.lineTo(at, root.rulerSize)
                    }
                    ctx.stroke()
                    if (!major)
                        continue
                    const text = Math.round(v).toString()
                    if (ruler.vertical) {
                        ctx.save()
                        ctx.translate(9, at + 3)
                        ctx.rotate(-Math.PI / 2)
                        ctx.textAlign = "right"
                        ctx.fillText(text, 0, 0)
                        ctx.restore()
                    } else {
                        ctx.fillText(text, at + 3, 9)
                    }
                }
            }
        }

        Rectangle {
            width: ruler.vertical ? 1 : parent.width
            height: ruler.vertical ? parent.height : 1
            anchors.right: ruler.vertical ? parent.right : undefined
            anchors.bottom: ruler.vertical ? undefined : parent.bottom
            color: Theme.panelBorder
        }

        MouseArea {
            anchors.fill: parent
            cursorShape: ruler.makesVertical ? Qt.SizeHorCursor : Qt.SizeVerCursor
            preventStealing: true
            onPositionChanged: (mouse) => {
                if (!pressed)
                    return
                const p = mapToItem(root, mouse.x, mouse.y)
                root.pendingVertical = ruler.makesVertical
                // Kept above -1 so a pull past the far edge still counts as "being dragged".
                root.pendingPos = Math.max(-0.99, ruler.makesVertical ? root.fracX(p.x) : root.fracY(p.y))
            }
            onReleased: {
                if (root.pendingPos > -1 && root.inFrame(root.pendingPos)) {
                    if (EditorState.addReferenceLine(root.pendingVertical, root.pendingPos) < 0)
                        Toasts.warning(qsTr("Maximum number of guides reached."))
                }
                root.pendingPos = -1
            }
            onCanceled: root.pendingPos = -1
        }
    }

    Ruler {
        x: root.rulerSize
        y: 0
        width: root.width - root.rulerSize
        height: root.rulerSize
        vertical: false
    }
    Ruler {
        x: 0
        y: root.rulerSize
        width: root.rulerSize
        height: root.height - root.rulerSize
        vertical: true
    }
    // The corner where the two rulers meet.
    Rectangle {
        visible: root.rulersOn
        width: root.rulerSize
        height: root.rulerSize
        color: Theme.panelBackground
    }
}
