import "."
import QtQuick
import Quickshell
import Quickshell.Hyprland

PopupWindow {
    id: root

    default property alias content: contentHost.data
    property var anchorWindow
    property real anchorX: Theme.railWidth + 8
    property real anchorY: 8
    property real contentWidth: 0
    property real contentHeight: 0
    property real slideOffset: 10
    property bool open: false
    property bool rendered: false
    property bool keyboardFocus: false
    property bool persistentKeyboardFocus: false
    property bool focusOnPress: false
    readonly property bool animating: showAnimation.running || hideAnimation.running

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
    visible: rendered
    onVisibleChanged: {
        if (!visible)
            keyboardFocus = false;

    }
    onOpenChanged: {
        if (open) {
            hideAnimation.stop();
            rendered = true;
            showAnimation.restart();
        } else {
            showAnimation.stop();
            hideAnimation.restart();
        }
    }

    Item {
        id: contentHost

        width: root.contentWidth
        height: root.contentHeight
        x: -root.slideOffset
        opacity: 0
        scale: 0.985
        transformOrigin: Item.Left

        HoverHandler {
            onHoveredChanged: hovered ? root.hoverEntered() : root.hoverExited()
        }

    }

    HyprlandFocusGrab {
        active: root.visible && root.keyboardFocus
        windows: [root]
        onCleared: root.keyboardFocus = false
    }

    ParallelAnimation {
        id: showAnimation

        NumberAnimation {
            target: contentHost
            property: "opacity"
            from: contentHost.opacity
            to: 1
            duration: 140
            easing.type: Easing.OutCubic
        }

        NumberAnimation {
            target: contentHost
            property: "x"
            from: contentHost.x
            to: 0
            duration: 160
            easing.type: Easing.OutCubic
        }

        NumberAnimation {
            target: contentHost
            property: "scale"
            from: contentHost.scale
            to: 1
            duration: 160
            easing.type: Easing.OutCubic
        }

    }

    ParallelAnimation {
        id: hideAnimation

        onFinished: {
            if (!root.open)
                root.rendered = false;

        }

        NumberAnimation {
            target: contentHost
            property: "opacity"
            from: contentHost.opacity
            to: 0
            duration: 110
            easing.type: Easing.InCubic
        }

        NumberAnimation {
            target: contentHost
            property: "x"
            from: contentHost.x
            to: -root.slideOffset
            duration: 130
            easing.type: Easing.InCubic
        }

        NumberAnimation {
            target: contentHost
            property: "scale"
            from: contentHost.scale
            to: 0.985
            duration: 130
            easing.type: Easing.InCubic
        }

    }

}
