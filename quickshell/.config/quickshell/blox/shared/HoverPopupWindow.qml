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
    property bool keyboardFocus: false
    property bool persistentKeyboardFocus: false
    property bool focusOnPress: false

    signal hoverEntered()
    signal hoverExited()

    function requestKeyboardFocus() {
        keyboardFocus = true;
        if (_backingWindow)
            _backingWindow.requestActivate();
    }

    anchor.window: anchorWindow
    anchor.rect.x: anchorX
    anchor.rect.y: anchorY
    implicitWidth: contentWidth
    implicitHeight: contentHeight
    surfaceFormat.opaque: false
    grabFocus: keyboardFocus || persistentKeyboardFocus
    color: Qt.rgba(0, 0, 0, 0.004)
    onVisibleChanged: {
        if (!visible)
            keyboardFocus = false;
    }

    Item {
        id: contentHost

        width: root.contentWidth
        height: root.contentHeight

        HoverHandler {
            onHoveredChanged: hovered ? root.hoverEntered() : root.hoverExited()
        }
    }
}
