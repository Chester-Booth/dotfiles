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
    property string wifiIcon: "󰤩"
    property string wifiText: "Wi-Fi"
    property string bluetoothIcon: "󰂯"
    property string brightnessIcon: "󰃠"
    property int brightnessPercent: 0
    property string blueLightMode: "auto"
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
            return brightnessPercent + "%";

        if (currentMode() === "bluetooth")
            return (micMuted ? "Mic muted" : "Mic open") + "  |  " + body.split("\n")[0];

        return body.split("\n")[0];
    }

    function micActions() {
        return actions.filter((item) => {
            return String(item.label || "").toLowerCase().indexOf("mic") >= 0;
        });
    }

    function bluetoothActions() {
        return actions.filter((item) => {
            return String(item.label || "").toLowerCase().indexOf("mic") < 0;
        });
    }

    function normalActions() {
        return actions.filter((item) => {
            return String(item.label || "").toLowerCase().indexOf("open app") < 0;
        });
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
                        font.family: Theme.fontFamily
                        font.pixelSize: 13
                        font.bold: true
                    }

                    Text {
                        Layout.fillWidth: true
                        text: root.subtitle()
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
                    visible: root.actionByLabel("open app") !== null && root.currentMode() !== "bluetooth"

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
                accent: root.visualAudioOverdriven ? Theme.red : Theme.blue
                onChanged: (value) => {
                    root.visualAudioVolume = value;
                    root.action("pactl set-sink-volume @DEFAULT_SINK@ " + value + "%", true);
                }
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
                    "icon": "󰃞"
                }, {
                    "id": "auto",
                    "icon": "󰖙"
                }, {
                    "id": "on",
                    "icon": "󰖔"
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
                text: root.body
                color: Theme.foreground
                font.family: Theme.fontFamily
                font.pixelSize: 11
                wrapMode: Text.Wrap
                maximumLineCount: 4
                elide: Text.ElideRight
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 8
                visible: root.currentMode() === "bluetooth"

                Text {
                    Layout.fillWidth: true
                    text: "Microphone"
                    color: Theme.muted
                    font.family: Theme.fontFamily
                    font.pixelSize: 10
                    font.bold: true
                }

                Flow {
                    Layout.fillWidth: true
                    spacing: 8

                    Repeater {
                        model: root.micActions()

                        ActionChip {
                            label: modelData.label || ""
                            danger: !!modelData.danger
                            onClicked: root.action(modelData.command || "", !!modelData.keepOpen)
                        }

                    }

                }

                Text {
                    Layout.fillWidth: true
                    text: "Bluetooth"
                    color: Theme.muted
                    font.family: Theme.fontFamily
                    font.pixelSize: 10
                    font.bold: true
                }

                Flow {
                    Layout.fillWidth: true
                    spacing: 8

                    Repeater {
                        model: root.bluetoothActions()

                        ActionChip {
                            label: modelData.label || ""
                            danger: !!modelData.danger
                            onClicked: root.action(modelData.command || "", !!modelData.keepOpen)
                        }

                    }

                }

            }

            Flow {
                Layout.fillWidth: true
                spacing: 8
                visible: root.currentMode() !== "bluetooth"

                Repeater {
                    model: root.normalActions()

                    ActionChip {
                        label: modelData.label || ""
                        danger: !!modelData.danger
                        onClicked: root.action(modelData.command || "", !!modelData.keepOpen)
                    }

                }

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
        property color accent: Theme.blue
        property color knobColor: accent === Theme.yellow ? "#b79a55" : accent === Theme.red ? "#ad4f63" : "#4f74ad"

        signal changed(int value)

        spacing: 8

        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 14
            radius: 7
            color: Theme.surface

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
                    return Math.round(Math.max(0, Math.min(1, xPos / width)) * slider.maxValue);
                }

                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onPressed: (mouse) => {
                    return slider.value = valueAt(mouse.x);
                }
                onPositionChanged: (mouse) => {
                    if (pressed) {
                        slider.value = valueAt(mouse.x);
                        slider.changed(slider.value);
                    }
                }
                onPressedChanged: {
                    if (pressed)
                        slider.changed(slider.value);

                }
            }

        }

    }

    component ActionChip: Rectangle {
        id: chip

        property string label: ""
        property bool danger: false

        signal clicked()

        width: Math.max(46, chipLabel.implicitWidth + 20)
        height: 32
        radius: 8
        color: chipMouse.containsMouse ? Theme.surfaceAlt : Theme.surface
        border.color: danger ? Theme.red : Theme.surfaceAlt
        border.width: 1

        Text {
            id: chipLabel

            anchors.centerIn: parent
            text: chip.label
            color: chip.danger ? Theme.red : Theme.foreground
            font.family: Theme.fontFamily
            font.pixelSize: 10
            font.bold: true
        }

        MouseArea {
            id: chipMouse

            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: chip.clicked()
        }

    }

    component SegmentControl: ColumnLayout {
        id: segment

        property string title: ""
        property string currentId: ""
        property var options: []
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
                font.family: Theme.fontFamily
                font.pixelSize: 10
                font.bold: true
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
