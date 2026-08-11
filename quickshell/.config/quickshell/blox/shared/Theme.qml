import QtQuick
import Quickshell
import Quickshell.Io
pragma Singleton

Singleton {
    id: root

    property string themeId: "catppuccin-mocha"
    property string activeThemeId: "catppuccin-mocha"
    property string previewThemeId: ""
    property string variant: "dark"
    property color background: "#1e1e2e"
    property color surface: "#313244"
    property color surfaceAlt: "#45475a"
    property color foreground: "#cdd6f4"
    property color muted: "#a6adc8"
    property color red: "#f38ba8"
    property color green: "#a6e3a1"
    property color yellow: "#f9e2af"
    property color accent: "#89b4fa"
    property color blue: "#74c7ec"
    property color mauve: "#cba6f7"
    property color teal: "#94e2d5"
    property color selectionForeground: "#1e1e2e"
    property color border: "#6c7086"
    readonly property int railWidth: 34
    readonly property int iconSize: 18
    readonly property int buttonSize: 30
    readonly property int radius: 4
    property string fontFamily: "FiraCode Nerd Font Propo"
    property string monoFontFamily: "FiraCode Nerd Font Mono"
    property string bodyFontFamily: "Outfit"
    property bool previewActive: false
    property string widgetProfile: "minimal"
    property real widgetOpacity: 0.3
    property int widgetPadding: 20
    property int widgetRadius: 0
    property int widgetFontSize: 14
    property var widgetItems: []
    property string barPosition: "right"
    property var barItems: builtinBarItems()
    readonly property var barStartItems: barItemsForRegion("start")
    readonly property var barCentreItems: barItemsForRegion("centre")
    readonly property var barEndItems: barItemsForRegion("end")
    readonly property var barHiddenItems: barItemsForRegion("hidden")
    property string osdPosition: "centre-top"
    property int osdOffsetX: 0
    property int osdOffsetY: 0
    property string notificationPosition: "top-left"
    property int notificationOffsetX: 0
    property int notificationOffsetY: 0
    readonly property string stateRoot: {
        const configured = Quickshell.env("XDG_STATE_HOME") || "";
        return configured.length > 0 ? configured : Quickshell.env("HOME") + "/.local/state";
    }
    readonly property string themePath: stateRoot + "/blox-theme/current/quickshell/theme.json"
    readonly property string widgetPath: stateRoot + "/blox-theme/current/widgets/profile.json"
    readonly property string wallpaperPath: stateRoot + "/blox-theme/current/hypr/wallpaper.json"
    property string activeWallpaperSource: wallpaperUrl("wallpapers/showcase/catppuccin-mocha.webp")
    property string activeWallpaperFit: "cover"
    property string wallpaperSource: activeWallpaperSource
    property string wallpaperFit: activeWallpaperFit

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

    function builtinBarItems() {
        return defaults.resolvedBarItems([{
            "id": "active-window-title",
            "enabled": true,
            "region": "start",
            "order": 0,
            "orientation": "inward"
        }, {
            "id": "workspaces",
            "enabled": true,
            "region": "centre",
            "order": 0
        }, {
            "id": "tray",
            "enabled": true,
            "region": "end",
            "order": 0
        }, {
            "id": "sound",
            "enabled": true,
            "region": "end",
            "order": 1
        }, {
            "id": "wifi",
            "enabled": true,
            "region": "end",
            "order": 2
        }, {
            "id": "battery",
            "enabled": true,
            "region": "end",
            "order": 3,
            "display": "icon"
        }, {
            "id": "power",
            "enabled": true,
            "region": "end",
            "order": 4
        }, {
            "id": "application-tray",
            "enabled": true,
            "region": "hidden",
            "order": 0
        }]);
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

    function wallpaperUrl(path) : string {
        const value = String(path || "");
        if (value.startsWith("file:"))
            return value;

        if (value.startsWith("~/"))
            return "file://" + Quickshell.env("HOME") + value.slice(1);

        if (value.startsWith("/"))
            return "file://" + value;

        if (value.startsWith("wallpapers/")) {
            const configured = Quickshell.env("BLOX_DATA_DIR") || "";
            const dataRoot = configured.length > 0 ? configured : Quickshell.shellDir + "/../../../../themes";
            return "file://" + dataRoot + "/" + value;
        }
        return "file://" + Quickshell.shellDir + "/../../../.." + "/" + value;
    }

    function setPreviewWallpaper(data) {
        if (data.targets && data.targets.wallpaper) {
            wallpaperSource = wallpaperUrl(data.wallpaper.path);
            wallpaperFit = data.wallpaper.fit;
        } else {
            wallpaperSource = activeWallpaperSource;
            wallpaperFit = activeWallpaperFit;
        }
    }

    function loadWallpaper(raw) : bool {
        try {
            const data = JSON.parse(raw);
            if (data.schema_version !== 1 || !data.path || ["cover", "contain", "stretch"].indexOf(data.fit) < 0)
                throw new Error("unsupported or incomplete wallpaper document");

            activeWallpaperSource = wallpaperUrl(data.path);
            activeWallpaperFit = data.fit;
            if (!previewActive) {
                wallpaperSource = activeWallpaperSource;
                wallpaperFit = activeWallpaperFit;
            }
            return true;
        } catch (error) {
            console.warn("[blox.theme] rejected wallpaper state: " + error);
            return false;
        }
    }

    function resetWallpaper() : string {
        activeWallpaperSource = wallpaperUrl("wallpapers/showcase/catppuccin-mocha.webp");
        activeWallpaperFit = "cover";
        if (!previewActive) {
            wallpaperSource = activeWallpaperSource;
            wallpaperFit = activeWallpaperFit;
        }
        return activeWallpaperSource;
    }

    function reloadWallpaper() : string {
        wallpaperFile.reload();
        return activeWallpaperSource;
    }

    function previewSource(raw) : bool {
        const loaded = document.previewSource(raw);
        if (!loaded)
            return false;

        const data = typeof raw === "string" ? JSON.parse(raw) : raw;
        setPreviewWallpaper(data);
        return true;
    }

    function cancelPreview() : string {
        previewActive = false;
        previewThemeId = "";
        wallpaperSource = activeWallpaperSource;
        wallpaperFit = activeWallpaperFit;
        const active = themeFile.text();
        if (!active || !loadJson(active))
            reset();

        reloadWidgets();
        return themeId;
    }

    function reload() : string {
        previewActive = false;
        previewThemeId = "";
        wallpaperSource = activeWallpaperSource;
        wallpaperFit = activeWallpaperFit;
        themeFile.reload();
        wallpaperFile.reload();
        return themeId;
    }

    function reloadWidgets() : string {
        widgetFile.reload();
        return widgetProfile;
    }

    ThemeDefaults {
        id: defaults
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
        id: wallpaperFile

        path: root.wallpaperPath
        preload: true
        blockLoading: true
        watchChanges: true
        printErrors: false
        onLoaded: root.loadWallpaper(text())
        onFileChanged: reload()
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

        function reloadWallpaper() : string {
            return root.reloadWallpaper();
        }

        function resetWallpaper() : string {
            return root.resetWallpaper();
        }

        target: "theme"
    }

}
