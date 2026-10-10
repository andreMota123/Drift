pragma Singleton
import QtQuick
import Drift

// Design tokens for the app shell and panel surfaces (dark + light), plus
// shared layout/typography/iconography constants used across the UI.
//
// Control chrome (buttons, inputs, chips, dialogs) lives in
// src/qml/components/Themed*.qml — use those; do not re-skin Qt controls inline.
QtObject {
    id: theme


    // --- Platform keyboard shortcuts -----------------------------------------
    // Shortcut strings stored by EditorState use a portable/canonical notation:
    //
    //   Ctrl  = primary application accelerator
    //           Command on macOS, Control on Windows/Linux
    //
    // This keeps project/settings data portable while the UI and actual Shortcut
    // objects follow the conventions of the operating system.
    readonly property bool isMacOS: Qt.platform.os === "osx"
    readonly property bool isWindows: Qt.platform.os === "windows"
    readonly property bool isLinux: Qt.platform.os === "linux"

    function nativeShortcutSequence(sequence) {
        // Qt already performs the native Apple modifier mapping:
        //
        //   Ctrl -> Command (⌘)
        //   Meta -> physical Control (⌃)
        //   Alt  -> Option (⌥)
        //
        // Therefore the canonical shortcut string must be passed through
        // unchanged. Converting Ctrl to Meta here would incorrectly turn
        // Command shortcuts into physical Control shortcuts on macOS.
        return sequence
    }

    function shortcutDisplay(sequence) {
        if (!sequence || sequence.length === 0)
            return ""

        if (!isMacOS)
            return sequence

        const parts = sequence.split("+")

        let control = false
        let option = false
        let shift = false
        let command = false
        let key = ""

        for (let i = 0; i < parts.length; ++i) {
            const part = parts[i]

            // Qt's native Apple mapping:
            // Ctrl = Command, Meta = physical Control.
            if (part === "Ctrl")
                command = true
            else if (part === "Meta")
                control = true
            else if (part === "Alt")
                option = true
            else if (part === "Shift")
                shift = true
            else
                key = part
        }

        const keySymbols = {
            "Left": "←",
            "Right": "→",
            "Up": "↑",
            "Down": "↓",
            "Backspace": "⌫",
            "Delete": "⌦",
            "Escape": "⎋",
            "Return": "↩",
            "Enter": "⌅"
        }

        if (keySymbols[key] !== undefined)
            key = keySymbols[key]

        // Ordem visual tradicional da Apple.
        return (control ? "⌃" : "")
             + (option ? "⌥" : "")
             + (shift ? "⇧" : "")
             + (command ? "⌘" : "")
             + key
    }

    function platformShortcutText(text) {
        if (!text || !isMacOS)
            return text

        // Used for prose/tooltips such as "Ctrl+scroll" and
        // "Shift for 5s", preserving the translated sentence itself.
        return text
            .replace(/Ctrl/g, "⌘")
            .replace(/Alt/g, "⌥")
            .replace(/Shift/g, "⇧")
            .replace(/Meta/g, "⌘")
    }

    function primaryModifierPressed(modifiers) {
        // On macOS Qt maps Command to ControlModifier by default.
        // On Windows/Linux this is the physical Control key.
        return (modifiers & Qt.ControlModifier) !== 0
    }


    // One loader per file: the UI ships static Inter instances under the family "Inter UI",
    // so the Essential Fonts addon's "Inter" cannot shadow them whichever registers last.
    property FontLoader _interRegular: FontLoader { source: "qrc:/qt/qml/Drift/resources/fonts/InterUI-Regular.ttf" }
    property FontLoader _interMedium: FontLoader { source: "qrc:/qt/qml/Drift/resources/fonts/InterUI-Medium.ttf" }
    property FontLoader _interSemiBold: FontLoader { source: "qrc:/qt/qml/Drift/resources/fonts/InterUI-SemiBold.ttf" }
    property FontLoader _interBold: FontLoader { source: "qrc:/qt/qml/Drift/resources/fonts/InterUI-Bold.ttf" }
    property FontLoader _interItalic: FontLoader { source: "qrc:/qt/qml/Drift/resources/fonts/InterUI-Italic.ttf" }

    readonly property string fontFamily: _interRegular.name || "sans-serif"
    readonly property string monoFontFamily: "monospace"

    // --- Light/dark mode: follows the OS until the user picks a side -----------
    // Qt.styleHints.colorScheme is live-updated by the platform theme (Qt 6.5+).
    // Once toggled, the choice lives in QSettings via EditorState and survives
    // restarts; it is app-wide, not stored per project.
    readonly property bool systemPrefersDark: Qt.styleHints.colorScheme !== Qt.Light
    readonly property bool darkMode: EditorState.darkModeOverridden ? EditorState.darkModePreferred
                                                                    : systemPrefersDark

    function toggleDarkMode() {
        EditorState.setDarkModePreference(!darkMode);
    }

    function setDarkMode(enabled) {
        EditorState.setDarkModePreference(enabled);
    }

    // --- Color palettes: app shell vs. panel surfaces, light and dark ------------
    readonly property var _dark: ({
        appBackground: "#000000",
        foreground: "#e0e0e0",
        border: "#262626",
        accent: "#262626",
        accentForeground: "#fafafa",
        mutedForeground: "#949494",
        popoverHover: "#303030",
        panelBackground: "#141414",
        panelForeground: "#e0e0e0",
        panelBorder: "#262626",
        panelAccent: "#262626",
        panelAccentForeground: "#fafafa",
        panelMuted: "#3b3b3b",
        panelSecondaryBg: "#213539",
        panelSecondaryBorder: "#004d52",
        panelSecondaryForeground: "#4adfe9"
    })
    readonly property var _light: ({
        appBackground: "#ffffff",
        foreground: "#1c1c1c",
        border: "#e8e8e8",
        accent: "#f5f5f5",
        accentForeground: "#050505",
        mutedForeground: "#7a7a7a",
        popoverHover: "#f5f5f5",
        panelBackground: "#f9fafb",
        panelForeground: "#212121",
        panelBorder: "#dedede",
        panelAccent: "#ededed",
        panelAccentForeground: "#0d0d0d",
        panelMuted: "#d4d4d4",
        panelSecondaryBg: "#dff8fa",
        panelSecondaryBorder: "#a3e9ee",
        panelSecondaryForeground: "#007882"
    })
    readonly property var _palette: darkMode ? _dark : _light

    // --- Colors: app shell ---------------------------------------------------
    readonly property color appBackground: _palette.appBackground
    readonly property color foreground: _palette.foreground
    readonly property color border: _palette.border
    readonly property color accent: _palette.accent
    readonly property color accentForeground: _palette.accentForeground
    readonly property color mutedForeground: _palette.mutedForeground
    readonly property color popoverHover: _palette.popoverHover

    // --- Colors: panel surfaces ------------------------------------------------
    readonly property color panelBackground: _palette.panelBackground
    readonly property color panelForeground: _palette.panelForeground
    readonly property color panelBorder: _palette.panelBorder
    readonly property color panelAccent: _palette.panelAccent
    readonly property color panelAccentForeground: _palette.panelAccentForeground
    readonly property color panelMuted: _palette.panelMuted
    // Slider groove — lighter than panelMuted in dark mode so the track reads at rest.
    readonly property color sliderTrack: darkMode ? "#4f4f4f" : panelMuted
    // Scrollbar track + handle (timeline horizontal bar, panel flickables).
    readonly property color scrollbarTrack: darkMode ? "#1c1c1c" : panelBorder
    readonly property color scrollbarHandle: darkMode ? "#4f4f4f" : panelMuted
    readonly property color scrollbarHandleHover: darkMode ? "#636363" : mutedForeground
    readonly property color scrollbarHandlePressed: darkMode ? "#b8b8b8" : foreground
    // Bottom-sheet drag pill. panelBorder put it at 1.28:1 against the sheet in both
    // themes, so the one affordance saying "this sheet moves" was invisible; these
    // clear the 3:1 non-text floor (3.1:1 dark, 3.0:1 light).
    readonly property color sheetHandle: darkMode ? "#6a6a6a" : "#919191"
    readonly property color panelSecondaryBg: _palette.panelSecondaryBg
    readonly property color panelSecondaryBorder: _palette.panelSecondaryBorder
    readonly property color panelSecondaryForeground: _palette.panelSecondaryForeground

    // --- Colors: shared semantic (identical in both themes) -----------------------
    readonly property color primary: "#00C1CD"
    readonly property color primaryForeground: "#00191B"
    // `primary` as a *foreground* on a panel surface. The brand accent is a fill
    // colour: on the light panel it lands at 1.69:1, so a selected tab tinted with
    // it was effectively invisible. Dark mode keeps the accent; light mode
    // uses the darkened brand tone. Only for text/glyphs on panels —
    // fills, rings and progress arcs still use `primary` in both themes.
    readonly property color accentOnPanel: darkMode ? primary : "#007882"
    readonly property color destructive: "#ff303d"
    readonly property color constructive: "#23d160"
    readonly property color warning: "#f2c921"

    // Keyboard focus indicator. Shared by every focusable control so a Tab pass
    // reads as one system regardless of which control has focus.
    readonly property color focusRing: primary

    // Export CTA gradient stops (the documented inline-color exception, sourced
    // from here so the button still tracks the token system).
    readonly property color exportGradientTop: "#00C1CD"
    readonly property color exportGradientBottom: "#00C1CD"
    readonly property color exportGlow: "#00C1CD"

    // Scrims/overlays drawn over media (clip name bands, preview letterbox,
    // thumbnail duration badges). Fixed regardless of app theme because they sit
    // on photographic content, not on panel surfaces.
    readonly property color scrimColor: "#00000066"
    readonly property color scrimStrong: "#000000b3"
    readonly property color overlayColor: "#000000"
    // Guides and handles drawn on top of preview media.
    readonly property color guideStrong: "#99ffffff"
    readonly property color guideMedium: "#80ffffff"
    readonly property color guideWeak: "#66ffffff"
    readonly property color onMedia: "#ffffff"
    // Timeline snap indicator.
    readonly property color snapGuide: "#f5c542"
    // Gaps a "close gap" action is about to remove.
    readonly property color gapHighlight: darkMode ? "#33ffffff" : "#33000000"
    // Async placeholder fill for thumbnails, filmstrips and waveforms.
    readonly property color skeletonColor: darkMode ? "#262626" : "#e8e8e8"
    readonly property color skeletonHighlight: darkMode ? "#303030" : "#f5f5f5"

    // --- Colors: timeline clip types (fixed regardless of app theme) ---------------
    readonly property color clipText: "#5DBAA0"
    readonly property color clipSubtitle: "#4A9FD4"
    readonly property color clipAudio: "#8F5DBA"
    readonly property color clipGraphic: "#BA5D7A"
    readonly property color clipEffect: "#5d93ba"
    // Adjustment layers, tinted by what they act on so a glance at the lane says which it is.
    // The video one is clipEffect itself, which is the colour adjustments have always had.
    readonly property color clipAdjustmentVideo: clipEffect
    readonly property color clipAdjustmentAudio: "#9B6BC9"
    readonly property color clipAdjustmentMask: "#BA9B5D"
    readonly property color transitionOverlap: "#9B5DE5"
    readonly property color waveformColor: "#ffffffb3" // rgba(255,255,255,0.7) — on dark clip chrome
    // Waveform drawn on panel surfaces (subtitle cue lane, etc.): follows light/dark FG.
    readonly property color panelWaveformColor: darkMode ? "#ffffffb3" : "#212121b3"
    // Detected beat grid in the keyframe strip. Bar lines get the stronger alpha; the
    // beats between them the weaker one, so the metre reads at a glance without the grid
    // competing with the keyframe curves drawn on top of it.
    readonly property color beatBarColor: darkMode ? "#7ac8ff8c" : "#1f6fb24d"
    readonly property color beatGridColor: darkMode ? "#7ac8ff47" : "#1f6fb230"
    // Transients that do not land on the grid — drawn as short vertically-centered bars.
    readonly property color beatOnsetColor: darkMode ? "#ffffff8c" : "#2121218c"
    // Video clips normally show real thumbnails (always photographic/dark-ish); until
    // thumbnail generation exists, use a fixed dark placeholder so the white filename
    // scrim stays legible in light mode too instead of following panelAccent.
    readonly property color clipVideoPlaceholder: "#2b2b2b"
    // The band around a letterboxed preview canvas. Fixed dark in both themes: it frames
    // photographic content, and following appBackground made it a white surround in light
    // mode with the video floating in the middle of it.
    //
    // Mid-grey rather than the near-black it was: an empty canvas, a letterboxed clip and a
    // dark frame all render close to black, so at #101010 there was nothing on screen saying
    // where the canvas ended and the surround began. Still dark enough to frame video without
    // competing with it.
    readonly property color previewLetterbox: "#333333"
    // Style-pack thumbnails: most packs use white/light glyphs (and sit on video), so the
    // card canvas stays dark in both themes — panelSecondaryBg washes them out in light mode.
    readonly property color textStylePreviewBg: "#1c1c1c"
    readonly property color textStylePreviewBorder: darkMode ? "#3a3a3a" : "#2a2a2a"

    // --- Colors: keyframe curves (fixed regardless of app theme) -------------
    // One hue per animatable property so overlaid curves, their key diamonds and
    // their gutter chips all read as the same series. Chosen for separation at
    // 1.5px stroke width on both panel backgrounds.
    readonly property var keyframeCurveColors: ({
        "x": "#16a9f3",
        "y": "#f59e0b",
        "width": "#23d160",
        "height": "#e879f9",
        "rotation": "#f43f5e",
        "opacity": "#a78bfa",
        "volume": "#2dd4bf"
    })
    // Effect parameters are open-ended ("fx.<index>.<key>"), so they can't have named entries
    // above. Hashing the prop into this ramp keeps each one a stable, distinct color across
    // sessions instead of drawing every effect curve in the same accent.
    readonly property var keyframeCurveRamp: [
        "#38bdf8", "#fb923c", "#4ade80", "#c084fc",
        "#fb7185", "#facc15", "#2dd4bf", "#818cf8"
    ]
    function keyframeCurveColor(prop) {
        if (keyframeCurveColors[prop])
            return keyframeCurveColors[prop]
        let hash = 0
        for (let i = 0; i < prop.length; ++i)
            hash = (hash * 31 + prop.charCodeAt(i)) & 0x7fffffff
        return keyframeCurveRamp[hash % keyframeCurveRamp.length]
    }

    // --- Radius --------------------------------------------------------------
    readonly property real radiusSm: touchUi ? 5.6 : 4
    readonly property real radiusMd: touchUi ? 10.4 : 8
    readonly property real radiusLg: touchUi ? 13.12 : 12
    readonly property real radiusXs: touchUi ? 3 : 2    // badges, tick marks, hairline chrome
    readonly property real radiusPill: 999

    // --- Spacing scale ---------------------------------------------------------
    // Every gap/margin/padding in the app should come from here. Values are the
    // ones already in de-facto use, deduplicated into a scale.
    readonly property real spacingXs: 2
    readonly property real spacingSm: 4
    readonly property real spacingMd: 6
    readonly property real spacingLg: 8
    readonly property real spacingXl: 12
    readonly property real spacing2xl: 16
    readonly property real spacing3xl: 24

    // --- Control metrics -------------------------------------------------------
    // controlHeight is the alignment baseline: text fields, combo boxes and text
    // buttons all share it so adjacent controls in a Row line up.
    //
    // The panels, inspectors and browsers are shared with the desktop build, and every
    // one of them sizes its controls from these three tokens. Rather than fork each
    // component for touch, the tokens themselves grow on Android: a 28px icon button
    // sized for a mouse cursor is roughly a third of a fingertip, which made destructive
    // controls (Remove sitting beside Disable in the effects list) genuinely risky.
    // 44/36/40 are Android's minimum comfortable targets, not arbitrary bumps.
    // Two independent axes, deliberately not one boolean.
    //
    //   sizeClass  — how much room there is. Drives which shell runs and whether a layout
    //                collapses to a single pane. A narrow window on a desktop is "compact".
    //   touchInput — what is pointing at it. Drives hit-target growth. A touchscreen laptop
    //                at 1400dp is touch but not compact; a 500dp mouse-driven window is the
    //                reverse. Conflating them is why touchUi ended up meaning three things.
    //
    // liftDragRequired is derived rather than a third axis: a platform DragHandler cannot
    // leave a bottom sheet, and the sheet is a consequence of being compact, not of being
    // touched — so a mouse user in the compact shell needs the lift gesture too.
    property real windowWidth: 0                        // pushed by the root window
    property string sizeClassOverride: ""               // "compact" | "medium" | "expanded"
    property string inputModeOverride: ""               // "touch" | "pointer"

    readonly property string sizeClass: sizeClassOverride.length > 0 ? sizeClassOverride
                                      : windowWidth <= 0 ? (Qt.platform.os === "android" ? "compact" : "expanded")
                                      : windowWidth < 600 ? "compact"
                                      : windowWidth < 840 ? "medium"
                                      : "expanded"
    readonly property bool compact: sizeClass === "compact"

    readonly property bool pointerPrimary: inputModeOverride.length > 0
                                         ? inputModeOverride === "pointer"
                                         : !(Qt.platform.os === "android" || Qt.platform.os === "ios")
    readonly property bool touchInput: !pointerPrimary
    readonly property bool liftDragRequired: touchInput || compact

    // Retained as an alias so the ~25 existing call sites keep compiling while they are
    // migrated to touchInput / compact / liftDragRequired one surface at a time.
    readonly property bool touchUi: touchInput
    readonly property real controlHeight: touchUi ? 44 : 22
    readonly property real controlHeightSm: touchUi ? 36 : 20   // chips, segmented toggles
    readonly property real iconButtonSize: touchUi ? 40 : 24
    readonly property real borderWidth: 1
    readonly property real borderWidthFocus: 2

    // --- Icon sizes ------------------------------------------------------------
    readonly property real iconSizeSm: 12
    readonly property real iconSizeMd: 14
    readonly property real iconSizeBase: 16
    readonly property real iconSizeLg: 18
    readonly property real iconSizeXl: 22

    // --- Motion ----------------------------------------------------------------
    // durationFast: hover/press tints. durationBase: dialogs, tab crossfades.
    // durationSlow: layout-affecting reveals. durationPress: press feedback.
    readonly property int durationFast: 90
    readonly property int durationBase: 140
    readonly property int durationSlow: 220
    readonly property int durationPress: 120
    // Strong ease-out (~cubic-bezier(0.22, 1, 0.36, 1)) for anything entering or
    // leaving: it starts fast, so the interface answers in the frame the user is
    // watching. OutCubic was too weak to read as deliberate.
    readonly property int easing: Easing.OutQuint
    // Strong ease-in-out (~cubic-bezier(0.76, 0, 0.24, 1)) for things already on
    // screen that move or morph, where a fast start reads as a jerk.
    readonly property int easingInOut: Easing.InOutQuart
    // Press feedback: pressable chrome dips to this scale while held.
    readonly property real pressScale: 0.97
    readonly property int tooltipDelay: 400

    // --- Dialog widths ---------------------------------------------------------
    readonly property real dialogWidthSm: 340
    readonly property real dialogWidthMd: 420
    readonly property real dialogWidthLg: 660
    // Minimum breathing room between a dialog and the window edge.
    readonly property real dialogMargin: 32

    // --- Typography ------------------------------------------------------------
    readonly property real fontSizeXs: touchUi ? 11.52 : 10
    readonly property real fontSizeSm: touchUi ? 12.64 : 11
    readonly property real fontSizeBase: touchUi ? 14.72 : 12
    readonly property real fontSizeTiny: 9.6   // 0.6rem clip captions
    readonly property real fontSizeTick: 10    // literal 10px ruler tick labels
    readonly property real fontSizeCard: touchUi ? 11.2 : 10  // 0.7rem asset card filenames

    // --- Layout: chrome ------------------------------------------------------
    readonly property real headerHeight: touchUi ? 54.4 : 36
    readonly property real panelGap: 3
    readonly property real pagePadding: 12

    // --- Layout: assets panel -----------------------------------------------
    readonly property real panelHeaderHeight: touchUi ? 52 : 42
    readonly property real tabRailWidth: touchUi ? 52 : 40
    // Assets panel top tab bar: icon over label.
    readonly property real tabBarHeight: touchUi ? 56 : 42
    readonly property real tabBarItemMinWidth: touchUi ? 60 : 48
    readonly property real assetCardWidth: 112
    readonly property real assetCardGap: 16

    // Tint for category chips in asset browser tabs.
    readonly property var categoryColors: [
        "#f59e0b", "#ef4444", "#8b5cf6", "#3b82f6", "#10b981",
        "#ec4899", "#06b6d4", "#84cc16", "#f97316", "#6366f1"
    ]

    function categoryColor(index) {
        const colors = categoryColors
        if (!colors || colors.length === 0)
            return primary
        return colors[Math.abs(index) % colors.length]
    }

    // --- Layout: preview panel -----------------------------------------------
    readonly property real previewToolbarPaddingTop: 20
    readonly property real previewToolbarPaddingBottom: 12

    // --- Layout: timeline ------------------------------------------------------
    readonly property real timelineToolbarHeight: touchUi ? 40 : 32
    // Tall enough to be an easy seek/scrub hit target (CapCut/Premiere-style).
    readonly property real timelineRulerHeight: 28
    readonly property real timelineBookmarkRowHeight: 18
    readonly property real trackHeightVideo: touchUi ? 65 : 62
    // The main (bottom) video track is taller than the overlay tracks above it.
    readonly property real trackHeightVideoMain: touchUi ? 65 : 76
    readonly property real trackHeightAudio: 50
    readonly property real trackHeightText: touchUi ? 44 : 24
    readonly property real trackHeightSubtitle: touchUi ? 44 : 24
    readonly property real trackHeightShape: 50
    // An adjustment carries no picture and no waveform — just the list of effects in it — so it
    // needs a label's worth of room, not a video track's.
    readonly property real trackHeightAdjustment: touchUi ? 40 : 28
    // One nested adjustment lane, drawn as a strip across the top of its parent's row. Roughly
    // 30% of a video track, which is where a track with a single lane lands — a percentage per
    // lane instead would make a track with three of them nearly twice its natural height.
    // 20px lanes came out at 12-14dp of usable strip on a phone once the row borders were
    // taken off — under half the touch floor for the toggles that live in them.
    readonly property real adjustmentLaneHeight: touchUi ? 24 : 20
    readonly property real trackGap: touchUi ? 6 : 4
    // Invisible hit area above tracks (no visible UI) for new-track drops when timeline has clips.
    readonly property real newTrackHitSlop: 24
    readonly property real trackLabelsWidth: touchUi ? 130 : 152
    readonly property real pixelsPerSecondBase: 50
    // Empty runway after the last clip: fixed in pixels at every zoom (not a
    // fixed number of seconds). Sized as a fraction of the timeline viewport.
    readonly property real timelineEndPadFraction: 0.25
    readonly property real timelineEndPadMinPx: 120
    readonly property real playheadLineWidth: 2
    // Top scrubber head — sized to sit in the seek strip and stay easy to grab.
    readonly property real playheadHandleSize: 16
    readonly property real playheadSeekGrabWidth: 18
    readonly property real clipSelectionRingWidth: 1.5
    // Name band across the top of a clip. Clamped against track height at the use
    // site so it never swallows a short (25px text/subtitle) row.
    readonly property real clipHeaderBandHeight: 20
    readonly property real clipTrimHandleWidth: 12
    // Floor for a selected clip's on-timeline width so it never shrinks to a
    // sliver. Sized for two trim handles plus a move strip between them.
    readonly property real clipMinInteractiveWidth: 28
    readonly property real clipMinWidth: clipMinInteractiveWidth * 2
    // Matches drift::kMinClipDurationUs (0.1s). Effective min duration is the
    // larger of this and clipMinWidth / pxPerSecond at the current zoom.
    readonly property real clipMinDurationSeconds: 0.1

    // --- Layout: Android / touch -----------------------------------------------
    // Used by AndroidMain / AndroidTimeline / AndroidPreview and the CapCut shell.
    // Desktop chrome keeps the metrics above.
    readonly property real androidIconButtonSize: 48
    readonly property real androidTimelineToolbarHeight: 56
    readonly property real androidPreviewTransportHeight: 56
    readonly property real androidTopBarHeight: 56
    // Four destinations plus the centred Add button. Taller than the old scrolling
    // strip because the Add button is a 48dp target that has to sit inside it.
    readonly property real androidBottomRailHeight: 64
    // Contextual clip toolbar. Taller than the 56dp strip it replaces because its slots
    // are glyph-over-caption, like the rail below it.
    readonly property real androidClipToolbarHeight: 64
    readonly property real androidSplitterHeight: 32
    readonly property real androidSheetHeightFraction: 0.50
    readonly property real androidSheetExpandedFraction: 0.92
    readonly property real androidSheetHeaderHeight: 56
    readonly property real androidSheetDismissFraction: 0.38
    // Hold before an asset card lifts out of the sheet for a drag. Shorter than the
    // 800ms platform long-press: the tap it competes with only opens a menu, and a
    // gesture that has to be held for most of a second reads as an unresponsive app.
    readonly property int touchLiftInterval: 320
    // The rail's five slots divide its width, so destinations have no fixed width.
    // The Add button is the one that does: a docked-FAB-sized target in the centre.
    readonly property real androidRailFabSize: 48
    // Add-menu row. A token rather than a literal because the sheet computes its own
    // height from the row count, and the two must not drift apart.
    readonly property real androidAddRowHeight: 64
    // Mute/hide icons only — track type labels do not fit a phone. Wide enough for the
    // two toggles to sit a dead band apart without their hit areas reaching the type
    // caption on the left or the corner filmstrip toggle below it.
    readonly property real androidTrackLabelsWidth: 88
    // The fixed centre line. Thinner than the desktop playhead: it is always on screen and
    // always over content, so it marks the frame rather than announcing itself.
    readonly property real androidPlayheadCentreWidth: 2
    readonly property real androidClipTrimHandleWidth: 20
    readonly property real androidClipEdgeMargin: 22
    readonly property real androidTrimHotspotExtra: 14
    // Preview region held between a floor and a ceiling. The pane is sized from the project
    // aspect, but only within this band: below the floor the canvas letterboxes inside the
    // pane instead of the pane shrinking, so the transport row's y stays put between the
    // editor, crop mode and a sheet being open.
    readonly property real androidPreviewMaxScreenFraction: 0.50
    readonly property real androidPreviewMinFraction: 0.34
    // Compact-width layout margin. Deliberately NOT the shared pagePadding (12): raising that
    // would move every desktop panel, and 16 is the Material compact figure.
    readonly property real androidPagePadding: 16
    // The 48dp floor and the 8dp separation rule, named so call sites state the intent rather
    // than reaching for whichever spacing token happens to be the right number today.
    readonly property real androidMinTouchTarget: 48
    readonly property real androidTouchGap: 8
    // Template card in the canvas sheet. A portrait card so a 9:16 swatch — what most phone
    // projects are — fills it rather than sitting as a sliver in a landscape box.
    readonly property real androidLayoutCardWidth: 88
    readonly property real androidLayoutCardHeight: 112
    readonly property real androidHomeTileHeight: 96
    readonly property real androidHomeRecentCardWidth: 140
    readonly property real androidHomeRecentCardHeight: 96


    // --- Layout: window --------------------------------------------------------
    // Floor for ApplicationWindow. Below this the split minimums cannot all be
    // satisfied and panels start overlapping.
    readonly property real windowMinimumWidth: 900
    readonly property real windowMinimumHeight: 560

    // --- Iconography (Lucide SVGs in resources/icons/; ISC-licensed, see
    // resources/licenses/LICENSE-lucide.txt) ------------------------------------
    // Values are Lucide icon file names (without .svg).
    readonly property var icons: ({
        scissors: "scissors",
        chevronsLeft: "chevrons-left",
        chevronsRightLeft: "chevrons-right-left",
        undo: "undo",
        redo: "redo",
        clipboardPaste: "clipboard-paste",
        copyPlus: "copy-plus",
        copy: "copy",
        trash: "trash-2",
        snowflake: "snowflake",
        bookmark: "bookmark",
        repeat: "repeat",
        star: "star",
        layers: "layers",
        split: "split",
        magnet: "magnet",
        link: "link",
        linkTwo: "link-2",
        unlink: "unlink-2",
        foldHorizontal: "fold-horizontal",
        mainTrackMagnet: "main-track-magnet",
        mainTrackMagnetOff: "main-track-magnet-off",
        zoomOut: "zoom-out",
        zoomIn: "zoom-in",
        zoomFit: "chevrons-left-right-ellipsis",
        gauge: "gauge",
        play: "play",
        pause: "pause",
        stepBack: "step-back",
        stepForward: "step-forward",
        rewind: "rewind",
        fastForward: "fast-forward",
        maximize: "maximize",
        locateFixed: "locate-fixed",
        minimize: "minimize",
        folder: "folder",
        folderInput: "folder-input",
        folderOutput: "folder-output",
        headphones: "headphones",
        type: "type",
        smile: "smile",
        wand: "wand-sparkles",
        sparkles: "sparkles",
        sliders: "sliders-horizontal",
        settings: "settings",
        upload: "upload",
        plus: "plus",
        volumeHigh: "volume-2",
        volumeOff: "volume-off",
        eye: "eye",
        eyeOff: "eye-off",
        film: "film",
        video: "video",
        music: "music",
        audioLines: "audio-lines",
        image: "image",
        shapes: "shapes",
        chevronDown: "chevron-down",
        chevronUp: "chevron-up",
        chevronsRight: "chevrons-right",
        x: "x",
        messageSquare: "message-square",
        moon: "moon",
        sun: "sun",
        grid: "grid-3x3",
        // The media bin's grid toggle; grid-3x3 above still marks the layout
        // pickers and the preview overlay's guide grid.
        layoutGrid: "layout-grid",
        list: "list",
        listTree: "list-tree",
        sortByName: "arrow-down-a-z",
        sortByKind: "tags",
        gripVertical: "grip-vertical",
        ellipsis: "ellipsis",
        menu: "menu",
        save: "save",
        setStart: "arrow-left-to-line",
        setEnd: "arrow-right-to-line",
        // Timeline trim tools — vertical align marks read as “keep from here”.
        trimStart: "align-start-vertical",
        trimEnd: "align-end-vertical",
        blend: "blend",
        option: "option",
        keyboard: "keyboard",
        crop: "crop",
        diamondPlus: "diamond-plus",
        diamondMinus: "diamond-minus",
        mask: "square-dashed",
        puzzle: "puzzle",
        bug: "bug",
        bot: "bot",
        languages: "languages",
        shuffle: "shuffle",
        info: "info",
        package: "package",
        store: "store",
        gem: "gem",
        fileText: "file-text",

        // Status / feedback
        warning: "triangle-alert",
        success: "circle-check",
        error: "circle-x",
        spinner: "loader-circle",
        refresh: "refresh-cw",
        download: "download",

        // Affordances
        reset: "rotate-ccw",
        search: "search",
        chevronRight: "chevron-right",
        chevronLeft: "chevron-left",
        check: "check",
        pencil: "pencil",
        clock: "clock",
        lock: "lock",
        lockOpen: "lock-open",
        moveHorizontal: "move-horizontal",
        // CapCut-style select/pointer tool (exit cut modes)
        mousePointer: "mouse-pointer",

        // Text alignment
        alignLeft: "text-align-start",
        alignCenter: "text-align-center",
        alignRight: "text-align-end",
        // Lucide names these *-horizontal, but they are the correct valign glyphs.
        alignTop: "align-start-horizontal",
        alignMiddle: "align-center-horizontal",
        alignBottom: "align-end-horizontal",

        // Media
        captions: "captions",
        listVideo: "list-video",
        // Lane height on the phone edit strip: list + chevrons collapsing /
        // expanding, not foldVertical (those keys were never registered).
        listChevronsDownUp: "list-chevrons-down-up",
        listChevronsUpDown: "list-chevrons-up-down",
        smartphone: "smartphone",
        monitor: "monitor",
        square: "square",
        ratio: "ratio",

        // Brand marks (layout chooser)
        brandYoutube: "brand-youtube",
        brandInstagram: "brand-instagram",
        brandFacebook: "brand-facebook",
        brandTiktok: "brand-tiktok",
        brandSnapchat: "brand-snapchat",
        brandX: "brand-x",
        brandLinkedin: "brand-linkedin"
    })
}
