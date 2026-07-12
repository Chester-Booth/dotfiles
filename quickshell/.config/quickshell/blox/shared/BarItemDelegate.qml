import "."
import QtQuick
import Quickshell.Services.SystemTray

Item {
    id: root

    required property string itemId
    required property var controller
    property bool horizontal: false
    property real panelExtent: 0

    function mappedCentre(item, centre) {
        // mapToItem(root) only includes this delegate's local offset. Once an
        // item is moved between the start, centre and end layouts that misses
        // the layout ancestors, so the popout remains near its old region.
        // A null target maps into the panel window's scene coordinates, which
        // are exactly the coordinates expected by PopupWindow.anchor.rect.
        const point = item.mapToItem(null, item.width / 2, centre);
        return root.horizontal ? point.x : point.y;
    }

    // Keep the cross-axis extent stable. Content such as the expandable battery
    // percentage must only grow along the bar, otherwise a click recentres the
    // whole vertical section and makes neighbouring icons jump sideways.
    implicitWidth: root.horizontal && contentLoader.item ? Math.max(Theme.buttonSize, contentLoader.item.implicitWidth || contentLoader.item.width) : Theme.buttonSize
    implicitHeight: !root.horizontal && contentLoader.item ? Math.max(Theme.buttonSize, contentLoader.item.implicitHeight || contentLoader.item.height) : Theme.buttonSize
    width: implicitWidth
    height: implicitHeight

    Loader {
        id: contentLoader

        anchors.centerIn: parent
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
            implicitWidth: root.horizontal ? 62 : verticalClock.implicitWidth
            implicitHeight: root.horizontal ? Theme.buttonSize : verticalClock.implicitHeight

            RailClock {
                id: verticalClock

                visible: !root.horizontal
                text: root.controller.railClockText()
                dateMode: root.controller.clockDateMode
                onHovered: (centre) => {
                    return root.controller.hoverButtonEntered("calendar", root.mappedCentre(this, centre), "calendar");
                }
                onExited: root.controller.hoverButtonExited("calendar")
                onClicked: root.controller.clockDateMode = !root.controller.clockDateMode
            }

            Text {
                anchors.fill: parent
                visible: root.horizontal
                text: String(root.controller.railClockText()).replace(/\n/g, ":")
                color: root.controller.clockDateMode ? Theme.foreground : Theme.blue
                font.family: Theme.fontFamily
                font.pixelSize: 14
                horizontalAlignment: Text.AlignHCenter
                verticalAlignment: Text.AlignVCenter

                MouseArea {
                    anchors.fill: parent
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

    }

    Component {
        id: batteryComponent

        Item {
            implicitWidth: root.horizontal && root.controller.batteryExpanded ? Theme.buttonSize * 2 : Theme.buttonSize
            implicitHeight: !root.horizontal && root.controller.batteryExpanded ? Theme.buttonSize * 2 : Theme.buttonSize
            width: implicitWidth
            height: implicitHeight

            BatteryRailButton {
                id: batteryButton

                x: 0
                y: 0
                status: root.controller.battery.json
                popupY: root.panelExtent - 24
                onToggleExpanded: {
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
                x: root.horizontal ? batteryButton.width : 0
                y: root.horizontal ? 0 : batteryButton.height
                status: root.controller.battery.json
                expanded: root.controller.batteryExpanded
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
                root.controller.closeDrawers();
                root.controller.togglePanel(panel, root.mappedCentre(this, centre));
            }
            onPanelHovered: (panel, centre, source) => {
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
            icon: root.controller.network.json.icon || "󰔩"
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
            icon: Lucide.icon("fan")
            iconFontFamily: Lucide.family
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
            icon: Lucide.icon("gpu")
            iconFontFamily: Lucide.family
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
        id: trayToggleComponent

        Flow {
            flow: root.horizontal ? Flow.LeftToRight : Flow.TopToBottom
            width: root.horizontal ? implicitWidth : Theme.buttonSize
            height: root.horizontal ? Theme.buttonSize : implicitHeight
            Component.onCompleted: root.controller.trayToggleItem = root
            Component.onDestruction: {
                if (root.controller.trayToggleItem === root)
                    root.controller.trayToggleItem = null;

            }

            ExtrasToggleButton {
                horizontal: root.horizontal
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
            implicitWidth: trayFlow.implicitWidth
            implicitHeight: trayFlow.implicitHeight

            Flow {
                id: trayFlow

                flow: root.horizontal ? Flow.TopToBottom : Flow.LeftToRight
                width: root.horizontal ? implicitWidth : Theme.buttonSize
                height: root.horizontal ? Theme.buttonSize : implicitHeight

                Repeater {
                    model: SystemTray.items

                    TrayRailItem {
                        item: modelData
                        onHovered: root.controller.trayItemEntered()
                        onExited: root.controller.extrasExited()
                        onOpenMenu: (item, centre) => {
                            return root.controller.openTrayMenu(item, root.mappedCentre(this, centre));
                        }
                    }

                }

            }

        }

    }

}
