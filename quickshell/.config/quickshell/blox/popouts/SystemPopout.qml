import "../shared"
import QtQuick
import QtQuick.Layouts

Rectangle {
    id: root

    property string mode: ""
    property string title: ""
    property string body: ""
    property var actions: []
    property int audioVolume: 0
    property bool audioMuted: false
    property bool micMuted: false
    property string wifiIcon: "󰤩"
    property string wifiText: "Wi-Fi"
    property string bluetoothIcon: "󰂯"
    property int brightnessPercent: 0

    signal action(string command, bool keepOpen)

    function actionByLabel(text) {
        const lower = text.toLowerCase();
        for (let i = 0; i < actions.length; i++) {
            const label = String(actions[i].label || "").toLowerCase();
            if (label.indexOf(lower) >= 0)
                return actions[i];

        }
        return null;
    }

    function runLabel(text, keep) {
        const item = actionByLabel(text);
        if (item)
            action(item.command || "", keep);

    }

    function heroIcon() {
        if (mode === "audio")
            return audioMuted ? "󰝟" : "󰕾";

        if (mode === "mic")
            return micMuted ? "󰍭" : "󰍬";

        if (mode === "network")
            return wifiIcon;

        if (mode === "bluetooth")
            return bluetoothIcon;

        if (mode === "brightness")
            return "󰃠";

        if (mode === "system")
            return "󰓅";

        return "󰁹";
    }

    function sliderValue() {
        if (mode === "audio")
            return audioVolume;

        if (mode === "brightness")
            return brightnessPercent;

        return 0;
    }

    width: 330
    height: Math.min(520, Math.max(178, content.implicitHeight + 24))
    radius: 8
    color: Theme.background
    border.color: Theme.surfaceAlt
    border.width: 1

    RowLayout {
        id: content

        anchors.fill: parent
        anchors.margins: 12
        spacing: 12

        Column {
            Layout.preferredWidth: 38
            spacing: 8

            Repeater {
                model: [{
                    "icon": root.mode === "network" ? root.wifiIcon : "󰤩",
                    "active": root.mode === "network"
                }, {
                    "icon": root.mode === "bluetooth" ? root.bluetoothIcon : "󰂯",
                    "active": root.mode === "bluetooth"
                }, {
                    "icon": root.mode === "mic" ? root.heroIcon() : "󰍬",
                    "active": root.mode === "mic"
                }, {
                    "icon": root.mode === "brightness" ? "󰃠" : "󰃟",
                    "active": root.mode === "brightness"
                }]

                Rectangle {
                    width: 34
                    height: 34
                    radius: 8
                    color: modelData.active ? "#553b3c4a" : "transparent"

                    Text {
                        anchors.centerIn: parent
                        text: modelData.icon
                        color: modelData.active ? Theme.blue : Theme.muted
                        font.family: Theme.fontFamily
                        font.pixelSize: 17
                    }

                }

            }

        }

        ColumnLayout {
            Layout.fillWidth: true
            spacing: 10

            RowLayout {
                Layout.fillWidth: true
                spacing: 10

                Text {
                    text: root.heroIcon()
                    color: mode === "system" ? Theme.yellow : Theme.foreground
                    font.family: Theme.fontFamily
                    font.pixelSize: 24
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 2

                    Text {
                        Layout.fillWidth: true
                        text: root.title
                        color: Theme.foreground
                        font.family: Theme.fontFamily
                        font.pixelSize: 13
                        font.bold: true
                    }

                    Text {
                        Layout.fillWidth: true
                        text: root.mode === "network" ? root.wifiText : root.mode === "audio" ? (root.audioMuted ? "Muted" : root.audioVolume + "%") : root.mode === "brightness" ? root.brightnessPercent + "%" : root.mode === "mic" ? (root.micMuted ? "Muted" : "Open") : root.body.split("\n")[0]
                        color: Theme.muted
                        font.family: Theme.fontFamily
                        font.pixelSize: 10
                        elide: Text.ElideRight
                    }

                }

                Rectangle {
                    width: 30
                    height: 30
                    radius: 7
                    color: cogMouse.containsMouse ? Theme.surfaceAlt : Theme.surface
                    visible: root.actionByLabel("open app") !== null

                    Text {
                        anchors.centerIn: parent
                        text: "󰒓"
                        color: Theme.foreground
                        font.family: Theme.fontFamily
                        font.pixelSize: 14
                    }

                    MouseArea {
                        id: cogMouse

                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.runLabel("open app", false)
                    }

                }

            }

            Rectangle {
                Layout.fillWidth: true
                height: 10
                radius: 5
                color: Theme.surface
                visible: root.mode === "audio" || root.mode === "brightness"

                Rectangle {
                    width: parent.width * Math.max(0, Math.min(100, root.sliderValue())) / 100
                    height: parent.height
                    radius: parent.radius
                    color: root.mode === "brightness" ? Theme.yellow : Theme.blue
                }

            }

            Text {
                Layout.fillWidth: true
                text: root.body
                color: Theme.foreground
                font.family: Theme.fontFamily
                font.pixelSize: 11
                wrapMode: Text.Wrap
                maximumLineCount: root.mode === "system" ? 10 : 4
                elide: Text.ElideRight
            }

            Flow {
                Layout.fillWidth: true
                spacing: 8

                Repeater {
                    model: root.actions.filter((item) => {
                        return String(item.label || "").toLowerCase().indexOf("open app") < 0;
                    })

                    Rectangle {
                        width: Math.max(46, label.implicitWidth + 20)
                        height: 32
                        radius: 8
                        color: actionMouse.containsMouse ? Theme.surfaceAlt : Theme.surface
                        border.color: modelData.danger ? Theme.red : Theme.surfaceAlt
                        border.width: 1

                        Text {
                            id: label

                            anchors.centerIn: parent
                            text: modelData.label || ""
                            color: modelData.danger ? Theme.red : Theme.foreground
                            font.family: Theme.fontFamily
                            font.pixelSize: 10
                            font.bold: true
                        }

                        MouseArea {
                            id: actionMouse

                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.action(modelData.command || "", !!modelData.keepOpen)
                        }

                    }

                }

            }

        }

    }

}
