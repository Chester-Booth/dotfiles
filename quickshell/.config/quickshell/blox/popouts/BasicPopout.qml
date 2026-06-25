import "../shared"
import QtQuick

Rectangle {
    id: root

    property string title: ""
    property string subtitle: ""
    property string body: ""
    property var actions: []
    property string currentId: ""
    property string headerActionIcon: ""
    property string headerActionCommand: ""

    signal action(string command, bool keepOpen)

    width: 340
    height: Math.min(520, Math.max(140, content.implicitHeight + 28))
    radius: 8
    color: Theme.background
    border.color: Theme.surfaceAlt
    border.width: 1

    Item {
        id: content

        anchors.fill: parent
        anchors.margins: 12
        implicitHeight: headerRow.height + bodyText.implicitHeight + (root.title === "Awake" ? awakeSlider.height : actionFlow.implicitHeight) + 20

        Item {
            id: headerRow

            width: parent.width
            anchors.top: parent.top
            height: Math.max(22, titleBlock.implicitHeight)

            Text {
                id: titleIcon

                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                text: root.title === "Updates" ? "󰧠" : root.title === "Awake" ? "󰅶" : "󰍹"
                color: root.title === "Awake" ? Theme.yellow : Theme.blue
                font.family: Theme.fontFamily
                font.pixelSize: 18
            }

            Column {
                id: titleBlock

                anchors.left: titleIcon.right
                anchors.leftMargin: 8
                anchors.right: headerAction.left
                anchors.rightMargin: headerAction.visible ? 8 : 0
                anchors.verticalCenter: parent.verticalCenter
                spacing: 1

                Text {
                    width: parent.width
                    text: root.title
                    color: Theme.foreground
                    font.family: Theme.bodyFontFamily
                    font.pixelSize: 16
                    font.bold: true
                    elide: Text.ElideRight
                }

                Text {
                    width: parent.width
                    visible: root.subtitle.length > 0
                    text: root.subtitle
                    color: Theme.muted
                    font.family: Theme.bodyFontFamily
                    font.pixelSize: 11
                    elide: Text.ElideRight
                }
            }

            Rectangle {
                id: headerAction

                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                visible: root.headerActionCommand.length > 0
                width: 28
                height: 28
                radius: 6
                color: headerActionMouse.containsMouse ? Theme.surfaceAlt : Theme.surface
                border.color: Theme.surfaceAlt
                border.width: 1

                Text {
                    anchors.centerIn: parent
                    text: root.headerActionIcon
                    color: Theme.foreground
                    font.family: Theme.fontFamily
                    font.pixelSize: 14
                }

                MouseArea {
                    id: headerActionMouse

                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.action(root.headerActionCommand, true)
                }
            }

        }

        Text {
            id: bodyText

            anchors.top: headerRow.bottom
            anchors.topMargin: 8
            width: parent.width
            text: root.body
            color: Theme.foreground
            font.family: Theme.bodyFontFamily
            font.pixelSize: 13
            wrapMode: Text.Wrap
        }

        Flow {
            id: actionFlow

            anchors.left: parent.left
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            width: parent.width
            spacing: 8
            visible: root.title !== "Awake"

            Repeater {
                model: root.actions

                Rectangle {
                    width: root.title === "Updates" ? Math.floor((parent.width - 8) / 2) : Math.max(96, actionContent.implicitWidth + 22)
                    height: 34
                    radius: 7
                    color: actionMouse.containsMouse ? Theme.surfaceAlt : Theme.surface
                    border.color: modelData.danger ? Theme.red : Theme.surfaceAlt
                    border.width: 1

                    Row {
                        id: actionContent

                        anchors.centerIn: parent
                        spacing: 7

                        Text {
                            visible: !!modelData.icon
                            text: modelData.icon || ""
                            color: modelData.danger ? Theme.red : Theme.foreground
                            font.family: Theme.fontFamily
                            font.pixelSize: 13
                        }

                        Text {
                            id: actionLabel

                            text: modelData.label || ""
                            color: modelData.danger ? Theme.red : Theme.foreground
                            font.family: Theme.bodyFontFamily
                            font.pixelSize: 12
                            font.bold: true
                        }
                    }

                    MouseArea {
                        id: actionMouse

                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            const label = (modelData.label || "").toLowerCase();
                            const keepOpen = !!modelData.keepOpen || label.indexOf("cycle") >= 0 || label.indexOf(" up") >= 0 || label.indexOf(" down") >= 0;
                            root.action(modelData.command || "", keepOpen);
                        }
                    }

                }

            }

        }

        AwakeSlider {
            id: awakeSlider

            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: bodyText.bottom
            anchors.topMargin: 10
            visible: root.title === "Awake"
            currentId: root.currentId || "off"
            options: root.actions
            onSelected: (command) => root.action(command, true)
        }

    }

    component AwakeSlider: Column {
        id: slider

        property string currentId: "off"
        property var options: []
        property string visualId: currentId
        property int selectedIndex: {
            for (let i = 0; i < options.length; i++) {
                if ((options[i].id || "") === visualId)
                    return i;

            }
            return 0;
        }

        signal selected(string command)

        spacing: 4
        height: visible ? labelRow.height + control.height + spacing : 0
        onCurrentIdChanged: visualId = currentId

        Row {
            id: labelRow

            width: parent.width
            height: 12

            Text {
                anchors.left: parent.left
                text: "Duration"
                color: Theme.muted
                font.family: Theme.bodyFontFamily
                font.pixelSize: 11
            }

            Text {
                anchors.right: parent.right
                text: {
                    for (let i = 0; i < slider.options.length; i++) {
                        if ((slider.options[i].id || "") === slider.visualId)
                            return slider.options[i].label || "";

                    }
                    return "";
                }
                color: Theme.foreground
                font.family: Theme.bodyFontFamily
                font.pixelSize: 10
            }

        }

        Rectangle {
            id: control

            width: parent.width
            height: 32
            radius: 16
            color: Theme.surface
            border.color: Theme.surfaceAlt
            border.width: 1
            clip: true

            Rectangle {
                x: 3 + slider.selectedIndex * ((parent.width - 6) / Math.max(1, slider.options.length))
                y: 3
                width: (parent.width - 6) / Math.max(1, slider.options.length)
                height: parent.height - 6
                radius: 13
                color: "#66453d3d"

                Behavior on x {
                    NumberAnimation {
                        duration: 150
                        easing.type: Easing.OutCubic
                    }

                }

            }

            Row {
                anchors.fill: parent
                anchors.margins: 3

                Repeater {
                    model: slider.options

                    Rectangle {
                        width: (control.width - 6) / Math.max(1, slider.options.length)
                        height: parent.height
                        radius: 13
                        color: optionMouse.containsMouse ? "#333b3c4a" : "transparent"

                        Text {
                            anchors.centerIn: parent
                            text: modelData.icon || ""
                            color: (modelData.id || "") === slider.visualId ? Theme.yellow : Theme.foreground
                            font.family: Theme.fontFamily
                            font.pixelSize: 14
                        }

                        MouseArea {
                            id: optionMouse

                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                slider.visualId = modelData.id || "";
                                slider.selected(modelData.command || "");
                            }
                        }

                    }

                }

            }

        }

    }

}
