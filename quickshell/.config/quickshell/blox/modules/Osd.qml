import "../shared"
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Wayland

Scope {
    id: root

    property string label: "Volume"
    property string icon: "󰕾"
    property int value: 0
    property bool muted: false
    property string valueText: "0%"
    property bool showing: false
    property bool rendered: false
    property string scriptRoot: Quickshell.shellDir + "/scripts"
    property bool segmented: false
    property int segments: 3
    property int activeSegments: 0
    property bool noticeMode: false
    property color noticeAccent: Theme.blue
    property double volumePreviewUntil: 0
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

    function showFor(durationMs) {
        hideDelay.interval = Math.max(500, parseInt(durationMs) || 1200);
        rendered = true;
        showing = true;
        hideFinish.stop();
        hideDelay.restart();
    }

    function showBlueLight(mode, active) {
        const id = String(mode || "auto").toLowerCase();
        const isActive = active === true || active === "true" || active === "yes" || active === "1";
        label = "Blue light";
        muted = false;
        segmented = false;
        noticeMode = true;
        noticeAccent = Theme.blue;
        if (id === "off" || id === "disable" || id === "disabled") {
            icon = "󰃞";
            value = 0;
            valueText = "";
        } else if (id === "on") {
            icon = "󰖔";
            value = 100;
            valueText = "";
        } else {
            icon = "󰖙";
            value = isActive ? 100 : 0;
            valueText = "Auto";
        }
        showFor(1200);
    }

    function showGpu(mode) {
        const id = String(mode || "eco").toLowerCase();
        label = "GPU mode";
        muted = false;
        noticeMode = false;
        segmented = true;
        segments = 4;
        if (id === "gaming" || id === "gpu144") {
            activeSegments = 4;
            icon = "󰪫";
            valueText = "GPU 144";
        } else if (id === "performance" || id === "gpu60") {
            activeSegments = 3;
            icon = "󰢮";
            valueText = "GPU 60";
        } else if (id === "high-refresh" || id === "igpu144") {
            activeSegments = 2;
            icon = "";
            valueText = "iGPU 144";
        } else {
            activeSegments = 1;
            icon = "󰌪";
            valueText = "iGPU 60";
        }
        value = Math.round(activeSegments * 100 / segments);
        showFor(4500);
    }

    function showFan(profile) {
        const id = String(profile || "balanced").toLowerCase();
        label = "Fan profile";
        muted = false;
        noticeMode = false;
        segmented = true;
        segments = 3;
        if (id === "quiet") {
            activeSegments = 1;
            icon = "󰠝";
            valueText = "Quiet";
        } else if (id === "performance") {
            activeSegments = 3;
            icon = "󱑬";
            valueText = "Performance";
        } else {
            activeSegments = 2;
            icon = "󱜝";
            valueText = "Balanced";
        }
        value = Math.round(activeSegments * 100 / segments);
        showFor(1200);
    }

    function show(kind, percent, isMuted) {
        noticeAccent = Theme.blue;
        noticeMode = false;
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
        showFor(1200);
    }

    function preview(kind, percent, isMuted) {
        if (kind === "volume")
            volumePreviewUntil = Date.now() + 300;

        show(kind, percent, isMuted);
    }

    function showNotice(title, message, iconName, level, durationMs) {
        label = title || "Status";
        icon = iconName || "󰋼";
        valueText = message || "";
        value = 100;
        muted = false;
        segmented = false;
        noticeMode = true;
        noticeAccent = level === "error" || level === "critical" ? Theme.red : level === "warning" ? Theme.yellow : Theme.blue;
        showFor(durationMs);
    }

    Connections {
        function onOsdPositionPreviewRequested() {
            root.showNotice("OSD position", "Previewing the selected position", "󰍹", "info", 1400);
        }

        target: Theme
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

        function fan(profile: string) : string {
            root.showFan(profile);
            return "ok";
        }

        function blueLight(mode: string, active: string) : string {
            root.showBlueLight(mode, active);
            return "ok";
        }

        function gpu(mode: string) : string {
            root.showGpu(mode);
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

        function notice(title: string, message: string, icon: string, level: string, durationMs: string) : string {
            root.showNotice(title, message, icon, level, durationMs);
            return "ok";
        }

        target: "osd"
    }

    Timer {
        id: hideDelay

        interval: 1200
        repeat: false
        onTriggered: {
            root.showing = false;
            hideFinish.restart();
        }
    }

    Timer {
        id: hideFinish

        interval: 190
        repeat: false
        onTriggered: {
            if (!root.showing)
                root.rendered = false;

        }
    }

    Timer {
        id: restartKeyboardWatcher

        interval: 2000
        repeat: false
        onTriggered: keyboardWatcher.running = true
    }

    Timer {
        id: restartAudioWatcher

        interval: 2000
        repeat: false
        onTriggered: audioWatcher.running = true
    }

    Process {
        id: audioWatcher

        command: [root.scriptRoot + "/osd/watch-audio.sh"]
        running: true
        onExited: (exitCode) => {
            if (exitCode !== 0)
                restartAudioWatcher.restart();

        }
        Component.onDestruction: {
            if (running)
                signal(15);

        }

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
                if (Date.now() >= root.volumePreviewUntil)
                    root.show("volume", event.volume, event.muted);
            }
        }

    }

    Process {
        id: keyboardWatcher

        command: [root.scriptRoot + "/osd/watch-keyboard-backlight.sh"]
        running: true
        onExited: (exitCode) => {
            if (exitCode !== 0)
                restartKeyboardWatcher.restart();

        }
        Component.onDestruction: {
            if (running)
                signal(15);

        }

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
            id: osdWindow

            required property var modelData
            readonly property bool onLeft: Theme.osdPosition === "top-left" || Theme.osdPosition === "bottom-left"
            readonly property bool onRight: Theme.osdPosition === "top-right" || Theme.osdPosition === "bottom-right"
            readonly property bool onTop: Theme.osdPosition.indexOf("top") >= 0
            readonly property bool onBottom: Theme.osdPosition.indexOf("bottom") >= 0
            readonly property bool horizontallyCentred: !onLeft && !onRight
            readonly property real restingGap: Math.max(0, onTop ? 28 + Theme.osdOffsetY : 28 - Theme.osdOffsetY)

            screen: modelData
            visible: root.rendered
            implicitWidth: 292 + (horizontallyCentred ? 2 * Math.abs(Theme.osdOffsetX) : 0)
            implicitHeight: 72 + restingGap
            exclusiveZone: 0
            focusable: false
            color: "transparent"
            WlrLayershell.layer: WlrLayer.Overlay
            WlrLayershell.namespace: "blox-osd"

            anchors {
                left: onLeft
                right: onRight
                top: onTop
                bottom: onBottom
            }

            margins {
                left: onLeft ? 28 + Theme.osdOffsetX : 0
                right: onRight ? 28 - Theme.osdOffsetX : 0
            }

            PopupWindow {
                id: osdPopup

                anchor.window: osdWindow
                anchor.rect.x: osdWindow.horizontallyCentred ? Math.abs(Theme.osdOffsetX) + Theme.osdOffsetX : 0
                anchor.rect.y: osdWindow.onTop ? osdWindow.restingGap : 0
                implicitWidth: 292
                implicitHeight: 72
                visible: root.rendered
                color: "transparent"

                Rectangle {
                    id: osdCard

                    anchors.fill: parent
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
                            color: root.volumeOverdriven ? Theme.red : root.muted ? Theme.yellow : root.noticeMode ? root.noticeAccent : Theme.foreground
                            font.family: Theme.fontFamily
                            font.pixelSize: 26
                        }

                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 8

                            RowLayout {
                                Layout.fillWidth: true
                                spacing: 8
                                visible: !root.noticeMode

                                Text {
                                    Layout.fillWidth: true
                                    text: root.label
                                    color: Theme.foreground
                                    font.family: Theme.bodyFontFamily
                                    font.pixelSize: 14
                                    font.bold: true
                                    elide: Text.ElideRight
                                }

                                Text {
                                    text: root.valueText
                                    color: root.volumeOverdriven ? Theme.red : root.muted ? Theme.yellow : Theme.muted
                                    font.family: Theme.bodyFontFamily
                                    font.pixelSize: 12
                                    elide: Text.ElideRight
                                    Layout.maximumWidth: 150
                                }

                            }

                            ColumnLayout {
                                Layout.fillWidth: true
                                spacing: 1
                                visible: root.noticeMode

                                Text {
                                    Layout.fillWidth: true
                                    text: root.label
                                    color: Theme.foreground
                                    font.family: Theme.bodyFontFamily
                                    font.pixelSize: 14
                                    font.bold: true
                                    elide: Text.ElideRight
                                }

                                Text {
                                    Layout.fillWidth: true
                                    text: root.valueText
                                    color: Theme.muted
                                    font.family: Theme.bodyFontFamily
                                    font.pixelSize: 12
                                    elide: Text.ElideRight
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
                                    color: root.volumeOverdriven ? Theme.red : root.muted ? Theme.yellow : root.noticeMode ? root.noticeAccent : Theme.blue
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

                    transform: Translate {
                        y: root.showing ? 0 : osdWindow.onTop ? -osdCard.height - osdWindow.restingGap : osdWindow.height

                        Behavior on y {
                            NumberAnimation {
                                duration: 190
                                easing.type: Easing.OutCubic
                            }

                        }

                    }

                    Behavior on opacity {
                        NumberAnimation {
                            duration: 140
                            easing.type: Easing.OutCubic
                        }

                    }

                }

                mask: Region {
                }

            }

            // OSD cards are informational only. Keep their input region empty so
            // pointer events always reach the application underneath.
            mask: Region {
            }

        }

    }

}
