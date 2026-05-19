import "."
import QtQuick

Item {
    id: root

    default property alias content: contentColumn.data
    property bool open: false
    property real topLimit: 0
    property real bottomLimit: 0
    property real push: 0
    readonly property real targetHeight: open ? Math.min(contentColumn.implicitHeight, Math.max(Theme.buttonSize, bottomLimit - topLimit)) : 0
    readonly property real columnY: height - contentColumn.implicitHeight - extrasScroll.offset

    signal hoverEntered()
    signal hoverExited()

    function popupCenterY(localCenterY) {
        return y + columnY + localCenterY;
    }

    function updatePush() {
        if (!open)
            return ;

        const naturalGap = bottomLimit - topLimit - push / 2;
        const nextPush = Math.max(0, 2 * (contentColumn.implicitHeight - naturalGap));
        if (Math.abs(push - nextPush) > 0.5)
            push = nextPush;

        extrasScroll.offset = extrasScroll.maxOffset;
    }

    x: Math.round((parent.width - width) / 2)
    y: bottomLimit - targetHeight
    z: 10
    width: Theme.buttonSize
    height: targetHeight
    visible: open || height > 1
    clip: true
    onVisibleChanged: {
        if (visible) {
            Qt.callLater(updatePush);
        } else {
            push = 0;
            extrasScroll.offset = 0;
        }
    }
    onTopLimitChanged: Qt.callLater(updatePush)
    onBottomLimitChanged: Qt.callLater(updatePush)

    MouseArea {
        id: extrasScroll

        property real offset: 0
        property real maxOffset: Math.max(0, contentColumn.implicitHeight - parent.height)

        anchors.fill: parent
        acceptedButtons: Qt.NoButton
        hoverEnabled: true
        onEntered: root.hoverEntered()
        onExited: root.hoverExited()
        onMaxOffsetChanged: {
            offset = Math.min(offset, maxOffset);
            if (root.open)
                Qt.callLater(root.updatePush);

        }
        onWheel: (event) => {
            offset = Math.max(0, Math.min(maxOffset, offset - event.angleDelta.y / 4));
        }
    }

    Column {
        id: contentColumn

        width: parent.width
        y: root.columnY
        opacity: root.open ? 1 : 0
        onImplicitHeightChanged: Qt.callLater(root.updatePush)

        Behavior on opacity {
            NumberAnimation {
                duration: 120
            }

        }
    }

    Behavior on height {
        NumberAnimation {
            duration: 160
            easing.type: Easing.OutCubic
        }

    }

    Behavior on y {
        NumberAnimation {
            duration: 160
            easing.type: Easing.OutCubic
        }

    }
}
