import "../shared"
import QtQuick
import QtQuick.Layouts

ColumnLayout {
    id: root

    required property SystemPopoutController controller

    Layout.fillWidth: true
    visible: controller.currentMode() === "brightness"
    spacing: 10

    SystemLevelSlider {
        Layout.fillWidth: true
        value: root.controller.visualBrightnessPercent
        accent: Theme.yellow
        onDragStarted: root.controller.adjustingBrightness = true
        onChanged: (value) => {
            root.controller.queueBrightness(value);
        }
        onDragFinished: root.controller.finishBrightness()
    }

    PillSelector {
        Layout.fillWidth: true
        title: "Blue light"
        currentId: root.controller.visualBlueLightMode
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
            if (id === root.controller.visualBlueLightMode)
                return ;

            root.controller.runCommand(root.controller.scriptRoot + "/display/blue-light-mode.sh " + id, true);
        }
    }

}
