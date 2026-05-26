import "."
import QtQuick
import QtQuick.Layouts

Rectangle {
    id: root

    property var status
    property bool expanded: false

    signal collapse()

    function displayCapacity() {
        if (!root.status || root.status.capacity === undefined)
            return "";

        const capacity = Number(root.status.capacity);
        if (!Number.isFinite(capacity) || capacity < 0 || capacity > 100)
            return "";

        return String(Math.round(capacity));
    }

    Layout.alignment: Qt.AlignHCenter
    width: Theme.buttonSize
    height: expanded ? Theme.buttonSize : 0
    radius: Theme.radius
    color: "transparent"
    visible: expanded
    clip: true

    Text {
        anchors.centerIn: parent
        width: parent.width
        text: root.displayCapacity()
        color: root.status && root.status.class === "critical" ? Theme.red : root.status && root.status.class === "charging" ? Theme.green : Theme.foreground
        font.family: Theme.fontFamily
        font.pixelSize: 13
        fontSizeMode: Text.Fit
        minimumPixelSize: 9
        font.bold: true
        horizontalAlignment: Text.AlignHCenter
        verticalAlignment: Text.AlignVCenter
        wrapMode: Text.NoWrap
        elide: Text.ElideNone
    }

    MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        onClicked: root.collapse()
    }
}
