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
        anchorX: root.geometry.popupX(calendarLoader.item ? calendarLoader.item.width : 360, root.geometry.openPanelX)
        anchorY: root.geometry.popupY(calendarLoader.item ? calendarLoader.item.height : 352, root.geometry.openPanelY)
        contentWidth: calendarLoader.item ? calendarLoader.item.width : 360
        contentHeight: calendarLoader.item ? calendarLoader.item.height : 352
        open: root.geometry.active && root.surfaceController.openPanel === "calendar"
        onOpenChanged: {
            if (open && root.contentController.useRedesignedCalendar)
                root.contentController.calendarController.open(root.contentController.now, root.geometry.panelWindow.screen);

        }
        onHoverEntered: {
            root.surfaceController.popoutEntered();
            if (root.contentController.useRedesignedCalendar)
                root.contentController.calendarController.refreshOnHover();

        }
        onHoverExited: root.surfaceController.popoutExited()
        onVisibleChanged: {
            if (!visible && root.geometry.active && !root.contentController.calendarController.childWindowOpen)
                root.surfaceController.setInputPopupLocked(false);

        }

        Loader {
            id: calendarLoader

            sourceComponent: root.contentController.useRedesignedCalendar ? redesignedComponent : legacyComponent
        }

        Component {
            id: redesignedComponent

            CalendarPopoutV2 {
                controller: root.contentController.calendarController
                onFocusRequested: calendarWindow.requestKeyboardFocus()
            }

        }

        Component {
            id: legacyComponent

            CalendarPopout {
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

    Connections {
        function onChildWindowOpenChanged() {
            if (root.geometry.active)
                root.surfaceController.setInputPopupLocked(root.contentController.calendarController.childWindowOpen);

        }

        target: root.contentController.calendarController
    }

}
