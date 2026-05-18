import "../shared"
import QtQuick

Rectangle {
    id: root

    property string title: ""
    property string body: ""
    property var actions: []

    signal action(string command, bool keepOpen)

    width: 300
    height: Math.min(520, Math.max(120, content.implicitHeight + 28))
    radius: Theme.radius
    color: Theme.background
    border.color: Theme.foreground
    border.width: 1

    Column {
        id: content

        anchors.fill: parent
        anchors.margins: 12
        spacing: 10

        Text {
            width: parent.width
            text: root.title
            color: Theme.blue
            font.family: Theme.fontFamily
            font.pixelSize: 14
            font.bold: true
            elide: Text.ElideRight
        }

        Text {
            width: parent.width
            text: root.body
            color: Theme.foreground
            font.family: Theme.fontFamily
            font.pixelSize: 12
            wrapMode: Text.Wrap
        }

        Repeater {
            model: root.actions

            Rectangle {
                width: content.width
                height: 30
                radius: Theme.radius
                color: actionMouse.containsMouse ? Theme.surfaceAlt : Theme.surface
                border.color: Theme.surfaceAlt
                border.width: 1

                Text {
                    anchors.fill: parent
                    anchors.leftMargin: 10
                    anchors.rightMargin: 10
                    text: modelData.label || ""
                    color: modelData.danger ? Theme.red : Theme.foreground
                    font.family: Theme.fontFamily
                    font.pixelSize: 12
                    verticalAlignment: Text.AlignVCenter
                    elide: Text.ElideRight
                }

                MouseArea {
                    id: actionMouse

                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        const label = (modelData.label || "").toLowerCase();
                        const keepOpen = !!modelData.keepOpen || label.indexOf("cycle") >= 0 || label.indexOf(" up") >= 0 || label.indexOf(" down") >= 0;
                        root.action(modelData.command || "", keepOpen);
                    }
                }

            }

        }

    }

}
