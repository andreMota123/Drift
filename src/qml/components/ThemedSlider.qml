import QtQuick
import QtQuick.Controls.Basic
import Drift

// Panel-themed slider that keeps parent Flickables from stealing mouse drags.
Slider {
    id: root

    property var _flickable: null

    // Shown in a tooltip while dragging. Set a formatter for units/precision.
    property bool showValueTooltip: true
    property var valueFormatter: function (v) { return Number(v).toFixed(2) }

    // Edge-triggered while the finger is down: a notch index, plus whether the
    // handle is currently parked on an end. Latched so a held min does not buzz.
    property int _hapticNotch: -1
    property bool _hapticMin: false
    property bool _hapticMax: false

    // What this slider controls, for assistive tech. The role was already declared
    // but no name ever was, so every instance announced as an unlabelled "slider".
    // Callers should set it; the formatter is a fallback, not a substitute.
    property string label: ""

    // True when the range runs from negative to positive, i.e. zero is the neutral value.
    readonly property bool zeroCrossing: from < 0 && to > 0
    // Lets a caller turn the neutral magnet off for a range where zero means nothing special.
    property bool snapToZero: true

    from: 0
    to: 1
    live: true
    implicitHeight: 22
    padding: 0
    topPadding: 0
    bottomPadding: 0
    hoverEnabled: true
    focusPolicy: Qt.StrongFocus
    opacity: enabled ? 1 : 0.5

    Accessible.role: Accessible.Slider
    Accessible.name: label
    Accessible.description: valueFormatter ? String(valueFormatter(value)) : String(value)

    // Guard against callers that bind inverted ranges (Qt debug asserts in qBound).
    onFromChanged: if (from > to) to = from
    onToChanged: if (to < from) from = to

    // Only Flickables that opt in with `property int dragLocks: 0` and fold it
    // into their `interactive` binding are lockable. Writing `interactive`
    // directly would destroy that binding, leaving the Flickable stuck at
    // whatever value it happened to hold when the drag started.
    function findFlickable(item) {
        var node = item
        while (node) {
            if (node.dragLocks !== undefined && node.contentHeight !== undefined)
                return node
            node = node.parent
        }
        return null
    }

    function restoreFlickable() {
        if (_flickable) {
            _flickable.dragLocks = Math.max(0, _flickable.dragLocks - 1)
            _flickable = null
        }
    }

    // Connections (not onPressedChanged) so callers can also handle pressedChanged
    // for preview-drag without replacing this guard. Without it, a destroyed slider
    // can leave the parent Flickable non-interactive.
    Connections {
        target: root
        function onPressedChanged() {
            if (root.pressed) {
                if (!root._flickable) {
                    root._flickable = root.findFlickable(root.parent)
                    if (root._flickable)
                        root._flickable.dragLocks++
                }
                root._hapticNotch = -1
                root._hapticMin = false
                root._hapticMax = false
                Haptics.press()
            } else {
                root.restoreFlickable()
            }
        }
    }

    Component.onDestruction: restoreFlickable()

    background: Rectangle {
        x: root.leftPadding
        y: root.topPadding + root.availableHeight / 2 - height / 2
        width: root.availableWidth
        // Desktop: a hairline track with a light fill (CapCut-style). Touch keeps the thicker,
        // accent-filled one, which is easier to follow under a finger.
        height: Theme.touchUi ? Theme.spacingSm : 2
        radius: height / 2
        color: Theme.sliderTrack

        Rectangle {
            // A range that crosses zero fills from zero, so the bar shows how far the value
            // is from neutral and in which direction.
            readonly property real zeroPos: root.zeroCrossing
                                            ? (0 - root.from) / (root.to - root.from) : 0
            x: Math.min(zeroPos, root.visualPosition) * parent.width
            width: Math.abs(root.visualPosition - zeroPos) * parent.width
            height: parent.height
            radius: parent.radius
            color: Theme.touchUi ? Theme.primary : Theme.panelForeground

            // Eases programmatic value changes (a preset chip, a reset button)
            // without fighting the drag, which sets position continuously.
            // Must share the handle's curve below, or fill and handle desync.
            Behavior on width {
                enabled: !root.pressed
                NumberAnimation { duration: Theme.durationFast; easing.type: Theme.easingInOut }
            }
        }
    }

    handle: Rectangle {
        id: handleRect
        x: root.leftPadding + root.visualPosition * (root.availableWidth - width)
        y: root.topPadding + root.availableHeight / 2 - height / 2
        // Desktop: a small light pill. Touch keeps the round accent knob.
        width: Theme.touchUi ? Theme.iconSizeMd : 8
        height: Theme.touchUi ? Theme.iconSizeMd : 12
        radius: Theme.touchUi ? width / 2 : 2
        color: Theme.touchUi
               ? (root.pressed ? Theme.panelSecondaryForeground
                               : (root.hovered ? Qt.lighter(Theme.primary, 1.25) : Qt.lighter(Theme.primary, 1.15)))
               : (root.pressed || root.hovered ? Theme.panelAccentForeground : Theme.panelForeground)
        border.width: Theme.touchUi || root.visualFocus ? Theme.borderWidthFocus : 0
        border.color: root.visualFocus ? Theme.focusRing : Theme.primaryForeground
        // Grows slightly on hover so the grab target is legible.
        scale: root.pressed ? 1.1 : (root.hovered || root.visualFocus ? 1.05 : 1.0)

        Behavior on x {
            enabled: !root.pressed
            NumberAnimation { duration: Theme.durationFast; easing.type: Theme.easingInOut }
        }
        Behavior on color {
            ColorAnimation { duration: Theme.durationFast; easing.type: Theme.easing }
        }
        Behavior on scale {
            NumberAnimation { duration: Theme.durationFast; easing.type: Theme.easing }
        }
    }

    ThemedToolTip {
        parent: root.handle
        visible: root.showValueTooltip && (root.pressed || root.hovered)
        // No reveal delay while dragging — the readout must track the handle.
        delay: root.pressed ? 0 : Theme.tooltipDelay
        text: root.valueFormatter(root.value)
    }

    onMoved: {
        if (!pressed)
            return
        const span = to - from
        if (span <= 0)
            return
        // Magnet at neutral: within 1.5% of the range the value lands exactly on zero.
        if (zeroCrossing && snapToZero && value !== 0 && Math.abs(value) <= span * 0.015)
            value = 0
        const t = (value - from) / span
        if (t <= 0.002) {
            if (!_hapticMin) {
                Haptics.boundary()
                _hapticMin = true
            }
        } else {
            _hapticMin = false
        }
        if (t >= 0.998) {
            if (!_hapticMax) {
                Haptics.boundary()
                _hapticMax = true
            }
        } else {
            _hapticMax = false
        }
        // Discrete sliders tick every step; continuous ones tick at the quarters
        // so a long drag still has a rhythm without grinding.
        const notch = stepSize > 0
                      ? Math.round((value - from) / stepSize)
                      : Math.round(t * 4)
        if (notch === _hapticNotch)
            return
        const prev = _hapticNotch
        _hapticNotch = notch
        if (prev >= 0 && !_hapticMin && !_hapticMax)
            Haptics.detent()
    }

    // Cursor-only overlay. Must forward wheel when inside a scrollable Flickable:
    // MouseArea eats wheel by default, and rejecting it lets Slider::wheelEvent
    // change the value instead of scrolling the panel (Audio/Effects tabs).
    MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.NoButton
        cursorShape: root.enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
        onWheel: (wheel) => {
            const flick = root.findFlickable(root.parent)
            const maxY = flick ? Math.max(0, flick.contentHeight - flick.height) : 0
            if (!flick || maxY <= 0) {
                wheel.accepted = false
                return
            }
            const dy = wheel.pixelDelta.y !== 0 ? wheel.pixelDelta.y
                                                : wheel.angleDelta.y / 8
            flick.contentY = Math.max(0, Math.min(maxY, flick.contentY - dy))
            wheel.accepted = true
        }
    }
}
