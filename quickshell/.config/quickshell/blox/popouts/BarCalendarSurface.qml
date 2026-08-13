import "../services"
import "../shared"
import QtQuick

Item {
    id: root

    required property BarPopoutGeometry geometry
    required property BarSurfaceController surfaceController
    required property BarContentController contentController
    HoverPopupWindow {
        id: calendarWindow

        anchorWindow: root.geometry.panelWindow
        anchorX: root.geometry.popupX(calendarPopout.width, root.geometry.openPanelX)
        anchorY: root.geometry.popupY(calendarPopout.height, root.geometry.openPanelY)
        contentWidth: calendarPopout.width
        contentHeight: calendarPopout.height
        open: root.geometry.active && root.surfaceController.openPanel === "calendar"
        onOpenChanged: if (open) root.contentController.calendarController.open(root.contentController.now, root.geometry.panelWindow.screen)
        onHoverEntered: {
            root.surfaceController.popoutEntered();
            root.contentController.calendarController.refreshOnHover();
        }
        onHoverExited: root.surfaceController.popoutExited()
        onVisibleChanged: {
            if (!visible && root.geometry.active && !root.contentController.calendarController.childWindowOpen)
                root.surfaceController.setInputPopupLocked(false);

        }

        CalendarPopout {
            id: calendarPopout

            controller: root.contentController.calendarController
            onFocusRequested: calendarWindow.requestKeyboardFocus()
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
