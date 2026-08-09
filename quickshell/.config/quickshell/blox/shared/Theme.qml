import QtQuick
import Quickshell
import Quickshell.Io
pragma Singleton

Singleton {
    id: root

    property string themeId: "blox-panel"
    property string activeThemeId: "blox-panel"
    property string previewThemeId: ""
    property string variant: "dark"
    property color background: "#242424"
    property color surface: "#1e1e1e"
    property color surfaceAlt: "#3b3c4a"
    property color foreground: "#cdd6f4"
    property color muted: "#a6adc8"
    property color red: "#f38ba8"
    property color green: "#a6e3a1"
    property color yellow: "#f9e2af"
    property color accent: "#89b4fa"
    property color blue: "#89b4fa"
    property color mauve: "#f5c2e7"
    property color teal: "#94e2d5"
    property color selectionForeground: "#1e1e1e"
    property color border: "#3b3c4a"
    readonly property int railWidth: 34
    readonly property int iconSize: 18
    readonly property int buttonSize: 30
    readonly property int radius: 4
    property string fontFamily: "MartianMono Nerd Font Propo"
    property string monoFontFamily: "MartianMono Nerd Font Mono"
    property string bodyFontFamily: "Google Sans"
    property bool previewActive: false
    property string widgetProfile: "minimal"
    property real widgetOpacity: 0.3
    property int widgetPadding: 20
    property int widgetRadius: 0
    property int widgetFontSize: 14
    property var widgetItems: []
    property string barPosition: "left"
    property var barItems: defaultBarItems()
    readonly property var barStartItems: barItemsForRegion("start")
    readonly property var barCentreItems: barItemsForRegion("centre")
    readonly property var barEndItems: barItemsForRegion("end")
    readonly property var barHiddenItems: barItemsForRegion("hidden")
    property string osdPosition: "top-left"
    property int osdOffsetX: 0
    property int osdOffsetY: 0
    property string notificationPosition: "bottom-right"
    property int notificationOffsetX: 0
    property int notificationOffsetY: 0
    readonly property string stateRoot: {
        const configured = Quickshell.env("XDG_STATE_HOME") || "";
        return configured.length > 0 ? configured : Quickshell.env("HOME") + "/.local/state";
    }
    readonly property string themePath: stateRoot + "/blox-theme/current/quickshell/theme.json"
    readonly property string widgetPath: stateRoot + "/blox-theme/current/widgets/profile.json"
    property var pendingWallpaperCommand: []
    property string previewWallpaperKey: ""

    signal osdPositionPreviewRequested()
    signal notificationPositionPreviewRequested()
    signal widgetEditModeRequested()
    signal widgetEditModeCancelRequested()
    signal widgetEditModeFinished(string widgetsJson, string returnWorkspace)

    function withAlpha(colour, opacity) : color {
        return Qt.rgba(colour.r, colour.g, colour.b, opacity);
    }

    function reset() : string {
        return document.reset();
    }

    function resetWidgets() : string {
        return document.resetWidgets();
    }

    function loadWidgets(raw) : bool {
        return document.loadWidgets(raw);
    }

    function defaultWidgetItems() {
        return defaults.defaultWidgetItems();
    }

    function loadJson(raw) : bool {
        return document.loadJson(raw);
    }

    function loadWidgetSource(profile) : bool {
        return document.loadWidgetSource(profile);
    }

    function loadShell(shell) : bool {
        return document.loadShell(shell);
    }

    function defaultBarItems() {
        return defaults.defaultBarItems();
    }

    function trayOpensForward(items) : bool {
        return defaults.trayOpensForward(items);
    }

    function resolvedBarItems(overrides, position) {
        return defaults.resolvedBarItems(overrides);
    }

    function barItemsForRegion(region) {
        return defaults.barItemsForRegion(barItems, region);
    }

    function loadActiveIdentity(raw) : bool {
        return document.loadActiveIdentity(raw);
    }

    function runPendingWallpaperCommand() {
        if (wallpaperProcess.running || pendingWallpaperCommand.length === 0)
            return ;

        const arguments = pendingWallpaperCommand;
        pendingWallpaperCommand = [];
        wallpaperProcess.command = [Quickshell.shellDir + "/scripts/theme/themectl.sh"].concat(arguments).concat(["--json"]);
        wallpaperProcess.running = true;
    }

    function queueWallpaperCommand(arguments) {
        pendingWallpaperCommand = arguments;
        runPendingWallpaperCommand();
    }

    function previewSource(raw) : bool {
        const loaded = document.previewSource(raw);
        if (!loaded)
            return false;

        const data = typeof raw === "string" ? JSON.parse(raw) : raw;
        if (data.targets && data.targets.wallpaper) {
            const key = data.wallpaper.path + "\n" + data.wallpaper.fit;
            if (key !== previewWallpaperKey) {
                previewWallpaperKey = key;
                queueWallpaperCommand(["wallpaper-preview", typeof raw === "string" ? raw : JSON.stringify(raw)]);
            }
        } else if (previewWallpaperKey.length > 0) {
            previewWallpaperKey = "";
            queueWallpaperCommand(["wallpaper-restore"]);
        }

        return true;
    }

    function cancelPreview() : string {
        previewActive = false;
        previewThemeId = "";
        previewWallpaperKey = "";
        const active = themeFile.text();
        if (!active || !loadJson(active))
            reset();

        reloadWidgets();
        queueWallpaperCommand(["wallpaper-restore"]);
        return themeId;
    }

    function reload() : string {
        previewActive = false;
        previewThemeId = "";
        previewWallpaperKey = "";
        themeFile.reload();
        queueWallpaperCommand(["wallpaper-restore"]);
        return themeId;
    }

    function reloadWidgets() : string {
        widgetFile.reload();
        return widgetProfile;
    }

    ThemeDefaults {
        id: defaults
    }

    Process {
        id: wallpaperProcess

        onExited: root.runPendingWallpaperCommand()
    }

    ThemeDocumentController {
        id: document

        theme: root
        defaults: defaults
    }

    FileView {
        id: themeFile

        path: root.themePath
        preload: true
        blockLoading: true
        watchChanges: true
        printErrors: false
        onLoaded: {
            if (!root.previewActive)
                root.loadJson(text());
            else
                root.loadActiveIdentity(text());
        }
        onFileChanged: {
            if (!root.previewActive)
                reload();
            else
                themeFile.reload();
        }
    }

    FileView {
        id: widgetFile

        path: root.widgetPath
        preload: true
        blockLoading: true
        watchChanges: true
        printErrors: false
        onLoaded: {
            if (!root.previewActive && !root.loadWidgets(text()))
                root.resetWidgets();

        }
        onFileChanged: {
            if (!root.previewActive)
                reloadWidgets();

        }
    }

    IpcHandler {
        function reload() : string {
            return root.reload();
        }

        function reset() : string {
            return root.reset();
        }

        function status() : string {
            return root.themeId + ":" + root.variant;
        }

        function reloadWidgets() : string {
            return root.reloadWidgets();
        }

        function resetWidgets() : string {
            return root.resetWidgets();
        }

        target: "theme"
    }

}
