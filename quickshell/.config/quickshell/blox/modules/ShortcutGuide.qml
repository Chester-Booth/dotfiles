import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io

Scope {
    id: root

    property bool armed: false
    property bool guideOpen: false
    property bool rendered: false
    property var targetScreen: null
    property var captureSource: null
    property string captureTitle: ""

    function focusedScreen() {
        for (const screen of Quickshell.screens) {
            if (Hyprland.monitorFor(screen) === Hyprland.focusedMonitor)
                return screen;

        }
        return Quickshell.screens.length > 0 ? Quickshell.screens[0] : null;
    }

    function takeSnapshot() {
        targetScreen = focusedScreen();
        const toplevel = Hyprland.activeToplevel;
        captureSource = toplevel ? toplevel.wayland : null;
        captureTitle = toplevel ? toplevel.title : "Desktop";
    }

    function arm() : string {
        if (guideOpen || armed)
            return "already armed";

        hideTimer.stop();
        takeSnapshot();
        armed = true;
        holdTimer.restart();
        return "armed";
    }

    function reveal() {
        rendered = true;
        guideOpen = true;
    }

    function release() : string {
        armed = false;
        holdTimer.stop();
        close();
        return "hidden";
    }

    function cancel() : string {
        return release();
    }

    function close() : string {
        armed = false;
        holdTimer.stop();
        guideOpen = false;
        hideTimer.restart();
        return "hidden";
    }

    function show() : string {
        armed = false;
        holdTimer.stop();
        takeSnapshot();
        reveal();
        return "visible";
    }

    function status() : string {
        return JSON.stringify({
            "armed": armed,
            "visible": guideOpen,
            "rendered": rendered,
            "screen": targetScreen ? targetScreen.name : ""
        });
    }

    IpcHandler {
        function arm() : string {
            return root.arm();
        }

        function release() : string {
            return root.release();
        }

        function cancel() : string {
            return root.cancel();
        }

        function close() : string {
            return root.close();
        }

        function show() : string {
            return root.show();
        }

        function status() : string {
            return root.status();
        }

        target: "shortcutGuide"
    }

    Timer {
        id: holdTimer

        interval: 700
        repeat: false
        onTriggered: {
            if (root.armed)
                root.reveal();

        }
    }

    Timer {
        id: hideTimer

        interval: 200
        repeat: false
        onTriggered: {
            if (!root.guideOpen) {
                root.rendered = false;
                root.captureSource = null;
            }
        }
    }

    Variants {
        model: Quickshell.screens

        ShortcutGuideWindow {
            required property var modelData

            screen: modelData
            guideOpen: root.guideOpen && root.targetScreen === modelData
            rendered: root.rendered && root.targetScreen === modelData
            captureSource: root.captureSource
            captureTitle: root.captureTitle
            onCloseRequested: root.close()
        }

    }

}
