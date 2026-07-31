import "."
import "../services"
import QtQuick

Item {
    id: root

    required property var regionItems
    required property BarSurfaceController surfaceController
    required property BarContentController contentController
    required property WorkspaceController workspaceController
    required property NotificationController notificationController
    required property var trayHost
    required property bool horizontal
    required property real panelExtent
    required property string region

    implicitWidth: horizontal ? horizontalRow.implicitWidth : verticalColumn.implicitWidth
    implicitHeight: horizontal ? horizontalRow.implicitHeight : verticalColumn.implicitHeight
    width: implicitWidth
    height: implicitHeight

    Row {
        id: horizontalRow

        visible: root.horizontal

        Repeater {
            model: root.horizontal ? root.regionItems : []
            delegate: regionDelegate
        }

    }

    Column {
        id: verticalColumn

        visible: !root.horizontal

        Repeater {
            model: root.horizontal ? [] : root.regionItems
            delegate: regionDelegate
        }

    }

    Component {
        id: regionDelegate

        BarItemDelegate {
            required property var modelData
            required property int index

            itemId: modelData.id
            surfaceController: root.surfaceController
            contentController: root.contentController
            workspaceController: root.workspaceController
            notificationController: root.notificationController
            horizontal: root.horizontal
            trayOpensForward: root.region === "start" || root.region === "centre" && index === root.regionItems.length - 1
            panelExtent: root.panelExtent
            Component.onCompleted: root.trayHost.registerTrayToggle(this, root.horizontal)
            Component.onDestruction: root.trayHost.unregisterTrayToggle(this, root.horizontal)
        }

    }

}
