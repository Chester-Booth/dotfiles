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

    signal osdLevelPreview(string kind, int value, bool muted)

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
    property bool batteryExpanded: false
    property bool clockDateMode: false
    property string hoveredSource: ""
    property bool popoutHovered: false
    property bool trayHovered: false
    property bool inputPopupLocked: false
    property alias blinkOn: workspaceController.blinkOn
    property string selectedCalendarDate: ""
    property var trayMenuHandle: null
    property string trayMenuTitle: ""
    property real trayMenuY: 8
    property bool trayMenuOpen: false
    property alias notificationDnd: uiState.notificationDnd
    property real notificationPanelY: 0
    property var activeScreen: Quickshell.screens.length > 0 ? Quickshell.screens[0] : null
    property alias workspaces: barStatus.workspaces
    property alias systemInfo: barStatus.system
    property alias updates: barStatus.updates
    property alias battery: barStatus.battery
    property alias audio: barStatus.audio
    property alias brightness: barStatus.brightness
    property alias network: barStatus.network
    property alias bluetooth: barStatus.bluetooth
    property alias touchpad: barStatus.touchpad
    property alias privacy: barStatus.privacy
    property alias caffeine: barStatus.caffeine
    readonly property bool horizontalBar: Theme.barPosition === "top" || Theme.barPosition === "bottom"

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

    function diagLog(event, detail) {
        console.log("[blox.bar] " + new Date().toISOString() + " " + event + " " + (detail || ""));
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

    function notificationStatus() {
        return notifications.status();
    }

    function clearNotifications() {
        notifications.clear();
    }

    function activateNotification(notification) {
        if (!notification)
            return ;

        const actions = notification.actions || [];
        for (let i = 0; i < actions.length; i++) {
            if (actions[i].identifier === "default") {
                actions[i].invoke();
                return ;
            }
        }

        focusNotificationSource(notification);
    }

    function focusNotificationSource(notification) {
        if (!notification)
            return ;

        diagLog("notifications.activate", "app=" + (notification.appName || "") + " desktop=" + (notification.desktopEntry || "") + " summary=" + (notification.summary || ""));
        runArgs(["env", "BLOX_NOTIFICATION_APP_NAME=" + (notification.appName || ""), "BLOX_NOTIFICATION_DESKTOP_ENTRY=" + (notification.desktopEntry || ""), "BLOX_NOTIFICATION_SUMMARY=" + (notification.summary || ""), "/home/blox/.config/hypr/scripts/focus-notification-source-workspace.sh"]);
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

    function setPerformancePolling(visible) {
        barStatus.performanceVisible = visible;
    }

    function workspaceAlert(id) {
        return workspaceController.hasAlert(id);
    }

    function focusWorkspace(id) {
        workspaceController.focusWorkspace(id);
    }

    function toggleSpecialWorkspace(name) {
        workspaceController.toggleSpecialWorkspace(name);
    }

    function run(command) {
        barActions.run(command);
    }

    function runArgs(args) {
        barActions.runArgs(args);
    }

    function runPerformance(command) {
        barActions.runPerformance(command);
    }

    function currentIsoDate() {
        return Qt.formatDate(clock.date, "yyyy-MM-dd");
    }

    function resetCalendarMonth() {
        selectedCalendarDate = currentIsoDate();
        barStatus.calendar.refresh();
    }

    function workspaceItems() {
        return workspaces.json.main || [];
    }

    function updateIcon() {
        return content.updateIcon();
    }

    function railClockText(horizontal) {
        return content.railClockText(horizontal);
    }

    function statusError(panel) {
        const pollers = {
            "audio": audio,
            "network": network,
            "bluetooth": bluetooth,
            "brightness": brightness,
            "privacy": privacy,
            "caffeine": caffeine,
            "updates": updates,
            "todo": barStatus.todo,
            "system": systemInfo
        };
        const poller = pollers[panel];
        return poller && !poller.ok ? poller.lastError : "";
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
        diagLog("component.completed", "bar loaded");
        Hyprland.refreshToplevels();
        syncActiveScreenToFocus();
    }

    Connections {
        function onNotificationPositionPreviewRequested() {
            root.diagLog("notification.preview", Theme.notificationPosition);
            Quickshell.execDetached(["notify-send", "--app-name", "Theme picker", "--expire-time", "2500", "Notification position", "Previewing " + Theme.notificationPosition]);
        }

        target: Theme
    }

    UiState {
        id: uiState
    }

    NotificationController {
        id: notifications

        openPanel: root.openPanel
        openPanelY: root.openPanelY
        panelY: root.notificationPanelY
        dnd: root.notificationDnd
        onOpenRequested: (centreY) => {
            return root.openHoverPanel("notifications", centreY);
        }
        onCloseRequested: root.closePanel()
        onDndToggleRequested: root.notificationDnd = !root.notificationDnd
    }

    WorkspaceController {
        id: workspaceController

        scriptRoot: root.scriptRoot
        items: root.workspaceItems()
        onStatusRefreshRequested: workspaces.refresh()
        onPrivacyRefreshRequested: privacy.refresh()
        onFocusedMonitorChanged: root.syncActiveScreenToFocus()
    }

    BarStatus {
        id: barStatus

        scriptRoot: root.scriptRoot
        barVisible: root.barVisible
        openPanel: root.openPanel
        selectedCalendarDate: root.selectedCalendarDate
        todayIso: root.currentIsoDate()
    }

    BarActions {
        id: barActions

        scriptRoot: root.scriptRoot
        onControlRefreshRequested: barStatus.refreshControl()
        onPerformanceRefreshRequested: barStatus.refreshPerformance()
        onTodoRefreshRequested: todoRefreshDelay.restart()
        onCalendarRefreshRequested: barStatus.calendar.refresh()
    }

    BarContent {
        id: content

        openPanel: root.openPanel
        scriptRoot: root.scriptRoot
        now: clock.date
        clockDateMode: root.clockDateMode
        updates: root.updates.json
        updatesLastUpdatedMs: root.updates.lastUpdatedMs
        bluetooth: root.bluetooth.json
        audio: root.audio.json
        brightness: root.brightness.json
        network: root.network.json
        privacy: root.privacy.json
        caffeine: root.caffeine.json
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
        id: todoRefreshDelay

        interval: 120
        repeat: false
        onTriggered: barStatus.todo.refresh()
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
                z: -1
                readonly property int triggerLength: Math.ceil((root.horizontalBar ? parent.width : parent.height) / 5)

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
                        controller: root
                        trayHost: configuredRail
                        horizontal: false
                        panelExtent: panel.height
                        region: "start"
                    }

                    BarRegion {
                        visible: !root.horizontalBar
                        anchors.centerIn: parent
                        regionItems: Theme.barCentreItems
                        controller: root
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
                        controller: root
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
                        controller: root
                        trayHost: configuredRail
                        horizontal: true
                        panelExtent: panel.height
                        region: "start"
                    }

                    BarRegion {
                        visible: root.horizontalBar
                        anchors.centerIn: parent
                        regionItems: Theme.barCentreItems
                        controller: root
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
                        controller: root
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
                                controller: root
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
                                controller: root
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
                updateSummary: content.updateSummary()
                onAction: (kind) => {
                    return root.run(content.powerCommand(kind));
                }
                onClose: root.closePanel()
            }

            BarPopouts {
                panelWindow: panel
                screenWidth: panel.screen ? panel.screen.width : 0
                screenHeight: panel.screen ? panel.screen.height : 0
                openPanel: root.activeScreen === modelData ? root.openPanel : ""
                openPanelX: root.openPanelX
                openPanelY: root.openPanelY
                trayMenuY: root.trayMenuY
                trayMenuOpen: root.activeScreen === modelData && root.trayMenuOpen
                trayMenuHandle: root.trayMenuHandle
                trayMenuTitle: root.trayMenuTitle
                todoStatus: barStatus.todo.json
                notesSaveRevision: barActions.notesSaveRevision
                notesSaveBusy: barActions.notesSaveBusy
                notesSaveError: barActions.notesSaveError
                notesStatusError: root.statusError("todo")
                generatedRefreshBusy: barActions.generatedRefreshBusy
                generatedRefreshError: barActions.generatedRefreshError
                calendarAddRevision: barActions.calendarAddRevision
                calendarAddBusy: barActions.calendarAddBusy
                calendarAddError: barActions.calendarAddError
                batteryStatus: battery.json
                clockDate: clock.date
                selectedCalendarDate: root.selectedCalendarDate
                calendarStatus: barStatus.calendar.json || ({
                })
                systemStatus: systemInfo.json || ({
                })
                performanceActionBusy: barActions.performanceBusy
                performanceActionError: barActions.performanceError
                performanceStatusError: root.statusError("system")
                scriptRoot: root.scriptRoot
                systemTitle: content.systemPanelTitle()
                systemBody: content.systemPanelBody()
                systemStatusError: root.statusError(root.openPanel)
                systemActions: content.systemPanelActions()
                audioVolume: audio.json.volume || 0
                audioIcon: audio.json.icon || "󰕾"
                audioMuted: !!audio.json.muted
                micMuted: !!audio.json.micMuted
                networkEnabled: network.json.class !== "disabled"
                bluetoothEnabled: bluetooth.json.class !== "disabled"
                wifiIcon: network.json.icon || "󰤩"
                wifiText: network.json.ssid || network.json.class || "Wi-Fi"
                bluetoothIcon: bluetooth.json.icon || "󰂯"
                brightnessIcon: brightness.json.icon || "󰃠"
                brightnessPercent: brightness.json.percent || 0
                blueLightMode: brightness.json.blueLightMode || "auto"
                blueLightActive: !!brightness.json.blueLightActive
                basicTitle: content.panelTitle()
                basicSubtitle: content.panelSubtitle()
                basicBody: content.panelBody()
                basicStatusError: root.statusError(root.openPanel)
                basicActions: content.panelActions()
                basicCurrentId: root.openPanel === "caffeine" ? (caffeine.json.mode || "off") : ""
                basicHeaderActionIcon: content.panelHeaderActionIcon()
                basicHeaderActionCommand: content.panelHeaderActionCommand()
                basicHeaderStatus: content.panelHeaderStatus()
                notificationsModel: notifications.items || []
                notificationDnd: root.notificationDnd
                activeMprisPlayer: uiState.activeMprisPlayer
                onHoverEntered: root.popoutEntered()
                onHoverExited: root.popoutExited()
                onInputLockChanged: (locked) => {
                    return root.setInputPopupLocked(locked);
                }
                onClosePanel: root.closePanel()
                onCloseTrayMenu: root.closeTrayMenu()
                onToggleNotificationDnd: {
                    root.notificationDnd = !root.notificationDnd;
                    if (root.notificationDnd)
                        notifications.toasts = [];

                }
                onActivateNotification: (notification) => {
                    return root.activateNotification(notification);
                }
                onSelectMprisPlayer: (playerName) => {
                    uiState.activeMprisPlayer = playerName;
                }
                onPreviousTodo: {
                    root.run(root.scriptRoot + "/todo/cycle.sh -1");
                    todoRefreshDelay.restart();
                }
                onNextTodo: {
                    root.run(root.scriptRoot + "/todo/cycle.sh 1");
                    todoRefreshDelay.restart();
                }
                onRefreshTodo: {
                    barActions.refreshGeneratedNotes();
                }
                onSaveTodo: (file, body) => {
                    barActions.saveNotes(file, body);
                }
                onResetCalendarMonth: root.resetCalendarMonth()
                onSelectCalendarDate: (day) => {
                    root.selectedCalendarDate = day;
                    barStatus.calendar.refresh();
                }
                onAddCalendarEvent: (day, title) => {
                    barActions.addCalendarEvent(day, title);
                }
                onOpenCalendarEvent: {
                    const date = root.selectedCalendarDate ? new Date(root.selectedCalendarDate + "T00:00:00") : clock.date;
                    root.run("xdg-open 'https://calendar.google.com/calendar/u/0/r/week/" + date.getFullYear() + "/" + (date.getMonth() + 1) + "/" + date.getDate() + "'");
                }
                onPerformanceAction: (command) => {
                    root.runPerformance(command);
                }
                onPerformanceVisibleChanged: (visible) => {
                    return root.setPerformancePolling(visible);
                }
                onSystemAction: (command, keepOpen) => {
                    root.run(command);
                    audio.refresh();
                    brightness.refresh();
                    bluetooth.refresh();
                    network.refresh();
                    if (!keepOpen)
                        root.closePanel();

                }
                onSystemLevelPreview: (kind, value, muted) => {
                    return root.osdLevelPreview(kind, value, muted);
                }
                onSelectSystemPanel: (panel) => {
                    return root.switchSystemPanel(panel);
                }
                onBasicAction: (command, keepOpen) => {
                    if (command === "__refresh_updates") {
                        updates.refresh();
                        return ;
                    }
                    if (command === "__clear_notifications") {
                        root.clearNotifications();
                        if (!keepOpen)
                            root.closePanel();

                        return ;
                    }
                    root.run(command);
                    if (!keepOpen)
                        root.closePanel();

                }
            }

            PanelWindow {
                id: notificationToastWindow

                readonly property bool onLeft: Theme.notificationPosition === "top-left" || Theme.notificationPosition === "bottom-left"
                readonly property bool onRight: Theme.notificationPosition === "top-right" || Theme.notificationPosition === "bottom-right"
                readonly property bool onTop: Theme.notificationPosition.indexOf("top") >= 0
                readonly property bool onBottom: Theme.notificationPosition.indexOf("bottom") >= 0

                screen: modelData
                implicitWidth: modelData ? modelData.width : 1
                implicitHeight: modelData ? modelData.height : 1
                exclusiveZone: 0
                focusable: false
                visible: root.activeScreen === modelData && notifications.toastsEnabled && notifications.toasts.length > 0 && !root.notificationDnd
                color: "transparent"
                WlrLayershell.layer: WlrLayer.Overlay
                WlrLayershell.namespace: "blox-notifications"

                anchors {
                    left: true
                    right: true
                    top: onTop
                    bottom: onBottom
                }

                NotificationToastStack {
                    id: notificationToasts

                    // Numeric placement clears cleanly when a live preview moves
                    // between opposite edges. Conditional anchors can retain both
                    // sides for a frame and stretch the stack to the old edge.
                    x: notificationToastWindow.onLeft ? 12 + Theme.notificationOffsetX : notificationToastWindow.onRight ? parent.width - width - 12 + Theme.notificationOffsetX : Math.round((parent.width - width) / 2 + Theme.notificationOffsetX)
                    y: notificationToastWindow.onTop ? 12 + Theme.notificationOffsetY : parent.height - height - 12 + Theme.notificationOffsetY
                    position: Theme.notificationPosition
                    visible: notifications.toastsEnabled && notifications.toasts.length > 0 && !root.notificationDnd
                    toasts: notifications.toasts
                    onDismiss: (notification, closeNotification) => {
                        notifications.removeToast(notification);
                        if (notification && closeNotification)
                            notification.dismiss();

                    }
                    onActivate: (notification) => {
                        return root.activateNotification(notification);
                    }
                }

                // The full-output surface gives every notification position the same
                // coordinate space. Only the visible cards accept pointer input.
                mask: Region {
                    // Bind window-local geometry explicitly so the input region is
                    // rebuilt when the hidden toast window appears and the stack's
                    // implicit height changes.
                    x: notificationToasts.x
                    y: notificationToasts.y
                    width: notificationToasts.width
                    height: notificationToasts.height
                }

            }

        }

    }

    SystemClock {
        id: clock

        precision: SystemClock.Seconds
    }

    Behavior on barSlide {
        NumberAnimation {
            duration: 180
            easing.type: Easing.OutCubic
        }

    }

}
