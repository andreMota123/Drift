import QtQuick
import QtQuick.Controls.Basic
import Drift

// Review of the caption corrections the local AI proposed: every changed line, before and
// after, each with its own checkbox. Only the ticked ones are applied, in one undo step.
ThemedDialog {
    id: root

    readonly property var changes: CaptionAi.pendingChanges
    // Cue index -> ticked. Rebuilt whenever a new set of changes arrives.
    property var ticked: ({})
    readonly property int tickedCount: {
        let n = 0
        for (let i = 0; i < changes.length; ++i)
            if (ticked[changes[i].index] !== false)
                ++n
        return n
    }

    title: qsTr("Review caption corrections")
    acceptText: qsTr("Apply %n correction(s)", "", tickedCount)
    preferredWidth: Theme.dialogWidthLg

    onChangesChanged: {
        ticked = ({})
        if (changes.length > 0 && !visible)
            open()
        else if (changes.length === 0 && visible)
            close()
    }

    onAccepted: {
        const accepted = []
        for (let i = 0; i < changes.length; ++i)
            if (ticked[changes[i].index] !== false)
                accepted.push(changes[i].index)
        CaptionAi.applyChanges(accepted)
    }
    onRejected: CaptionAi.discardChanges()

    contentItem: Column {
        spacing: Theme.spacingLg
        width: parent ? parent.width : 520

        ThemedLabel {
            width: parent.width
            wrapMode: Text.Wrap
            text: qsTr("The local AI suggests these fixes. Times stay as they are; untick any line you want to keep.")
            color: Theme.mutedForeground
        }

        ListView {
            id: list
            width: parent.width
            height: Math.min(contentHeight, 360)
            clip: true
            spacing: Theme.spacingMd
            model: root.changes
            boundsBehavior: Flickable.StopAtBounds
            ScrollBar.vertical: AppScrollBar { }

            delegate: Row {
                required property var modelData
                width: list.width - Theme.spacingLg
                spacing: Theme.spacingMd

                ThemedCheckBox {
                    checked: root.ticked[modelData.index] !== false
                    onToggled: {
                        const next = Object.assign({}, root.ticked)
                        next[modelData.index] = checked
                        root.ticked = next
                    }
                }

                Column {
                    width: parent.width - 32
                    spacing: Theme.spacingXs

                    Text {
                        width: parent.width
                        text: modelData.before
                        wrapMode: Text.Wrap
                        font.strikeout: true
                        color: Theme.mutedForeground
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontSizeXs
                    }
                    Text {
                        width: parent.width
                        text: modelData.after
                        wrapMode: Text.Wrap
                        color: Theme.panelForeground
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontSizeSm
                    }
                }
            }
        }
    }
}
