import "../shared"
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io

Scope {
    id: root

    property string label: "Volume"
    property string icon: "󰕾"
    property int value: 0
    property bool muted: false
    property string valueText: "0%"
    property bool showing: false
    property string scriptRoot: Quickshell.shellDir + "/scripts"
    property bool segmented: false
    property int segments: 3
    property int activeSegments: 0
    readonly property bool volumeOverdriven: label === "Volume" && !muted && value > 100
    readonly property int fillValue: Math.max(0, Math.min(100, value))

    function clamp(percent) {
        return Math.max(0, Math.min(100, parseInt(percent) || 0));
    }

    function iconForKeyboardLevel(level) {
        if (level <= 0)
            return "󰹐";

        if (level === 1)
            return "󱩐";

        if (level === 2)
            return "󱩓";

        return "󰛨";
    }

    function show(kind, percent, isMuted) {
        value = kind === "volume" ? Math.max(0, parseInt(percent) || 0) : clamp(percent);
        muted = isMuted === true || isMuted === "true" || isMuted === "yes" || isMuted === "1";
        segmented = false;
        segments = 3;
        activeSegments = Math.round(value * segments / 100);
        if (kind === "brightness") {
            label = "Brightness";
            icon = "󰃠";
            valueText = value + "%";
        } else if (kind === "keyboard") {
            label = "Keyboard Backlight";
            segmented = true;
            activeSegments = Math.max(0, Math.min(segments, Math.round(value * segments / 100)));
            icon = iconForKeyboardLevel(activeSegments);
            valueText = "";
        } else if (kind === "camera") {
            label = "Camera";
            icon = muted ? "󰗟" : "󰄀";
            valueText = muted ? "Off" : "On";
        } else if (kind === "touchpad") {
            label = "Touchpad";
            icon = muted ? "󰤳" : "󰟸";
            valueText = muted ? "Off" : "On";
        } else if (kind === "caps") {
            label = "Caps Lock";
            icon = muted ? "󰬶" : "󰬵";
            valueText = muted ? "On" : "Off";
        } else if (kind === "mic") {
            label = "Microphone";
            icon = muted ? "󰍭" : "󰍬";
            valueText = muted ? "Muted" : "Unmuted";
        } else {
            label = "Volume";
            icon = muted ? "󰝟" : value > 100 ? "󰝝" : value < 35 ? "󰕿" : value < 70 ? "󰖀" : "󰕾";
            valueText = muted ? "Muted" : value + "%";
        }
        showing = true;
        hideDelay.restart();
    }

    IpcHandler {
        function volume(percent: string, muted: string) : string {
            root.show("volume", percent, muted);
            return "ok";
        }

        function brightness(percent: string) : string {
            root.show("brightness", percent, false);
            return "ok";
        }

        function mic(percent: string, muted: string) : string {
            root.show("mic", percent, muted);
            return "ok";
        }

        function keyboard(percent: string) : string {
            root.show("keyboard", percent, false);
            return "ok";
        }

        function caps(enabled: string) : string {
            root.show("caps", enabled === "true" || enabled === "1" || enabled === "yes" ? 100 : 0, enabled);
            return "ok";
        }

        function camera(enabled: string) : string {
            const active = enabled === "true" || enabled === "1" || enabled === "yes";
            root.show("camera", active ? 100 : 0, !active);
            return "ok";
        }

        function touchpad(enabled: string) : string {
            const active = enabled === "true" || enabled === "1" || enabled === "yes";
            root.show("touchpad", active ? 100 : 0, !active);
            return "ok";
        }

        target: "osd"
    }

    Timer {
        id: hideDelay

        interval: 1200
        repeat: false
        onTriggered: root.showing = false
    }

    Timer {
        id: restartKeyboardWatcher

        interval: 2000
        repeat: false
        onTriggered: keyboardWatcher.running = true
    }

    Process {
        id: keyboardWatcher

        command: [root.scriptRoot + "/osd/watch-keyboard-backlight.sh"]
        running: true
        onExited: restartKeyboardWatcher.restart()

        stdout: SplitParser {
            splitMarker: "\n"
            onRead: (data) => {
                let event = {
                };
                try {
                    event = JSON.parse(data.trim());
                } catch (error) {
                    return ;
                }
                const max = parseInt(event.max) || 0;
                const value = parseInt(event.value) || 0;
                if (max > 0)
                    root.show("keyboard", Math.round(value * 100 / max), false);

            }
        }

    }

    Variants {
        model: Quickshell.screens

        PanelWindow {
            required property var modelData

            screen: modelData
            visible: root.showing
            implicitWidth: 320
            implicitHeight: 128
            exclusiveZone: 0
            focusable: false
            color: "transparent"

            anchors {
                bottom: true
            }

            Rectangle {
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.bottom: parent.bottom
                anchors.bottomMargin: 28
                width: 292
                height: 72
                radius: 8
                color: Theme.background
                border.color: Theme.surfaceAlt
                border.width: 1
                opacity: root.showing ? 1 : 0

                RowLayout {
                    anchors.fill: parent
                    anchors.margins: 12
                    spacing: 12

                    Text {
                        Layout.preferredWidth: 34
                        horizontalAlignment: Text.AlignHCenter
                        text: root.icon
                        color: root.volumeOverdriven ? Theme.red : root.muted ? Theme.yellow : Theme.foreground
                        font.family: Theme.fontFamily
                        font.pixelSize: 26
                    }

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 8

                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 8

                            Text {
                                Layout.fillWidth: true
                                text: root.label
                                color: Theme.foreground
                                font.family: Theme.fontFamily
                                font.pixelSize: 12
                                font.bold: true
                                elide: Text.ElideRight
                            }

                            Text {
                                text: root.valueText
                                color: root.volumeOverdriven ? Theme.red : root.muted ? Theme.yellow : Theme.muted
                                font.family: Theme.fontFamily
                                font.pixelSize: 11
                            }

                        }

                        Rectangle {
                            Layout.fillWidth: true
                            Layout.preferredHeight: 8
                            radius: 4
                            color: Theme.surface
                            visible: !root.segmented

                            Rectangle {
                                width: Math.round(parent.width * root.fillValue / 100)
                                height: parent.height
                                radius: 4
                                color: root.volumeOverdriven ? Theme.red : root.muted ? Theme.yellow : Theme.blue
                            }

                        }

                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 7
                            visible: root.segmented

                            Repeater {
                                model: root.segments

                                Rectangle {
                                    Layout.fillWidth: true
                                    Layout.preferredHeight: 8
                                    radius: 4
                                    color: index < root.activeSegments ? Theme.blue : Theme.surface
                                }

                            }

                        }

                    }

                }

                Behavior on opacity {
                    NumberAnimation {
                        duration: 120
                        easing.type: Easing.OutCubic
                    }

                }

            }

        }

    }

}
