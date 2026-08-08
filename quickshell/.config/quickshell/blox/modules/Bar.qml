import "../popouts"
import "../services"
import "../shared"
import QtQuick
import Quickshell
import Quickshell.Wayland

Scope {
    id: root

    property bool barOpen: true
    readonly property alias controller: barSurfaceController

    BarSurfaceController {
        id: barSurfaceController

        barOpen: root.barOpen
    }

    UiState {
        id: uiState
    }

    NotificationController {
        id: barNotificationController

        openPanel: barSurfaceController.openPanel
        openPanelY: barSurfaceController.openPanelY
        dnd: uiState.notificationDnd
        actionRunner: barContentController
        persistentState: uiState
        focusScript: "/home/blox/.config/hypr/scripts/focus-notification-source-workspace.sh"
        onOpenRequested: (centreY) => {
            return barSurfaceController.openHoverPanel("notifications", centreY);
        }
        onCloseRequested: barSurfaceController.closePanel()
    }

    WorkspaceController {
        id: barWorkspaceController

        scriptRoot: barSurfaceController.scriptRoot
        items: barContentController.workspaces.json.main || []
        special: barContentController.workspaces.json.special || ({
        })
        onStatusRefreshRequested: barContentController.workspaces.refresh()
        onPrivacyRefreshRequested: barContentController.privacy.refresh()
        onFocusedMonitorChanged: barSurfaceController.syncActiveScreenToFocus()
    }

    BarContentController {
        id: barContentController

        scriptRoot: barSurfaceController.scriptRoot
        barVisible: barSurfaceController.barVisible
        openPanel: barSurfaceController.openPanel
    }

    Variants {
        model: Quickshell.screens

        PanelWindow {
            id: panel

            required property var modelData

            function claimScreen() {
                barSurfaceController.activeScreen = modelData;
            }

            screen: modelData
            implicitWidth: barSurfaceController.horizontalBar ? modelData.width : (barSurfaceController.barVisible || barSurfaceController.barSlide > 0.01 ? Theme.railWidth : 1)
            implicitHeight: barSurfaceController.horizontalBar ? (barSurfaceController.barVisible || barSurfaceController.barSlide > 0.01 ? Theme.railWidth : 1) : modelData.height
            exclusiveZone: barSurfaceController.barPinnedOpen ? Math.round(Theme.railWidth * barSurfaceController.barSlide) : 0
            focusable: false
            visible: true
            color: "transparent"
            WlrLayershell.layer: WlrLayer.Overlay
            WlrLayershell.namespace: "blox-bar"

            anchors {
                left: Theme.barPosition === "left"
                right: Theme.barPosition === "right"
                top: Theme.barPosition === "top" || !barSurfaceController.horizontalBar
                bottom: Theme.barPosition === "bottom" || !barSurfaceController.horizontalBar
            }

            MouseArea {
                readonly property int triggerLength: Math.ceil((barSurfaceController.horizontalBar ? parent.width : parent.height) / 5)

                z: -1
                x: barSurfaceController.horizontalBar ? parent.width - width : Theme.barPosition === "right" ? parent.width - width : 0
                y: barSurfaceController.horizontalBar ? Theme.barPosition === "bottom" ? parent.height - height : 0 : parent.height - height
                width: barSurfaceController.horizontalBar ? triggerLength : 1
                height: barSurfaceController.horizontalBar ? 1 : triggerLength
                acceptedButtons: Qt.NoButton
                hoverEnabled: true
                onEntered: {
                    panel.claimScreen();
                    barSurfaceController.enterEdgeTrigger();
                }
                onExited: barSurfaceController.leaveEdgeTrigger()
            }

            Rectangle {
                x: Theme.barPosition === "left" ? Math.round(-Theme.railWidth * (1 - barSurfaceController.barSlide)) : Theme.barPosition === "right" ? Math.round(Theme.railWidth * (1 - barSurfaceController.barSlide)) : 0
                y: Theme.barPosition === "top" ? Math.round(-Theme.railWidth * (1 - barSurfaceController.barSlide)) : Theme.barPosition === "bottom" ? Math.round(Theme.railWidth * (1 - barSurfaceController.barSlide)) : 0
                width: barSurfaceController.horizontalBar ? parent.width : Theme.railWidth
                height: barSurfaceController.horizontalBar ? Theme.railWidth : parent.height
                color: Theme.background

                HoverHandler {
                    onHoveredChanged: {
                        if (hovered)
                            panel.claimScreen();

                        barSurfaceController.railSurfaceHovered = hovered;
                    }
                }

                MouseArea {
                    anchors.fill: parent
                    onClicked: barSurfaceController.closeBarOverlays()
                }

                Item {
                    id: configuredRail

                    property var verticalTrayToggleItem: null
                    property var horizontalTrayToggleItem: null
                    readonly property point verticalTrayPoint: mappedTrayPoint(verticalTrayToggleItem)
                    readonly property point horizontalTrayPoint: mappedTrayPoint(horizontalTrayToggleItem)

                    function mappedTrayPoint(item) {
                        if (!item)
                            return Qt.point(0, 0);

                        // mapToItem() does not create bindings to ancestor
                        // geometry. Read the full chain so region resizing and
                        // preview rotation both recalculate the drawer point.
                        let geometryDependency = width + height;
                        let ancestor = item;
                        while (ancestor && ancestor !== configuredRail) {
                            geometryDependency += ancestor.x + ancestor.y + ancestor.width + ancestor.height;
                            ancestor = ancestor.parent;
                        }
                        const point = item.mapToItem(configuredRail, 0, 0);
                        return Qt.point(point.x + geometryDependency * 0, point.y);
                    }

                    function registerTrayToggle(item, horizontal) {
                        if (item.itemId !== "tray")
                            return ;

                        if (horizontal)
                            horizontalTrayToggleItem = item;
                        else
                            verticalTrayToggleItem = item;
                    }

                    function unregisterTrayToggle(item, horizontal) {
                        if (horizontal && horizontalTrayToggleItem === item)
                            horizontalTrayToggleItem = null;
                        else if (!horizontal && verticalTrayToggleItem === item)
                            verticalTrayToggleItem = null;
                    }

                    anchors.fill: parent
                    anchors.margins: 4

                    BarRegion {
                        visible: !barSurfaceController.horizontalBar
                        anchors.top: parent.top
                        anchors.horizontalCenter: parent.horizontalCenter
                        regionItems: Theme.barStartItems
                        surfaceController: barSurfaceController
                        contentController: barContentController
                        workspaceController: barWorkspaceController
                        notificationController: barNotificationController
                        trayHost: configuredRail
                        horizontal: false
                        panelExtent: panel.height
                        region: "start"
                    }

                    BarRegion {
                        visible: !barSurfaceController.horizontalBar
                        anchors.centerIn: parent
                        regionItems: Theme.barCentreItems
                        surfaceController: barSurfaceController
                        contentController: barContentController
                        workspaceController: barWorkspaceController
                        notificationController: barNotificationController
                        trayHost: configuredRail
                        horizontal: false
                        panelExtent: panel.height
                        region: "centre"
                    }

                    BarRegion {
                        visible: !barSurfaceController.horizontalBar
                        anchors.bottom: parent.bottom
                        anchors.horizontalCenter: parent.horizontalCenter
                        regionItems: Theme.barEndItems
                        surfaceController: barSurfaceController
                        contentController: barContentController
                        workspaceController: barWorkspaceController
                        notificationController: barNotificationController
                        trayHost: configuredRail
                        horizontal: false
                        panelExtent: panel.height
                        region: "end"
                    }

                    BarRegion {
                        visible: barSurfaceController.horizontalBar
                        anchors.left: parent.left
                        anchors.verticalCenter: parent.verticalCenter
                        regionItems: Theme.barStartItems
                        surfaceController: barSurfaceController
                        contentController: barContentController
                        workspaceController: barWorkspaceController
                        notificationController: barNotificationController
                        trayHost: configuredRail
                        horizontal: true
                        panelExtent: panel.height
                        region: "start"
                    }

                    BarRegion {
                        visible: barSurfaceController.horizontalBar
                        anchors.centerIn: parent
                        regionItems: Theme.barCentreItems
                        surfaceController: barSurfaceController
                        contentController: barContentController
                        workspaceController: barWorkspaceController
                        notificationController: barNotificationController
                        trayHost: configuredRail
                        horizontal: true
                        panelExtent: panel.height
                        region: "centre"
                    }

                    BarRegion {
                        visible: barSurfaceController.horizontalBar
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        regionItems: Theme.barEndItems
                        surfaceController: barSurfaceController
                        contentController: barContentController
                        workspaceController: barWorkspaceController
                        notificationController: barNotificationController
                        trayHost: configuredRail
                        horizontal: true
                        panelExtent: panel.height
                        region: "end"
                    }

                    Column {
                        visible: !barSurfaceController.horizontalBar && barSurfaceController.trayOpen && configuredRail.verticalTrayToggleItem
                        z: 100
                        x: configuredRail.verticalTrayPoint.x
                        y: configuredRail.verticalTrayToggleItem && configuredRail.verticalTrayToggleItem.trayOpensForward ? configuredRail.verticalTrayPoint.y + configuredRail.verticalTrayToggleItem.height + spacing : configuredRail.verticalTrayPoint.y - height - spacing
                        spacing: 2

                        HoverHandler {
                            margin: configuredRail.anchors.margins
                            onHoveredChanged: hovered ? barSurfaceController.trayBoundsEntered() : barSurfaceController.trayBoundsExited()
                        }

                        Repeater {
                            model: Theme.barHiddenItems.filter((item) => {
                                return item.id !== "tray";
                            })

                            BarItemDelegate {
                                required property var modelData

                                itemId: modelData.id
                                surfaceController: barSurfaceController
                                contentController: barContentController
                                workspaceController: barWorkspaceController
                                notificationController: barNotificationController
                                horizontal: false
                                panelExtent: panel.height
                            }

                        }

                    }

                    Row {
                        visible: barSurfaceController.horizontalBar && barSurfaceController.trayOpen && configuredRail.horizontalTrayToggleItem
                        z: 100
                        x: configuredRail.horizontalTrayToggleItem && configuredRail.horizontalTrayToggleItem.trayOpensForward ? configuredRail.horizontalTrayPoint.x + configuredRail.horizontalTrayToggleItem.width + spacing : configuredRail.horizontalTrayPoint.x - width - spacing
                        y: configuredRail.horizontalTrayPoint.y
                        spacing: 2

                        HoverHandler {
                            margin: configuredRail.anchors.margins
                            onHoveredChanged: hovered ? barSurfaceController.trayBoundsEntered() : barSurfaceController.trayBoundsExited()
                        }

                        Repeater {
                            model: Theme.barHiddenItems.filter((item) => {
                                return item.id !== "tray";
                            })

                            BarItemDelegate {
                                required property var modelData

                                itemId: modelData.id
                                surfaceController: barSurfaceController
                                contentController: barContentController
                                workspaceController: barWorkspaceController
                                notificationController: barNotificationController
                                horizontal: true
                                panelExtent: panel.height
                            }

                        }

                    }

                }

            }

            PowerOverlayWindow {
                targetScreen: modelData
                open: barSurfaceController.activeScreen === modelData && barSurfaceController.openPanel === "power"
                updateSummary: barContentController.content.updateSummary()
                onAction: (kind) => {
                    return barContentController.run(barContentController.content.powerCommand(kind));
                }
                onClose: barSurfaceController.closePanel()
            }

            BarPopouts {
                panelWindow: panel
                active: barSurfaceController.activeScreen === modelData
                surfaceController: barSurfaceController
                contentController: barContentController
                notificationController: barNotificationController
                persistentState: uiState
            }

            BarNotificationToastSurface {
                targetScreen: modelData
                surfaceActive: barSurfaceController.activeScreen === modelData
                notificationController: barNotificationController
            }

        }

    }

}
