import QtQuick

Item {
    id: root

    required property BarPopoutGeometry geometry
    property string openPanel: ""
    property date clockDate
    property string selectedDate: ""
    property var status
    property int addRevision: 0
    property bool addBusy: false
    property string addError: ""
    readonly property string effectiveDate: selectedDate || Qt.formatDate(clockDate, "yyyy-MM-dd")
    readonly property bool loading: !status || status.date !== effectiveDate

    signal hoverEntered()
    signal hoverExited()
    signal inputLockChanged(bool locked)
    signal resetMonth()
    signal selected(string day)
    signal addEvent(string day, string title)
    signal openEvent(string title)

    HoverPopupWindow {
        id: calendarWindow

        anchorWindow: root.geometry.panelWindow
        anchorX: root.geometry.popupX(calendarPopout.width, root.geometry.openPanelX)
        anchorY: root.geometry.popupY(calendarPopout.height, root.geometry.openPanelY)
        contentWidth: calendarPopout.width
        contentHeight: calendarPopout.height
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
            selectedDate: root.selectedDate ? new Date(root.selectedDate + "T00:00:00") : root.clockDate
            addRevision: root.addRevision
            addBusy: root.addBusy
            addError: root.addError
            eventsLoading: root.loading
            events: !root.loading && root.status.events ? root.status.events : []
            eventsText: root.loading ? "Loading…" : root.status.raw || "No events"
            eventsError: !root.loading && root.status.ok === false ? (root.status.error || "Calendar request failed") : ""
            onResetMonth: root.resetMonth()
            onSelected: (day) => {
                return root.selected(day);
            }
            onAddEvent: (day, title) => {
                return root.addEvent(day, title);
            }
            onOpenEvent: (title) => {
                return root.openEvent(title);
            }
            onFocusRequested: calendarWindow.requestKeyboardFocus()
        }

    }

}
