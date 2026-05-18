import "."
import QtQuick
import QtQuick.Layouts

Rectangle {
    id: root

    property string icon: ""
    property string label: ""
    property color accent: Theme.foreground
    property bool active: false
    property bool alert: false

    signal clicked(real centerY)
    signal rightClicked()
    signal wheeled(int delta)

    Layout.alignment: Qt.AlignHCenter
    width: Theme.buttonSize
    height: visible ? Theme.buttonSize : 0
    radius: Theme.radius
    color: alert ? Theme.red : active ? Theme.surfaceAlt : "transparent"
    opacity: mouse.containsMouse ? 0.68 : 1

    Text {
        id: iconText

        anchors.fill: parent
        text: root.icon
        color: root.accent
        font.family: Theme.fontFamily
        font.pixelSize: Theme.iconSize
        horizontalAlignment: Text.AlignHCenter
        verticalAlignment: Text.AlignVCenter
    }

    Text {
        anchors.top: iconText.bottom
        anchors.topMargin: -2
        anchors.horizontalCenter: parent.horizontalCenter
        text: root.label
        color: root.accent
        font.family: Theme.fontFamily
        font.pixelSize: 9
        horizontalAlignment: Text.AlignHCenter
        visible: root.label.length > 0
    }

    MouseArea {
        id: mouse

        anchors.fill: parent
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: (event) => {
            if (event.button === Qt.RightButton)
                root.rightClicked();
            else
                root.clicked(root.y + root.height / 2);
        }
        onWheel: (event) => {
            return root.wheeled(event.angleDelta.y);
        }
    }

}
