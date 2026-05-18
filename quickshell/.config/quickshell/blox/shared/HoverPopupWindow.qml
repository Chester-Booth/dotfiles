import "."
import QtQuick
import Quickshell

PopupWindow {
    id: root

    default property alias content: contentHost.data
    property var anchorWindow
    property real anchorX: Theme.railWidth + 8
    property real anchorY: 8
    property real contentWidth: 0
    property real contentHeight: 0

    signal hoverEntered()
    signal hoverExited()

    anchor.window: anchorWindow
    anchor.rect.x: anchorX
    anchor.rect.y: anchorY
    implicitWidth: contentWidth
    implicitHeight: contentHeight
    color: "transparent"

    Item {
        id: contentHost

        width: root.contentWidth
        height: root.contentHeight

        HoverHandler {
            onHoveredChanged: hovered ? root.hoverEntered() : root.hoverExited()
        }
    }
}
