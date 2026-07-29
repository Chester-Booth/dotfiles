import QtQuick

Rectangle {
    id: root

    property string text: ""
    property string iconName: ""
    property int iconSize: 16
    property color accent: Theme.blue
    property bool destructive: false
    property bool checked: false
    property bool compact: false
    readonly property bool hovered: hover.hovered
    readonly property bool down: tap.pressed

    signal clicked()

    implicitHeight: 36
    implicitWidth: compact ? Math.max(34, buttonContent.implicitWidth + 18) : Math.max(76, buttonContent.implicitWidth + 30)
    radius: 9
    color: !enabled ? Theme.withAlpha(Theme.surface, 0.42) : down ? Theme.withAlpha(accent, 0.26) : checked ? Theme.withAlpha(accent, 0.18) : hovered ? Theme.surfaceAlt : Theme.surface
    border.color: activeFocus || checked ? accent : hovered ? Theme.withAlpha(Theme.foreground, 0.34) : Theme.border
    border.width: activeFocus || checked ? 2 : 1
    opacity: enabled ? 1 : 0.68
    activeFocusOnTab: enabled
    Keys.onSpacePressed: {
        if (enabled)
            clicked();

    }
    Keys.onReturnPressed: {
        if (enabled)
            clicked();

    }

    Row {
        id: buttonContent

        anchors.centerIn: parent
        spacing: root.iconName.length > 0 && root.text.length > 0 ? 7 : 0

        Text {
            visible: root.iconName.length > 0
            anchors.verticalCenter: parent.verticalCenter
            text: Lucide.icon(root.iconName)
            color: label.color
            font.family: Lucide.family
            font.pixelSize: root.iconSize
            horizontalAlignment: Text.AlignHCenter
            verticalAlignment: Text.AlignVCenter
        }

        Text {
            id: label

            anchors.verticalCenter: parent.verticalCenter
            text: root.text
            color: !root.enabled ? Theme.muted : root.destructive ? Theme.red : root.checked ? root.accent : Theme.foreground
            font.family: Theme.bodyFontFamily
            font.pixelSize: 12
            font.bold: root.checked
            horizontalAlignment: Text.AlignHCenter
            verticalAlignment: Text.AlignVCenter
            elide: Text.ElideRight
        }

    }

    HoverHandler {
        id: hover

        cursorShape: root.enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
    }

    TapHandler {
        id: tap

        enabled: root.enabled
        onTapped: root.clicked()
    }

}
