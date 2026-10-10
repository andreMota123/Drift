import QtQuick
import Drift

// Schematic of a short-video app's interface drawn over the preview, to show what the
// app's own buttons and caption will cover. Laid out in a 9:16 box centred on the frame,
// so on a wider project it also marks what a vertical crop would keep.
Item {
    id: root

    // "tiktok" | "shorts" | "reels"
    property string network: "tiktok"

    readonly property var layouts: ({
        "tiktok": { label: "TikTok", railTop: 0.44, railCount: 5, captionTop: 0.80, navTop: 0.92, topTabs: true },
        "shorts": { label: "YouTube Shorts", railTop: 0.50, railCount: 5, captionTop: 0.84, navTop: 0.93, topTabs: false },
        "reels": { label: "Instagram Reels", railTop: 0.54, railCount: 4, captionTop: 0.82, navTop: 0.92, topTabs: false }
    })
    readonly property var spec: layouts[network] || layouts["tiktok"]
    readonly property color ink: Theme.onMedia

    Item {
        id: phone
        anchors.centerIn: parent
        height: Math.min(root.height, root.width * 16 / 9)
        width: height * 9 / 16
        opacity: 0.6

        // What falls outside the vertical frame on a wider project.
        Rectangle {
            anchors.fill: parent
            color: "transparent"
            border.width: 1
            border.color: root.ink
            visible: phone.width < root.width - 1
        }

        Text {
            x: phone.width * 0.04
            y: phone.height * 0.03
            text: root.spec.label
            color: root.ink
            font.family: Theme.fontFamily
            font.pixelSize: Math.max(9, phone.width * 0.045)
            font.weight: Font.DemiBold
        }

        // "Following | For you" tabs.
        Row {
            visible: root.spec.topTabs
            anchors.horizontalCenter: parent.horizontalCenter
            y: phone.height * 0.07
            spacing: phone.width * 0.04
            Repeater {
                model: 2
                Rectangle {
                    width: phone.width * 0.16
                    height: Math.max(2, phone.height * 0.008)
                    radius: height / 2
                    color: root.ink
                    opacity: index === 1 ? 1 : 0.6
                }
            }
        }

        // Right-hand rail: avatar, like, comment, share…
        Column {
            x: phone.width * 0.85
            y: phone.height * root.spec.railTop
            spacing: phone.height * 0.022
            Repeater {
                model: root.spec.railCount
                Rectangle {
                    width: phone.width * 0.11
                    height: width
                    radius: width / 2
                    color: "transparent"
                    border.width: Math.max(1, phone.width * 0.006)
                    border.color: root.ink
                }
            }
        }

        // Account name and caption.
        Column {
            x: phone.width * 0.04
            y: phone.height * root.spec.captionTop
            spacing: phone.height * 0.012
            Repeater {
                model: [0.34, 0.66, 0.50]
                Rectangle {
                    required property real modelData
                    width: phone.width * modelData
                    height: Math.max(2, phone.height * 0.012)
                    radius: height / 2
                    color: root.ink
                }
            }
        }

        // Bottom navigation bar.
        Rectangle {
            x: 0
            y: phone.height * root.spec.navTop
            width: phone.width
            height: phone.height - y
            color: Theme.scrimColor
            Rectangle {
                width: parent.width
                height: 1
                color: root.ink
            }
            Row {
                anchors.centerIn: parent
                spacing: phone.width * 0.09
                Repeater {
                    model: 5
                    Rectangle {
                        width: phone.width * 0.07
                        height: width
                        radius: Theme.radiusXs
                        color: "transparent"
                        border.width: 1
                        border.color: root.ink
                    }
                }
            }
        }
    }
}
