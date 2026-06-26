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
    property var touchpadStatus
    property var fanStatus
    property var gpuStatus
    property var batteryStatus

    signal panelClicked(string panel, real centerY)
    signal panelHovered(string panel, real centerY, string source)
    signal panelExited(string source)
    signal notificationsPositionChanged(real centerY)
    signal runCommand(string command)
    signal clearNotifications()
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
            accent: root.audioStatus && root.audioStatus.muted ? Theme.yellow : root.audioStatus && root.audioStatus.volume > 100 ? Theme.red : Theme.foreground
            panel: "audio"
            active: root.openPanel === "audio"
            onPanelClicked: (panel, centerY) => {
                return root.panelClicked(panel, root.mapCenterY(centerY));
            }
            onPanelHovered: (panel, centerY, source) => {
                return root.panelHovered(panel, root.mapCenterY(centerY), source);
            }
            onPanelExited: (source) => {
                return root.panelExited(source);
            }
            onRightClicked: root.runCommand("pavucontrol -t 3")
        }

        PanelRailButton {
            icon: root.networkStatus && root.networkStatus.icon ? root.networkStatus.icon : "󰤩"
            accent: root.networkStatus && root.networkStatus.class === "wifi" ? Theme.green : root.networkStatus && root.networkStatus.class === "disabled" ? Theme.red : Theme.yellow
            panel: "network"
            active: root.openPanel === "network"
            onPanelClicked: (panel, centerY) => {
                return root.panelClicked(panel, root.mapCenterY(centerY));
            }
            onPanelHovered: (panel, centerY, source) => {
                return root.panelHovered(panel, root.mapCenterY(centerY), source);
            }
            onPanelExited: (source) => {
                return root.panelExited(source);
            }
        }

        PanelRailButton {
            id: notificationButton

            icon: root.notificationsStatus && root.notificationsStatus.icon ? root.notificationsStatus.icon : "󰂜"
            accent: root.notificationsStatus && root.notificationsStatus.dnd ? Theme.yellow : root.notificationsStatus && root.notificationsStatus.count > 0 ? Theme.blue : Theme.foreground
            panel: "notifications"
            active: root.openPanel === "notifications"
            Component.onCompleted: Qt.callLater(function() {
                root.notificationsPositionChanged(root.mapCenterY(notificationButton.y + notificationButton.height / 2));
            })
            onYChanged: root.notificationsPositionChanged(root.mapCenterY(notificationButton.y + notificationButton.height / 2))
            onPanelClicked: (panel, centerY) => {
                root.closeDrawers();
                return root.panelClicked(panel, root.mapCenterY(centerY));
            }
            onPanelHovered: (panel, centerY, source) => {
                return root.panelHovered(panel, root.mapCenterY(centerY), source);
            }
            onPanelExited: (source) => {
                return root.panelExited(source);
            }
            onRightClicked: root.clearNotifications()
        }

        RailButton {
            icon: root.touchpadStatus && root.touchpadStatus.icon ? root.touchpadStatus.icon : "󰤳"
            accent: Theme.red
            visible: root.touchpadStatus && root.touchpadStatus.enabled === false
            onClicked: root.runCommand("~/.config/quickshell/blox/scripts/osd/control.sh touchpad-toggle")
            onHovered: (centerY) => {
                return root.panelHovered("touchpad", root.mapCenterY(centerY), "touchpad");
            }
            onExited: root.panelExited("touchpad")
        }

        PanelRailButton {
            icon: root.fanStatus && root.fanStatus.class === "Performance" ? "󱑬" : root.fanStatus && root.fanStatus.class === "Quiet" ? "󰠝" : "󱜝"
            accent: root.fanStatus && root.fanStatus.class === "Performance" ? Theme.red : Theme.foreground
            panel: "system"
            source: "fan"
            active: root.openPanel === "system"
            visible: root.fanStatus && root.fanStatus.class !== undefined && root.fanStatus.class !== "Quiet"
            onPanelClicked: (panel, centerY) => {
                return root.panelClicked(panel, root.mapCenterY(centerY));
            }
            onPanelHovered: (panel, centerY, source) => {
                return root.panelHovered(panel, root.mapCenterY(centerY), source);
            }
            onPanelExited: (source) => {
                return root.panelExited(source);
            }
        }

        PanelRailButton {
            icon: root.gpuStatus && root.gpuStatus.alt === "eco" ? "󰌪" : root.gpuStatus && root.gpuStatus.alt === "gaming" ? "󰪫" : root.gpuStatus && root.gpuStatus.alt === "high-refresh" ? "" : "󰢮"
            accent: root.gpuStatus && root.gpuStatus.alt === "eco" ? Theme.green : Theme.yellow
            panel: "system"
            source: "gpu"
            active: root.openPanel === "system"
            visible: root.gpuStatus && root.gpuStatus.alt !== undefined && root.gpuStatus.alt !== "eco"
            onPanelClicked: (panel, centerY) => {
                return root.panelClicked(panel, root.mapCenterY(centerY));
            }
            onPanelHovered: (panel, centerY, source) => {
                return root.panelHovered(panel, root.mapCenterY(centerY), source);
            }
            onPanelExited: (source) => {
                return root.panelExited(source);
            }
        }

        BatteryRailButton {
            status: root.batteryStatus
            popupY: root.panelHeight - 24
            onToggleExpanded: {
                root.closeDrawers();
                root.toggleBatteryExpanded();
            }
            onSystemPanelRequested: (centerY) => {
                return root.panelClicked("system", centerY);
            }
            onSystemPanelHovered: (centerY) => {
                return root.panelHovered("system", root.mapCenterY(centerY), "battery");
            }
            onSystemPanelExited: root.panelExited("battery")
        }

        BatteryCapacityTile {
            status: root.batteryStatus
            expanded: root.batteryExpanded
            onCollapse: root.collapseBattery()
        }

    }

}
