import "../shared"
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
    property var targetMonitor: null
    property var targetWorkspace: null
    property var captureSource: null
    property string captureTitle: ""
    property string wallpaperSource: ""
    property string wallpaperFit: "cover"

    function focusedScreen() {
        for (const screen of Quickshell.screens) {
            if (Hyprland.monitorFor(screen) === Hyprland.focusedMonitor)
                return screen;

        }
        return Quickshell.screens.length > 0 ? Quickshell.screens[0] : null;
    }

    function takeSnapshot() {
        Hyprland.refreshToplevels();
        targetScreen = focusedScreen();
        targetMonitor = targetScreen ? Hyprland.monitorFor(targetScreen) : null;
        targetWorkspace = targetMonitor ? targetMonitor.activeWorkspace : null;
        captureSource = targetScreen;
        captureTitle = targetScreen ? targetScreen.name : "Desktop";
    }

    function loadWallpaper(raw) {
        try {
            const data = JSON.parse(raw);
            const path = String(data.path || "");
            wallpaperSource = path.startsWith("~/") ? "file://" + Quickshell.env("HOME") + path.slice(1) : path.startsWith("/") ? "file://" + path : path;
            wallpaperFit = String(data.fit || "cover");
        } catch (error) {
            console.warn("[blox.shortcut-guide] rejected wallpaper state: " + error);
            wallpaperSource = "";
            wallpaperFit = "cover";
        }
    }

    function arm() : string {
        if (guideOpen || armed)
            return "already armed";

        hideTimer.stop();
        takeSnapshot();
        rendered = true;
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
        snapshotRevealTimer.stop();
        guideOpen = false;
        hideTimer.restart();
        return "hidden";
    }

    function show() : string {
        armed = false;
        holdTimer.stop();
        takeSnapshot();
        rendered = true;
        snapshotRevealTimer.restart();
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

    FileView {
        id: wallpaperFile

        path: Theme.stateRoot + "/blox-theme/current/hypr/wallpaper.json"
        preload: true
        blockLoading: true
        watchChanges: true
        printErrors: false
        onLoaded: root.loadWallpaper(text())
        onFileChanged: reload()
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
                root.targetMonitor = null;
                root.targetWorkspace = null;
            }
        }
    }

    Timer {
        id: snapshotRevealTimer

        interval: 120
        repeat: false
        onTriggered: root.reveal()
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
            captureMonitor: root.targetMonitor
            captureWorkspace: root.targetWorkspace
            wallpaperSource: root.wallpaperSource
            wallpaperFit: root.wallpaperFit
            onCloseRequested: root.close()
        }

    }

}
