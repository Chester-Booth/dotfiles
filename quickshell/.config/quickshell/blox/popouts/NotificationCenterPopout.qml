import "../shared"
import QtQuick
import QtQuick.Controls
import Quickshell.Services.Notifications

Rectangle {
    id: root

    property var notifications: []
    property real maxPopoutHeight: 720
    property bool dnd: false
    property int clearAnimationRevision: 0
    property double nowMs: Date.now()
    readonly property int notificationListChromeHeight: 240

    signal clearAll()
    signal toggleDnd()
    signal activate(var notification)

    function orderedNotifications() {
        const items = root.notifications ? root.notifications.slice() : [];
        return items.reverse();
    }

    function receivedAt(notification) {
        return notification && notification.bloxReceivedAt ? notification.bloxReceivedAt : root.nowMs;
    }

    function ageText(notification) {
        const elapsed = Math.max(0, root.nowMs - root.receivedAt(notification));
        const seconds = Math.floor(elapsed / 1000);
        if (seconds < 45)
            return "now";

        const minutes = Math.floor(seconds / 60);
        if (minutes < 60)
            return minutes + "m ago";

        const hours = Math.floor(minutes / 60);
        if (hours < 24)
            return hours + "h ago";

        const days = Math.floor(hours / 24);
        return days + "d ago";
    }

    function notificationMeta(notification) {
        const app = notification && notification.appName ? notification.appName : "notification";
        return app + " • " + root.ageText(notification);
    }

    function notificationIcon(notification) {
        if (!notification)
            return "󰂜";

        if (notification.urgency === NotificationUrgency.Critical)
            return "";

        return "󰂚";
    }

    function notificationAccent(notification) {
        if (!notification)
            return Theme.blue;

        if (notification.urgency === NotificationUrgency.Critical)
            return Theme.red;

        if (notification.urgency === NotificationUrgency.Low)
            return Theme.muted;

        return Theme.blue;
    }

    function plainText(text) {
        return String(text || "").replace(/<[^>]*>/g, "");
    }

    width: 360
    height: Math.min(root.maxPopoutHeight, Math.max(220, content.implicitHeight + 26))
    radius: 8
    color: Theme.background
    border.color: Theme.surfaceAlt
    border.width: 1

    Timer {
        interval: 30000
        running: true
        repeat: true
        onTriggered: root.nowMs = Date.now()
    }

    Column {
        id: content

        anchors.fill: parent
        anchors.margins: 12
        spacing: 10

        Row {
            width: parent.width
            height: 34
            spacing: 8

            Item {
                width: 22
                height: parent.height

                Text {
                    anchors.centerIn: parent
                    text: root.dnd ? "󰂛" : "󰂚"
                    color: root.dnd ? Theme.yellow : Theme.blue
                    font.family: Theme.fontFamily
                    font.pixelSize: 18
                }
            }

            Column {
                width: parent.width - clearButton.width - dndSwitch.width - 46
                anchors.verticalCenter: parent.verticalCenter
                spacing: 1

                Text {
                    width: parent.width
                    text: "Notifications"
                    color: Theme.foreground
                    font.family: Theme.bodyFontFamily
                    font.pixelSize: 16
                    font.bold: true
                    elide: Text.ElideRight
                }

                Text {
                    width: parent.width
                    text: root.notifications.length === 1 ? "1 notification" : root.notifications.length + " notifications"
                    color: Theme.muted
                    font.family: Theme.bodyFontFamily
                    font.pixelSize: 11
                    elide: Text.ElideRight
                }
            }

            Rectangle {
                id: dndSwitch

                width: 112
                height: 32
                radius: 999
                color: Theme.surface
                border.color: Theme.surfaceAlt
                border.width: 1

                Rectangle {
                    width: 53
                    height: 26
                    radius: 13
                    x: root.dnd ? parent.width - width - 3 : 3
                    anchors.verticalCenter: parent.verticalCenter
                    color: "#66453d3d"

                    Behavior on x {
                        NumberAnimation {
                            duration: 120
                            easing.type: Easing.OutCubic
                        }
                    }
                }

                Item {
                    anchors.left: parent.left
                    anchors.top: parent.top
                    anchors.bottom: parent.bottom
                    width: parent.width / 2

                    Text {
                        anchors.centerIn: parent
                        text: "󰂜"
                        color: root.dnd ? Theme.foreground : Theme.yellow
                        font.family: Theme.fontFamily
                        font.pixelSize: 12
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                    }
                }

                Item {
                    anchors.right: parent.right
                    anchors.top: parent.top
                    anchors.bottom: parent.bottom
                    width: parent.width / 2

                    Text {
                        anchors.centerIn: parent
                        text: "󰂛"
                        color: root.dnd ? Theme.yellow : Theme.foreground
                        font.family: Theme.fontFamily
                        font.pixelSize: 12
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                    }
                }

                MouseArea {
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.toggleDnd()
                }
            }

            Rectangle {
                id: clearButton

                width: 30
                height: 30
                radius: 7
                color: clearMouse.containsMouse ? Theme.surfaceAlt : Theme.surface
                border.color: Theme.surfaceAlt
                border.width: 1
                opacity: root.notifications.length > 0 ? 1 : 0.45

                Text {
                    anchors.fill: parent
                    text: "󰆴"
                    color: Theme.foreground
                    font.family: Theme.fontFamily
                    font.pixelSize: 14
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                }

                MouseArea {
                    id: clearMouse

                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: root.notifications.length > 0 ? Qt.PointingHandCursor : Qt.ArrowCursor
                    onClicked: {
                        if (root.notifications.length > 0)
                            root.clearAnimationRevision++;
                    }
                }
            }
        }

        Rectangle {
            width: parent.width
            height: 1
            color: Qt.rgba(1, 1, 1, 0.08)
        }

        Flickable {
            id: notificationList

            property bool needsScrollbar: contentHeight > height
            property int scrollbarGutter: needsScrollbar ? 16 : 0
            property int bottomScrollPadding: needsScrollbar ? 32 : 0

            width: parent.width
            height: Math.min(Math.max(120, root.maxPopoutHeight - root.notificationListChromeHeight), Math.max(90, listContent.implicitHeight))
            contentWidth: width
            contentHeight: listContent.implicitHeight + bottomScrollPadding
            clip: true
            boundsBehavior: Flickable.StopAtBounds
            ScrollBar.vertical: ScrollBar {
                id: notificationScrollbar

                width: 8
                policy: notificationList.needsScrollbar ? ScrollBar.AlwaysOn : ScrollBar.AlwaysOff
                interactive: true

                background: Rectangle {
                    implicitWidth: 8
                    radius: 999
                    color: notificationScrollbar.hovered || notificationScrollbar.pressed ? Qt.rgba(1, 1, 1, 0.09) : Qt.rgba(1, 1, 1, 0.04)
                }

                contentItem: Rectangle {
                    implicitWidth: 4
                    radius: 999
                    color: notificationScrollbar.pressed ? Theme.blue : notificationScrollbar.hovered ? Theme.foreground : Theme.surfaceAlt

                    Behavior on color {
                        ColorAnimation {
                            duration: 110
                            easing.type: Easing.OutCubic
                        }
                    }
                }
            }

            Column {
                id: listContent

                width: notificationList.width - notificationList.scrollbarGutter
                spacing: 8

                Text {
                    width: parent.width
                    visible: root.notifications.length === 0
                    text: "No notifications"
                    color: Theme.muted
                    font.family: Theme.bodyFontFamily
                    font.pixelSize: 13
                    horizontalAlignment: Text.AlignHCenter
                    topPadding: 22
                    bottomPadding: 22
                }

                Repeater {
                    model: root.orderedNotifications()

                    NotificationCard {
                        width: parent.width
                        notification: modelData
                        clearRevision: root.clearAnimationRevision
                    }
                }
            }
        }
    }


    component NotificationCard: Rectangle {
        id: card

        property var notification
        property int clearRevision: 0
        property int seenClearRevision: 0
        property bool removing: false
        readonly property bool hasActions: notification && notification.actions && notification.actions.length > 0
        readonly property bool hasImage: notification && notification.image && notification.image.length > 0

        height: bodyColumn.implicitHeight + 18
        x: removing ? width * 0.18 : 0
        scale: removing ? 0.985 : 1
        opacity: removing ? 0 : 1
        transformOrigin: Item.Right
        radius: 8
        color: Theme.surface
        border.color: notification && notification.urgency === NotificationUrgency.Critical ? Theme.red : Theme.surfaceAlt
        border.width: 1

        function startRemove() {
            if (removing)
                return ;

            removing = true;
            removeTimer.restart();
        }

        onClearRevisionChanged: {
            if (clearRevision === seenClearRevision)
                return ;

            seenClearRevision = clearRevision;
            startRemove();
        }

        Component.onCompleted: seenClearRevision = clearRevision

        Behavior on opacity {
            NumberAnimation {
                duration: 150
                easing.type: Easing.OutCubic
            }
        }

        Behavior on x {
            NumberAnimation {
                duration: 150
                easing.type: Easing.OutCubic
            }
        }

        Behavior on scale {
            NumberAnimation {
                duration: 150
                easing.type: Easing.OutCubic
            }
        }

        Timer {
            id: removeTimer

            interval: 150
            repeat: false
            onTriggered: {
                if (card.notification)
                    card.notification.dismiss();
            }
        }

        MouseArea {
            anchors.fill: parent
            z: 0
            acceptedButtons: Qt.LeftButton
            onClicked: root.activate(card.notification)
        }

        Row {
            z: 1
            anchors.fill: parent
            anchors.margins: 9

            Column {
                id: bodyColumn

                width: parent.width
                spacing: 6

                Row {
                    width: parent.width
                    spacing: 8

                    Column {
                        width: parent.width - closeButton.width - 8
                        spacing: 1

                        Text {
                            width: parent.width
                            text: card.notification ? card.notification.summary : ""
                            color: Theme.foreground
                            font.family: Theme.bodyFontFamily
                            font.pixelSize: 13
                            font.bold: true
                            elide: Text.ElideRight
                        }

                        Text {
                            width: parent.width
                            visible: true
                            text: root.notificationMeta(card.notification)
                            color: Theme.muted
                            font.family: Theme.bodyFontFamily
                            font.pixelSize: 10
                            elide: Text.ElideRight
                        }
                    }

                    Rectangle {
                        id: closeButton

                        width: 24
                        height: 24
                        radius: 6
                        color: closeMouse.containsMouse ? Theme.surfaceAlt : "transparent"

                        Text {
                            anchors.centerIn: parent
                            text: "󰅖"
                            color: Theme.muted
                            font.family: Theme.fontFamily
                            font.pixelSize: 12
                        }

                        MouseArea {
                            id: closeMouse

                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                if (card.notification)
                                    card.startRemove();
                            }
                        }
                    }
                }

                Text {
                    width: parent.width
                    visible: card.notification && card.notification.body.length > 0
                    text: root.plainText(card.notification ? card.notification.body : "")
                    color: Theme.foreground
                    opacity: 0.86
                    font.family: Theme.bodyFontFamily
                    font.pixelSize: 12
                    wrapMode: Text.Wrap
                    maximumLineCount: 4
                    elide: Text.ElideRight
                }

                Image {
                    width: parent.width
                    height: visible ? Math.min(150, Math.round(parent.width * 0.52)) : 0
                    visible: card.hasImage
                    source: card.notification ? card.notification.image : ""
                    fillMode: Image.PreserveAspectCrop
                    clip: true
                }

                Flow {
                    width: parent.width
                    visible: card.hasActions
                    spacing: 6

                    Repeater {
                        model: card.notification && card.notification.actions ? card.notification.actions : []

                        Rectangle {
                            width: Math.max(76, actionLabel.implicitWidth + 20)
                            height: 28
                            radius: 7
                            color: actionMouse.containsMouse ? Theme.surfaceAlt : Theme.background
                            border.color: Theme.surfaceAlt
                            border.width: 1

                            Text {
                                id: actionLabel

                                anchors.centerIn: parent
                                text: modelData.text || ""
                                color: Theme.foreground
                                font.family: Theme.bodyFontFamily
                                font.pixelSize: 11
                                font.bold: true
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
        }
    }
}
