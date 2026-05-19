import "../shared"
import QtQuick
import Quickshell

Item {
    id: root

    property var panelWindow
    property real panelHeight: 0
    property real screenWidth: 0
    property string openPanel: ""
    property real openPanelY: 8
    property real trayMenuY: 8
    property bool trayMenuOpen: false
    property var trayMenuHandle: null
    property string trayMenuTitle: ""
    property var todoStatus
    property var batteryStatus
    property date clockDate
    property string selectedCalendarDate: ""
    property var calendarStatus
    property var systemStatus
    property string scriptRoot: ""
    property string systemTitle: ""
    property string systemBody: ""
    property var systemActions: []
    property int audioVolume: 0
    property string audioIcon: "󰕾"
    property bool audioMuted: false
    property bool micMuted: false
    property string wifiIcon: "󰤩"
    property string wifiText: "Wi-Fi"
    property string bluetoothIcon: "󰂯"
    property string brightnessIcon: "󰃠"
    property int brightnessPercent: 0
    property string basicTitle: ""
    property string basicSubtitle: ""
    property string basicBody: ""
    property var basicActions: []
    property string basicHeaderActionIcon: ""
    property string basicHeaderActionCommand: ""

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

    HoverPopupWindow {
        id: notesWindow

        anchorWindow: root.panelWindow
        anchorY: Math.max(8, Math.min(root.panelHeight - notesPopout.height - 8, root.openPanelY - notesPopout.height / 2))
        contentWidth: notesPopout.width
        contentHeight: notesPopout.height
        persistentKeyboardFocus: notesPopout.editing
        focusOnPress: true
        visible: root.openPanel === "todo"
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
            maxPopoutWidth: root.screenWidth > 0 ? root.screenWidth * 0.75 : 680
            maxPopoutHeight: root.panelHeight > 0 ? root.panelHeight * 0.75 : 760
            onPrevious: root.previousTodo()
            onNext: root.nextTodo()
            onRefresh: (file) => root.refreshTodo(file)
            onSave: (file, body) => root.saveTodo(file, body)
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
        anchorY: Math.max(8, Math.min(root.panelHeight - trayMenuPopout.height - 8, root.trayMenuY - trayMenuPopout.height / 2))
        contentWidth: trayMenuPopout.width
        contentHeight: trayMenuPopout.height
        visible: root.trayMenuOpen
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
        anchorY: Math.max(8, Math.min(root.panelHeight - calendarPopout.height - 8, root.openPanelY - calendarPopout.height / 2))
        contentWidth: calendarPopout.width
        contentHeight: calendarPopout.height
        focusOnPress: true
        visible: root.openPanel === "calendar"
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
            events: root.calendarStatus && root.calendarStatus.events ? root.calendarStatus.events : []
            eventsText: root.calendarStatus && root.calendarStatus.raw ? root.calendarStatus.raw : "No events"
            onResetMonth: root.resetCalendarMonth()
            onSelected: (day) => root.selectCalendarDate(day)
            onAddEvent: (day, title) => root.addCalendarEvent(day, title)
            onOpenEvent: (title) => root.openCalendarEvent(title)
            onFocusRequested: {
                calendarWindow.requestKeyboardFocus();
            }
        }
    }

    HoverPopupWindow {
        anchorWindow: root.panelWindow
        anchorY: Math.max(8, Math.min(root.panelHeight - performancePopout.height - 8, root.openPanelY - performancePopout.height / 2))
        contentWidth: performancePopout.width
        contentHeight: performancePopout.height
        visible: root.openPanel === "system"
        onHoverEntered: root.hoverEntered()
        onHoverExited: root.hoverExited()
        onVisibleChanged: root.performanceVisibleChanged(visible)

        PerformancePopout {
            id: performancePopout

            status: root.systemStatus || ({})
            batteryStatus: root.batteryStatus || ({})
            scriptRoot: root.scriptRoot
            onAction: (command) => root.performanceAction(command)
        }
    }

    HoverPopupWindow {
        anchorWindow: root.panelWindow
        anchorY: Math.max(8, Math.min(root.panelHeight - systemPopout.height - 8, root.openPanelY - systemPopout.height / 2))
        contentWidth: systemPopout.width
        contentHeight: systemPopout.height
        visible: ["audio", "network", "bluetooth", "brightness"].indexOf(root.openPanel) >= 0
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
            actions: root.systemActions
            mode: root.openPanel
            audioVolume: root.audioVolume
            audioIcon: root.audioIcon
            audioMuted: root.audioMuted
            micMuted: root.micMuted
            wifiIcon: root.wifiIcon
            wifiText: root.wifiText
            bluetoothIcon: root.bluetoothIcon
            brightnessIcon: root.brightnessIcon
            brightnessPercent: root.brightnessPercent
            onAction: (command, keepOpen) => root.systemAction(command, keepOpen)
            onSectionSelected: (panel) => root.selectSystemPanel(panel)
        }
    }

    HoverPopupWindow {
        anchorWindow: root.panelWindow
        anchorY: Math.max(8, Math.min(root.panelHeight - basicPopout.height - 8, root.openPanelY - basicPopout.height / 2))
        contentWidth: 320
        contentHeight: basicPopout.height
        visible: ["updates", "privacy"].indexOf(root.openPanel) >= 0
        onHoverEntered: root.hoverEntered()
        onHoverExited: root.hoverExited()

        BasicPopout {
            id: basicPopout

            width: 320
            title: root.basicTitle
            subtitle: root.basicSubtitle
            body: root.basicBody
            actions: root.basicActions
            headerActionIcon: root.basicHeaderActionIcon
            headerActionCommand: root.basicHeaderActionCommand
            onAction: (command, keepOpen) => root.basicAction(command, keepOpen)
        }
    }
}
