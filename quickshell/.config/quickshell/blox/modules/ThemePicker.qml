import "../services"
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
    property alias barDragProxyItem: barDragProxy
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
        const point = row.mapToItem(pickerRoot, 0, 0);
        barDragItemId = itemId;
        barDragLabel = barItemLabel(itemId);
        barDragProxy.width = row.width;
        barDragProxy.height = row.height;
        barDragProxy.x = point.x;
        barDragProxy.y = point.y;
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

        barDragProxy.x = barDragOriginX + deltaX;
        barDragProxy.y = barDragOriginY + deltaY;
    }

    function scrollBarDrag() {
        if (!barDragActive)
            return ;

        const viewport = editorScroll.mapToItem(pickerRoot, 0, 0);
        const pointerY = barDragProxy.y + barDragProxy.height / 2;
        const edge = 54;
        const maximum = Math.max(editorScroll.originY, editorScroll.originY + editorScroll.contentHeight - editorScroll.height);
        if (pointerY > viewport.y + editorScroll.height - edge)
            editorScroll.contentY = Math.min(maximum, editorScroll.contentY + 14);
        else if (pointerY < viewport.y + edge)
            editorScroll.contentY = Math.max(editorScroll.originY, editorScroll.contentY - 14);
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

    function pathBasename(path) {
        const parts = String(path || "").split("/");
        return parts.length > 0 ? parts[parts.length - 1] : "";
    }

    function themePreviewSubtitle(entry) {
        if (entry.unsaved)
            return "Unsaved draft";

        const wallpaper = entry.preview ? pathBasename(entry.preview.wallpaper) : "";
        const uiFont = entry.preview && entry.preview.fonts ? entry.preview.fonts.ui : "";
        return wallpaper || uiFont || "No preview data";
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
        return [scriptRoot + "/overlays/terminal-frame.py", widget.type, "--command", command, "--columns", String(columns), "--rows", String(rows)];
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
        generatedExportDialog.open();
    }

    function downloadGeneratedArchive(target) {
        if (busy)
            return ;

        generatedDownloadTarget = target;
        generatedDownloadFile = target + "-generated-files.zip";
        generatedDownloadArchive = true;
        generatedExportDialog.open();
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

    title: "Blox Theme Picker"
    implicitWidth: 1320
    implicitHeight: 860
    minimumSize: Qt.size(960, 680)
    visible: open && !widgetEditModePending
    color: "transparent"
    onClosed: {
        if (root.open && !root.widgetEditModePending)
            root.closePicker();

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
                if (root.open && root._backingWindow)
                    root._backingWindow.requestActivate();

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
        id: generatedExportDialog

        parentWindow: root._backingWindow
        title: "Download " + root.generatedDownloadFile
        modality: Qt.WindowModal
        fileMode: FileDialog.SaveFile
        defaultSuffix: root.generatedDownloadArchive ? "zip" : root.generatedDownloadFile.indexOf(".") >= 0 ? root.generatedDownloadFile.slice(root.generatedDownloadFile.lastIndexOf(".") + 1) : "txt"
        nameFilters: root.generatedDownloadArchive ? ["Zip archive (*.zip)"] : ["Generated file (*.*)"]
        onAccepted: {
            const path = decodeURIComponent(String(selectedFile).replace(/^file:\/\//, ""));
            const args = ["export-target", root.generatedDownloadTarget, "--output", path];
            if (root.generatedDownloadArchive)
                args.push("--archive");
            else
                args.push("--file", root.generatedDownloadFile);
            root.runApi("export-target", args);
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
        Keys.onPressed: (event) => {
            if (!root.open || !root.candidateValid || !(event.modifiers & Qt.ControlModifier))
                return ;

            if (event.key === Qt.Key_S) {
                root.saveCandidate("");
                event.accepted = true;
            } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                root.applyCandidate();
                event.accepted = true;
            }
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

                    Rectangle {
                        Layout.preferredWidth: 1
                        Layout.preferredHeight: 24
                        color: Theme.border
                    }

                    BloxButton {
                        text: "Widgets"
                        checkable: true
                        checked: root.editorMode === "widgets"
                        onClicked: root.editorMode = "widgets"
                    }

                    Rectangle {
                        Layout.preferredWidth: 1
                        Layout.preferredHeight: 24
                        color: Theme.border
                    }

                    BloxButton {
                        iconName: "x"
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
                                iconName: "plus"
                                iconSize: 20
                                text: "New theme"
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
                                    iconName: "download"
                                    text: "Import"
                                    enabled: !root.dirty && !root.busy
                                    onClicked: root.openImportDialog()
                                }

                                BloxButton {
                                    Layout.fillWidth: true
                                    iconName: "upload"
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
                                    readonly property bool selected: modelData.id === root.selectedId
                                    readonly property color previewBackground: root.themePreviewColour(modelData, "background", Theme.background)
                                    readonly property color previewSurface: root.themePreviewColour(modelData, "surface", Theme.surface)
                                    readonly property color previewSurfaceAlt: root.themePreviewColour(modelData, "surface_alt", Theme.surfaceAlt)
                                    readonly property color previewForeground: root.themePreviewColour(modelData, "foreground", Theme.foreground)
                                    readonly property color previewMuted: root.themePreviewColour(modelData, "muted", Theme.muted)
                                    readonly property color previewAccent: root.themePreviewColour(modelData, "accent", Theme.blue)
                                    readonly property color previewSuccess: root.themePreviewColour(modelData, "success", Theme.green)
                                    readonly property color previewWarning: root.themePreviewColour(modelData, "warning", Theme.yellow)
                                    readonly property string previewFont: modelData.preview && modelData.preview.fonts && modelData.preview.fonts.ui ? modelData.preview.fonts.ui : Theme.bodyFontFamily
                                    readonly property string previewBarPosition: root.themePreviewBarPosition(modelData)
                                    readonly property bool verticalBar: previewBarPosition === "left" || previewBarPosition === "right"
                                    readonly property real maxPreviewWidth: width * 0.5
                                    readonly property real minPreviewWidth: width * 0.3
                                    readonly property real normalWrapWidth: Math.max(themeTitleMetrics.advanceWidth * 0.65, longestWordMetrics.advanceWidth)
                                    readonly property real previewWidth: Math.max(minPreviewWidth, Math.min(maxPreviewWidth, width - 59 - normalWrapWidth))
                                    readonly property bool previewAtMinimum: previewWidth <= minPreviewWidth + 0.5

                                    width: themeList.width - (themeList.contentHeight > themeList.height ? 10 : 0)
                                    height: 82
                                    radius: 10
                                    color: selected ? previewSurface : mouse.containsMouse ? Qt.lighter(previewBackground, 1.13) : previewBackground
                                    border.color: modelData.unsaved ? previewWarning : selected ? previewAccent : mouse.containsMouse ? previewForeground : modelData.id === Theme.activeThemeId ? previewAccent : previewSurfaceAlt
                                    border.width: selected ? 2 : 1
                                    scale: mouse.containsMouse && !selected ? 1.008 : 1
                                    transformOrigin: Item.Center

                                    Rectangle {
                                        id: themeThumbnail

                                        x: 8
                                        y: 8
                                        width: themeDelegate.previewWidth
                                        height: themeDelegate.height - 16
                                        radius: 7
                                        color: themeDelegate.previewSurface
                                        clip: true

                                        Image {
                                            anchors.fill: parent
                                            anchors.margins: 3
                                            source: themeDelegate.modelData.preview && themeDelegate.modelData.preview.wallpaper ? root.localFileUrl(themeDelegate.modelData.preview.wallpaper) : ""
                                            fillMode: Image.PreserveAspectCrop
                                            visible: source.toString().length > 0
                                        }

                                        Rectangle {
                                            anchors.fill: parent
                                            anchors.margins: 3
                                            radius: 5
                                            color: "#18000000"
                                        }

                                        Rectangle {
                                            id: themeBarPreview

                                            x: themeDelegate.previewBarPosition === "right" ? parent.width - width - 3 : 3
                                            y: themeDelegate.previewBarPosition === "bottom" ? parent.height - height - 3 : 3
                                            width: themeDelegate.verticalBar ? 5 : parent.width - 6
                                            height: themeDelegate.verticalBar ? parent.height - 6 : 5
                                            color: themeDelegate.previewSurface

                                            Row {
                                                anchors.left: parent.left
                                                anchors.leftMargin: 2
                                                anchors.verticalCenter: parent.verticalCenter
                                                spacing: 1
                                                visible: !themeDelegate.verticalBar

                                                Repeater {
                                                    model: root.themePreviewBarCount(themeDelegate.modelData, "start")

                                                    Rectangle {
                                                        width: 2
                                                        height: 2
                                                        radius: 1
                                                        color: themeDelegate.previewForeground
                                                    }

                                                }

                                            }

                                            Row {
                                                anchors.centerIn: parent
                                                spacing: 1
                                                visible: !themeDelegate.verticalBar

                                                Repeater {
                                                    model: root.themePreviewBarCount(themeDelegate.modelData, "centre")

                                                    Rectangle {
                                                        width: 2
                                                        height: 2
                                                        radius: 1
                                                        color: themeDelegate.previewAccent
                                                    }

                                                }

                                            }

                                            Row {
                                                anchors.right: parent.right
                                                anchors.rightMargin: 2
                                                anchors.verticalCenter: parent.verticalCenter
                                                spacing: 1
                                                visible: !themeDelegate.verticalBar

                                                Repeater {
                                                    model: root.themePreviewBarCount(themeDelegate.modelData, "end")

                                                    Rectangle {
                                                        width: 2
                                                        height: 2
                                                        radius: 1
                                                        color: themeDelegate.previewForeground
                                                    }

                                                }

                                            }

                                            Column {
                                                anchors.top: parent.top
                                                anchors.topMargin: 2
                                                anchors.horizontalCenter: parent.horizontalCenter
                                                spacing: 1
                                                visible: themeDelegate.verticalBar

                                                Repeater {
                                                    model: root.themePreviewBarCount(themeDelegate.modelData, "start")

                                                    Rectangle {
                                                        width: 2
                                                        height: 2
                                                        radius: 1
                                                        color: themeDelegate.previewForeground
                                                    }

                                                }

                                            }

                                            Column {
                                                anchors.centerIn: parent
                                                spacing: 1
                                                visible: themeDelegate.verticalBar

                                                Repeater {
                                                    model: root.themePreviewBarCount(themeDelegate.modelData, "centre")

                                                    Rectangle {
                                                        width: 2
                                                        height: 2
                                                        radius: 1
                                                        color: themeDelegate.previewAccent
                                                    }

                                                }

                                            }

                                            Column {
                                                anchors.bottom: parent.bottom
                                                anchors.bottomMargin: 2
                                                anchors.horizontalCenter: parent.horizontalCenter
                                                spacing: 1
                                                visible: themeDelegate.verticalBar

                                                Repeater {
                                                    model: root.themePreviewBarCount(themeDelegate.modelData, "end")

                                                    Rectangle {
                                                        width: 2
                                                        height: 2
                                                        radius: 1
                                                        color: themeDelegate.previewForeground
                                                    }

                                                }

                                            }

                                        }

                                    }

                                    Item {
                                        id: themeIdentity

                                        x: themeThumbnail.x + themeThumbnail.width + 10
                                        y: 7
                                        width: themeDelegate.width - x - 8
                                        height: themeDelegate.height - 14

                                        TextMetrics {
                                            id: themeTitleMetrics

                                            font.family: themeDelegate.previewFont
                                            font.pixelSize: 17
                                            font.bold: true
                                            text: themeDelegate.modelData.name
                                        }

                                        TextMetrics {
                                            id: longestWordMetrics

                                            font.family: themeDelegate.previewFont
                                            font.pixelSize: 17
                                            font.bold: true
                                            text: root.longestWord(themeDelegate.modelData.name)
                                        }

                                        Row {
                                            id: themePalette

                                            anchors.left: parent.left
                                            anchors.bottom: parent.bottom
                                            spacing: 5

                                            Repeater {
                                                model: [themeDelegate.previewAccent, themeDelegate.previewSuccess, themeDelegate.previewWarning, themeDelegate.previewForeground]

                                                Rectangle {
                                                    required property color modelData

                                                    width: Math.max(14, Math.min(24, (themeIdentity.width - 15) / 4))
                                                    height: 6
                                                    radius: 3
                                                    color: modelData
                                                }

                                            }

                                        }

                                        Text {
                                            anchors.left: parent.left
                                            anchors.right: parent.right
                                            anchors.rightMargin: 33
                                            anchors.bottom: themePalette.top
                                            anchors.bottomMargin: 4
                                            height: 42
                                            text: themeDelegate.modelData.name
                                            color: themeDelegate.previewForeground
                                            font.family: themeDelegate.previewFont
                                            font.pixelSize: 17
                                            font.bold: true
                                            fontSizeMode: themeDelegate.previewAtMinimum ? Text.Fit : Text.FixedSize
                                            minimumPixelSize: 1
                                            horizontalAlignment: Text.AlignLeft
                                            verticalAlignment: Text.AlignBottom
                                            wrapMode: Text.WordWrap
                                            elide: Text.ElideNone
                                            clip: true
                                        }

                                    }

                                    Rectangle {
                                        id: kebab

                                        z: 2
                                        anchors.right: parent.right
                                        anchors.rightMargin: 7
                                        anchors.verticalCenter: parent.verticalCenter
                                        width: 30
                                        height: 34
                                        radius: 8
                                        color: kebabMouse.containsMouse || themeActions.visible ? Theme.withAlpha(themeDelegate.previewAccent, 0.22) : "transparent"

                                        Text {
                                            anchors.centerIn: parent
                                            text: Lucide.icon("ellipsis")
                                            color: kebabMouse.containsMouse || themeActions.visible ? themeDelegate.previewForeground : themeDelegate.previewMuted
                                            font.family: Lucide.family
                                            font.pixelSize: 18
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

                                    Behavior on color {
                                        ColorAnimation {
                                            duration: 110
                                        }

                                    }

                                    Behavior on border.color {
                                        ColorAnimation {
                                            duration: 110
                                        }

                                    }

                                    Behavior on scale {
                                        NumberAnimation {
                                            duration: 110
                                            easing.type: Easing.OutCubic
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
                                    visible: root.editorMode === "overview"
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
                                            placeholderText: "My Theme"
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
                                                color: root.candidate && root.candidate.colours ? root.validColour(root.candidate.colours[modelData], "transparent") : "transparent"
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
                                        text: "Fonts"
                                        color: Theme.foreground
                                        font.family: Theme.bodyFontFamily
                                        font.pixelSize: 17
                                        font.bold: true
                                    }

                                    GridLayout {
                                        Layout.fillWidth: true
                                        columns: 3
                                        columnSpacing: 10

                                        Repeater {
                                            model: ["ui", "mono", "panel"]

                                            ColumnLayout {
                                                required property string modelData

                                                Layout.fillWidth: true

                                                Label {
                                                    text: modelData === "panel" ? "panel · proportional fonts recommended" : modelData
                                                    color: Theme.muted
                                                }

                                                BloxFontPicker {
                                                    Layout.fillWidth: true
                                                    families: root.fontFamilies
                                                    value: {
                                                        root.candidateRevision;
                                                        return root.candidate && root.candidate.fonts ? root.candidate.fonts[modelData] : "";
                                                    }
                                                    onAccepted: (family) => {
                                                        return root.setFont(modelData, family);
                                                    }
                                                }

                                            }

                                        }

                                    }

                                    Label {
                                        text: "Font samples"
                                        color: Theme.muted
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
                                                    color: root.candidate ? root.validColour(root.candidate.colours[modelData], "transparent") : "transparent"
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

                                    Label {
                                        text: "Bar / OSD / Notifications"
                                        color: Theme.foreground
                                        font.family: Theme.bodyFontFamily
                                        font.pixelSize: 17
                                        font.bold: true
                                    }

                                    Text {
                                        Layout.fillWidth: true
                                        text: "Choose which bar items are shown and arrange them within each section. Tray items remain available in the expanded section."
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
                                                    text: regionSection.modelData === "hidden" ? "Tray" : regionSection.modelData.charAt(0).toUpperCase() + regionSection.modelData.slice(1)
                                                    color: Theme.blue
                                                    font.bold: true
                                                }

                                                DropArea {
                                                    Layout.fillWidth: true
                                                    Layout.preferredHeight: 12
                                                    z: 1
                                                    onEntered: root.setBarDropTarget(regionSection.modelData, 0, "start:" + regionSection.modelData)
                                                    onDropped: (drop) => {
                                                        if (drop.source === root.barDragProxyItem)
                                                            root.finishBarDrag();

                                                    }

                                                    Rectangle {
                                                        anchors.left: parent.left
                                                        anchors.right: parent.right
                                                        anchors.verticalCenter: parent.verticalCenter
                                                        height: 3
                                                        radius: 2
                                                        visible: root.barDragActive && root.barDropTarget === "start:" + regionSection.modelData
                                                        color: Theme.blue
                                                    }

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
                                                        property string barItemId: modelData.id

                                                        Layout.fillWidth: true
                                                        implicitHeight: 48
                                                        radius: 8
                                                        color: handleDrag.active || emptyDrag.active ? Theme.withAlpha(Theme.blue, 0.15) : Theme.background
                                                        border.color: handleDrag.active || emptyDrag.active ? Theme.blue : Theme.border
                                                        z: handleDrag.active || emptyDrag.active ? 20 : 0

                                                        RowLayout {
                                                            anchors.fill: parent
                                                            anchors.margins: 8
                                                            spacing: 9

                                                            Item {
                                                                Layout.preferredWidth: 18
                                                                Layout.fillHeight: true

                                                                Text {
                                                                    anchors.centerIn: parent
                                                                    text: Lucide.icon("grip-vertical")
                                                                    color: handleHover.hovered ? Theme.foreground : Theme.muted
                                                                    font.family: Lucide.family
                                                                    font.pixelSize: 17
                                                                }

                                                                HoverHandler {
                                                                    id: handleHover

                                                                    cursorShape: Qt.SizeAllCursor
                                                                }

                                                                DragHandler {
                                                                    id: handleDrag

                                                                    target: null
                                                                    acceptedButtons: Qt.LeftButton
                                                                    onTranslationChanged: root.moveBarDragProxy(translation.x, translation.y)
                                                                    onActiveChanged: {
                                                                        if (active)
                                                                            root.beginBarDrag(barItemRow, barItemRow.barItemId);
                                                                        else if (root.barDragActive)
                                                                            Qt.callLater(root.finishBarDrag);
                                                                    }
                                                                }

                                                            }

                                                            RowLayout {
                                                                Layout.alignment: Qt.AlignVCenter
                                                                spacing: 9

                                                                BloxCheckBox {
                                                                    text: root.barItemLabel(barItemRow.modelData.id)
                                                                    checked: barItemRow.modelData.enabled
                                                                    onToggled: (value) => {
                                                                        if (value !== barItemRow.modelData.enabled)
                                                                            root.setBarItemEnabled(barItemRow.modelData.id, value);

                                                                    }
                                                                }

                                                                BloxComboBox {
                                                                    readonly property var displayValues: ["toggle", "numeric", "icon"]

                                                                    visible: barItemRow.modelData.id === "battery"
                                                                    Layout.preferredWidth: visible ? 132 : 0
                                                                    Layout.preferredHeight: 32
                                                                    model: ["click to toggle", "only numeric", "only icon"]
                                                                    currentIndex: Math.max(0, displayValues.indexOf(barItemRow.modelData.display || "toggle"))
                                                                    onActivated: (index) => {
                                                                        return root.setBarItemDisplay(barItemRow.barItemId, displayValues[index]);
                                                                    }
                                                                }

                                                                BloxComboBox {
                                                                    readonly property var visibilityValues: ["always", "normal"]

                                                                    visible: ["touchpad", "fan", "gpu"].indexOf(barItemRow.modelData.id) >= 0
                                                                    Layout.preferredWidth: visible ? 172 : 0
                                                                    Layout.preferredHeight: 32
                                                                    model: ["always visible", "hidden when normal"]
                                                                    currentIndex: Math.max(0, visibilityValues.indexOf(barItemRow.modelData.visibility || "normal"))
                                                                    onActivated: (index) => {
                                                                        return root.setBarItemVisibility(barItemRow.barItemId, visibilityValues[index]);
                                                                    }
                                                                }

                                                            }

                                                            Item {
                                                                Layout.fillWidth: true
                                                                Layout.fillHeight: true

                                                                HoverHandler {
                                                                    cursorShape: Qt.SizeAllCursor
                                                                }

                                                                DragHandler {
                                                                    id: emptyDrag

                                                                    target: null
                                                                    acceptedButtons: Qt.LeftButton
                                                                    onTranslationChanged: root.moveBarDragProxy(translation.x, translation.y)
                                                                    onActiveChanged: {
                                                                        if (active)
                                                                            root.beginBarDrag(barItemRow, barItemRow.barItemId);
                                                                        else if (root.barDragActive)
                                                                            Qt.callLater(root.finishBarDrag);
                                                                    }
                                                                }

                                                            }

                                                            BloxButton {
                                                                Layout.preferredWidth: 34
                                                                Layout.preferredHeight: 32
                                                                compact: true
                                                                iconName: "chevron-up"
                                                                enabled: barItemRow.modelData.id === "application-tray" ? false : barItemRow.modelData.id === "tray" ? barItemRow.modelData.region === "centre" && barItemRow.index > 0 : barItemRow.index > 0
                                                                onClicked: root.moveBarItem(barItemRow.barItemId, -1)
                                                            }

                                                            BloxButton {
                                                                Layout.preferredWidth: 34
                                                                Layout.preferredHeight: 32
                                                                compact: true
                                                                iconName: "chevron-down"
                                                                enabled: barItemRow.modelData.id === "application-tray" ? false : barItemRow.modelData.id === "tray" ? barItemRow.modelData.region === "centre" && barItemRow.index === 0 && barItemRepeater.count > 1 : barItemRow.index < barItemRepeater.count - 1
                                                                onClicked: root.moveBarItem(barItemRow.barItemId, 1)
                                                            }

                                                            BloxComboBox {
                                                                Layout.preferredWidth: 92
                                                                Layout.preferredHeight: 32
                                                                model: barItemRow.modelData.id === "application-tray" ? ["tray"] : barItemRow.modelData.id === "tray" ? ["start", "centre", "end"] : root.barRegions
                                                                currentIndex: model.indexOf(barItemRow.modelData.region === "hidden" ? "tray" : barItemRow.modelData.region)
                                                                onActivated: (index, value) => {
                                                                    return root.setBarItemRegion(barItemRow.barItemId, value === "tray" ? "hidden" : value);
                                                                }
                                                            }

                                                        }

                                                        DropArea {
                                                            anchors.fill: parent
                                                            enabled: !(handleDrag.active || emptyDrag.active)
                                                            z: 2
                                                            onEntered: (drag) => {
                                                                const insertion = drag.y < height / 2 ? barItemRow.index : barItemRow.index + 1;
                                                                root.setBarDropTarget(regionSection.modelData, insertion, barItemRow.barItemId);
                                                            }
                                                            onPositionChanged: (drag) => {
                                                                const insertion = drag.y < height / 2 ? barItemRow.index : barItemRow.index + 1;
                                                                root.setBarDropTarget(regionSection.modelData, insertion, barItemRow.barItemId);
                                                            }
                                                            onDropped: (drop) => {
                                                                if (drop.source === root.barDragProxyItem)
                                                                    root.finishBarDrag();

                                                            }
                                                        }

                                                        Rectangle {
                                                            anchors.left: parent.left
                                                            anchors.right: parent.right
                                                            anchors.top: root.barDropIndex === barItemRow.index ? parent.top : undefined
                                                            anchors.bottom: root.barDropIndex === barItemRow.index + 1 ? parent.bottom : undefined
                                                            height: 3
                                                            radius: 2
                                                            z: 40
                                                            visible: root.barDragActive && root.barDropTarget === barItemRow.barItemId
                                                            color: Theme.blue
                                                        }

                                                    }

                                                }

                                            }

                                        }

                                    }

                                    GridLayout {
                                        Layout.fillWidth: true
                                        columns: 6
                                        columnSpacing: 8
                                        rowSpacing: 8

                                        Label {
                                            text: "Bar"
                                            color: Theme.muted
                                        }

                                        BloxComboBox {
                                            Layout.fillWidth: true
                                            Layout.columnSpan: 5
                                            model: ["left", "right", "top", "bottom"]
                                            currentIndex: model.indexOf(root.shellValue("bar", "position"))
                                            onActivated: (index, value) => {
                                                return root.setShellValue("bar", "position", value);
                                            }
                                        }

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

                                        Label {
                                            text: "X offset"
                                            color: Theme.muted
                                        }

                                        BloxTextField {
                                            text: String(root.shellValue("osd", "offset_x"))
                                            suffix: "px"
                                            onEditingFinished: root.setShellValue("osd", "offset_x", parseInt(text) || 0)
                                        }

                                        Label {
                                            text: "Y offset"
                                            color: Theme.muted
                                        }

                                        BloxTextField {
                                            text: String(root.shellValue("osd", "offset_y"))
                                            suffix: "px"
                                            onEditingFinished: root.setShellValue("osd", "offset_y", parseInt(text) || 0)
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

                                        Label {
                                            text: "X offset"
                                            color: Theme.muted
                                        }

                                        BloxTextField {
                                            text: String(root.shellValue("notifications", "offset_x"))
                                            suffix: "px"
                                            onEditingFinished: root.setShellValue("notifications", "offset_x", parseInt(text) || 0)
                                        }

                                        Label {
                                            text: "Y offset"
                                            color: Theme.muted
                                        }

                                        BloxTextField {
                                            text: String(root.shellValue("notifications", "offset_y"))
                                            suffix: "px"
                                            onEditingFinished: root.setShellValue("notifications", "offset_y", parseInt(text) || 0)
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
                                                    text: modelData === "panel" ? "panel · proportional fonts recommended" : modelData
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
                                                height: 54
                                                radius: 8
                                                color: Theme.background
                                                border.color: Theme.border

                                                RowLayout {
                                                    anchors.fill: parent
                                                    anchors.margins: 7

                                                    BloxCheckBox {
                                                        Layout.fillWidth: true
                                                        Layout.alignment: Qt.AlignVCenter
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
                                                        Layout.alignment: Qt.AlignVCenter
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
                                                height: 54
                                                radius: 8
                                                color: Theme.background
                                                border.color: Theme.border

                                                RowLayout {
                                                    anchors.fill: parent
                                                    anchors.margins: 7

                                                    BloxCheckBox {
                                                        Layout.fillWidth: true
                                                        Layout.alignment: Qt.AlignVCenter
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
                                                        Layout.alignment: Qt.AlignVCenter
                                                        visible: root.targetApplyMode(modelData) !== "manual"
                                                        text: root.targetModeLabel(modelData)
                                                        color: root.targetApplyMode(modelData) === "restart" ? Theme.yellow : Theme.green
                                                        font.pixelSize: 9
                                                    }

                                                    BloxButton {
                                                        Layout.alignment: Qt.AlignVCenter
                                                        Layout.preferredHeight: 32
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
                                        text: "Generated Files"
                                        color: Theme.foreground
                                        font.family: Theme.bodyFontFamily
                                        font.pixelSize: 17
                                        font.bold: true
                                    }

                                    Text {
                                        Layout.fillWidth: true
                                        text: "Download the generated files for the currently selected targets. Apply or save the theme first so the active generation is up to date."
                                        color: Theme.muted
                                        font.family: Theme.bodyFontFamily
                                        wrapMode: Text.Wrap
                                    }

                                    ColumnLayout {
                                        Layout.fillWidth: true
                                        spacing: 8

                                        Repeater {
                                            model: {
                                                root.candidateRevision;
                                                return root.generatedFileGroups();
                                            }

                                            ColumnLayout {
                                                required property var modelData

                                                Layout.fillWidth: true
                                                spacing: 6

                                                RowLayout {
                                                    Layout.fillWidth: true

                                                    Label {
                                                        Layout.fillWidth: true
                                                        text: root.targetLabel(modelData.target)
                                                        color: Theme.blue
                                                        font.family: Theme.fontFamily
                                                        font.pixelSize: 12
                                                        font.bold: true
                                                    }

                                                    BloxButton {
                                                        visible: modelData.files.length > 1
                                                        iconName: "download"
                                                        text: "Download all (.zip)"
                                                        onClicked: root.downloadGeneratedArchive(modelData.target)
                                                    }

                                                }

                                                Flow {
                                                    Layout.fillWidth: true
                                                    spacing: 8

                                                    Repeater {
                                                        model: modelData.files

                                                        BloxButton {
                                                            required property var modelData

                                                            iconName: "download"
                                                            text: modelData.name
                                                            onClicked: root.downloadGeneratedFile(modelData.target, modelData.file)
                                                        }

                                                    }

                                                }

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
                                                                iconName: "rotate-ccw"
                                                                text: ""
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

                                    Label {
                                        text: "Style"
                                        color: Theme.foreground
                                        font.pixelSize: 17
                                        font.bold: true
                                    }

                                    BloxComboBox {
                                        Layout.fillWidth: true
                                        model: ["minimal", "compact", "comfortable"]
                                        currentIndex: {
                                            root.candidateRevision;
                                            const profile = root.candidate && root.candidate.widgets ? root.candidate.widgets.profile : "minimal";
                                            return Math.max(0, model.indexOf(profile));
                                        }
                                        onActivated: (index, value) => {
                                            return root.setWidgetProfile(value);
                                        }
                                    }

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
                                            iconName: "grid-2x2"
                                            text: "Edit mode"
                                            onClicked: root.openWidgetEditMode()
                                        }

                                        BloxButton {
                                            iconName: "plus"
                                            text: "New Widget"
                                            onClicked: root.openWidgetEditor(-1)
                                        }

                                        BloxButton {
                                            iconName: "download"
                                            text: "Import"
                                            onClicked: widgetImportDialog.open()
                                        }

                                        BloxButton {
                                            iconName: "upload"
                                            text: "Export"
                                            onClicked: widgetExportDialog.open()
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
                                        visible: false
                                        text: "Position"
                                        color: Theme.foreground
                                        font.bold: true
                                    }

                                    Text {
                                        visible: false
                                        Layout.fillWidth: true
                                        text: "Drag a widget to position it. Drop near a corner to snap it; drag any edge to resize."
                                        color: Theme.muted
                                        wrapMode: Text.Wrap
                                    }

                                    Rectangle {
                                        id: widgetCanvas

                                        visible: false
                                        Layout.fillWidth: true
                                        Layout.preferredHeight: Math.min(520, width * 9 / 16)
                                        clip: true
                                        radius: 12
                                        color: Theme.background
                                        border.color: Theme.border

                                        Rectangle {
                                            id: barPreview

                                            property string barPosition: root.candidate && root.candidate.shell && root.candidate.shell.bar ? root.candidate.shell.bar.position : "left"
                                            readonly property bool horizontal: barPosition === "top" || barPosition === "bottom"

                                            anchors.left: barPosition === "left" || barPosition === "top" || barPosition === "bottom" ? parent.left : undefined
                                            anchors.right: barPosition === "right" || barPosition === "top" || barPosition === "bottom" ? parent.right : undefined
                                            anchors.top: barPosition === "top" || barPosition === "left" || barPosition === "right" ? parent.top : undefined
                                            anchors.bottom: barPosition === "bottom" || barPosition === "left" || barPosition === "right" ? parent.bottom : undefined
                                            width: horizontal ? parent.width : 18
                                            height: horizontal ? 18 : parent.height
                                            z: 4
                                            color: Theme.withAlpha(Theme.surface, 0.94)
                                            border.color: Theme.border

                                            Row {
                                                anchors.left: parent.left
                                                anchors.verticalCenter: parent.verticalCenter
                                                visible: barPreview.horizontal

                                                Repeater {
                                                    model: root.barPreviewItems("start")

                                                    delegate: PreviewBarItem {
                                                    }

                                                }

                                            }

                                            Row {
                                                anchors.centerIn: parent
                                                visible: barPreview.horizontal

                                                Repeater {
                                                    model: root.barPreviewItems("centre")

                                                    delegate: PreviewBarItem {
                                                    }

                                                }

                                            }

                                            Row {
                                                anchors.right: parent.right
                                                anchors.verticalCenter: parent.verticalCenter
                                                visible: barPreview.horizontal

                                                Repeater {
                                                    model: root.barPreviewItems("end")

                                                    delegate: PreviewBarItem {
                                                    }

                                                }

                                            }

                                            Column {
                                                anchors.top: parent.top
                                                anchors.horizontalCenter: parent.horizontalCenter
                                                visible: !barPreview.horizontal

                                                Repeater {
                                                    model: root.barPreviewItems("start")

                                                    delegate: PreviewBarItem {
                                                    }

                                                }

                                            }

                                            Column {
                                                anchors.centerIn: parent
                                                visible: !barPreview.horizontal

                                                Repeater {
                                                    model: root.barPreviewItems("centre")

                                                    delegate: PreviewBarItem {
                                                    }

                                                }

                                            }

                                            Column {
                                                anchors.bottom: parent.bottom
                                                anchors.horizontalCenter: parent.horizontalCenter
                                                visible: !barPreview.horizontal

                                                Repeater {
                                                    model: root.barPreviewItems("end")

                                                    delegate: PreviewBarItem {
                                                    }

                                                }

                                            }

                                            component PreviewBarItem: Item {
                                                required property var modelData

                                                width: barPreview.horizontal ? 15 : barPreview.width
                                                height: barPreview.horizontal ? barPreview.height : 15

                                                Text {
                                                    anchors.centerIn: parent
                                                    text: Lucide.icon(root.barPreviewIcon(parent.modelData.id))
                                                    color: Theme.foreground
                                                    font.family: Lucide.family
                                                    font.pixelSize: 8
                                                }

                                            }

                                        }

                                        TapHandler {
                                            acceptedButtons: Qt.LeftButton
                                            onTapped: root.selectedWidgetIndex = -1
                                        }

                                        Image {
                                            anchors.fill: parent
                                            source: root.candidate && root.candidate.wallpaper && root.candidate.wallpaper.path ? root.localFileUrl(root.candidate.wallpaper.path) : "data:image/gif;base64,R0lGODlhAQABAAD/ACwAAAAAAQABAAACADs="
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

                                                ScriptPoller {
                                                    id: previewWidgetContent

                                                    command: root.widgetPreviewCommand(widgetPreview.modelData)
                                                    interval: Math.max(500, widgetPreview.modelData.interval_ms || 60000)
                                                }

                                                Text {
                                                    anchors.centerIn: parent
                                                    width: parent.width - 16
                                                    text: previewWidgetContent.raw.trim().length > 0 ? previewWidgetContent.raw : widgetPreview.modelData.name
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

                                                MouseArea {
                                                    property real startCanvasX: 0
                                                    property real startPreviewX: 0
                                                    property real startWidth: 0

                                                    anchors.left: parent.left
                                                    anchors.top: parent.top
                                                    anchors.bottom: parent.bottom
                                                    width: 7
                                                    cursorShape: Qt.SizeHorCursor
                                                    onPressed: (mouse) => {
                                                        const point = mapToItem(widgetCanvas, mouse.x, mouse.y);
                                                        startCanvasX = point.x;
                                                        startPreviewX = widgetPreview.x;
                                                        startWidth = widgetPreview.width;
                                                        root.selectedWidgetIndex = widgetPreview.index;
                                                    }
                                                    onPositionChanged: (mouse) => {
                                                        if (!pressed)
                                                            return ;

                                                        const point = mapToItem(widgetCanvas, mouse.x, mouse.y);
                                                        const delta = Math.min(startWidth - 48, point.x - startCanvasX);
                                                        widgetPreview.x = startPreviewX + delta;
                                                        widgetPreview.width = startWidth - delta;
                                                    }
                                                    onReleased: root.commitWidgetPreview(widgetPreview.index, widgetPreview.x, widgetPreview.y, widgetPreview.width, widgetPreview.height, widgetCanvas.width, widgetCanvas.height)
                                                }

                                                MouseArea {
                                                    property real startCanvasX: 0
                                                    property real startWidth: 0

                                                    anchors.right: parent.right
                                                    anchors.top: parent.top
                                                    anchors.bottom: parent.bottom
                                                    width: 7
                                                    cursorShape: Qt.SizeHorCursor
                                                    onPressed: (mouse) => {
                                                        startCanvasX = mapToItem(widgetCanvas, mouse.x, mouse.y).x;
                                                        startWidth = widgetPreview.width;
                                                        root.selectedWidgetIndex = widgetPreview.index;
                                                    }
                                                    onPositionChanged: (mouse) => {
                                                        if (pressed)
                                                            widgetPreview.width = Math.max(48, Math.min(widgetCanvas.width - widgetPreview.x, startWidth + mapToItem(widgetCanvas, mouse.x, mouse.y).x - startCanvasX));

                                                    }
                                                    onReleased: root.commitWidgetPreview(widgetPreview.index, widgetPreview.x, widgetPreview.y, widgetPreview.width, widgetPreview.height, widgetCanvas.width, widgetCanvas.height)
                                                }

                                                MouseArea {
                                                    property real startCanvasY: 0
                                                    property real startPreviewY: 0
                                                    property real startHeight: 0

                                                    anchors.left: parent.left
                                                    anchors.right: parent.right
                                                    anchors.top: parent.top
                                                    height: 7
                                                    cursorShape: Qt.SizeVerCursor
                                                    onPressed: (mouse) => {
                                                        const point = mapToItem(widgetCanvas, mouse.x, mouse.y);
                                                        startCanvasY = point.y;
                                                        startPreviewY = widgetPreview.y;
                                                        startHeight = widgetPreview.height;
                                                        root.selectedWidgetIndex = widgetPreview.index;
                                                    }
                                                    onPositionChanged: (mouse) => {
                                                        if (!pressed)
                                                            return ;

                                                        const point = mapToItem(widgetCanvas, mouse.x, mouse.y);
                                                        const delta = Math.min(startHeight - 32, point.y - startCanvasY);
                                                        widgetPreview.y = startPreviewY + delta;
                                                        widgetPreview.height = startHeight - delta;
                                                    }
                                                    onReleased: root.commitWidgetPreview(widgetPreview.index, widgetPreview.x, widgetPreview.y, widgetPreview.width, widgetPreview.height, widgetCanvas.width, widgetCanvas.height)
                                                }

                                                MouseArea {
                                                    property real startCanvasY: 0
                                                    property real startHeight: 0

                                                    anchors.left: parent.left
                                                    anchors.right: parent.right
                                                    anchors.bottom: parent.bottom
                                                    height: 7
                                                    cursorShape: Qt.SizeVerCursor
                                                    onPressed: (mouse) => {
                                                        startCanvasY = mapToItem(widgetCanvas, mouse.x, mouse.y).y;
                                                        startHeight = widgetPreview.height;
                                                        root.selectedWidgetIndex = widgetPreview.index;
                                                    }
                                                    onPositionChanged: (mouse) => {
                                                        if (pressed)
                                                            widgetPreview.height = Math.max(32, Math.min(widgetCanvas.height - widgetPreview.y, startHeight + mapToItem(widgetCanvas, mouse.x, mouse.y).y - startCanvasY));

                                                    }
                                                    onReleased: root.commitWidgetPreview(widgetPreview.index, widgetPreview.x, widgetPreview.y, widgetPreview.width, widgetPreview.height, widgetCanvas.width, widgetCanvas.height)
                                                }

                                            }

                                        }

                                    }

                                    GridLayout {
                                        visible: false
                                        Layout.fillWidth: true
                                        columns: 4
                                        columnSpacing: 10
                                        rowSpacing: 6

                                        BloxCheckBox {
                                            Layout.columnSpan: 4
                                            text: "Automatic size"
                                            checked: {
                                                const item = root.selectedWidgetIndex >= 0 && root.selectedWidgetIndex < root.widgetItems().length ? root.widgetItems()[root.selectedWidgetIndex] : null;
                                                return item && item.width === 0 && item.height === 0;
                                            }
                                            onToggled: (checked) => {
                                                const item = root.widgetItems()[root.selectedWidgetIndex];
                                                root.updateWidgetGeometry(root.selectedWidgetIndex, item.anchor, item.offset_x, item.offset_y, checked ? 0 : 320, checked ? 0 : 160);
                                            }
                                        }

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
                                                enabled: modelData === "offset_x" || modelData === "offset_y" || !selectedItem || selectedItem.width > 0 || selectedItem.height > 0
                                                text: selectedItem ? String(selectedItem[modelData]) : "0"
                                                ToolTip.visible: hovered && !enabled
                                                ToolTip.text: "Disable Automatic size to set width and height"
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
                        iconName: "save"
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

            Rectangle {
                id: barDragProxy

                property string barItemId: root.barDragItemId

                z: 1000
                visible: root.barDragActive
                radius: 8
                color: Theme.withAlpha(Theme.surface, 0.98)
                border.color: Theme.blue
                border.width: 2
                Drag.active: root.barDragActive
                Drag.source: barDragProxy
                Drag.hotSpot.x: width / 2
                Drag.hotSpot.y: height / 2

                Text {
                    anchors.centerIn: parent
                    text: root.barDragLabel
                    color: Theme.foreground
                    font.family: Theme.bodyFontFamily
                }

            }

            Timer {
                interval: 16
                repeat: true
                running: root.barDragActive
                onTriggered: root.scrollBarDrag()
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
                    height: Math.min(root.height - 80, implicitHeight)
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
                            placeholderText: "My Theme"
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
                                text: root.guideTarget === "obsidian" ? "1. Install and select the Minimal theme, then enable the Style Settings plugin.\n2. Open Style Settings in its own pane and choose Import.\n3. Select the generated style-settings.json file and confirm the import." : "1. Open the Stylus extension dashboard.\n2. Choose Import and select the generated blox-system.user.css file.\n3. Replace the previous Blox System Theme entry, then enable it."
                                color: Theme.foreground
                                wrapMode: Text.Wrap
                            }

                            BloxButton {
                                visible: root.guideTarget === "stylus"
                                Layout.alignment: Qt.AlignRight
                                iconName: "download"
                                text: "Download file"
                                onClicked: root.downloadGeneratedFile("stylus", "stylus/blox-system.user.css")
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
                                onTextEdited: (value) => {
                                    if (root.widgetDraft)
                                        root.updateWidgetDraft({
                                        "name": value
                                    });

                                }
                            }

                            Label {
                                text: "Preset"
                                color: Theme.muted
                            }

                            BloxComboBox {
                                Layout.fillWidth: true
                                model: ["file", "music", "calendar", "clock", "decorative", "custom"]
                                currentIndex: root.widgetDraft ? model.indexOf(root.widgetPreset(root.widgetDraft)) : model.length - 1
                                onActivated: (index, value) => {
                                    const identity = root.widgetDraft.id;
                                    const name = root.widgetDraft.name;
                                    root.widgetDraft = root.newWidgetDraft(value === "decorative" ? "aquarium" : value);
                                    root.updateWidgetDraft({
                                        "id": identity,
                                        "name": name
                                    });
                                }
                            }

                            Label {
                                visible: root.widgetDraft && root.widgetPreset(root.widgetDraft) === "decorative"
                                text: "Decoration"
                                color: Theme.muted
                            }

                            BloxComboBox {
                                visible: root.widgetDraft && root.widgetPreset(root.widgetDraft) === "decorative"
                                Layout.fillWidth: true
                                model: ["aquarium", "pipes", "tree", "matrix", "fortune", "train"]
                                currentIndex: root.widgetDraft ? model.indexOf(root.widgetDraft.type) : 0
                                onActivated: (index, value) => {
                                    const replacement = root.newWidgetDraft(value);
                                    root.updateWidgetDraft({
                                        "type": value,
                                        "content_command": replacement.content_command,
                                        "options": replacement.options
                                    });
                                }
                            }

                            Label {
                                visible: root.widgetDraft && (root.widgetDraft.type === "custom" || root.widgetDraft.type === "file")
                                text: "Content command"
                                color: Theme.muted
                            }

                            RowLayout {
                                visible: root.widgetDraft && (root.widgetDraft.type === "custom" || root.widgetDraft.type === "file")
                                Layout.fillWidth: true

                                BloxTextField {
                                    Layout.fillWidth: true
                                    text: root.widgetDraft ? root.widgetDraft.content_command : ""
                                    onTextEdited: (value) => {
                                        if (root.widgetDraft)
                                            root.updateWidgetDraft({
                                            "content_command": value
                                        });

                                    }
                                }

                                BloxButton {
                                    visible: root.widgetDraft && root.widgetDraft.type === "file"
                                    text: "Browse"
                                    onClicked: widgetFileDialog.open()
                                }

                            }

                            Label {
                                visible: root.widgetDraft && root.widgetDraft.type === "custom"
                                text: "Left click"
                                color: Theme.muted
                            }

                            BloxTextField {
                                visible: root.widgetDraft && root.widgetDraft.type === "custom"
                                Layout.fillWidth: true
                                text: root.widgetDraft ? root.widgetDraft.left_click_command : ""
                                onTextEdited: (value) => {
                                    if (root.widgetDraft)
                                        root.updateWidgetDraft({
                                        "left_click_command": value
                                    });

                                }
                            }

                            Label {
                                visible: root.widgetDraft && root.widgetDraft.type === "custom"
                                text: "Right click"
                                color: Theme.muted
                            }

                            BloxTextField {
                                visible: root.widgetDraft && root.widgetDraft.type === "custom"
                                Layout.fillWidth: true
                                text: root.widgetDraft ? root.widgetDraft.right_click_command : ""
                                onTextEdited: (value) => {
                                    if (root.widgetDraft)
                                        root.updateWidgetDraft({
                                        "right_click_command": value
                                    });

                                }
                            }

                            Label {
                                visible: root.widgetDraft && (root.widgetDraft.type === "custom" || root.widgetDraft.type === "file")
                                text: "Update (ms)"
                                color: Theme.muted
                            }

                            BloxTextField {
                                visible: root.widgetDraft && (root.widgetDraft.type === "custom" || root.widgetDraft.type === "file")
                                Layout.fillWidth: true
                                text: root.widgetDraft ? String(root.widgetDraft.interval_ms) : "60000"
                                onEditingFinished: {
                                    if (root.widgetDraft)
                                        root.updateWidgetDraft({
                                        "interval_ms": Math.max(250, parseInt(text) || 60000)
                                    });

                                }
                            }

                            Label {
                                visible: root.widgetDraft && root.widgetDraft.type === "clock"
                                text: "Clock options"
                                color: Theme.muted
                            }

                            RowLayout {
                                visible: root.widgetDraft && root.widgetDraft.type === "clock"

                                BloxCheckBox {
                                    text: "24 hour"
                                    checked: !(root.widgetDraft && root.widgetDraft.options && root.widgetDraft.options.twelve_hour)
                                    onToggled: root.updateWidgetOption("twelve_hour", !checked)
                                }

                                BloxCheckBox {
                                    text: "Seconds"
                                    checked: root.widgetDraft && root.widgetDraft.options && root.widgetDraft.options.seconds === true
                                    onToggled: root.updateWidgetOption("seconds", checked)
                                }

                                BloxCheckBox {
                                    text: "Bold"
                                    checked: root.widgetDraft && root.widgetDraft.options && root.widgetDraft.options.bold === true
                                    onToggled: root.updateWidgetOption("bold", checked)
                                }

                                BloxCheckBox {
                                    text: "Blink"
                                    checked: root.widgetDraft && root.widgetDraft.options && root.widgetDraft.options.blink === true
                                    onToggled: root.updateWidgetOption("blink", checked)
                                }

                                BloxCheckBox {
                                    text: "Box"
                                    checked: root.widgetDraft && root.widgetDraft.options && root.widgetDraft.options.box === true
                                    onToggled: root.updateWidgetOption("box", checked)
                                }

                            }

                            Label {
                                visible: root.widgetDraft && root.widgetDraft.type === "calendar"
                                text: "View"
                                color: Theme.muted
                            }

                            BloxComboBox {
                                visible: root.widgetDraft && root.widgetDraft.type === "calendar"
                                Layout.fillWidth: true
                                model: ["agenda", "week", "month"]
                                currentIndex: root.widgetDraft && root.widgetDraft.options ? Math.max(0, model.indexOf(root.widgetDraft.options.view || "agenda")) : 0
                                onActivated: (index, value) => {
                                    return root.updateWidgetOption("view", value);
                                }
                            }

                            Label {
                                visible: root.widgetDraft && root.widgetDraft.type === "calendar"
                                text: "Line art"
                                color: Theme.muted
                            }

                            RowLayout {
                                visible: root.widgetDraft && root.widgetDraft.type === "calendar"

                                BloxComboBox {
                                    Layout.fillWidth: true
                                    model: ["fancy", "unicode", "ascii"]
                                    currentIndex: root.widgetDraft && root.widgetDraft.options ? Math.max(0, model.indexOf(root.widgetDraft.options.lineart || "unicode")) : 1
                                    onActivated: (index, value) => {
                                        return root.updateWidgetOption("lineart", value);
                                    }
                                }

                                BloxCheckBox {
                                    text: "Colour"
                                    checked: !root.widgetDraft || !root.widgetDraft.options || root.widgetDraft.options.colour !== false
                                    onToggled: root.updateWidgetOption("colour", checked)
                                }

                            }

                            Label {
                                visible: root.widgetDraft && root.widgetDraft.type === "music"
                                text: "Cava config file"
                                color: Theme.muted
                            }

                            BloxTextField {
                                visible: root.widgetDraft && root.widgetDraft.type === "music"
                                Layout.fillWidth: true
                                placeholderText: "~/.config/cava/config"
                                text: root.widgetDraft && root.widgetDraft.options ? root.widgetDraft.options.config_file || "" : ""
                                onEditingFinished: root.updateWidgetOption("config_file", text.trim())
                            }

                            Label {
                                visible: root.widgetDraft && root.widgetDraft.type === "file"
                                text: "File options"
                                color: Theme.muted
                            }

                            RowLayout {
                                visible: root.widgetDraft && root.widgetDraft.type === "file"
                                Layout.fillWidth: true
                                Layout.rightMargin: 10

                                BloxCheckBox {
                                    text: "Show filename"
                                    checked: root.widgetDraft && root.widgetDraft.options && root.widgetDraft.options.show_filename === true
                                    onToggled: root.updateWidgetOption("show_filename", checked)
                                }

                                BloxCheckBox {
                                    text: "Markdown"
                                    checked: root.widgetDraft && root.widgetDraft.options && root.widgetDraft.options.markdown === true
                                    onToggled: root.updateWidgetOption("markdown", checked)
                                }

                                BloxCheckBox {
                                    text: "Auto update"
                                    checked: !root.widgetDraft || !root.widgetDraft.options || root.widgetDraft.options.auto_update !== false
                                    onToggled: root.updateWidgetOption("auto_update", checked)
                                }

                            }

                        }

                        BloxTextField {
                            id: duplicateNameField

                            visible: root.modalKind === "duplicate"
                            Layout.fillWidth: true
                            placeholderText: "My Theme - Copy"
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
                            placeholderText: "My Theme"
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
                                iconName: root.modalKind === "progress" || root.modalKind === "guide" ? "x" : ""
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
                                            color: root.candidate ? root.validColour(root.candidate.colours[modelData], "transparent") : "transparent"
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
