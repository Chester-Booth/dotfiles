import "../shared"
import QtQuick
import QtQuick.Controls
import Quickshell

FloatingWindow {
    id: root

    required property EmojiController controller
    required property bool positionReady
    property bool open: false
    property var targetScreen
    property bool suppressEmojiActivation: false
    readonly property var categoryIcons: ["magnifying-glass", "clock-counter-clockwise", "smiley", "person-simple", "paw-print", "hamburger", "soccer-ball", "airplane", "lamp", "flag", "shapes"]
    readonly property var toneColours: ["#ffdc5d", "#f5d8c7", "#f3d2a2", "#d3a784", "#af7e57", "#7c533e"]

    screen: targetScreen
    visible: open
    title: "Blox Emoji Picker"
    implicitWidth: LauncherState.emojiWidth
    implicitHeight: LauncherState.emojiHeight
    minimumSize: Qt.size(327, 260)
    color: "transparent"
    onWidthChanged: {
        if (visible && width >= minimumSize.width)
            LauncherState.emojiWidth = width;

    }
    onHeightChanged: {
        if (visible && height >= minimumSize.height)
            LauncherState.emojiHeight = height;

    }
    onOpenChanged: {
        if (open) {
            Qt.callLater(() => {
                return emojiGrid.positionViewAtBeginning();
            });
            if (controller.category === "Search")
                focusTimer.restart();
            else
                Qt.callLater(() => {
                return emojiGrid.forceActiveFocus();
            });
        }
    }

    Shortcut {
        sequence: "Escape"
        onActivated: controller.closeRequested()
    }

    Connections {
        function onItemsChanged() {
            emojiGrid.positionViewAtBeginning();
        }

        target: controller
    }

    Rectangle {
        id: card

        anchors.fill: parent
        anchors.margins: 1
        radius: 12
        color: Theme.surface
        border.color: Theme.border
        clip: true
        opacity: root.positionReady ? 1 : 0

        MouseArea {
            anchors.fill: parent
        }

        MouseArea {
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            height: 9
            z: 99
            cursorShape: Qt.SizeAllCursor
            onPressed: root.contentItem.QsWindow.window.startSystemMove()
        }

        Row {
            anchors.fill: parent
            anchors.margins: 10
            spacing: 8

            Item {
                width: 44
                height: parent.height

                ListView {
                    id: categoryList

                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.top: parent.top
                    anchors.bottom: categoryToneSeparator.top
                    anchors.bottomMargin: 5
                    model: controller.categories
                    spacing: 5
                    clip: true
                    boundsBehavior: Flickable.StopAtBounds

                    WheelHandler {
                        acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
                        onWheel: (event) => {
                            const delta = event.pixelDelta.y || event.angleDelta.y / 2;
                            categoryList.contentY = Math.max(categoryList.originY, Math.min(categoryList.originY + categoryList.contentHeight - categoryList.height, categoryList.contentY - delta * 4));
                            event.accepted = true;
                        }
                    }

                    delegate: Rectangle {
                        id: categoryButton

                        required property string modelData
                        required property int index

                        width: 40
                        height: 40
                        radius: 8
                        color: controller.category === modelData ? Theme.surfaceAlt : categoryHover.hovered ? Theme.withAlpha(Theme.foreground, 0.1) : "transparent"
                        border.width: controller.category === modelData || categoryHover.hovered ? 1 : 0
                        border.color: controller.category === modelData ? Theme.accent : Theme.withAlpha(Theme.foreground, 0.4)

                        PhosphorIcon {
                            anchors.centerIn: parent
                            width: 20
                            height: 20
                            iconName: root.categoryIcons[index]
                            opacity: controller.category === modelData ? 1 : 0.62
                        }

                        BloxToolTip {
                            shown: categoryHover.hovered
                            text: modelData
                        }

                        HoverHandler {
                            id: categoryHover

                            cursorShape: Qt.PointingHandCursor
                        }

                        TapHandler {
                            onTapped: {
                                controller.category = modelData;
                                if (modelData === "Search")
                                    search.focusEditor(false);
                                else
                                    emojiGrid.forceActiveFocus();
                            }
                        }

                    }

                }

                Rectangle {
                    id: categoryToneSeparator

                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.bottom: toneButton.top
                    anchors.bottomMargin: 5
                    height: 1
                    color: Theme.border
                }

                Rectangle {
                    id: toneButton

                    anchors.left: parent.left
                    anchors.bottom: parent.bottom
                    width: 40
                    height: 40
                    radius: 8
                    color: toneHover.hovered ? Theme.surfaceAlt : "transparent"

                    Rectangle {
                        anchors.centerIn: parent
                        width: 20
                        height: 20
                        radius: 10
                        color: root.toneColours[LauncherState.emojiTone]
                        border.color: Theme.border
                    }

                    BloxToolTip {
                        shown: toneHover.hovered && !toneMenu.opened
                        text: "Skin tone"
                    }

                    HoverHandler {
                        id: toneHover

                        cursorShape: Qt.PointingHandCursor
                    }

                    TapHandler {
                        onTapped: toneMenu.opened ? toneMenu.close() : toneMenu.open()
                    }

                    Popup {
                        id: toneMenu

                        parent: toneButton
                        popupType: Popup.Item
                        modal: true
                        dim: false
                        x: toneButton.width + 6
                        y: (toneButton.height - height) / 2
                        width: toneRow.implicitWidth + 12
                        height: 46
                        padding: 6
                        closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutside

                        contentItem: Row {
                            id: toneRow

                            spacing: 5

                            Repeater {
                                model: root.toneColours

                                Rectangle {
                                    id: toneChoice

                                    required property color modelData
                                    required property int index

                                    width: 30
                                    height: 30
                                    radius: 15
                                    color: modelData
                                    border.width: LauncherState.emojiTone === index || toneChoiceHover.hovered ? 3 : 1
                                    border.color: LauncherState.emojiTone === index || toneChoiceHover.hovered ? Theme.accent : Theme.border

                                    MouseArea {
                                        anchors.fill: parent
                                        cursorShape: Qt.PointingHandCursor
                                        onPressed: (mouse) => {
                                            return mouse.accepted = true;
                                        }
                                        onClicked: (mouse) => {
                                            mouse.accepted = true;
                                            root.suppressEmojiActivation = true;
                                            LauncherState.emojiTone = index;
                                            toneMenu.close();
                                            toneGuard.restart();
                                        }
                                    }

                                    HoverHandler {
                                        id: toneChoiceHover

                                        cursorShape: Qt.PointingHandCursor
                                    }

                                }

                            }

                        }

                        background: Rectangle {
                            radius: 9
                            color: Theme.surfaceAlt
                            border.color: Theme.border
                        }

                    }

                }

            }

            Rectangle {
                width: 1
                height: parent.height
                color: Theme.border
            }

            Column {
                width: parent.width - 61
                height: parent.height
                spacing: 8

                BloxTextField {
                    id: search

                    width: parent.width
                    visible: controller.category === "Search"
                    height: visible ? implicitHeight : 0
                    placeholderText: "Search emoji"
                    text: controller.query
                    onTextEdited: (value) => {
                        return controller.query = value;
                    }
                    onAccepted: controller.activate()
                    Keys.onEscapePressed: controller.closeRequested()
                }

                GridView {
                    id: emojiGrid

                    width: parent.width
                    height: parent.height - (search.visible ? search.height + 8 : 0)
                    rightMargin: emojiScrollbar.policy === ScrollBar.AlwaysOn ? 12 : 0
                    cellWidth: 58
                    cellHeight: 54
                    clip: true
                    model: controller.items
                    currentIndex: controller.selectedIndex
                    activeFocusOnTab: true
                    Keys.onPressed: (event) => {
                        const columns = Math.max(1, Math.floor(width / cellWidth));
                        let delta = 0;
                        if (event.key === Qt.Key_Left) {
                            delta = -1;
                        } else if (event.key === Qt.Key_Right) {
                            delta = 1;
                        } else if (event.key === Qt.Key_Up) {
                            delta = -columns;
                        } else if (event.key === Qt.Key_Down) {
                            delta = columns;
                        } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter || event.key === Qt.Key_Space) {
                            controller.activate();
                            event.accepted = true;
                            return ;
                        } else if (event.key === Qt.Key_Escape) {
                            controller.closeRequested();
                            event.accepted = true;
                            return ;
                        }
                        if (delta !== 0 && controller.items.length) {
                            controller.selectedIndex = Math.max(0, Math.min(controller.items.length - 1, controller.selectedIndex + delta));
                            positionViewAtIndex(controller.selectedIndex, GridView.Contain);
                            event.accepted = true;
                        }
                    }

                    WheelHandler {
                        acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
                        onWheel: (event) => {
                            const delta = event.pixelDelta.y || event.angleDelta.y / 2;
                            emojiGrid.contentY = Math.max(emojiGrid.originY, Math.min(emojiGrid.originY + emojiGrid.contentHeight - emojiGrid.height, emojiGrid.contentY - delta * 4));
                            event.accepted = true;
                        }
                    }

                    ScrollBar.vertical: ScrollBar {
                        id: emojiScrollbar

                        width: 8
                        policy: emojiGrid.contentHeight > emojiGrid.height ? ScrollBar.AlwaysOn : ScrollBar.AlwaysOff

                        background: Rectangle {
                            radius: 999
                            color: Theme.withAlpha(Theme.foreground, 0.04)
                        }

                        contentItem: Rectangle {
                            implicitWidth: 4
                            radius: 999
                            color: emojiScrollbar.hovered ? Theme.foreground : Theme.surfaceAlt
                        }

                    }

                    delegate: Rectangle {
                        id: emojiCell

                        required property var modelData
                        required property int index

                        width: 48
                        height: 48
                        radius: 8
                        color: index === controller.selectedIndex ? Theme.surfaceAlt : emojiHover.hovered ? Theme.withAlpha(Theme.foreground, 0.07) : "transparent"

                        Text {
                            anchors.centerIn: parent
                            text: modelData.value
                            color: Theme.foreground
                            // Qt Quick cannot render Twemoji's SVG glyphs here.
                            // Noto's bitmap colour glyphs cover full Emoji sequences.
                            font.family: "Noto Color Emoji"
                            font.pixelSize: 25
                        }

                        PhosphorIcon {
                            anchors.right: parent.right
                            anchors.rightMargin: 3
                            anchors.top: parent.top
                            anchors.topMargin: 3
                            width: 12
                            height: 12
                            visible: modelData.pinned
                            iconName: "push-pin"
                            iconColor: Theme.foreground
                        }

                        BloxToolTip {
                            shown: emojiHover.hovered
                            text: modelData.name + (modelData.pinned ? " · Pinned" : " · Right-click to pin")
                        }

                        HoverHandler {
                            id: emojiHover

                            cursorShape: Qt.PointingHandCursor
                        }

                        TapHandler {
                            enabled: !root.suppressEmojiActivation && !toneMenu.opened
                            onTapped: {
                                controller.selectedIndex = index;
                                controller.activate();
                            }
                        }

                        TapHandler {
                            acceptedButtons: Qt.RightButton
                            onTapped: {
                                controller.selectedIndex = index;
                                emojiMenu.open();
                            }
                        }

                        Popup {
                            id: emojiMenu

                            readonly property point anchorPosition: emojiCell.mapToItem(root.contentItem, emojiCell.width, emojiCell.height)

                            parent: root.contentItem
                            popupType: Popup.Item
                            modal: true
                            dim: false
                            x: Math.max(6, Math.min(root.width - width - 6, anchorPosition.x - width))
                            y: anchorPosition.y + height <= root.height - 6 ? anchorPosition.y : Math.max(6, anchorPosition.y - emojiCell.height - height)
                            width: 132
                            padding: 4
                            closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutside

                            contentItem: BloxButton {
                                text: modelData.pinned ? "Unpin" : "Pin"
                                onClicked: {
                                    controller.togglePin(index);
                                    emojiMenu.close();
                                }

                                PhosphorIcon {
                                    anchors.left: parent.left
                                    anchors.leftMargin: 9
                                    anchors.verticalCenter: parent.verticalCenter
                                    width: 15
                                    height: 15
                                    iconName: "push-pin"
                                    iconColor: Theme.foreground
                                }

                            }

                            background: Rectangle {
                                radius: 9
                                color: Theme.surfaceAlt
                                border.color: Theme.border
                            }

                        }

                    }

                }

            }

        }

        MouseArea {
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.bottom: parent.bottom
            width: 7
            z: 100
            cursorShape: Qt.SizeHorCursor
            onPressed: root.contentItem.QsWindow.window.startSystemResize(Qt.RightEdge)
        }

        MouseArea {
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            height: 7
            z: 101
            cursorShape: Qt.SizeVerCursor
            onPressed: root.contentItem.QsWindow.window.startSystemResize(Qt.BottomEdge)
        }

        MouseArea {
            anchors.left: parent.left
            anchors.top: parent.top
            anchors.bottom: parent.bottom
            width: 7
            z: 102
            cursorShape: Qt.SizeHorCursor
            onPressed: root.contentItem.QsWindow.window.startSystemResize(Qt.LeftEdge)
        }

        MouseArea {
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            height: 7
            z: 103
            cursorShape: Qt.SizeVerCursor
            onPressed: root.contentItem.QsWindow.window.startSystemResize(Qt.TopEdge)
        }

    }

    Timer {
        id: focusTimer

        interval: 30
        onTriggered: search.focusEditor(false)
    }

    Timer {
        id: toneGuard

        interval: 180
        onTriggered: root.suppressEmojiActivation = false
    }

}
