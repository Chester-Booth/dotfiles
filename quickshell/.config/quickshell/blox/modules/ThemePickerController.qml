import "../shared"
import QtQuick
import Quickshell
import Quickshell.Io

Scope {
    id: root

    required property var host
    property Flickable editorScrollItem
    property Item pickerRootItem
    property Item barDragProxyItem
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
    property bool widgetEditModePending: false
    property bool exportIncludeWallpaper: true
    property bool exportIncludeWidgets: true
    property string generatedDownloadTarget: ""
    property string generatedDownloadFile: ""
    property bool generatedDownloadArchive: false
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
    property bool barDragActive: false
    property string barDragItemId: ""
    property string barDragLabel: ""
    property string barDropRegion: ""
    property int barDropIndex: -1
    property string barDropTarget: ""
    property real barDragOriginX: 0
    property real barDragOriginY: 0
    readonly property bool dirty: candidate !== null && JSON.stringify(candidate) !== baselineJson
    readonly property string apiPath: Quickshell.shellDir + "/scripts/theme/themectl.sh"
    readonly property string scriptRoot: Quickshell.shellDir + "/scripts"
    readonly property var semanticKeys: ["background", "surface", "surface_alt", "foreground", "muted", "accent", "danger", "success", "warning", "info", "mauve", "teal", "selection_background", "selection_foreground", "border"]
    readonly property var ansiKeys: ["color0", "color1", "color2", "color3", "color4", "color5", "color6", "color7", "color8", "color9", "color10", "color11", "color12", "color13", "color14", "color15"]
    readonly property var overrideKeys: ["background", "foreground", "accent", "border"]
    readonly property var targetKeys: ["quickshell", "vicinae", "widgets", "gtk", "cursor", "wallpaper", "kitty", "hyprland", "hyprlock", "btop", "micro", "glow", "code", "cursor_editor", "stylus", "obsidian", "powerlevel10k", "sddm", "grub"]
    readonly property var unavailableTargetKeys: ["sddm", "grub"]
    readonly property var coreTargetKeys: ["quickshell", "widgets", "wallpaper", "hyprland", "hyprlock", "cursor"]
    readonly property var applicationTargetKeys: ["vicinae", "kitty", "gtk", "btop", "micro", "glow", "code", "cursor_editor", "stylus", "obsidian", "powerlevel10k"]
    readonly property var barRegions: ["start", "centre", "end", "tray"]

    function beginBarDrag(row, itemId) {
        const point = row.mapToItem(pickerRootItem, 0, 0);
        barDragItemId = itemId;
        barDragLabel = barItemLabel(itemId);
        barDragProxyItem.width = row.width;
        barDragProxyItem.height = row.height;
        barDragProxyItem.x = point.x;
        barDragProxyItem.y = point.y;
        barDragOriginX = point.x;
        barDragOriginY = point.y;
        barDropRegion = "";
        barDropIndex = -1;
        barDropTarget = "";
        barDragActive = true;
    }

    function moveBarDragProxy(deltaX, deltaY) {
        if (!barDragActive)
            return ;

        barDragProxyItem.x = barDragOriginX + deltaX;
        barDragProxyItem.y = barDragOriginY + deltaY;
    }

    function scrollBarDrag() {
        if (!barDragActive)
            return ;

        const viewport = editorScrollItem.mapToItem(pickerRootItem, 0, 0);
        const pointerY = barDragProxyItem.y + barDragProxyItem.height / 2;
        const edge = 54;
        const maximum = Math.max(editorScrollItem.originY, editorScrollItem.originY + editorScrollItem.contentHeight - editorScrollItem.height);
        if (pointerY > viewport.y + editorScrollItem.height - edge)
            editorScrollItem.contentY = Math.min(maximum, editorScrollItem.contentY + 14);
        else if (pointerY < viewport.y + edge)
            editorScrollItem.contentY = Math.max(editorScrollItem.originY, editorScrollItem.contentY - 14);
    }

    function setBarDropTarget(region, index, target) {
        if (!barDragActive)
            return ;

        if (!barDropAllowed(barDragItemId, region, index)) {
            barDropRegion = "";
            barDropIndex = -1;
            barDropTarget = "";
            return ;
        }
        barDropRegion = region;
        barDropIndex = index;
        barDropTarget = target;
    }

    function barDropAllowed(id, region, index) {
        if (id === "application-tray") {
            if (region !== "hidden")
                return false;

            const count = barItems().filter((item) => {
                return item.region === "hidden";
            }).length;
            return applicationTrayAtStart() ? index === 0 : index === count;
        }
        if (id !== "tray")
            return true;

        if (region === "hidden")
            return false;

        const count = barItems().filter((item) => {
            return item.region === region;
        }).length;
        if (region === "start")
            return index === count;

        if (region === "end")
            return index === 0;

        return region === "centre" && (index === 0 || index === count);
    }

    function commitBarDrop() {
        if (barDragItemId.length > 0 && barDropRegion.length > 0 && barDropIndex >= 0)
            moveBarItemTo(barDragItemId, barDropRegion, barDropIndex);

    }

    function endBarDrag() {
        barDragActive = false;
        barDragItemId = "";
        barDragLabel = "";
        barDropRegion = "";
        barDropIndex = -1;
        barDropTarget = "";
    }

    function finishBarDrag() {
        commitBarDrop();
        endBarDrag();
    }

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

    function validColour(value, fallback) {
        return /^#[0-9a-fA-F]{6}$/.test(String(value || "")) ? value : (fallback || "transparent");
    }

    function themePreviewColour(entry, key, fallback) {
        const colours = entry && entry.preview ? entry.preview.colours || {
        } : {
        };
        return validColour(colours[key], fallback);
    }

    function themePreviewBarPosition(entry) {
        const bar = entry && entry.preview ? entry.preview.bar || {
        } : {
        };
        const position = String(bar.position || "left");
        return ["left", "right", "top", "bottom"].indexOf(position) >= 0 ? position : "left";
    }

    function themePreviewBarCount(entry, region) {
        const bar = entry && entry.preview ? entry.preview.bar || {
        } : {
        };
        const items = Array.isArray(bar.items) ? bar.items : [];
        let count = 0;
        for (let index = 0; index < items.length; ++index) {
            if (items[index].enabled && items[index].region === region)
                count += 1;

        }
        return count;
    }

    function longestWord(text) {
        const words = String(text || "").split(" ");
        return words.reduce((longest, word) => {
            return word.length > longest.length ? word : longest;
        }, "");
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
        const normalised = /^#[0-9a-fA-F]{6}$/.test(String(value || "")) ? value : "#ffffff";
        const hex = String(normalised).replace("#", "");
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
        const previewValues = target === "ansi" && previewData ? previewData.ansi : null;
        const value = overrideValues && overrideValues[key] ? overrideValues[key] : previewValues && previewValues[key] ? previewValues[key] : candidate.colours[key];
        loadPickerColour(value);
        rememberOverlayFocus();
        colourPickerOpen = true;
        Qt.callLater(() => {
            host.focusColourPicker();
        });
    }

    function rememberOverlayFocus() {
        focusBeforeOverlay = host.contentItem.QsWindow.window.activeFocusItem;
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
        host.focusModal();
    }

    function schedulePaletteRequest() {
        paletteDelay.restart();
    }

    function openWidgetFileDialog() {
        host.dialogs.openWidgetFile();
    }

    function openWidgetImportDialog() {
        host.dialogs.openWidgetImport();
    }

    function openWidgetExportDialog() {
        host.dialogs.openWidgetExport();
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

    function recoverPickerWorkspace(returnWorkspace) {
        // The picker is recreated on the widget-edit workspace when Save
        // finishes. Move that existing window to the current workspace using
        // Hyprland's structured Lua dispatcher; the legacy
        // `movetoworkspacesilent` syntax is rejected by current Hyprland.
        Quickshell.execDetached(["sh", "-c", "requested=$1; if [ -n \"$requested\" ]; then hyprctl dispatch \"hl.dsp.focus({ workspace = \\\"$requested\\\" })\" >/dev/null; sleep 0.15; workspace=$requested; else if [ \"$(hyprctl activeworkspace -j | jq -r .name)\" = blox-widget-edit ]; then hyprctl dispatch 'hl.dsp.focus({ workspace = \"previous\" })' >/dev/null; sleep 0.15; fi; workspace=$(hyprctl activeworkspace -j | jq -r .id); fi; [ -n \"$workspace\" ] || exit 0; hyprctl dispatch \"hl.dsp.window.move({ workspace = \\\"$workspace\\\", follow = false, window = \\\"title:^Blox Theme Picker$\\\" })\" >/dev/null", "blox-picker-recover", String(returnWorkspace || "")]);
    }

    function openPicker() {
        hideTimer.stop();
        // An interrupted widget-edit transition used to leave the picker open
        // internally but permanently hidden.  Opening the picker is an
        // explicit request to return to it, so always cancel that transient
        // mode first.
        widgetEditModePending = false;
        Theme.widgetEditModeCancelRequested();
        open = true;
        rendered = true;
        recoverPickerWorkspace("");
        revealTimer.restart();
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

    function applyValidatedPreview(source) {
        if (!dirty && selectedId === Theme.activeThemeId) {
            Theme.cancelPreview();
            statusMessage = "Active theme";
            return ;
        }
        Theme.previewSource(source);
        statusMessage = dirty ? "Temporary Quickshell preview — unsaved" : "Temporary Quickshell preview";
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
        next.widgets = next.widgets || {
        };
        next.widgets.profile = value;
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

        if (target === "ansi")
            next.terminal.ansi_source = "override";

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
        if (section === "bar" && key === "position") {
            const overrides = next.shell.bar.items || [];
            next.shell.bar.items = normaliseBarItemOrders(Theme.resolvedBarItems(overrides, value), value);
        }
        markCandidate(next);
        Theme.loadShell(next.shell);
        if (section === "osd")
            Theme.osdPositionPreviewRequested();
        else if (section === "notifications")
            Theme.notificationPositionPreviewRequested();
    }

    function barItems() {
        const overrides = candidate && candidate.shell && candidate.shell.bar && candidate.shell.bar.items ? candidate.shell.bar.items : [];
        const position = candidate && candidate.shell && candidate.shell.bar ? candidate.shell.bar.position : Theme.barPosition;
        return Theme.resolvedBarItems(overrides, position);
    }

    function trayOpensForward(items) {
        const source = items || barItems();
        const tray = source.find((item) => {
            return item.id === "tray";
        });
        if (!tray || tray.region === "end")
            return false;

        if (tray.region === "start")
            return true;

        if (tray.region !== "centre")
            return false;

        const centre = source.filter((item) => {
            return item.region === "centre";
        }).sort((left, right) => {
            return left.order - right.order;
        });
        return centre.length > 0 && centre[centre.length - 1].id === "tray";
    }

    function applicationTrayAtStart(items) {
        return !trayOpensForward(items);
    }

    function normaliseBarItemOrders(items, position) {
        const regions = ["start", "centre", "end", "hidden"];
        const tray = items.find((item) => {
            return item.id === "tray";
        });
        if (tray && tray.region === "hidden")
            tray.region = "end";

        const applicationTray = items.find((item) => {
            return item.id === "application-tray";
        });
        if (applicationTray)
            applicationTray.region = "hidden";

        const ordered = [];
        for (let regionIndex = 0; regionIndex < regions.length; ++regionIndex) {
            const region = regions[regionIndex];
            const members = items.filter((item) => {
                return item.region === region;
            }).sort((left, right) => {
                return left.order - right.order;
            });
            const trayIndex = members.findIndex((item) => {
                return item.id === "tray";
            });
            if (trayIndex >= 0) {
                const trayItem = members.splice(trayIndex, 1)[0];
                if (region === "start")
                    members.push(trayItem);
                else if (region === "end")
                    members.unshift(trayItem);
                else if (region === "centre" && trayIndex < (members.length + 1) / 2)
                    members.unshift(trayItem);
                else
                    members.push(trayItem);
            }
            const applicationTrayIndex = members.findIndex((item) => {
                return item.id === "application-tray";
            });
            if (applicationTrayIndex >= 0) {
                const applicationTrayItem = members.splice(applicationTrayIndex, 1)[0];
                if (applicationTrayAtStart(items))
                    members.unshift(applicationTrayItem);
                else
                    members.push(applicationTrayItem);
            }
            for (let index = 0; index < members.length; ++index) {
                members[index].order = index;
                ordered.push(members[index]);
            }
        }
        return ordered;
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

    function setBarItemDisplay(id, display) {
        const items = barItems();
        for (let index = 0; index < items.length; ++index) {
            if (items[index].id === id) {
                items[index].display = display;
                break;
            }
        }
        setBarItems(items);
    }

    function setBarItemVisibility(id, visibility) {
        const items = barItems();
        for (let index = 0; index < items.length; ++index) {
            if (items[index].id === id) {
                items[index].visibility = visibility;
                break;
            }
        }
        setBarItems(items);
    }

    function setBarItemRegion(id, region) {
        const items = barItems();
        if (id === "application-tray")
            region = "hidden";

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

        if (id === "application-tray")
            return ;

        if (id === "tray") {
            if (selected.region !== "centre")
                return ;

            const members = items.filter((item) => {
                return item.region === "centre";
            });
            selected.order = selected.order === 0 ? members.length : -1;
            setBarItems(items);
            return ;
        }
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

    function moveBarItemTo(id, region, destinationIndex) {
        const items = normaliseBarItemOrders(barItems());
        const selected = items.find((item) => {
            return item.id === id;
        });
        if (!selected)
            return ;

        if (id === "application-tray") {
            region = "hidden";
            destinationIndex = applicationTrayAtStart(items) ? 0 : items.filter((item) => {
                return item.region === "hidden";
            }).length;
        }
        const sourceRegion = selected.region;
        const sourceIndex = items.filter((item) => {
            return item.region === sourceRegion;
        }).findIndex((item) => {
            return item.id === id;
        });
        const groups = {
            "start": [],
            "centre": [],
            "end": [],
            "hidden": []
        };
        for (const item of items) {
            if (item.id !== id)
                groups[item.region].push(item);

        }
        selected.region = region;
        const destination = groups[region];
        if (region === sourceRegion && destinationIndex > sourceIndex)
            destinationIndex -= 1;

        destination.splice(Math.max(0, Math.min(destination.length, destinationIndex)), 0, selected);
        const next = [];
        for (const group of ["start", "centre", "end", "hidden"]) {
            for (let index = 0; index < groups[group].length; ++index) {
                groups[group][index].order = index;
                next.push(groups[group][index]);
            }
        }
        setBarItems(next);
    }

    function barItemLabel(id) {
        const labels = {
            "application-tray": "Application tray",
            "bt": "Bluetooth",
            "notifications": "Notifications",
            "wifi": "Wi-Fi"
        };
        return labels[id] || id.charAt(0).toUpperCase() + id.slice(1);
    }

    function barPreviewItems(region) {
        candidateRevision;
        return barItems().filter((item) => {
            return item.enabled && item.region === region;
        }).sort((left, right) => {
            return left.order - right.order;
        });
    }

    function barPreviewIcon(id) {
        const icons = {
            "power": "power",
            "notes": "notebook-tabs",
            "workspaces": "grid-2x2",
            "clock": "clock",
            "battery": "battery",
            "tray": "panels-top-left",
            "notifications": "bell",
            "wifi": "wifi",
            "sound": "volume-2",
            "touchpad": "panel-top",
            "privacy": "shield",
            "awake": "coffee",
            "display": "sun",
            "bt": "bluetooth",
            "updates": "refresh-cw",
            "application-tray": "app-window"
        };
        return icons[id] || "app-window";
    }

    function widgetItems() {
        return candidate && candidate.widgets && candidate.widgets.items ? candidate.widgets.items : Theme.defaultWidgetItems();
    }

    function localFileUrl(path) {
        const value = String(path || "");
        if (value.startsWith("~/"))
            return "file://" + Quickshell.env("HOME") + value.slice(1);

        if (value.startsWith("/"))
            return "file://" + value;

        return value;
    }

    function widgetPreviewCommand(widget) {
        const terminalTypes = ["music", "clock", "aquarium", "pipes", "tree", "matrix", "train"];
        const command = String(widget.content_command || "").replace(/\$SCRIPT_ROOT/g, scriptRoot);
        if (terminalTypes.indexOf(widget.type) < 0)
            return ["sh", "-c", command];

        const columns = Math.max(10, Math.floor((widget.width || 320) / 8));
        const rows = Math.max(4, Math.floor((widget.height || 160) / 18));
        return [scriptRoot + "/widgets/terminal-frame.py", widget.type, "--command", command, "--columns", String(columns), "--rows", String(rows)];
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
        item.width = width <= 0 ? 0 : Math.max(80, Math.round(width));
        item.height = height <= 0 ? 0 : Math.max(48, Math.round(height));
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
            "clock": "tty-clock",
            "aquarium": "asciiquarium",
            "pipes": "pipes.sh",
            "tree": "cbonsai -l",
            "matrix": "unimatrix",
            "fortune": "fortune | cowsay",
            "train": "sl"
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
            "visibility": "empty-workspace",
            "anchor": "top-left",
            "offset_x": 20,
            "offset_y": 20,
            "width": 0,
            "height": 0,
            "shape": "auto",
            "options": {
                "auto_size": true,
                "scale": 1
            }
        };
    }

    function widgetPreset(item) {
        if (!item)
            return "custom";

        return ["aquarium", "pipes", "tree", "matrix", "fortune", "train"].indexOf(item.type) >= 0 ? "decorative" : item.type;
    }

    function updateWidgetDraft(values) {
        if (!widgetDraft)
            return ;

        const next = JSON.parse(JSON.stringify(widgetDraft));
        Object.keys(values).forEach((key) => {
            return next[key] = values[key];
        });
        widgetDraft = next;
    }

    function updateWidgetOption(key, value) {
        if (!widgetDraft)
            return ;

        const next = JSON.parse(JSON.stringify(widgetDraft));
        if (!next.options)
            next.options = {
        };

        next.options[key] = value;
        if (next.type === "clock") {
            const flags = ["tty-clock"];
            if (next.options.twelve_hour)
                flags.push("-t");

            if (next.options.seconds)
                flags.push("-s");

            if (next.options.bold)
                flags.push("-b");

            if (next.options.blink)
                flags.push("-B");

            if (next.options.box)
                flags.push("-x");

            if (next.options.hide_date)
                flags.push("-D");

            next.content_command = flags.join(" ");
        } else if (next.type === "calendar")
            next.content_command = "gcalcli --lineart " + (next.options.lineart || "unicode") + (next.options.colour === false ? " --nocolor" : "") + " " + (next.options.view === "month" ? "calm" : next.options.view === "week" ? "calw" : "agenda");
        else if (next.type === "music" && key === "config_file")
            next.content_command = value ? "cava -p " + shellQuote(value) : "cava";
        widgetDraft = next;
    }

    function shellQuote(value) {
        return "'" + String(value).replace(/'/g, "'\\''") + "'";
    }

    function openWidgetEditor(index) {
        widgetEditIndex = index;
        widgetDraft = index >= 0 ? JSON.parse(JSON.stringify(widgetItems()[index])) : newWidgetDraft("custom");
        showModal("widget");
    }

    function openWidgetEditMode() {
        if (!candidate || widgetEditModePending)
            return ;

        widgetEditModePending = true;
        rendered = false;
        Theme.widgetEditModeRequested();
    }

    function saveWidgetDraft() {
        if (!widgetDraft || !widgetDraft.name.trim() || !widgetDraft.id.trim())
            return ;

        const items = widgetItems().slice();
        if (widgetEditIndex >= 0)
            items[widgetEditIndex] = widgetDraft;
        else
            items.unshift(widgetDraft);
        setWidgetItems(items);
        dismissModal();
    }

    function openWallpaperDialog(target) {
        wallpaperDialogTarget = target || "overview";
        host.dialogs.openWallpaper();
    }

    function openImportDialog() {
        if (!busy && !dirty)
            host.dialogs.openImport();

    }

    function openExportDialog() {
        if (busy || dirty || !candidate || !sourceDigest)
            return ;

        exportIncludeWallpaper = true;
        exportIncludeWidgets = true;
        showModal("export");
    }

    function generatedFiles() {
        if (!candidate || !candidate.targets)
            return [];

        const files = {
            "quickshell": ["quickshell/theme.json"],
            "vicinae": ["vicinae/theme.toml"],
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
        const order = ["stylus"].concat(targetKeys.filter((target) => {
            return target !== "stylus";
        }));
        const result = [];
        for (const target of order) {
            if (!candidate.targets[target] || !files[target])
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

    function downloadGeneratedFile(target, file) {
        if (busy)
            return ;

        generatedDownloadTarget = target;
        generatedDownloadFile = file;
        generatedDownloadArchive = false;
        host.dialogs.openGeneratedExport();
    }

    function downloadGeneratedArchive(target) {
        if (busy)
            return ;

        generatedDownloadTarget = target;
        generatedDownloadFile = target + "-generated-files.zip";
        generatedDownloadArchive = true;
        host.dialogs.openGeneratedExport();
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
        applyValidatedPreview(candidate);
        if (selectedId !== Theme.activeThemeId)
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
        duplicateName = modalThemeName + " - Copy";
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
            host.dialogs.openExport();
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
            if (!failed)
                applyValidatedPreview(JSON.parse(request.candidateJson));

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
            const blank = blankTheme(response.data, request.inputs);
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

    onOpenChanged: {
        if (open)
            rendered = true;
        else
            hideTimer.restart();
    }

    Connections {
        function onWidgetEditModeFinished(widgetsJson, returnWorkspace) {
            if (!root.widgetEditModePending)
                return ;

            root.widgetEditModePending = false;
            if (widgetsJson.length > 0) {
                try {
                    root.setWidgetItems(JSON.parse(widgetsJson));
                    root.statusMessage = "Widget positions updated from edit mode.";
                } catch (error) {
                    root.errorMessage = "Could not read the widget edit result: " + error;
                }
            }
            root.rendered = true;
            root.recoverPickerWorkspace(returnWorkspace);
            revealTimer.restart();
        }

        target: Theme
    }

    Timer {
        id: revealTimer

        interval: 320
        repeat: false
        onTriggered: {
            if (!root.open || !root.rendered)
                return ;

            // Floating windows keep their Hyprland workspace across hides.
            // Move a picker stranded by widget edit mode back to the workspace
            Qt.callLater(() => {
                if (root.open && host._backingWindow)
                    host._backingWindow.requestActivate();

            });
        }
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

}
