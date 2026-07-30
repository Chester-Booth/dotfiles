import "../popouts"
import "../services"
import "../shared"
import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import Quickshell.Wayland

Scope {
    id: root

    property string openPanel: ""
    property real openPanelX: 8
    property real openPanelY: 8
    property string scriptRoot: Quickshell.shellDir + "/scripts"
    property bool barOpen: true
    property bool edgeTriggerHovered: false
    property bool railSurfaceHovered: false
    readonly property var activeToplevelState: Hyprland.activeToplevel ? Hyprland.activeToplevel.lastIpcObject || ({
    }) : ({
    })
    readonly property var activeWaylandToplevel: ToplevelManager.activeToplevel
    readonly property bool fullscreenActive: activeWaylandToplevel ? activeWaylandToplevel.fullscreen : Number(activeToplevelState.fullscreen || 0) > 0
    readonly property bool barPinnedOpen: barOpen && !fullscreenActive
    readonly property bool hoverRevealHeld: !barPinnedOpen && (edgeTriggerHovered || railSurfaceHovered || openPanel.length > 0 || trayOpen || trayMenuOpen || popoutHovered || trayHovered || inputPopupLocked)
    readonly property bool barVisible: barPinnedOpen || hoverRevealHeld
    property real barSlide: barVisible ? 1 : 0
    property bool trayOpen: false
    property string hoveredSource: ""
    property bool popoutHovered: false
    property bool trayHovered: false
    property bool inputPopupLocked: false
    property var trayMenuHandle: null
    property string trayMenuTitle: ""
    property real trayMenuY: 8
    property bool trayMenuOpen: false
    property var activeScreen: Quickshell.screens.length > 0 ? Quickshell.screens[0] : null
    readonly property bool horizontalBar: Theme.barPosition === "top" || Theme.barPosition === "bottom"

    signal osdLevelPreview(string kind, int value, bool muted)

    function enterEdgeTrigger() {
        edgeTriggerRelease.stop();
        edgeTriggerHovered = true;
    }

    function leaveEdgeTrigger() {
        edgeTriggerRelease.restart();
    }

    function syncActiveScreenToFocus() {
        if (!Hyprland.focusedMonitor)
            return ;

        for (let i = 0; i < Quickshell.screens.length; i++) {
            const screen = Quickshell.screens[i];
            if (Hyprland.monitorFor(screen) === Hyprland.focusedMonitor) {
                activeScreen = screen;
                return ;
            }
        }
    }

    function closePanel() {
        openPanel = "";
        hoveredSource = "";
        popoutHovered = false;
        trayHovered = false;
        inputPopupLocked = false;
        hoverCloseDelay.stop();
    }

    function setInputPopupLocked(locked) {
        inputPopupLocked = locked;
        if (locked)
            hoverCloseDelay.stop();
        else if (hoveredSource.length === 0 && !popoutHovered)
            scheduleHoverClose();
    }

    function openHoverPanel(panel, centerY) {
        if (openPanel !== panel)
            inputPopupLocked = false;

        if (horizontalBar)
            openPanelX = centerY === undefined ? 8 : centerY;
        else
            openPanelY = centerY === undefined ? 8 : centerY;
        openPanel = panel;
        hoverCloseDelay.stop();
    }

    function switchSystemPanel(panel) {
        if (["network", "bluetooth", "audio", "brightness"].indexOf(panel) < 0)
            return ;

        if (openPanel !== panel)
            inputPopupLocked = false;

        openPanel = panel;
        hoveredSource = "";
        hoverCloseDelay.stop();
    }

    function hoverButtonEntered(panel, centerY, source) {
        hoveredSource = source === undefined ? panel : source;
        openHoverPanel(panel, centerY);
    }

    function hoverButtonExited(source) {
        if (hoveredSource !== (source === undefined ? "" : source))
            return ;

        hoveredSource = "";
        scheduleHoverClose();
    }

    function scheduleHoverClose() {
        hoverCloseDelay.restart();
    }

    function trayEntered() {
        trayHovered = true;
        hoverCloseDelay.stop();
    }

    function trayItemEntered() {
        openPanel = "";
        hoveredSource = "";
        popoutHovered = false;
        inputPopupLocked = false;
        trayEntered();
    }

    function trayExited() {
        trayHovered = false;
        scheduleHoverClose();
    }

    function popoutEntered() {
        popoutHovered = true;
        hoverCloseDelay.stop();
    }

    function popoutExited() {
        popoutHovered = false;
        scheduleHoverClose();
    }

    function closeTrayMenu() {
        trayMenuOpen = false;
        trayMenuHandle = null;
        trayMenuTitle = "";
    }

    function toggleTray() {
        closePanel();
        closeTrayMenu();
        trayOpen = !trayOpen;
        trayHovered = trayOpen;
    }

    function openTray() {
        if (trayOpen)
            return ;

        closePanel();
        closeTrayMenu();
        trayOpen = true;
    }

    function closeBarOverlays() {
        closePanel();
        closeTrayMenu();
        trayHovered = false;
        trayOpen = false;
    }

    function openTrayMenu(item, centerY) {
        closePanel();
        trayOpen = true;
        trayHovered = true;
        trayMenuHandle = item.menu;
        trayMenuTitle = item.tooltipTitle || item.title || item.id || "Tray";
        trayMenuY = centerY;
        trayMenuOpen = !!(item.hasMenu || item.onlyMenu);
        if (!trayMenuOpen)
            item.activate();

    }

    onBarOpenChanged: {
        if (!barOpen)
            closeBarOverlays();

    }
    onFullscreenActiveChanged: {
        if (fullscreenActive)
            closeBarOverlays();

    }
    Component.onCompleted: {
        Hyprland.refreshToplevels();
        syncActiveScreenToFocus();
    }

    UiState {
        id: uiState
    }

    NotificationController {
        id: barNotificationController

        openPanel: root.openPanel
        openPanelY: root.openPanelY
        dnd: uiState.notificationDnd
        actionRunner: barContentController
        persistentState: uiState
        focusScript: "/home/blox/.config/hypr/scripts/focus-notification-source-workspace.sh"
        onOpenRequested: (centreY) => {
            return root.openHoverPanel("notifications", centreY);
        }
        onCloseRequested: root.closePanel()
    }

    WorkspaceController {
        id: barWorkspaceController

        scriptRoot: root.scriptRoot
        items: barContentController.workspaces.json.main || []
        special: barContentController.workspaces.json.special || ({
        })
        onStatusRefreshRequested: barContentController.workspaces.refresh()
        onPrivacyRefreshRequested: barContentController.privacy.refresh()
        onFocusedMonitorChanged: root.syncActiveScreenToFocus()
    }

    BarContentController {
        id: barContentController

        scriptRoot: root.scriptRoot
        barVisible: root.barVisible
        openPanel: root.openPanel
    }

    IpcHandler {
        function open() : string {
            root.openHoverPanel("power", root.openPanelY);
            return "open";
        }

        function toggle() : string {
            if (root.openPanel === "power") {
                root.closePanel();
                return "closed";
            }
            root.openHoverPanel("power", root.openPanelY);
            return "open";
        }

        function close() : string {
            root.closePanel();
            return "closed";
        }

        target: "power"
    }

    Timer {
        id: hoverCloseDelay

        interval: 180
        repeat: false
        onTriggered: {
            if (root.hoveredSource.length === 0 && !root.popoutHovered && !root.trayHovered && !root.inputPopupLocked) {
                root.closePanel();
                root.closeTrayMenu();
                root.trayOpen = false;
            }
        }
    }

    Timer {
        id: edgeTriggerRelease

        interval: 140
        repeat: false
        onTriggered: root.edgeTriggerHovered = false
    }

    Variants {
        model: Quickshell.screens

        PanelWindow {
            id: panel

            required property var modelData

            function claimScreen() {
                root.activeScreen = modelData;
            }

            screen: modelData
            implicitWidth: root.horizontalBar ? modelData.width : (root.barVisible || root.barSlide > 0.01 ? Theme.railWidth : 1)
            implicitHeight: root.horizontalBar ? (root.barVisible || root.barSlide > 0.01 ? Theme.railWidth : 1) : modelData.height
            exclusiveZone: root.barPinnedOpen ? Math.round(Theme.railWidth * root.barSlide) : 0
            focusable: false
            visible: true
            color: "transparent"
            WlrLayershell.layer: WlrLayer.Overlay
            WlrLayershell.namespace: "blox-bar"

            anchors {
                left: Theme.barPosition === "left"
                right: Theme.barPosition === "right"
                top: Theme.barPosition === "top" || !root.horizontalBar
                bottom: Theme.barPosition === "bottom" || !root.horizontalBar
            }

            MouseArea {
                readonly property int triggerLength: Math.ceil((root.horizontalBar ? parent.width : parent.height) / 5)

                z: -1
                x: root.horizontalBar ? parent.width - width : Theme.barPosition === "right" ? parent.width - width : 0
                y: root.horizontalBar ? Theme.barPosition === "bottom" ? parent.height - height : 0 : parent.height - height
                width: root.horizontalBar ? triggerLength : 1
                height: root.horizontalBar ? 1 : triggerLength
                acceptedButtons: Qt.NoButton
                hoverEnabled: true
                onEntered: {
                    panel.claimScreen();
                    root.enterEdgeTrigger();
                }
                onExited: root.leaveEdgeTrigger()
            }

            Rectangle {
                x: Theme.barPosition === "left" ? Math.round(-Theme.railWidth * (1 - root.barSlide)) : Theme.barPosition === "right" ? Math.round(Theme.railWidth * (1 - root.barSlide)) : 0
                y: Theme.barPosition === "top" ? Math.round(-Theme.railWidth * (1 - root.barSlide)) : Theme.barPosition === "bottom" ? Math.round(Theme.railWidth * (1 - root.barSlide)) : 0
                width: root.horizontalBar ? parent.width : Theme.railWidth
                height: root.horizontalBar ? Theme.railWidth : parent.height
                color: Theme.background

                HoverHandler {
                    onHoveredChanged: {
                        if (hovered)
                            panel.claimScreen();

                        root.railSurfaceHovered = hovered;
                    }
                }

                MouseArea {
                    anchors.fill: parent
                    onClicked: root.closeBarOverlays()
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
                        visible: !root.horizontalBar
                        anchors.top: parent.top
                        anchors.horizontalCenter: parent.horizontalCenter
                        regionItems: Theme.barStartItems
                        surfaceController: root
                        contentController: barContentController
                        workspaceController: barWorkspaceController
                        notificationController: barNotificationController
                        trayHost: configuredRail
                        horizontal: false
                        panelExtent: panel.height
                        region: "start"
                    }

                    BarRegion {
                        visible: !root.horizontalBar
                        anchors.centerIn: parent
                        regionItems: Theme.barCentreItems
                        surfaceController: root
                        contentController: barContentController
                        workspaceController: barWorkspaceController
                        notificationController: barNotificationController
                        trayHost: configuredRail
                        horizontal: false
                        panelExtent: panel.height
                        region: "centre"
                    }

                    BarRegion {
                        visible: !root.horizontalBar
                        anchors.bottom: parent.bottom
                        anchors.horizontalCenter: parent.horizontalCenter
                        regionItems: Theme.barEndItems
                        surfaceController: root
                        contentController: barContentController
                        workspaceController: barWorkspaceController
                        notificationController: barNotificationController
                        trayHost: configuredRail
                        horizontal: false
                        panelExtent: panel.height
                        region: "end"
                    }

                    BarRegion {
                        visible: root.horizontalBar
                        anchors.left: parent.left
                        anchors.verticalCenter: parent.verticalCenter
                        regionItems: Theme.barStartItems
                        surfaceController: root
                        contentController: barContentController
                        workspaceController: barWorkspaceController
                        notificationController: barNotificationController
                        trayHost: configuredRail
                        horizontal: true
                        panelExtent: panel.height
                        region: "start"
                    }

                    BarRegion {
                        visible: root.horizontalBar
                        anchors.centerIn: parent
                        regionItems: Theme.barCentreItems
                        surfaceController: root
                        contentController: barContentController
                        workspaceController: barWorkspaceController
                        notificationController: barNotificationController
                        trayHost: configuredRail
                        horizontal: true
                        panelExtent: panel.height
                        region: "centre"
                    }

                    BarRegion {
                        visible: root.horizontalBar
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        regionItems: Theme.barEndItems
                        surfaceController: root
                        contentController: barContentController
                        workspaceController: barWorkspaceController
                        notificationController: barNotificationController
                        trayHost: configuredRail
                        horizontal: true
                        panelExtent: panel.height
                        region: "end"
                    }

                    Column {
                        visible: !root.horizontalBar && root.trayOpen && configuredRail.verticalTrayToggleItem
                        z: 100
                        x: configuredRail.verticalTrayPoint.x
                        y: configuredRail.verticalTrayToggleItem && configuredRail.verticalTrayToggleItem.trayOpensForward ? configuredRail.verticalTrayPoint.y + configuredRail.verticalTrayToggleItem.height + spacing : configuredRail.verticalTrayPoint.y - height - spacing
                        spacing: 2

                        Repeater {
                            model: Theme.barHiddenItems.filter((item) => {
                                return item.id !== "tray";
                            })

                            BarItemDelegate {
                                required property var modelData

                                itemId: modelData.id
                                surfaceController: root
                                contentController: barContentController
                                workspaceController: barWorkspaceController
                                notificationController: barNotificationController
                                horizontal: false
                                panelExtent: panel.height
                            }

                        }

                    }

                    Row {
                        visible: root.horizontalBar && root.trayOpen && configuredRail.horizontalTrayToggleItem
                        z: 100
                        x: configuredRail.horizontalTrayToggleItem && configuredRail.horizontalTrayToggleItem.trayOpensForward ? configuredRail.horizontalTrayPoint.x + configuredRail.horizontalTrayToggleItem.width + spacing : configuredRail.horizontalTrayPoint.x - width - spacing
                        y: configuredRail.horizontalTrayPoint.y
                        spacing: 2

                        Repeater {
                            model: Theme.barHiddenItems.filter((item) => {
                                return item.id !== "tray";
                            })

                            BarItemDelegate {
                                required property var modelData

                                itemId: modelData.id
                                surfaceController: root
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
                open: root.activeScreen === modelData && root.openPanel === "power"
                updateSummary: barContentController.content.updateSummary()
                onAction: (kind) => {
                    return barContentController.run(barContentController.content.powerCommand(kind));
                }
                onClose: root.closePanel()
            }

            BarPopouts {
                panelWindow: panel
                active: root.activeScreen === modelData
                surfaceController: root
                contentController: barContentController
                notificationController: barNotificationController
                persistentState: uiState
            }

            BarNotificationToastSurface {
                targetScreen: modelData
                surfaceActive: root.activeScreen === modelData
                notificationController: barNotificationController
            }

        }

    }

    Behavior on barSlide {
        NumberAnimation {
            duration: 180
            easing.type: Easing.OutCubic
        }

    }

}
