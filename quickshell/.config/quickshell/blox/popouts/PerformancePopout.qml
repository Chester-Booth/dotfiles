import "../shared"
import QtQuick
import QtQuick.Layouts

Rectangle {
    id: root

    property var status: ({
    })
    property var batteryStatus: ({
    })
    property string scriptRoot: ""

    signal action(string command)

    function fanCommand(profile) {
        return "asusctl profile set " + profile.toLowerCase() + "; notify-send -u low '" + profile + " mode'";
    }

    function gpuCommand(mode) {
        const paths = {
            "gaming": "/waybar/gpu/modes/gpu144.sh",
            "performance": "/waybar/gpu/modes/gpu60.sh",
            "high-refresh": "/waybar/gpu/modes/igpu144.sh",
            "eco": "/waybar/gpu/modes/igpu60.sh"
        };
        return scriptRoot + paths[mode];
    }

    width: 370
    height: 490
    radius: 8
    color: Theme.background
    border.color: Theme.surfaceAlt
    border.width: 1

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 14
        spacing: 12

        RowLayout {
            Layout.fillWidth: true
            spacing: 10

            Text {
                text: "󰓅"
                color: Theme.yellow
                font.family: Theme.fontFamily
                font.pixelSize: 25
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 1

                Text {
                    text: "Performance"
                    color: Theme.foreground
                    font.family: Theme.fontFamily
                    font.pixelSize: 15
                    font.bold: true
                }

                Text {
                    text: "Fan " + (status.profile || "Unknown") + "  |  " + (status.gpuLabel || "GPU")
                    color: Theme.muted
                    font.family: Theme.fontFamily
                    font.pixelSize: 10
                    elide: Text.ElideRight
                }

            }

        }

        GridLayout {
            Layout.fillWidth: true
            columns: 2
            rowSpacing: 8
            columnSpacing: 8

            Repeater {
                model: [{
                    "icon": "󰈐",
                    "label": "Fans",
                    "value": status.fanRpm || "N/A"
                }, {
                    "icon": "󰘚",
                    "label": "CPU",
                    "value": (status.cpuUtil || 0) + "% at " + (status.cpuClock || "N/A") + " GHz"
                }, {
                    "icon": "󰔏",
                    "label": "Temp",
                    "value": (status.cpuTemp || "N/A") + "°C"
                }, {
                    "icon": "󱟤",
                    "label": "Power",
                    "value": (status.powerW || "N/A") + " W"
                }, {
                    "icon": batteryStatus && batteryStatus.icon ? batteryStatus.icon : "󰁹",
                    "label": "Battery",
                    "value": batteryStatus && batteryStatus.capacity !== "" && batteryStatus.capacity !== undefined ? (batteryStatus.capacity + "% " + (batteryStatus.status || "")) : (batteryStatus && batteryStatus.tooltip ? batteryStatus.tooltip : "N/A")
                }, {
                    "icon": "",
                    "label": "Memory",
                    "value": (status.ramUsed || "?") + "/" + (status.ramTotal || "?") + " GB"
                }, {
                    "icon": "󰢮",
                    "label": "GPU",
                    "value": status.gpuOn ? ((status.gpuUtil || "0") + "% " + (status.gpuTemp ? status.gpuTemp + "°C" : "")) : "iGPU"
                }]

                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 52
                    radius: 7
                    color: Theme.surface
                    border.color: Theme.surfaceAlt
                    border.width: 1

                    RowLayout {
                        anchors.fill: parent
                        anchors.margins: 8
                        spacing: 7

                        Text {
                            text: modelData.icon
                            color: Theme.blue
                            font.family: Theme.fontFamily
                            font.pixelSize: 15
                        }

                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 1

                            Text {
                                text: modelData.label
                                color: Theme.muted
                                font.family: Theme.fontFamily
                                font.pixelSize: 9
                            }

                            Text {
                                Layout.fillWidth: true
                                text: modelData.value
                                color: Theme.foreground
                                font.family: Theme.fontFamily
                                font.pixelSize: 10
                                font.bold: true
                                elide: Text.ElideRight
                            }

                        }

                    }

                }

            }

        }

        ColumnLayout {
            Layout.fillWidth: true
            spacing: 8

            Text {
                text: "Fan profile"
                color: Theme.muted
                font.family: Theme.fontFamily
                font.pixelSize: 10
            }

            RowLayout {
                Layout.fillWidth: true
                spacing: 0

                Repeater {
                    model: ["Performance", "Balanced", "Quiet"]

                    Rectangle {
                        Layout.fillWidth: true
                        height: 34
                        radius: 8
                        color: String(root.status.profile || "").toLowerCase() === String(modelData).toLowerCase() ? "#66453d3d" : fanMouse.containsMouse ? Theme.surfaceAlt : Theme.surface
                        border.color: Theme.surfaceAlt
                        border.width: 1

                        Text {
                            anchors.centerIn: parent
                            text: modelData
                            color: String(root.status.profile || "").toLowerCase() === String(modelData).toLowerCase() ? Theme.yellow : Theme.foreground
                            font.family: Theme.fontFamily
                            font.pixelSize: 10
                            font.bold: true
                        }

                        MouseArea {
                            id: fanMouse

                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.action(root.fanCommand(modelData))
                        }

                    }

                }

            }

            Text {
                text: "GPU mode"
                color: Theme.muted
                font.family: Theme.fontFamily
                font.pixelSize: 10
            }

            GridLayout {
                Layout.fillWidth: true
                columns: 2
                rowSpacing: 6
                columnSpacing: 6

                Repeater {
                    model: [{
                        "id": "gaming",
                        "label": "Gaming 144"
                    }, {
                        "id": "performance",
                        "label": "GPU 60"
                    }, {
                        "id": "high-refresh",
                        "label": "iGPU 144"
                    }, {
                        "id": "eco",
                        "label": "Eco 60"
                    }]

                    Rectangle {
                        Layout.fillWidth: true
                        height: 34
                        radius: 8
                        color: root.status.gpuMode === modelData.id ? "#66453d3d" : gpuMouse.containsMouse ? Theme.surfaceAlt : Theme.surface
                        border.color: Theme.surfaceAlt
                        border.width: 1

                        Text {
                            anchors.centerIn: parent
                            text: modelData.label
                            color: root.status.gpuMode === modelData.id ? Theme.yellow : Theme.foreground
                            font.family: Theme.fontFamily
                            font.pixelSize: 10
                            font.bold: true
                        }

                        MouseArea {
                            id: gpuMouse

                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.action(root.gpuCommand(modelData.id))
                        }

                    }

                }

            }

        }

    }

}
