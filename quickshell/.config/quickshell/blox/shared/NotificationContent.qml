import QtQuick
import Quickshell

Column {
    id: root

    property var notification
    property string meta: notification && notification.appName ? notification.appName : ""
    property int maximumBodyLineCount: 4
    property int headerRightPadding: 0
    property var actionItems: []
    readonly property bool hasActions: actionItems.length > 0
    readonly property bool hasImage: notification && notification.image && String(notification.image).length > 0
    readonly property string appIcon: notification && notification.appIcon ? Quickshell.iconPath(notification.appIcon, true) : ""

    function refreshActions() {
        const next = [];
        const actions = notification ? notification.actions : null;
        if (actions) {
            for (let i = 0; i < actions.length; i++) {
                if (String(actions[i].text || "").trim().length > 0)
                    next.push(actions[i]);

            }
        }
        actionItems = next;
    }

    function actionIcon(action) {
        if (!notification || !notification.hasActionIcons || !action || !action.identifier)
            return "";

        return Quickshell.iconPath(action.identifier, true);
    }

    spacing: 6
    onNotificationChanged: refreshActions()
    Component.onCompleted: refreshActions()

    Connections {
        function onActionsChanged() {
            root.refreshActions();
        }

        target: root.notification
        ignoreUnknownSignals: true
    }

    Row {
        id: notificationRow

        width: parent.width
        spacing: notificationThumbnail.visible ? 8 : 0

        Image {
            id: notificationThumbnail

            visible: root.hasImage
            width: visible ? 72 : 0
            height: visible ? 72 : 0
            source: root.notification ? root.notification.image : ""
            sourceSize.width: 144
            sourceSize.height: 144
            fillMode: Image.PreserveAspectFit
            smooth: true
        }

        Column {
            width: parent.width - notificationThumbnail.width - parent.spacing
            spacing: 6

            Row {
                width: parent.width - root.headerRightPadding
                spacing: appIconSlot.visible ? 8 : 0

                Item {
                    id: appIconSlot

                    visible: root.appIcon.length > 0
                    width: visible ? 30 : 0
                    height: 30

                    Image {
                        anchors.fill: parent
                        source: root.appIcon
                        fillMode: Image.PreserveAspectFit
                        smooth: true
                    }

                }

                NotificationHeader {
                    width: parent.width - appIconSlot.width - parent.spacing
                    summary: root.notification ? root.notification.summary : ""
                    meta: root.meta
                }

            }

            NotificationBody {
                width: parent.width
                body: root.notification ? root.notification.body : ""
                opacity: 0.86
                maximumLineCount: root.maximumBodyLineCount
            }

        }

    }

    Flow {
        width: parent.width
        visible: root.hasActions
        spacing: 6

        Repeater {
            model: root.actionItems

            Rectangle {
                readonly property string iconSource: root.actionIcon(modelData)

                width: Math.min(parent.width, Math.max(76, actionRow.implicitWidth + 20))
                height: 28
                radius: 7
                color: actionMouse.containsMouse ? Theme.surfaceAlt : Theme.background
                border.color: Theme.surfaceAlt
                border.width: 1

                Row {
                    id: actionRow

                    anchors.centerIn: parent
                    spacing: actionIcon.visible ? 5 : 0

                    Image {
                        id: actionIcon

                        width: visible ? 14 : 0
                        height: 14
                        visible: parent.parent.iconSource.length > 0
                        source: parent.parent.iconSource
                        fillMode: Image.PreserveAspectFit
                    }

                    Text {
                        id: actionLabel

                        text: modelData.text || ""
                        color: Theme.foreground
                        font.family: Theme.bodyFontFamily
                        font.pixelSize: 11
                        font.bold: true
                    }

                }

                MouseArea {
                    id: actionMouse

                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: modelData.invoke()
                }

            }

        }

    }

}
