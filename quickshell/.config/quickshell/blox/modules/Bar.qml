import "../popouts"
import "../services"
import "../shared"
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import Quickshell.Services.SystemTray

Scope {
    id: root

    property string openPanel: ""
    property real openPanelY: 8
    property string scriptRoot: Quickshell.shellDir + "/scripts"
    property bool barOpen: true
    property bool edgeTriggerHovered: false
    property bool railSurfaceHovered: false
    readonly property bool hoverRevealHeld: !barOpen && (edgeTriggerHovered || railSurfaceHovered || openPanel.length > 0 || extrasOpen || trayMenuOpen || popoutHovered || extrasHovered || inputPopupLocked)
    readonly property bool barVisible: barOpen || hoverRevealHeld
    property real barSlide: barVisible ? 1 : 0
    property bool extrasOpen: false
    property bool batteryExpanded: false
    property bool clockDateMode: false
    property bool railHovered: false
    property string hoveredSource: ""
    property bool popoutHovered: false
    property bool extrasHovered: false
    property bool inputPopupLocked: false
    property alias blinkOn: workspaceController.blinkOn
    property string selectedCalendarDate: ""
    property alias calendarAddRevision: barActions.calendarAddRevision
    property alias calendarAddBusy: barActions.calendarAddBusy
    property alias calendarAddError: barActions.calendarAddError
    property alias notesSaveRevision: barActions.notesSaveRevision
    property alias notesSaveBusy: barActions.notesSaveBusy
    property alias notesSaveError: barActions.notesSaveError
    property alias generatedRefreshBusy: barActions.generatedRefreshBusy
    property alias generatedRefreshError: barActions.generatedRefreshError
    property var trayMenuHandle: null
    property string trayMenuTitle: ""
    property real trayMenuY: 8
    property bool trayMenuOpen: false
    property alias notificationItems: notifications.items
    property alias toastItems: notifications.toasts
    property alias notificationToastsEnabled: notifications.toastsEnabled
    property alias notificationDnd: uiState.notificationDnd
    property alias activeMprisPlayer: uiState.activeMprisPlayer
    property real notificationPanelY: 0
    property var activeScreen: Quickshell.screens.length > 0 ? Quickshell.screens[0] : null
    property alias performanceActionBusy: barActions.performanceBusy
    property alias performanceActionError: barActions.performanceError
    property alias workspaces: barStatus.workspaces
    property alias systemInfo: barStatus.system
    property alias todo: barStatus.todo
    property alias calendarEvents: barStatus.calendar
    property alias updates: barStatus.updates
    property alias battery: barStatus.battery
    property alias audio: barStatus.audio
    property alias brightness: barStatus.brightness
    property alias network: barStatus.network
    property alias bluetooth: barStatus.bluetooth
    property alias touchpad: barStatus.touchpad
    property alias privacy: barStatus.privacy
    property alias caffeine: barStatus.caffeine

    function togglePanel(panel, centerY) {
        openHoverPanel(panel, centerY);
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
        railHovered = false;
        hoveredSource = "";
        popoutHovered = false;
        extrasHovered = false;
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
        railHovered = false;
        hoverCloseDelay.stop();
    }

    function hoverButtonEntered(panel, centerY, source) {
        hoveredSource = source === undefined ? panel : source;
        railHovered = true;
        openHoverPanel(panel, centerY);
    }

    function hoverButtonExited(source) {
        if (hoveredSource !== (source === undefined ? "" : source))
            return ;

        hoveredSource = "";
        railHovered = false;
        scheduleHoverClose();
    }

    function scheduleHoverClose() {
        hoverCloseDelay.restart();
    }

    function extrasEntered() {
        extrasHovered = true;
        hoverCloseDelay.stop();
    }

    function trayItemEntered() {
        openPanel = "";
        railHovered = false;
        hoveredSource = "";
        popoutHovered = false;
        inputPopupLocked = false;
        extrasEntered();
    }

    function extrasExited() {
        extrasHovered = false;
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

    function focusNotificationSource(notification) {
        if (!notification)
            return ;

        diagLog("notifications.activate", "app=" + (notification.appName || "") + " desktop=" + (notification.desktopEntry || "") + " summary=" + (notification.summary || ""));
        runArgs(["env", "BLOX_NOTIFICATION_APP_NAME=" + (notification.appName || ""), "BLOX_NOTIFICATION_DESKTOP_ENTRY=" + (notification.desktopEntry || ""), "BLOX_NOTIFICATION_SUMMARY=" + (notification.summary || ""), "/home/blox/.config/hypr/scripts/focus-notification-source-workspace.sh"]);
    }

    function toggleExtras() {
        closePanel();
        closeTrayMenu();
        extrasOpen = !extrasOpen;
        extrasHovered = extrasOpen;
    }

    function openExtras() {
        if (extrasOpen)
            return ;

        closePanel();
        closeTrayMenu();
        extrasOpen = true;
    }

    function closeDrawers() {
        closePanel();
        closeTrayMenu();
        extrasHovered = false;
        extrasOpen = false;
    }

    function openTrayMenu(item, centerY) {
        closePanel();
        extrasOpen = true;
        extrasHovered = true;
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

    function powerCommand(kind) {
        return content.powerCommand(kind);
    }

    function updateSummary() {
        return content.updateSummary();
    }

    function currentIsoDate() {
        return Qt.formatDate(clock.date, "yyyy-MM-dd");
    }

    function resetCalendarMonth() {
        selectedCalendarDate = currentIsoDate();
        calendarEvents.refresh();
    }

    function systemPanelTitle() {
        return content.systemPanelTitle();
    }

    function systemPanelBody() {
        return content.systemPanelBody();
    }

    function systemPanelActions() {
        return content.systemPanelActions();
    }

    function workspaceItems() {
        return workspaces.json.main || [];
    }

    function updateIcon() {
        return content.updateIcon();
    }

    function railClockText() {
        return content.railClockText();
    }

    function panelTitle() {
        return content.panelTitle();
    }

    function panelSubtitle() {
        return content.panelSubtitle();
    }

    function panelHeaderActionIcon() {
        return content.panelHeaderActionIcon();
    }

    function panelHeaderActionCommand() {
        return content.panelHeaderActionCommand();
    }

    function panelHeaderStatus() {
        return content.panelHeaderStatus();
    }

    function panelBody() {
        return content.panelBody();
    }

    function panelActions(panel) {
        return content.panelActions(panel);
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
            "todo": todo,
            "calendar": calendarEvents,
            "system": systemInfo,
            "battery": battery,
            "touchpad": touchpad
        };
        const poller = pollers[panel];
        return poller && !poller.ok ? poller.lastError : "";
    }

    onBarOpenChanged: {
        if (!barOpen)
            closeDrawers();

    }
    Component.onCompleted: {
        diagLog("component.completed", "bar loaded");
        syncActiveScreenToFocus();
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
        onCalendarRefreshRequested: calendarEvents.refresh()
    }

    BarContent {
        id: content

        openPanel: root.openPanel
        scriptRoot: root.scriptRoot
        now: clock.date
        clockDateMode: root.clockDateMode
        updates: root.updates.json
        updatesLastUpdatedMs: root.updates.lastUpdatedMs
        todo: root.todo.json
        calendar: root.calendarEvents.json
        bluetooth: root.bluetooth.json
        audio: root.audio.json
        brightness: root.brightness.json
        network: root.network.json
        privacy: root.privacy.json
        touchpad: root.touchpad.json
        system: root.systemInfo.json
        battery: root.battery.json
        caffeine: root.caffeine.json
        notificationTooltip: root.notificationStatus().tooltip
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
        onTriggered: todo.refresh()
    }

    Timer {
        id: hoverCloseDelay

        interval: 180
        repeat: false
        onTriggered: {
            if (root.hoveredSource.length === 0 && !root.popoutHovered && !root.extrasHovered && !root.inputPopupLocked) {
                root.closePanel();
                root.closeTrayMenu();
                root.extrasOpen = false;
            }
        }
    }

    Variants {
        model: Quickshell.screens

        PanelWindow {
            id: panel

            required property var modelData

            function claimScreen() {
                root.activeScreen = modelData;
            }

            function extrasLeft() {
                Qt.callLater(function() {
                    if (!extrasViewport.hovered)
                        root.extrasExited();

                });
            }

            screen: modelData
            implicitWidth: root.barVisible || root.barSlide > 0.01 ? Theme.railWidth : 1
            exclusiveZone: root.barOpen ? Math.round(Theme.railWidth * root.barSlide) : 0
            focusable: false
            visible: true
            color: "transparent"

            anchors {
                left: true
                top: true
                bottom: true
            }

            MouseArea {
                z: -1
                x: 0
                y: parent.height - height
                width: 1
                height: Math.ceil(parent.height / 5)
                acceptedButtons: Qt.NoButton
                hoverEnabled: true
                onEntered: {
                    panel.claimScreen();
                    root.edgeTriggerHovered = true;
                }
                onExited: root.edgeTriggerHovered = false
            }

            Rectangle {
                x: Math.round(-Theme.railWidth * (1 - root.barSlide))
                width: Theme.railWidth
                height: parent.height
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
                    onClicked: root.closeDrawers()
                }

                ColumnLayout {
                    id: railLayout

                    anchors.fill: parent
                    anchors.topMargin: 4
                    anchors.bottomMargin: 4
                    spacing: 0

                    RailTopActions {
                        openPanel: root.openPanel
                        scriptRoot: root.scriptRoot
                        onPanelClicked: (panel, centerY) => {
                            return root.togglePanel(panel, centerY);
                        }
                        onPanelHovered: (panel, centerY, source) => {
                            return root.hoverButtonEntered(panel, centerY, source);
                        }
                        onPanelExited: (source) => {
                            return root.hoverButtonExited(source);
                        }
                        onRunCommand: (command) => {
                            return root.run(command);
                        }
                    }

                    Repeater {
                        model: root.workspaceItems()

                        WorkspaceRailButton {
                            item: modelData
                            blinking: (modelData.urgent || root.workspaceAlert(modelData.id)) && root.blinkOn
                            onActivate: {
                                root.closeDrawers();
                                root.focusWorkspace(modelData.id);
                                workspaces.refresh();
                            }
                        }

                    }

                    SpecialWorkspaceRailButton {
                        workspace: workspaces.json.special
                        onActivate: {
                            root.closeDrawers();
                            root.toggleSpecialWorkspace("magic");
                            workspaces.refresh();
                        }
                    }

                    Item {
                        Layout.fillHeight: true
                    }

                    Item {
                        id: extrasPushSpacer

                        Layout.preferredHeight: root.extrasOpen ? extrasViewport.push : 0
                        Layout.minimumHeight: Layout.preferredHeight
                        Layout.maximumHeight: Layout.preferredHeight

                        Behavior on Layout.preferredHeight {
                            NumberAnimation {
                                duration: 140
                                easing.type: Easing.OutCubic
                            }

                        }

                    }

                    ExtrasToggleButton {
                        id: extrasToggle

                        active: root.extrasOpen
                        onToggle: root.toggleExtras()
                        onOpenRequested: {
                            root.openExtras();
                            root.extrasEntered();
                        }
                        onExited: panel.extrasLeft()
                    }

                    SystemRailSection {
                        audioStatus: audio.json
                        networkStatus: network.json
                        notificationsStatus: root.notificationStatus()
                        touchpadStatus: touchpad.json
                        systemStatus: systemInfo.json
                        batteryStatus: battery.json
                        openPanel: root.openPanel
                        panelHeight: panel.height
                        batteryExpanded: root.batteryExpanded
                        onPanelClicked: (panel, centerY) => {
                            if (panel === "notifications")
                                root.notificationPanelY = centerY;

                            return root.togglePanel(panel, centerY);
                        }
                        onPanelHovered: (panel, centerY, source) => {
                            if (panel === "notifications")
                                root.notificationPanelY = centerY;

                            return root.hoverButtonEntered(panel, centerY, source);
                        }
                        onNotificationsPositionChanged: (centerY) => {
                            root.notificationPanelY = centerY;
                        }
                        onPanelExited: (source) => {
                            return root.hoverButtonExited(source);
                        }
                        onRunCommand: (command) => {
                            return root.run(command);
                        }
                        onClearNotifications: root.clearNotifications()
                        onCloseDrawers: root.closeDrawers()
                        onToggleBatteryExpanded: root.batteryExpanded = !root.batteryExpanded
                        onCollapseBattery: root.batteryExpanded = false
                    }

                }

                RailClock {
                    id: clockText

                    anchors.horizontalCenter: parent.horizontalCenter
                    y: Math.round((parent.height - height) / 2)
                    z: 20
                    text: root.railClockText()
                    dateMode: root.clockDateMode
                    onHovered: (centerY) => {
                        return root.hoverButtonEntered("calendar", centerY, "calendar");
                    }
                    onExited: root.hoverButtonExited("calendar")
                    onClicked: root.clockDateMode = !root.clockDateMode
                }

                ExtrasDrawer {
                    id: extrasViewport

                    open: root.extrasOpen
                    topLimit: clockText.y + clockText.height + 4
                    bottomLimit: railLayout.y + extrasToggle.y
                    hoverMargin: Theme.buttonSize + 4
                    onHoverEntered: root.extrasEntered()
                    onHoverExited: panel.extrasLeft()

                    Column {
                        id: systemTrayItems

                        width: Theme.buttonSize

                        Repeater {
                            model: SystemTray.items

                            TrayRailItem {
                                item: modelData
                                onHovered: root.trayItemEntered()
                                onExited: panel.extrasLeft()
                                onOpenMenu: (item, centerY) => {
                                    return root.openTrayMenu(item, Math.round(extrasViewport.popupCenterY(systemTrayItems.y + centerY)));
                                }
                            }

                        }

                    }

                    ExtrasActionSection {
                        openPanel: root.openPanel
                        centerOffset: extrasViewport.popupCenterY(0)
                        updateIcon: root.updateIcon()
                        updatesStatus: updates.json
                        bluetoothStatus: bluetooth.json
                        audioStatus: audio.json
                        brightnessStatus: brightness.json
                        caffeineStatus: caffeine.json
                        privacyStatus: privacy.json
                        scriptRoot: root.scriptRoot
                        onPanelClicked: (panel, centerY) => {
                            return root.togglePanel(panel, centerY);
                        }
                        onPanelHovered: (panel, centerY, source) => {
                            return root.hoverButtonEntered(panel, centerY, source);
                        }
                        onPanelExited: (source) => {
                            return root.hoverButtonExited(source);
                        }
                        onRunCommand: (command) => {
                            return root.run(command);
                        }
                    }

                }

            }

            PowerOverlayWindow {
                targetScreen: modelData
                open: root.activeScreen === modelData && root.openPanel === "power"
                updateSummary: root.updateSummary()
                onAction: (kind) => {
                    return root.run(root.powerCommand(kind));
                }
                onClose: root.closePanel()
            }

            BarPopouts {
                panelWindow: panel
                panelHeight: panel.height
                screenWidth: panel.screen ? panel.screen.width : 0
                openPanel: root.activeScreen === modelData ? root.openPanel : ""
                openPanelY: root.openPanelY
                trayMenuY: root.trayMenuY
                trayMenuOpen: root.activeScreen === modelData && root.trayMenuOpen
                trayMenuHandle: root.trayMenuHandle
                trayMenuTitle: root.trayMenuTitle
                todoStatus: todo.json
                notesSaveRevision: root.notesSaveRevision
                notesSaveBusy: root.notesSaveBusy
                notesSaveError: root.notesSaveError
                notesStatusError: root.statusError("todo")
                generatedRefreshBusy: root.generatedRefreshBusy
                generatedRefreshError: root.generatedRefreshError
                calendarAddRevision: root.calendarAddRevision
                calendarAddBusy: root.calendarAddBusy
                calendarAddError: root.calendarAddError
                batteryStatus: battery.json
                clockDate: clock.date
                selectedCalendarDate: root.selectedCalendarDate
                calendarStatus: calendarEvents.json || ({
                })
                systemStatus: systemInfo.json || ({
                })
                performanceActionBusy: root.performanceActionBusy
                performanceActionError: root.performanceActionError
                performanceStatusError: root.statusError("system")
                scriptRoot: root.scriptRoot
                systemTitle: root.systemPanelTitle()
                systemBody: root.systemPanelBody()
                systemStatusError: root.statusError(root.openPanel)
                systemActions: root.systemPanelActions()
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
                basicTitle: root.panelTitle()
                basicSubtitle: root.panelSubtitle()
                basicBody: root.panelBody()
                basicStatusError: root.statusError(root.openPanel)
                basicActions: root.panelActions()
                basicCurrentId: root.openPanel === "caffeine" ? (caffeine.json.mode || "off") : ""
                basicHeaderActionIcon: root.panelHeaderActionIcon()
                basicHeaderActionCommand: root.panelHeaderActionCommand()
                basicHeaderStatus: root.panelHeaderStatus()
                notificationsModel: root.notificationItems || []
                notificationDnd: root.notificationDnd
                activeMprisPlayer: root.activeMprisPlayer
                onHoverEntered: root.popoutEntered()
                onHoverExited: root.popoutExited()
                onInputLockChanged: (locked) => {
                    return root.setInputPopupLocked(locked);
                }
                onClosePanel: root.closePanel()
                onCloseTrayMenu: root.closeTrayMenu()
                onClearNotifications: root.clearNotifications()
                onToggleNotificationDnd: {
                    root.notificationDnd = !root.notificationDnd;
                    if (root.notificationDnd)
                        root.toastItems = [];

                }
                onActivateNotification: (notification) => {
                    return root.focusNotificationSource(notification);
                }
                onSelectMprisPlayer: (playerName) => {
                    root.activeMprisPlayer = playerName;
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
                    calendarEvents.refresh();
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

                screen: modelData
                implicitWidth: notificationToasts.width
                implicitHeight: Math.max(1, notificationToasts.implicitHeight + 12)
                exclusiveZone: 0
                focusable: false
                visible: root.activeScreen === modelData && root.notificationToastsEnabled && root.toastItems.length > 0 && !root.notificationDnd
                color: "transparent"

                anchors {
                    right: true
                    bottom: true
                }

                NotificationToastStack {
                    id: notificationToasts

                    anchors.right: parent.right
                    anchors.bottom: parent.bottom
                    anchors.bottomMargin: 12
                    visible: root.notificationToastsEnabled && root.toastItems.length > 0 && !root.notificationDnd
                    toasts: root.toastItems
                    onDismiss: (notification, closeNotification) => {
                        root.removeNotificationToast(notification);
                        if (notification && closeNotification)
                            notification.dismiss();

                    }
                    onActivate: (notification) => {
                        return root.focusNotificationSource(notification);
                    }
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
