import "../shared"
import QtQuick

QtObject {
    id: root

    required property var host
    property string backend: "matugen"
    property bool generateAfterLoad: false
    property string newThemeName: ""
    property string newThemeId: ""
    property string newWallpaper: ""
    property string newFlowPage: "name"
    property var paletteOptions: []
    property int paletteRequestSerial: 0
    property string paletteRequestPath: ""
    property bool paletteLoading: false
    property bool creationBusy: false
    property var creationRequest: null
    property string downloadTarget: ""
    property string downloadFile: ""
    property bool downloadArchive: false

    function generatedFiles() {
        if (!host.candidate || !host.candidate.targets)
            return [];

        const files = {
            "quickshell": ["quickshell/theme.json"],
            "widgets": ["widgets/profile.json"],
            "kitty": ["kitty/theme.conf"],
            "wallpaper": ["hypr/wallpaper.json"],
            "gtk": ["gtk/gtk-3.0/settings.ini", "gtk/gtk-3.0/gtk.css", "gtk/gtk-4.0/settings.ini", "gtk/gtk-4.0/gtk.css", "gtk/metadata.json"],
            "cursor": ["cursor/metadata.json"],
            "hyprland": ["hyprland/theme.lua"],
            "hyprlock": ["hyprlock/theme.conf"],
            "btop": ["btop/theme.theme"],
            "micro": ["micro/blox-theme.micro"],
            "glow": ["glow/style.json"],
            "code": ["code/settings.json", "code/package.json", "code/themes/blox-dark-2026.json"],
            "cursor_editor": ["cursor-editor/settings.json"],
            "stylus": ["stylus/blox-system.user.css"],
            "obsidian": ["obsidian/style-settings.json"],
            "powerlevel10k": ["powerlevel10k/theme.zsh"]
        };
        const order = ["stylus"].concat(host.targetKeys.filter((target) => {
            return target !== "stylus";
        }));
        const result = [];
        for (const target of order) {
            if (!host.candidate.targets[target] || !files[target])
                continue;

            for (const file of files[target]) result.push({
                "target": target,
                "file": file,
                "name": file.slice(file.lastIndexOf("/") + 1)
            })
        }
        return result;
    }

    function generatedFileGroups() {
        const flatFiles = generatedFiles();
        const result = [];
        for (const file of flatFiles) {
            let group = null;
            for (const candidateGroup of result) {
                if (candidateGroup.target === file.target) {
                    group = candidateGroup;
                    break;
                }
            }
            if (group === null) {
                group = {
                    "target": file.target,
                    "files": []
                };
                result.push(group);
            }
            group.files.push(file);
        }
        return result;
    }

    function downloadFileTo(target, file) {
        if (host.busy)
            return ;

        downloadTarget = target;
        downloadFile = file;
        downloadArchive = false;
        host.host.dialogs.openGeneratedExport();
    }

    function downloadTargetArchive(target) {
        if (host.busy)
            return ;

        downloadTarget = target;
        downloadFile = target + "-generated-files.zip";
        downloadArchive = true;
        host.host.dialogs.openGeneratedExport();
    }

    function generate(wallpaper, displayName, themeId, requestedBackend) {
        if (!wallpaper || !wallpaper.trim()) {
            host.errorMessage = "Choose a wallpaper first.";
            return ;
        }
        const selectedBackend = requestedBackend || backend;
        const args = ["generate", wallpaper.trim(), "--backend", selectedBackend];
        if (displayName)
            args.push("--name", displayName.trim());

        if (themeId)
            args.push("--id", themeId.trim());

        if (host.runApi("generate", args))
            host.activeRequest.inputs = {
            "wallpaper": wallpaper.trim(),
            "name": displayName || "",
            "id": themeId || "",
            "backend": selectedBackend
        };

    }

    function requestPalettes() {
        const path = newWallpaper.trim();
        paletteRequestSerial += 1;
        paletteRequestPath = path;
        paletteOptions = [];
        if (!path) {
            paletteLoading = false;
            return ;
        }
        paletteLoading = true;
        if (host.runApi("palette", ["palette", path]))
            host.activeRequest.inputs = {
            "wallpaper": path,
            "paletteSerial": paletteRequestSerial
        };
        else
            paletteLoading = false;
    }

    function loadActive() {
        generateAfterLoad = false;
        return host.runApi("show-generate-current", ["show", Theme.activeThemeId]);
    }

    function continueQueued() {
        if (!generateAfterLoad || host.busy || !host.open)
            return ;

        if (host.dirty) {
            generateAfterLoad = false;
            host.showModal("generate-current");
            return ;
        }
        loadActive();
    }

    function requestCurrent() {
        host.openPicker();
        if (host.dirty) {
            host.showModal("generate-current");
            return "confirmation-required";
        }
        if (!host.busy)
            openNew(true);

        return host.busy ? "queued" : "choose-wallpaper";
    }

    function openNew(wallpaperPage) {
        if (host.busy || host.dirty)
            return ;

        newThemeName = "";
        newThemeId = host.duplicateIdForName(newThemeName);
        newWallpaper = "";
        newFlowPage = wallpaperPage ? "wallpaper" : "blank";
        paletteOptions = [];
        paletteLoading = false;
        creationBusy = false;
        creationRequest = null;
        host.showModal("new");
    }

    function blankTheme(template, inputs) {
        const blank = JSON.parse(JSON.stringify(template));
        blank.id = inputs.id;
        blank.name = inputs.name;
        blank.variant = "light";
        delete blank.generator;
        blank.colours = {
            "background": "#ffffff",
            "surface": "#ffffff",
            "surface_alt": "#f2f2f2",
            "foreground": "#000000",
            "muted": "#595959",
            "accent": "#005fcc",
            "danger": "#b00020",
            "success": "#137333",
            "warning": "#8a4b00",
            "info": "#005fcc",
            "mauve": "#6f42c1",
            "teal": "#00796b",
            "selection_background": "#000000",
            "selection_foreground": "#ffffff",
            "border": "#b3b3b3"
        };
        blank.terminal = {
            "ansi_source": "override",
            "canvas": "#ffffff",
            "chrome_background": "#f2f2f2"
        };
        if (!blank.overrides)
            blank.overrides = {
        };

        blank.overrides.ansi = {
            "color0": "#000000",
            "color1": "#800000",
            "color2": "#008000",
            "color3": "#808000",
            "color4": "#000080",
            "color5": "#800080",
            "color6": "#008080",
            "color7": "#c0c0c0",
            "color8": "#808080",
            "color9": "#ff0000",
            "color10": "#00ff00",
            "color11": "#ffff00",
            "color12": "#0000ff",
            "color13": "#ff00ff",
            "color14": "#00ffff",
            "color15": "#ffffff"
        };
        blank.wallpaper = {
            "fit": "cover",
            "path": "~/Pictures/wallpapers/blank-light.png"
        };
        blank.targets.wallpaper = true;
        return blank;
    }

    function startNew(fromWallpaper) {
        if (!newThemeName.trim() || !newThemeId.trim())
            return ;

        if (fromWallpaper && !newWallpaper.trim()) {
            host.errorMessage = "Choose a wallpaper first.";
            return ;
        }
        creationRequest = {
            "wallpaper": newWallpaper.trim(),
            "name": newThemeName.trim(),
            "id": newThemeId.trim(),
            "backend": backend
        };
        creationBusy = true;
        host.errorMessage = "";
        if (fromWallpaper)
            generate(creationRequest.wallpaper, creationRequest.name, creationRequest.id, creationRequest.backend);
        else if (host.runApi("new-template", ["show", "catppuccin-mocha"]))
            host.activeRequest.inputs = creationRequest;
    }

}
