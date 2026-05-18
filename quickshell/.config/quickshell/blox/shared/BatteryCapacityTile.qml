import "."
import QtQuick
import QtQuick.Layouts

Rectangle {
    id: root

    property var status
    property bool expanded: false

    signal collapse()

    Layout.alignment: Qt.AlignHCenter
    width: Theme.buttonSize
    height: expanded ? Theme.buttonSize : 0
    radius: Theme.radius
    color: "transparent"
    visible: expanded
    clip: true

    Text {
        anchors.centerIn: parent
        text: root.status && root.status.capacity !== undefined ? String(root.status.capacity) : ""
        color: root.status && root.status.class === "critical" ? Theme.red : root.status && root.status.class === "charging" ? Theme.green : Theme.foreground
        font.family: Theme.fontFamily
        font.pixelSize: 13
        font.bold: true
    }

    MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        onClicked: root.collapse()
    }
}
