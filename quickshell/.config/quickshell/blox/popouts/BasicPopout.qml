import "../shared"
import QtQuick

Rectangle {
    id: root

    property string title: ""
    property string subtitle: ""
    property string body: ""
    property var actions: []
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
        implicitHeight: headerRow.height + bodyText.implicitHeight + actionFlow.implicitHeight + 20

        Item {
            id: headerRow

            width: parent.width
            anchors.top: parent.top
            height: Math.max(22, titleBlock.implicitHeight)

            Text {
                id: titleIcon

                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                text: root.title === "Updates" ? "󰧠" : "󰍹"
                color: Theme.blue
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
                    font.family: Theme.fontFamily
                    font.pixelSize: 14
                    font.bold: true
                    elide: Text.ElideRight
                }

                Text {
                    width: parent.width
                    visible: root.subtitle.length > 0
                    text: root.subtitle
                    color: Theme.muted
                    font.family: Theme.fontFamily
                    font.pixelSize: 10
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
            font.family: Theme.fontFamily
            font.pixelSize: 12
            wrapMode: Text.Wrap
        }

        Flow {
            id: actionFlow

            anchors.left: parent.left
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            width: parent.width
            spacing: 8

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
                            font.family: Theme.fontFamily
                            font.pixelSize: 11
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

    }

}
