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
            "gaming": "/gpu/modes/gpu144.sh",
            "performance": "/gpu/modes/gpu60.sh",
            "high-refresh": "/gpu/modes/igpu144.sh",
            "eco": "/gpu/modes/igpu60.sh"
        };
        return scriptRoot + paths[mode];
    }

    function numberValue(value, fallback) {
        const parsed = Number(value);
        return isNaN(parsed) ? fallback : parsed;
    }

    function clamp(value, min, max) {
        return Math.max(min, Math.min(max, value));
    }

    function fanProfileId() {
        return String(status.profile || "balanced").toLowerCase();
    }

    function fanText() {
        const value = String(status.fanRpm || "N/A");
        if (value === "N/A" || value.toLowerCase().indexOf("rpm") >= 0)
            return value;

        return value + " RPM";
    }

    width: 268
    height: 474
    radius: 8
    color: Theme.background
    border.color: Theme.surfaceAlt
    border.width: 1

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 12
        spacing: 10

        RowLayout {
            Layout.fillWidth: true
            spacing: 9

            Rectangle {
                width: 34
                height: 34
                radius: 17
                color: "#3324231b"
                border.color: "#55f9e2af"
                border.width: 1

                Text {
                    anchors.centerIn: parent
                    text: "󰓅"
                    color: Theme.yellow
                    font.family: Theme.fontFamily
                    font.pixelSize: 18
                }

            }

            Item {
                Layout.fillWidth: true
                Layout.preferredHeight: 34

                Text {
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    text: "Performance"
                    color: Theme.foreground
                    font.family: Theme.fontFamily
                    font.pixelSize: 15
                    font.bold: true
                }

            }

        }

        GridLayout {
            Layout.fillWidth: true
            columns: 2
            rowSpacing: 7
            columnSpacing: 7

            DetailPill {
                icon: "󰈐"
                label: "Fans"
                value: root.fanText()
                accent: Theme.blue
            }

            DetailPill {
                icon: "󱟤"
                label: "Power"
                value: (root.status.powerW || "N/A") + " W"
                accent: Theme.yellow
            }

            DetailPill {
                icon: "󰢮"
                label: "GPU"
                value: root.status.gpuOn ? ((root.status.gpuUtil || "0") + "% " + (root.status.gpuTemp ? root.status.gpuTemp + "°C" : "")) : "iGPU"
                accent: Theme.teal
            }

            DetailPill {
                icon: "󰍛"
                label: "VRAM"
                value: root.status.vramTotal ? ((root.status.vramUsed || "0") + "/" + root.status.vramTotal + " MB") : "off"
                accent: Theme.mauve
            }

        }

        ColumnLayout {
            Layout.fillWidth: true
            spacing: 7

            MetricBar {
                icon: "󰘚"
                label: "CPU"
                detail: (root.status.cpuUtil || 0) + "% at " + (root.status.cpuClock || "N/A") + " GHz"
                percent: root.clamp(root.numberValue(root.status.cpuUtil, 0), 0, 100)
                accent: Theme.blue
            }

            MetricBar {
                icon: "󰔏"
                label: "Temperature"
                detail: (root.status.cpuTemp || "N/A") + "°C"
                percent: root.clamp(root.numberValue(root.status.cpuTemp, 0), 0, 100)
                accent: root.numberValue(root.status.cpuTemp, 0) >= 80 ? Theme.red : Theme.yellow
            }

            MetricBar {
                icon: root.batteryStatus && root.batteryStatus.icon ? root.batteryStatus.icon : "󰁹"
                label: "Battery"
                detail: root.batteryStatus && root.batteryStatus.capacity !== "" && root.batteryStatus.capacity !== undefined ? (root.batteryStatus.capacity + "% " + (root.batteryStatus.status || "")) : (root.batteryStatus && root.batteryStatus.tooltip ? root.batteryStatus.tooltip : "N/A")
                percent: root.clamp(root.numberValue(root.batteryStatus.capacity, 0), 0, 100)
                accent: root.batteryStatus && root.batteryStatus.class === "critical" ? Theme.red : root.batteryStatus && root.batteryStatus.class === "charging" ? Theme.green : Theme.teal
            }

            MetricBar {
                icon: ""
                label: "Memory"
                detail: (root.status.ramUsed || "?") + "/" + (root.status.ramTotal || "?") + " GB"
                percent: root.clamp(root.numberValue(root.status.ramPercent, 0), 0, 100)
                accent: Theme.mauve
            }

        }

        ColumnLayout {
            Layout.fillWidth: true
            spacing: 6

            SliderControl {
                Layout.fillWidth: true
                title: "Fan profile"
                currentText: root.status.profile || "Unknown"
                currentId: root.fanProfileId()
                options: [{
                    "id": "performance",
                    "icon": "󱑬",
                    "label": "Perf"
                }, {
                    "id": "balanced",
                    "icon": "󱜝",
                    "label": "Bal"
                }, {
                    "id": "quiet",
                    "icon": "󰠝",
                    "label": "Quiet"
                }]
                onSelected: (id) => {
                    return root.action(root.fanCommand(id.charAt(0).toUpperCase() + id.slice(1)));
                }
            }

            SliderControl {
                Layout.fillWidth: true
                title: "GPU mode"
                currentText: root.status.gpuLabel || "Unknown"
                currentId: root.status.gpuMode || "eco"
                options: [{
                    "id": "gaming",
                    "icon": "󰪫",
                    "label": "144"
                }, {
                    "id": "performance",
                    "icon": "󰢮",
                    "label": "60"
                }, {
                    "id": "high-refresh",
                    "icon": "",
                    "label": "144"
                }, {
                    "id": "eco",
                    "icon": "󰌪",
                    "label": "Eco"
                }]
                onSelected: (id) => {
                    return root.action(root.gpuCommand(id));
                }
            }

        }

    }

    component DetailPill: Rectangle {
        id: pill

        property string icon: ""
        property string label: ""
        property string value: ""
        property color accent: Theme.blue

        Layout.fillWidth: true
        Layout.preferredHeight: 36
        radius: 6
        color: Theme.surface
        border.color: Theme.surfaceAlt
        border.width: 1

        RowLayout {
            anchors.fill: parent
            anchors.leftMargin: 8
            anchors.rightMargin: 8
            spacing: 6

            Text {
                text: pill.icon
                color: pill.accent
                font.family: Theme.fontFamily
                font.pixelSize: 13
                horizontalAlignment: Text.AlignHCenter
                Layout.preferredWidth: 16
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 0

                Text {
                    Layout.fillWidth: true
                    text: pill.label
                    color: Theme.muted
                    font.family: Theme.fontFamily
                    font.pixelSize: 8
                    elide: Text.ElideRight
                }

                Text {
                    Layout.fillWidth: true
                    text: pill.value
                    color: Theme.foreground
                    font.family: Theme.fontFamily
                    font.pixelSize: 10
                    font.bold: true
                    elide: Text.ElideRight
                }

            }

        }

    }

    component MetricBar: Rectangle {
        id: metric

        property string icon: ""
        property string label: ""
        property string detail: ""
        property real percent: 0
        property color accent: Theme.blue

        Layout.fillWidth: true
        Layout.preferredHeight: 45
        radius: 6
        color: Theme.surface
        border.color: Theme.surfaceAlt
        border.width: 1

        ColumnLayout {
            anchors.fill: parent
            anchors.leftMargin: 9
            anchors.rightMargin: 9
            anchors.topMargin: 7
            anchors.bottomMargin: 7
            spacing: 5

            RowLayout {
                Layout.fillWidth: true
                spacing: 7

                Text {
                    text: metric.icon
                    color: metric.accent
                    font.family: Theme.fontFamily
                    font.pixelSize: 13
                    Layout.preferredWidth: 18
                    horizontalAlignment: Text.AlignHCenter
                }

                Text {
                    text: metric.label
                    color: Theme.muted
                    font.family: Theme.fontFamily
                    font.pixelSize: 9
                }

                Text {
                    Layout.fillWidth: true
                    text: metric.detail
                    color: Theme.foreground
                    font.family: Theme.fontFamily
                    font.pixelSize: 10
                    font.bold: true
                    horizontalAlignment: Text.AlignRight
                    elide: Text.ElideRight
                }

            }

            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 5
                radius: 2
                color: Theme.background

                Rectangle {
                    width: Math.max(3, parent.width * metric.percent / 100)
                    height: parent.height
                    radius: parent.radius
                    color: metric.accent

                    Behavior on width {
                        NumberAnimation {
                            duration: 180
                            easing.type: Easing.OutCubic
                        }

                    }

                }

            }

        }

    }

    component SliderControl: ColumnLayout {
        id: slider

        property string title: ""
        property string currentText: ""
        property string currentId: ""
        property var options: []
        property string visualId: currentId
        property int selectedIndex: {
            for (let i = 0; i < options.length; i++) {
                if (options[i].id === visualId)
                    return i;

            }
            return 0;
        }

        signal selected(string id)

        spacing: 4
        onCurrentIdChanged: visualId = currentId

        RowLayout {
            Layout.fillWidth: true

            Text {
                text: slider.title
                color: Theme.muted
                font.family: Theme.fontFamily
                font.pixelSize: 9
            }

            Text {
                Layout.fillWidth: true
                text: slider.currentText
                color: Theme.foreground
                font.family: Theme.fontFamily
                font.pixelSize: 9
                horizontalAlignment: Text.AlignRight
                elide: Text.ElideRight
            }

        }

        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 32
            radius: 16
            color: Theme.surface
            border.color: Theme.surfaceAlt
            border.width: 1
            clip: true

            Rectangle {
                x: 3 + slider.selectedIndex * ((parent.width - 6) / Math.max(1, slider.options.length))
                y: 3
                width: (parent.width - 6) / Math.max(1, slider.options.length)
                height: parent.height - 6
                radius: 13
                color: "#66453d3d"

                Behavior on x {
                    NumberAnimation {
                        duration: 150
                        easing.type: Easing.OutCubic
                    }

                }

            }

            RowLayout {
                anchors.fill: parent
                anchors.margins: 3
                spacing: 0

                Repeater {
                    model: slider.options

                    Rectangle {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        radius: 13
                        color: sliderMouse.containsMouse ? "#333b3c4a" : "transparent"

                        Text {
                            anchors.centerIn: parent
                            text: modelData.icon
                            color: modelData.id === slider.visualId ? Theme.yellow : Theme.foreground
                            font.family: Theme.fontFamily
                            font.pixelSize: 14
                        }

                        MouseArea {
                            id: sliderMouse

                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                slider.visualId = modelData.id;
                                slider.selected(modelData.id);
                            }
                        }

                    }

                }

            }

        }

    }

}
