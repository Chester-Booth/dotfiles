import "../shared"
import QtQuick
import QtQuick.Layouts

Rectangle {
    id: root

    property string mode: ""
    property string title: ""
    property string body: ""
    property string statusError: ""
    property var actions: []
    property string scriptRoot: ""
    property int audioVolume: 0
    property string audioIcon: "󰕾"
    property bool audioMuted: false
    property bool micMuted: false
    property bool networkEnabled: true
    property bool bluetoothEnabled: true
    property string wifiIcon: "󰤩"
    property string wifiText: "Wi-Fi"
    property string bluetoothIcon: "󰂯"
    property string brightnessIcon: "󰃠"
    property int brightnessPercent: 0
    property string blueLightMode: "auto"
    property bool blueLightActive: false
    property int visualAudioVolume: audioVolume
    property int visualBrightnessPercent: brightnessPercent
    property string visualBlueLightMode: blueLightMode
    property bool adjustingAudio: false
    property bool adjustingBrightness: false
    property bool audioApplyPending: false
    property bool brightnessApplyPending: false
    readonly property bool audioOverdriven: currentMode() === "audio" && !audioMuted && audioVolume > 100
    readonly property bool visualAudioOverdriven: currentMode() === "audio" && !audioMuted && visualAudioVolume > 100

    signal action(string command, bool keepOpen)
    signal sectionSelected(string panel)
    signal levelPreview(string kind, int value, bool muted)

    function currentMode() {
        return mode === "mic" ? "bluetooth" : mode;
    }

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
        if (currentMode() === "audio")
            return audioIcon;

        if (currentMode() === "network")
            return wifiIcon;

        if (currentMode() === "bluetooth")
            return bluetoothIcon;

        if (currentMode() === "brightness")
            return brightnessIcon;

        return "󰁹";
    }

    function subtitle() {
        if (currentMode() === "network")
            return wifiText;

        if (currentMode() === "audio")
            return audioMuted ? "Muted" : visualAudioVolume + "%";

        if (currentMode() === "brightness")
            return visualBrightnessPercent + "% • " + (blueLightActive ? "Active" : "Inactive");

        if (currentMode() === "bluetooth")
            return body.split("\n").join(" ");

        return body.split("\n")[0];
    }

    function applyAudio() {
        audioApplyPending = false;
        action(scriptRoot + "/control.sh audio-set-silent " + visualAudioVolume, true);
    }

    function queueAudio(value) {
        visualAudioVolume = value;
        levelPreview("volume", value, audioMuted);
        audioApplyPending = true;
        audioSyncDelay.stop();
        if (!audioApplyDelay.running) {
            applyAudio();
            audioApplyDelay.restart();
        }
    }

    function finishAudio() {
        adjustingAudio = false;
        audioApplyDelay.stop();
        if (audioApplyPending)
            applyAudio();

        audioSyncDelay.restart();
    }

    function applyBrightness() {
        brightnessApplyPending = false;
        action(scriptRoot + "/control.sh brightness-set-silent " + visualBrightnessPercent, true);
    }

    function queueBrightness(value) {
        visualBrightnessPercent = value;
        levelPreview("brightness", value, false);
        brightnessApplyPending = true;
        brightnessSyncDelay.stop();
        if (!brightnessApplyDelay.running) {
            applyBrightness();
            brightnessApplyDelay.restart();
        }
    }

    function finishBrightness() {
        adjustingBrightness = false;
        brightnessApplyDelay.stop();
        if (brightnessApplyPending)
            applyBrightness();

        brightnessSyncDelay.restart();
    }

    onAudioVolumeChanged: {
        if (!adjustingAudio && !audioSyncDelay.running)
            visualAudioVolume = audioVolume;

    }
    onBrightnessPercentChanged: {
        if (!adjustingBrightness && !brightnessSyncDelay.running)
            visualBrightnessPercent = brightnessPercent;

    }
    onBlueLightModeChanged: visualBlueLightMode = blueLightMode
    width: 330
    height: Math.min(520, Math.max(178, content.implicitHeight + 24))
    radius: 8
    color: Theme.background
    border.color: Theme.surfaceAlt
    border.width: 1

    Timer {
        id: audioApplyDelay

        interval: 50
        repeat: false
        onTriggered: {
            if (root.audioApplyPending) {
                root.applyAudio();
                restart();
            }
        }
    }

    Timer {
        id: brightnessApplyDelay

        interval: 50
        repeat: false
        onTriggered: {
            if (root.brightnessApplyPending) {
                root.applyBrightness();
                restart();
            }
        }
    }

    Timer {
        id: audioSyncDelay

        interval: 250
        repeat: false
        onTriggered: root.visualAudioVolume = root.audioVolume
    }

    Timer {
        id: brightnessSyncDelay

        interval: 250
        repeat: false
        onTriggered: root.visualBrightnessPercent = root.brightnessPercent
    }

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
                    "panel": "network",
                    "icon": root.wifiIcon
                }, {
                    "panel": "bluetooth",
                    "icon": root.bluetoothIcon
                }, {
                    "panel": "audio",
                    "icon": root.audioIcon
                }, {
                    "panel": "brightness",
                    "icon": root.brightnessIcon
                }]

                SectionButton {
                    icon: modelData.icon
                    active: root.currentMode() === modelData.panel
                    onClicked: root.sectionSelected(modelData.panel)
                }

            }

        }

        ColumnLayout {
            Layout.fillWidth: true
            spacing: 10

            RowLayout {
                Layout.fillWidth: true
                spacing: 10

                Rectangle {
                    width: 30
                    height: 30
                    radius: 7
                    color: root.currentMode() === "audio" && headerIconMouse.containsMouse ? Theme.surfaceAlt : "transparent"

                    Text {
                        anchors.centerIn: parent
                        text: root.heroIcon()
                        color: root.audioOverdriven ? Theme.red : root.currentMode() === "brightness" ? Theme.yellow : Theme.foreground
                        font.family: Theme.fontFamily
                        font.pixelSize: 24
                    }

                    MouseArea {
                        id: headerIconMouse

                        anchors.fill: parent
                        enabled: root.currentMode() === "audio"
                        hoverEnabled: true
                        cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                        onClicked: root.action(root.scriptRoot + "/control.sh audio-toggle", true)
                    }

                }

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 2

                    Text {
                        Layout.fillWidth: true
                        text: root.title
                        color: Theme.foreground
                        font.family: Theme.bodyFontFamily
                        font.pixelSize: 15
                        font.bold: true
                    }

                    Text {
                        Layout.fillWidth: true
                        text: root.subtitle()
                        color: Theme.muted
                        font.family: Theme.bodyFontFamily
                        font.pixelSize: 11
                        elide: Text.ElideRight
                    }

                }

                Rectangle {
                    width: 30
                    height: 30
                    radius: 7
                    color: cogMouse.containsMouse ? Theme.surfaceAlt : Theme.surface
                    border.color: Theme.surfaceAlt
                    border.width: 1
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

            LevelSlider {
                Layout.fillWidth: true
                visible: root.currentMode() === "audio"
                value: root.visualAudioVolume
                maxValue: 150
                snapValue: 100
                accent: root.visualAudioOverdriven ? Theme.red : Theme.blue
                onDragStarted: root.adjustingAudio = true
                onChanged: (value) => root.queueAudio(value)
                onDragFinished: root.finishAudio()
            }

            PillSelector {
                Layout.fillWidth: true
                visible: root.currentMode() === "audio"
                title: "Microphone"
                currentText: visualId === "muted" ? "Muted" : "Open"
                currentId: root.micMuted ? "muted" : "open"
                selectedAccent: visualId === "open" ? Theme.blue : Theme.yellow
                optimistic: true
                options: [{
                    "id": "open",
                    "icon": "󰍬",
                    "label": "Open"
                }, {
                    "id": "muted",
                    "icon": "󰍭",
                    "label": "Muted"
                }]
                onSelected: (id) => {
                    if (id !== currentId)
                        root.action(root.scriptRoot + "/control.sh mic " + id, true);

                }
            }

            PillSelector {
                Layout.fillWidth: true
                visible: root.currentMode() === "network"
                title: "Wi-Fi"
                currentText: visualId === "on" ? "On" : "Off"
                currentId: root.networkEnabled ? "on" : "off"
                selectedAccent: visualId === "on" ? Theme.blue : Theme.yellow
                optimistic: true
                options: [{
                    "id": "on",
                    "icon": "󰤯",
                    "label": "On"
                }, {
                    "id": "off",
                    "icon": "󰤭",
                    "label": "Off"
                }]
                onSelected: (id) => {
                    if (id !== currentId)
                        root.action(root.scriptRoot + "/control.sh wifi " + id, true);

                }
            }

            PillSelector {
                Layout.fillWidth: true
                visible: root.currentMode() === "bluetooth"
                title: "Bluetooth"
                currentText: visualId === "on" ? "On" : "Off"
                currentId: root.bluetoothEnabled ? "on" : "off"
                selectedAccent: visualId === "on" ? Theme.blue : Theme.yellow
                optimistic: true
                options: [{
                    "id": "on",
                    "icon": "󰂯",
                    "label": "On"
                }, {
                    "id": "off",
                    "icon": "󰂲",
                    "label": "Off"
                }]
                onSelected: (id) => {
                    if (id !== currentId)
                        root.action(root.scriptRoot + "/control.sh bluetooth " + id, true);

                }
            }

            LevelSlider {
                Layout.fillWidth: true
                visible: root.currentMode() === "brightness"
                value: root.visualBrightnessPercent
                accent: Theme.yellow
                onDragStarted: root.adjustingBrightness = true
                onChanged: (value) => root.queueBrightness(value)
                onDragFinished: root.finishBrightness()
            }

            PillSelector {
                Layout.fillWidth: true
                visible: root.currentMode() === "brightness"
                title: "Blue light"
                currentId: root.visualBlueLightMode
                optimistic: true
                options: [{
                    "id": "off",
                    "icon": "󰃞",
                    "label": "Off"
                }, {
                    "id": "auto",
                    "icon": "󰖙",
                    "label": "Auto"
                }, {
                    "id": "on",
                    "icon": "󰖔",
                    "label": "On"
                }]
                onSelected: (id) => {
                    if (id === root.visualBlueLightMode)
                        return ;

                    root.action(root.scriptRoot + "/display/blue-light-mode.sh " + id, true);
                }
            }

            Text {
                Layout.fillWidth: true
                visible: root.statusError.length > 0 || (root.body.length > 0 && root.currentMode() !== "network" && root.currentMode() !== "bluetooth" && root.currentMode() !== "brightness")
                text: root.statusError.length > 0 ? "Status error: " + root.statusError + (root.body.length > 0 ? "\n" + root.body : "") : root.body
                color: root.statusError.length > 0 ? Theme.red : Theme.foreground
                font.family: Theme.bodyFontFamily
                font.pixelSize: 12
                wrapMode: Text.Wrap
                maximumLineCount: 4
                elide: Text.ElideRight
            }

        }

    }

    component SectionButton: Rectangle {
        id: section

        property string icon: ""
        property bool active: false

        signal clicked()

        width: 34
        height: 34
        radius: 8
        color: active ? Theme.withAlpha(Theme.surfaceAlt, 0.33) : sectionMouse.containsMouse ? Theme.surfaceAlt : "transparent"

        Text {
            anchors.centerIn: parent
            text: section.icon
            color: section.active ? Theme.blue : Theme.muted
            font.family: Theme.fontFamily
            font.pixelSize: 17
        }

        MouseArea {
            id: sectionMouse

            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: section.clicked()
        }

    }

    component LevelSlider: RowLayout {
        id: slider

        property int value: 0
        property int maxValue: 100
        property int snapValue: -1
        property int snapDistance: 3
        property color accent: Theme.blue
        property color knobColor: Qt.darker(accent, 1.4)
        property color overdriveTrackColor: Qt.rgba(Theme.surface.r * 0.82 + Theme.red.r * 0.18, Theme.surface.g * 0.82 + Theme.red.g * 0.18, Theme.surface.b * 0.82 + Theme.red.b * 0.18, 1)

        signal changed(int value)
        signal dragStarted()
        signal dragFinished()

        spacing: 8

        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 14
            radius: 7
            color: Theme.surface

            Rectangle {
                anchors.right: parent.right
                width: slider.snapValue >= 0 && slider.snapValue < slider.maxValue ? parent.width * (slider.maxValue - slider.snapValue) / slider.maxValue : 0
                height: parent.height
                radius: parent.radius
                color: slider.overdriveTrackColor

                Rectangle {
                    anchors.left: parent.left
                    width: Math.min(parent.radius, parent.width)
                    height: parent.height
                    color: parent.color
                }

            }

            Rectangle {
                width: parent.width * Math.max(0, Math.min(slider.maxValue, slider.value)) / slider.maxValue
                height: parent.height
                radius: parent.radius
                color: slider.accent

            }

            Rectangle {
                width: 18
                height: 18
                radius: 9
                x: Math.max(0, Math.min(parent.width - width, parent.width * Math.max(0, Math.min(slider.maxValue, slider.value)) / slider.maxValue - width / 2))
                y: -2
                color: slider.knobColor
                border.color: slider.accent
                border.width: 2

            }

            MouseArea {
                function valueAt(xPos) {
                    const value = Math.round(Math.max(0, Math.min(1, xPos / width)) * slider.maxValue);
                    if (slider.snapValue >= 0 && Math.abs(value - slider.snapValue) <= slider.snapDistance)
                        return slider.snapValue;

                    return value;
                }

                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onPressed: (mouse) => {
                    slider.dragStarted();
                    slider.changed(valueAt(mouse.x));
                }
                onPositionChanged: (mouse) => {
                    if (pressed)
                        slider.changed(valueAt(mouse.x));

                }
                onReleased: slider.dragFinished()
                onCanceled: slider.dragFinished()
            }

        }

    }

}
