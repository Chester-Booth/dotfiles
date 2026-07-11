import "../shared"
import QtQuick
import QtQuick.Controls
import QtQuick.Dialogs
import QtQuick.Layouts
import Quickshell
import Quickshell.Io

FloatingWindow {
    id: root

    property bool open: false
    property bool rendered: false
    property bool busy: false
    property string action: ""
    property string processOutput: ""
    property string processError: ""
    property var themes: []
    property var candidate: null
    property int candidateRevision: 0
    property int sessionRevision: 0
    property int requestSerial: 0
    property var activeRequest: null
    property bool validationPending: false
    property string baselineJson: ""
    property string sourceDigest: ""
    property string selectedId: ""
    property var previewData: ({
    })
    property var apiWarnings: []
    property var validationErrors: []
    property bool candidateValid: false
    property string statusMessage: ""
    property string errorMessage: ""
    property string searchText: ""
    property string editorMode: "overview"
    property string generatorBackend: "matugen"
    property string pendingAfterSave: ""
    property string pendingSelection: ""
    property string modalKind: ""
    property string pendingModalConfirmation: ""
    property bool generateAfterLoad: false
    property string duplicateId: ""
    property string duplicateName: ""
    property string renameName: ""
    property string modalThemeId: ""
    property string modalThemeName: ""
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
    property var applyProgressRows: []
    property bool applyProgressComplete: false
    property string guideTarget: ""
    property var widgetDraft: null
    property int widgetEditIndex: -1
    property int selectedWidgetIndex: -1
    property bool exportIncludeWallpaper: true
    property bool exportIncludeWidgets: true
    property string wallpaperDialogTarget: "overview"
    property var fontFamilies: []
    property string fontOutput: ""
    property bool colourPickerOpen: false
    property string colourPickerKey: ""
    property string colourPickerTarget: ""
    property var focusBeforeOverlay: null
    property real colourHue: 0
    property real colourSaturation: 0
    property real colourValue: 1
    property string colourHex: "#ffffff"
    readonly property bool dirty: candidate !== null && JSON.stringify(candidate) !== baselineJson
    readonly property string apiPath: Quickshell.shellDir + "/scripts/theme/themectl.sh"
    readonly property var semanticKeys: ["background", "surface", "surface_alt", "foreground", "muted", "accent", "danger", "success", "warning", "info", "mauve", "teal", "selection_background", "selection_foreground", "border"]
    readonly property var ansiKeys: ["color0", "color1", "color2", "color3", "color4", "color5", "color6", "color7", "color8", "color9", "color10", "color11", "color12", "color13", "color14", "color15"]
    readonly property var overrideKeys: ["background", "foreground", "accent", "border"]
    readonly property var targetKeys: ["quickshell", "vicinae", "widgets", "gtk", "cursor", "wallpaper", "kitty", "hyprland", "hyprlock", "btop", "micro", "glow", "code", "cursor_editor", "stylus", "obsidian", "powerlevel10k", "sddm", "grub"]
    readonly property var unavailableTargetKeys: ["sddm", "grub"]
    readonly property var coreTargetKeys: ["quickshell", "widgets", "wallpaper", "hyprland", "hyprlock", "cursor"]
    readonly property var applicationTargetKeys: ["vicinae", "kitty", "gtk", "btop", "micro", "glow", "code", "cursor_editor", "stylus", "obsidian", "powerlevel10k"]

    function targetAvailable(key) {
        return unavailableTargetKeys.indexOf(key) < 0;
    }

    function targetLabel(key) {
        if (key === "sddm" || key === "grub")
            return key + " · unavailable";

        return key;
    }

    function targetApplyMode(key) {
        if (key === "stylus" || key === "obsidian")
            return "manual";

        if (["gtk", "cursor", "hyprlock", "btop", "micro", "glow", "code", "cursor_editor", "powerlevel10k"].indexOf(key) >= 0)
            return "restart";

        return "automatic";
    }

    function targetModeLabel(key) {
        const mode = targetApplyMode(key);
        return mode === "manual" ? "Apply Manually" : mode === "restart" ? (key === "code" || key === "cursor_editor" ? "Reload Window" : "Restart Needed") : "Automatic";
    }

    function cloneCandidate() {
        return candidate === null ? null : JSON.parse(JSON.stringify(candidate));
    }

    function swatchText(colour) {
        const value = String(colour || "#000000").replace("#", "");
        if (value.length !== 6)
            return Theme.foreground;

        const red = parseInt(value.slice(0, 2), 16);
        const green = parseInt(value.slice(2, 4), 16);
        const blue = parseInt(value.slice(4, 6), 16);
        return (red * 299 + green * 587 + blue * 114) / 1000 > 145 ? "#111111" : "#f5f5f5";
    }

    function themeDigest(id) {
        for (let index = 0; index < themes.length; ++index) {
            if (themes[index].id === id)
                return themes[index].source_sha256 || "";

        }
        return "";
    }

    function duplicateIdForName(name) {
        let stem = String(name || "").trim().toLowerCase().replace(/[^a-z0-9]+/g, "-").replace(/^-+|-+$/g, "");
        if (!stem)
            stem = "theme";

        stem = stem.slice(0, 64).replace(/-+$/g, "");
        let id = stem;
        let suffix = 2;
        const exists = (value) => {
            return themes.some((entry) => {
                return entry.id === value;
            });
        };
        while (exists(id)) {
            const ending = "-" + suffix;
            id = stem.slice(0, 64 - ending.length).replace(/-+$/g, "") + ending;
            suffix += 1;
        }
        return id;
    }

    function filteredThemes() {
        const needle = searchText.trim().toLowerCase();
        const entries = themes.slice();
        if (candidate && !sourceDigest && !entries.some((entry) => {
            return entry.id === candidate.id;
        }))
            entries.unshift({
            "id": candidate.id,
            "name": candidate.name,
            "variant": candidate.variant,
            "unsaved": true
        });

        if (!needle)
            return entries;

        return entries.filter((entry) => {
            return String(entry.id + " " + entry.name).toLowerCase().indexOf(needle) >= 0;
        });
    }

    function componentHex(value) {
        return Math.round(Math.max(0, Math.min(255, value))).toString(16).padStart(2, "0");
    }

    function hsvHex(hue, saturation, value) {
        const sector = ((hue % 1) + 1) % 1 * 6;
        const chroma = value * saturation;
        const intermediate = chroma * (1 - Math.abs(sector % 2 - 1));
        const offset = value - chroma;
        let red = 0;
        let green = 0;
        let blue = 0;
        if (sector < 1) {
            red = chroma;
            green = intermediate;
        } else if (sector < 2) {
            red = intermediate;
            green = chroma;
        } else if (sector < 3) {
            green = chroma;
            blue = intermediate;
        } else if (sector < 4) {
            green = intermediate;
            blue = chroma;
        } else if (sector < 5) {
            red = intermediate;
            blue = chroma;
        } else {
            red = chroma;
            blue = intermediate;
        }
        return "#" + componentHex((red + offset) * 255) + componentHex((green + offset) * 255) + componentHex((blue + offset) * 255);
    }

    function loadPickerColour(value) {
        const hex = String(value || "#ffffff").replace("#", "");
        const red = parseInt(hex.slice(0, 2), 16) / 255;
        const green = parseInt(hex.slice(2, 4), 16) / 255;
        const blue = parseInt(hex.slice(4, 6), 16) / 255;
        const maximum = Math.max(red, green, blue);
        const minimum = Math.min(red, green, blue);
        const delta = maximum - minimum;
        let hue = 0;
        if (delta > 0) {
            if (maximum === red)
                hue = ((green - blue) / delta % 6) / 6;
            else if (maximum === green)
                hue = ((blue - red) / delta + 2) / 6;
            else
                hue = ((red - green) / delta + 4) / 6;
        }
        colourHue = hue < 0 ? hue + 1 : hue;
        colourSaturation = maximum === 0 ? 0 : delta / maximum;
        colourValue = maximum;
        colourHex = "#" + hex.toLowerCase();
    }

    function openColourPicker(key, target) {
        if (!candidate)
            return ;

        colourPickerKey = key;
        colourPickerTarget = target || "";
        const overrideValues = target && candidate.overrides ? candidate.overrides[target] : null;
        const value = overrideValues && overrideValues[key] ? overrideValues[key] : candidate.colours[key];
        loadPickerColour(value);
        rememberOverlayFocus();
        colourPickerOpen = true;
        Qt.callLater(() => {
            colourHexField.focusEditor(true);
        });
    }

    function rememberOverlayFocus() {
        focusBeforeOverlay = root.contentItem.QsWindow.window.activeFocusItem;
    }

    function restoreOverlayFocus() {
        try {
            if (focusBeforeOverlay && focusBeforeOverlay.visible && focusBeforeOverlay.enabled)
                focusBeforeOverlay.forceActiveFocus();

        } catch (error) {
        }
        focusBeforeOverlay = null;
    }

    function focusModal() {
        if (modalKind === "new") {
            if (newFlowPage === "wallpaper")
                newWallpaperField.focusEditor(true);
            else
                newNameField.focusEditor(true);
        } else if (modalKind === "duplicate")
            duplicateNameField.focusEditor(true);
        else if (modalKind === "widget")
            widgetNameField.focusEditor(true);
        else if (modalKind === "rename")
            renameNameField.focusEditor(true);
        else if (modalCancelButton.visible)
            modalCancelButton.forceActiveFocus();
        else
            modalFocusScope.forceActiveFocus();
    }

    function showModal(kind) {
        rememberOverlayFocus();
        modalKind = kind;
        Qt.callLater(focusModal);
    }

    function modalConfirmationEnabled() {
        if (modalKind === "duplicate")
            return duplicateId.trim().length > 0 && duplicateName.trim().length > 0;

        if (modalKind === "rename")
            return renameName.trim().length > 0;

        return true;
    }

    function applyPickerColour(value) {
        if (!/^#[0-9a-fA-F]{6}$/.test(value))
            return ;

        colourHex = value.toLowerCase();
        if (colourPickerTarget)
            setOverride(colourPickerTarget, colourPickerKey, colourHex);
        else
            setColour(colourPickerKey, colourHex);
    }

    function updatePickerColour() {
        applyPickerColour(hsvHex(colourHue, colourSaturation, colourValue));
    }

    function runApi(nextAction, args) {
        if (busy) {
            errorMessage = "Another theme action is still running.";
            return false;
        }
        action = nextAction;
        requestSerial += 1;
        activeRequest = {
            "serial": requestSerial,
            "sessionRevision": sessionRevision,
            "action": nextAction,
            "candidateRevision": candidateRevision,
            "candidateJson": candidate === null ? "" : JSON.stringify(candidate)
        };
        processOutput = "";
        processError = "";
        errorMessage = "";
        busy = true;
        apiProcess.command = [apiPath].concat(args).concat(["--json"]);
        apiProcess.running = true;
        return true;
    }

    function refreshThemes(refreshOnly) {
        runApi(refreshOnly ? "list-refresh" : "list", ["list"]);
    }

    function openPicker() {
        open = true;
        rendered = true;
        statusMessage = "Loading themes…";
        if (themes.length === 0)
            refreshThemes(false);
        else if (candidate === null)
            requestSelection(Theme.activeThemeId, false);
        return "open";
    }

    function requestClose() {
        if (busy && action !== "preview-edit")
            return "busy";

        if (dirty) {
            showModal("close");
            return "confirmation-required";
        }
        closePicker();
        return "closed";
    }

    function closePicker() {
        sessionRevision += 1;
        validationPending = false;
        validationDelay.stop();
        Theme.cancelPreview();
        open = false;
        modalKind = "";
        candidate = null;
        candidateRevision += 1;
        selectedId = "";
        sourceDigest = "";
        baselineJson = "";
        candidateValid = false;
        validationErrors = [];
        pendingAfterSave = "";
        pendingSelection = "";
        pendingModalConfirmation = "";
        generateAfterLoad = false;
        focusBeforeOverlay = null;
        hideTimer.restart();
    }

    function requestSelection(id, confirmDirty) {
        if (!id || id === selectedId && candidate !== null)
            return ;

        if (confirmDirty && dirty) {
            pendingSelection = id;
            showModal("navigate");
            return ;
        }
        runApi("show", ["show", id]);
    }

    function validatePreview() {
        if (candidate === null)
            return ;

        if (busy) {
            validationPending = true;
            candidateValid = false;
            return ;
        }
        validationPending = false;
        runApi("preview-edit", ["preview", JSON.stringify(candidate)]);
    }

    function markCandidate(value) {
        candidate = value;
        candidateRevision += 1;
        candidateValid = false;
        validationPending = true;
        validationDelay.restart();
    }

    function setTopLevel(key, value) {
        const next = cloneCandidate();
        next[key] = value;
        markCandidate(next);
    }

    function setColour(key, value) {
        const next = cloneCandidate();
        next.colours[key] = value;
        markCandidate(next);
    }

    function setFont(key, value) {
        const next = cloneCandidate();
        next.fonts[key] = value;
        markCandidate(next);
    }

    function setWidgetProfile(value) {
        const next = cloneCandidate();
        next.widgets = {
            "profile": value
        };
        markCandidate(next);
    }

    function setTarget(key, value) {
        if (!targetAvailable(key))
            return ;

        const next = cloneCandidate();
        next.targets[key] = value;
        markCandidate(next);
    }

    function setOverride(target, key, value) {
        const next = cloneCandidate();
        if (!next.overrides)
            next.overrides = {
        };

        if (!next.overrides[target])
            next.overrides[target] = {
        };

        if (value.trim().length === 0)
            delete next.overrides[target][key];
        else
            next.overrides[target][key] = value.trim();
        if (Object.keys(next.overrides[target]).length === 0)
            delete next.overrides[target];

        if (Object.keys(next.overrides).length === 0)
            delete next.overrides;

        markCandidate(next);
    }

    function setWallpaperPath(path) {
        if (!candidate)
            return ;

        const next = cloneCandidate();
        next.wallpaper.path = String(path || "").trim();
        markCandidate(next);
    }

    function shellDefaults() {
        return {
            "bar": {
                "position": "left"
            },
            "osd": {
                "position": "top-left",
                "offset_x": 0,
                "offset_y": 0
            },
            "notifications": {
                "position": "bottom-right",
                "offset_x": 0,
                "offset_y": 0
            }
        };
    }

    function shellValue(section, key) {
        const shell = candidate && candidate.shell ? candidate.shell : shellDefaults();
        return shell[section][key];
    }

    function setShellValue(section, key, value) {
        if (!candidate)
            return ;

        const next = cloneCandidate();
        if (!next.shell)
            next.shell = shellDefaults();

        next.shell[section][key] = value;
        markCandidate(next);
        Theme.loadShell(next.shell);
        if (section === "osd")
            Theme.osdPositionPreviewRequested();
        else if (section === "notifications")
            Theme.notificationPositionPreviewRequested();
    }

    function barItems() {
        const overrides = candidate && candidate.shell && candidate.shell.bar && candidate.shell.bar.items ? candidate.shell.bar.items : [];
        return Theme.resolvedBarItems(overrides);
    }

    function normaliseBarItemOrders(items) {
        const regions = ["start", "centre", "end", "hidden"];
        for (let regionIndex = 0; regionIndex < regions.length; ++regionIndex) {
            const region = regions[regionIndex];
            const members = items.filter((item) => {
                return item.region === region;
            }).sort((left, right) => {
                return left.order - right.order;
            });
            for (let index = 0; index < members.length; ++index) members[index].order = index
        }
        return items;
    }

    function setBarItems(items) {
        const next = cloneCandidate();
        if (!next.shell)
            next.shell = shellDefaults();

        if (!next.shell.bar)
            next.shell.bar = shellDefaults().bar;

        next.shell.bar.items = normaliseBarItemOrders(items);
        markCandidate(next);
        Theme.loadShell(next.shell);
    }

    function setBarItemEnabled(id, enabled) {
        const items = barItems();
        for (let index = 0; index < items.length; ++index) {
            if (items[index].id === id) {
                items[index].enabled = enabled;
                break;
            }
        }
        setBarItems(items);
    }

    function setBarItemRegion(id, region) {
        const items = barItems();
        let nextOrder = items.filter((item) => {
            return item.region === region;
        }).length;
        for (let index = 0; index < items.length; ++index) {
            if (items[index].id === id) {
                items[index].region = region;
                items[index].order = nextOrder;
                break;
            }
        }
        setBarItems(items);
    }

    function moveBarItem(id, direction) {
        const items = normaliseBarItemOrders(barItems());
        const selected = items.find((item) => {
            return item.id === id;
        });
        if (!selected)
            return ;

        const neighbour = items.find((item) => {
            return item.region === selected.region && item.order === selected.order + direction;
        });
        if (!neighbour)
            return ;

        const previousOrder = selected.order;
        selected.order = neighbour.order;
        neighbour.order = previousOrder;
        setBarItems(items);
    }

    function barItemLabel(id) {
        const labels = {
            "bt": "Bluetooth",
            "notifications": "Notifications",
            "wifi": "Wi-Fi"
        };
        return labels[id] || id.charAt(0).toUpperCase() + id.slice(1);
    }

    function widgetItems() {
        return candidate && candidate.widgets && candidate.widgets.items ? candidate.widgets.items : Theme.defaultWidgetItems();
    }

    function setWidgetItems(items) {
        const next = cloneCandidate();
        if (!next.widgets)
            next.widgets = {
            "profile": "minimal"
        };

        next.widgets.items = items;
        markCandidate(next);
    }

    function updateWidgetGeometry(index, anchor, offsetX, offsetY, width, height) {
        const items = widgetItems().slice();
        if (index < 0 || index >= items.length)
            return ;

        const item = JSON.parse(JSON.stringify(items[index]));
        item.anchor = anchor;
        item.offset_x = Math.max(-10000, Math.min(10000, Math.round(offsetX)));
        item.offset_y = Math.max(-10000, Math.min(10000, Math.round(offsetY)));
        item.width = Math.max(80, Math.round(width));
        item.height = Math.max(48, Math.round(height));
        items[index] = item;
        setWidgetItems(items);
    }

    function commitWidgetPreview(index, previewX, previewY, previewWidth, previewHeight, canvasWidth, canvasHeight) {
        const virtualWidth = 1920;
        const virtualHeight = 1080;
        const x = previewX * virtualWidth / canvasWidth;
        const y = previewY * virtualHeight / canvasHeight;
        const width = previewWidth * virtualWidth / canvasWidth;
        const height = previewHeight * virtualHeight / canvasHeight;
        const centreX = x + width / 2;
        const centreY = y + height / 2;
        let anchor = "centre";
        let offsetX = x - (virtualWidth - width) / 2;
        let offsetY = y - (virtualHeight - height) / 2;
        if (Math.abs(centreX - virtualWidth / 2) > virtualWidth * 0.16 || Math.abs(centreY - virtualHeight / 2) > virtualHeight * 0.16) {
            const right = centreX >= virtualWidth / 2;
            const bottom = centreY >= virtualHeight / 2;
            anchor = (bottom ? "bottom-" : "top-") + (right ? "right" : "left");
            offsetX = right ? virtualWidth - x - width : x;
            offsetY = bottom ? virtualHeight - y - height : y;
        }
        updateWidgetGeometry(index, anchor, offsetX, offsetY, width, height);
    }

    function newWidgetDraft(type) {
        const preset = type || "custom";
        const commands = {
            "music": "cava",
            "calendar": "gcalcli agenda",
            "clock": "tty-clock -c",
            "aquarium": "asciiquarium",
            "pipes": "pipes.sh",
            "tree": "cbonsai -l",
            "matrix": "unimatrix",
            "fortune": "fortune | cowsay",
            "train": "while true; do sl; sleep 1; done"
        };
        return {
            "id": "widget-" + (widgetItems().length + 1),
            "name": "New widget",
            "type": preset,
            "enabled": true,
            "content_command": commands[preset] || "",
            "left_click_command": "",
            "right_click_command": "",
            "interval_ms": 60000,
            "visibility": "always",
            "anchor": "top-left",
            "offset_x": 20,
            "offset_y": 20,
            "width": 0,
            "height": 0,
            "shape": "auto",
            "options": {
            }
        };
    }

    function shellQuote(value) {
        return "'" + String(value).replace(/'/g, "'\\''") + "'";
    }

    function openWidgetEditor(index) {
        widgetEditIndex = index;
        widgetDraft = index >= 0 ? JSON.parse(JSON.stringify(widgetItems()[index])) : newWidgetDraft("custom");
        showModal("widget");
    }

    function saveWidgetDraft() {
        if (!widgetDraft || !widgetDraft.name.trim() || !widgetDraft.id.trim())
            return ;

        const items = widgetItems().slice();
        if (widgetEditIndex >= 0)
            items[widgetEditIndex] = widgetDraft;
        else
            items.push(widgetDraft);
        setWidgetItems(items);
        dismissModal();
    }

    function openWallpaperDialog(target) {
        wallpaperDialogTarget = target || "overview";
        wallpaperDialog.open();
    }

    function openImportDialog() {
        if (!busy && !dirty)
            importDialog.open();

    }

    function openExportDialog() {
        if (busy || dirty || !candidate || !sourceDigest)
            return ;

        exportIncludeWallpaper = true;
        exportIncludeWidgets = true;
        showModal("export");
    }

    function downloadStylusFile() {
        if (!busy)
            stylusExportDialog.open();

    }

    function generateTheme(wallpaper, displayName, themeId, backend) {
        if (!wallpaper || !wallpaper.trim()) {
            errorMessage = "Choose a wallpaper first.";
            return ;
        }
        const args = ["generate", wallpaper.trim(), "--backend", backend || generatorBackend];
        if (displayName)
            args.push("--name", displayName.trim());

        if (themeId)
            args.push("--id", themeId.trim());

        if (runApi("generate", args))
            activeRequest.inputs = {
            "wallpaper": wallpaper.trim(),
            "name": displayName || "",
            "id": themeId || "",
            "backend": backend || generatorBackend
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
        if (runApi("palette", ["palette", path]))
            activeRequest.inputs = {
            "wallpaper": path,
            "paletteSerial": paletteRequestSerial
        };
        else
            paletteLoading = false;
    }

    function loadActiveForGeneration() {
        generateAfterLoad = false;
        return runApi("show-generate-current", ["show", Theme.activeThemeId]);
    }

    function continueQueuedGeneration() {
        if (!generateAfterLoad || busy || !open)
            return ;

        if (dirty) {
            generateAfterLoad = false;
            showModal("generate-current");
            return ;
        }
        loadActiveForGeneration();
    }

    function requestGenerateCurrent() {
        openPicker();
        if (dirty) {
            showModal("generate-current");
            return "confirmation-required";
        }
        if (!busy)
            openNewTheme(true);

        return busy ? "queued" : "choose-wallpaper";
    }

    function saveCandidate(after) {
        if (candidate === null || !candidateValid || busy)
            return ;

        pendingAfterSave = after || "";
        const args = ["save", JSON.stringify(candidate)];
        if (sourceDigest)
            args.push("--replace", "--expect-sha256", sourceDigest);

        runApi("save", args);
    }

    function applyCandidate() {
        if (candidate === null || !candidateValid || busy)
            return ;

        applyProgressComplete = false;
        applyProgressRows = targetKeys.filter((key) => {
            return candidate.targets[key] && targetAvailable(key);
        }).map((key) => {
            return ({
                "target": key,
                "state": "running",
                "message": "generating files"
            });
        });
        showModal("progress");
        if (dirty || !sourceDigest) {
            saveCandidate("apply");
            return ;
        }
        runApi("apply", ["apply", candidate.id]);
    }

    function revertCandidate() {
        if (!baselineJson)
            return ;

        candidate = JSON.parse(baselineJson);
        candidateRevision += 1;
        candidateValid = true;
        validationErrors = [];
        Theme.previewSource(candidate);
        statusMessage = "Unsaved changes reverted.";
    }

    function openNewTheme(wallpaperPage) {
        if (busy || dirty)
            return ;

        newThemeName = "";
        newThemeId = duplicateIdForName(newThemeName);
        newWallpaper = "";
        newFlowPage = wallpaperPage ? "wallpaper" : "blank";
        paletteOptions = [];
        paletteLoading = false;
        creationBusy = false;
        creationRequest = null;
        showModal("new");
    }

    function startNewTheme(fromWallpaper) {
        if (!newThemeName.trim() || !newThemeId.trim())
            return ;

        if (fromWallpaper && !newWallpaper.trim()) {
            errorMessage = "Choose a wallpaper first.";
            return ;
        }
        creationRequest = {
            "wallpaper": newWallpaper.trim(),
            "name": newThemeName.trim(),
            "id": newThemeId.trim(),
            "backend": generatorBackend
        };
        creationBusy = true;
        errorMessage = "";
        if (fromWallpaper)
            generateTheme(creationRequest.wallpaper, creationRequest.name, creationRequest.id, creationRequest.backend);
        else if (runApi("new-template", ["show", "blox-panel"]))
            activeRequest.inputs = creationRequest;
    }

    function openDuplicate(themeId, themeName) {
        const sourceId = themeId || (candidate ? candidate.id : "");
        if (!sourceId || sourceId === selectedId && dirty)
            return ;

        modalThemeId = sourceId;
        modalThemeName = themeName || (candidate ? candidate.name : sourceId);
        duplicateName = modalThemeName + " Copy";
        duplicateId = duplicateIdForName(duplicateName);
        showModal("duplicate");
    }

    function openRename(themeId, themeName) {
        const sourceId = themeId || (candidate ? candidate.id : "");
        if (!sourceId || sourceId === selectedId && dirty)
            return ;

        modalThemeId = sourceId;
        modalThemeName = themeName || (candidate ? candidate.name : sourceId);
        renameName = modalThemeName;
        showModal("rename");
    }

    function requestDelete(themeId, themeName) {
        const sourceId = themeId || (candidate ? candidate.id : "");
        if (!sourceId || sourceId === "blox-panel" || sourceId === selectedId && dirty)
            return ;

        modalThemeId = sourceId;
        modalThemeName = themeName || (candidate ? candidate.name : sourceId);
        showModal("delete");
    }

    function dismissModal() {
        pendingModalConfirmation = "";
        modalDismissTimer.restart();
    }

    function confirmModal() {
        pendingModalConfirmation = modalKind;
        modalDismissTimer.restart();
    }

    function completeModalDismissal() {
        const kind = pendingModalConfirmation;
        pendingModalConfirmation = "";
        modalKind = "";
        Qt.callLater(restoreOverlayFocus);
        if (!kind)
            return ;

        if (kind === "navigate") {
            Theme.cancelPreview();
            baselineJson = candidate === null ? "" : JSON.stringify(candidate);
            const id = pendingSelection;
            pendingSelection = "";
            requestSelection(id, false);
        } else if (kind === "close")
            closePicker();
        else if (kind === "delete")
            runApi("delete", ["delete", modalThemeId, "--yes"]);
        else if (kind === "duplicate")
            runApi("duplicate", ["duplicate", modalThemeId, duplicateId.trim(), "--name", duplicateName.trim()]);
        else if (kind === "rename")
            runApi("rename", ["rename", modalThemeId, renameName.trim()]);
        else if (kind === "new-wallpaper")
            generateTheme(newWallpaper, newThemeName, newThemeId);
        else if (kind === "new-blank")
            runApi("new-template", ["show", "blox-panel"]);
        else if (kind === "export")
            exportDialog.open();
        else if (kind === "generate-current")
            loadActiveForGeneration();
    }

    function dismissColourPicker() {
        colourDismissTimer.restart();
    }

    function handleResponse(request, response) {
        const completedAction = request.action;
        const failed = !response || response.ok !== true;
        if (completedAction === "palette") {
            paletteLoading = false;
            if (!request.inputs || request.inputs.paletteSerial !== paletteRequestSerial || request.inputs.wallpaper !== newWallpaper.trim()) {
                paletteDelay.restart();
                return ;
            }
            paletteOptions = response && response.data ? response.data : [];
            apiWarnings = response && response.warnings ? response.warnings : [];
            if (failed) {
                errorMessage = response && response.errors ? response.errors.join("\n") : "Palette preview failed.";
            } else if (!paletteOptions.some((entry) => {
                return entry.available && entry.backend === generatorBackend;
            })) {
                const available = paletteOptions.find((entry) => {
                    return entry.available;
                });
                if (available)
                    generatorBackend = available.backend;

            }
            return ;
        }
        if (completedAction === "widgets-import") {
            if (!failed && response.data) {
                const next = cloneCandidate();
                next.widgets = response.data;
                markCandidate(next);
                statusMessage = "Widget configuration imported.";
            }
            return ;
        }
        if (completedAction === "preview-edit") {
            if (candidate === null || request.candidateRevision !== candidateRevision || request.candidateJson !== JSON.stringify(candidate)) {
                validationPending = candidate !== null;
                candidateValid = false;
                return ;
            }
            candidateValid = !failed;
            validationErrors = response && response.errors ? response.errors : ["Preview validation failed."];
            apiWarnings = response && response.warnings ? response.warnings : [];
            previewData = response && response.data ? response.data : ({
            });
            if (!failed) {
                Theme.previewSource(JSON.parse(request.candidateJson));
                statusMessage = dirty ? "Temporary Quickshell preview — unsaved" : "Temporary Quickshell preview";
            }
            return ;
        }
        if (failed) {
            errorMessage = response && response.errors ? response.errors.join("\n") : "Theme action failed.";
            if (completedAction === "generate" || completedAction === "new-template")
                creationBusy = false;

            if (completedAction === "apply") {
                applyProgressComplete = true;
                applyProgressRows = applyProgressRows.map((entry) => {
                    return ({
                        "target": entry.target,
                        "state": "failed",
                        "message": "failed"
                    });
                });
            }
            return ;
        }
        apiWarnings = response.warnings || [];
        if (completedAction === "list" || completedAction === "list-refresh") {
            themes = response.data || [];
            if (completedAction === "list") {
                const preferred = themes.some((entry) => {
                    return entry.id === Theme.activeThemeId;
                }) ? Theme.activeThemeId : (themes.length > 0 ? themes[0].id : "");
                if (preferred)
                    requestSelection(preferred, false);

            }
        } else if (completedAction === "show") {
            candidate = JSON.parse(JSON.stringify(response.data));
            selectedId = candidate.id;
            sourceDigest = themeDigest(candidate.id);
            baselineJson = JSON.stringify(candidate);
            candidateRevision += 1;
            if (generateAfterLoad) {
                generateAfterLoad = false;
                generateTheme(candidate.wallpaper.path);
            } else {
                validatePreview();
            }
        } else if (completedAction === "show-generate-current") {
            generateAfterLoad = false;
            generateTheme(response.data.wallpaper.path);
        } else if (completedAction === "generate") {
            candidate = JSON.parse(JSON.stringify(response.data.theme));
            selectedId = candidate.id;
            sourceDigest = "";
            baselineJson = "";
            previewData = response.data;
            candidateRevision += 1;
            creationBusy = false;
            modalKind = "";
            Qt.callLater(restoreOverlayFocus);
            validatePreview();
        } else if (completedAction === "new-template") {
            const blank = JSON.parse(JSON.stringify(response.data));
            blank.id = request.inputs.id;
            blank.name = request.inputs.name;
            delete blank.generator;
            candidate = blank;
            selectedId = candidate.id;
            sourceDigest = "";
            baselineJson = "";
            candidateRevision += 1;
            creationBusy = false;
            modalKind = "";
            Qt.callLater(restoreOverlayFocus);
            validatePreview();
        } else if (completedAction === "save") {
            sourceDigest = response.data.source_sha256;
            selectedId = candidate.id;
            baselineJson = JSON.stringify(candidate);
            candidateRevision += 1;
            statusMessage = "Theme source saved.";
            if (pendingAfterSave === "apply") {
                pendingAfterSave = "";
                runApi("apply", ["apply", candidate.id]);
            } else {
                refreshThemes(true);
            }
        } else if (completedAction === "apply") {
            Theme.reload();
            baselineJson = JSON.stringify(candidate);
            candidateRevision += 1;
            statusMessage = "Theme applied. Some applications may require restart.";
            applyProgressComplete = true;
            applyProgressRows = applyProgressRows.map((entry) => {
                const mode = targetApplyMode(entry.target);
                const editorName = entry.target === "code" ? "Code" : entry.target === "cursor_editor" ? "Cursor" : "";
                const editorFailure = editorName && (response.warnings || []).find((warning) => {
                    return String(warning).indexOf(editorName + " settings were not changed:") >= 0;
                });
                if (editorFailure)
                    return {
                    "target": entry.target,
                    "state": "failed",
                    "message": "Could not apply automatically"
                };

                return {
                    "target": entry.target,
                    "state": mode === "manual" ? "manual" : mode === "restart" ? "restart" : "applied",
                    "message": mode === "manual" ? "Apply Manually" : mode === "restart" ? targetModeLabel(entry.target) : "Applied"
                };
            });
            refreshThemes(true);
        } else if (completedAction === "duplicate") {
            statusMessage = "Theme duplicated.";
            pendingSelection = response.data.id;
            runApi("list-after-duplicate", ["list"]);
        } else if (completedAction === "list-after-duplicate") {
            themes = response.data || [];
            const id = pendingSelection;
            pendingSelection = "";
            requestSelection(id, false);
        } else if (completedAction === "rename") {
            if (response.data.id === selectedId) {
                candidate.name = response.data.name;
                sourceDigest = response.data.source_sha256;
                baselineJson = JSON.stringify(candidate);
                candidateRevision += 1;
            }
            statusMessage = "Display name changed; stable ID preserved.";
            refreshThemes(true);
        } else if (completedAction === "delete") {
            if (response.data.id === selectedId) {
                Theme.cancelPreview();
                candidate = null;
                selectedId = "";
                sourceDigest = "";
                baselineJson = "";
            }
            statusMessage = "Theme deleted.";
            refreshThemes(candidate !== null);
        } else if (completedAction === "import") {
            statusMessage = "Theme imported. Apply remains a separate action.";
            pendingSelection = response.data.id;
            runApi("list-after-import", ["list"]);
        } else if (completedAction === "list-after-import") {
            themes = response.data || [];
            const id = pendingSelection;
            pendingSelection = "";
            requestSelection(id, false);
        } else if (completedAction === "export") {
            statusMessage = "Theme exported to " + response.data.path;
        }
    }

    title: "Blox Theme Picker"
    implicitWidth: 1320
    implicitHeight: 860
    minimumSize: Qt.size(960, 680)
    visible: rendered
    color: "transparent"
    onClosed: root.closePicker()
    onOpenChanged: {
        if (open)
            rendered = true;
        else
            hideTimer.restart();
    }

    Timer {
        id: hideTimer

        interval: 180
        repeat: false
        onTriggered: {
            if (!root.open)
                root.rendered = false;

        }
    }

    Timer {
        id: modalDismissTimer

        interval: 80
        repeat: false
        onTriggered: root.completeModalDismissal()
    }

    Timer {
        id: colourDismissTimer

        interval: 80
        repeat: false
        onTriggered: root.colourPickerOpen = false
    }

    Timer {
        id: validationDelay

        interval: 300
        repeat: false
        onTriggered: root.validatePreview()
    }

    Timer {
        id: paletteDelay

        interval: 350
        repeat: false
        onTriggered: root.requestPalettes()
    }

    Process {
        id: apiProcess

        onExited: (exitCode, exitStatus) => {
            const request = root.activeRequest;
            root.activeRequest = null;
            root.busy = false;
            if (!request || request.sessionRevision !== root.sessionRevision) {
                if (root.open && root.candidate === null) {
                    if (root.themes.length === 0)
                        root.refreshThemes(false);
                    else
                        root.requestSelection(Theme.activeThemeId, false);
                }
                return ;
            }
            let response = null;
            try {
                response = JSON.parse(root.processOutput.trim());
            } catch (error) {
                root.errorMessage = "Theme API returned invalid JSON: " + String(error) + (root.processError ? "\n" + root.processError.trim() : "");
                if (root.validationPending && root.candidate !== null)
                    root.validationDelay.restart();

                root.continueQueuedGeneration();
                return ;
            }
            root.handleResponse(request, response);
            if (root.validationPending && root.candidate !== null)
                root.validationDelay.restart();

            root.continueQueuedGeneration();
        }

        stdout: StdioCollector {
            onStreamFinished: root.processOutput = this.text
        }

        stderr: StdioCollector {
            onStreamFinished: root.processError = this.text
        }

    }

    Process {
        id: fontProcess

        command: ["fc-list", "--format=%{family}\\n"]
        running: true
        onExited: {
            const seen = ({
            });
            const families = [];
            root.fontOutput.split("\n").forEach((line) => {
                line.split(",").forEach((value) => {
                    const family = value.trim();
                    if (family && !seen[family]) {
                        seen[family] = true;
                        families.push(family);
                    }
                });
            });
            families.sort((left, right) => {
                return left.localeCompare(right);
            });
            root.fontFamilies = families;
        }

        stdout: StdioCollector {
            onStreamFinished: root.fontOutput = this.text
        }

    }

    FileDialog {
        id: wallpaperDialog

        parentWindow: root._backingWindow
        title: "Choose a wallpaper"
        modality: Qt.WindowModal
        nameFilters: ["Images (*.png *.jpg *.jpeg *.webp)", "All files (*)"]
        onAccepted: {
            const path = decodeURIComponent(String(selectedFile).replace(/^file:\/\//, ""));
            if (root.wallpaperDialogTarget === "new")
                root.newWallpaper = path;
            else
                root.setWallpaperPath(path);
            if (root.wallpaperDialogTarget === "new")
                paletteDelay.restart();

        }
    }

    FileDialog {
        id: importDialog

        parentWindow: root._backingWindow
        title: "Import a theme"
        modality: Qt.WindowModal
        nameFilters: ["Blox themes (*.blox-theme *.json)", "All files (*)"]
        onAccepted: {
            const path = decodeURIComponent(String(selectedFile).replace(/^file:\/\//, ""));
            root.runApi("import", ["import", path]);
        }
    }

    FileDialog {
        id: exportDialog

        parentWindow: root._backingWindow
        title: "Export theme"
        modality: Qt.WindowModal
        fileMode: FileDialog.SaveFile
        defaultSuffix: "blox-theme"
        nameFilters: ["Blox theme bundle (*.blox-theme)"]
        onAccepted: {
            const path = decodeURIComponent(String(selectedFile).replace(/^file:\/\//, ""));
            const args = ["export", root.candidate.id, "--output", path];
            if (root.exportIncludeWallpaper)
                args.push("--include-wallpaper");

            if (!root.exportIncludeWidgets)
                args.push("--exclude-widgets");

            root.runApi("export", args);
        }
    }

    FileDialog {
        id: stylusExportDialog

        parentWindow: root._backingWindow
        title: "Download Stylus theme"
        modality: Qt.WindowModal
        fileMode: FileDialog.SaveFile
        defaultSuffix: "css"
        nameFilters: ["Stylus UserCSS (*.css)"]
        onAccepted: {
            const path = decodeURIComponent(String(selectedFile).replace(/^file:\/\//, ""));
            root.runApi("export-target", ["export-target", "stylus", "--output", path]);
        }
    }

    FileDialog {
        id: widgetImportDialog

        parentWindow: root._backingWindow
        title: "Import widgets"
        modality: Qt.WindowModal
        nameFilters: ["Blox widgets (*.json)"]
        onAccepted: {
            const path = decodeURIComponent(String(selectedFile).replace(/^file:\/\//, ""));
            root.runApi("widgets-import", ["widgets-import", path]);
        }
    }

    FileDialog {
        id: widgetFileDialog

        parentWindow: root._backingWindow
        title: "Choose widget file"
        modality: Qt.WindowModal
        fileMode: FileDialog.OpenFile
        onAccepted: {
            if (!root.widgetDraft)
                return ;

            const path = decodeURIComponent(String(selectedFile).replace(/^file:\/\//, ""));
            root.widgetDraft.content_command = "sed -n '1,200p' -- " + root.shellQuote(path);
            root.widgetDraft = JSON.parse(JSON.stringify(root.widgetDraft));
        }
    }

    FileDialog {
        id: widgetExportDialog

        parentWindow: root._backingWindow
        title: "Export widgets"
        modality: Qt.WindowModal
        fileMode: FileDialog.SaveFile
        defaultSuffix: "json"
        nameFilters: ["Blox widgets (*.json)"]
        onAccepted: {
            const path = decodeURIComponent(String(selectedFile).replace(/^file:\/\//, ""));
            root.runApi("widgets-export", ["widgets-export", JSON.stringify(root.candidate.widgets || {
                "profile": "minimal"
            }), "--output", path]);
        }
    }

    IpcHandler {
        function open() : string {
            return root.openPicker();
        }

        function close() : string {
            return root.requestClose();
        }

        function cancel() : string {
            root.closePicker();
            return "cancelled";
        }

        function toggle() : string {
            if (root.open)
                return close();

            return open();
        }

        function generateCurrent() : string {
            return root.requestGenerateCurrent();
        }

        function mode(value: string) : string {
            if (value !== "overview" && value !== "advanced" && value !== "widgets")
                return "invalid-mode";

            root.editorMode = value;
            return root.editorMode;
        }

        function select(value: string) : string {
            root.requestSelection(value, true);
            return value === root.selectedId ? "selected" : root.modalKind === "navigate" ? "confirmation-required" : "loading";
        }

        function status() : string {
            return JSON.stringify({
                "open": root.open,
                "busy": root.busy,
                "dirty": root.dirty,
                "valid": root.candidateValid,
                "selected_id": root.selectedId,
                "mode": root.editorMode,
                "modal": root.modalKind
            });
        }

        target: "themePicker"
    }

    Shortcut {
        enabled: root.open && root.candidateValid
        sequence: "Ctrl+S"
        onActivated: root.saveCandidate("")
    }

    Shortcut {
        enabled: root.open && root.candidateValid
        sequence: "Ctrl+Return"
        onActivated: root.applyCandidate()
    }

    Rectangle {
        id: pickerRoot

        anchors.fill: parent
        color: "transparent"
        focus: root.open
        Keys.onEscapePressed: (event) => {
            if (root.colourPickerOpen)
                root.dismissColourPicker();
            else if (root.modalKind.length > 0 && !(root.modalKind === "new" && root.creationBusy) && !(root.modalKind === "progress" && !root.applyProgressComplete))
                root.dismissModal();
            else
                root.requestClose();
            event.accepted = true;
        }

        Rectangle {
            anchors.fill: parent
            anchors.margins: 1
            radius: 8
            clip: true
            color: Theme.background
            border.color: Theme.border
            border.width: 1

            ColumnLayout {
                id: pickerContent

                anchors.fill: parent
                anchors.margins: 18
                spacing: 12
                enabled: root.modalKind.length === 0 && !root.colourPickerOpen && (!root.busy || root.action === "preview-edit")

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 12

                    DragHandler {
                        target: null
                        acceptedButtons: Qt.LeftButton
                        onActiveChanged: {
                            if (active)
                                root.contentItem.QsWindow.window.startSystemMove();

                        }
                    }

                    Label {
                        text: "Theme Picker"
                        color: Theme.foreground
                        font.family: Theme.bodyFontFamily
                        font.pixelSize: 24
                        font.bold: true

                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.SizeAllCursor
                            onPressed: root.contentItem.QsWindow.window.startSystemMove()
                        }

                    }

                    Label {
                        text: root.dirty ? "UNSAVED" : root.candidateValid ? "VALID" : "CHECKING"
                        color: root.dirty ? Theme.yellow : root.candidateValid ? Theme.green : Theme.muted
                        font.family: Theme.fontFamily
                        font.pixelSize: 11
                    }

                    Item {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 36

                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.SizeAllCursor
                            onPressed: root.contentItem.QsWindow.window.startSystemMove()
                        }

                    }

                    BloxButton {
                        text: "Simple"
                        checkable: true
                        checked: root.editorMode === "overview"
                        onClicked: root.editorMode = "overview"
                    }

                    BloxButton {
                        text: "Advanced"
                        checkable: true
                        checked: root.editorMode === "advanced"
                        onClicked: root.editorMode = "advanced"
                    }

                    BloxButton {
                        text: "Widgets"
                        checkable: true
                        checked: root.editorMode === "widgets"
                        onClicked: root.editorMode = "widgets"
                    }

                    BloxButton {
                        text: "Close"
                        onClicked: root.requestClose()
                    }

                }

                Rectangle {
                    Layout.fillWidth: true
                    height: 1
                    color: Theme.border
                }

                RowLayout {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    spacing: 14

                    Rectangle {
                        Layout.preferredWidth: 265
                        Layout.fillHeight: true
                        radius: 8
                        color: Theme.surface
                        border.color: Theme.border

                        ColumnLayout {
                            anchors.fill: parent
                            anchors.margins: 10
                            spacing: 8

                            BloxTextField {
                                id: themeSearchField

                                Layout.fillWidth: true
                                placeholderText: "Search themes"
                                text: root.searchText
                                onTextChanged: root.searchText = text
                            }

                            BloxButton {
                                Layout.fillWidth: true
                                text: "+  New theme"
                                enabled: root.candidate && !root.dirty && !root.busy
                                onClicked: newThemeMenu.open()

                                Popup {
                                    id: newThemeMenu

                                    y: parent.height + 5
                                    width: parent.width
                                    padding: 5
                                    modal: false
                                    closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutside

                                    contentItem: Column {
                                        spacing: 4

                                        BloxButton {
                                            width: parent.width
                                            text: "From blank"
                                            onClicked: {
                                                newThemeMenu.close();
                                                root.openNewTheme(false);
                                            }
                                        }

                                        BloxButton {
                                            width: parent.width
                                            text: "From wallpaper"
                                            onClicked: {
                                                newThemeMenu.close();
                                                root.openNewTheme(true);
                                            }
                                        }

                                    }

                                    background: Rectangle {
                                        radius: 10
                                        color: Theme.surfaceAlt
                                        border.color: Theme.border
                                    }

                                }

                            }

                            RowLayout {
                                Layout.fillWidth: true
                                spacing: 6

                                BloxButton {
                                    Layout.fillWidth: true
                                    text: "Import"
                                    enabled: !root.dirty && !root.busy
                                    onClicked: root.openImportDialog()
                                }

                                BloxButton {
                                    Layout.fillWidth: true
                                    text: "Export"
                                    enabled: root.candidate && root.sourceDigest.length > 0 && !root.dirty && !root.busy
                                    onClicked: root.openExportDialog()
                                }

                            }

                            ListView {
                                id: themeList

                                Layout.fillWidth: true
                                Layout.fillHeight: true
                                clip: true
                                spacing: 4
                                model: root.filteredThemes()

                                ScrollBar.vertical: ScrollBar {
                                    policy: themeList.contentHeight > themeList.height ? ScrollBar.AlwaysOn : ScrollBar.AlwaysOff
                                    width: 8

                                    contentItem: Rectangle {
                                        implicitWidth: 6
                                        radius: 3
                                        color: Theme.withAlpha(Theme.muted, 0.68)
                                    }

                                }

                                delegate: Rectangle {
                                    id: themeDelegate

                                    required property var modelData

                                    width: themeList.width - (themeList.contentHeight > themeList.height ? 10 : 0)
                                    height: 62
                                    radius: 6
                                    color: modelData.id === root.selectedId ? Theme.surfaceAlt : mouse.containsMouse ? Theme.withAlpha(Theme.surfaceAlt, 0.62) : "transparent"
                                    border.color: modelData.unsaved ? Theme.yellow : modelData.id === Theme.activeThemeId ? Theme.blue : "transparent"
                                    border.width: modelData.unsaved || modelData.id === Theme.activeThemeId ? 1 : 0

                                    Column {
                                        anchors.left: parent.left
                                        anchors.right: kebab.left
                                        anchors.verticalCenter: parent.verticalCenter
                                        anchors.margins: 10
                                        spacing: 3

                                        Text {
                                            text: modelData.name
                                            color: Theme.foreground
                                            font.family: Theme.bodyFontFamily
                                            font.pixelSize: 14
                                            elide: Text.ElideRight
                                            width: parent.width
                                        }

                                        Text {
                                            text: modelData.unsaved ? "UNSAVED  ·  " + modelData.variant : modelData.variant
                                            color: modelData.unsaved ? Theme.yellow : Theme.muted
                                            font.family: Theme.fontFamily
                                            font.pixelSize: 10
                                            elide: Text.ElideRight
                                            width: parent.width
                                        }

                                    }

                                    Rectangle {
                                        id: kebab

                                        anchors.right: parent.right
                                        anchors.rightMargin: 7
                                        anchors.verticalCenter: parent.verticalCenter
                                        width: 30
                                        height: 34
                                        radius: 8
                                        color: kebabMouse.containsMouse || themeActions.visible ? Theme.withAlpha(Theme.blue, 0.22) : "transparent"

                                        Text {
                                            anchors.centerIn: parent
                                            text: "⋮"
                                            color: kebabMouse.containsMouse || themeActions.visible ? Theme.foreground : Theme.muted
                                            font.family: Theme.bodyFontFamily
                                            font.pixelSize: 20
                                        }

                                        MouseArea {
                                            id: kebabMouse

                                            anchors.fill: parent
                                            hoverEnabled: true
                                            cursorShape: Qt.PointingHandCursor
                                            onClicked: themeActions.open()
                                        }

                                    }

                                    MouseArea {
                                        id: mouse

                                        anchors.fill: parent
                                        anchors.rightMargin: 38
                                        hoverEnabled: true
                                        acceptedButtons: Qt.LeftButton | Qt.RightButton
                                        onClicked: (event) => {
                                            if (event.button === Qt.RightButton)
                                                themeActions.open();
                                            else if (modelData.id !== root.selectedId)
                                                root.requestSelection(modelData.id, true);
                                        }
                                    }

                                    Popup {
                                        id: themeActions

                                        parent: themeDelegate
                                        popupType: Popup.Item
                                        modal: true
                                        dim: false
                                        x: themeDelegate.width - width - 6
                                        y: 48
                                        width: 154
                                        height: actionColumn.implicitHeight + 8
                                        padding: 4
                                        closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutside

                                        contentItem: Column {
                                            id: actionColumn

                                            spacing: 4

                                            BloxButton {
                                                width: parent.width
                                                text: "Duplicate"
                                                enabled: modelData.id !== root.selectedId || !root.dirty
                                                onClicked: {
                                                    themeActions.close();
                                                    root.openDuplicate(modelData.id, modelData.name);
                                                }
                                            }

                                            BloxButton {
                                                width: parent.width
                                                text: "Rename"
                                                enabled: !modelData.unsaved && (modelData.id !== root.selectedId || !root.dirty)
                                                onClicked: {
                                                    themeActions.close();
                                                    root.openRename(modelData.id, modelData.name);
                                                }
                                            }

                                            BloxButton {
                                                width: parent.width
                                                text: "Delete"
                                                destructive: true
                                                enabled: !modelData.unsaved && modelData.id !== "blox-panel" && (modelData.id !== root.selectedId || !root.dirty) && !root.busy
                                                onClicked: {
                                                    themeActions.close();
                                                    root.requestDelete(modelData.id, modelData.name);
                                                }
                                            }

                                        }

                                        background: Rectangle {
                                            radius: 10
                                            color: Theme.surfaceAlt
                                            border.color: Theme.border
                                        }

                                    }

                                }

                            }

                        }

                    }

                    Rectangle {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        radius: 8
                        color: Theme.surface
                        border.color: Theme.border

                        Flickable {
                            id: editorScroll

                            anchors.fill: parent
                            anchors.margins: 14
                            clip: true
                            contentWidth: width
                            contentHeight: editorContent.implicitHeight
                            boundsBehavior: Flickable.StopAtBounds

                            WheelHandler {
                                acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
                                onWheel: (event) => {
                                    const pixelDelta = event.pixelDelta.y || 0;
                                    const angleDelta = event.angleDelta.y || 0;
                                    const delta = pixelDelta !== 0 ? pixelDelta : angleDelta / 2;
                                    const maximumContentY = Math.max(editorScroll.originY, editorScroll.originY + editorScroll.contentHeight - editorScroll.height);
                                    editorScroll.contentY = Math.max(editorScroll.originY, Math.min(maximumContentY, editorScroll.contentY - delta * 4));
                                    event.accepted = true;
                                }
                            }

                            ColumnLayout {
                                id: editorContent

                                width: editorScroll.width - 16
                                spacing: 14

                                ColumnLayout {
                                    Layout.fillWidth: true
                                    spacing: 6

                                    Label {
                                        text: "Theme name"
                                        color: Theme.foreground
                                        font.family: Theme.bodyFontFamily
                                        font.pixelSize: 17
                                        font.bold: true
                                    }

                                    RowLayout {
                                        Layout.fillWidth: true
                                        spacing: 10

                                        BloxTextField {
                                            Layout.fillWidth: true
                                            placeholderText: "Display name"
                                            text: {
                                                root.candidateRevision;
                                                return root.candidate ? root.candidate.name : "";
                                            }
                                            onEditingFinished: {
                                                if (root.candidate)
                                                    root.setTopLevel("name", text.trim());

                                            }
                                        }

                                        Text {
                                            text: root.candidate ? root.candidate.id : ""
                                            color: Theme.muted
                                            font.family: Theme.fontFamily
                                            font.pixelSize: 9
                                            elide: Text.ElideMiddle
                                            Layout.maximumWidth: 260
                                        }

                                    }

                                    Label {
                                        text: "Bar / OSD / Notifications"
                                        color: Theme.foreground
                                        font.family: Theme.bodyFontFamily
                                        font.pixelSize: 17
                                        font.bold: true
                                    }

                                    GridLayout {
                                        Layout.fillWidth: true
                                        columns: 2
                                        columnSpacing: 12
                                        rowSpacing: 8

                                        Label {
                                            text: "Bar position"
                                            color: Theme.muted
                                        }

                                        BloxComboBox {
                                            Layout.fillWidth: true
                                            model: ["left", "right", "top", "bottom"]
                                            currentIndex: model.indexOf(root.shellValue("bar", "position"))
                                            onActivated: (index, value) => {
                                                return root.setShellValue("bar", "position", value);
                                            }
                                        }

                                        Label {
                                            text: "OSD position"
                                            color: Theme.muted
                                        }

                                        BloxComboBox {
                                            Layout.fillWidth: true
                                            model: ["top-left", "top-right", "bottom-left", "bottom-right", "centre-top", "centre-bottom"]
                                            currentIndex: model.indexOf(root.shellValue("osd", "position"))
                                            onActivated: (index, value) => {
                                                return root.setShellValue("osd", "position", value);
                                            }
                                        }

                                        Label {
                                            text: "Notification position"
                                            color: Theme.muted
                                        }

                                        BloxComboBox {
                                            Layout.fillWidth: true
                                            model: ["top-left", "top-right", "bottom-left", "bottom-right", "centre-top", "centre-bottom"]
                                            currentIndex: model.indexOf(root.shellValue("notifications", "position"))
                                            onActivated: (index, value) => {
                                                return root.setShellValue("notifications", "position", value);
                                            }
                                        }

                                    }

                                }

                                ColumnLayout {
                                    visible: root.editorMode === "overview"
                                    Layout.fillWidth: true
                                    spacing: 12

                                    Label {
                                        text: "Wallpaper"
                                        color: Theme.foreground
                                        font.family: Theme.bodyFontFamily
                                        font.pixelSize: 17
                                        font.bold: true
                                    }

                                    RowLayout {
                                        Layout.fillWidth: true

                                        BloxTextField {
                                            id: wallpaperField

                                            Layout.fillWidth: true
                                            placeholderText: "/path/to/wallpaper"
                                            text: {
                                                root.candidateRevision;
                                                return root.candidate && root.candidate.wallpaper ? root.candidate.wallpaper.path : "";
                                            }
                                            onEditingFinished: {
                                                root.setWallpaperPath(text);
                                            }
                                        }

                                        BloxButton {
                                            text: "Browse"
                                            onClicked: root.openWallpaperDialog("overview")
                                        }

                                        BloxComboBox {
                                            model: ["cover", "contain", "tile"]
                                            currentIndex: root.candidate && root.candidate.wallpaper ? model.indexOf(root.candidate.wallpaper.fit) : 0
                                            onActivated: (index, selectedText) => {
                                                const next = root.cloneCandidate();
                                                next.wallpaper.fit = selectedText;
                                                root.markCandidate(next);
                                            }
                                        }

                                    }

                                    Label {
                                        text: "Semantic palette"
                                        color: Theme.foreground
                                        font.family: Theme.bodyFontFamily
                                        font.pixelSize: 17
                                        font.bold: true
                                    }

                                    Flow {
                                        Layout.fillWidth: true
                                        spacing: 8

                                        Repeater {
                                            model: root.semanticKeys

                                            Rectangle {
                                                id: semanticSwatch

                                                required property string modelData

                                                width: 112
                                                height: 72
                                                radius: 6
                                                color: root.candidate && root.candidate.colours ? root.candidate.colours[modelData] : "transparent"
                                                border.color: Theme.withAlpha(Theme.foreground, 0.45)
                                                ToolTip.visible: semanticHover.hovered && semanticLabel.truncated
                                                ToolTip.text: modelData.replace(/_/g, " ")
                                                ToolTip.delay: 350

                                                HoverHandler {
                                                    id: semanticHover

                                                    cursorShape: Qt.PointingHandCursor
                                                }

                                                TapHandler {
                                                    onTapped: root.openColourPicker(modelData, "")
                                                }

                                                Text {
                                                    id: semanticLabel

                                                    anchors.left: parent.left
                                                    anchors.right: parent.right
                                                    anchors.bottom: parent.bottom
                                                    anchors.margins: 6
                                                    text: modelData.replace(/_/g, " ")
                                                    color: root.swatchText(parent.color)
                                                    font.family: Theme.fontFamily
                                                    font.pixelSize: 9
                                                    wrapMode: Text.WordWrap
                                                    maximumLineCount: 2
                                                }

                                            }

                                        }

                                    }

                                    Label {
                                        text: "Terminal palette"
                                        color: Theme.foreground
                                        font.family: Theme.bodyFontFamily
                                        font.pixelSize: 17
                                        font.bold: true
                                    }

                                    Flow {
                                        Layout.fillWidth: true
                                        spacing: 6

                                        Repeater {
                                            model: root.ansiKeys

                                            Rectangle {
                                                required property string modelData

                                                width: 58
                                                height: 34
                                                radius: 5
                                                color: root.previewData && root.previewData.ansi ? root.previewData.ansi[modelData] : "transparent"
                                                border.color: Theme.border

                                                Text {
                                                    anchors.centerIn: parent
                                                    text: modelData.replace("color", "")
                                                    color: root.swatchText(parent.color)
                                                    font.family: Theme.fontFamily
                                                    font.pixelSize: 9
                                                }

                                            }

                                        }

                                    }

                                    Label {
                                        text: "Font samples"
                                        color: Theme.foreground
                                        font.family: Theme.bodyFontFamily
                                        font.pixelSize: 17
                                        font.bold: true
                                    }

                                    Rectangle {
                                        Layout.fillWidth: true
                                        height: 116
                                        radius: 7
                                        color: Theme.background
                                        border.color: Theme.border

                                        Column {
                                            anchors.fill: parent
                                            anchors.margins: 12
                                            spacing: 7

                                            Text {
                                                text: "Interface — Notifications and theme picker 0123456789"
                                                color: Theme.foreground
                                                font.family: root.candidate ? root.candidate.fonts.ui : Theme.bodyFontFamily
                                                font.pixelSize: 16
                                            }

                                            Text {
                                                text: "const accent = \"#89b4fa\";  {} [] () => ⚡󰍹"
                                                color: Theme.foreground
                                                font.family: root.candidate ? root.candidate.fonts.mono : Theme.monoFontFamily
                                                font.pixelSize: 14
                                            }

                                            Text {
                                                text: "Panel 󰕾 󰂄 󰤨 󰔛 󰖩"
                                                color: Theme.foreground
                                                font.family: root.candidate ? root.candidate.fonts.panel : Theme.fontFamily
                                                font.pixelSize: 14
                                            }

                                        }

                                    }

                                }

                                ColumnLayout {
                                    visible: root.editorMode === "advanced"
                                    Layout.fillWidth: true
                                    spacing: 12

                                    Label {
                                        text: "Semantic colours"
                                        color: Theme.foreground
                                        font.family: Theme.bodyFontFamily
                                        font.pixelSize: 17
                                        font.bold: true
                                    }

                                    GridLayout {
                                        Layout.fillWidth: true
                                        columns: 3
                                        columnSpacing: 10
                                        rowSpacing: 8

                                        Repeater {
                                            model: root.semanticKeys

                                            ColumnLayout {
                                                required property string modelData

                                                Layout.fillWidth: true

                                                Label {
                                                    text: modelData.replace(/_/g, " ")
                                                    color: Theme.muted
                                                    font.family: Theme.fontFamily
                                                    font.pixelSize: 10
                                                }

                                                Rectangle {
                                                    Layout.fillWidth: true
                                                    height: 38
                                                    radius: 9
                                                    color: root.candidate ? root.candidate.colours[modelData] : "transparent"
                                                    border.color: colourHover.hovered ? Theme.foreground : Theme.border
                                                    border.width: colourHover.hovered ? 2 : 1

                                                    Text {
                                                        anchors.left: parent.left
                                                        anchors.right: parent.right
                                                        anchors.bottom: parent.bottom
                                                        anchors.margins: 7
                                                        text: root.candidate ? root.candidate.colours[modelData] : ""
                                                        color: root.swatchText(parent.color)
                                                        font.family: Theme.fontFamily
                                                        font.pixelSize: 9
                                                        elide: Text.ElideRight
                                                    }

                                                    HoverHandler {
                                                        id: colourHover

                                                        cursorShape: Qt.PointingHandCursor
                                                    }

                                                    TapHandler {
                                                        onTapped: root.openColourPicker(modelData, "")
                                                    }

                                                }

                                            }

                                        }

                                    }

                                    RowLayout {
                                        Layout.fillWidth: true

                                        ColumnLayout {
                                            Layout.fillWidth: true

                                            Label {
                                                text: "Widget profile"
                                                color: Theme.foreground
                                                font.family: Theme.bodyFontFamily
                                                font.pixelSize: 17
                                                font.bold: true
                                            }

                                            Text {
                                                text: "Named presets keep overlay geometry consistent; resolved values are intentionally not edited here."
                                                color: Theme.muted
                                                font.family: Theme.bodyFontFamily
                                                wrapMode: Text.Wrap
                                            }

                                        }

                                        BloxComboBox {
                                            Layout.preferredWidth: 190
                                            enabled: root.candidate && root.candidate.targets.widgets
                                            model: ["minimal", "compact", "comfortable"]
                                            currentIndex: {
                                                root.candidateRevision;
                                                const profile = root.candidate && root.candidate.widgets ? root.candidate.widgets.profile : "minimal";
                                                return Math.max(0, model.indexOf(profile));
                                            }
                                            onActivated: (index, selectedText) => {
                                                return root.setWidgetProfile(selectedText);
                                            }
                                        }

                                    }

                                    Label {
                                        text: "Bar / OSD / Notifications"
                                        color: Theme.foreground
                                        font.family: Theme.bodyFontFamily
                                        font.pixelSize: 17
                                        font.bold: true
                                    }

                                    Text {
                                        Layout.fillWidth: true
                                        text: "Choose which bar items are shown and arrange them within each section. Hidden items remain available in the expanded section."
                                        color: Theme.muted
                                        font.family: Theme.bodyFontFamily
                                        wrapMode: Text.Wrap
                                    }

                                    ColumnLayout {
                                        Layout.fillWidth: true
                                        spacing: 10

                                        Repeater {
                                            model: ["start", "centre", "end", "hidden"]

                                            ColumnLayout {
                                                id: regionSection

                                                required property string modelData

                                                Layout.fillWidth: true
                                                spacing: 5

                                                Label {
                                                    text: regionSection.modelData === "hidden" ? "Expanded / hidden" : regionSection.modelData.charAt(0).toUpperCase() + regionSection.modelData.slice(1)
                                                    color: Theme.blue
                                                    font.bold: true
                                                }

                                                Repeater {
                                                    id: barItemRepeater

                                                    model: {
                                                        root.candidateRevision;
                                                        return root.barItems().filter((item) => {
                                                            return item.region === regionSection.modelData;
                                                        }).sort((left, right) => {
                                                            return left.order - right.order;
                                                        });
                                                    }

                                                    Rectangle {
                                                        id: barItemRow

                                                        required property var modelData
                                                        required property int index

                                                        Layout.fillWidth: true
                                                        implicitHeight: 44
                                                        radius: 8
                                                        color: Theme.background
                                                        border.color: Theme.border

                                                        RowLayout {
                                                            anchors.fill: parent
                                                            anchors.margins: 6
                                                            spacing: 7

                                                            BloxCheckBox {
                                                                Layout.fillWidth: true
                                                                text: root.barItemLabel(barItemRow.modelData.id)
                                                                checked: barItemRow.modelData.enabled
                                                                onToggled: (value) => {
                                                                    if (value !== barItemRow.modelData.enabled)
                                                                        root.setBarItemEnabled(barItemRow.modelData.id, value);

                                                                }
                                                            }

                                                            BloxComboBox {
                                                                Layout.preferredWidth: 145
                                                                model: ["start", "centre", "end", "hidden"]
                                                                currentIndex: model.indexOf(barItemRow.modelData.region)
                                                                onActivated: (selectedIndex, value) => {
                                                                    if (value !== barItemRow.modelData.region)
                                                                        root.setBarItemRegion(barItemRow.modelData.id, value);

                                                                }
                                                            }

                                                            BloxButton {
                                                                Layout.preferredWidth: 38
                                                                text: "↑"
                                                                enabled: barItemRow.index > 0
                                                                onClicked: root.moveBarItem(barItemRow.modelData.id, -1)
                                                            }

                                                            BloxButton {
                                                                Layout.preferredWidth: 38
                                                                text: "↓"
                                                                enabled: barItemRow.index + 1 < barItemRepeater.count
                                                                onClicked: root.moveBarItem(barItemRow.modelData.id, 1)
                                                            }

                                                        }

                                                    }

                                                }

                                            }

                                        }

                                    }

                                    GridLayout {
                                        Layout.fillWidth: true
                                        columns: 4
                                        columnSpacing: 8
                                        rowSpacing: 8

                                        Label {
                                            text: "OSD"
                                            color: Theme.muted
                                        }

                                        BloxComboBox {
                                            Layout.fillWidth: true
                                            model: ["top-left", "top-right", "bottom-left", "bottom-right", "centre-top", "centre-bottom"]
                                            currentIndex: model.indexOf(root.shellValue("osd", "position"))
                                            onActivated: (index, value) => {
                                                return root.setShellValue("osd", "position", value);
                                            }
                                        }

                                        BloxTextField {
                                            placeholderText: "X offset"
                                            text: String(root.shellValue("osd", "offset_x"))
                                            onEditingFinished: root.setShellValue("osd", "offset_x", Math.max(-1000, Math.min(1000, parseInt(text) || 0)))
                                        }

                                        BloxTextField {
                                            placeholderText: "Y offset"
                                            text: String(root.shellValue("osd", "offset_y"))
                                            onEditingFinished: root.setShellValue("osd", "offset_y", Math.max(-1000, Math.min(1000, parseInt(text) || 0)))
                                        }

                                        Label {
                                            text: "Notifications"
                                            color: Theme.muted
                                        }

                                        BloxComboBox {
                                            Layout.fillWidth: true
                                            model: ["top-left", "top-right", "bottom-left", "bottom-right", "centre-top", "centre-bottom"]
                                            currentIndex: model.indexOf(root.shellValue("notifications", "position"))
                                            onActivated: (index, value) => {
                                                return root.setShellValue("notifications", "position", value);
                                            }
                                        }

                                        BloxTextField {
                                            placeholderText: "X offset"
                                            text: String(root.shellValue("notifications", "offset_x"))
                                            onEditingFinished: root.setShellValue("notifications", "offset_x", Math.max(-1000, Math.min(1000, parseInt(text) || 0)))
                                        }

                                        BloxTextField {
                                            placeholderText: "Y offset"
                                            text: String(root.shellValue("notifications", "offset_y"))
                                            onEditingFinished: root.setShellValue("notifications", "offset_y", Math.max(-1000, Math.min(1000, parseInt(text) || 0)))
                                        }

                                    }

                                    Label {
                                        text: "Fonts"
                                        color: Theme.foreground
                                        font.family: Theme.bodyFontFamily
                                        font.pixelSize: 17
                                        font.bold: true
                                    }

                                    GridLayout {
                                        Layout.fillWidth: true
                                        columns: 3

                                        Repeater {
                                            model: ["ui", "mono", "panel"]

                                            ColumnLayout {
                                                required property string modelData

                                                Layout.fillWidth: true

                                                Label {
                                                    text: modelData
                                                    color: Theme.muted
                                                }

                                                BloxFontPicker {
                                                    Layout.fillWidth: true
                                                    families: root.fontFamilies
                                                    value: {
                                                        root.candidateRevision;
                                                        return root.candidate ? root.candidate.fonts[modelData] : "";
                                                    }
                                                    onAccepted: (family) => {
                                                        return root.setFont(modelData, family);
                                                    }
                                                }

                                            }

                                        }

                                    }

                                    Label {
                                        text: "Theme targets"
                                        color: Theme.foreground
                                        font.family: Theme.bodyFontFamily
                                        font.pixelSize: 17
                                        font.bold: true
                                    }

                                    Label {
                                        text: "Core"
                                        color: Theme.blue
                                        font.bold: true
                                    }

                                    Flow {
                                        Layout.fillWidth: true
                                        spacing: 8

                                        Repeater {
                                            model: root.coreTargetKeys

                                            Rectangle {
                                                required property string modelData

                                                width: 250
                                                height: 48
                                                radius: 8
                                                color: Theme.background
                                                border.color: Theme.border

                                                RowLayout {
                                                    anchors.fill: parent
                                                    anchors.margins: 7

                                                    BloxCheckBox {
                                                        Layout.fillWidth: true
                                                        text: root.targetLabel(modelData)
                                                        checked: {
                                                            root.candidateRevision;
                                                            return root.candidate ? root.candidate.targets[modelData] : false;
                                                        }
                                                        onToggled: (value) => {
                                                            if (root.candidate && value !== root.candidate.targets[modelData])
                                                                root.setTarget(modelData, value);

                                                        }
                                                    }

                                                    Text {
                                                        text: root.targetModeLabel(modelData)
                                                        color: root.targetApplyMode(modelData) === "restart" ? Theme.yellow : Theme.green
                                                        font.pixelSize: 9
                                                    }

                                                }

                                            }

                                        }

                                    }

                                    Label {
                                        text: "Applications"
                                        color: Theme.blue
                                        font.bold: true
                                    }

                                    Flow {
                                        Layout.fillWidth: true
                                        spacing: 8

                                        Repeater {
                                            model: root.applicationTargetKeys

                                            Rectangle {
                                                required property string modelData

                                                width: 250
                                                height: 48
                                                radius: 8
                                                color: Theme.background
                                                border.color: Theme.border

                                                RowLayout {
                                                    anchors.fill: parent
                                                    anchors.margins: 7

                                                    BloxCheckBox {
                                                        Layout.fillWidth: true
                                                        text: root.targetLabel(modelData)
                                                        checked: {
                                                            root.candidateRevision;
                                                            return root.candidate ? root.candidate.targets[modelData] : false;
                                                        }
                                                        onToggled: (value) => {
                                                            if (root.candidate && value !== root.candidate.targets[modelData])
                                                                root.setTarget(modelData, value);

                                                        }
                                                    }

                                                    Text {
                                                        visible: root.targetApplyMode(modelData) !== "manual"
                                                        text: root.targetModeLabel(modelData)
                                                        color: root.targetApplyMode(modelData) === "restart" ? Theme.yellow : Theme.green
                                                        font.pixelSize: 9
                                                    }

                                                    BloxButton {
                                                        visible: root.targetApplyMode(modelData) === "manual"
                                                        text: "Guide"
                                                        onClicked: {
                                                            root.guideTarget = modelData;
                                                            root.showModal("guide");
                                                        }
                                                    }

                                                }

                                            }

                                        }

                                    }

                                    Label {
                                        text: "Unavailable"
                                        color: Theme.muted
                                        font.bold: true
                                    }

                                    Flow {
                                        Layout.fillWidth: true
                                        spacing: 8

                                        Repeater {
                                            model: root.unavailableTargetKeys

                                            BloxCheckBox {
                                                required property string modelData

                                                text: root.targetLabel(modelData)
                                                checked: false
                                                enabled: root.targetAvailable(modelData)
                                            }

                                        }

                                    }

                                    Label {
                                        text: "Stylus"
                                        color: Theme.foreground
                                        font.family: Theme.bodyFontFamily
                                        font.pixelSize: 17
                                        font.bold: true
                                    }

                                    RowLayout {
                                        Layout.fillWidth: true

                                        Text {
                                            Layout.fillWidth: true
                                            text: "Install the generated UserCSS in the Stylus browser extension."
                                            color: Theme.muted
                                            wrapMode: Text.Wrap
                                        }

                                        BloxButton {
                                            text: "Download file"
                                            onClicked: root.downloadStylusFile()
                                        }

                                        BloxButton {
                                            text: "View guide"
                                            onClicked: {
                                                root.guideTarget = "stylus";
                                                root.showModal("guide");
                                            }
                                        }

                                    }

                                    Label {
                                        text: "Target-specific colour overrides"
                                        color: Theme.foreground
                                        font.family: Theme.bodyFontFamily
                                        font.pixelSize: 17
                                        font.bold: true
                                    }

                                    Repeater {
                                        model: ["gtk", "vicinae", "hyprlock"]

                                        ColumnLayout {
                                            required property string modelData

                                            Layout.fillWidth: true

                                            Label {
                                                text: modelData
                                                color: Theme.blue
                                                font.family: Theme.fontFamily
                                                font.pixelSize: 12
                                            }

                                            RowLayout {
                                                Repeater {
                                                    model: root.overrideKeys

                                                    ColumnLayout {
                                                        id: overrideEditor

                                                        required property string modelData
                                                        property string targetName: parent.parent.modelData
                                                        property string overrideValue: {
                                                            root.candidateRevision;
                                                            const values = root.candidate && root.candidate.overrides && root.candidate.overrides[targetName];
                                                            return values && values[modelData] ? values[modelData] : "";
                                                        }

                                                        Layout.fillWidth: true

                                                        Label {
                                                            text: modelData
                                                            color: Theme.muted
                                                            font.pixelSize: 9
                                                        }

                                                        RowLayout {
                                                            Layout.fillWidth: true

                                                            Rectangle {
                                                                Layout.fillWidth: true
                                                                height: 38
                                                                radius: 9
                                                                color: overrideEditor.overrideValue || Theme.background
                                                                border.color: overrideHover.hovered ? Theme.foreground : Theme.border
                                                                border.width: overrideHover.hovered ? 2 : 1

                                                                Text {
                                                                    anchors.fill: parent
                                                                    anchors.margins: 9
                                                                    text: overrideEditor.overrideValue || "inherit"
                                                                    color: overrideEditor.overrideValue ? root.swatchText(parent.color) : Theme.muted
                                                                    font.family: Theme.fontFamily
                                                                    font.pixelSize: 9
                                                                    verticalAlignment: Text.AlignVCenter
                                                                    elide: Text.ElideRight
                                                                }

                                                                HoverHandler {
                                                                    id: overrideHover

                                                                    cursorShape: Qt.PointingHandCursor
                                                                }

                                                                TapHandler {
                                                                    onTapped: root.openColourPicker(overrideEditor.modelData, overrideEditor.targetName)
                                                                }

                                                            }

                                                            BloxButton {
                                                                visible: overrideEditor.overrideValue.length > 0
                                                                Layout.preferredWidth: 38
                                                                text: "↺"
                                                                onClicked: root.setOverride(overrideEditor.targetName, overrideEditor.modelData, "")
                                                            }

                                                        }

                                                    }

                                                }

                                            }

                                        }

                                    }

                                }

                                ColumnLayout {
                                    visible: root.editorMode === "widgets"
                                    Layout.fillWidth: true
                                    spacing: 12

                                    RowLayout {
                                        Layout.fillWidth: true

                                        Label {
                                            Layout.fillWidth: true
                                            text: "Widgets"
                                            color: Theme.foreground
                                            font.pixelSize: 20
                                            font.bold: true
                                        }

                                        BloxButton {
                                            text: "New Widget"
                                            onClicked: root.openWidgetEditor(-1)
                                        }

                                        BloxButton {
                                            text: "Import"
                                            onClicked: widgetImportDialog.open()
                                        }

                                        BloxButton {
                                            text: "Export"
                                            onClicked: widgetExportDialog.open()
                                        }

                                    }

                                    Label {
                                        text: "Style"
                                        color: Theme.foreground
                                        font.bold: true
                                    }

                                    BloxComboBox {
                                        Layout.fillWidth: true
                                        model: ["minimal", "compact", "comfortable"]
                                        currentIndex: root.candidate && root.candidate.widgets ? model.indexOf(root.candidate.widgets.profile) : 0
                                        onActivated: (index, value) => {
                                            return root.setWidgetProfile(value);
                                        }
                                    }

                                    Label {
                                        text: "List"
                                        color: Theme.foreground
                                        font.bold: true
                                    }

                                    Repeater {
                                        model: root.widgetItems()

                                        Rectangle {
                                            required property var modelData
                                            required property int index

                                            Layout.fillWidth: true
                                            height: 54
                                            radius: 8
                                            color: Theme.background
                                            border.color: Theme.border

                                            RowLayout {
                                                anchors.fill: parent
                                                anchors.margins: 8

                                                BloxCheckBox {
                                                    checked: modelData.enabled
                                                    onToggled: (value) => {
                                                        const items = root.widgetItems().slice();
                                                        items[index].enabled = value;
                                                        root.setWidgetItems(items);
                                                    }
                                                }

                                                Text {
                                                    Layout.fillWidth: true
                                                    text: modelData.name + " · " + modelData.type
                                                    color: Theme.foreground
                                                }

                                                BloxButton {
                                                    text: "Edit"
                                                    onClicked: root.openWidgetEditor(index)
                                                }

                                                BloxButton {
                                                    text: "Delete"
                                                    destructive: true
                                                    onClicked: {
                                                        const items = root.widgetItems().slice();
                                                        items.splice(index, 1);
                                                        root.setWidgetItems(items);
                                                    }
                                                }

                                            }

                                        }

                                    }

                                    Text {
                                        visible: root.widgetItems().length === 0
                                        text: "No explicit widgets yet. Add one to replace the default Todo and Calendar widgets."
                                        color: Theme.muted
                                        wrapMode: Text.Wrap
                                    }

                                    Label {
                                        text: "Position"
                                        color: Theme.foreground
                                        font.bold: true
                                    }

                                    Text {
                                        Layout.fillWidth: true
                                        text: "Drag a widget to position it. Drop near a corner to snap it; drag the lower-right handle to resize."
                                        color: Theme.muted
                                        wrapMode: Text.Wrap
                                    }

                                    Rectangle {
                                        id: widgetCanvas

                                        Layout.fillWidth: true
                                        Layout.preferredHeight: Math.min(520, width * 9 / 16)
                                        clip: true
                                        radius: 12
                                        color: Theme.background
                                        border.color: Theme.border

                                        Image {
                                            anchors.fill: parent
                                            source: root.candidate && root.candidate.wallpaper && root.candidate.wallpaper.path ? "file://" + root.candidate.wallpaper.path : ""
                                            fillMode: Image.PreserveAspectCrop
                                            asynchronous: true

                                            Rectangle {
                                                anchors.fill: parent
                                                color: Qt.rgba(0, 0, 0, 0.22)
                                            }

                                        }

                                        Text {
                                            anchors.centerIn: parent
                                            visible: !root.candidate || !root.candidate.wallpaper || !root.candidate.wallpaper.path
                                            text: "No wallpaper selected"
                                            color: Theme.muted
                                        }

                                        Repeater {
                                            model: root.widgetItems()

                                            Rectangle {
                                                id: widgetPreview

                                                required property var modelData
                                                required property int index
                                                property real virtualWidth: modelData.width > 0 ? modelData.width : 320
                                                property real virtualHeight: modelData.height > 0 ? modelData.height : 160
                                                property real resizeStartX: 0
                                                property real resizeStartY: 0
                                                property real resizeStartWidth: 0
                                                property real resizeStartHeight: 0

                                                width: Math.max(48, virtualWidth * widgetCanvas.width / 1920)
                                                height: Math.max(32, virtualHeight * widgetCanvas.height / 1080)
                                                x: modelData.anchor.indexOf("right") >= 0 ? widgetCanvas.width - width - modelData.offset_x * widgetCanvas.width / 1920 : modelData.anchor === "centre" ? (widgetCanvas.width - width) / 2 + modelData.offset_x * widgetCanvas.width / 1920 : modelData.offset_x * widgetCanvas.width / 1920
                                                y: modelData.anchor.indexOf("bottom") >= 0 ? widgetCanvas.height - height - modelData.offset_y * widgetCanvas.height / 1080 : modelData.anchor === "centre" ? (widgetCanvas.height - height) / 2 + modelData.offset_y * widgetCanvas.height / 1080 : modelData.offset_y * widgetCanvas.height / 1080
                                                radius: modelData.shape === "circle" ? Math.min(width, height) / 2 : modelData.shape === "square" ? 0 : 8
                                                color: Theme.withAlpha(Theme.surface, 0.88)
                                                border.width: root.selectedWidgetIndex === index ? 2 : 1
                                                border.color: root.selectedWidgetIndex === index ? Theme.blue : Theme.border

                                                Text {
                                                    anchors.centerIn: parent
                                                    width: parent.width - 16
                                                    text: widgetPreview.modelData.name
                                                    color: Theme.foreground
                                                    horizontalAlignment: Text.AlignHCenter
                                                    elide: Text.ElideRight
                                                }

                                                MouseArea {
                                                    anchors.fill: parent
                                                    drag.target: widgetPreview
                                                    drag.minimumX: 0
                                                    drag.maximumX: widgetCanvas.width - widgetPreview.width
                                                    drag.minimumY: 0
                                                    drag.maximumY: widgetCanvas.height - widgetPreview.height
                                                    onPressed: root.selectedWidgetIndex = widgetPreview.index
                                                    onReleased: root.commitWidgetPreview(widgetPreview.index, widgetPreview.x, widgetPreview.y, widgetPreview.width, widgetPreview.height, widgetCanvas.width, widgetCanvas.height)
                                                }

                                                Rectangle {
                                                    width: 18
                                                    height: 18
                                                    anchors.right: parent.right
                                                    anchors.bottom: parent.bottom
                                                    radius: 4
                                                    color: Theme.blue
                                                    border.color: Theme.background

                                                    MouseArea {
                                                        anchors.fill: parent
                                                        cursorShape: Qt.SizeFDiagCursor
                                                        onPressed: (mouse) => {
                                                            const point = mapToItem(widgetCanvas, mouse.x, mouse.y);
                                                            widgetPreview.resizeStartX = point.x;
                                                            widgetPreview.resizeStartY = point.y;
                                                            widgetPreview.resizeStartWidth = widgetPreview.width;
                                                            widgetPreview.resizeStartHeight = widgetPreview.height;
                                                            root.selectedWidgetIndex = widgetPreview.index;
                                                        }
                                                        onPositionChanged: (mouse) => {
                                                            if (!pressed)
                                                                return ;

                                                            const point = mapToItem(widgetCanvas, mouse.x, mouse.y);
                                                            widgetPreview.width = Math.max(48, Math.min(widgetCanvas.width - widgetPreview.x, widgetPreview.resizeStartWidth + point.x - widgetPreview.resizeStartX));
                                                            widgetPreview.height = Math.max(32, Math.min(widgetCanvas.height - widgetPreview.y, widgetPreview.resizeStartHeight + point.y - widgetPreview.resizeStartY));
                                                        }
                                                        onReleased: root.commitWidgetPreview(widgetPreview.index, widgetPreview.x, widgetPreview.y, widgetPreview.width, widgetPreview.height, widgetCanvas.width, widgetCanvas.height)
                                                    }

                                                }

                                            }

                                        }

                                    }

                                    GridLayout {
                                        visible: root.selectedWidgetIndex >= 0 && root.selectedWidgetIndex < root.widgetItems().length
                                        Layout.fillWidth: true
                                        columns: 4
                                        columnSpacing: 10
                                        rowSpacing: 6

                                        Repeater {
                                            model: ["X offset", "Y offset", "Width", "Height"]

                                            Label {
                                                required property string modelData

                                                text: modelData
                                                color: Theme.muted
                                            }

                                        }

                                        Repeater {
                                            model: ["offset_x", "offset_y", "width", "height"]

                                            BloxTextField {
                                                required property string modelData
                                                property var selectedItem: root.selectedWidgetIndex >= 0 && root.selectedWidgetIndex < root.widgetItems().length ? root.widgetItems()[root.selectedWidgetIndex] : null

                                                Layout.fillWidth: true
                                                text: selectedItem ? String(selectedItem[modelData]) : "0"
                                                onEditingFinished: {
                                                    if (!selectedItem)
                                                        return ;

                                                    const parsed = parseInt(text);
                                                    const value = modelData === "width" || modelData === "height" ? Math.max(1, parsed || 0) : Math.max(-10000, Math.min(10000, isNaN(parsed) ? 0 : parsed));
                                                    root.updateWidgetGeometry(root.selectedWidgetIndex, selectedItem.anchor, modelData === "offset_x" ? value : selectedItem.offset_x, modelData === "offset_y" ? value : selectedItem.offset_y, modelData === "width" ? value : selectedItem.width, modelData === "height" ? value : selectedItem.height);
                                                }
                                            }

                                        }

                                    }

                                }

                            }

                            ScrollBar.vertical: ScrollBar {
                                id: editorScrollbar

                                policy: ScrollBar.AlwaysOn
                                width: 8
                                interactive: true

                                background: Rectangle {
                                    implicitWidth: 8
                                    radius: 999
                                    color: editorScrollbar.hovered || editorScrollbar.pressed ? Qt.rgba(1, 1, 1, 0.09) : Qt.rgba(1, 1, 1, 0.04)
                                }

                                contentItem: Rectangle {
                                    implicitWidth: 4
                                    radius: 999
                                    color: editorScrollbar.pressed ? Theme.blue : editorScrollbar.hovered ? Theme.foreground : Theme.muted

                                    Behavior on color {
                                        ColorAnimation {
                                            duration: 110
                                            easing.type: Easing.OutCubic
                                        }

                                    }

                                }

                            }

                        }

                    }

                }

                Rectangle {
                    Layout.fillWidth: true
                    height: 1
                    color: Theme.border
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 5

                    Repeater {
                        model: root.validationErrors

                        Text {
                            required property string modelData

                            Layout.fillWidth: true
                            text: modelData
                            color: Theme.red
                            wrapMode: Text.Wrap
                            font.family: Theme.bodyFontFamily
                            font.pixelSize: 11
                        }

                    }

                    Text {
                        visible: root.errorMessage.length > 0
                        Layout.fillWidth: true
                        text: root.errorMessage
                        color: Theme.red
                        wrapMode: Text.Wrap
                        font.family: Theme.bodyFontFamily
                        font.pixelSize: 11
                    }

                    Text {
                        visible: root.statusMessage.length > 0
                        Layout.fillWidth: true
                        text: root.statusMessage
                        color: Theme.muted
                        elide: Text.ElideRight
                        font.family: Theme.bodyFontFamily
                        font.pixelSize: 11
                    }

                }

                RowLayout {
                    Layout.fillWidth: true

                    Item {
                        Layout.fillWidth: true
                    }

                    BusyIndicator {
                        running: root.busy
                        visible: root.busy
                        Layout.preferredWidth: 28
                        Layout.preferredHeight: 28
                    }

                    BloxButton {
                        text: "Revert"
                        visible: root.candidate && root.dirty && root.baselineJson.length > 0
                        enabled: !root.busy
                        onClicked: root.revertCandidate()
                    }

                    BloxButton {
                        text: "Save"
                        enabled: root.candidate && root.dirty && root.candidateValid && !root.busy
                        onClicked: root.saveCandidate("")
                    }

                    BloxButton {
                        text: "Apply"
                        enabled: root.candidate && root.candidateValid && !root.busy
                        onClicked: root.applyCandidate()
                    }

                }

            }

            FocusScope {
                id: modalFocusScope

                anchors.fill: parent
                visible: root.modalKind.length > 0
                focus: visible
                z: 50

                Rectangle {
                    anchors.fill: parent
                    color: Theme.withAlpha("#000000", 0.68)
                }

                MouseArea {
                    id: modalInputBlocker

                    anchors.fill: parent
                    acceptedButtons: Qt.AllButtons
                    hoverEnabled: true
                    preventStealing: true
                }

                Rectangle {
                    anchors.centerIn: parent
                    width: 500
                    height: root.modalKind === "widget" ? 620 : implicitHeight
                    implicitHeight: modalColumn.implicitHeight + 40
                    radius: 10
                    color: Theme.surface
                    border.color: Theme.border

                    MouseArea {
                        id: modalCardInputBlocker

                        anchors.fill: parent
                        acceptedButtons: Qt.AllButtons
                        hoverEnabled: true
                        preventStealing: true
                    }

                    ColumnLayout {
                        id: modalColumn

                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.top: parent.top
                        anchors.margins: 20
                        spacing: 12

                        Label {
                            Layout.fillWidth: true
                            text: root.modalKind === "new" ? "New theme" : root.modalKind === "widget" ? (root.widgetEditIndex >= 0 ? "Edit widget" : "New widget") : root.modalKind === "progress" ? "Applying theme" : root.modalKind === "guide" ? "Manual application guide" : root.modalKind === "delete" ? "Delete theme permanently?" : root.modalKind === "duplicate" ? "Duplicate theme" : root.modalKind === "rename" ? "Rename display name" : root.modalKind === "export" ? "Export theme" : "Discard unsaved changes?"
                            color: Theme.foreground
                            font.family: Theme.bodyFontFamily
                            font.pixelSize: 19
                            font.bold: true
                        }

                        Text {
                            visible: root.modalKind === "new" || root.modalKind === "progress" || root.modalKind === "guide" || root.modalKind === "navigate" || root.modalKind === "generate-current" || root.modalKind === "close" || root.modalKind === "delete" || root.modalKind === "export"
                            Layout.fillWidth: true
                            text: root.modalKind === "new" ? root.creationBusy ? "Creating the theme from the selected inputs…" : root.newFlowPage === "blank" ? "Create a blank editable theme." : "Choose a wallpaper and the palette generator to use." : root.modalKind === "progress" ? root.applyProgressComplete ? "Application finished. Review any follow-up actions below." : "Generating and applying each enabled target…" : root.modalKind === "delete" ? "This removes the editable source. The action cannot be undone." : root.modalKind === "export" ? "Create a portable bundle. Fonts, GTK, icon and cursor themes remain dependency notes." : "The temporary Quickshell preview will be restored to the active theme."
                            color: Theme.muted
                            wrapMode: Text.Wrap
                            font.family: Theme.bodyFontFamily
                        }

                        Label {
                            visible: root.modalKind === "new" && !root.creationBusy
                            text: "Name"
                            color: Theme.foreground
                            font.bold: true
                        }

                        BloxTextField {
                            id: newNameField

                            visible: root.modalKind === "new" && !root.creationBusy
                            Layout.fillWidth: true
                            placeholderText: "Display name"
                            text: root.newThemeName
                            onTextChanged: {
                                root.newThemeName = text;
                                root.newThemeId = root.duplicateIdForName(text);
                            }
                            onAccepted: {
                                if (root.newThemeId.trim().length > 0 && root.newThemeName.trim().length > 0)
                                    root.startNewTheme(false);

                            }
                        }

                        Label {
                            visible: root.modalKind === "new" && !root.creationBusy && root.newFlowPage === "wallpaper"
                            text: "File Path"
                            color: Theme.foreground
                            font.bold: true
                        }

                        RowLayout {
                            visible: root.modalKind === "new" && !root.creationBusy && root.newFlowPage === "wallpaper"
                            Layout.fillWidth: true

                            BloxTextField {
                                id: newWallpaperField

                                Layout.fillWidth: true
                                placeholderText: "/path/to/wallpaper"
                                text: root.newWallpaper
                                onTextChanged: {
                                    root.newWallpaper = text;
                                    paletteDelay.restart();
                                }
                            }

                            BloxButton {
                                text: "Browse"
                                onClicked: root.openWallpaperDialog("new")
                            }

                        }

                        Label {
                            visible: root.modalKind === "new" && !root.creationBusy && root.newFlowPage === "wallpaper" && root.newWallpaper.trim().length > 0
                            text: "Base Colour Palette"
                            color: Theme.foreground
                            font.bold: true
                        }

                        BusyIndicator {
                            visible: root.modalKind === "new" && !root.creationBusy && root.paletteLoading
                            running: visible
                            Layout.alignment: Qt.AlignHCenter
                        }

                        Repeater {
                            model: root.modalKind === "new" && !root.creationBusy && root.newFlowPage === "wallpaper" ? root.paletteOptions : []

                            Rectangle {
                                id: paletteRow

                                required property var modelData

                                Layout.fillWidth: true
                                height: 46
                                radius: 8
                                color: Theme.background
                                border.color: root.generatorBackend === modelData.backend ? Theme.blue : Theme.border
                                opacity: modelData.available ? 1 : 0.5

                                RowLayout {
                                    anchors.fill: parent
                                    anchors.margins: 8

                                    Rectangle {
                                        width: 18
                                        height: 18
                                        radius: 9
                                        color: "transparent"
                                        border.color: modelData.available ? Theme.blue : Theme.muted
                                        border.width: 2

                                        Rectangle {
                                            anchors.centerIn: parent
                                            width: 8
                                            height: 8
                                            radius: 4
                                            visible: root.generatorBackend === modelData.backend
                                            color: Theme.blue
                                        }

                                    }

                                    Text {
                                        text: modelData.backend === "matugen" ? "Matugen" : "Pywal"
                                        color: Theme.foreground
                                        font.family: Theme.bodyFontFamily
                                        Layout.preferredWidth: 72
                                    }

                                    Repeater {
                                        model: ["background", "surface", "accent", "danger", "success", "warning", "info", "mauve", "teal", "foreground"]

                                        Rectangle {
                                            required property string modelData

                                            width: 24
                                            height: 24
                                            radius: 12
                                            color: paletteRow.modelData.colours[modelData] || "transparent"
                                            border.color: Theme.border
                                        }

                                    }

                                }

                                TapHandler {
                                    enabled: modelData.available
                                    onTapped: root.generatorBackend = modelData.backend
                                }

                            }

                        }

                        ColumnLayout {
                            visible: root.modalKind === "new" && root.creationBusy
                            Layout.fillWidth: true

                            BusyIndicator {
                                running: visible
                                Layout.alignment: Qt.AlignHCenter
                            }

                            Text {
                                Layout.alignment: Qt.AlignHCenter
                                text: root.creationRequest && root.creationRequest.wallpaper ? root.creationRequest.backend + " — generating palette and theme" : "Creating blank theme"
                                color: Theme.blue
                            }

                        }

                        ScrollView {
                            visible: root.modalKind === "progress"
                            Layout.fillWidth: true
                            Layout.preferredHeight: Math.min(420, progressGrid.implicitHeight)
                            contentWidth: availableWidth
                            clip: true

                            GridLayout {
                                id: progressGrid

                                width: parent.width
                                columns: 1
                                columnSpacing: 14
                                rowSpacing: 8

                                Repeater {
                                    model: root.applyProgressRows

                                    RowLayout {
                                        required property var modelData

                                        Layout.preferredWidth: progressGrid.width

                                        Text {
                                            text: modelData.target.replace("cursor_editor", "cursor")
                                            color: Theme.foreground
                                            font.family: Theme.fontFamily
                                            Layout.preferredWidth: 150
                                        }

                                        Text {
                                            text: modelData.message
                                            color: modelData.state === "failed" || modelData.state === "manual" ? Theme.red : modelData.state === "restart" ? Theme.yellow : modelData.state === "applied" ? Theme.green : Theme.blue
                                            Layout.fillWidth: true
                                            elide: Text.ElideRight
                                        }

                                        BloxButton {
                                            visible: modelData.state === "manual"
                                            text: "Guide"
                                            onClicked: {
                                                root.guideTarget = modelData.target;
                                                root.modalKind = "guide";
                                            }
                                        }

                                    }

                                }

                            }

                        }

                        ColumnLayout {
                            visible: root.modalKind === "guide"
                            Layout.fillWidth: true

                            Image {
                                visible: root.guideTarget === "stylus"
                                Layout.fillWidth: true
                                height: 180
                                source: "../assets/stylus-import.png"
                                fillMode: Image.PreserveAspectFit
                            }

                            Text {
                                Layout.fillWidth: true
                                text: root.guideTarget === "obsidian" ? "1. Open your vault's .obsidian/snippets folder.\n2. Copy the generated blox-theme.css file into it.\n3. In Obsidian, open Appearance → CSS snippets and enable Blox theme." : "1. Open the Stylus extension dashboard.\n2. Choose Import and select the generated blox-system.user.css file.\n3. Replace the previous Blox System Theme entry, then enable it."
                                color: Theme.foreground
                                wrapMode: Text.Wrap
                            }

                            BloxButton {
                                visible: root.guideTarget === "stylus"
                                Layout.alignment: Qt.AlignRight
                                text: "Download file"
                                onClicked: root.downloadStylusFile()
                            }

                        }

                        GridLayout {
                            visible: root.modalKind === "widget" && root.widgetDraft !== null
                            Layout.fillWidth: true
                            columns: 2
                            columnSpacing: 10
                            rowSpacing: 8

                            Label {
                                text: "Name"
                                color: Theme.muted
                            }

                            BloxTextField {
                                id: widgetNameField

                                Layout.fillWidth: true
                                text: root.widgetDraft ? root.widgetDraft.name : ""
                                onTextChanged: {
                                    if (root.widgetDraft)
                                        root.widgetDraft.name = text;

                                }
                            }

                            Label {
                                text: "Preset"
                                color: Theme.muted
                            }

                            BloxComboBox {
                                Layout.fillWidth: true
                                model: ["file", "music", "calendar", "clock", "aquarium", "pipes", "tree", "matrix", "fortune", "train", "custom"]
                                currentIndex: root.widgetDraft ? model.indexOf(root.widgetDraft.type) : model.length - 1
                                onActivated: (index, value) => {
                                    const identity = root.widgetDraft.id;
                                    const name = root.widgetDraft.name;
                                    root.widgetDraft = root.newWidgetDraft(value);
                                    root.widgetDraft.id = identity;
                                    root.widgetDraft.name = name;
                                }
                            }

                            Label {
                                text: "Content command"
                                color: Theme.muted
                            }

                            RowLayout {
                                Layout.fillWidth: true

                                BloxTextField {
                                    Layout.fillWidth: true
                                    text: root.widgetDraft ? root.widgetDraft.content_command : ""
                                    onTextChanged: {
                                        if (root.widgetDraft)
                                            root.widgetDraft.content_command = text;

                                    }
                                }

                                BloxButton {
                                    visible: root.widgetDraft && root.widgetDraft.type === "file"
                                    text: "Browse"
                                    onClicked: widgetFileDialog.open()
                                }

                            }

                            Label {
                                text: "Left click"
                                color: Theme.muted
                            }

                            BloxTextField {
                                Layout.fillWidth: true
                                text: root.widgetDraft ? root.widgetDraft.left_click_command : ""
                                onTextChanged: {
                                    if (root.widgetDraft)
                                        root.widgetDraft.left_click_command = text;

                                }
                            }

                            Label {
                                text: "Right click"
                                color: Theme.muted
                            }

                            BloxTextField {
                                Layout.fillWidth: true
                                text: root.widgetDraft ? root.widgetDraft.right_click_command : ""
                                onTextChanged: {
                                    if (root.widgetDraft)
                                        root.widgetDraft.right_click_command = text;

                                }
                            }

                            Label {
                                text: "Update (ms)"
                                color: Theme.muted
                            }

                            BloxTextField {
                                Layout.fillWidth: true
                                text: root.widgetDraft ? String(root.widgetDraft.interval_ms) : "60000"
                                onEditingFinished: {
                                    if (root.widgetDraft)
                                        root.widgetDraft.interval_ms = Math.max(250, parseInt(text) || 60000);

                                }
                            }

                            Label {
                                text: "Position"
                                color: Theme.muted
                            }

                            BloxComboBox {
                                Layout.fillWidth: true
                                model: ["top-left", "top-right", "bottom-left", "bottom-right", "centre"]
                                currentIndex: root.widgetDraft ? model.indexOf(root.widgetDraft.anchor) : 0
                                onActivated: (index, value) => {
                                    if (root.widgetDraft)
                                        root.widgetDraft.anchor = value;

                                }
                            }

                            Label {
                                text: "Shape"
                                color: Theme.muted
                            }

                            BloxComboBox {
                                Layout.fillWidth: true
                                model: ["auto", "rectangle", "rounded", "circle"]
                                currentIndex: root.widgetDraft ? model.indexOf(root.widgetDraft.shape) : 0
                                onActivated: (index, value) => {
                                    if (root.widgetDraft)
                                        root.widgetDraft.shape = value;

                                }
                            }

                        }

                        BloxTextField {
                            id: duplicateNameField

                            visible: root.modalKind === "duplicate"
                            Layout.fillWidth: true
                            placeholderText: "Display name"
                            text: root.duplicateName
                            onTextChanged: {
                                root.duplicateName = text;
                                root.duplicateId = root.duplicateIdForName(text);
                            }
                            onAccepted: {
                                if (root.modalConfirmationEnabled())
                                    root.confirmModal();

                            }
                        }

                        BloxTextField {
                            id: renameNameField

                            visible: root.modalKind === "rename"
                            Layout.fillWidth: true
                            placeholderText: "Display name"
                            text: root.renameName
                            onTextChanged: root.renameName = text
                            onAccepted: {
                                if (root.modalConfirmationEnabled())
                                    root.confirmModal();

                            }
                        }

                        BloxCheckBox {
                            visible: root.modalKind === "export"
                            text: "Include wallpaper in bundle"
                            checked: root.exportIncludeWallpaper
                            onToggled: root.exportIncludeWallpaper = checked
                        }

                        BloxCheckBox {
                            visible: root.modalKind === "export"
                            text: "Include widgets in bundle"
                            checked: root.exportIncludeWidgets
                            onToggled: root.exportIncludeWidgets = checked
                        }

                        RowLayout {
                            Layout.fillWidth: true

                            Text {
                                id: duplicateIdFooter

                                visible: root.modalKind === "duplicate" || root.modalKind === "new" && !root.creationBusy
                                Layout.fillWidth: true
                                text: root.modalKind === "new" ? root.newThemeId : root.duplicateId
                                color: Theme.muted
                                elide: Text.ElideMiddle
                                font.family: Theme.monoFontFamily
                                font.pixelSize: 10
                            }

                            Item {
                                visible: root.modalKind !== "duplicate" && root.modalKind !== "new" && root.modalKind !== "export" && root.modalKind !== "widget"
                                Layout.fillWidth: true
                            }

                            BloxButton {
                                id: modalCancelButton

                                visible: root.modalKind !== "progress" || root.applyProgressComplete
                                text: root.modalKind === "progress" || root.modalKind === "guide" ? "Close" : "Cancel"
                                onClicked: root.dismissModal()
                            }

                            BloxButton {
                                visible: root.modalKind === "new" && !root.creationBusy
                                text: "Create"
                                enabled: root.newThemeId.trim().length > 0 && root.newThemeName.trim().length > 0 && (root.newFlowPage === "blank" || root.newWallpaper.trim().length > 0 && root.paletteOptions.some((entry) => {
                                    return entry.backend === root.generatorBackend && entry.available;
                                }))
                                onClicked: root.startNewTheme(root.newFlowPage === "wallpaper")
                            }

                            BloxButton {
                                visible: root.modalKind === "widget"
                                text: "Save widget"
                                enabled: root.widgetDraft && root.widgetDraft.name.trim().length > 0
                                onClicked: root.saveWidgetDraft()
                            }

                            BloxButton {
                                visible: false
                            }

                            BloxButton {
                                visible: root.modalKind !== "new" && root.modalKind !== "progress" && root.modalKind !== "guide" && root.modalKind !== "widget"
                                text: root.modalKind === "delete" ? "Delete" : root.modalKind === "duplicate" ? "Duplicate" : root.modalKind === "rename" ? "Rename" : root.modalKind === "export" ? "Choose destination" : "Discard"
                                destructive: root.modalKind === "delete" || root.modalKind === "close" || root.modalKind === "navigate" || root.modalKind === "generate-current"
                                enabled: root.modalConfirmationEnabled()
                                onClicked: root.confirmModal()
                            }

                        }

                    }

                }

            }

            FocusScope {
                id: colourFocusScope

                anchors.fill: parent
                visible: root.colourPickerOpen
                focus: visible
                z: 60

                Rectangle {
                    anchors.fill: parent
                    color: Theme.withAlpha("#000000", 0.68)
                }

                MouseArea {
                    id: colourInputBlocker

                    anchors.fill: parent
                    acceptedButtons: Qt.AllButtons
                    hoverEnabled: true
                    preventStealing: true
                }

                Rectangle {
                    anchors.centerIn: parent
                    width: 620
                    height: 500
                    radius: 14
                    color: Theme.surface
                    border.color: Theme.border
                    border.width: 1

                    MouseArea {
                        id: colourCardInputBlocker

                        anchors.fill: parent
                        acceptedButtons: Qt.AllButtons
                        hoverEnabled: true
                        preventStealing: true
                    }

                    ColumnLayout {
                        anchors.fill: parent
                        anchors.margins: 20
                        spacing: 14

                        RowLayout {
                            Layout.fillWidth: true

                            ColumnLayout {
                                spacing: 2

                                Text {
                                    text: "Choose " + root.colourPickerKey.replace(/_/g, " ")
                                    color: Theme.foreground
                                    font.family: Theme.bodyFontFamily
                                    font.pixelSize: 20
                                    font.bold: true
                                }

                                Text {
                                    text: root.colourPickerTarget ? "Override for " + root.colourPickerTarget : "Semantic theme colour"
                                    color: Theme.muted
                                    font.family: Theme.bodyFontFamily
                                    font.pixelSize: 11
                                }

                            }

                            Item {
                                Layout.fillWidth: true
                            }

                            BloxButton {
                                id: colourDoneButton

                                text: "Done"
                                Layout.alignment: Qt.AlignRight | Qt.AlignTop
                                onClicked: root.dismissColourPicker()
                            }

                        }

                        RowLayout {
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            spacing: 16

                            ColumnLayout {
                                Layout.preferredWidth: 344
                                Layout.minimumWidth: 300
                                Layout.fillHeight: true
                                spacing: 10

                                Rectangle {
                                    id: colourCanvas

                                    Layout.fillWidth: true
                                    Layout.fillHeight: true
                                    Layout.minimumHeight: 230
                                    radius: 9
                                    color: root.hsvHex(root.colourHue, 1, 1)
                                    clip: true

                                    Rectangle {
                                        anchors.fill: parent

                                        gradient: Gradient {
                                            orientation: Gradient.Horizontal

                                            GradientStop {
                                                position: 0
                                                color: "#ffffff"
                                            }

                                            GradientStop {
                                                position: 1
                                                color: "#00ffffff"
                                            }

                                        }

                                    }

                                    Rectangle {
                                        anchors.fill: parent

                                        gradient: Gradient {
                                            orientation: Gradient.Vertical

                                            GradientStop {
                                                position: 0
                                                color: "#00000000"
                                            }

                                            GradientStop {
                                                position: 1
                                                color: "#000000"
                                            }

                                        }

                                    }

                                    Rectangle {
                                        x: root.colourSaturation * parent.width - width / 2
                                        y: (1 - root.colourValue) * parent.height - height / 2
                                        width: 14
                                        height: 14
                                        radius: 7
                                        color: "transparent"
                                        border.color: Theme.foreground
                                        border.width: 2
                                    }

                                    MouseArea {
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onPressed: (mouse) => {
                                            root.colourSaturation = Math.max(0, Math.min(1, mouse.x / width));
                                            root.colourValue = Math.max(0, Math.min(1, 1 - mouse.y / height));
                                            root.updatePickerColour();
                                        }
                                        onPositionChanged: (mouse) => {
                                            if (pressed) {
                                                root.colourSaturation = Math.max(0, Math.min(1, mouse.x / width));
                                                root.colourValue = Math.max(0, Math.min(1, 1 - mouse.y / height));
                                                root.updatePickerColour();
                                            }
                                        }
                                    }

                                }

                                Rectangle {
                                    id: hueCanvas

                                    Layout.fillWidth: true
                                    Layout.preferredHeight: 22
                                    Layout.minimumHeight: 22
                                    Layout.maximumHeight: 22
                                    radius: 7

                                    Rectangle {
                                        x: root.colourHue * parent.width - width / 2
                                        y: -3
                                        width: 6
                                        height: parent.height + 6
                                        radius: 3
                                        color: Theme.foreground
                                        border.color: Theme.background
                                    }

                                    MouseArea {
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onPressed: (mouse) => {
                                            root.colourHue = Math.max(0, Math.min(1, mouse.x / width));
                                            root.updatePickerColour();
                                        }
                                        onPositionChanged: (mouse) => {
                                            if (pressed) {
                                                root.colourHue = Math.max(0, Math.min(1, mouse.x / width));
                                                root.updatePickerColour();
                                            }
                                        }
                                    }

                                    gradient: Gradient {
                                        orientation: Gradient.Horizontal

                                        GradientStop {
                                            position: 0
                                            color: "#ff0000"
                                        }

                                        GradientStop {
                                            position: 0.1667
                                            color: "#ffff00"
                                        }

                                        GradientStop {
                                            position: 0.3333
                                            color: "#00ff00"
                                        }

                                        GradientStop {
                                            position: 0.5
                                            color: "#00ffff"
                                        }

                                        GradientStop {
                                            position: 0.6667
                                            color: "#0000ff"
                                        }

                                        GradientStop {
                                            position: 0.8333
                                            color: "#ff00ff"
                                        }

                                        GradientStop {
                                            position: 1
                                            color: "#ff0000"
                                        }

                                    }

                                }

                            }

                            ColumnLayout {
                                Layout.preferredWidth: 220
                                Layout.fillHeight: true
                                spacing: 10

                                Rectangle {
                                    Layout.fillWidth: true
                                    height: 74
                                    radius: 10
                                    color: root.colourHex
                                    border.color: Theme.border

                                    Text {
                                        anchors.centerIn: parent
                                        text: root.colourHex
                                        color: root.swatchText(parent.color)
                                        font.family: Theme.fontFamily
                                        font.pixelSize: 12
                                    }

                                }

                                Text {
                                    text: "Theme colours"
                                    color: Theme.foreground
                                    font.family: Theme.bodyFontFamily
                                    font.pixelSize: 12
                                    font.bold: true
                                }

                                Flow {
                                    Layout.fillWidth: true
                                    spacing: 6

                                    Repeater {
                                        model: root.semanticKeys

                                        Rectangle {
                                            required property string modelData

                                            width: 34
                                            height: 34
                                            radius: 8
                                            color: root.candidate ? root.candidate.colours[modelData] : "transparent"
                                            border.color: presetHover.hovered ? Theme.foreground : Theme.border

                                            HoverHandler {
                                                id: presetHover

                                                cursorShape: Qt.PointingHandCursor
                                            }

                                            TapHandler {
                                                onTapped: {
                                                    root.loadPickerColour(parent.color);
                                                    root.applyPickerColour(root.colourHex);
                                                }
                                            }

                                        }

                                    }

                                }

                                Item {
                                    Layout.fillHeight: true
                                }

                                Text {
                                    text: "Hex value"
                                    color: Theme.muted
                                    font.family: Theme.bodyFontFamily
                                    font.pixelSize: 10
                                }

                                BloxTextField {
                                    id: colourHexField

                                    Layout.fillWidth: true
                                    text: root.colourHex
                                    onEditingFinished: {
                                        if (/^#[0-9a-fA-F]{6}$/.test(text)) {
                                            root.loadPickerColour(text);
                                            root.applyPickerColour(text);
                                        }
                                    }
                                }

                                BloxButton {
                                    visible: root.colourPickerTarget.length > 0
                                    Layout.fillWidth: true
                                    text: "Use semantic colour"
                                    onClicked: {
                                        root.setOverride(root.colourPickerTarget, root.colourPickerKey, "");
                                        root.dismissColourPicker();
                                    }
                                }

                            }

                        }

                    }

                }

            }

        }

    }

}
