import "."
import QtQuick
import QtQuick.Layouts

Item {
    id: root

    property string openPanel: ""
    property real panelHeight: 0
    property bool batteryExpanded: false
    property var audioStatus
    property var networkStatus
    property var notificationsStatus
    property var fanStatus
    property var gpuStatus
    property var batteryStatus

    signal panelClicked(string panel, real centerY)
    signal panelHovered(string panel, real centerY, string source)
    signal panelExited(string source)
    signal runCommand(string command)
    signal closeDrawers()
    signal toggleBatteryExpanded()
    signal collapseBattery()

    function mapCenterY(centerY) {
        return y + centerY;
    }

    width: Theme.buttonSize
    implicitHeight: content.implicitHeight
    Layout.alignment: Qt.AlignHCenter

    Column {
        id: content

        width: parent.width

        PanelRailButton {
            icon: root.audioStatus && root.audioStatus.icon ? root.audioStatus.icon : "󰕾"
            accent: root.audioStatus && root.audioStatus.muted ? Theme.yellow : Theme.foreground
            panel: "audio"
            active: root.openPanel === "audio"
            onPanelClicked: (panel, centerY) => root.panelClicked(panel, root.mapCenterY(centerY))
            onPanelHovered: (panel, centerY, source) => root.panelHovered(panel, root.mapCenterY(centerY), source)
            onPanelExited: (source) => root.panelExited(source)
            onRightClicked: root.runCommand("pavucontrol -t 3")
        }

        PanelRailButton {
            icon: root.networkStatus && root.networkStatus.icon ? root.networkStatus.icon : "󰤩"
            accent: root.networkStatus && root.networkStatus.class === "wifi" ? Theme.green : root.networkStatus && root.networkStatus.class === "disabled" ? Theme.red : Theme.yellow
            panel: "network"
            active: root.openPanel === "network"
            onPanelClicked: (panel, centerY) => root.panelClicked(panel, root.mapCenterY(centerY))
            onPanelHovered: (panel, centerY, source) => root.panelHovered(panel, root.mapCenterY(centerY), source)
            onPanelExited: (source) => root.panelExited(source)
        }

        PanelRailButton {
            icon: root.notificationsStatus && root.notificationsStatus.icon ? root.notificationsStatus.icon : "󰂜"
            accent: root.notificationsStatus && root.notificationsStatus.dnd ? Theme.yellow : root.notificationsStatus && root.notificationsStatus.count > 0 ? Theme.blue : Theme.foreground
            panel: "notifications"
            active: root.openPanel === "notifications"
            onPanelClicked: {
                root.closeDrawers();
                root.runCommand("swaync-client -op -sw");
            }
            onPanelHovered: (panel, centerY, source) => root.panelHovered(panel, root.mapCenterY(centerY), source)
            onPanelExited: (source) => root.panelExited(source)
            onRightClicked: root.runCommand("swaync-client -d -sw")
        }

        PanelRailButton {
            icon: root.fanStatus && root.fanStatus.class === "Performance" ? "󱑬" : root.fanStatus && root.fanStatus.class === "Quiet" ? "󰠝" : "󱜝"
            accent: root.fanStatus && root.fanStatus.class === "Performance" ? Theme.red : Theme.foreground
            panel: "system"
            source: "fan"
            active: root.openPanel === "system"
            visible: root.fanStatus && root.fanStatus.class !== undefined && root.fanStatus.class !== "Quiet"
            onPanelClicked: (panel, centerY) => root.panelClicked(panel, root.mapCenterY(centerY))
            onPanelHovered: (panel, centerY, source) => root.panelHovered(panel, root.mapCenterY(centerY), source)
            onPanelExited: (source) => root.panelExited(source)
        }

        PanelRailButton {
            icon: root.gpuStatus && root.gpuStatus.alt === "eco" ? "󰌪" : root.gpuStatus && root.gpuStatus.alt === "gaming" ? "󰪫" : root.gpuStatus && root.gpuStatus.alt === "high-refresh" ? "" : "󰢮"
            accent: root.gpuStatus && root.gpuStatus.alt === "eco" ? Theme.green : Theme.yellow
            panel: "system"
            source: "gpu"
            active: root.openPanel === "system"
            visible: root.gpuStatus && root.gpuStatus.alt !== undefined && root.gpuStatus.alt !== "eco"
            onPanelClicked: (panel, centerY) => root.panelClicked(panel, root.mapCenterY(centerY))
            onPanelHovered: (panel, centerY, source) => root.panelHovered(panel, root.mapCenterY(centerY), source)
            onPanelExited: (source) => root.panelExited(source)
        }

        BatteryRailButton {
            status: root.batteryStatus
            popupY: root.panelHeight - 24
            onToggleExpanded: {
                root.closeDrawers();
                root.toggleBatteryExpanded();
            }
            onPanelHovered: (panel, centerY, source) => root.panelHovered(panel, centerY, source)
            onPanelExited: (source) => root.panelExited(source)
            onSystemPanelRequested: (centerY) => root.panelClicked("system", centerY)
        }

        BatteryCapacityTile {
            status: root.batteryStatus
            expanded: root.batteryExpanded
            onCollapse: root.collapseBattery()
        }
    }
}
