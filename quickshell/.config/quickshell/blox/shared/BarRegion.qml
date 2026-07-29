import "."
import QtQuick

Item {
    id: root

    required property var regionItems
    required property var controller
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
            controller: root.controller
            horizontal: root.horizontal
            trayOpensForward: root.region === "start" || root.region === "centre" && index === root.regionItems.length - 1
            panelExtent: root.panelExtent
            Component.onCompleted: root.trayHost.registerTrayToggle(this, root.horizontal)
            Component.onDestruction: root.trayHost.unregisterTrayToggle(this, root.horizontal)
        }

    }

}
