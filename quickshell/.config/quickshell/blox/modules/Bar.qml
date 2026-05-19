import "../popouts"
import "../services"
import "../shared"
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import Quickshell.Services.SystemTray
import Quickshell.Wayland

Scope {
    id: root

    property string openPanel: ""
    property real openPanelY: 8
    property string scriptRoot: Quickshell.shellDir + "/scripts"
    property bool extrasOpen: false
    property bool batteryExpanded: false
    property bool clockDateMode: false
    property bool railHovered: false
    property string hoveredSource: ""
    property bool popoutHovered: false
    property bool extrasHovered: false
    property bool inputPopupLocked: false
    property bool blinkOn: true
    property string selectedCalendarDate: ""
    property string alertWorkspaceIds: ","
    property string alertWindowAddress: ""
    property var trayMenuHandle: null
    property string trayMenuTitle: ""
    property real trayMenuY: 8
    property bool trayMenuOpen: false

    function togglePanel(panel, centerY) {
        openHoverPanel(panel, centerY);
    }

    function closePanel() {
        openPanel = "";
        railHovered = false;
        hoveredSource = "";
        popoutHovered = false;
        extrasHovered = false;
        inputPopupLocked = false;
        hoverCloseDelay.stop();
    }

    function setInputPopupLocked(locked) {
        inputPopupLocked = locked;
        if (locked) {
            hoverCloseDelay.stop();
        } else if (hoveredSource.length === 0 && !popoutHovered) {
            scheduleHoverClose();
        }
    }

    function openHoverPanel(panel, centerY) {
        if (openPanel !== panel)
            inputPopupLocked = false;

        openPanelY = centerY === undefined ? 8 : centerY;
        openPanel = panel;
        hoverCloseDelay.stop();
    }

    function hoverButtonEntered(panel, centerY, source) {
        hoveredSource = source === undefined ? panel : source;
        railHovered = true;
        openHoverPanel(panel, centerY);
    }

    function hoverButtonExited(source) {
        if (hoveredSource !== (source === undefined ? "" : source))
            return ;

        hoveredSource = "";
        railHovered = false;
        scheduleHoverClose();
    }

    function scheduleHoverClose() {
        hoverCloseDelay.restart();
    }

    function extrasEntered() {
        extrasHovered = true;
        hoverCloseDelay.stop();
    }

    function trayItemEntered() {
        openPanel = "";
        railHovered = false;
        hoveredSource = "";
        popoutHovered = false;
        inputPopupLocked = false;
        extrasEntered();
    }

    function extrasExited() {
        extrasHovered = false;
        scheduleHoverClose();
    }

    function popoutEntered() {
        popoutHovered = true;
        hoverCloseDelay.stop();
    }

    function popoutExited() {
        popoutHovered = false;
        scheduleHoverClose();
    }

    function closeTrayMenu() {
        trayMenuOpen = false;
        trayMenuHandle = null;
        trayMenuTitle = "";
    }

    function toggleExtras() {
        closePanel();
        closeTrayMenu();
        extrasOpen = !extrasOpen;
        extrasHovered = extrasOpen;
    }

    function openExtras() {
        if (extrasOpen)
            return ;

        closePanel();
        closeTrayMenu();
        extrasOpen = true;
    }

    function closeDrawers() {
        closePanel();
        closeTrayMenu();
        extrasHovered = false;
        extrasOpen = false;
    }

    function openTrayMenu(item, centerY) {
        closePanel();
        extrasOpen = true;
        extrasHovered = true;
        trayMenuHandle = item.menu;
        trayMenuTitle = item.tooltipTitle || item.title || item.id || "Tray";
        trayMenuY = centerY;
        trayMenuOpen = !!(item.hasMenu || item.onlyMenu);
        if (!trayMenuOpen)
            item.activate();
    }

    function activeWorkspaceId() {
        const items = workspaceItems();
        for (let i = 0; i < items.length; i++) {
            if (items[i].active)
                return items[i].id;

        }
        return -1;
    }

    function focusedWorkspaceId() {
        return Hyprland.focusedWorkspace ? Hyprland.focusedWorkspace.id : activeWorkspaceId();
    }

    function workspaceAlert(id) {
        return alertWorkspaceIds.indexOf("," + id + ",") >= 0;
    }

    function addWorkspaceAlert(id, address) {
        if (id <= 0)
            return ;

        if (!workspaceAlert(id))
            alertWorkspaceIds += id + ",";

        if (address !== undefined && address.length > 0)
            alertWindowAddress = address;

        urgentSwitchDelay.restart();
    }

    function clearWorkspaceAlert(id) {
        alertWorkspaceIds = alertWorkspaceIds.replace("," + id + ",", ",");
    }

    function focusWindow(address) {
        if (address !== undefined && address.length > 0)
            Hyprland.dispatch("focuswindow address:" + address);
    }

    function lookupWindowWorkspace(address) {
        if (address === undefined || address.length === 0 || activationLookup.running)
            return ;

        activationLookup.command = ["python3", root.scriptRoot + "/quickshell/window-workspace.py", address];
        activationLookup.running = true;
    }

    function activateWorkspaceItem(item) {
        Hyprland.dispatch("workspace " + item.id);
        focusWindow(item.urgentAddress || alertWindowAddress);
        clearWorkspaceAlert(item.id);
        alertWindowAddress = "";
        workspaces.refresh();
    }

    function run(command) {
        if (command.length === 0)
            return ;

        action.running = false;
        action.command = ["sh", "-c", command];
        action.running = true;
    }

    function runArgs(args) {
        if (args.length === 0)
            return ;

        actionArgs.running = false;
        actionArgs.command = args;
        actionArgs.running = true;
    }

    function powerCommand(kind) {
        if (kind === "update-shutdown")
            return "kitty --class update-shutdown --title update-shutdown sh -c '" + root.scriptRoot + "/waybar/update/update-run.sh; " + root.scriptRoot + "/waybar/power/safe-power.sh shutdown'";

        return root.scriptRoot + "/waybar/power/safe-power.sh " + kind;
    }

    function updateSummary() {
        const text = updates.json.tooltip || "";
        const match = text.match(/([0-9]+)\s+repo updates,\s+([0-9]+)\s+AUR updates/);
        if (match)
            return (parseInt(match[1]) + parseInt(match[2])) + " updates";

        if (updates.json.class === "zero")
            return "0 updates";

        return text || "Check updates";
    }

    function updateBody() {
        const text = updates.json.tooltip || "";
        const match = text.match(/([0-9]+)\s+repo updates,\s+([0-9]+)\s+AUR updates/i);
        if (match) {
            const repo = parseInt(match[1]);
            const yay = parseInt(match[2]);
            return repo + " repo updates, " + yay + " yay updates\n" + (repo + yay) + " total updates";
        }

        if (updates.json.class === "zero")
            return "0 repo updates, 0 yay updates\n0 total updates";

        return text || "Update status unavailable";
    }

    function currentIsoDate() {
        return Qt.formatDate(clock.date, "yyyy-MM-dd");
    }

    function resetCalendarMonth() {
        selectedCalendarDate = currentIsoDate();
        calendarEvents.refresh();
    }

    function systemPanelTitle() {
        if (openPanel === "audio")
            return "Audio";

        if (openPanel === "network")
            return "Network";

        if (openPanel === "bluetooth")
            return "Bluetooth";

        if (openPanel === "mic")
            return "Microphone";

        if (openPanel === "brightness")
            return "Display";

        if (openPanel === "system")
            return "Performance";

        if (openPanel === "battery")
            return "Battery";

        return panelTitle();
    }

    function systemPanelBody() {
        if (openPanel === "audio")
            return (audio.json.tooltip || "Audio unavailable") + "\n\nVolume " + (audio.json.volume || 0) + "%";

        if (openPanel === "network")
            return network.json.tooltip || "Network unavailable";

        if (openPanel === "bluetooth")
            return bluetooth.json.tooltip || "Bluetooth unavailable";

        if (openPanel === "mic")
            return audio.json.micMuted ? "Microphone muted" : "Microphone open";

        if (openPanel === "brightness")
            return brightness.json.tooltip || "Brightness unavailable";

        if (openPanel === "system")
            return "Fan\n" + (systemInfo.json.profile || "Unknown") + "\n\nGPU\n" + (systemInfo.json.gpuLabel || "GPU unavailable");

        if (openPanel === "battery")
            return battery.json.tooltip || "Battery unavailable";

        return panelBody();
    }

    function systemPanelActions() {
        if (openPanel === "audio")
            return [{
            "label": audio.json.muted ? "Unmute" : "Mute",
            "command": "pactl set-sink-mute @DEFAULT_SINK@ toggle",
            "keepOpen": true
        }, {
            "label": "Volume down",
            "command": "pactl set-sink-volume @DEFAULT_SINK@ -5%",
            "keepOpen": true
        }, {
            "label": "Volume up",
            "command": "pactl set-sink-volume @DEFAULT_SINK@ +5%",
            "keepOpen": true
        }, {
            "label": "Open app",
            "command": "pavucontrol -t 3"
        }];

        if (openPanel === "network")
            return [{
            "label": network.json.class === "disabled" ? "Enable" : "Disable",
            "command": "nmcli radio wifi " + (network.json.class === "disabled" ? "on" : "off"),
            "keepOpen": true
        }, {
            "label": "Open app",
            "command": root.scriptRoot + "/waybar/network/nm-applet-toggle.sh"
        }];

        if (openPanel === "bluetooth")
            return [{
            "label": bluetooth.json.class === "disabled" ? "Enable" : "Toggle",
            "command": "rfkill toggle bluetooth",
            "keepOpen": true
        }, {
            "label": "Open app",
            "command": "blueman-manager"
        }];

        if (openPanel === "mic")
            return [{
            "label": audio.json.micMuted ? "Unmute" : "Mute",
            "command": "pactl set-source-mute @DEFAULT_SOURCE@ toggle",
            "keepOpen": true
        }, {
            "label": "Open app",
            "command": "pavucontrol -t 4"
        }];

        if (openPanel === "brightness")
            return [{
            "label": "Brightness up",
            "command": "brightnessctl -d amdgpu_bl1 set +5%"
        }, {
            "label": "Brightness down",
            "command": "brightnessctl -d amdgpu_bl1 set 5%-"
        }, {
            "label": "Toggle sunset",
            "command": root.scriptRoot + "/waybar/hyprsunset-toggle.sh"
        }];

        if (openPanel === "system")
            return [];

        return panelActions();
    }

    function workspaceItems() {
        return workspaces.json.main || [];
    }

    function updateIcon() {
        const cls = updates.json.class || updates.json.alt || "zero";
        if (cls === "error")
            return "";

        if (cls === "zero")
            return "󰅠";

        if (cls === "lessfifty")
            return "󰅢";

        return "󰧠";
    }

    function shortDayName(date) {
        const days = ["Su", "Mo", "Tu", "We", "Th", "Fr", "Sa"];
        return days[date.getDay()];
    }

    function twoDigit(value) {
        return value < 10 ? "0" + value : String(value);
    }

    function railClockText() {
        const date = clock.date;
        if (clockDateMode)
            return shortDayName(date) + "\n" + twoDigit(date.getDate()) + "\n" + twoDigit(date.getMonth() + 1) + "\n" + twoDigit(date.getFullYear() % 100);

        const hour = date.getHours() % 12 || 12;
        return twoDigit(hour) + "\n" + twoDigit(date.getMinutes()) + "\n" + twoDigit(date.getSeconds());
    }

    function panelTitle() {
        const titles = {
            "audio": "Audio",
            "battery": "Battery",
            "bluetooth": "Bluetooth",
            "brightness": "Brightness",
            "calendar": "Calendar",
            "extras": "Extras",
            "fan": "Fan",
            "gpu": "GPU",
            "network": "Network",
            "notifications": "Notifications",
            "power": "Power",
            "privacy": "Privacy",
            "todo": "Todo",
            "updates": "Updates"
        };
        return titles[openPanel] || "";
    }

    function elapsedText(ms, nowMs) {
        if (!ms || ms <= 0)
            return "Not fetched yet";

        const elapsed = Math.max(0, Math.floor((nowMs - ms) / 1000));
        if (elapsed < 5)
            return "Fetched just now";
        if (elapsed < 60)
            return "Fetched " + elapsed + "s ago";

        const minutes = Math.floor(elapsed / 60);
        if (minutes < 60)
            return "Fetched " + minutes + "m ago";

        const hours = Math.floor(minutes / 60);
        if (hours < 24)
            return "Fetched " + hours + "h ago";

        return "Fetched " + Math.floor(hours / 24) + "d ago";
    }

    function panelSubtitle() {
        if (openPanel === "updates")
            return elapsedText(updates.lastUpdatedMs, clock.date.getTime());

        return "";
    }

    function panelHeaderActionIcon() {
        if (openPanel === "updates")
            return "󰑐";

        return "";
    }

    function panelHeaderActionCommand() {
        if (openPanel === "updates")
            return "__refresh_updates";

        return "";
    }

    function panelBody() {
        if (openPanel === "power")
            return "Session actions use the copied safe-power backend, including the micro guard.";

        if (openPanel === "todo")
            return todo.json.tooltip || "Todo status unavailable";

        if (openPanel === "calendar")
            return Qt.formatDateTime(clock.date, "dddd, dd MMMM yyyy");

        if (openPanel === "extras")
            return "Tray/menu placeholder\n" + (updates.json.tooltip || "Update status unavailable") + "\n" + (bluetooth.json.tooltip || "Bluetooth unavailable") + "\n" + (audio.json.micMuted ? "Mic muted" : "Mic open") + "\n" + (brightness.json.tooltip || "Brightness unavailable") + "\n" + (privacy.json.tooltip || "Privacy unavailable");

        if (openPanel === "updates")
            return updateBody();

        if (openPanel === "bluetooth")
            return bluetooth.json.tooltip || "Bluetooth status unavailable";

        if (openPanel === "brightness")
            return brightness.json.tooltip || "Brightness status unavailable";

        if (openPanel === "privacy")
            return privacy.json.tooltip || "Privacy status unavailable";

        if (openPanel === "audio")
            return audio.json.tooltip || "Audio status unavailable";

        if (openPanel === "network")
            return (network.json.tooltip || "Network unavailable") + "\n\n" + (bluetooth.json.tooltip || "Bluetooth unavailable");

        if (openPanel === "notifications")
            return notifications.json.tooltip || "Notification status unavailable";

        if (openPanel === "fan")
            return fan.json.tooltip || "Fan status unavailable";

        if (openPanel === "gpu")
            return gpu.json.tooltip || "GPU status unavailable";

        if (openPanel === "battery")
            return battery.json.tooltip || "Battery status unavailable";

        return "";
    }

    function panelActions(panel) {
        const current = panel || openPanel;
        if (current === "power")
            return [{
            "label": "Lock",
            "command": root.scriptRoot + "/waybar/power/safe-power.sh lock"
        }, {
            "label": "Sleep",
            "command": root.scriptRoot + "/waybar/power/safe-power.sh sleep"
        }, {
            "label": "Hibernate",
            "command": root.scriptRoot + "/waybar/power/safe-power.sh hibernate"
        }, {
            "label": "Reboot",
            "command": root.scriptRoot + "/waybar/power/safe-power.sh reboot",
            "danger": true
        }, {
            "label": "Shut down",
            "command": root.scriptRoot + "/waybar/power/safe-power.sh shutdown",
            "danger": true
        }];

        if (current === "todo")
            return [{
            "label": "Cycle file",
            "command": root.scriptRoot + "/waybar/todo/cycle.sh"
        }, {
            "label": "Open editor",
            "command": root.scriptRoot + "/waybar/todo/open.sh"
        }];

        if (current === "calendar")
            return [{
            "label": "Add calendar item",
            "command": root.scriptRoot + "/waybar/cal/add.sh"
        }, {
            "label": "Cycle calendar mode",
            "command": root.scriptRoot + "/waybar/cal/cycle.sh"
        }];

        if (current === "extras")
            return [{
            "label": "Run updates",
            "command": "kitty --class update --title update sh -c '" + root.scriptRoot + "/waybar/update/update-run.sh; echo Done - press enter; read'"
        }, {
            "label": "List updates",
            "command": "kitty --class update-list --title update-list sh -c '" + root.scriptRoot + "/waybar/update/update-list.sh'"
        }, {
            "label": bluetooth.json.class === "disabled" ? "Enable Bluetooth" : "Toggle Bluetooth",
            "command": "rfkill toggle bluetooth"
        }, {
            "label": "Bluetooth manager",
            "command": "blueman-manager"
        }, {
            "label": audio.json.micMuted ? "Unmute microphone" : "Mute microphone",
            "command": "pactl set-source-mute @DEFAULT_SOURCE@ toggle"
        }, {
            "label": "Microphone settings",
            "command": "pavucontrol -t 4"
        }, {
            "label": "Brightness up",
            "command": "brightnessctl -d amdgpu_bl1 set +5%"
        }, {
            "label": "Brightness down",
            "command": "brightnessctl -d amdgpu_bl1 set 5%-"
        }, {
            "label": "Toggle sunset",
            "command": root.scriptRoot + "/waybar/hyprsunset-toggle.sh"
        }];

        if (current === "updates")
            return [{
            "icon": "󰇚",
            "label": "Run updates",
            "command": "kitty --class update --title update sh -c '" + root.scriptRoot + "/waybar/update/update-run.sh; echo Done - press enter; read'"
        }, {
            "icon": "",
            "label": "List updates",
            "command": "kitty --class update-list --title update-list sh -c '" + root.scriptRoot + "/waybar/update/update-list.sh'"
        }];

        if (current === "bluetooth")
            return [{
            "label": bluetooth.json.class === "disabled" ? "Enable Bluetooth" : "Toggle Bluetooth",
            "command": "rfkill toggle bluetooth"
        }, {
            "label": "Bluetooth manager",
            "command": "blueman-manager"
        }];

        if (current === "brightness")
            return [{
            "label": "Brightness up",
            "command": "brightnessctl -d amdgpu_bl1 set +5%"
        }, {
            "label": "Brightness down",
            "command": "brightnessctl -d amdgpu_bl1 set 5%-"
        }, {
            "label": "Toggle sunset",
            "command": root.scriptRoot + "/waybar/hyprsunset-toggle.sh"
        }];

        if (current === "audio")
            return [{
            "label": audio.json.muted ? "Unmute output" : "Mute output",
            "command": "pactl set-sink-mute @DEFAULT_SINK@ toggle"
        }, {
            "label": "Volume up",
            "command": "pactl set-sink-volume @DEFAULT_SINK@ +5%"
        }, {
            "label": "Volume down",
            "command": "pactl set-sink-volume @DEFAULT_SINK@ -5%"
        }, {
            "label": "Audio settings",
            "command": "pavucontrol -t 3"
        }];

        if (current === "network")
            return [{
            "label": network.json.class === "disabled" ? "Enable Wi-Fi" : "Toggle Wi-Fi",
            "command": "nmcli radio wifi " + (network.json.class === "disabled" ? "on" : "off")
        }, {
            "label": "Network applet",
            "command": root.scriptRoot + "/waybar/network/nm-applet-toggle.sh"
        }, {
            "label": bluetooth.json.class === "disabled" ? "Enable Bluetooth" : "Toggle Bluetooth",
            "command": "rfkill toggle bluetooth"
        }, {
            "label": "Bluetooth manager",
            "command": "blueman-manager"
        }];

        if (current === "notifications")
            return [{
            "label": "Open notification center",
            "command": "swaync-client -op -sw"
        }, {
            "label": notifications.json.dnd ? "Disable DND" : "Enable DND",
            "command": "swaync-client -d -sw"
        }, {
            "label": "Clear notifications",
            "command": "swaync-client -C -sw"
        }];

        if (current === "fan")
            return [{
            "label": "Performance",
            "command": "asusctl profile set performance; notify-send -u low '󱑬 Performance Mode Activated'"
        }, {
            "label": "Balanced",
            "command": "asusctl profile set balanced; notify-send -u low '󱜝 Balanced Mode Activated'"
        }, {
            "label": "Quiet",
            "command": "asusctl profile set quiet; notify-send -u low '󰠝 Quiet Mode Activated'"
        }];

        if (current === "gpu")
            return [{
            "label": "Gaming: GPU + 144Hz",
            "command": root.scriptRoot + "/waybar/gpu/modes/gpu144.sh"
        }, {
            "label": "Performance: GPU + 60Hz",
            "command": root.scriptRoot + "/waybar/gpu/modes/gpu60.sh"
        }, {
            "label": "High refresh: iGPU + 144Hz",
            "command": root.scriptRoot + "/waybar/gpu/modes/igpu144.sh"
        }, {
            "label": "Eco: iGPU + 60Hz",
            "command": root.scriptRoot + "/waybar/gpu/modes/igpu60.sh"
        }];

        return [];
    }

    ScriptPoller {
        id: workspaces

        command: [root.scriptRoot + "/quickshell/workspaces-status.py"]
        interval: 60000
    }

    ScriptPoller {
        id: gpu

        command: [root.scriptRoot + "/waybar/gpu/gpu-status.sh"]
        interval: 5000
    }

    ScriptPoller {
        id: fan

        command: [root.scriptRoot + "/waybar/fan/fan-status.sh"]
        interval: 10000
    }

    ScriptPoller {
        id: systemInfo

        command: [root.scriptRoot + "/quickshell/system-status.sh"]
        interval: 5000
    }

    ScriptPoller {
        id: todo

        command: [root.scriptRoot + "/quickshell/todo-status.sh"]
        interval: 10000
    }

    ScriptPoller {
        id: calendarEvents

        command: [root.scriptRoot + "/quickshell/calendar-events.sh", root.selectedCalendarDate || root.currentIsoDate()]
        interval: 300000
    }

    ScriptPoller {
        id: updates

        command: [root.scriptRoot + "/waybar/update/update.sh"]
        interval: 3.6e+06
    }

    ScriptPoller {
        id: battery

        command: [root.scriptRoot + "/quickshell/battery-status.sh"]
        interval: 5000
    }

    ScriptPoller {
        id: audio

        command: [root.scriptRoot + "/quickshell/audio-status.sh"]
        interval: 2000
    }

    ScriptPoller {
        id: brightness

        command: [root.scriptRoot + "/quickshell/brightness-status.sh"]
        interval: 5000
    }

    ScriptPoller {
        id: network

        command: [root.scriptRoot + "/quickshell/network-status.sh"]
        interval: 5000
    }

    ScriptPoller {
        id: bluetooth

        command: [root.scriptRoot + "/quickshell/bluetooth-status.sh"]
        interval: 5000
    }

    ScriptPoller {
        id: notifications

        command: [root.scriptRoot + "/quickshell/notification-status.sh"]
        interval: 2000
    }

    ScriptPoller {
        id: privacy

        command: [root.scriptRoot + "/quickshell/privacy-status.sh"]
        interval: 5000
    }

    Process {
        id: action
    }

    Process {
        id: actionArgs
    }

    Process {
        id: saveNotes

        onExited: todoRefreshDelay.restart()
    }

    Process {
        id: addCalendarEvent

        onExited: calendarEvents.refresh()
    }

    Process {
        id: activationLookup

        stdout: StdioCollector {
            onStreamFinished: {
                let info = {};
                try {
                    info = this.text.trim().length > 0 ? JSON.parse(this.text.trim()) : {};
                } catch (error) {
                    info = {};
                }

                const workspaceId = parseInt(info.workspace);
                const address = info.address || "";
                if (!isNaN(workspaceId) && workspaceId !== root.focusedWorkspaceId())
                    root.addWorkspaceAlert(workspaceId, address);
            }
        }
    }

    Connections {
        function onRawEvent(event) {
            workspaces.refresh();
            if (event.name === "workspace" || event.name === "workspacev2") {
                const activeId = parseInt(event.data.split(",")[0]);
                if (!isNaN(activeId))
                    clearWorkspaceAlert(activeId);

            } else if (event.name === "openwindow") {
                const parts = event.data.split(",");
                const address = parts[0] || "";
                const workspaceId = parseInt(parts[1]);
                if (!isNaN(workspaceId))
                    addWorkspaceAlert(workspaceId, address);

            } else if (event.name === "urgent") {
                alertWindowAddress = event.data || "";
                lookupWindowWorkspace(alertWindowAddress);
                urgentSwitchDelay.restart();
            } else if (event.name === "activewindowv2") {
                lookupWindowWorkspace(event.data || "");
            }
        }

        target: Hyprland
    }

    Timer {
        interval: 550
        repeat: true
        running: true
        onTriggered: root.blinkOn = !root.blinkOn
    }

    Timer {
        id: urgentSwitchDelay

        interval: 120
        repeat: false
        onTriggered: {
            const items = root.workspaceItems();
            for (let i = 0; i < items.length; i++) {
                if ((items[i].urgent || root.workspaceAlert(items[i].id)) && !items[i].active) {
                    root.activateWorkspaceItem(items[i]);
                    break;
                } else if ((items[i].urgent || root.workspaceAlert(items[i].id)) && items[i].active) {
                    root.focusWindow(items[i].urgentAddress || root.alertWindowAddress);
                    root.clearWorkspaceAlert(items[i].id);
                    root.alertWindowAddress = "";
                    workspaces.refresh();
                    break;
                }
            }
        }
    }

    Timer {
        id: todoRefreshDelay

        interval: 120
        repeat: false
        onTriggered: todo.refresh()
    }

    Timer {
        id: systemRefreshDelay

        interval: 1000
        repeat: false
        onTriggered: {
            fan.refresh();
            gpu.refresh();
            systemInfo.refresh();
        }
    }

    Timer {
        id: hoverCloseDelay

        interval: 180
        repeat: false
        onTriggered: {
            if (root.hoveredSource.length === 0 && !root.popoutHovered && !root.extrasHovered && !root.inputPopupLocked) {
                root.closePanel();
                root.closeTrayMenu();
                root.extrasOpen = false;
            }

        }
    }

    Variants {
        model: Quickshell.screens

        PanelWindow {
            id: panel

            required property var modelData

            function extrasLeft() {
                Qt.callLater(function() {
                    if (!extrasViewport.hovered)
                        root.extrasExited();
                });
            }

            screen: modelData
            implicitWidth: Theme.railWidth
            exclusiveZone: Theme.railWidth
            focusable: false

            anchors {
                left: true
                top: true
                bottom: true
            }

            Rectangle {
                anchors.fill: parent
                color: Theme.background

                MouseArea {
                    anchors.fill: parent
                    onClicked: root.closeDrawers()
                }

                ColumnLayout {
                    id: railLayout

                    anchors.fill: parent
                    anchors.topMargin: 4
                    anchors.bottomMargin: 4
                    spacing: 0

                    RailTopActions {
                        openPanel: root.openPanel
                        scriptRoot: root.scriptRoot
                        onPanelClicked: (panel, centerY) => root.togglePanel(panel, centerY)
                        onPanelHovered: (panel, centerY, source) => root.hoverButtonEntered(panel, centerY, source)
                        onPanelExited: (source) => root.hoverButtonExited(source)
                        onRunCommand: (command) => root.run(command)
                    }

                    Repeater {
                        model: root.workspaceItems()

                        WorkspaceRailButton {
                            item: modelData
                            blinking: (modelData.urgent || root.workspaceAlert(modelData.id)) && root.blinkOn
                            onActivate: {
                                root.closeDrawers();
                                Hyprland.dispatch("workspace " + modelData.id);
                                workspaces.refresh();
                            }
                        }

                    }

                    SpecialWorkspaceRailButton {
                        workspace: workspaces.json.special
                        onActivate: {
                            root.closeDrawers();
                            Hyprland.dispatch("togglespecialworkspace magic");
                            workspaces.refresh();
                        }
                    }

                    Item {
                        Layout.fillHeight: true
                    }

                    RailClock {
                        id: clockText

                        text: root.railClockText()
                        dateMode: root.clockDateMode
                        onHovered: (centerY) => root.hoverButtonEntered("calendar", centerY, "calendar")
                        onExited: root.hoverButtonExited("calendar")
                        onClicked: root.clockDateMode = !root.clockDateMode
                    }

                    Item {
                        Layout.fillHeight: true
                    }

                    Item {
                        id: extrasPushSpacer

                        Layout.preferredHeight: root.extrasOpen ? extrasViewport.push : 0
                        Layout.minimumHeight: Layout.preferredHeight
                        Layout.maximumHeight: Layout.preferredHeight

                        Behavior on Layout.preferredHeight {
                            NumberAnimation {
                                duration: 140
                                easing.type: Easing.OutCubic
                            }

                        }

                    }

                    ExtrasToggleButton {
                        id: extrasToggle

                        active: root.extrasOpen
                        onToggle: root.toggleExtras()
                        onOpenRequested: {
                            root.openExtras();
                            root.extrasEntered();
                        }
                        onExited: panel.extrasLeft()
                    }

                    SystemRailSection {
                        audioStatus: audio.json
                        networkStatus: network.json
                        notificationsStatus: notifications.json
                        fanStatus: fan.json
                        gpuStatus: gpu.json
                        batteryStatus: battery.json
                        openPanel: root.openPanel
                        panelHeight: panel.height
                        batteryExpanded: root.batteryExpanded
                        onPanelClicked: (panel, centerY) => root.togglePanel(panel, centerY)
                        onPanelHovered: (panel, centerY, source) => root.hoverButtonEntered(panel, centerY, source)
                        onPanelExited: (source) => root.hoverButtonExited(source)
                        onRunCommand: (command) => root.run(command)
                        onCloseDrawers: root.closeDrawers()
                        onToggleBatteryExpanded: root.batteryExpanded = !root.batteryExpanded
                        onCollapseBattery: root.batteryExpanded = false
                    }

                }

                ExtrasDrawer {
                    id: extrasViewport

                    open: root.extrasOpen
                    topLimit: railLayout.y + clockText.y + clockText.height + 4
                    bottomLimit: railLayout.y + extrasToggle.y
                    hoverMargin: Theme.buttonSize + 4
                    onHoverEntered: root.extrasEntered()
                    onHoverExited: panel.extrasLeft()

                        Column {
                            id: systemTrayItems

                            width: Theme.buttonSize

                            Repeater {
                                model: SystemTray.items

                                TrayRailItem {
                                    item: modelData
                                    onHovered: root.trayItemEntered()
                                    onExited: panel.extrasLeft()
                                    onOpenMenu: (item, centerY) => root.openTrayMenu(item, Math.round(extrasViewport.popupCenterY(systemTrayItems.y + centerY)))
                                }

                            }

                        }

                        ExtrasActionSection {
                            openPanel: root.openPanel
                            centerOffset: extrasViewport.popupCenterY(0)
                            updateIcon: root.updateIcon()
                            updatesStatus: updates.json
                            bluetoothStatus: bluetooth.json
                            audioStatus: audio.json
                            brightnessStatus: brightness.json
                            privacyStatus: privacy.json
                            scriptRoot: root.scriptRoot
                            onPanelClicked: (panel, centerY) => root.togglePanel(panel, centerY)
                            onPanelHovered: (panel, centerY, source) => root.hoverButtonEntered(panel, centerY, source)
                            onPanelExited: (source) => root.hoverButtonExited(source)
                            onRunCommand: (command) => root.run(command)
                        }

                }

            }

            PowerOverlayWindow {
                targetScreen: modelData
                open: root.openPanel === "power"
                updateSummary: root.updateSummary()
                onAction: (kind) => root.run(root.powerCommand(kind))
                onClose: root.closePanel()
            }

            BarPopouts {
                panelWindow: panel
                panelHeight: panel.height
                screenWidth: panel.screen ? panel.screen.width : 0
                openPanel: root.openPanel
                openPanelY: root.openPanelY
                trayMenuY: root.trayMenuY
                trayMenuOpen: root.trayMenuOpen
                trayMenuHandle: root.trayMenuHandle
                trayMenuTitle: root.trayMenuTitle
                todoStatus: todo.json
                clockDate: clock.date
                selectedCalendarDate: root.selectedCalendarDate
                calendarStatus: calendarEvents.json || ({})
                systemStatus: systemInfo.json || ({})
                scriptRoot: root.scriptRoot
                systemTitle: root.systemPanelTitle()
                systemBody: root.systemPanelBody()
                systemActions: root.systemPanelActions()
                audioVolume: audio.json.volume || 0
                audioMuted: !!audio.json.muted
                micMuted: !!audio.json.micMuted
                wifiIcon: network.json.icon || "󰤩"
                wifiText: network.json.ssid || network.json.class || "Wi-Fi"
                bluetoothIcon: bluetooth.json.icon || "󰂯"
                brightnessPercent: brightness.json.percent || 0
                basicTitle: root.panelTitle()
                basicSubtitle: root.panelSubtitle()
                basicBody: root.panelBody()
                basicActions: root.panelActions()
                basicHeaderActionIcon: root.panelHeaderActionIcon()
                basicHeaderActionCommand: root.panelHeaderActionCommand()
                onHoverEntered: root.popoutEntered()
                onHoverExited: root.popoutExited()
                onInputLockChanged: (locked) => root.setInputPopupLocked(locked)
                onClosePanel: root.closePanel()
                onCloseTrayMenu: root.closeTrayMenu()
                onPreviousTodo: {
                    root.run(root.scriptRoot + "/quickshell/todo-cycle.sh -1");
                    todoRefreshDelay.restart();
                }
                onNextTodo: {
                    root.run(root.scriptRoot + "/quickshell/todo-cycle.sh 1");
                    todoRefreshDelay.restart();
                }
                onSaveTodo: (file, body) => {
                    saveNotes.running = false;
                    saveNotes.command = ["python3", "-c", "from pathlib import Path; import sys; Path(sys.argv[1]).write_text(sys.argv[2])", file, body];
                    saveNotes.running = true;
                }
                onResetCalendarMonth: root.resetCalendarMonth()
                onSelectCalendarDate: (day) => {
                    root.selectedCalendarDate = day;
                    calendarEvents.refresh();
                }
                onAddCalendarEvent: (day, title) => {
                    addCalendarEvent.running = false;
                    addCalendarEvent.command = [root.scriptRoot + "/quickshell/calendar-add.sh", day, title];
                    addCalendarEvent.running = true;
                }
                onOpenCalendarEvent: {
                    const date = root.selectedCalendarDate ? new Date(root.selectedCalendarDate + "T00:00:00") : clock.date;
                    root.run("xdg-open 'https://calendar.google.com/calendar/u/0/r/week/" + date.getFullYear() + "/" + (date.getMonth() + 1) + "/" + date.getDate() + "'");
                }
                onPerformanceAction: (command) => {
                    root.run(command);
                    systemRefreshDelay.restart();
                }
                onSystemAction: (command, keepOpen) => {
                    root.run(command);
                    if (!keepOpen)
                        root.closePanel();
                }
                onBasicAction: (command, keepOpen) => {
                    if (command === "__refresh_updates") {
                        updates.refresh();
                        return ;
                    }

                    root.run(command);
                    if (!keepOpen)
                        root.closePanel();
                }
            }

        }

    }

    SystemClock {
        id: clock

        precision: SystemClock.Seconds
    }

}
