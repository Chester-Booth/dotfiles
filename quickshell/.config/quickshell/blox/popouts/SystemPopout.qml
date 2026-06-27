import "../shared"
import QtQuick
import QtQuick.Layouts

Rectangle {
    id: root

    property string mode: ""
    property string title: ""
    property string body: ""
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
    readonly property bool audioOverdriven: currentMode() === "audio" && !audioMuted && audioVolume > 100
    readonly property bool visualAudioOverdriven: currentMode() === "audio" && !audioMuted && visualAudioVolume > 100

    signal action(string command, bool keepOpen)
    signal sectionSelected(string panel)

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
            return audioMuted ? "Muted" : audioVolume + "%";

        if (currentMode() === "brightness")
            return brightnessPercent + "% • " + (blueLightActive ? "Active" : "Inactive");

        if (currentMode() === "bluetooth")
            return body.split("\n").join(" ");

        return body.split("\n")[0];
    }

    onAudioVolumeChanged: visualAudioVolume = audioVolume
    onBrightnessPercentChanged: visualBrightnessPercent = brightnessPercent
    onBlueLightModeChanged: visualBlueLightMode = blueLightMode
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
                        onClicked: root.action("pactl set-sink-mute @DEFAULT_SINK@ toggle", true)
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
                onChanged: (value) => {
                    root.visualAudioVolume = value;
                    root.action("pactl set-sink-volume @DEFAULT_SINK@ " + value + "%", true);
                }
            }

            SlideToggle {
                Layout.fillWidth: true
                visible: root.currentMode() === "audio"
                title: "Microphone"
                currentText: root.micMuted ? "Muted" : "Open"
                leftSelected: !root.micMuted
                leftIcon: "󰍬"
                rightIcon: "󰍭"
                onToggled: root.action("pactl set-source-mute @DEFAULT_SOURCE@ toggle", true)
            }

            SlideToggle {
                Layout.fillWidth: true
                visible: root.currentMode() === "network"
                title: "Wi-Fi"
                currentText: root.networkEnabled ? "On" : "Off"
                leftSelected: root.networkEnabled
                leftIcon: "󰤯"
                rightIcon: "󰤭"
                onToggled: root.action("nmcli radio wifi " + (root.networkEnabled ? "off" : "on"), true)
            }

            SlideToggle {
                Layout.fillWidth: true
                visible: root.currentMode() === "bluetooth"
                title: "Bluetooth"
                currentText: root.bluetoothEnabled ? "On" : "Off"
                leftSelected: root.bluetoothEnabled
                leftIcon: "󰂯"
                rightIcon: "󰂲"
                onToggled: root.action("rfkill toggle bluetooth", true)
            }

            LevelSlider {
                Layout.fillWidth: true
                visible: root.currentMode() === "brightness"
                value: root.visualBrightnessPercent
                accent: Theme.yellow
                onChanged: (value) => {
                    root.visualBrightnessPercent = value;
                    root.action("brightnessctl -d amdgpu_bl1 set " + value + "%", true);
                }
            }

            SegmentControl {
                Layout.fillWidth: true
                visible: root.currentMode() === "brightness"
                title: "Blue light"
                currentId: root.visualBlueLightMode
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

                    root.visualBlueLightMode = id;
                    root.action(root.scriptRoot + "/display/blue-light-mode.sh " + id, true);
                }
            }

            Text {
                Layout.fillWidth: true
                visible: root.body.length > 0 && root.currentMode() !== "network" && root.currentMode() !== "bluetooth" && root.currentMode() !== "brightness"
                text: root.body
                color: Theme.foreground
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
        color: active ? "#553b3c4a" : sectionMouse.containsMouse ? Theme.surfaceAlt : "transparent"

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
        property color knobColor: accent === Theme.yellow ? "#b79a55" : accent === Theme.red ? "#ad4f63" : "#4f74ad"
        property color overdriveTrackColor: Qt.rgba(Theme.surface.r * 0.82 + Theme.red.r * 0.18, Theme.surface.g * 0.82 + Theme.red.g * 0.18, Theme.surface.b * 0.82 + Theme.red.b * 0.18, 1)

        signal changed(int value)

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

                Behavior on width {
                    NumberAnimation {
                        duration: 120
                        easing.type: Easing.OutCubic
                    }

                }

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

                Behavior on x {
                    NumberAnimation {
                        duration: 120
                        easing.type: Easing.OutCubic
                    }

                }

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
                onPressed: (mouse) => slider.changed(valueAt(mouse.x))
                onPositionChanged: (mouse) => {
                    if (pressed)
                        slider.changed(valueAt(mouse.x));
                }
            }

        }

    }

    component SlideToggle: ColumnLayout {
        id: toggle

        property string title: ""
        property string currentText: ""
        property bool leftSelected: true
        property string leftIcon: ""
        property string rightIcon: ""

        signal toggled()

        spacing: 4

        RowLayout {
            Layout.fillWidth: true

            Text {
                Layout.fillWidth: true
                text: toggle.title
                color: Theme.muted
                font.family: Theme.bodyFontFamily
                font.pixelSize: 12
                font.bold: true
            }

            Text {
                text: toggle.currentText
                color: Theme.foreground
                font.family: Theme.bodyFontFamily
                font.pixelSize: 10
                horizontalAlignment: Text.AlignRight
                elide: Text.ElideRight
            }

        }

        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 32
            radius: 999
            color: Theme.surface
            border.color: Theme.surfaceAlt
            border.width: 1

            Rectangle {
                width: (parent.width - 6) / 2
                height: 26
                radius: 13
                x: toggle.leftSelected ? 3 : parent.width - width - 3
                anchors.verticalCenter: parent.verticalCenter
                color: "#66453d3d"

                Behavior on x {
                    NumberAnimation {
                        duration: 120
                        easing.type: Easing.OutCubic
                    }
                }
            }

            Item {
                anchors.left: parent.left
                anchors.top: parent.top
                anchors.bottom: parent.bottom
                width: parent.width / 2

                Text {
                    anchors.centerIn: parent
                    text: toggle.leftIcon
                    color: toggle.leftSelected ? Theme.blue : Theme.foreground
                    font.family: Theme.fontFamily
                    font.pixelSize: 14
                }
            }

            Item {
                anchors.right: parent.right
                anchors.top: parent.top
                anchors.bottom: parent.bottom
                width: parent.width / 2

                Text {
                    anchors.centerIn: parent
                    text: toggle.rightIcon
                    color: toggle.leftSelected ? Theme.foreground : Theme.yellow
                    font.family: Theme.fontFamily
                    font.pixelSize: 14
                }
            }

            MouseArea {
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: toggle.toggled()
            }

        }

    }

    component SegmentControl: ColumnLayout {
        id: segment

        property string title: ""
        property string currentId: ""
        property var options: []
        property string currentText: {
            for (let i = 0; i < options.length; i++) {
                if (options[i].id === currentId)
                    return options[i].label || "";

            }
            return "";
        }
        property int selectedIndex: {
            for (let i = 0; i < options.length; i++) {
                if (options[i].id === currentId)
                    return i;

            }
            return 0;
        }

        signal selected(string id)

        spacing: 4

        RowLayout {
            Layout.fillWidth: true

            Text {
                Layout.fillWidth: true
                text: segment.title
                color: Theme.muted
                font.family: Theme.bodyFontFamily
                font.pixelSize: 12
                font.bold: true
            }

            Text {
                text: segment.currentText
                color: Theme.foreground
                font.family: Theme.bodyFontFamily
                font.pixelSize: 10
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
                x: 3 + segment.selectedIndex * ((parent.width - 6) / Math.max(1, segment.options.length))
                y: 3
                width: (parent.width - 6) / Math.max(1, segment.options.length)
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
                    model: segment.options

                    Rectangle {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        radius: 13
                        color: segmentMouse.containsMouse ? "#333b3c4a" : "transparent"

                        Text {
                            anchors.centerIn: parent
                            text: modelData.icon
                            color: modelData.id === segment.currentId ? Theme.yellow : Theme.foreground
                            font.family: Theme.fontFamily
                            font.pixelSize: 14
                        }

                        MouseArea {
                            id: segmentMouse

                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: segment.selected(modelData.id)
                        }

                    }

                }

            }

        }

    }

}
