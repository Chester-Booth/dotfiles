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
    property real iconRotation: 0

    signal clicked(real centerY)
    signal rightClicked()
    signal wheeled(int delta)
    signal hovered(real centerY)
    signal exited()

    Layout.alignment: Qt.AlignHCenter
    width: Theme.buttonSize
    height: visible ? Theme.buttonSize : 0
    radius: Theme.radius
    color: alert ? Theme.red : active || mouse.containsMouse ? Theme.surfaceAlt : "transparent"
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
        rotation: root.iconRotation

        Behavior on rotation {
            NumberAnimation {
                duration: 160
                easing.type: Easing.OutCubic
            }

        }

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
        onEntered: root.hovered(root.y + root.height / 2)
        onExited: root.exited()
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
