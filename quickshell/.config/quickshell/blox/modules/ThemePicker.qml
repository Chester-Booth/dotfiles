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
    property bool exportIncludeWallpaper: false
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
    readonly property var targetKeys: ["quickshell", "vicinae", "widgets", "gtk", "cursor", "wallpaper", "kitty", "hyprland", "hyprlock", "btop", "micro", "glow", "code", "cursor_editor", "stylus", "powerlevel10k", "sddm", "grub"]
    readonly property var unavailableTargetKeys: ["widgets", "sddm", "grub"]

    function targetAvailable(key) {
        return unavailableTargetKeys.indexOf(key) < 0;
    }

    function targetLabel(key) {
        if (key === "widgets")
            return key + " · phase 9";

        if (key === "sddm" || key === "grub")
            return key + " · unavailable";

        return key;
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
        if (modalKind === "new")
            newNameField.focusEditor(true);
        else if (modalKind === "duplicate")
            duplicateNameField.focusEditor(true);
        else if (modalKind === "rename")
            renameNameField.focusEditor(true);
        else
            modalCancelButton.forceActiveFocus();
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

        exportIncludeWallpaper = false;
        showModal("export");
    }

    function generateTheme(wallpaper, displayName, themeId) {
        if (!wallpaper || !wallpaper.trim()) {
            errorMessage = "Choose a wallpaper first.";
            return ;
        }
        const args = ["generate", wallpaper.trim(), "--backend", generatorBackend];
        if (displayName)
            args.push("--name", displayName.trim());

        if (themeId)
            args.push("--id", themeId.trim());

        runApi("generate", args);
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
        generateAfterLoad = true;
        openPicker();
        if (dirty) {
            generateAfterLoad = false;
            showModal("generate-current");
            return "confirmation-required";
        }
        if (busy)
            return "queued";

        loadActiveForGeneration();
        return "open-generating";
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

    function openNewTheme() {
        if (busy || dirty)
            return ;

        newThemeName = "Untitled Theme";
        newThemeId = duplicateIdForName(newThemeName);
        newWallpaper = "";
        showModal("new");
    }

    function startNewTheme(fromWallpaper) {
        if (!newThemeName.trim() || !newThemeId.trim())
            return ;

        if (fromWallpaper && !newWallpaper.trim()) {
            errorMessage = "Choose a wallpaper first.";
            return ;
        }
        pendingModalConfirmation = fromWallpaper ? "new-wallpaper" : "new-blank";
        modalDismissTimer.restart();
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
            validatePreview();
        } else if (completedAction === "new-template") {
            const blank = JSON.parse(JSON.stringify(response.data));
            blank.id = newThemeId;
            blank.name = newThemeName;
            delete blank.generator;
            candidate = blank;
            selectedId = candidate.id;
            sourceDigest = "";
            baselineJson = "";
            candidateRevision += 1;
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

            root.runApi("export", args);
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
            if (value !== "overview" && value !== "advanced")
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
            else if (root.modalKind.length > 0)
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
                        text: "Overview"
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
                                Layout.fillWidth: true
                                placeholderText: "Search themes"
                                text: root.searchText
                                onTextChanged: root.searchText = text
                            }

                            BloxButton {
                                Layout.fillWidth: true
                                text: "+  New theme"
                                enabled: root.candidate && !root.dirty && !root.busy
                                onClicked: root.openNewTheme()
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
                                        color: kebabMouse.containsMouse || themeActions.visible ? Theme.surface : "transparent"

                                        Text {
                                            anchors.centerIn: parent
                                            text: "⋮"
                                            color: Theme.muted
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
                                                text: "Revert"
                                                enabled: modelData.id === root.selectedId && root.dirty && root.baselineJson.length > 0 && !root.busy
                                                onClicked: {
                                                    themeActions.close();
                                                    root.revertCandidate();
                                                }
                                            }

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
                                                enabled: modelData.id !== root.selectedId || !root.dirty
                                                onClicked: {
                                                    themeActions.close();
                                                    root.openRename(modelData.id, modelData.name);
                                                }
                                            }

                                            BloxButton {
                                                width: parent.width
                                                text: "Delete"
                                                destructive: true
                                                enabled: modelData.id !== "blox-panel" && (modelData.id !== root.selectedId || !root.dirty) && !root.busy
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

                        ScrollView {
                            id: editorScroll

                            anchors.fill: parent
                            anchors.margins: 14
                            clip: true

                            ColumnLayout {
                                width: Math.max(620, parent.width - 18)
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

                                    Label {
                                        text: "Target impact"
                                        color: Theme.foreground
                                        font.family: Theme.bodyFontFamily
                                        font.pixelSize: 17
                                        font.bold: true
                                    }

                                    Flow {
                                        Layout.fillWidth: true
                                        spacing: 6

                                        Repeater {
                                            model: root.targetKeys

                                            Rectangle {
                                                required property string modelData

                                                width: root.targetAvailable(modelData) ? 112 : 152
                                                height: 30
                                                radius: 15
                                                color: root.targetAvailable(modelData) && root.candidate && root.candidate.targets[modelData] ? Theme.withAlpha(Theme.blue, 0.25) : Theme.background
                                                border.color: root.targetAvailable(modelData) && root.candidate && root.candidate.targets[modelData] ? Theme.blue : Theme.border

                                                Text {
                                                    anchors.centerIn: parent
                                                    text: root.targetLabel(modelData)
                                                    color: root.targetAvailable(modelData) ? Theme.foreground : Theme.muted
                                                    font.family: Theme.fontFamily
                                                    font.pixelSize: 9
                                                }

                                            }

                                        }

                                    }

                                    Label {
                                        text: "Dependency and compatibility notes"
                                        color: Theme.foreground
                                        font.family: Theme.bodyFontFamily
                                        font.pixelSize: 17
                                        font.bold: true
                                    }

                                    Repeater {
                                        model: root.apiWarnings

                                        Text {
                                            required property string modelData

                                            Layout.fillWidth: true
                                            text: "• " + modelData
                                            color: Theme.yellow
                                            wrapMode: Text.Wrap
                                            font.family: Theme.bodyFontFamily
                                            font.pixelSize: 12
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

                                    Flow {
                                        Layout.fillWidth: true

                                        Repeater {
                                            model: root.targetKeys

                                            BloxCheckBox {
                                                required property string modelData

                                                text: root.targetLabel(modelData)
                                                enabled: root.targetAvailable(modelData)
                                                checked: {
                                                    root.candidateRevision;
                                                    return root.candidate ? root.candidate.targets[modelData] : false;
                                                }
                                                onToggled: (value) => {
                                                    if (root.candidate && value !== root.candidate.targets[modelData])
                                                        root.setTarget(modelData, value);

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

                            }

                            ScrollBar.vertical: ScrollBar {
                                policy: ScrollBar.AlwaysOn
                                width: 10

                                contentItem: Rectangle {
                                    implicitWidth: 7
                                    radius: 4
                                    color: Theme.withAlpha(Theme.muted, 0.72)
                                }

                            }

                            ScrollBar.horizontal: ScrollBar {
                                policy: ScrollBar.AlwaysOff
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
                            text: root.modalKind === "new" ? "New theme" : root.modalKind === "delete" ? "Delete theme permanently?" : root.modalKind === "duplicate" ? "Duplicate theme" : root.modalKind === "rename" ? "Rename display name" : root.modalKind === "export" ? "Export theme" : "Discard unsaved changes?"
                            color: Theme.foreground
                            font.family: Theme.bodyFontFamily
                            font.pixelSize: 19
                            font.bold: true
                        }

                        Text {
                            visible: root.modalKind === "new" || root.modalKind === "navigate" || root.modalKind === "generate-current" || root.modalKind === "close" || root.modalKind === "delete" || root.modalKind === "export"
                            Layout.fillWidth: true
                            text: root.modalKind === "new" ? "Start with the standard editable palette, or generate a palette from a wallpaper." : root.modalKind === "delete" ? "This removes the editable source. The action cannot be undone." : root.modalKind === "export" ? "Create a portable bundle. Fonts, GTK, icon and cursor themes remain dependency notes." : "The temporary Quickshell preview will be restored to the active theme."
                            color: Theme.muted
                            wrapMode: Text.Wrap
                            font.family: Theme.bodyFontFamily
                        }

                        BloxTextField {
                            id: newNameField

                            visible: root.modalKind === "new"
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

                        RowLayout {
                            visible: root.modalKind === "new"
                            Layout.fillWidth: true

                            BloxTextField {
                                Layout.fillWidth: true
                                placeholderText: "Optional wallpaper for palette generation"
                                text: root.newWallpaper
                                onTextChanged: root.newWallpaper = text
                            }

                            BloxButton {
                                text: "Browse"
                                onClicked: root.openWallpaperDialog("new")
                            }

                            BloxComboBox {
                                model: ["matugen", "pywal"]
                                currentIndex: root.generatorBackend === "matugen" ? 0 : 1
                                onActivated: (index, selectedText) => {
                                    root.generatorBackend = selectedText;
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

                        RowLayout {
                            Layout.fillWidth: true

                            Text {
                                id: duplicateIdFooter

                                visible: root.modalKind === "duplicate" || root.modalKind === "new"
                                Layout.fillWidth: true
                                text: root.modalKind === "new" ? root.newThemeId : root.duplicateId
                                color: Theme.muted
                                elide: Text.ElideMiddle
                                font.family: Theme.monoFontFamily
                                font.pixelSize: 10
                            }

                            Item {
                                visible: root.modalKind !== "duplicate" && root.modalKind !== "new" && root.modalKind !== "export"
                                Layout.fillWidth: true
                            }

                            BloxButton {
                                id: modalCancelButton

                                text: "Cancel"
                                onClicked: root.dismissModal()
                            }

                            BloxButton {
                                visible: root.modalKind === "new"
                                text: "Create blank"
                                enabled: root.newThemeId.trim().length > 0 && root.newThemeName.trim().length > 0
                                onClicked: root.startNewTheme(false)
                            }

                            BloxButton {
                                visible: root.modalKind === "new"
                                text: "Create from wallpaper"
                                enabled: root.newThemeId.trim().length > 0 && root.newThemeName.trim().length > 0 && root.newWallpaper.trim().length > 0
                                onClicked: root.startNewTheme(true)
                            }

                            BloxButton {
                                visible: root.modalKind !== "new"
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
