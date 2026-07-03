import QtQuick

Item {
    id: root

    property string text: ""
    property bool checked: false

    signal toggled(bool checked)

    implicitHeight: 30
    implicitWidth: box.width + 8 + label.implicitWidth
    activeFocusOnTab: enabled
    opacity: enabled ? 1 : 0.58
    Keys.onSpacePressed: {
        if (enabled)
            toggled(!checked);

    }

    Rectangle {
        id: box

        anchors.left: parent.left
        anchors.verticalCenter: parent.verticalCenter
        width: 19
        height: 19
        radius: 6
        color: root.checked ? Theme.withAlpha(Theme.blue, 0.22) : Theme.background
        border.color: root.activeFocus || root.checked ? Theme.blue : hover.hovered ? Theme.withAlpha(Theme.foreground, 0.36) : Theme.border
        border.width: root.activeFocus ? 2 : 1

        Text {
            anchors.centerIn: parent
            visible: root.checked
            text: "✓"
            color: Theme.blue
            font.family: Theme.fontFamily
            font.pixelSize: 12
            font.bold: true
        }

    }

    Text {
        id: label

        anchors.left: box.right
        anchors.leftMargin: 8
        anchors.verticalCenter: parent.verticalCenter
        text: root.text
        color: root.enabled ? Theme.foreground : Theme.muted
        font.family: Theme.fontFamily
        font.pixelSize: 11
    }

    HoverHandler {
        id: hover

        cursorShape: root.enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
    }

    TapHandler {
        enabled: root.enabled
        onTapped: root.toggled(!root.checked)
    }

}
