import "."
import QtQuick

Item {
    id: root

    property string openPanel: ""
    property real centerOffset: 0
    property string updateIcon: "󰧠"
    property var updatesStatus
    property var bluetoothStatus
    property var audioStatus
    property var brightnessStatus
    property var privacyStatus
    property string scriptRoot: ""

    signal panelClicked(string panel, real centerY)
    signal panelHovered(string panel, real centerY, string source)
    signal panelExited(string source)
    signal runCommand(string command)

    function mapCenterY(centerY) {
        return centerOffset + y + centerY;
    }

    width: Theme.buttonSize
    implicitHeight: content.implicitHeight

    Column {
        id: content

        width: parent.width

        PanelRailButton {
            icon: root.updateIcon
            accent: root.updatesStatus && root.updatesStatus.class === "zero" ? Theme.green : root.updatesStatus && root.updatesStatus.class === "error" ? Theme.red : Theme.yellow
            panel: "updates"
            active: root.openPanel === "updates"
            onPanelClicked: (panel, centerY) => root.panelClicked(panel, root.mapCenterY(centerY))
            onPanelHovered: (panel, centerY, source) => root.panelHovered(panel, root.mapCenterY(centerY), source)
            onPanelExited: (source) => root.panelExited(source)
            onRightClicked: root.runCommand("kitty --class update-list --title update-list sh -c '" + root.scriptRoot + "/waybar/update/update-list.sh'")
        }

        PanelRailButton {
            icon: root.bluetoothStatus && root.bluetoothStatus.icon ? root.bluetoothStatus.icon : "󰂯"
            accent: root.bluetoothStatus && root.bluetoothStatus.class === "connected" ? Theme.blue : root.bluetoothStatus && root.bluetoothStatus.class === "disabled" ? Theme.red : Theme.foreground
            panel: "bluetooth"
            active: root.openPanel === "bluetooth"
            onPanelClicked: (panel, centerY) => root.panelClicked(panel, root.mapCenterY(centerY))
            onPanelHovered: (panel, centerY, source) => root.panelHovered(panel, root.mapCenterY(centerY), source)
            onPanelExited: (source) => root.panelExited(source)
            onRightClicked: root.runCommand("blueman-manager")
        }

        PanelRailButton {
            icon: root.audioStatus && root.audioStatus.micIcon ? root.audioStatus.micIcon : "󰍬"
            accent: root.audioStatus && root.audioStatus.micMuted ? Theme.red : Theme.foreground
            panel: "mic"
            active: root.openPanel === "mic"
            onPanelClicked: (panel, centerY) => root.panelClicked(panel, root.mapCenterY(centerY))
            onPanelHovered: (panel, centerY, source) => root.panelHovered(panel, root.mapCenterY(centerY), source)
            onPanelExited: (source) => root.panelExited(source)
            onRightClicked: root.runCommand("pavucontrol -t 4")
        }

        PanelRailButton {
            icon: root.brightnessStatus && root.brightnessStatus.icon ? root.brightnessStatus.icon : "󰃠"
            accent: Theme.yellow
            panel: "brightness"
            active: root.openPanel === "brightness"
            onPanelClicked: (panel, centerY) => root.panelClicked(panel, root.mapCenterY(centerY))
            onPanelHovered: (panel, centerY, source) => root.panelHovered(panel, root.mapCenterY(centerY), source)
            onPanelExited: (source) => root.panelExited(source)
            onRightClicked: root.runCommand(root.scriptRoot + "/waybar/hyprsunset-toggle.sh")
            onWheeled: (delta) => root.runCommand("brightnessctl -d amdgpu_bl1 set " + (delta > 0 ? "+2%" : "2%-"))
        }

        PanelRailButton {
            icon: root.privacyStatus && root.privacyStatus.icon ? root.privacyStatus.icon : "󰍹"
            accent: root.privacyStatus && root.privacyStatus.class === "active" ? Theme.yellow : Theme.foreground
            panel: "privacy"
            active: root.openPanel === "privacy"
            onPanelClicked: (panel, centerY) => root.panelClicked(panel, root.mapCenterY(centerY))
            onPanelHovered: (panel, centerY, source) => root.panelHovered(panel, root.mapCenterY(centerY), source)
            onPanelExited: (source) => root.panelExited(source)
        }
    }
}
