import QtQuick

QtObject {
    id: root

    required property var theme
    required property ThemeDefaults defaults

    function reset() {
        theme.previewActive = false;
        theme.previewThemeId = "";
        theme.themeId = "catppuccin-mocha";
        theme.activeThemeId = theme.themeId;
        theme.variant = "dark";
        theme.background = "#1e1e2e";
        theme.surface = "#313244";
        theme.surfaceAlt = "#45475a";
        theme.foreground = "#cdd6f4";
        theme.muted = "#a6adc8";
        theme.red = "#f38ba8";
        theme.green = "#a6e3a1";
        theme.yellow = "#f9e2af";
        theme.accent = "#89b4fa";
        theme.blue = "#74c7ec";
        theme.mauve = "#cba6f7";
        theme.teal = "#94e2d5";
        theme.selectionForeground = "#1e1e2e";
        theme.border = "#6c7086";
        theme.fontFamily = "FiraCode Nerd Font Propo";
        theme.monoFontFamily = "FiraCode Nerd Font Mono";
        theme.bodyFontFamily = "Outfit";
        theme.barPosition = "right";
        theme.barItems = theme.builtinBarItems();
        theme.osdPosition = "centre-top";
        theme.osdOffsetX = 0;
        theme.osdOffsetY = 0;
        theme.notificationPosition = "top-left";
        theme.notificationOffsetX = 0;
        theme.notificationOffsetY = 0;
        return theme.themeId;
    }

    function resetWidgets() {
        theme.widgetProfile = "minimal";
        theme.widgetOpacity = 0.3;
        theme.widgetPadding = 20;
        theme.widgetRadius = 0;
        theme.widgetFontSize = 14;
        theme.widgetItems = [];
        return theme.widgetProfile;
    }

    function loadWidgets(raw) {
        try {
            const data = JSON.parse(raw);
            if (data.schema_version !== 1 || !data.profile)
                throw new Error("unsupported or incomplete widget profile");

            theme.widgetProfile = data.profile;
            theme.widgetOpacity = data.opacity;
            theme.widgetPadding = data.padding;
            theme.widgetRadius = data.radius;
            theme.widgetFontSize = data.font_size;
            theme.widgetItems = data.items || [];
            return true;
        } catch (error) {
            console.warn("[blox.theme] rejected widget profile: " + error);
            return false;
        }
    }

    function loadJson(raw) {
        try {
            const data = JSON.parse(raw);
            if (data.schema_version !== 1 || !data.id || !data.colours || !data.compatibility || !data.fonts)
                throw new Error("unsupported or incomplete theme document");

            theme.themeId = data.id;
            theme.activeThemeId = data.id;
            theme.variant = data.variant;
            theme.background = data.colours.background;
            theme.surface = data.colours.surface;
            theme.surfaceAlt = data.colours.surface_alt;
            theme.foreground = data.colours.foreground;
            theme.muted = data.colours.muted;
            theme.red = data.compatibility.red;
            theme.green = data.compatibility.green;
            theme.yellow = data.compatibility.yellow;
            theme.accent = data.colours.accent;
            theme.blue = data.compatibility.blue;
            theme.mauve = data.compatibility.mauve;
            theme.teal = data.compatibility.teal;
            theme.selectionForeground = data.colours.selection_foreground;
            theme.border = data.colours.border;
            theme.fontFamily = data.fonts.panel;
            theme.monoFontFamily = data.fonts.mono;
            theme.bodyFontFamily = data.fonts.ui;
            loadShell(data.shell);
            if (data.widgets)
                loadWidgetSource(data.widgets.profile);

            return true;
        } catch (error) {
            console.warn("[blox.theme] rejected generated theme: " + error);
            return false;
        }
    }

    function loadWidgetSource(profile) {
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

    function loadShell(shell) {
        const data = shell || {
        };
        const osd = data.osd || {
        };
        const notifications = data.notifications || {
        };
        theme.barPosition = data.bar && data.bar.position ? data.bar.position : "left";
        theme.barItems = defaults.resolvedBarItems(data.bar && data.bar.items ? data.bar.items : []);
        theme.osdPosition = osd.position || "top-left";
        theme.osdOffsetX = osd.offset_x || 0;
        theme.osdOffsetY = osd.offset_y || 0;
        theme.notificationPosition = notifications.position || "bottom-right";
        theme.notificationOffsetX = notifications.offset_x || 0;
        theme.notificationOffsetY = notifications.offset_y || 0;
        return true;
    }

    function loadActiveIdentity(raw) {
        try {
            const data = JSON.parse(raw);
            if (data.schema_version !== 1 || !data.id)
                throw new Error("unsupported or incomplete theme document");

            theme.activeThemeId = data.id;
            return true;
        } catch (error) {
            console.warn("[blox.theme] rejected active theme identity: " + error);
            return false;
        }
    }

    function previewSource(raw) {
        try {
            const data = typeof raw === "string" ? JSON.parse(raw) : raw;
            if (data.schema_version !== 1 || !data.id || !data.colours || !data.fonts)
                throw new Error("unsupported or incomplete source theme");

            theme.previewActive = true;
            theme.previewThemeId = data.id;
            theme.themeId = data.id;
            theme.variant = data.variant;
            theme.background = data.colours.background;
            theme.surface = data.colours.surface;
            theme.surfaceAlt = data.colours.surface_alt;
            theme.foreground = data.colours.foreground;
            theme.muted = data.colours.muted;
            theme.red = data.colours.danger;
            theme.green = data.colours.success;
            theme.yellow = data.colours.warning;
            theme.accent = data.colours.accent;
            theme.blue = data.colours.info;
            theme.mauve = data.colours.mauve;
            theme.teal = data.colours.teal;
            theme.selectionForeground = data.colours.selection_foreground;
            theme.border = data.colours.border;
            theme.fontFamily = data.fonts.panel;
            theme.monoFontFamily = data.fonts.mono;
            theme.bodyFontFamily = data.fonts.ui;
            loadShell(data.shell);
            loadWidgetSource(data.widgets ? data.widgets.profile : "minimal");
            if (data.widgets && data.widgets.items)
                theme.widgetItems = data.widgets.items;

            return true;
        } catch (error) {
            console.warn("[blox.theme] rejected source preview: " + error);
            return false;
        }
    }

}
