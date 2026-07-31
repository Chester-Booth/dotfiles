import "../services"
import "../shared"
import QtQuick

Item {
    id: root

    required property BarPopoutGeometry geometry
    required property BarSurfaceController surfaceController
    required property BarContentController contentController
    readonly property string effectiveDate: contentController.selectedCalendarDate || Qt.formatDate(contentController.now, "yyyy-MM-dd")
    readonly property var status: contentController.calendar.json || ({
    })
    readonly property bool loading: !status || status.date !== effectiveDate

    HoverPopupWindow {
        id: calendarWindow

        anchorWindow: root.geometry.panelWindow
        anchorX: root.geometry.popupX(calendarPopout.width, root.geometry.openPanelX)
        anchorY: root.geometry.popupY(calendarPopout.height, root.geometry.openPanelY)
        contentWidth: calendarPopout.width
        contentHeight: calendarPopout.height
        open: root.geometry.active && root.surfaceController.openPanel === "calendar"
        onHoverEntered: root.surfaceController.popoutEntered()
        onHoverExited: root.surfaceController.popoutExited()
        onVisibleChanged: {
            if (!visible && root.geometry.active)
                root.surfaceController.setInputPopupLocked(false);

        }

        CalendarPopout {
            id: calendarPopout

            baseDate: root.contentController.now
            selectedDate: root.contentController.selectedCalendarDate ? new Date(root.contentController.selectedCalendarDate + "T00:00:00") : root.contentController.now
            addRevision: root.contentController.actions.calendarAddRevision
            addBusy: root.contentController.actions.calendarAddBusy
            addError: root.contentController.actions.calendarAddError
            eventsLoading: root.loading
            events: !root.loading && root.status.events ? root.status.events : []
            eventsText: root.loading ? "Loading…" : root.status.raw || "No events"
            eventsError: !root.loading && root.status.ok === false ? (root.status.error || "Calendar request failed") : ""
            onResetMonth: root.contentController.resetCalendarMonth()
            onSelected: (day) => {
                return root.contentController.selectCalendarDate(day);
            }
            onAddEvent: (day, title) => {
                root.contentController.actions.addCalendarEvent(day, title);
            }
            onOpenEvent: root.contentController.openCalendar()
            onFocusRequested: calendarWindow.requestKeyboardFocus()
        }

    }

}
