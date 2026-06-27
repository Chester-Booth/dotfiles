import "../shared"
import QtQuick
import Quickshell.Services.Notifications

Item {
    id: root

    property var toasts: []
    readonly property int toastWidth: 330
    readonly property int sidePadding: 12
    readonly property int visibleWidth: toastWidth + sidePadding * 2
    readonly property int dismissTravel: toastWidth + sidePadding
    property var animatedToastIds: ({})

    signal dismiss(var notification, bool closeNotification)
    signal activate(var notification)

    function accentFor(notification) {
        if (notification && notification.urgency === NotificationUrgency.Critical)
            return Theme.red;

        return Theme.blue;
    }

    function imageFor(notification) {
        return notification && notification.image ? notification.image : "";
    }

    function takeEntranceAnimation(toastId) {
        if (animatedToastIds[toastId] === true)
            return false;

        animatedToastIds[toastId] = true;
        return true;
    }

    function pruneEntranceHistory() {
        const retained = {};
        const current = toasts || [];
        for (let i = 0; i < current.length; i++) {
            const toastId = current[i].toastId;
            if (animatedToastIds[toastId] === true)
                retained[toastId] = true;

        }
        animatedToastIds = retained;
    }

    width: visibleWidth + dismissTravel
    implicitHeight: toastColumn.implicitHeight
    onToastsChanged: pruneEntranceHistory()

    Column {
        id: toastColumn

        x: root.dismissTravel + root.sidePadding
        width: root.toastWidth
        spacing: 8

        Repeater {
            model: root.toasts

            Rectangle {
                id: toast

                property var notification: modelData.notification
                property bool dismissing: false
                property bool dragged: false
                property bool closeNotificationOnDismiss: false
                property bool animateHorizontalMovement: true
                readonly property bool hasImage: root.imageFor(notification).length > 0

                function finishDismiss(closeNotification) {
                    if (dismissing)
                        return ;

                    closeNotificationOnDismiss = closeNotification;
                    dismissing = true;
                    x = root.dismissTravel;
                    dismissTimer.restart();
                }

                x: root.dismissTravel
                width: root.toastWidth
                height: toastBody.implicitHeight + 18
                opacity: dismissing ? 0 : 1
                radius: 8
                color: Theme.surface
                border.color: notification && notification.urgency === NotificationUrgency.Critical ? Theme.red : Theme.surfaceAlt
                border.width: 1
                Component.onCompleted: {
                    animateHorizontalMovement = root.takeEntranceAnimation(modelData.toastId);
                    x = 0;
                    if (!animateHorizontalMovement)
                        Qt.callLater(() => animateHorizontalMovement = true);

                }

                Timer {
                    id: dismissTimer

                    interval: 185
                    repeat: false
                    onTriggered: root.dismiss(toast.notification, toast.closeNotificationOnDismiss)
                }

                Timer {
                    id: expiryTimer

                    interval: modelData.expiresAt ? Math.max(1, modelData.expiresAt - Date.now()) : Math.max(3500, modelData.timeout || 6000)
                    repeat: false
                    running: !toast.dismissing
                    onTriggered: toast.finishDismiss(false)
                }

                Row {
                    z: 1
                    anchors.fill: parent
                    anchors.margins: 9
                    spacing: imageSlot.visible ? 9 : 0

                    Item {
                        id: imageSlot

                        visible: toast.hasImage
                        width: visible ? 38 : 0
                        height: 38
                        anchors.top: parent.top

                        Image {
                            anchors.fill: parent
                            source: root.imageFor(toast.notification)
                            fillMode: Image.PreserveAspectCrop
                            clip: true
                        }

                    }

                    Column {
                        id: toastBody

                        width: parent.width - imageSlot.width - parent.spacing
                        spacing: 3

                        Row {
                            width: parent.width
                            spacing: 8

                            NotificationHeader {
                                width: parent.width - closeButton.width - 8
                                summary: toast.notification ? toast.notification.summary : ""
                                meta: toast.notification ? toast.notification.appName : ""
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

                            }

                        }

                        NotificationBody {
                            width: parent.width
                            body: toast.notification ? toast.notification.body : ""
                            opacity: 0.84
                            maximumLineCount: 2
                        }

                    }

                }

                MouseArea {
                    id: toastMouse

                    anchors.fill: parent
                    anchors.rightMargin: 42
                    z: 2
                    acceptedButtons: Qt.LeftButton
                    drag.target: toast
                    drag.axis: Drag.XAxis
                    drag.minimumX: 0
                    drag.maximumX: root.dismissTravel
                    propagateComposedEvents: true
                    onPressed: {
                        toast.dragged = false;
                    }
                    onPositionChanged: (mouse) => {
                        toast.dragged = toast.dragged || Math.abs(toast.x) > 8;
                    }
                    onReleased: {
                        if (toast.x > 28)
                            toast.finishDismiss(true);
                        else
                            toast.x = 0;
                    }
                    onCanceled: {
                        toast.x = 0;
                    }
                    onClicked: (mouse) => {
                        if (toast.dragged) {
                            mouse.accepted = true;
                            return ;
                        }
                        root.activate(toast.notification);
                    }
                }

                MouseArea {
                    id: closeMouse

                    anchors.top: parent.top
                    anchors.right: parent.right
                    anchors.topMargin: 6
                    anchors.rightMargin: 6
                    width: 36
                    height: 36
                    z: 5
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: toast.finishDismiss(true)
                }

                Behavior on x {
                    enabled: toast.animateHorizontalMovement && !toastMouse.drag.active

                    NumberAnimation {
                        duration: 180
                        easing.type: Easing.OutCubic
                    }

                }

                Behavior on opacity {
                    NumberAnimation {
                        duration: 160
                        easing.type: Easing.OutCubic
                    }

                }

            }

        }

    }

}
