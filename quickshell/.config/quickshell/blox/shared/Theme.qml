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
    property color selectionBackground: "#89b4fa"
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
    property int widgetMargin: 20
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

    signal osdPositionPreviewRequested()
    signal notificationPositionPreviewRequested()
    signal widgetEditModeRequested()
    signal widgetEditModeCancelRequested()
    signal widgetEditModeFinished(string widgetsJson, string returnWorkspace)

    function withAlpha(colour, opacity) : color {
        return Qt.rgba(colour.r, colour.g, colour.b, opacity);
    }

    function reset() : string {
        previewActive = false;
        previewThemeId = "";
        themeId = "blox-panel";
        activeThemeId = themeId;
        variant = "dark";
        background = "#242424";
        surface = "#1e1e1e";
        surfaceAlt = "#3b3c4a";
        foreground = "#cdd6f4";
        muted = "#a6adc8";
        red = "#f38ba8";
        green = "#a6e3a1";
        yellow = "#f9e2af";
        accent = "#89b4fa";
        blue = "#89b4fa";
        mauve = "#f5c2e7";
        teal = "#94e2d5";
        selectionBackground = "#89b4fa";
        selectionForeground = "#1e1e1e";
        border = "#3b3c4a";
        fontFamily = "MartianMono Nerd Font Propo";
        monoFontFamily = "MartianMono Nerd Font Mono";
        bodyFontFamily = "Google Sans";
        barPosition = "left";
        barItems = defaultBarItems();
        osdPosition = "top-left";
        osdOffsetX = 0;
        osdOffsetY = 0;
        notificationPosition = "bottom-right";
        notificationOffsetX = 0;
        notificationOffsetY = 0;
        return themeId;
    }

    function resetWidgets() : string {
        widgetProfile = "minimal";
        widgetOpacity = 0.3;
        widgetMargin = 20;
        widgetPadding = 20;
        widgetRadius = 0;
        widgetFontSize = 14;
        widgetItems = defaultWidgetItems();
        return widgetProfile;
    }

    function loadWidgets(raw) : bool {
        try {
            const data = JSON.parse(raw);
            if (data.schema_version !== 1 || !data.profile)
                throw new Error("unsupported or incomplete widget profile");

            widgetProfile = data.profile;
            widgetOpacity = data.opacity;
            widgetMargin = data.margin;
            widgetPadding = data.padding;
            widgetRadius = data.radius;
            widgetFontSize = data.font_size;
            widgetItems = data.items || defaultWidgetItems();
            return true;
        } catch (error) {
            console.warn("[blox.theme] rejected widget profile: " + error);
            return false;
        }
    }

    function defaultWidgetItems() : var {
        return [{
            "id": "todo", "name": "Todo", "type": "custom", "enabled": true,
            "content_command": "$SCRIPT_ROOT/overlays/todo-content.sh", "left_click_command": "$SCRIPT_ROOT/overlays/cycle-todo.sh", "right_click_command": "$SCRIPT_ROOT/overlays/open-todo-editor.sh",
            "interval_ms": 60000, "visibility": "empty-workspace", "anchor": "top-left", "offset_x": 20, "offset_y": 20, "width": 0, "height": 0, "shape": "auto", "options": {}
        }, {
            "id": "calendar", "name": "Calendar", "type": "custom", "enabled": true,
            "content_command": "$SCRIPT_ROOT/overlays/gcal-content.sh", "left_click_command": "$SCRIPT_ROOT/overlays/cycle-gcal.sh", "right_click_command": "$SCRIPT_ROOT/overlays/open-gcal.sh",
            "interval_ms": 60000, "visibility": "empty-workspace", "anchor": "bottom-right", "offset_x": 20, "offset_y": 20, "width": 0, "height": 0, "shape": "auto", "options": {}
        }];
    }

    function loadJson(raw) : bool {
        try {
            const data = JSON.parse(raw);
            if (data.schema_version !== 1 || !data.id || !data.colours || !data.compatibility || !data.fonts)
                throw new Error("unsupported or incomplete theme document");

            themeId = data.id;
            activeThemeId = data.id;
            variant = data.variant;
            background = data.colours.background;
            surface = data.colours.surface;
            surfaceAlt = data.colours.surface_alt;
            foreground = data.colours.foreground;
            muted = data.colours.muted;
            red = data.compatibility.red;
            green = data.compatibility.green;
            yellow = data.compatibility.yellow;
            accent = data.colours.accent;
            blue = data.compatibility.blue;
            mauve = data.compatibility.mauve;
            teal = data.compatibility.teal;
            selectionBackground = data.colours.selection_background;
            selectionForeground = data.colours.selection_foreground;
            border = data.colours.border;
            fontFamily = data.fonts.panel;
            monoFontFamily = data.fonts.mono;
            bodyFontFamily = data.fonts.ui;
            loadShell(data.shell);
            if (data.widgets)
                loadWidgetSource(data.widgets.profile);

            return true;
        } catch (error) {
            console.warn("[blox.theme] rejected generated theme: " + error);
            return false;
        }
    }

    function loadWidgetSource(profile) : bool {
        const profiles = {
            "minimal": {
                "opacity": 0.3,
                "margin": 20,
                "padding": 20,
                "radius": 0,
                "font_size": 14
            },
            "compact": {
                "opacity": 0.52,
                "margin": 12,
                "padding": 12,
                "radius": 6,
                "font_size": 12
            },
            "comfortable": {
                "opacity": 0.42,
                "margin": 24,
                "padding": 24,
                "radius": 10,
                "font_size": 15
            }
        };
        const resolved = profiles[profile || "minimal"];
        if (!resolved)
            return false;

        return loadWidgets(JSON.stringify({
            "schema_version": 1,
            "profile": profile || "minimal",
            "opacity": resolved.opacity,
            "margin": resolved.margin,
            "padding": resolved.padding,
            "radius": resolved.radius,
            "font_size": resolved.font_size
        }));
    }

    function loadShell(shell) : bool {
        const data = shell || {
        };
        const osd = data.osd || {
        };
        const notifications = data.notifications || {
        };
        barPosition = data.bar && data.bar.position ? data.bar.position : "left";
        barItems = resolvedBarItems(data.bar && data.bar.items ? data.bar.items : [], barPosition);
        osdPosition = osd.position || "top-left";
        osdOffsetX = osd.offset_x || 0;
        osdOffsetY = osd.offset_y || 0;
        notificationPosition = notifications.position || "bottom-right";
        notificationOffsetX = notifications.offset_x || 0;
        notificationOffsetY = notifications.offset_y || 0;
        return true;
    }

    function defaultBarItems() : var {
        return [{"id": "power", "enabled": true, "region": "start", "order": 0}, {"id": "notes", "enabled": true, "region": "start", "order": 1}, {"id": "workspaces", "enabled": true, "region": "start", "order": 2}, {"id": "clock", "enabled": true, "region": "centre", "order": 0}, {"id": "battery", "enabled": true, "region": "end", "order": 0, "display": "toggle"}, {"id": "tray", "enabled": true, "region": "end", "order": 1}, {"id": "notifications", "enabled": true, "region": "end", "order": 2}, {"id": "wifi", "enabled": true, "region": "end", "order": 3}, {"id": "sound", "enabled": true, "region": "end", "order": 4}, {"id": "privacy", "enabled": true, "region": "hidden", "order": 0}, {"id": "awake", "enabled": true, "region": "hidden", "order": 1}, {"id": "display", "enabled": true, "region": "hidden", "order": 2}, {"id": "bt", "enabled": true, "region": "hidden", "order": 3}, {"id": "updates", "enabled": true, "region": "hidden", "order": 4}, {"id": "fan", "enabled": true, "region": "hidden", "order": 5, "visibility": "normal"}, {"id": "gpu", "enabled": true, "region": "hidden", "order": 6, "visibility": "normal"}, {"id": "application-tray", "enabled": true, "region": "hidden", "order": 7}, {"id": "touchpad", "enabled": true, "region": "hidden", "order": 8, "visibility": "normal"}];
    }

    function trayOpensForward(items) : bool {
        const tray = items.find((item) => item.id === "tray");
        if (!tray || tray.region === "end")
            return false;
        if (tray.region === "start")
            return true;
        if (tray.region !== "centre")
            return false;

        const centre = items.filter((item) => item.region === "centre").sort((left, right) => left.order - right.order);
        return centre.length > 0 && centre[centre.length - 1].id === "tray";
    }

    function resolvedBarItems(overrides, position) : var {
        const defaults = defaultBarItems();
        const byId = {};
        for (let index = 0; index < overrides.length; index++)
            byId[overrides[index].id] = overrides[index];
        if (byId["tray"] && !byId["application-tray"]) {
            byId["application-tray"] = Object.assign({}, byId["tray"], {
                "id": "application-tray"
            });
            byId["tray"] = null;
        }
        for (let index = 0; index < defaults.length; index++) {
            const override = byId[defaults[index].id];
            if (override)
                defaults[index] = Object.assign({}, defaults[index], override);
        }
        const applicationTray = defaults.find((item) => item.id === "application-tray");
        applicationTray.region = "hidden";
        const hidden = defaults.filter((item) => item.region === "hidden" && item.id !== "application-tray").sort((left, right) => left.order - right.order);
        if (trayOpensForward(defaults))
            hidden.push(applicationTray);
        else
            hidden.unshift(applicationTray);
        for (let index = 0; index < hidden.length; ++index)
            hidden[index].order = index;

        return defaults;
    }

    function barItemsForRegion(region) : var {
        return barItems.filter(item => item.enabled && item.region === region).sort((left, right) => left.order - right.order);
    }

    function loadActiveIdentity(raw) : bool {
        try {
            const data = JSON.parse(raw);
            if (data.schema_version !== 1 || !data.id)
                throw new Error("unsupported or incomplete theme document");

            activeThemeId = data.id;
            return true;
        } catch (error) {
            console.warn("[blox.theme] rejected active theme identity: " + error);
            return false;
        }
    }

    function previewSource(raw) : bool {
        try {
            const data = typeof raw === "string" ? JSON.parse(raw) : raw;
            if (data.schema_version !== 1 || !data.id || !data.colours || !data.fonts)
                throw new Error("unsupported or incomplete source theme");

            previewActive = true;
            previewThemeId = data.id;
            themeId = data.id;
            variant = data.variant;
            background = data.colours.background;
            surface = data.colours.surface;
            surfaceAlt = data.colours.surface_alt;
            foreground = data.colours.foreground;
            muted = data.colours.muted;
            red = data.colours.danger;
            green = data.colours.success;
            yellow = data.colours.warning;
            blue = data.colours.info;
            mauve = data.colours.mauve;
            teal = data.colours.teal;
            selectionBackground = data.colours.selection_background;
            selectionForeground = data.colours.selection_foreground;
            border = data.colours.border;
            fontFamily = data.fonts.panel;
            monoFontFamily = data.fonts.mono;
            bodyFontFamily = data.fonts.ui;
            loadShell(data.shell);
            loadWidgetSource(data.widgets ? data.widgets.profile : "minimal");
            if (data.widgets && data.widgets.items)
                widgetItems = data.widgets.items;
            return true;
        } catch (error) {
            console.warn("[blox.theme] rejected source preview: " + error);
            return false;
        }
    }

    function cancelPreview() : string {
        previewActive = false;
        previewThemeId = "";
        const active = themeFile.text();
        if (!active || !loadJson(active))
            reset();

        reloadWidgets();
        return themeId;
    }

    function reload() : string {
        previewActive = false;
        previewThemeId = "";
        themeFile.reload();
        return themeId;
    }

    function reloadWidgets() : string {
        widgetFile.reload();
        return widgetProfile;
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
