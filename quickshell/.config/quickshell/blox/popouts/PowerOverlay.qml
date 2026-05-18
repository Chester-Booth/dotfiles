import "../shared"
import QtQuick
import QtQuick.Layouts

Rectangle {
    id: root

    property string updateSummary: "Check updates"

    signal action(string command)
    signal close()

    color: "#99000000"

    MouseArea {
        anchors.fill: parent
        onClicked: root.close()
    }

    ColumnLayout {
        anchors.centerIn: parent
        width: Math.min(parent.width - 160, 820)
        height: Math.min(parent.height - 160, 420)
        spacing: 18

        Text {
            Layout.fillWidth: true
            text: "Power"
            color: Theme.foreground
            font.family: Theme.fontFamily
            font.pixelSize: 20
            font.bold: true
            horizontalAlignment: Text.AlignHCenter
        }

        GridLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            columns: 3
            rowSpacing: 12
            columnSpacing: 12

            Repeater {
                model: [{
                    "icon": "󰌾",
                    "label": "Lock",
                    "command": "lock"
                }, {
                    "icon": "󰒲",
                    "label": "Sleep",
                    "command": "sleep"
                }, {
                    "icon": "󰤄",
                    "label": "Hibernate",
                    "command": "hibernate"
                }, {
                    "icon": "󰚰",
                    "label": "Update + shutdown",
                    "command": "update-shutdown",
                    "danger": true
                }, {
                    "icon": "󰜉",
                    "label": "Reboot",
                    "command": "reboot",
                    "danger": true
                }, {
                    "icon": "⏻",
                    "label": "Shut down",
                    "command": "shutdown",
                    "danger": true
                }]

                Rectangle {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    Layout.minimumHeight: 112
                    radius: 8
                    color: powerMouse.containsMouse ? "#ee3b3c4a" : "#dd1e1e1e"
                    border.color: modelData.danger ? Theme.red : Theme.surfaceAlt
                    border.width: 1

                    Column {
                        anchors.centerIn: parent
                        spacing: 8

                        Text {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: modelData.icon
                            color: modelData.danger ? Theme.red : Theme.foreground
                            font.family: Theme.fontFamily
                            font.pixelSize: 32
                        }

                        Text {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: modelData.command === "update-shutdown" ? modelData.label + "\n" + root.updateSummary : modelData.label
                            color: Theme.foreground
                            font.family: Theme.fontFamily
                            font.pixelSize: 12
                            font.bold: true
                            horizontalAlignment: Text.AlignHCenter
                        }

                    }

                    MouseArea {
                        id: powerMouse

                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            root.action(modelData.command);
                            root.close();
                        }
                    }

                }

            }

        }

    }

}
