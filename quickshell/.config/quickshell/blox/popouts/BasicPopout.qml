import "../shared"
import QtQuick

Rectangle {
    id: root

    property string title: ""
    property string body: ""
    property var actions: []

    signal action(string command, bool keepOpen)

    width: 340
    height: Math.min(520, Math.max(140, content.implicitHeight + 28))
    radius: 8
    color: Theme.background
    border.color: Theme.surfaceAlt
    border.width: 1

    Column {
        id: content

        anchors.fill: parent
        anchors.margins: 12
        spacing: 10

        Row {
            width: parent.width
            spacing: 8

            Text {
                text: root.title === "Updates" ? "󰧠" : "󰍹"
                color: Theme.blue
                font.family: Theme.fontFamily
                font.pixelSize: 18
            }

            Text {
                width: parent.width - 28
                text: root.title
                color: Theme.foreground
                font.family: Theme.fontFamily
                font.pixelSize: 14
                font.bold: true
                elide: Text.ElideRight
            }

        }

        Text {
            width: parent.width
            text: root.body
            color: Theme.foreground
            font.family: Theme.fontFamily
            font.pixelSize: 12
            wrapMode: Text.Wrap
        }

        Flow {
            width: parent.width
            spacing: 8

            Repeater {
                model: root.actions

                Rectangle {
                    width: Math.max(96, actionLabel.implicitWidth + 22)
                    height: 34
                    radius: 7
                    color: actionMouse.containsMouse ? Theme.surfaceAlt : Theme.surface
                    border.color: modelData.danger ? Theme.red : Theme.surfaceAlt
                    border.width: 1

                    Text {
                        id: actionLabel

                        anchors.centerIn: parent
                        text: modelData.label || ""
                        color: modelData.danger ? Theme.red : Theme.foreground
                        font.family: Theme.fontFamily
                        font.pixelSize: 11
                        font.bold: true
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

}
