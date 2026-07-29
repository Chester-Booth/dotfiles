import "."
import "../services"
import QtQuick
import Quickshell.Services.SystemTray

Item {
    id: root

    required property string itemId
    required property var surfaceController
    required property BarContentController contentController
    required property WorkspaceController workspaceController
    required property NotificationController notificationController
    property bool horizontal: false
    property real panelExtent: 0
    property bool trayOpensForward: false
    readonly property var itemConfig: Theme.barItems.find((item) => {
        return item.id === root.itemId;
    }) || ({
    })
    readonly property string batteryDisplay: itemConfig.display || "toggle"
    readonly property string itemVisibility: itemConfig.visibility || "normal"
    readonly property bool runtimeSuppressed: itemVisibility === "always" ? false : itemId === "touchpad" ? contentController.touchpad.json.enabled !== false : itemId === "fan" ? contentController.systemInfo.json.profile === undefined || contentController.systemInfo.json.profile === "Quiet" : itemId === "gpu" ? contentController.systemInfo.json.gpuMode === undefined || contentController.systemInfo.json.gpuMode === "eco" : false
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
        if (itemId !== "notifications" || horizontal !== surfaceController.horizontalBar || !contentLoader.item)
            return ;

        notificationController.panelY = mappedCentre(contentLoader.item, contentLoader.item.height / 2);
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

        target: root.surfaceController
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
            icon: "󰤆"
            accent: Theme.foreground
            active: root.surfaceController.openPanel === "power"
            onClicked: (centre) => {
                return root.surfaceController.openHoverPanel("power", root.mappedCentre(this, centre));
            }
        }

    }

    Component {
        id: notesComponent

        PanelRailButton {
            icon: "󰺦"
            accent: Theme.foreground
            panel: "todo"
            active: root.surfaceController.openPanel === "todo"
            onPanelClicked: (panel, centre) => {
                return root.surfaceController.openHoverPanel(panel, root.mappedCentre(this, centre));
            }
            onPanelHovered: (panel, centre, source) => {
                return root.surfaceController.hoverButtonEntered(panel, root.mappedCentre(this, centre), source);
            }
            onPanelExited: (source) => {
                return root.surfaceController.hoverButtonExited(source);
            }
            onRightClicked: root.contentController.run(root.contentController.scriptRoot + "/todo/open.sh")
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
                    model: root.workspaceController.items

                    WorkspaceRailButton {
                        item: modelData
                        blinking: (modelData.urgent || root.workspaceController.hasAlert(modelData.id)) && root.workspaceController.blinkOn
                        onActivate: {
                            root.surfaceController.closeBarOverlays();
                            root.workspaceController.focusWorkspace(modelData.id);
                            root.workspaceController.refresh();
                        }
                    }

                }

                SpecialWorkspaceRailButton {
                    workspace: root.workspaceController.special
                    onActivate: {
                        root.surfaceController.closeBarOverlays();
                        root.workspaceController.toggleSpecialWorkspace("magic");
                        root.workspaceController.refresh();
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
                text: root.contentController.railClockText(root.horizontal)
                dateMode: root.contentController.clockDateMode
                onHovered: (centre) => {
                    return root.surfaceController.hoverButtonEntered("calendar", root.mappedCentre(this, centre), "calendar");
                }
                onExited: root.surfaceController.hoverButtonExited("calendar")
                onClicked: root.contentController.clockDateMode = !root.contentController.clockDateMode
            }

            Text {
                id: horizontalClock

                anchors.centerIn: parent
                visible: root.horizontal
                text: String(root.contentController.railClockText(root.horizontal))
                color: root.contentController.clockDateMode ? Theme.foreground : Theme.blue
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
                    root.surfaceController.hoverButtonEntered("calendar", root.horizontal ? point.x : point.y, "calendar");
                }
                onExited: root.surfaceController.hoverButtonExited("calendar")
                onClicked: root.contentController.clockDateMode = !root.contentController.clockDateMode
            }

        }

    }

    Component {
        id: batteryComponent

        Item {
            readonly property bool showIcon: root.batteryDisplay !== "numeric"
            readonly property bool showCapacity: root.batteryDisplay === "numeric" || root.batteryDisplay === "toggle" && root.contentController.batteryExpanded

            implicitWidth: root.horizontal && showIcon && showCapacity ? Theme.buttonSize * 2 : Theme.buttonSize
            implicitHeight: !root.horizontal && showIcon && showCapacity ? Theme.buttonSize * 2 : Theme.buttonSize
            width: implicitWidth
            height: implicitHeight

            BatteryRailButton {
                id: batteryButton

                x: 0
                y: 0
                visible: parent.showIcon
                status: root.contentController.battery.json
                popupY: root.panelExtent - 24
                onToggleExpanded: {
                    if (root.batteryDisplay !== "toggle")
                        return ;

                    const expanded = !root.contentController.batteryExpanded;
                    root.surfaceController.closeBarOverlays();
                    root.contentController.batteryExpanded = expanded;
                }
                onSystemPanelRequested: (centre) => {
                    return root.surfaceController.openHoverPanel("system", root.mappedCentre(this, centre));
                }
                onSystemPanelHovered: (centre) => {
                    return root.surfaceController.hoverButtonEntered("system", root.mappedCentre(this, centre), "battery");
                }
                onSystemPanelExited: root.surfaceController.hoverButtonExited("battery")
            }

            BatteryCapacityTile {
                x: root.horizontal && parent.showIcon ? batteryButton.width : 0
                y: !root.horizontal && parent.showIcon ? batteryButton.height : 0
                status: root.contentController.battery.json
                expanded: parent.showCapacity
                collapsible: root.batteryDisplay === "toggle"
                onCollapse: root.contentController.batteryExpanded = false
                onPanelHovered: (centre) => {
                    return root.surfaceController.hoverButtonEntered("system", root.mappedCentre(this, centre), "battery");
                }
                onPanelExited: root.surfaceController.hoverButtonExited("battery")
            }

        }

    }

    Component {
        id: notificationsComponent

        PanelRailButton {
            icon: root.notificationController.status().icon || "󰂜"
            accent: root.notificationController.dnd ? Theme.yellow : root.notificationController.status().count > 0 ? Theme.blue : Theme.foreground
            panel: "notifications"
            active: root.surfaceController.openPanel === panel
            onPanelClicked: (panel, centre) => {
                root.publishNotificationPosition();
                root.surfaceController.closeBarOverlays();
                root.surfaceController.openHoverPanel(panel, root.mappedCentre(this, centre));
            }
            onPanelHovered: (panel, centre, source) => {
                root.publishNotificationPosition();
                return root.surfaceController.hoverButtonEntered(panel, root.mappedCentre(this, centre), source);
            }
            onPanelExited: (source) => {
                return root.surfaceController.hoverButtonExited(source);
            }
            onRightClicked: root.notificationController.clear()
        }

    }

    Component {
        id: wifiComponent

        PanelRailButton {
            icon: root.contentController.network.json.icon || "󰤩"
            accent: root.contentController.network.json.class === "wifi" ? Theme.green : Theme.yellow
            panel: "network"
            active: root.surfaceController.openPanel === panel
            onPanelClicked: (p, c) => {
                return root.surfaceController.openHoverPanel(p, root.mappedCentre(this, c));
            }
            onPanelHovered: (p, c, s) => {
                return root.surfaceController.hoverButtonEntered(p, root.mappedCentre(this, c), s);
            }
            onPanelExited: (s) => {
                return root.surfaceController.hoverButtonExited(s);
            }
        }

    }

    Component {
        id: soundComponent

        PanelRailButton {
            icon: root.contentController.audio.json.icon || "󰝾"
            accent: root.contentController.audio.json.muted ? Theme.yellow : Theme.foreground
            panel: "audio"
            active: root.surfaceController.openPanel === panel
            onPanelClicked: (p, c) => {
                return root.surfaceController.openHoverPanel(p, root.mappedCentre(this, c));
            }
            onPanelHovered: (p, c, s) => {
                return root.surfaceController.hoverButtonEntered(p, root.mappedCentre(this, c), s);
            }
            onPanelExited: (s) => {
                return root.surfaceController.hoverButtonExited(s);
            }
            onRightClicked: root.contentController.run("pavucontrol -t 3")
        }

    }

    Component {
        id: privacyComponent

        PanelRailButton {
            icon: root.contentController.privacy.json.icon || "󰝹"
            accent: root.contentController.privacy.json.class === "active" ? Theme.yellow : Theme.foreground
            panel: "privacy"
            active: root.surfaceController.openPanel === panel
            onPanelClicked: (p, c) => {
                return root.surfaceController.openHoverPanel(p, root.mappedCentre(this, c));
            }
            onPanelHovered: (p, c, s) => {
                return root.surfaceController.hoverButtonEntered(p, root.mappedCentre(this, c), s);
            }
            onPanelExited: (s) => {
                return root.surfaceController.hoverButtonExited(s);
            }
        }

    }

    Component {
        id: awakeComponent

        PanelRailButton {
            icon: root.contentController.caffeine.json.icon || "󰅶"
            accent: root.contentController.caffeine.json.active ? Theme.yellow : Theme.foreground
            panel: "caffeine"
            active: root.surfaceController.openPanel === panel
            onPanelClicked: (p, c) => {
                return root.surfaceController.openHoverPanel(p, root.mappedCentre(this, c));
            }
            onPanelHovered: (p, c, s) => {
                return root.surfaceController.hoverButtonEntered(p, root.mappedCentre(this, c), s);
            }
            onPanelExited: (s) => {
                return root.surfaceController.hoverButtonExited(s);
            }
            onRightClicked: root.contentController.run(root.contentController.scriptRoot + "/status/caffeine.sh off")
        }

    }

    Component {
        id: displayComponent

        PanelRailButton {
            icon: root.contentController.brightness.json.icon || "󰃠"
            accent: Theme.yellow
            panel: "brightness"
            active: root.surfaceController.openPanel === panel
            onPanelClicked: (p, c) => {
                return root.surfaceController.openHoverPanel(p, root.mappedCentre(this, c));
            }
            onPanelHovered: (p, c, s) => {
                return root.surfaceController.hoverButtonEntered(p, root.mappedCentre(this, c), s);
            }
            onPanelExited: (s) => {
                return root.surfaceController.hoverButtonExited(s);
            }
            onRightClicked: root.contentController.run(root.contentController.scriptRoot + "/display/hyprsunset-toggle.sh")
        }

    }

    Component {
        id: bluetoothComponent

        PanelRailButton {
            icon: root.contentController.bluetooth.json.icon || "󰂯"
            accent: root.contentController.bluetooth.json.class === "connected" ? Theme.blue : Theme.foreground
            panel: "bluetooth"
            active: root.surfaceController.openPanel === panel
            onPanelClicked: (p, c) => {
                return root.surfaceController.openHoverPanel(p, root.mappedCentre(this, c));
            }
            onPanelHovered: (p, c, s) => {
                return root.surfaceController.hoverButtonEntered(p, root.mappedCentre(this, c), s);
            }
            onPanelExited: (s) => {
                return root.surfaceController.hoverButtonExited(s);
            }
            onRightClicked: root.contentController.run("blueman-manager")
        }

    }

    Component {
        id: updatesComponent

        PanelRailButton {
            icon: root.contentController.updateIcon()
            accent: root.contentController.updates.json.class === "zero" ? Theme.green : Theme.yellow
            panel: "updates"
            active: root.surfaceController.openPanel === panel
            onPanelClicked: (p, c) => {
                return root.surfaceController.openHoverPanel(p, root.mappedCentre(this, c));
            }
            onPanelHovered: (p, c, s) => {
                return root.surfaceController.hoverButtonEntered(p, root.mappedCentre(this, c), s);
            }
            onPanelExited: (s) => {
                return root.surfaceController.hoverButtonExited(s);
            }
        }

    }

    Component {
        id: fanComponent

        PanelRailButton {
            icon: root.contentController.systemInfo.json.profile === "Performance" ? "󱑬" : root.contentController.systemInfo.json.profile === "Quiet" ? "󰠝" : "󱜝"
            accent: root.contentController.systemInfo.json.profile === "Performance" ? Theme.red : Theme.foreground
            panel: "system"
            source: "fan"
            active: root.surfaceController.openPanel === panel
            onPanelClicked: (p, c) => {
                return root.surfaceController.openHoverPanel(p, root.mappedCentre(this, c));
            }
            onPanelHovered: (p, c, s) => {
                return root.surfaceController.hoverButtonEntered(p, root.mappedCentre(this, c), s);
            }
            onPanelExited: (s) => {
                return root.surfaceController.hoverButtonExited(s);
            }
        }

    }

    Component {
        id: gpuComponent

        PanelRailButton {
            icon: root.contentController.systemInfo.json.gpuMode === "eco" ? "󰌪" : root.contentController.systemInfo.json.gpuMode === "gaming" ? "󰪫" : root.contentController.systemInfo.json.gpuMode === "high-refresh" ? "" : "󰢮"
            accent: root.contentController.systemInfo.json.gpuMode === "eco" ? Theme.green : Theme.yellow
            panel: "system"
            source: "gpu"
            active: root.surfaceController.openPanel === panel
            onPanelClicked: (p, c) => {
                return root.surfaceController.openHoverPanel(p, root.mappedCentre(this, c));
            }
            onPanelHovered: (p, c, s) => {
                return root.surfaceController.hoverButtonEntered(p, root.mappedCentre(this, c), s);
            }
            onPanelExited: (s) => {
                return root.surfaceController.hoverButtonExited(s);
            }
        }

    }

    Component {
        id: touchpadComponent

        RailButton {
            icon: root.contentController.touchpad.json.icon || "󰟸"
            accent: root.contentController.touchpad.json.enabled === false ? Theme.yellow : Theme.foreground
            onHovered: root.surfaceController.trayEntered()
            onExited: root.surfaceController.trayExited()
            onClicked: {
                root.contentController.run(root.contentController.scriptRoot + "/osd/control.sh touchpad-toggle");
            }
        }

    }

    Component {
        id: trayToggleComponent

        Flow {
            flow: root.horizontal ? Flow.LeftToRight : Flow.TopToBottom
            width: root.horizontal ? implicitWidth : Theme.buttonSize
            height: root.horizontal ? Theme.buttonSize : implicitHeight

            TrayToggleButton {
                horizontal: root.horizontal
                opensForward: root.trayOpensForward
                active: root.surfaceController.trayOpen
                onToggle: root.surfaceController.toggleTray()
                onOpenRequested: {
                    root.surfaceController.openTray();
                    root.surfaceController.trayEntered();
                }
                onExited: root.surfaceController.trayExited()
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
                        root.surfaceController.trayEntered();
                    else
                        root.surfaceController.trayExited();
                }
            }

            Flow {
                anchors.fill: parent
                flow: root.horizontal ? Flow.LeftToRight : Flow.TopToBottom

                Repeater {
                    id: trayRepeater

                    model: SystemTray.items

                    TrayRailItem {
                        item: modelData
                        onHovered: root.surfaceController.trayItemEntered()
                        onOpenMenu: (item, centre) => {
                            return root.surfaceController.openTrayMenu(item, root.mappedCentre(this, centre));
                        }
                    }

                }

            }

        }

    }

}
