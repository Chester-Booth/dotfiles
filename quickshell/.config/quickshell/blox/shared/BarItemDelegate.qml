import "."
import QtQuick
import Quickshell.Services.SystemTray

Item {
    id: root

    required property string itemId
    required property var controller
    property bool horizontal: false
    property real panelExtent: 0
    property bool trayOpensForward: false
    readonly property var itemConfig: Theme.barItems.find((item) => {
        return item.id === root.itemId;
    }) || ({
    })
    readonly property string batteryDisplay: itemConfig.display || "toggle"
    readonly property string itemVisibility: itemConfig.visibility || "normal"
    readonly property bool runtimeSuppressed: itemVisibility === "always" ? false : itemId === "touchpad" ? controller.touchpad.json.enabled !== false : itemId === "fan" ? controller.systemInfo.json.profile === undefined || controller.systemInfo.json.profile === "Quiet" : itemId === "gpu" ? controller.systemInfo.json.gpuMode === undefined || controller.systemInfo.json.gpuMode === "eco" : false
    readonly property bool contentVisible: contentLoader.item !== null && !runtimeSuppressed

    function mappedCentre(item, centre) {
        // mapToItem(root) only includes this delegate's local offset. Once an
        // item is moved between the start, centre and end layouts that misses
        // the layout ancestors, so the popout remains near its old region.
        // A null target maps into the panel window's scene coordinates, which
        // are exactly the coordinates expected by PopupWindow.anchor.rect.
        const point = item.mapToItem(null, item.width / 2, centre);
        return root.horizontal ? point.x : point.y;
    }

    function publishNotificationPosition() {
        if (itemId !== "notifications" || horizontal !== controller.horizontalBar || !contentLoader.item)
            return ;

        controller.notificationPanelY = mappedCentre(contentLoader.item, contentLoader.item.height / 2);
    }

    onXChanged: publishNotificationPosition()
    onYChanged: publishNotificationPosition()
    onWidthChanged: publishNotificationPosition()
    onHeightChanged: publishNotificationPosition()
    onHorizontalChanged: publishNotificationPosition()
    Component.onCompleted: publishNotificationPosition()
    // Keep the cross-axis extent stable. Content such as the expandable battery
    // percentage must only grow along the bar, otherwise a click recentres the
    // whole vertical section and makes neighbouring icons jump sideways.
    visible: contentVisible
    implicitWidth: !contentVisible ? 0 : root.horizontal && contentLoader.item ? Math.max(Theme.buttonSize, contentLoader.item.implicitWidth || contentLoader.item.width) : Theme.buttonSize
    implicitHeight: !contentVisible ? 0 : !root.horizontal && contentLoader.item ? Math.max(Theme.buttonSize, contentLoader.item.implicitHeight || contentLoader.item.height) : Theme.buttonSize
    width: implicitWidth
    height: implicitHeight

    Connections {
        function onHorizontalBarChanged() {
            root.publishNotificationPosition();
        }

        target: root.controller
    }

    Loader {
        id: contentLoader

        anchors.centerIn: parent
        onLoaded: root.publishNotificationPosition()
        sourceComponent: {
            const components = {
                "power": powerComponent,
                "notes": notesComponent,
                "workspaces": workspacesComponent,
                "clock": clockComponent,
                "battery": batteryComponent,
                "notifications": notificationsComponent,
                "wifi": wifiComponent,
                "sound": soundComponent,
                "privacy": privacyComponent,
                "awake": awakeComponent,
                "display": displayComponent,
                "bt": bluetoothComponent,
                "updates": updatesComponent,
                "fan": fanComponent,
                "gpu": gpuComponent,
                "touchpad": touchpadComponent,
                "tray": trayToggleComponent,
                "application-tray": applicationTrayComponent
            };
            return components[root.itemId] || null;
        }
    }

    Component {
        id: powerComponent

        RailButton {
            icon: "⏻"
            accent: Theme.foreground
            active: root.controller.openPanel === "power"
            onClicked: (centre) => {
                return root.controller.togglePanel("power", root.mappedCentre(this, centre));
            }
        }

    }

    Component {
        id: notesComponent

        PanelRailButton {
            icon: "󰺦"
            accent: Theme.foreground
            panel: "todo"
            active: root.controller.openPanel === "todo"
            onPanelClicked: (panel, centre) => {
                return root.controller.togglePanel(panel, root.mappedCentre(this, centre));
            }
            onPanelHovered: (panel, centre, source) => {
                return root.controller.hoverButtonEntered(panel, root.mappedCentre(this, centre), source);
            }
            onPanelExited: (source) => {
                return root.controller.hoverButtonExited(source);
            }
            onRightClicked: root.controller.run(root.controller.scriptRoot + "/todo/open.sh")
        }

    }

    Component {
        id: workspacesComponent

        Item {
            implicitWidth: workspaceFlow.implicitWidth
            implicitHeight: workspaceFlow.implicitHeight

            Flow {
                id: workspaceFlow

                flow: root.horizontal ? Flow.TopToBottom : Flow.LeftToRight
                width: root.horizontal ? implicitWidth : Theme.buttonSize
                height: root.horizontal ? Theme.buttonSize : implicitHeight

                Repeater {
                    model: root.controller.workspaceItems()

                    WorkspaceRailButton {
                        item: modelData
                        blinking: (modelData.urgent || root.controller.workspaceAlert(modelData.id)) && root.controller.blinkOn
                        onActivate: {
                            root.controller.closeDrawers();
                            root.controller.focusWorkspace(modelData.id);
                            root.controller.workspaces.refresh();
                        }
                    }

                }

                SpecialWorkspaceRailButton {
                    workspace: root.controller.workspaces.json.special
                    onActivate: {
                        root.controller.closeDrawers();
                        root.controller.toggleSpecialWorkspace("magic");
                        root.controller.workspaces.refresh();
                    }
                }

            }

        }

    }

    Component {
        id: clockComponent

        Item {
            implicitWidth: root.horizontal ? Math.ceil(horizontalClock.implicitWidth) + 16 : verticalClock.implicitWidth
            implicitHeight: root.horizontal ? Theme.buttonSize : verticalClock.implicitHeight

            RailClock {
                id: verticalClock

                visible: !root.horizontal
                text: root.controller.railClockText(root.horizontal)
                dateMode: root.controller.clockDateMode
                onHovered: (centre) => {
                    return root.controller.hoverButtonEntered("calendar", root.mappedCentre(this, centre), "calendar");
                }
                onExited: root.controller.hoverButtonExited("calendar")
                onClicked: root.controller.clockDateMode = !root.controller.clockDateMode
            }

            Text {
                id: horizontalClock

                anchors.centerIn: parent
                visible: root.horizontal
                text: String(root.controller.railClockText(root.horizontal))
                color: root.controller.clockDateMode ? Theme.foreground : Theme.blue
                font.family: Theme.fontFamily
                font.pixelSize: 14
                horizontalAlignment: Text.AlignHCenter
                verticalAlignment: Text.AlignVCenter
            }

            MouseArea {
                anchors.fill: parent
                visible: root.horizontal
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onEntered: {
                    const point = mapToItem(null, width / 2, height / 2);
                    root.controller.hoverButtonEntered("calendar", root.horizontal ? point.x : point.y, "calendar");
                }
                onExited: root.controller.hoverButtonExited("calendar")
                onClicked: root.controller.clockDateMode = !root.controller.clockDateMode
            }

        }

    }

    Component {
        id: batteryComponent

        Item {
            readonly property bool showIcon: root.batteryDisplay !== "numeric"
            readonly property bool showCapacity: root.batteryDisplay === "numeric" || root.batteryDisplay === "toggle" && root.controller.batteryExpanded

            implicitWidth: root.horizontal && showIcon && showCapacity ? Theme.buttonSize * 2 : Theme.buttonSize
            implicitHeight: !root.horizontal && showIcon && showCapacity ? Theme.buttonSize * 2 : Theme.buttonSize
            width: implicitWidth
            height: implicitHeight

            BatteryRailButton {
                id: batteryButton

                x: 0
                y: 0
                visible: parent.showIcon
                status: root.controller.battery.json
                popupY: root.panelExtent - 24
                onToggleExpanded: {
                    if (root.batteryDisplay !== "toggle")
                        return ;

                    const expanded = !root.controller.batteryExpanded;
                    root.controller.closeDrawers();
                    root.controller.batteryExpanded = expanded;
                }
                onSystemPanelRequested: (centre) => {
                    return root.controller.togglePanel("system", root.mappedCentre(this, centre));
                }
                onSystemPanelHovered: (centre) => {
                    return root.controller.hoverButtonEntered("system", root.mappedCentre(this, centre), "battery");
                }
                onSystemPanelExited: root.controller.hoverButtonExited("battery")
            }

            BatteryCapacityTile {
                x: root.horizontal && parent.showIcon ? batteryButton.width : 0
                y: !root.horizontal && parent.showIcon ? batteryButton.height : 0
                status: root.controller.battery.json
                expanded: parent.showCapacity
                collapsible: root.batteryDisplay === "toggle"
                onCollapse: root.controller.batteryExpanded = false
            }

        }

    }

    Component {
        id: notificationsComponent

        PanelRailButton {
            icon: root.controller.notificationStatus().icon || "󰂜"
            accent: root.controller.notificationDnd ? Theme.yellow : root.controller.notificationStatus().count > 0 ? Theme.blue : Theme.foreground
            panel: "notifications"
            active: root.controller.openPanel === panel
            onPanelClicked: (panel, centre) => {
                root.publishNotificationPosition();
                root.controller.closeDrawers();
                root.controller.togglePanel(panel, root.mappedCentre(this, centre));
            }
            onPanelHovered: (panel, centre, source) => {
                root.publishNotificationPosition();
                return root.controller.hoverButtonEntered(panel, root.mappedCentre(this, centre), source);
            }
            onPanelExited: (source) => {
                return root.controller.hoverButtonExited(source);
            }
            onRightClicked: root.controller.clearNotifications()
        }

    }

    Component {
        id: wifiComponent

        PanelRailButton {
            icon: root.controller.network.json.icon || "󰤩"
            accent: root.controller.network.json.class === "wifi" ? Theme.green : Theme.yellow
            panel: "network"
            active: root.controller.openPanel === panel
            onPanelClicked: (p, c) => {
                return root.controller.togglePanel(p, root.mappedCentre(this, c));
            }
            onPanelHovered: (p, c, s) => {
                return root.controller.hoverButtonEntered(p, root.mappedCentre(this, c), s);
            }
            onPanelExited: (s) => {
                return root.controller.hoverButtonExited(s);
            }
        }

    }

    Component {
        id: soundComponent

        PanelRailButton {
            icon: root.controller.audio.json.icon || "󰝾"
            accent: root.controller.audio.json.muted ? Theme.yellow : Theme.foreground
            panel: "audio"
            active: root.controller.openPanel === panel
            onPanelClicked: (p, c) => {
                return root.controller.togglePanel(p, root.mappedCentre(this, c));
            }
            onPanelHovered: (p, c, s) => {
                return root.controller.hoverButtonEntered(p, root.mappedCentre(this, c), s);
            }
            onPanelExited: (s) => {
                return root.controller.hoverButtonExited(s);
            }
            onRightClicked: root.controller.run("pavucontrol -t 3")
        }

    }

    Component {
        id: privacyComponent

        PanelRailButton {
            icon: root.controller.privacy.json.icon || "󰝹"
            accent: root.controller.privacy.json.class === "active" ? Theme.yellow : Theme.foreground
            panel: "privacy"
            active: root.controller.openPanel === panel
            onPanelClicked: (p, c) => {
                return root.controller.togglePanel(p, root.mappedCentre(this, c));
            }
            onPanelHovered: (p, c, s) => {
                return root.controller.hoverButtonEntered(p, root.mappedCentre(this, c), s);
            }
            onPanelExited: (s) => {
                return root.controller.hoverButtonExited(s);
            }
        }

    }

    Component {
        id: awakeComponent

        PanelRailButton {
            icon: root.controller.caffeine.json.icon || "󰅶"
            accent: root.controller.caffeine.json.active ? Theme.yellow : Theme.foreground
            panel: "caffeine"
            active: root.controller.openPanel === panel
            onPanelClicked: (p, c) => {
                return root.controller.togglePanel(p, root.mappedCentre(this, c));
            }
            onPanelHovered: (p, c, s) => {
                return root.controller.hoverButtonEntered(p, root.mappedCentre(this, c), s);
            }
            onPanelExited: (s) => {
                return root.controller.hoverButtonExited(s);
            }
            onRightClicked: root.controller.run(root.controller.scriptRoot + "/status/caffeine.sh off")
        }

    }

    Component {
        id: displayComponent

        PanelRailButton {
            icon: root.controller.brightness.json.icon || "󰃠"
            accent: Theme.yellow
            panel: "brightness"
            active: root.controller.openPanel === panel
            onPanelClicked: (p, c) => {
                return root.controller.togglePanel(p, root.mappedCentre(this, c));
            }
            onPanelHovered: (p, c, s) => {
                return root.controller.hoverButtonEntered(p, root.mappedCentre(this, c), s);
            }
            onPanelExited: (s) => {
                return root.controller.hoverButtonExited(s);
            }
            onRightClicked: root.controller.run(root.controller.scriptRoot + "/display/hyprsunset-toggle.sh")
        }

    }

    Component {
        id: bluetoothComponent

        PanelRailButton {
            icon: root.controller.bluetooth.json.icon || "󰂯"
            accent: root.controller.bluetooth.json.class === "connected" ? Theme.blue : Theme.foreground
            panel: "bluetooth"
            active: root.controller.openPanel === panel
            onPanelClicked: (p, c) => {
                return root.controller.togglePanel(p, root.mappedCentre(this, c));
            }
            onPanelHovered: (p, c, s) => {
                return root.controller.hoverButtonEntered(p, root.mappedCentre(this, c), s);
            }
            onPanelExited: (s) => {
                return root.controller.hoverButtonExited(s);
            }
            onRightClicked: root.controller.run("blueman-manager")
        }

    }

    Component {
        id: updatesComponent

        PanelRailButton {
            icon: root.controller.updateIcon()
            accent: root.controller.updates.json.class === "zero" ? Theme.green : Theme.yellow
            panel: "updates"
            active: root.controller.openPanel === panel
            onPanelClicked: (p, c) => {
                return root.controller.togglePanel(p, root.mappedCentre(this, c));
            }
            onPanelHovered: (p, c, s) => {
                return root.controller.hoverButtonEntered(p, root.mappedCentre(this, c), s);
            }
            onPanelExited: (s) => {
                return root.controller.hoverButtonExited(s);
            }
        }

    }

    Component {
        id: fanComponent

        PanelRailButton {
            icon: root.controller.systemInfo.json.profile === "Performance" ? "󱑬" : root.controller.systemInfo.json.profile === "Quiet" ? "󰠝" : "󱜝"
            accent: root.controller.systemInfo.json.profile === "Performance" ? Theme.red : Theme.foreground
            panel: "system"
            source: "fan"
            active: root.controller.openPanel === panel
            onPanelClicked: (p, c) => {
                return root.controller.togglePanel(p, root.mappedCentre(this, c));
            }
            onPanelHovered: (p, c, s) => {
                return root.controller.hoverButtonEntered(p, root.mappedCentre(this, c), s);
            }
            onPanelExited: (s) => {
                return root.controller.hoverButtonExited(s);
            }
        }

    }

    Component {
        id: gpuComponent

        PanelRailButton {
            icon: root.controller.systemInfo.json.gpuMode === "eco" ? "󰌪" : root.controller.systemInfo.json.gpuMode === "gaming" ? "󰪫" : root.controller.systemInfo.json.gpuMode === "high-refresh" ? "" : "󰢮"
            accent: root.controller.systemInfo.json.gpuMode === "eco" ? Theme.green : Theme.yellow
            panel: "system"
            source: "gpu"
            active: root.controller.openPanel === panel
            onPanelClicked: (p, c) => {
                return root.controller.togglePanel(p, root.mappedCentre(this, c));
            }
            onPanelHovered: (p, c, s) => {
                return root.controller.hoverButtonEntered(p, root.mappedCentre(this, c), s);
            }
            onPanelExited: (s) => {
                return root.controller.hoverButtonExited(s);
            }
        }

    }

    Component {
        id: touchpadComponent

        RailButton {
            icon: root.controller.touchpad.json.icon || "󰟸"
            accent: root.controller.touchpad.json.enabled === false ? Theme.yellow : Theme.foreground
            onHovered: root.controller.extrasEntered()
            onExited: root.controller.extrasExited()
            onClicked: {
                root.controller.run(root.controller.scriptRoot + "/osd/control.sh touchpad-toggle");
                touchpadRefresh.restart();
            }

            Timer {
                id: touchpadRefresh

                interval: 300
                repeat: false
                onTriggered: root.controller.touchpad.refresh()
            }

        }

    }

    Component {
        id: trayToggleComponent

        Flow {
            flow: root.horizontal ? Flow.LeftToRight : Flow.TopToBottom
            width: root.horizontal ? implicitWidth : Theme.buttonSize
            height: root.horizontal ? Theme.buttonSize : implicitHeight

            ExtrasToggleButton {
                horizontal: root.horizontal
                opensForward: root.trayOpensForward
                active: root.controller.extrasOpen
                onToggle: root.controller.toggleExtras()
                onOpenRequested: {
                    root.controller.openExtras();
                    root.controller.extrasEntered();
                }
                onExited: root.controller.extrasExited()
            }

        }

    }

    Component {
        id: applicationTrayComponent

        Item {
            readonly property int trayCount: trayRepeater.count

            implicitWidth: root.horizontal ? trayCount * Theme.buttonSize : Theme.buttonSize
            implicitHeight: root.horizontal ? Theme.buttonSize : trayCount * Theme.buttonSize
            width: implicitWidth
            height: implicitHeight

            HoverHandler {
                onHoveredChanged: {
                    if (hovered)
                        root.controller.extrasEntered();
                    else
                        root.controller.extrasExited();
                }
            }

            Flow {
                id: trayFlow

                anchors.fill: parent
                flow: root.horizontal ? Flow.LeftToRight : Flow.TopToBottom

                Repeater {
                    id: trayRepeater

                    model: SystemTray.items

                    TrayRailItem {
                        item: modelData
                        onHovered: root.controller.trayItemEntered()
                        onOpenMenu: (item, centre) => {
                            return root.controller.openTrayMenu(item, root.mappedCentre(this, centre));
                        }
                    }

                }

            }

        }

    }

}
