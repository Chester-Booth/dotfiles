import "../shared"
import QtQuick
import QtQuick.Controls
import Quickshell
import Quickshell.Wayland

PanelWindow {
    id: root

    required property LauncherMainController controller
    property bool open: false
    property var targetScreen

    screen: targetScreen
    visible: open
    color: "transparent"
    exclusionMode: ExclusionMode.Ignore
    focusable: true
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: open ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
    WlrLayershell.namespace: "blox-launcher-main"
    onOpenChanged: {
        if (open) {
            controller.refresh();
            focusTimer.restart();
        } else {
            controller.query = "";
        }
    }

    anchors {
        left: true
        right: true
        top: true
        bottom: true
    }

    MouseArea {
        anchors.fill: parent
        onClicked: (mouse) => {
            if (mouse.x < card.x || mouse.x > card.x + card.width || mouse.y < card.y || mouse.y > card.y + card.height)
                controller.closeRequested();

        }
    }

    Timer {
        id: focusTimer

        interval: 30
        repeat: false
        onTriggered: search.forceActiveFocus()
    }

    Rectangle {
        id: card

        width: 770
        height: controller.query.length || (controller.dmenuMode && controller.results.length) ? (controller.dmenuMode && controller.dmenuLimit > 0 ? Math.min(520, 78 + controller.dmenuLimit * 58) : 520) : 62
        x: (root.width - width) / 2
        y: controller.dmenuMode && controller.dmenuBottom ? root.height - height - 20 : (root.height - 520) / 2
        radius: 9
        color: Theme.background
        border.color: Theme.withAlpha(Theme.foreground, 0.2)
        border.width: 1
        clip: true

        MouseArea {
            anchors.fill: parent
        }

        TextInput {
            id: search

            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            height: 61
            leftPadding: 16
            rightPadding: 16
            color: Theme.foreground
            selectionColor: Theme.withAlpha(Theme.blue, 0.5)
            selectedTextColor: Theme.foreground
            font.family: Theme.bodyFontFamily
            font.pixelSize: 16
            verticalAlignment: TextInput.AlignVCenter
            selectByMouse: true
            clip: true
            activeFocusOnTab: true
            text: controller.query
            onTextEdited: controller.query = text
            Keys.onPressed: (event) => {
                if (event.key === Qt.Key_Escape) {
                    controller.closeRequested();
                    event.accepted = true;
                } else if (event.key === Qt.Key_Down) {
                    controller.move(1);
                    event.accepted = true;
                } else if (event.key === Qt.Key_Up) {
                    controller.move(-1);
                    event.accepted = true;
                } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                    controller.activate();
                    event.accepted = true;
                }
            }
        }

        Text {
            anchors.fill: search
            anchors.leftMargin: search.leftPadding
            anchors.rightMargin: search.rightPadding
            visible: search.text.length === 0
            text: controller.dmenuMode && controller.dmenuPrompt.length ? controller.dmenuPrompt : "Search for anything..."
            color: Theme.withAlpha(Theme.foreground, 0.78)
            font: search.font
            verticalAlignment: Text.AlignVCenter
        }

        Rectangle {
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: search.bottom
            height: 1
            color: Theme.withAlpha(Theme.foreground, 0.12)
        }

        ListView {
            id: resultList

            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: controller.calculation.length ? calculator.bottom : search.bottom
            anchors.bottom: parent.bottom
            anchors.margins: 8
            spacing: 3
            clip: true
            model: controller.results
            currentIndex: controller.selectedIndex
            rightMargin: resultScrollbar.policy === ScrollBar.AlwaysOn ? 12 : 0

            WheelHandler {
                acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
                onWheel: (event) => {
                    const delta = event.pixelDelta.y || event.angleDelta.y / 2;
                    resultList.contentY = Math.max(resultList.originY, Math.min(resultList.originY + resultList.contentHeight - resultList.height, resultList.contentY - delta * 4));
                    event.accepted = true;
                }
            }

            ScrollBar.vertical: ScrollBar {
                id: resultScrollbar

                width: 8
                policy: resultList.contentHeight > resultList.height ? ScrollBar.AlwaysOn : ScrollBar.AlwaysOff

                background: Rectangle {
                    radius: 999
                    color: Theme.withAlpha(Theme.foreground, 0.04)
                }

                contentItem: Rectangle {
                    implicitWidth: 4
                    radius: 999
                    color: resultScrollbar.hovered ? Theme.foreground : Theme.surfaceAlt
                }

            }

            delegate: Rectangle {
                id: resultCard

                required property var modelData
                required property int index

                width: ListView.view.width - (resultScrollbar.policy === ScrollBar.AlwaysOn ? 12 : 0)
                height: 55
                radius: 7
                color: (!controller.calculationSelected && index === controller.selectedIndex) || resultHover.hovered ? Theme.surfaceAlt : Theme.surface
                border.width: 1
                border.color: resultHover.hovered ? Theme.withAlpha(Theme.foreground, 0.32) : Theme.border

                Row {
                    anchors.fill: parent
                    anchors.leftMargin: 10
                    anchors.rightMargin: 12
                    spacing: modelData.kind === "dmenu" ? 0 : 12

                    Item {
                        width: modelData.kind === "dmenu" ? 0 : 34
                        height: parent.height

                        Image {
                            anchors.centerIn: parent
                            width: 30
                            height: 30
                            visible: (modelData.kind === "app" || modelData.kind === "command") && modelData.icon.length > 0
                            source: modelData.icon || ""
                            sourceSize.width: 30
                            sourceSize.height: 30
                            fillMode: Image.PreserveAspectFit
                            asynchronous: true
                        }

                        PhosphorIcon {
                            anchors.centerIn: parent
                            width: 22
                            height: 22
                            visible: modelData.kind === "category" || ((modelData.kind === "app" || modelData.kind === "command") && modelData.icon.length === 0)
                            iconName: modelData.kind === "category" ? modelData.iconName : modelData.kind === "command" ? "terminal-window" : "presentation-chart"
                            iconColor: Theme.foreground
                        }

                    }

                    Column {
                        width: modelData.kind === "dmenu" ? parent.width : parent.width - 142
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 2

                        Text {
                            width: parent.width
                            text: modelData.title
                            color: Theme.foreground
                            font.family: Theme.bodyFontFamily
                            font.pixelSize: 14
                            elide: Text.ElideRight
                        }

                        Text {
                            width: parent.width
                            visible: modelData.subtitle.length > 0
                            text: modelData.subtitle
                            color: Theme.muted
                            font.family: Theme.bodyFontFamily
                            font.pixelSize: 11
                            elide: Text.ElideRight
                        }

                    }

                }

                Text {
                    anchors.right: parent.right
                    anchors.rightMargin: 12
                    anchors.verticalCenter: parent.verticalCenter
                    visible: modelData.kind !== "dmenu"
                    text: modelData.kind === "category" ? "Category" : modelData.kind === "command" ? "Command" : "Application"
                    color: Theme.muted
                    font.family: Theme.bodyFontFamily
                    font.pixelSize: 11
                }

                TapHandler {
                    onTapped: {
                        controller.selectedIndex = index;
                        controller.activateResult(index);
                    }
                }

                HoverHandler {
                    id: resultHover

                    cursorShape: Qt.PointingHandCursor
                }

            }

        }

        Column {
            id: calculator

            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: search.bottom
            visible: controller.calculation.length > 0
            height: visible ? 132 : 0
            padding: 8
            spacing: 7

            Text {
                text: "Calculator"
                color: Theme.foreground
                font.family: Theme.bodyFontFamily
                font.pixelSize: 12
            }

            Rectangle {
                id: calculatorCard

                width: parent.width - 16
                height: 88
                radius: 8
                color: controller.calculationSelected || calculatorHover.hovered ? Theme.surfaceAlt : Theme.surface
                border.width: controller.calculationSelected ? 2 : 1
                border.color: controller.calculationSelected ? Theme.accent : calculatorHover.hovered ? Theme.withAlpha(Theme.foreground, 0.32) : Theme.border

                Row {
                    anchors.fill: parent
                    anchors.margins: 16

                    Column {
                        width: (parent.width - arrow.width) / 2
                        anchors.verticalCenter: parent.verticalCenter

                        Text {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: controller.query
                            color: Theme.foreground
                            font.family: Theme.bodyFontFamily
                            font.pixelSize: 20
                        }

                        Text {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: "Question"
                            color: Theme.muted
                            font.family: Theme.bodyFontFamily
                            font.pixelSize: 12
                        }

                    }

                    PhosphorIcon {
                        id: arrow

                        width: 38
                        height: 22
                        anchors.verticalCenter: parent.verticalCenter
                        iconName: "arrow-right"
                        iconColor: Theme.foreground
                    }

                    Column {
                        width: (parent.width - arrow.width) / 2
                        anchors.verticalCenter: parent.verticalCenter

                        Text {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: controller.calculation
                            color: Theme.foreground
                            font.family: Theme.bodyFontFamily
                            font.pixelSize: 20
                            font.bold: true
                        }

                        Text {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: "Answer"
                            color: Theme.muted
                            font.family: Theme.bodyFontFamily
                            font.pixelSize: 12
                        }

                    }

                }

                TapHandler {
                    onTapped: {
                        controller.calculationSelected = true;
                        controller.activateCalculation();
                    }
                }

                HoverHandler {
                    id: calculatorHover

                    cursorShape: Qt.PointingHandCursor
                }

            }

        }

    }

}
