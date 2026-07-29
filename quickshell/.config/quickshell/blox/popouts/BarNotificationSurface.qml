import QtQuick

Item {
    id: root

    required property BarPopoutGeometry geometry
    property string openPanel: ""
    property var notifications: []
    property bool dnd: false

    signal hoverEntered()
    signal hoverExited()
    signal toggleDnd()
    signal activate(var notification)

    HoverPopupWindow {
        anchorWindow: root.geometry.panelWindow
        anchorX: root.geometry.popupX(notificationCenter.width, root.geometry.openPanelX)
        anchorY: root.geometry.popupY(notificationCenter.height, root.geometry.openPanelY)
        contentWidth: notificationCenter.width
        contentHeight: notificationCenter.height
        open: root.openPanel === "notifications"
        onHoverEntered: root.hoverEntered()
        onHoverExited: root.hoverExited()

        NotificationCenterPopout {
            id: notificationCenter

            notifications: root.notifications
            dnd: root.dnd
            // A horizontal panel is only one bar-thickness tall. Size against the
            // screen instead, otherwise the notification header consumes the
            // whole 240px minimum and the list is clipped.
            maxPopoutHeight: Math.min(720, Math.max(240, root.geometry.screenHeight - 16))
            onToggleDnd: root.toggleDnd()
            onActivate: (notification) => {
                return root.activate(notification);
            }
        }

    }

}
