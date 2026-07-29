import QtQuick

Item {
    id: root

    required property BarPopoutGeometry geometry
    property string openPanel: ""
    property string title: ""
    property string subtitle: ""
    property string body: ""
    property string statusError: ""
    property var actions: []
    property string currentId: ""
    property string headerActionIcon: ""
    property string headerActionCommand: ""
    property string headerStatus: ""

    signal hoverEntered()
    signal hoverExited()
    signal action(string command, bool keepOpen)

    HoverPopupWindow {
        anchorWindow: root.geometry.panelWindow
        anchorX: root.geometry.popupX(basicPopout.width, root.geometry.openPanelX)
        anchorY: root.geometry.popupY(basicPopout.height, root.geometry.openPanelY)
        contentWidth: 320
        contentHeight: basicPopout.height
        open: ["updates", "privacy", "caffeine"].indexOf(root.openPanel) >= 0
        onHoverEntered: root.hoverEntered()
        onHoverExited: root.hoverExited()

        BasicPopout {
            id: basicPopout

            width: 320
            title: root.title
            subtitle: root.subtitle
            body: root.body
            statusError: root.statusError
            actions: root.actions
            currentId: root.currentId
            headerActionIcon: root.headerActionIcon
            headerActionCommand: root.headerActionCommand
            headerStatus: root.headerStatus
            onAction: (command, keepOpen) => {
                return root.action(command, keepOpen);
            }
        }

    }

}
