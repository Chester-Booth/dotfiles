import "../shared"
import QtQuick

Item {
    id: root

    required property BarPopoutGeometry geometry
    property real menuY: 8
    property bool menuOpen: false
    property var menuHandle: null
    property string menuTitle: ""

    signal hoverEntered()
    signal hoverExited()
    signal closeRequested()

    HoverPopupWindow {
        anchorWindow: root.geometry.panelWindow
        anchorX: root.geometry.popupX(trayMenuPopout.width, root.geometry.openPanelX)
        anchorY: root.geometry.popupY(trayMenuPopout.height, root.menuY)
        contentWidth: trayMenuPopout.width
        contentHeight: trayMenuPopout.height
        open: root.menuOpen
        onHoverEntered: root.hoverEntered()
        onHoverExited: root.hoverExited()

        TrayMenuPopout {
            id: trayMenuPopout

            menuHandle: root.menuHandle
            title: root.menuTitle
            onTriggered: root.closeRequested()
        }

    }

}
