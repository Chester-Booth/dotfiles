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

        return String(Math.round(capacity)); // no need for a % sign takes up too much space and is implied by the context
    }

    Layout.alignment: Qt.AlignHCenter
    width: Theme.buttonSize
    height: expanded ? Theme.buttonSize : 0
    radius: Theme.radius
    color: mouse.containsMouse ? Theme.surfaceAlt : "transparent"
    opacity: mouse.containsMouse ? 0.68 : 1
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
        font.bold: false
        horizontalAlignment: Text.AlignHCenter
        verticalAlignment: Text.AlignVCenter
        wrapMode: Text.NoWrap
        elide: Text.ElideNone
    }

    MouseArea {
        id: mouse

        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: root.collapse()
    }

}
