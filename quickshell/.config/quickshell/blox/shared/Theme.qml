import QtQuick
import Quickshell
import Quickshell.Io
pragma Singleton

Singleton {
    id: root

    property string themeId: "blox-panel"
    property string variant: "dark"
    property color background: "#242424"
    property color surface: "#1e1e1e"
    property color surfaceAlt: "#3b3c4a"
    property color foreground: "#cdd6f4"
    property color muted: "#a6adc8"
    property color red: "#f38ba8"
    property color green: "#a6e3a1"
    property color yellow: "#f9e2af"
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
    readonly property string stateRoot: {
        const configured = Quickshell.env("XDG_STATE_HOME") || "";
        return configured.length > 0 ? configured : Quickshell.env("HOME") + "/.local/state";
    }
    readonly property string themePath: stateRoot + "/blox-theme/current/quickshell/theme.json"

    function withAlpha(colour, opacity) : color {
        return Qt.rgba(colour.r, colour.g, colour.b, opacity);
    }

    function reset() : string {
        themeId = "blox-panel";
        variant = "dark";
        background = "#242424";
        surface = "#1e1e1e";
        surfaceAlt = "#3b3c4a";
        foreground = "#cdd6f4";
        muted = "#a6adc8";
        red = "#f38ba8";
        green = "#a6e3a1";
        yellow = "#f9e2af";
        blue = "#89b4fa";
        mauve = "#f5c2e7";
        teal = "#94e2d5";
        selectionBackground = "#89b4fa";
        selectionForeground = "#1e1e1e";
        border = "#3b3c4a";
        fontFamily = "MartianMono Nerd Font Propo";
        monoFontFamily = "MartianMono Nerd Font Mono";
        bodyFontFamily = "Google Sans";
        return themeId;
    }

    function loadJson(raw) : bool {
        try {
            const data = JSON.parse(raw);
            if (data.schema_version !== 1 || !data.id || !data.colours || !data.compatibility || !data.fonts)
                throw new Error("unsupported or incomplete theme document");

            themeId = data.id;
            variant = data.variant;
            background = data.colours.background;
            surface = data.colours.surface;
            surfaceAlt = data.colours.surface_alt;
            foreground = data.colours.foreground;
            muted = data.colours.muted;
            red = data.compatibility.red;
            green = data.compatibility.green;
            yellow = data.compatibility.yellow;
            blue = data.compatibility.blue;
            mauve = data.compatibility.mauve;
            teal = data.compatibility.teal;
            selectionBackground = data.colours.selection_background;
            selectionForeground = data.colours.selection_foreground;
            border = data.colours.border;
            fontFamily = data.fonts.panel;
            monoFontFamily = data.fonts.mono;
            bodyFontFamily = data.fonts.ui;
            return true;
        } catch (error) {
            console.warn("[blox.theme] rejected generated theme: " + error);
            return false;
        }
    }

    function previewSource(raw) : bool {
        try {
            const data = typeof raw === "string" ? JSON.parse(raw) : raw;
            if (data.schema_version !== 1 || !data.id || !data.colours || !data.fonts)
                throw new Error("unsupported or incomplete source theme");

            previewActive = true;
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
            return true;
        } catch (error) {
            console.warn("[blox.theme] rejected source preview: " + error);
            return false;
        }
    }

    function cancelPreview() : string {
        previewActive = false;
        const active = themeFile.text();
        if (!active || !loadJson(active))
            reset();

        return themeId;
    }

    function reload() : string {
        previewActive = false;
        themeFile.reload();
        return themeId;
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

        }
        onFileChanged: {
            if (!root.previewActive)
                reload();

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

        target: "theme"
    }

}
