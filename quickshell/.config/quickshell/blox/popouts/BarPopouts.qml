import "../shared"
import QtQuick
import Quickshell

Item {
    id: root

    property var panelWindow
    property real panelHeight: 0
    property real screenWidth: 0
    property real screenHeight: 0
    property string openPanel: ""
    property real openPanelX: 8
    property real openPanelY: 8
    property real trayMenuY: 8
    property bool trayMenuOpen: false
    property var trayMenuHandle: null
    property string trayMenuTitle: ""
    property var todoStatus
    property int notesSaveRevision: 0
    property bool notesSaveBusy: false
    property string notesSaveError: ""
    property string notesStatusError: ""
    property bool generatedRefreshBusy: false
    property string generatedRefreshError: ""
    property int calendarAddRevision: 0
    property bool calendarAddBusy: false
    property string calendarAddError: ""
    property var batteryStatus
    property date clockDate
    property string selectedCalendarDate: ""
    property var calendarStatus
    readonly property string effectiveCalendarDate: selectedCalendarDate || Qt.formatDate(clockDate, "yyyy-MM-dd")
    readonly property bool calendarLoading: !calendarStatus || calendarStatus.date !== effectiveCalendarDate
    property var systemStatus
    property bool performanceActionBusy: false
    property string performanceActionError: ""
    property string performanceStatusError: ""
    property string scriptRoot: ""
    property string systemTitle: ""
    property string systemBody: ""
    property string systemStatusError: ""
    property var systemActions: []
    property int audioVolume: 0
    property string audioIcon: "󰕾"
    property bool audioMuted: false
    property bool micMuted: false
    property bool networkEnabled: true
    property bool bluetoothEnabled: true
    property string wifiIcon: "󰤩"
    property string wifiText: "Wi-Fi"
    property string bluetoothIcon: "󰂯"
    property string brightnessIcon: "󰃠"
    property int brightnessPercent: 0
    property string blueLightMode: "auto"
    property bool blueLightActive: false
    property string basicTitle: ""
    property string basicSubtitle: ""
    property string basicBody: ""
    property string basicStatusError: ""
    property var basicActions: []
    property string basicCurrentId: ""
    property string basicHeaderActionIcon: ""
    property string basicHeaderActionCommand: ""
    property string basicHeaderStatus: ""
    property var notificationsModel: []
    property real maxNotificationHeight: 720
    property bool notificationDnd: false
    property string activeMprisPlayer: ""

    signal hoverEntered()
    signal hoverExited()
    signal inputLockChanged(bool locked)
    signal closePanel()
    signal closeTrayMenu()
    signal runCommand(string command)
    signal previousTodo()
    signal nextTodo()
    signal refreshTodo(string file)
    signal saveTodo(string file, string body)
    signal resetCalendarMonth()
    signal selectCalendarDate(string day)
    signal addCalendarEvent(string day, string title)
    signal openCalendarEvent(string title)
    signal performanceAction(string command)
    signal performanceVisibleChanged(bool visible)
    signal systemAction(string command, bool keepOpen)
    signal selectSystemPanel(string panel)
    signal basicAction(string command, bool keepOpen)
    signal clearNotifications()
    signal toggleNotificationDnd()
    signal activateNotification(var notification)
    signal selectMprisPlayer(string playerName)

    function popupY(height, requestedY) {
        if (Theme.barPosition === "top")
            return Theme.railWidth + 8;

        if (Theme.barPosition === "bottom")
            return -height - 8;

        return Math.max(8, Math.min(screenHeight - height - 8, requestedY - height / 2));
    }

    function popupX(width, requestedX) {
        if (Theme.barPosition === "left")
            return Theme.railWidth + 8;

        if (Theme.barPosition === "right")
            return -width - 8;

        return Math.max(8, Math.min(screenWidth - width - 8, requestedX - width / 2));
    }

    HoverPopupWindow {
        id: notesWindow

        anchorWindow: root.panelWindow
        anchorX: root.popupX(notesPopout.width, root.openPanelX)
        anchorY: root.popupY(notesPopout.height, root.openPanelY)
        contentWidth: notesPopout.width
        contentHeight: notesPopout.height
        persistentKeyboardFocus: notesPopout.editing
        focusOnPress: true
        open: root.openPanel === "todo"
        onHoverEntered: root.hoverEntered()
        onHoverExited: root.hoverExited()
        onVisibleChanged: {
            if (!visible)
                root.inputLockChanged(false);

        }

        NotesPopout {
            id: notesPopout

            title: root.todoStatus && root.todoStatus.name ? root.todoStatus.name : "notes.md"
            body: root.todoStatus && root.todoStatus.raw ? root.todoStatus.raw : ""
            file: root.todoStatus && root.todoStatus.file ? root.todoStatus.file : ""
            index: root.todoStatus && root.todoStatus.index !== undefined ? root.todoStatus.index : 0
            count: root.todoStatus && root.todoStatus.count !== undefined ? root.todoStatus.count : 1
            saveRevision: root.notesSaveRevision
            saveBusy: root.notesSaveBusy
            saveError: root.notesSaveError
            statusError: root.notesStatusError
            refreshBusy: root.generatedRefreshBusy
            refreshError: root.generatedRefreshError
            maxPopoutWidth: root.screenWidth > 0 ? root.screenWidth * 0.75 : 680
            maxPopoutHeight: root.panelHeight > 0 ? root.panelHeight * 0.75 : 760
            onPrevious: root.previousTodo()
            onNext: root.nextTodo()
            onRefresh: (file) => {
                return root.refreshTodo(file);
            }
            onSave: (file, body) => {
                return root.saveTodo(file, body);
            }
            onEditingChanged: root.inputLockChanged(editing)
            onFocusRequested: {
                root.inputLockChanged(true);
                notesWindow.requestKeyboardFocus();
            }
        }

    }

    HoverPopupWindow {
        id: trayWindow

        anchorWindow: root.panelWindow
        anchorX: root.popupX(trayMenuPopout.width, root.openPanelX)
        anchorY: root.popupY(trayMenuPopout.height, root.trayMenuY)
        contentWidth: trayMenuPopout.width
        contentHeight: trayMenuPopout.height
        open: root.trayMenuOpen
        onHoverEntered: root.hoverEntered()
        onHoverExited: root.hoverExited()

        TrayMenuPopout {
            id: trayMenuPopout

            menuHandle: root.trayMenuHandle
            title: root.trayMenuTitle
            onTriggered: root.closeTrayMenu()
        }

    }

    HoverPopupWindow {
        id: calendarWindow

        anchorWindow: root.panelWindow
        anchorX: root.popupX(calendarPopout.width, root.openPanelX)
        anchorY: root.popupY(calendarPopout.height, root.openPanelY)
        contentWidth: calendarPopout.width
        contentHeight: calendarPopout.height
        focusOnPress: true
        open: root.openPanel === "calendar"
        onHoverEntered: root.hoverEntered()
        onHoverExited: root.hoverExited()
        onVisibleChanged: {
            if (!visible)
                root.inputLockChanged(false);

        }

        CalendarPopout {
            id: calendarPopout

            baseDate: root.clockDate
            selectedDate: root.selectedCalendarDate ? new Date(root.selectedCalendarDate + "T00:00:00") : root.clockDate
            addRevision: root.calendarAddRevision
            addBusy: root.calendarAddBusy
            addError: root.calendarAddError
            eventsLoading: root.calendarLoading
            events: !root.calendarLoading && root.calendarStatus.events ? root.calendarStatus.events : []
            eventsText: root.calendarLoading ? "Loading…" : root.calendarStatus.raw || "No events"
            eventsError: !root.calendarLoading && root.calendarStatus.ok === false ? (root.calendarStatus.error || "Calendar request failed") : ""
            onResetMonth: root.resetCalendarMonth()
            onSelected: (day) => {
                return root.selectCalendarDate(day);
            }
            onAddEvent: (day, title) => {
                return root.addCalendarEvent(day, title);
            }
            onOpenEvent: (title) => {
                return root.openCalendarEvent(title);
            }
            onFocusRequested: {
                calendarWindow.requestKeyboardFocus();
            }
        }

    }

    HoverPopupWindow {
        id: mediaWindow

        anchorWindow: root.panelWindow
        anchorX: root.popupX(mediaPlayer.implicitWidth, root.openPanelX)
        anchorY: Math.max(8, systemWindow.anchorY - mediaPlayer.implicitHeight - 8)
        contentWidth: 330
        contentHeight: mediaPlayer.implicitHeight
        open: root.openPanel === "audio"
        onHoverEntered: root.hoverEntered()
        onHoverExited: root.hoverExited()

        MediaPlayer {
            id: mediaPlayer

            width: 330
            activePlayerName: root.activeMprisPlayer
            onSelectPlayer: (playerName) => {
                return root.selectMprisPlayer(playerName);
            }
        }

    }

    HoverPopupWindow {
        id: performanceWindow

        anchorWindow: root.panelWindow
        anchorX: root.popupX(performancePopout.width, root.openPanelX)
        anchorY: root.popupY(performancePopout.height, root.openPanelY)
        contentWidth: performancePopout.width
        contentHeight: performancePopout.height
        open: root.openPanel === "system"
        onHoverEntered: root.hoverEntered()
        onHoverExited: root.hoverExited()
        onVisibleChanged: root.performanceVisibleChanged(visible)

        PerformancePopout {
            id: performancePopout

            status: root.systemStatus || ({
            })
            batteryStatus: root.batteryStatus || ({
            })
            scriptRoot: root.scriptRoot
            actionBusy: root.performanceActionBusy
            actionError: root.performanceActionError
            statusError: root.performanceStatusError
            onAction: (command) => {
                return root.performanceAction(command);
            }
        }

    }

    HoverPopupWindow {
        id: systemWindow

        anchorWindow: root.panelWindow
        anchorX: root.popupX(systemPopout.width, root.openPanelX)
        anchorY: root.popupY(systemPopout.height, root.openPanelY)
        contentWidth: systemPopout.width
        contentHeight: systemPopout.height
        open: ["audio", "network", "bluetooth", "brightness"].indexOf(root.openPanel) >= 0
        onHoverEntered: root.hoverEntered()
        onHoverExited: root.hoverExited()
        onVisibleChanged: {
            if (!visible && ["audio", "network", "bluetooth", "brightness"].indexOf(root.openPanel) >= 0)
                root.closePanel();

        }

        SystemPopout {
            id: systemPopout

            title: root.systemTitle
            body: root.systemBody
            statusError: root.systemStatusError
            actions: root.systemActions
            mode: root.openPanel
            audioVolume: root.audioVolume
            audioIcon: root.audioIcon
            audioMuted: root.audioMuted
            micMuted: root.micMuted
            networkEnabled: root.networkEnabled
            bluetoothEnabled: root.bluetoothEnabled
            wifiIcon: root.wifiIcon
            wifiText: root.wifiText
            bluetoothIcon: root.bluetoothIcon
            brightnessIcon: root.brightnessIcon
            brightnessPercent: root.brightnessPercent
            blueLightMode: root.blueLightMode
            blueLightActive: root.blueLightActive
            scriptRoot: root.scriptRoot
            onAction: (command, keepOpen) => {
                return root.systemAction(command, keepOpen);
            }
            onSectionSelected: (panel) => {
                return root.selectSystemPanel(panel);
            }
        }

    }

    HoverPopupWindow {
        anchorWindow: root.panelWindow
        anchorX: root.popupX(notificationCenter.width, root.openPanelX)
        anchorY: root.popupY(notificationCenter.height, root.openPanelY)
        contentWidth: notificationCenter.width
        contentHeight: notificationCenter.height
        open: root.openPanel === "notifications"
        onHoverEntered: root.hoverEntered()
        onHoverExited: root.hoverExited()

        NotificationCenterPopout {
            id: notificationCenter

            notifications: root.notificationsModel
            dnd: root.notificationDnd
            maxPopoutHeight: Math.min(720, Math.max(240, root.panelHeight - 16))
            onClearAll: root.clearNotifications()
            onToggleDnd: root.toggleNotificationDnd()
            onActivate: (notification) => {
                return root.activateNotification(notification);
            }
        }

    }

    HoverPopupWindow {
        anchorWindow: root.panelWindow
        anchorX: root.popupX(basicPopout.width, root.openPanelX)
        anchorY: root.popupY(basicPopout.height, root.openPanelY)
        contentWidth: 320
        contentHeight: basicPopout.height
        open: ["updates", "privacy", "caffeine"].indexOf(root.openPanel) >= 0
        onHoverEntered: root.hoverEntered()
        onHoverExited: root.hoverExited()

        BasicPopout {
            id: basicPopout

            width: 320
            title: root.basicTitle
            subtitle: root.basicSubtitle
            body: root.basicBody
            statusError: root.basicStatusError
            actions: root.basicActions
            currentId: root.basicCurrentId
            headerActionIcon: root.basicHeaderActionIcon
            headerActionCommand: root.basicHeaderActionCommand
            headerStatus: root.basicHeaderStatus
            onAction: (command, keepOpen) => {
                return root.basicAction(command, keepOpen);
            }
        }

    }

}
