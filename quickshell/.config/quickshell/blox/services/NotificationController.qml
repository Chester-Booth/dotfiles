import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.Notifications

Scope {
    id: root

    property string openPanel: ""
    property real openPanelY: 8
    property real panelY: 0
    property bool dnd: false
    property bool toastsEnabled: true
    property var items: server.trackedNotifications.values
    property var toasts: []
    property bool initialSyncComplete: false
    property double toggleAllowedAt: 0
    property int nextToastId: 0

    signal openRequested(real centreY)
    signal closeRequested()
    signal dndToggleRequested()

    function log(event, detail) {
        console.log("[blox.notifications] " + new Date().toISOString() + " " + event + " " + (detail || ""));
    }

    function status() {
        const count = items ? items.length : 0;
        return {
            "icon": dnd ? "󰂛" : count > 0 ? "󰂚" : "󰂜",
            "class": dnd ? "dnd" : count > 0 ? "notification" : "none",
            "count": count,
            "dnd": dnd,
            "inhibited": false,
            "tooltip": (count === 1 ? "1 notification" : count + " notifications") + "\nDND: " + (dnd ? "true" : "false")
        };
    }

    function clear() {
        const current = items ? items.slice() : [];
        for (let i = 0; i < current.length; i++) current[i].dismiss()
        toasts = [];
    }

    function open(centreY) {
        const now = Date.now();
        const targetY = centreY !== undefined && centreY > 0 ? centreY : panelY > 0 ? panelY : openPanelY > 0 ? openPanelY : 120;
        if (openPanel === "notifications" || now < toggleAllowedAt)
            return ;

        toggleAllowedAt = now + 750;
        toasts = [];
        openRequested(targetY);
    }

    function toggle() {
        const now = Date.now();
        if (now < toggleAllowedAt)
            return ;

        if (openPanel === "notifications") {
            toggleAllowedAt = now + 750;
            closeRequested();
        } else {
            open();
        }
    }

    function addToast(notification) {
        if (!toastsEnabled || dnd || openPanel === "notifications")
            return ;

        const timeout = notification.expireTimeout && notification.expireTimeout > 0 ? notification.expireTimeout : 6000;
        const boundedTimeout = Math.max(3500, Math.min(12000, timeout));
        const next = toasts ? toasts.slice() : [];
        next.unshift({
            "toastId": ++nextToastId,
            "notification": notification,
            "timeout": boundedTimeout,
            "expiresAt": Date.now() + boundedTimeout
        });
        toasts = next.slice(0, 4);
    }

    function markCentreOnly(notification) {
        if (!notification)
            return ;

        notification.tracked = true;
        notification.bloxToastKnown = true;
        if (!notification.bloxReceivedAt)
            notification.bloxReceivedAt = Date.now();

    }

    function markExistingCentreOnly() {
        const current = items ? items.slice() : [];
        for (let i = 0; i < current.length; i++) markCentreOnly(current[i])
        initialSyncComplete = true;
    }

    function removeToast(notification) {
        toasts = toasts ? toasts.filter((item) => {
            return item.notification !== notification;
        }) : [];
    }

    onDndChanged: {
        if (dnd)
            toasts = [];

    }

    Timer {
        interval: 1200
        repeat: false
        running: true
        onTriggered: root.markExistingCentreOnly()
    }

    NotificationServer {
        id: server

        keepOnReload: true
        persistenceSupported: true
        bodySupported: true
        bodyMarkupSupported: true
        bodyImagesSupported: true
        imageSupported: true
        actionsSupported: true
        actionIconsSupported: true
        inlineReplySupported: true
        onNotification: (notification) => {
            const known = notification.bloxToastKnown === true;
            notification.tracked = true;
            if (!notification.bloxReceivedAt)
                notification.bloxReceivedAt = Date.now();

            notification.bloxToastKnown = true;
            if (!known && root.initialSyncComplete)
                root.addToast(notification);

            notification.closed.connect(() => {
                return root.removeToast(notification);
            });
        }
    }

    IpcHandler {
        function open() : string {
            root.open();
            return "open";
        }

        function toggle() : string {
            root.toggle();
            return root.openPanel === "notifications" ? "open" : "closed";
        }

        function close() : string {
            root.closeRequested();
            return "closed";
        }

        function dnd() : string {
            root.dndToggleRequested();
            return root.dnd ? "enabled" : "disabled";
        }

        function clear() : string {
            root.clear();
            return "cleared";
        }

        target: "notifications"
    }

}
