import QtQuick

Item {
    id: root

    property var panelWindow
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
    property bool notificationDnd: false
    property string activeMprisPlayer: ""

    signal hoverEntered()
    signal hoverExited()
    signal inputLockChanged(bool locked)
    signal closePanel()
    signal closeTrayMenu()
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
    signal systemLevelPreview(string kind, int value, bool muted)
    signal selectSystemPanel(string panel)
    signal basicAction(string command, bool keepOpen)
    signal toggleNotificationDnd()
    signal activateNotification(var notification)
    signal selectMprisPlayer(string playerName)

    BarPopoutGeometry {
        id: geometry

        panelWindow: root.panelWindow
        screenWidth: root.screenWidth
        screenHeight: root.screenHeight
        openPanelX: root.openPanelX
        openPanelY: root.openPanelY
    }

    BarNotesSurface {
        geometry: geometry
        openPanel: root.openPanel
        todoStatus: root.todoStatus
        saveRevision: root.notesSaveRevision
        saveBusy: root.notesSaveBusy
        saveError: root.notesSaveError
        statusError: root.notesStatusError
        refreshBusy: root.generatedRefreshBusy
        refreshError: root.generatedRefreshError
        onHoverEntered: root.hoverEntered()
        onHoverExited: root.hoverExited()
        onInputLockChanged: (locked) => {
            return root.inputLockChanged(locked);
        }
        onPrevious: root.previousTodo()
        onNext: root.nextTodo()
        onRefresh: (file) => {
            return root.refreshTodo(file);
        }
        onSave: (file, body) => {
            return root.saveTodo(file, body);
        }
    }

    BarTrayMenuSurface {
        geometry: geometry
        menuY: root.trayMenuY
        menuOpen: root.trayMenuOpen
        menuHandle: root.trayMenuHandle
        menuTitle: root.trayMenuTitle
        onHoverEntered: root.hoverEntered()
        onHoverExited: root.hoverExited()
        onCloseRequested: root.closeTrayMenu()
    }

    BarCalendarSurface {
        geometry: geometry
        openPanel: root.openPanel
        clockDate: root.clockDate
        selectedDate: root.selectedCalendarDate
        status: root.calendarStatus
        addRevision: root.calendarAddRevision
        addBusy: root.calendarAddBusy
        addError: root.calendarAddError
        onHoverEntered: root.hoverEntered()
        onHoverExited: root.hoverExited()
        onInputLockChanged: (locked) => {
            return root.inputLockChanged(locked);
        }
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
    }

    BarSystemSurfaces {
        geometry: geometry
        openPanel: root.openPanel
        systemStatus: root.systemStatus
        batteryStatus: root.batteryStatus
        scriptRoot: root.scriptRoot
        performanceActionBusy: root.performanceActionBusy
        performanceActionError: root.performanceActionError
        performanceStatusError: root.performanceStatusError
        systemTitle: root.systemTitle
        systemBody: root.systemBody
        systemStatusError: root.systemStatusError
        systemActions: root.systemActions
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
        activeMprisPlayer: root.activeMprisPlayer
        onHoverEntered: root.hoverEntered()
        onHoverExited: root.hoverExited()
        onClosePanel: root.closePanel()
        onPerformanceAction: (command) => {
            return root.performanceAction(command);
        }
        onPerformanceVisibleChanged: (visible) => {
            return root.performanceVisibleChanged(visible);
        }
        onSystemAction: (command, keepOpen) => {
            return root.systemAction(command, keepOpen);
        }
        onLevelPreview: (kind, value, muted) => {
            return root.systemLevelPreview(kind, value, muted);
        }
        onSelectSystemPanel: (panel) => {
            return root.selectSystemPanel(panel);
        }
        onSelectMprisPlayer: (playerName) => {
            return root.selectMprisPlayer(playerName);
        }
    }

    BarNotificationSurface {
        geometry: geometry
        openPanel: root.openPanel
        notifications: root.notificationsModel
        dnd: root.notificationDnd
        onHoverEntered: root.hoverEntered()
        onHoverExited: root.hoverExited()
        onToggleDnd: root.toggleNotificationDnd()
        onActivate: (notification) => {
            return root.activateNotification(notification);
        }
    }

    BarBasicSurface {
        geometry: geometry
        openPanel: root.openPanel
        title: root.basicTitle
        subtitle: root.basicSubtitle
        body: root.basicBody
        statusError: root.basicStatusError
        actions: root.basicActions
        currentId: root.basicCurrentId
        headerActionIcon: root.basicHeaderActionIcon
        headerActionCommand: root.basicHeaderActionCommand
        headerStatus: root.basicHeaderStatus
        onHoverEntered: root.hoverEntered()
        onHoverExited: root.hoverExited()
        onAction: (command, keepOpen) => {
            return root.basicAction(command, keepOpen);
        }
    }

}
