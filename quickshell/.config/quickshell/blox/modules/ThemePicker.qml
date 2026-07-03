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
    property var fontFamilies: []
    property string fontOutput: ""
    property bool colourPickerOpen: false
    property string colourPickerKey: ""
    property string colourPickerTarget: ""
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
        colourPickerOpen = true;
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
            requestSelection(Theme.themeId, false);
        return "open";
    }

    function requestClose() {
        if (busy)
            return ;

        if (dirty) {
            modalKind = "close";
            return ;
        }
        closePicker();
    }

    function closePicker() {
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
        hideTimer.restart();
    }

    function requestSelection(id, confirmDirty) {
        if (!id || id === selectedId && candidate !== null)
            return ;

        if (confirmDirty && dirty) {
            pendingSelection = id;
            modalKind = "navigate";
            return ;
        }
        runApi("show", ["show", id]);
    }

    function validatePreview() {
        if (candidate === null || busy)
            return ;

        runApi("preview-edit", ["preview", JSON.stringify(candidate)]);
    }

    function markCandidate(value) {
        candidate = value;
        candidateRevision += 1;
        candidateValid = false;
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

    function generateTheme(wallpaper) {
        if (!wallpaper || !wallpaper.trim()) {
            errorMessage = "Choose a wallpaper first.";
            return ;
        }
        runApi("generate", ["generate", wallpaper.trim(), "--backend", generatorBackend]);
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

    function openDuplicate() {
        if (candidate === null || dirty || !sourceDigest)
            return ;

        duplicateName = candidate.name + " Copy";
        duplicateId = duplicateIdForName(duplicateName);
        modalKind = "duplicate";
    }

    function openRename() {
        if (candidate === null || dirty || !sourceDigest)
            return ;

        renameName = candidate.name;
        modalKind = "rename";
    }

    function requestDelete() {
        if (candidate === null || dirty || candidate.id === "blox-panel")
            return ;

        modalKind = "delete";
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
            runApi("delete", ["delete", candidate.id, "--yes"]);
        else if (kind === "duplicate")
            runApi("duplicate", ["duplicate", candidate.id, duplicateId.trim(), "--name", duplicateName.trim()]);
        else if (kind === "rename")
            runApi("rename", ["rename", candidate.id, renameName.trim()]);
    }

    function dismissColourPicker() {
        colourDismissTimer.restart();
    }

    function handleResponse(response) {
        const failed = !response || response.ok !== true;
        if (action === "preview-edit") {
            candidateValid = !failed;
            validationErrors = response && response.errors ? response.errors : ["Preview validation failed."];
            apiWarnings = response && response.warnings ? response.warnings : [];
            previewData = response && response.data ? response.data : ({
            });
            if (!failed) {
                Theme.previewSource(candidate);
                statusMessage = dirty ? "Temporary Quickshell preview — unsaved" : "Temporary Quickshell preview";
            }
            return ;
        }
        if (failed) {
            errorMessage = response && response.errors ? response.errors.join("\n") : "Theme action failed.";
            return ;
        }
        apiWarnings = response.warnings || [];
        if (action === "list" || action === "list-refresh") {
            themes = response.data || [];
            if (action === "list") {
                const preferred = themes.some((entry) => {
                    return entry.id === Theme.themeId;
                }) ? Theme.themeId : (themes.length > 0 ? themes[0].id : "");
                if (preferred)
                    requestSelection(preferred, false);

            }
        } else if (action === "show") {
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
        } else if (action === "generate") {
            candidate = JSON.parse(JSON.stringify(response.data.theme));
            selectedId = candidate.id;
            sourceDigest = "";
            baselineJson = "";
            previewData = response.data;
            candidateRevision += 1;
            validatePreview();
        } else if (action === "save") {
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
        } else if (action === "apply") {
            Theme.reload();
            baselineJson = JSON.stringify(candidate);
            candidateRevision += 1;
            statusMessage = "Theme applied. Some applications may require restart.";
            refreshThemes(true);
        } else if (action === "duplicate") {
            statusMessage = "Theme duplicated.";
            pendingSelection = response.data.id;
            runApi("list-after-duplicate", ["list"]);
        } else if (action === "list-after-duplicate") {
            themes = response.data || [];
            const id = pendingSelection;
            pendingSelection = "";
            requestSelection(id, false);
        } else if (action === "rename") {
            candidate.name = response.data.name;
            sourceDigest = response.data.source_sha256;
            baselineJson = JSON.stringify(candidate);
            candidateRevision += 1;
            statusMessage = "Display name changed; stable ID preserved.";
            refreshThemes(true);
        } else if (action === "delete") {
            Theme.cancelPreview();
            candidate = null;
            selectedId = "";
            sourceDigest = "";
            baselineJson = "";
            statusMessage = "Theme deleted.";
            refreshThemes(false);
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
            root.busy = false;
            let response = null;
            try {
                response = JSON.parse(root.processOutput.trim());
            } catch (error) {
                root.errorMessage = "Theme API returned invalid JSON: " + String(error) + (root.processError ? "\n" + root.processError.trim() : "");
                return ;
            }
            root.handleResponse(response);
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
        onAccepted: wallpaperField.text = decodeURIComponent(String(selectedFile).replace(/^file:\/\//, ""))
    }

    IpcHandler {
        function open() : string {
            return root.openPicker();
        }

        function close() : string {
            root.requestClose();
            return root.open ? "confirmation-required" : "closed";
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
            root.generateAfterLoad = true;
            root.openPicker();
            if (root.candidate !== null && root.candidate.id === Theme.themeId) {
                root.generateAfterLoad = false;
                root.generateTheme(root.candidate.wallpaper.path);
            }
            return "open-generating";
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
        enabled: root.open
        sequence: "Escape"
        onActivated: {
            if (root.colourPickerOpen)
                root.colourPickerOpen = false;
            else
                root.requestClose();
        }
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
        anchors.fill: parent
        color: "transparent"

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
                enabled: root.modalKind.length === 0 && !root.colourPickerOpen

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
                                enabled: root.candidate && !root.dirty && root.sourceDigest && !root.busy
                                onClicked: root.openDuplicate()
                            }

                            ListView {
                                id: themeList

                                Layout.fillWidth: true
                                Layout.fillHeight: true
                                clip: true
                                spacing: 4
                                model: root.filteredThemes()

                                delegate: Rectangle {
                                    id: themeDelegate

                                    required property var modelData

                                    width: themeList.width
                                    height: 62
                                    radius: 6
                                    color: modelData.id === root.selectedId ? Theme.surfaceAlt : mouse.containsMouse ? Theme.withAlpha(Theme.surfaceAlt, 0.62) : "transparent"
                                    border.color: modelData.unsaved ? Theme.yellow : modelData.id === Theme.themeId ? Theme.blue : "transparent"
                                    border.width: modelData.unsaved || modelData.id === Theme.themeId ? 1 : 0

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
                                            onClicked: {
                                                if (modelData.id !== root.selectedId)
                                                    root.requestSelection(modelData.id, true);

                                                themeActions.open();
                                            }
                                        }

                                    }

                                    MouseArea {
                                        id: mouse

                                        anchors.fill: parent
                                        anchors.rightMargin: 38
                                        hoverEnabled: true
                                        acceptedButtons: Qt.LeftButton | Qt.RightButton
                                        onClicked: (event) => {
                                            if (modelData.id !== root.selectedId)
                                                root.requestSelection(modelData.id, true);

                                            if (event.button === Qt.RightButton)
                                                themeActions.open();

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
                                                enabled: modelData.id === root.selectedId && root.candidate && !root.dirty && root.sourceDigest && !root.busy
                                                onClicked: {
                                                    themeActions.close();
                                                    root.openDuplicate();
                                                }
                                            }

                                            BloxButton {
                                                width: parent.width
                                                text: "Rename"
                                                enabled: modelData.id === root.selectedId && root.candidate && !root.dirty && root.sourceDigest && !root.busy
                                                onClicked: {
                                                    themeActions.close();
                                                    root.openRename();
                                                }
                                            }

                                            BloxButton {
                                                width: parent.width
                                                text: "Delete"
                                                destructive: true
                                                enabled: modelData.id === root.selectedId && root.candidate && !root.dirty && root.candidate.id !== "blox-panel" && !root.busy
                                                onClicked: {
                                                    themeActions.close();
                                                    root.requestDelete();
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
                                        text: "Create from wallpaper"
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
                                                if (root.candidate) {
                                                    const next = root.cloneCandidate();
                                                    next.wallpaper.path = text.trim();
                                                    root.markCandidate(next);
                                                }
                                            }
                                        }

                                        BloxButton {
                                            text: "Browse"
                                            onClicked: wallpaperDialog.open()
                                        }

                                        BloxComboBox {
                                            model: ["matugen", "pywal"]
                                            currentIndex: root.generatorBackend === "matugen" ? 0 : 1
                                            onActivated: root.generatorBackend = currentText
                                        }

                                        BloxButton {
                                            text: "Generate"
                                            enabled: !root.busy
                                            onClicked: root.generateTheme(wallpaperField.text)
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
                                                required property string modelData

                                                width: 112
                                                height: 72
                                                radius: 6
                                                color: root.candidate && root.candidate.colours ? root.candidate.colours[modelData] : "transparent"
                                                border.color: Theme.withAlpha(Theme.foreground, 0.45)

                                                HoverHandler {
                                                    cursorShape: Qt.PointingHandCursor
                                                }

                                                TapHandler {
                                                    onTapped: root.openColourPicker(modelData, "")
                                                }

                                                Text {
                                                    anchors.left: parent.left
                                                    anchors.right: parent.right
                                                    anchors.bottom: parent.bottom
                                                    anchors.margins: 6
                                                    text: modelData.replace(/_/g, " ")
                                                    color: root.swatchText(parent.color)
                                                    font.family: Theme.fontFamily
                                                    font.pixelSize: 9
                                                    elide: Text.ElideRight
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

                                                width: 112
                                                height: 30
                                                radius: 15
                                                color: root.candidate && root.candidate.targets[modelData] ? Theme.withAlpha(Theme.blue, 0.25) : Theme.background
                                                border.color: root.candidate && root.candidate.targets[modelData] ? Theme.blue : Theme.border

                                                Text {
                                                    anchors.centerIn: parent
                                                    text: modelData
                                                    color: Theme.foreground
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
                                        text: "Enabled targets"
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

                                                text: modelData
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

            Rectangle {
                anchors.fill: parent
                visible: root.modalKind.length > 0
                color: Theme.withAlpha("#000000", 0.68)
                z: 50

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
                            text: root.modalKind === "delete" ? "Delete theme permanently?" : root.modalKind === "duplicate" ? "Duplicate theme" : root.modalKind === "rename" ? "Rename display name" : "Discard unsaved changes?"
                            color: Theme.foreground
                            font.family: Theme.bodyFontFamily
                            font.pixelSize: 19
                            font.bold: true
                        }

                        Text {
                            visible: root.modalKind === "navigate" || root.modalKind === "close" || root.modalKind === "delete"
                            Layout.fillWidth: true
                            text: root.modalKind === "delete" ? "This removes the editable source. The action cannot be undone." : "The temporary Quickshell preview will be restored to the active theme."
                            color: Theme.muted
                            wrapMode: Text.Wrap
                            font.family: Theme.bodyFontFamily
                        }

                        BloxTextField {
                            visible: root.modalKind === "duplicate"
                            Layout.fillWidth: true
                            placeholderText: "Display name"
                            text: root.duplicateName
                            onTextChanged: {
                                root.duplicateName = text;
                                root.duplicateId = root.duplicateIdForName(text);
                            }
                        }

                        BloxTextField {
                            visible: root.modalKind === "rename"
                            Layout.fillWidth: true
                            placeholderText: "Display name"
                            text: root.renameName
                            onTextChanged: root.renameName = text
                        }

                        RowLayout {
                            Layout.fillWidth: true

                            Text {
                                id: duplicateIdFooter

                                visible: root.modalKind === "duplicate"
                                Layout.fillWidth: true
                                text: root.duplicateId
                                color: Theme.muted
                                elide: Text.ElideMiddle
                                font.family: Theme.monoFontFamily
                                font.pixelSize: 10
                            }

                            Item {
                                visible: root.modalKind !== "duplicate"
                                Layout.fillWidth: true
                            }

                            BloxButton {
                                text: "Cancel"
                                onClicked: root.dismissModal()
                            }

                            BloxButton {
                                text: root.modalKind === "delete" ? "Delete" : root.modalKind === "duplicate" ? "Duplicate" : root.modalKind === "rename" ? "Rename" : "Discard"
                                destructive: root.modalKind === "delete" || root.modalKind === "close" || root.modalKind === "navigate"
                                enabled: root.modalKind !== "duplicate" || root.duplicateId.trim().length > 0 && root.duplicateName.trim().length > 0
                                onClicked: root.confirmModal()
                            }

                        }

                    }

                }

            }

            Rectangle {
                anchors.fill: parent
                visible: root.colourPickerOpen
                color: Theme.withAlpha("#000000", 0.68)
                z: 60

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
