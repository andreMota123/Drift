import QtQuick
import QtQuick.Controls.Basic
import QtQuick.Layouts
import Drift

ThemedDialog {
    id: root

    title: qsTr("Export")
    acceptText: qsTr("Export")
    // Two columns on desktop (CapCut-style): a still and a summary of what will be written on
    // the left, the settings on the right. A compact window keeps the single settings column.
    readonly property bool showSummary: !Theme.compact && !Theme.touchUi
    readonly property real summaryWidth: 260
    preferredWidth: showSummary ? Theme.dialogWidthLg + summaryWidth + Theme.spacing2xl
                                : Theme.dialogWidthLg
    property url previewUrl: ""

    // Rough size of the file about to be written. Exact for a fixed bitrate; for constant
    // quality it is a guess from resolution, frame rate and the quality number, good to tell
    // 50 MB from 500 MB and no better.
    readonly property real estimatedMegabytes: {
        const seconds = root.exportWorkAreaOnly
                        ? Math.max(0, EditorState.workAreaOutSeconds - EditorState.workAreaInSeconds)
                        : EditorState.durationSeconds
        if (seconds <= 0)
            return 0
        const audioKbps = root.audioBitrateKbps > 0 ? root.audioBitrateKbps : 192
        if (root.exportMode === "audio")
            return audioKbps * seconds / 8 / 1024
        let videoKbps = root.videoBitrateKbps
        if (root.rateControl === "crf" || root.exportMode === "gif") {
            const h = root.targetHeight > 0 ? root.targetHeight : EditorState.projectHeight()
            const w = h * EditorState.projectWidth() / Math.max(1, EditorState.projectHeight())
            const fps = root.fpsNum > 0 ? root.fpsNum / Math.max(1, root.fpsDen) : EditorState.projectFps()
            videoKbps = w * h * fps * 0.07 * Math.pow(2, (23 - root.crf) / 6) / 1000
            if (root.videoCodecId !== "h264")
                videoKbps *= 0.65
        }
        return (videoKbps + audioKbps) * seconds / 8 / 1024
    }

    function formatSize(mb) {
        if (mb <= 0)
            return "—"
        return mb >= 1024 ? qsTr("about %1 GB").arg((mb / 1024).toFixed(1))
                          : qsTr("about %1 MB").arg(Math.max(1, Math.round(mb)))
    }

    function formatDuration(seconds) {
        const total = Math.max(0, Math.round(seconds))
        const pad = (n) => (n < 10 ? "0" : "") + n
        return pad(Math.floor(total / 3600)) + ":" + pad(Math.floor((total % 3600) / 60)) + ":" + pad(total % 60)
    }

    property string exportMode: "video" // "video" | "audio" | "gif"
    property string scaleId: "source"
    property int targetHeight: 0
    property int videoBitrateKbps: 12000
    property string videoCodecId: "h264"
    property string rateControl: "crf"
    property int crf: 18
    property string videoPreset: "medium"
    property string audioCodecId: "aac"
    property int audioBitrateKbps: 192
    property bool advancedOpen: false
    property bool exportWorkAreaOnly: false

    // Export frame rate. fpsNum 0 means "follow the project fps". Rational so the
    // NTSC rates (30000/1001 and friends) survive the round-trip.
    property string frameRateId: "project"
    property int fpsNum: 0
    property int fpsDen: 1
    property var frameRateOptions: []
    readonly property bool frameRateCustom: frameRateId === "custom"

    // Bitrate combo: preset kbps values, or "custom"
    property string audioBitrateChoice: "192"
    readonly property var audioBitratePresets: [96, 128, 160, 192, 256, 320]
    readonly property var audioBitrateModel: [
        { label: qsTr("96 kbps"), value: "96" },
        { label: qsTr("128 kbps"), value: "128" },
        { label: qsTr("160 kbps"), value: "160" },
        { label: qsTr("192 kbps"), value: "192" },
        { label: qsTr("256 kbps"), value: "256" },
        { label: qsTr("320 kbps"), value: "320" },
        { label: qsTr("Custom"), value: "custom" }
    ]

    property var videoCodecs: []
    property var audioCodecs: []
    property var scaleOptions: []
    property var currentVideoCodec: ({})
    property var currentAudioCodec: ({})

    readonly property bool videoLossless: !!(currentVideoCodec && currentVideoCodec.lossless)
    readonly property bool videoSupportsCrf: !!(currentVideoCodec && currentVideoCodec.supportsCrf)
    readonly property bool videoSupportsBitrate: !!(currentVideoCodec && currentVideoCodec.supportsBitrate)
    readonly property bool videoSupportsPreset: !!(currentVideoCodec && currentVideoCodec.supportsPreset)
    readonly property var videoPresetList: (currentVideoCodec && currentVideoCodec.presets) ? currentVideoCodec.presets : []
    readonly property bool audioLossless: !!(currentAudioCodec && currentAudioCodec.lossless)
    readonly property bool isAudioOnly: exportMode === "audio"
    readonly property bool isGifExport: exportMode === "gif"

    function codecById(list, id) {
        for (var i = 0; i < list.length; ++i) {
            if (list[i].id === id)
                return list[i]
        }
        return null
    }

    function firstAvailableId(list, preferred) {
        var pref = codecById(list, preferred)
        if (pref && pref.available)
            return preferred
        for (var i = 0; i < list.length; ++i) {
            if (list[i].available)
                return list[i].id
        }
        return preferred
    }

    // Catalog from the engine plus a Custom… escape hatch for rates not listed.
    readonly property var frameRateModel: {
        var list = []
        for (var i = 0; i < frameRateOptions.length; ++i)
            list.push(frameRateOptions[i])
        list.push({ id: "custom", label: qsTr("Custom…"), fpsNum: 0, fpsDen: 1 })
        return list
    }

    // Picks the catalog entry matching num/den, else "custom" for a hand-typed rate.
    function frameRateIdFor(num, den) {
        if (!(num > 0) || !(den > 0))
            return "project"
        for (var i = 0; i < frameRateOptions.length; ++i) {
            var o = frameRateOptions[i]
            if (o.fpsNum === num && o.fpsDen === den)
                return o.id
        }
        return "custom"
    }

    function applyFrameRateChoice(entry) {
        if (!entry)
            return
        frameRateId = entry.id
        if (entry.id === "custom") {
            // Keep whatever rate was showing; only fall back when following the project.
            if (!(fpsNum > 0)) {
                fpsNum = EditorState.projectFps()
                fpsDen = 1
            }
        } else {
            fpsNum = entry.fpsNum
            fpsDen = entry.fpsDen
        }
    }

    function syncAudioBitrateChoice() {
        var s = String(audioBitrateKbps)
        for (var i = 0; i < audioBitratePresets.length; ++i) {
            if (audioBitratePresets[i] === audioBitrateKbps) {
                audioBitrateChoice = s
                return
            }
        }
        audioBitrateChoice = "custom"
    }

    function applyAudioBitrateChoice(choice) {
        audioBitrateChoice = choice
        if (choice !== "custom") {
            var n = parseInt(choice, 10)
            if (!isNaN(n))
                audioBitrateKbps = n
        }
    }

    function refreshCodecMeta() {
        currentVideoCodec = codecById(videoCodecs, videoCodecId) || {}
        currentAudioCodec = codecById(audioCodecs, audioCodecId) || {}
        if (videoLossless)
            rateControl = "crf"
        else if (!videoSupportsCrf && videoSupportsBitrate)
            rateControl = "bitrate"
        else if (videoSupportsCrf && rateControl !== "bitrate")
            rateControl = "crf"
    }

    function applyVideoCodecDefaults(codec) {
        if (!codec)
            return
        if (codec.defaultCrf !== undefined)
            crf = codec.defaultCrf
        if (codec.defaultPreset)
            videoPreset = codec.defaultPreset
        if (codec.lossless)
            rateControl = "crf"
        else if (!codec.supportsCrf && codec.supportsBitrate)
            rateControl = "bitrate"
        else if (codec.supportsCrf)
            rateControl = "crf"
    }

    function formatWorkAreaTime(seconds) {
        const clamped = Math.max(0, seconds)
        const m = Math.floor(clamped / 60)
        const s = clamped - m * 60
        const whole = Math.floor(s)
        const frac = Math.floor((s - whole) * 100)
        return String(m).padStart(2, "0") + ":" + String(whole).padStart(2, "0") + "."
               + String(frac).padStart(2, "0")
    }

    function applyGifDefaults() {
        if (!(fpsNum > 0) || frameRateId === "project") {
            fpsNum = 15
            fpsDen = 1
            frameRateId = frameRateIdFor(15, 1)
        }
        if (EditorState.workAreaActive)
            exportWorkAreaOnly = true
    }

    function openDialog() {
        previewUrl = ""
        const host = root.parent && root.parent.Window ? root.parent.Window.window : null
        if (root.showSummary && host && host.grabPreviewFrame)
            host.grabPreviewFrame(function(url) { root.previewUrl = url })
        videoCodecs = EditorState.exportVideoCodecs()
        audioCodecs = EditorState.exportAudioCodecs()
        scaleOptions = EditorState.exportScaleOptions()
        frameRateOptions = EditorState.exportFrameRateOptions()

        var defaults = EditorState.exportDefaultSettings()
        var remembered = EditorState.lastExportSettings()
        var hasRemembered = !!(remembered
                               && (remembered.scaleId || remembered.videoCodecId
                                   || remembered.audioCodecId || remembered.gifExport))
        var src = hasRemembered ? remembered : defaults

        // Always open on Video unless the last export was audio-only or GIF.
        exportMode = hasRemembered && src.gifExport ? "gif"
                : hasRemembered && src.audioOnly ? "audio" : "video"
        videoCodecId = firstAvailableId(videoCodecs, src.videoCodecId || defaults.videoCodecId || "h264")
        audioCodecId = firstAvailableId(audioCodecs, src.audioCodecId || defaults.audioCodecId || "aac")
        rateControl = src.rateControl || defaults.rateControl || "crf"
        crf = (src.crf !== undefined && src.crf !== null) ? src.crf : (defaults.crf || 18)
        videoBitrateKbps = src.videoBitrateKbps || defaults.videoBitrateKbps || 12000
        videoPreset = src.videoPreset || defaults.videoPreset || "medium"
        audioBitrateKbps = src.audioBitrateKbps || defaults.audioBitrateKbps || 192
        syncAudioBitrateChoice()

        var restoredNum = (src.fpsNum !== undefined && src.fpsNum !== null) ? src.fpsNum : 0
        var restoredDen = (src.fpsDen !== undefined && src.fpsDen !== null) ? src.fpsDen : 1
        if (!(restoredNum > 0) || !(restoredDen > 0)) {
            restoredNum = 0
            restoredDen = 1
        }
        fpsNum = restoredNum
        fpsDen = restoredDen
        frameRateId = frameRateIdFor(restoredNum, restoredDen)
        if (exportMode === "gif")
            applyGifDefaults()

        advancedOpen = false
        exportWorkAreaOnly = EditorState.workAreaActive
                && (remembered.exportWorkAreaOnly === true)

        var meta = EditorState.projectMetadata || {}
        tagTitleField.text = meta.title || EditorState.projectName || ""
        tagArtistField.text = meta.author || ""
        tagAlbumField.text = ""
        tagCommentField.text = meta.description || ""

        var restoredScale = false
        if (hasRemembered && src.scaleId && scaleOptions.length > 0) {
            for (var i = 0; i < scaleOptions.length; ++i) {
                if (scaleOptions[i].id === src.scaleId) {
                    scaleId = scaleOptions[i].id
                    targetHeight = scaleOptions[i].targetHeight
                    // Keep the remembered bitrate when Advanced was customized; otherwise use
                    // the chip's suggested bitrate for that scale.
                    if (src.videoBitrateKbps === undefined || src.videoBitrateKbps === null)
                        videoBitrateKbps = scaleOptions[i].videoBitrateKbps || videoBitrateKbps
                    restoredScale = true
                    break
                }
            }
        }
        if (!restoredScale) {
            if (scaleOptions.length > 0) {
                scaleId = scaleOptions[0].id
                targetHeight = scaleOptions[0].targetHeight
                if (!hasRemembered && scaleOptions[0].videoBitrateKbps)
                    videoBitrateKbps = scaleOptions[0].videoBitrateKbps
            } else {
                scaleId = "source"
                targetHeight = 0
            }
        }

        // Codec catalog defaults only on a fresh dialog — otherwise they wipe the remembered CRF.
        if (!hasRemembered)
            applyVideoCodecDefaults(codecById(videoCodecs, videoCodecId))
        refreshCodecMeta()
        syncComboIndices()
        open()
    }

    function syncComboIndices() {
        if (frameRateCombo)
            frameRateCombo.currentIndex = Math.max(0, frameRateCombo.indexOfValue(frameRateId))
        if (gifFrameRateCombo)
            gifFrameRateCombo.currentIndex = Math.max(0, gifFrameRateCombo.indexOfValue(frameRateId))
        if (videoCodecCombo)
            videoCodecCombo.currentIndex = Math.max(0, videoCodecCombo.indexOfValue(videoCodecId))
        if (audioCodecCombo)
            audioCodecCombo.currentIndex = Math.max(0, audioCodecCombo.indexOfValue(audioCodecId))
        if (audioOnlyCodecCombo)
            audioOnlyCodecCombo.currentIndex = Math.max(0, audioOnlyCodecCombo.indexOfValue(audioCodecId))
        if (audioBitrateCombo)
            audioBitrateCombo.currentIndex = Math.max(0, audioBitrateCombo.indexOfValue(audioBitrateChoice))
        if (audioOnlyBitrateCombo)
            audioOnlyBitrateCombo.currentIndex = Math.max(0, audioOnlyBitrateCombo.indexOfValue(audioBitrateChoice))
        if (videoSupportsPreset && videoPresetList.length > 0 && presetCombo) {
            var pi = videoPresetList.indexOf(videoPreset)
            presetCombo.currentIndex = pi >= 0 ? pi : Math.max(0, videoPresetList.indexOf(
                                                                   currentVideoCodec.defaultPreset || ""))
            if (presetCombo.currentIndex >= 0 && presetCombo.currentIndex < videoPresetList.length)
                videoPreset = videoPresetList[presetCombo.currentIndex]
        }
    }

    function buildSettings() {
        var s = {
            "scaleId": scaleId,
            "targetHeight": targetHeight,
            "fpsNum": isAudioOnly ? 0 : fpsNum,
            "fpsDen": isAudioOnly ? 1 : fpsDen,
            "videoCodecId": videoCodecId,
            "rateControl": videoLossless ? "crf" : rateControl,
            "crf": crf,
            "videoBitrateKbps": videoBitrateKbps,
            "videoPreset": videoPreset,
            "audioCodecId": audioCodecId,
            "audioBitrateKbps": audioBitrateKbps,
            "audioOnly": isAudioOnly,
            "gifExport": isGifExport,
            "exportWorkAreaOnly": exportWorkAreaOnly && EditorState.workAreaActive
        }
        if (s.exportWorkAreaOnly) {
            s.startUs = Math.round(EditorState.workAreaInSeconds * 1000000)
            s.endUs = Math.round(EditorState.workAreaOutSeconds * 1000000)
        }
        if (isAudioOnly) {
            if (tagTitleField.text.length)
                s.metadataTitle = tagTitleField.text
            if (tagArtistField.text.length)
                s.metadataArtist = tagArtistField.text
            if (tagAlbumField.text.length)
                s.metadataAlbum = tagAlbumField.text
            if (tagCommentField.text.length)
                s.metadataComment = tagCommentField.text
        }
        return s
    }

    onAccepted: {
        var container = isGifExport ? "gif"
                : isAudioOnly
                  ? EditorState.exportPreferredAudioOnlyContainer(audioCodecId)
                  : EditorState.exportPreferredContainer(videoCodecId, audioCodecId)
        var filters = EditorState.exportSaveFilters(container, isAudioOnly)
        var suffix = EditorState.exportDefaultSuffix(container, isAudioOnly)
        var dialogTitle = isGifExport ? qsTr("Export GIF")
                : isAudioOnly ? qsTr("Export Audio") : qsTr("Export Video")
        var url = FileDialogs.saveFile(dialogTitle, filters,
                                       EditorState.projectName, suffix,
                                       EditorState.lastExportFolder())
        if (url != "") {
            EditorState.exportWithSettings(url, buildSettings())
            Toasts.info(qsTr("Export started…"))
        } else {
            Toasts.info(qsTr("Export cancelled."))
        }
    }

    // With Advanced open this content is ~800px tall against a 560px minimum
    // window height, so it has to scroll: unscrolled, the dialog overflowed the
    // window and took the Export/Cancel buttons off-screen with it.
    contentItem: Item {
        implicitHeight: Math.max(contentFlick.implicitHeight,
                                 root.showSummary ? Math.min(summaryColumn.implicitHeight,
                                                             root.availableContentHeight) : 0)

        Column {
            id: summaryColumn
            visible: root.showSummary
            width: root.summaryWidth
            spacing: Theme.spacingLg

            Rectangle {
                width: parent.width
                height: Math.round(width * 9 / 16)
                radius: Theme.radiusMd
                color: Theme.overlayColor
                border.width: Theme.borderWidth
                border.color: Theme.panelBorder
                clip: true

                Image {
                    anchors.fill: parent
                    anchors.margins: 1
                    source: root.previewUrl
                    fillMode: Image.PreserveAspectFit
                    asynchronous: true
                    cache: false
                }
            }

            ThemedLabel {
                width: parent.width
                text: EditorState.projectName
                tone: "default"
                size: "sm"
                elide: Text.ElideRight
                font.weight: Font.DemiBold
            }

            component SummaryRow: Row {
                property alias label: summaryKey.text
                property alias value: summaryValue.text
                width: parent ? parent.width : 0
                ThemedLabel { id: summaryKey; width: parent.width * 0.45; size: "xs" }
                ThemedLabel { id: summaryValue; width: parent.width * 0.55; size: "xs"; tone: "default"; horizontalAlignment: Text.AlignRight; elide: Text.ElideRight }
            }

            SummaryRow {
                visible: root.exportMode !== "audio"
                label: qsTr("Resolution")
                value: {
                    const ph = EditorState.projectHeight(), pw = EditorState.projectWidth()
                    const h = root.targetHeight > 0 ? root.targetHeight : ph
                    return Math.round(h * pw / Math.max(1, ph)) + " × " + h
                }
            }
            SummaryRow {
                visible: root.exportMode !== "audio"
                label: qsTr("Frame rate")
                value: (root.fpsNum > 0 ? (root.fpsNum / Math.max(1, root.fpsDen)).toFixed(root.fpsDen > 1 ? 2 : 0)
                                        : EditorState.projectFps()) + " fps"
            }
            SummaryRow {
                label: qsTr("Duration")
                value: root.formatDuration(root.exportWorkAreaOnly
                           ? EditorState.workAreaOutSeconds - EditorState.workAreaInSeconds
                           : EditorState.durationSeconds)
            }
            SummaryRow {
                label: qsTr("Estimated size")
                value: root.formatSize(root.estimatedMegabytes)
            }
        }

    Flickable {
        id: contentFlick
        x: root.showSummary ? root.summaryWidth + Theme.spacing2xl : 0
        width: parent.width - x
        height: parent.height
        implicitHeight: Math.min(exportColumn.height, root.availableContentHeight)
        contentWidth: width
        contentHeight: exportColumn.height
        clip: true
        boundsBehavior: Flickable.StopAtBounds
        // Bumped by ThemedSlider while a handle is dragged, so the dialog
        // doesn't steal the drag.
        property int dragLocks: 0
        interactive: contentHeight > height && dragLocks === 0
        ScrollBar.vertical: AppScrollBar {
            policy: contentFlick.contentHeight > contentFlick.height
                    ? ScrollBar.AlwaysOn : ScrollBar.AsNeeded
        }

        Column {
            id: exportColumn
            spacing: Theme.spacingXl
            width: contentFlick.width

            Row {
                spacing: Theme.spacingMd

                ThemedToggleButton {
                    text: qsTr("Video")
                    checked: root.exportMode === "video"
                    onClicked: {
                        if (root.exportMode === "video")
                            return
                        root.exportMode = "video"
                        root.advancedOpen = false
                        root.syncComboIndices()
                    }
                }

                ThemedToggleButton {
                    text: qsTr("Audio")
                    checked: root.exportMode === "audio"
                    onClicked: {
                        if (root.exportMode === "audio")
                            return
                        root.exportMode = "audio"
                        root.advancedOpen = false
                        root.syncComboIndices()
                    }
                }

                ThemedToggleButton {
                    text: qsTr("GIF")
                    enabled: EditorState.exportGifAvailable()
                    tooltip: enabled ? "" : qsTr("GIF encoder is not available in this build")
                    checked: root.exportMode === "gif"
                    onClicked: {
                        if (root.exportMode === "gif")
                            return
                        root.exportMode = "gif"
                        root.advancedOpen = false
                        root.applyGifDefaults()
                        root.syncComboIndices()
                    }
                }
            }

            ThemedCheckBox {
                width: parent.width
                visible: EditorState.workAreaActive
                text: qsTr("Export work area only (%1 – %2)")
                      .arg(root.formatWorkAreaTime(EditorState.workAreaInSeconds))
                      .arg(root.formatWorkAreaTime(EditorState.workAreaOutSeconds))
                checked: root.exportWorkAreaOnly
                tooltip: qsTr("Encode only the marked In/Out range instead of the full timeline")
                onToggled: root.exportWorkAreaOnly = checked
            }

            // ---- Video mode ----
            Column {
                width: parent.width
                spacing: Theme.spacingXl
                visible: root.exportMode === "video"
                height: visible ? implicitHeight : 0
                clip: true

                ThemedLabel {
                    width: parent.width
                    size: "sm"
                    text: qsTr("Saves what you see in the preview. Pick a size — the picture shape stays the same.")
                }

                ThemedLabel {
                    text: qsTr("Downscale")
                }

                Flow {
                    width: parent.width
                    spacing: Theme.spacingMd

                    Repeater {
                        model: root.scaleOptions

                        delegate: ThemedChip {
                            required property var modelData
                            text: modelData.label
                            selected: root.scaleId === modelData.id
                            tooltip: qsTr("Export at %1×%2").arg(modelData.width).arg(modelData.height)
                            onClicked: {
                                root.scaleId = modelData.id
                                root.targetHeight = modelData.targetHeight
                                if (modelData.videoBitrateKbps)
                                    root.videoBitrateKbps = modelData.videoBitrateKbps
                            }
                        }
                    }
                }

                Column {
                    width: parent.width
                    spacing: Theme.spacingSm

                    ThemedLabel {
                        text: qsTr("Frame rate")
                    }

                    RowLayout {
                        width: parent.width
                        spacing: Theme.spacingMd

                        ThemedComboBox {
                            id: frameRateCombo
                            Layout.fillWidth: true
                            textRole: "label"
                            valueRole: "id"
                            model: root.frameRateModel
                            onActivated: function (index) {
                                root.applyFrameRateChoice(root.frameRateModel[index])
                            }
                        }

                        ThemedNumberField {
                            Layout.preferredWidth: 120
                            visible: root.frameRateCustom
                            from: 1
                            to: 480
                            step: 1
                            unit: qsTr("fps")
                            value: root.fpsNum > 0 ? root.fpsNum : EditorState.projectFps()
                            // Whole numbers only here; every fractional rate worth
                            // delivering (23.976 / 29.97 / 59.94) is already a preset.
                            onEdited: function (v) {
                                root.fpsNum = Math.round(v)
                                root.fpsDen = 1
                            }
                        }
                    }

                    ThemedLabel {
                        width: parent.width
                        size: "sm"
                        visible: root.fpsNum > 0
                        height: visible ? implicitHeight : 0
                        text: qsTr("Exporting above the project rate pulls extra frames from the source footage where it has them — this is what makes slowed clips look smooth. Where it doesn't, frames repeat.")
                    }
                }

                Item {
                    width: parent.width
                    height: advancedHeader.implicitHeight

                    Row {
                        id: advancedHeader
                        spacing: Theme.spacingSm
                        anchors.left: parent.left

                        IconGlyph {
                            anchors.verticalCenter: parent.verticalCenter
                            glyph: Theme.icons.chevronRight
                            iconSize: Theme.iconSizeSm
                            iconColor: Theme.mutedForeground
                            rotation: root.advancedOpen ? 90 : 0
                            Behavior on rotation {
                                NumberAnimation { duration: Theme.durationFast; easing.type: Theme.easing }
                            }
                        }

                        ThemedLabel {
                            anchors.verticalCenter: parent.verticalCenter
                            text: qsTr("Advanced")
                        }
                    }

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.advancedOpen = !root.advancedOpen
                    }

                    Accessible.role: Accessible.Button
                    Accessible.name: qsTr("Advanced")
                    Accessible.checkable: true
                    Accessible.checked: root.advancedOpen
                    Accessible.onPressAction: root.advancedOpen = !root.advancedOpen
                }

                Column {
                    width: parent.width
                    spacing: Theme.spacingXl
                    visible: root.advancedOpen
                    height: visible ? implicitHeight : 0
                    clip: true

                    Column {
                        width: parent.width
                        spacing: Theme.spacingSm

                        ThemedLabel {
                            text: qsTr("Video encoder")
                            size: "sm"
                        }

                        ThemedComboBox {
                            id: videoCodecCombo
                            width: parent.width
                            textRole: "label"
                            valueRole: "id"
                            model: root.videoCodecs
                            onActivated: function (index) {
                                var item = root.videoCodecs[index]
                                if (!item || !item.available) {
                                    currentIndex = Math.max(0, indexOfValue(root.videoCodecId))
                                    return
                                }
                                root.videoCodecId = item.id
                                root.applyVideoCodecDefaults(item)
                                root.refreshCodecMeta()
                                root.syncComboIndices()
                            }
                        }
                    }

                    Column {
                        width: parent.width
                        spacing: Theme.spacingMd
                        visible: !root.videoLossless

                        Row {
                            spacing: Theme.spacingMd

                            ThemedToggleButton {
                                text: qsTr("Constant Quality")
                                checked: root.rateControl === "crf"
                                enabled: root.videoSupportsCrf
                                onClicked: {
                                    if (root.videoSupportsCrf)
                                        root.rateControl = "crf"
                                }
                            }

                            ThemedToggleButton {
                                text: qsTr("Bitrate")
                                checked: root.rateControl === "bitrate"
                                enabled: root.videoSupportsBitrate
                                onClicked: {
                                    if (root.videoSupportsBitrate)
                                        root.rateControl = "bitrate"
                                }
                            }
                        }

                        Column {
                            width: parent.width
                            spacing: Theme.spacingSm
                            visible: root.rateControl === "crf" && root.videoSupportsCrf

                            Row {
                                width: parent.width
                                ThemedLabel {
                                    text: qsTr("RF %1").arg(root.crf)
                                    size: "sm"
                                }
                            }

                            ThemedSlider {
                                width: parent.width
                                label: qsTr("Quality (RF)")
                                from: 0
                                to: 51
                                stepSize: 1
                                value: root.crf
                                valueFormatter: function (v) { return qsTr("RF %1").arg(Math.round(v)) }
                                onMoved: root.crf = Math.round(value)
                            }

                            RowLayout {
                                width: parent.width

                                ThemedLabel {
                                    text: qsTr("Higher quality")
                                    size: "xs"
                                }

                                Item { Layout.fillWidth: true }

                                ThemedLabel {
                                    text: qsTr("Lower quality")
                                    size: "xs"
                                }
                            }
                        }

                        RowLayout {
                            width: parent.width
                            spacing: Theme.spacingMd
                            visible: root.rateControl === "bitrate" && root.videoSupportsBitrate

                            ThemedLabel {
                                text: qsTr("Bitrate (kbps)")
                                size: "sm"
                            }

                            ThemedNumberField {
                                Layout.preferredWidth: 120
                                from: 100
                                to: 100000
                                step: 100
                                unit: qsTr("kbps")
                                value: root.videoBitrateKbps
                                onEdited: function (v) { root.videoBitrateKbps = Math.round(v) }
                            }
                        }
                    }

                    Column {
                        width: parent.width
                        spacing: Theme.spacingSm
                        visible: root.videoSupportsPreset && root.videoPresetList.length > 0

                        ThemedLabel {
                            text: qsTr("Preset")
                            size: "sm"
                        }

                        ThemedComboBox {
                            id: presetCombo
                            width: parent.width
                            model: root.videoPresetList
                            onActivated: function (index) {
                                if (index >= 0 && index < root.videoPresetList.length)
                                    root.videoPreset = root.videoPresetList[index]
                            }
                        }
                    }

                    GridLayout {
                        width: parent.width
                        columns: 2
                        columnSpacing: Theme.spacingLg
                        rowSpacing: Theme.spacingSm

                        ThemedLabel {
                            text: qsTr("Audio encoder")
                            size: "sm"
                            Layout.fillWidth: true
                        }

                        ThemedLabel {
                            text: qsTr("Bitrate")
                            size: "sm"
                            Layout.fillWidth: true
                            visible: !root.audioLossless
                        }

                        ThemedComboBox {
                            id: audioCodecCombo
                            Layout.fillWidth: true
                            textRole: "label"
                            valueRole: "id"
                            model: root.audioCodecs
                            onActivated: function (index) {
                                var item = root.audioCodecs[index]
                                if (!item || !item.available) {
                                    currentIndex = Math.max(0, indexOfValue(root.audioCodecId))
                                    return
                                }
                                root.audioCodecId = item.id
                                root.refreshCodecMeta()
                            }
                        }

                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: Theme.spacingSm
                            visible: !root.audioLossless

                            ThemedComboBox {
                                id: audioBitrateCombo
                                Layout.fillWidth: true
                                textRole: "label"
                                valueRole: "value"
                                model: root.audioBitrateModel
                                onActivated: function (index) {
                                    var item = root.audioBitrateModel[index]
                                    if (!item)
                                        return
                                    root.applyAudioBitrateChoice(item.value)
                                    if (audioOnlyBitrateCombo)
                                        audioOnlyBitrateCombo.currentIndex = currentIndex
                                }
                            }

                            ThemedNumberField {
                                Layout.fillWidth: true
                                visible: root.audioBitrateChoice === "custom"
                                from: 32
                                to: 512
                                step: 16
                                unit: qsTr("kbps")
                                value: root.audioBitrateKbps
                                onEdited: function (v) { root.audioBitrateKbps = Math.round(v) }
                            }
                        }
                    }
                }
            }

            // ---- GIF mode ----
            Column {
                width: parent.width
                spacing: Theme.spacingXl
                visible: root.isGifExport
                height: visible ? implicitHeight : 0
                clip: true

                ThemedLabel {
                    width: parent.width
                    size: "sm"
                    text: qsTr("Animated GIF — no audio. Mark a work area for short loops, or export up to 60 seconds.")
                }

                ThemedLabel {
                    text: qsTr("Downscale")
                }

                Flow {
                    width: parent.width
                    spacing: Theme.spacingMd

                    Repeater {
                        model: root.scaleOptions

                        delegate: ThemedChip {
                            required property var modelData
                            text: modelData.label
                            selected: root.scaleId === modelData.id
                            tooltip: qsTr("Export at %1×%2").arg(modelData.width).arg(modelData.height)
                            onClicked: {
                                root.scaleId = modelData.id
                                root.targetHeight = modelData.targetHeight
                            }
                        }
                    }
                }

                Column {
                    width: parent.width
                    spacing: Theme.spacingSm

                    ThemedLabel {
                        text: qsTr("Frame rate")
                    }

                    RowLayout {
                        width: parent.width
                        spacing: Theme.spacingMd

                        ThemedComboBox {
                            id: gifFrameRateCombo
                            Layout.fillWidth: true
                            textRole: "label"
                            valueRole: "id"
                            model: root.frameRateModel
                            onActivated: function (index) {
                                root.applyFrameRateChoice(root.frameRateModel[index])
                            }
                        }

                        ThemedNumberField {
                            Layout.preferredWidth: 120
                            visible: root.frameRateCustom
                            from: 1
                            to: 30
                            step: 1
                            unit: qsTr("fps")
                            value: root.fpsNum > 0 ? root.fpsNum : 15
                            onEdited: function (v) {
                                root.fpsNum = Math.round(v)
                                root.fpsDen = 1
                            }
                        }
                    }

                    ThemedLabel {
                        width: parent.width
                        size: "sm"
                        text: qsTr("15 fps is a good default for small file sizes. GIF export is limited to 60 seconds.")
                    }
                }
            }

            // ---- Audio mode ----
            Column {
                width: parent.width
                spacing: Theme.spacingXl
                visible: root.isAudioOnly
                height: visible ? implicitHeight : 0
                clip: true

                ThemedLabel {
                    width: parent.width
                    size: "sm"
                    text: qsTr("Exports the timeline audio mix only — no video track.")
                }

                Column {
                    width: parent.width
                    spacing: Theme.spacingSm

                    ThemedLabel {
                        text: qsTr("Audio encoder")
                        size: "sm"
                    }

                    ThemedComboBox {
                        id: audioOnlyCodecCombo
                        width: parent.width
                        textRole: "label"
                        valueRole: "id"
                        model: root.audioCodecs
                        onActivated: function (index) {
                            var item = root.audioCodecs[index]
                            if (!item || !item.available) {
                                currentIndex = Math.max(0, indexOfValue(root.audioCodecId))
                                return
                            }
                            root.audioCodecId = item.id
                            root.refreshCodecMeta()
                            if (audioCodecCombo)
                                audioCodecCombo.currentIndex = currentIndex
                        }
                    }
                }

                Column {
                    width: parent.width
                    spacing: Theme.spacingSm
                    visible: !root.audioLossless

                    ThemedLabel {
                        text: qsTr("Bitrate")
                        size: "sm"
                    }

                    ThemedComboBox {
                        id: audioOnlyBitrateCombo
                        width: parent.width
                        textRole: "label"
                        valueRole: "value"
                        model: root.audioBitrateModel
                        onActivated: function (index) {
                            var item = root.audioBitrateModel[index]
                            if (!item)
                                return
                            root.applyAudioBitrateChoice(item.value)
                            if (audioBitrateCombo)
                                audioBitrateCombo.currentIndex = currentIndex
                        }
                    }

                    ThemedNumberField {
                        width: parent.width
                        visible: root.audioBitrateChoice === "custom"
                        from: 32
                        to: 512
                        step: 16
                        unit: qsTr("kbps")
                        value: root.audioBitrateKbps
                        onEdited: function (v) { root.audioBitrateKbps = Math.round(v) }
                    }
                }

                Item {
                    width: parent.width
                    height: audioAdvancedHeader.implicitHeight

                    Row {
                        id: audioAdvancedHeader
                        spacing: Theme.spacingSm
                        anchors.left: parent.left

                        IconGlyph {
                            anchors.verticalCenter: parent.verticalCenter
                            glyph: Theme.icons.chevronRight
                            iconSize: Theme.iconSizeSm
                            iconColor: Theme.mutedForeground
                            rotation: root.advancedOpen ? 90 : 0
                            Behavior on rotation {
                                NumberAnimation { duration: Theme.durationFast; easing.type: Theme.easing }
                            }
                        }

                        ThemedLabel {
                            anchors.verticalCenter: parent.verticalCenter
                            text: qsTr("Advanced")
                        }
                    }

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.advancedOpen = !root.advancedOpen
                    }

                    Accessible.role: Accessible.Button
                    Accessible.name: qsTr("Advanced")
                    Accessible.checkable: true
                    Accessible.checked: root.advancedOpen
                    Accessible.onPressAction: root.advancedOpen = !root.advancedOpen
                }

                Column {
                    width: parent.width
                    spacing: Theme.spacingLg
                    visible: root.advancedOpen
                    height: visible ? implicitHeight : 0
                    clip: true

                    ThemedLabel {
                        text: qsTr("Tags")
                        size: "sm"
                    }

                    Column {
                        width: parent.width
                        spacing: Theme.spacingSm

                        ThemedLabel {
                            text: qsTr("Title")
                            size: "xs"
                        }
                        ThemedTextField {
                            id: tagTitleField
                            width: parent.width
                        }
                    }

                    Column {
                        width: parent.width
                        spacing: Theme.spacingSm

                        ThemedLabel {
                            text: qsTr("Artist")
                            size: "xs"
                        }
                        ThemedTextField {
                            id: tagArtistField
                            width: parent.width
                        }
                    }

                    Column {
                        width: parent.width
                        spacing: Theme.spacingSm

                        ThemedLabel {
                            text: qsTr("Album")
                            size: "xs"
                        }
                        ThemedTextField {
                            id: tagAlbumField
                            width: parent.width
                        }
                    }

                    Column {
                        width: parent.width
                        spacing: Theme.spacingSm

                        ThemedLabel {
                            text: qsTr("Comment")
                            size: "xs"
                        }
                        ThemedTextArea {
                            id: tagCommentField
                            width: parent.width
                            height: 96
                        }
                    }
                }
            }
        }
    }
    }
}
