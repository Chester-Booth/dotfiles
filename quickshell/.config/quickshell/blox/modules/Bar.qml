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
    property bool blinkOn: true
    property string selectedCalendarDate: ""
    property string alertWorkspaceIds: ","
    property string alertWindowAddress: ""
    property var trayMenuHandle: null
    property string trayMenuTitle: ""
    property real trayMenuY: 8
    property bool trayMenuOpen: false
    property real extrasPush: 0

    function togglePanel(panel, centerY) {
        openHoverPanel(panel, centerY);
    }

    function closePanel() {
        openPanel = "";
        railHovered = false;
        hoveredSource = "";
        popoutHovered = false;
        hoverCloseDelay.stop();
    }

    function openHoverPanel(panel, centerY) {
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
    }

    function closeDrawers() {
        closePanel();
        closeTrayMenu();
        extrasOpen = false;
    }

    function openTrayMenu(item, centerY) {
        closePanel();
        extrasOpen = true;
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

    function activateWorkspaceItem(item) {
        Hyprland.dispatch("workspace " + item.id);
        focusWindow(item.urgentAddress || alertWindowAddress);
        clearWorkspaceAlert(item.id);
        alertWindowAddress = "";
        workspaces.refresh();
    }

    function extrasViewportHeight(panelHeight) {
        const fixedHeight = 8 + Theme.buttonSize * 2 + Theme.buttonSize * 5 + 96 + Theme.buttonSize * 7 + (batteryExpanded ? Theme.buttonSize : 0);
        return Math.max(Theme.buttonSize, panelHeight - fixedHeight);
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
            return updates.json.tooltip || "Update status unavailable";

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
            "label": "Run updates",
            "command": "kitty --class update --title update sh -c '" + root.scriptRoot + "/waybar/update/update-run.sh; echo Done - press enter; read'"
        }, {
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
                urgentSwitchDelay.restart();
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
            if (root.hoveredSource.length === 0 && !root.popoutHovered) {
                root.closePanel();
                root.closeTrayMenu();
            }

        }
    }

    Variants {
        model: Quickshell.screens

        PanelWindow {
            id: panel

            required property var modelData

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

                    RailButton {
                        icon: "⏻"
                        accent: Theme.foreground
                        active: root.openPanel === "power"
                        onClicked: (centerY) => {
                            return root.togglePanel("power", centerY);
                        }
                    }

                    RailButton {
                        icon: "󰺦"
                        accent: Theme.foreground
                        active: root.openPanel === "todo"
                        onClicked: (centerY) => {
                            return root.togglePanel("todo", centerY);
                        }
                        onHovered: (centerY) => root.hoverButtonEntered("todo", centerY, "todo")
                        onExited: root.hoverButtonExited("todo")
                        onRightClicked: root.run(root.scriptRoot + "/waybar/todo/open.sh")
                    }

                    Repeater {
                        model: root.workspaceItems()

                        RailButton {
                            icon: modelData.icon
                            accent: modelData.urgent ? Theme.red : modelData.active ? Theme.blue : modelData.empty ? Theme.muted : Theme.foreground
                            active: modelData.active
                            alert: (modelData.urgent || root.workspaceAlert(modelData.id)) && root.blinkOn
                            onClicked: () => {
                                root.closeDrawers();
                                Hyprland.dispatch("workspace " + modelData.id);
                                workspaces.refresh();
                            }
                        }

                    }

                    RailButton {
                        icon: (workspaces.json.special && workspaces.json.special.icon) || "󰘼"
                        accent: workspaces.json.special && workspaces.json.special.active ? Theme.blue : Theme.muted
                        active: !!(workspaces.json.special && workspaces.json.special.active)
                        visible: !!(workspaces.json.special && workspaces.json.special.occupied)
                        onClicked: () => {
                            root.closeDrawers();
                            Hyprland.dispatch("togglespecialworkspace magic");
                            workspaces.refresh();
                        }
                    }

                    Item {
                        Layout.fillHeight: true
                    }

                    Text {
                        id: clockText

                        Layout.alignment: Qt.AlignHCenter
                        text: root.railClockText()
                        color: root.clockDateMode ? Theme.foreground : Theme.blue
                        font.family: Theme.fontFamily
                        font.pixelSize: 16
                        horizontalAlignment: Text.AlignHCenter

                        MouseArea {
                            anchors.fill: parent
                            acceptedButtons: Qt.LeftButton | Qt.RightButton
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onEntered: root.hoverButtonEntered("calendar", clockText.y + clockText.height / 2, "calendar")
                            onExited: root.hoverButtonExited("calendar")
                            onClicked: (event) => {
                                if (event.button === Qt.RightButton)
                                    root.clockDateMode = !root.clockDateMode;
                                else
                                    root.togglePanel("calendar", clockText.y + clockText.height / 2);
                            }
                        }

                    }

                    Item {
                        Layout.fillHeight: true
                    }

                    Item {
                        id: extrasPushSpacer

                        Layout.preferredHeight: root.extrasOpen ? root.extrasPush : 0
                        Layout.minimumHeight: Layout.preferredHeight
                        Layout.maximumHeight: Layout.preferredHeight

                        Behavior on Layout.preferredHeight {
                            NumberAnimation {
                                duration: 140
                                easing.type: Easing.OutCubic
                            }

                        }

                    }

                    RailButton {
                        id: extrasToggle

                        icon: "󰅃"
                        accent: Theme.foreground
                        active: root.extrasOpen
                        onClicked: () => {
                            return root.toggleExtras();
                        }
                    }

                    RailButton {
                        icon: audio.json.icon || "󰕾"
                        accent: audio.json.muted ? Theme.yellow : Theme.foreground
                        active: root.openPanel === "audio"
                        onClicked: (centerY) => {
                            return root.togglePanel("audio", centerY);
                        }
                        onHovered: (centerY) => root.hoverButtonEntered("audio", centerY, "audio")
                        onExited: root.hoverButtonExited("audio")
                        onRightClicked: root.run("pavucontrol -t 3")
                    }

                    RailButton {
                        icon: network.json.icon || "󰤩"
                        accent: network.json.class === "wifi" ? Theme.green : network.json.class === "disabled" ? Theme.red : Theme.yellow
                        active: root.openPanel === "network"
                        onClicked: (centerY) => {
                            return root.togglePanel("network", centerY);
                        }
                        onHovered: (centerY) => root.hoverButtonEntered("network", centerY, "network")
                        onExited: root.hoverButtonExited("network")
                    }

                    RailButton {
                        icon: notifications.json.icon || "󰂜"
                        accent: notifications.json.dnd ? Theme.yellow : notifications.json.count > 0 ? Theme.blue : Theme.foreground
                        active: false
                        onClicked: () => {
                            root.closeDrawers();
                            return root.run("swaync-client -op -sw");
                        }
                        onRightClicked: root.run("swaync-client -d -sw")
                    }

                    RailButton {
                        icon: fan.json.class === "Performance" ? "󱑬" : fan.json.class === "Quiet" ? "󰠝" : "󱜝"
                        accent: fan.json.class === "Performance" ? Theme.red : Theme.foreground
                        active: root.openPanel === "system"
                        visible: fan.json.class !== undefined && fan.json.class !== "Quiet"
                        onClicked: (centerY) => {
                            return root.togglePanel("system", centerY);
                        }
                        onHovered: (centerY) => root.hoverButtonEntered("system", centerY, "fan")
                        onExited: root.hoverButtonExited("fan")
                    }

                    RailButton {
                        icon: gpu.json.alt === "eco" ? "󰌪" : gpu.json.alt === "gaming" ? "󰪫" : gpu.json.alt === "high-refresh" ? "" : "󰢮"
                        accent: gpu.json.alt === "eco" ? Theme.green : Theme.yellow
                        active: root.openPanel === "system"
                        visible: gpu.json.alt !== undefined && gpu.json.alt !== "eco"
                        onClicked: (centerY) => {
                            return root.togglePanel("system", centerY);
                        }
                        onHovered: (centerY) => root.hoverButtonEntered("system", centerY, "gpu")
                        onExited: root.hoverButtonExited("gpu")
                    }

                    RailButton {
                        icon: battery.json.icon || "󰁹"
                        accent: battery.json.class === "critical" ? Theme.red : battery.json.class === "charging" ? Theme.green : Theme.muted
                        active: false
                        onClicked: () => {
                            root.closeDrawers();
                            root.batteryExpanded = !root.batteryExpanded;
                        }
                        onHovered: () => root.hoverButtonEntered("battery", panel.height - 24, "battery")
                        onExited: root.hoverButtonExited("battery")
                        onRightClicked: root.togglePanel("system", panel.height - 24)
                    }

                    Rectangle {
                        Layout.alignment: Qt.AlignHCenter
                        width: Theme.buttonSize
                        height: root.batteryExpanded ? Theme.buttonSize : 0
                        radius: Theme.radius
                        color: "transparent"
                        visible: root.batteryExpanded
                        clip: true

                        Text {
                            anchors.centerIn: parent
                            text: battery.json.capacity === undefined ? "" : String(battery.json.capacity)
                            color: battery.json.class === "critical" ? Theme.red : battery.json.class === "charging" ? Theme.green : Theme.foreground
                            font.family: Theme.fontFamily
                            font.pixelSize: 13
                            font.bold: true
                        }

                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.batteryExpanded = false
                        }

                    }

                }

                Item {
                    id: extrasViewport

                    readonly property real topLimit: railLayout.y + clockText.y + clockText.height + 4
                    readonly property real bottomLimit: railLayout.y + extrasToggle.y
                    readonly property real targetHeight: root.extrasOpen ? Math.min(extrasColumn.implicitHeight, Math.max(Theme.buttonSize, bottomLimit - topLimit)) : 0
                    readonly property real contentY: height - extrasColumn.implicitHeight - extrasScroll.offset

                    function updateExtrasPush() {
                        if (!root.extrasOpen)
                            return ;

                        const naturalGap = bottomLimit - topLimit - root.extrasPush / 2;
                        const nextPush = Math.max(0, 2 * (extrasColumn.implicitHeight - naturalGap));
                        if (Math.abs(root.extrasPush - nextPush) > 0.5)
                            root.extrasPush = nextPush;

                        extrasScroll.offset = extrasScroll.maxOffset;
                    }

                    x: Math.round((parent.width - width) / 2)
                    y: bottomLimit - targetHeight
                    z: 10
                    width: Theme.buttonSize
                    height: targetHeight
                    visible: root.extrasOpen || height > 1
                    clip: true
                    onVisibleChanged: {
                        if (visible) {
                            Qt.callLater(updateExtrasPush);
                        } else {
                            root.extrasPush = 0;
                            extrasScroll.offset = 0;
                        }
                    }
                    onTopLimitChanged: Qt.callLater(updateExtrasPush)
                    onBottomLimitChanged: Qt.callLater(updateExtrasPush)

                    MouseArea {
                        id: extrasScroll

                        property real offset: 0
                        property real maxOffset: Math.max(0, extrasColumn.implicitHeight - parent.height)

                        anchors.fill: parent
                        acceptedButtons: Qt.NoButton
                        onMaxOffsetChanged: {
                            offset = Math.min(offset, maxOffset);
                            if (root.extrasOpen)
                                Qt.callLater(extrasViewport.updateExtrasPush);

                        }
                        onWheel: (event) => {
                            offset = Math.max(0, Math.min(maxOffset, offset - event.angleDelta.y / 4));
                        }
                    }

                    Column {
                        id: extrasColumn

                        width: parent.width
                        y: extrasViewport.contentY
                        opacity: root.extrasOpen ? 1 : 0
                        onImplicitHeightChanged: Qt.callLater(extrasViewport.updateExtrasPush)

                        Repeater {
                            model: SystemTray.items

                            Rectangle {
                                id: trayItem

                                width: Theme.buttonSize
                                height: Theme.buttonSize
                                radius: Theme.radius
                                color: trayMouse.containsMouse ? Theme.surfaceAlt : "transparent"
                                clip: true

                                Image {
                                    anchors.centerIn: parent
                                    width: 17
                                    height: 17
                                    source: modelData.icon
                                    fillMode: Image.PreserveAspectFit
                                    smooth: true
                                }

                                MouseArea {
                                    id: trayMouse

                                    anchors.fill: parent
                                    acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
                                    hoverEnabled: true
                                    preventStealing: true
                                    cursorShape: Qt.PointingHandCursor
                                    onPressed: (event) => {
                                        if (event.button !== Qt.RightButton)
                                            return ;

                                        event.accepted = true;
                                        root.openTrayMenu(modelData, Math.round(extrasViewport.y + extrasColumn.y + trayItem.y + trayItem.height / 2));
                                    }
                                    onClicked: (event) => {
                                        if (event.button === Qt.RightButton) {
                                            event.accepted = true;
                                            return ;
                                        } else if (event.button === Qt.MiddleButton)
                                            modelData.secondaryActivate();
                                        else
                                            modelData.activate();
                                    }
                                }

                            }

                        }

                        RailButton {
                            icon: root.updateIcon()
                            accent: updates.json.class === "zero" ? Theme.green : updates.json.class === "error" ? Theme.red : Theme.yellow
                            active: root.openPanel === "updates"
                            onClicked: (centerY) => {
                                return root.togglePanel("updates", extrasViewport.y + extrasColumn.y + centerY);
                            }
                            onHovered: (centerY) => root.hoverButtonEntered("updates", extrasViewport.y + extrasColumn.y + centerY, "updates")
                            onExited: root.hoverButtonExited("updates")
                            onRightClicked: root.run("kitty --class update-list --title update-list sh -c '" + root.scriptRoot + "/waybar/update/update-list.sh'")
                        }

                        RailButton {
                            icon: bluetooth.json.icon || "󰂯"
                            accent: bluetooth.json.class === "connected" ? Theme.blue : bluetooth.json.class === "disabled" ? Theme.red : Theme.foreground
                            active: root.openPanel === "bluetooth"
                            onClicked: (centerY) => {
                                return root.togglePanel("bluetooth", extrasViewport.y + extrasColumn.y + centerY);
                            }
                            onHovered: (centerY) => root.hoverButtonEntered("bluetooth", extrasViewport.y + extrasColumn.y + centerY, "bluetooth")
                            onExited: root.hoverButtonExited("bluetooth")
                            onRightClicked: root.run("blueman-manager")
                        }

                        RailButton {
                            icon: audio.json.micIcon || "󰍬"
                            accent: audio.json.micMuted ? Theme.red : Theme.foreground
                            active: root.openPanel === "mic"
                            onClicked: (centerY) => {
                                return root.togglePanel("mic", extrasViewport.y + extrasColumn.y + centerY);
                            }
                            onHovered: (centerY) => root.hoverButtonEntered("mic", extrasViewport.y + extrasColumn.y + centerY, "mic")
                            onExited: root.hoverButtonExited("mic")
                            onRightClicked: root.run("pavucontrol -t 4")
                        }

                        RailButton {
                            icon: brightness.json.icon || "󰃠"
                            accent: Theme.yellow
                            active: root.openPanel === "brightness"
                            onClicked: (centerY) => {
                                return root.togglePanel("brightness", extrasViewport.y + extrasColumn.y + centerY);
                            }
                            onHovered: (centerY) => root.hoverButtonEntered("brightness", extrasViewport.y + extrasColumn.y + centerY, "brightness")
                            onExited: root.hoverButtonExited("brightness")
                            onRightClicked: root.run(root.scriptRoot + "/waybar/hyprsunset-toggle.sh")
                            onWheeled: (delta) => {
                                return root.run("brightnessctl -d amdgpu_bl1 set " + (delta > 0 ? "+2%" : "2%-"));
                            }
                        }

                        RailButton {
                            icon: privacy.json.icon || "󰍹"
                            accent: privacy.json.class === "active" ? Theme.yellow : Theme.foreground
                            active: root.openPanel === "privacy"
                            onClicked: (centerY) => {
                                return root.togglePanel("privacy", extrasViewport.y + extrasColumn.y + centerY);
                            }
                            onHovered: (centerY) => root.hoverButtonEntered("privacy", extrasViewport.y + extrasColumn.y + centerY, "privacy")
                            onExited: root.hoverButtonExited("privacy")
                        }

                        Behavior on opacity {
                            NumberAnimation {
                                duration: 120
                            }

                        }

                    }

                    Behavior on height {
                        NumberAnimation {
                            duration: 160
                            easing.type: Easing.OutCubic
                        }

                    }

                    Behavior on y {
                        NumberAnimation {
                            duration: 160
                            easing.type: Easing.OutCubic
                        }

                    }

                }

            }

            PanelWindow {
                screen: modelData
                exclusionMode: ExclusionMode.Ignore
                focusable: true
                aboveWindows: true
                visible: root.openPanel === "power"
                color: "transparent"
                WlrLayershell.layer: WlrLayer.Overlay
                WlrLayershell.keyboardFocus: WlrKeyboardFocus.OnDemand

                anchors {
                    left: true
                    right: true
                    top: true
                    bottom: true
                }

                PowerOverlay {
                    anchors.fill: parent
                    updateSummary: root.updateSummary()
                    onAction: (kind) => {
                        return root.run(root.powerCommand(kind));
                    }
                    onClose: root.closePanel()
                }

            }

            PopupWindow {
                anchor.window: panel
                anchor.rect.x: Theme.railWidth + 8
                anchor.rect.y: Math.max(8, Math.min(panel.height - notesPopout.height - 8, root.openPanelY - notesPopout.height / 2))
                implicitWidth: notesPopout.width
                implicitHeight: notesPopout.height
                visible: root.openPanel === "todo"
                color: "transparent"

                Item {
                    width: notesPopout.width
                    height: notesPopout.height

                    HoverHandler {
                        onHoveredChanged: hovered ? root.popoutEntered() : root.popoutExited()
                    }

                    NotesPopout {
                        id: notesPopout

                        title: todo.json.name || "notes.md"
                        body: todo.json.raw || ""
                        file: todo.json.file || ""
                        index: todo.json.index || 0
                        count: todo.json.count || 1
                        maxPopoutWidth: panel.width > 0 && panel.screen ? panel.screen.width * 0.75 : 680
                        maxPopoutHeight: panel.height > 0 ? panel.height * 0.75 : 760
                        onPrevious: {
                            root.run(root.scriptRoot + "/quickshell/todo-cycle.sh -1");
                            todoRefreshDelay.restart();
                        }
                        onNext: {
                            root.run(root.scriptRoot + "/quickshell/todo-cycle.sh 1");
                            todoRefreshDelay.restart();
                        }
                        onSave: (file, body) => {
                            saveNotes.running = false;
                            saveNotes.command = ["python3", "-c", "from pathlib import Path; import sys; Path(sys.argv[1]).write_text(sys.argv[2])", file, body];
                            saveNotes.running = true;
                            notesPopout.editing = false;
                        }
                    }
                }

            }

            PopupWindow {
                anchor.window: panel
                anchor.rect.x: Theme.railWidth + 8
                anchor.rect.y: Math.max(8, Math.min(panel.height - trayMenuPopout.height - 8, root.trayMenuY - trayMenuPopout.height / 2))
                implicitWidth: trayMenuPopout.width
                implicitHeight: trayMenuPopout.height
                visible: root.trayMenuOpen
                color: "transparent"

                QsMenuOpener {
                    id: trayMenuOpener

                    menu: root.trayMenuHandle
                }

                Rectangle {
                    id: trayMenuPopout

                    width: 240
                    height: Math.min(420, Math.max(44, trayMenuContent.implicitHeight + 16))
                    radius: 8
                    color: Theme.background
                    border.color: Theme.surfaceAlt
                    border.width: 1
                    clip: true

                    HoverHandler {
                        onHoveredChanged: hovered ? root.popoutEntered() : root.popoutExited()
                    }

                    Column {
                        id: trayMenuContent

                        anchors.fill: parent
                        anchors.margins: 8
                        spacing: 2

                        Text {
                            width: parent.width
                            text: root.trayMenuTitle
                            color: Theme.blue
                            font.family: Theme.fontFamily
                            font.pixelSize: 12
                            font.bold: true
                            elide: Text.ElideRight
                            visible: text.length > 0
                        }

                        Repeater {
                            model: trayMenuOpener.children

                            Rectangle {
                                width: parent.width
                                height: modelData.isSeparator ? 7 : 28
                                radius: 5
                                color: !modelData.isSeparator && trayEntryMouse.containsMouse && modelData.enabled ? Theme.surfaceAlt : "transparent"
                                opacity: modelData.enabled ? 1 : 0.45

                                Rectangle {
                                    anchors.left: parent.left
                                    anchors.right: parent.right
                                    anchors.verticalCenter: parent.verticalCenter
                                    height: 1
                                    color: Theme.surfaceAlt
                                    visible: modelData.isSeparator
                                }

                                Text {
                                    anchors.left: parent.left
                                    anchors.leftMargin: 8
                                    anchors.right: parent.right
                                    anchors.rightMargin: 8
                                    anchors.verticalCenter: parent.verticalCenter
                                    text: modelData.text || ""
                                    color: Theme.foreground
                                    font.family: Theme.fontFamily
                                    font.pixelSize: 12
                                    elide: Text.ElideRight
                                    visible: !modelData.isSeparator
                                }

                                MouseArea {
                                    id: trayEntryMouse

                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: modelData.enabled && !modelData.isSeparator ? Qt.PointingHandCursor : Qt.ArrowCursor
                                    onClicked: {
                                        if (!modelData.enabled || modelData.isSeparator)
                                            return ;

                                        modelData.sendTriggered();
                                        root.closeTrayMenu();
                                    }
                                }
                            }
                        }
                    }
                }
            }

            PopupWindow {
                anchor.window: panel
                anchor.rect.x: Theme.railWidth + 8
                anchor.rect.y: Math.max(8, Math.min(panel.height - calendarPopout.height - 8, root.openPanelY - calendarPopout.height / 2))
                implicitWidth: calendarPopout.width
                implicitHeight: calendarPopout.height
                visible: root.openPanel === "calendar"
                color: "transparent"

                Item {
                    width: calendarPopout.width
                    height: calendarPopout.height

                    HoverHandler {
                        onHoveredChanged: hovered ? root.popoutEntered() : root.popoutExited()
                    }

                    CalendarPopout {
                        id: calendarPopout

                        baseDate: clock.date
                        selectedDate: root.selectedCalendarDate ? new Date(root.selectedCalendarDate + "T00:00:00") : clock.date
                        events: calendarEvents.json.events || []
                        eventsText: calendarEvents.json.raw || "No events"
                        onResetMonth: root.resetCalendarMonth()
                        onSelected: (day) => {
                            root.selectedCalendarDate = day;
                            calendarEvents.refresh();
                        }
                        onAddEvent: (day, title) => {
                            addCalendarEvent.running = false;
                            addCalendarEvent.command = [root.scriptRoot + "/quickshell/calendar-add.sh", day, title];
                            addCalendarEvent.running = true;
                        }
                        onOpenEvent: (title) => {
                            const date = root.selectedCalendarDate ? new Date(root.selectedCalendarDate + "T00:00:00") : clock.date;
                            root.run("xdg-open 'https://calendar.google.com/calendar/u/0/r/week/" + date.getFullYear() + "/" + (date.getMonth() + 1) + "/" + date.getDate() + "'");
                        }
                    }
                }

            }

            PopupWindow {
                anchor.window: panel
                anchor.rect.x: Theme.railWidth + 8
                anchor.rect.y: Math.max(8, Math.min(panel.height - performancePopout.height - 8, root.openPanelY - performancePopout.height / 2))
                implicitWidth: performancePopout.width
                implicitHeight: performancePopout.height
                visible: root.openPanel === "system"
                color: "transparent"

                Item {
                    width: performancePopout.width
                    height: performancePopout.height

                    HoverHandler {
                        onHoveredChanged: hovered ? root.popoutEntered() : root.popoutExited()
                    }

                    PerformancePopout {
                        id: performancePopout

                        status: systemInfo.json
                        scriptRoot: root.scriptRoot
                        onAction: (command) => {
                            root.run(command);
                            systemRefreshDelay.restart();
                        }
                    }
                }

            }

            PopupWindow {
                anchor.window: panel
                anchor.rect.x: Theme.railWidth + 8
                anchor.rect.y: Math.max(8, Math.min(panel.height - systemPopout.height - 8, root.openPanelY - systemPopout.height / 2))
                implicitWidth: systemPopout.width
                implicitHeight: systemPopout.height
                visible: ["audio", "network", "bluetooth", "mic", "brightness", "battery"].indexOf(root.openPanel) >= 0
                color: "transparent"
                onVisibleChanged: {
                    if (!visible && ["audio", "network", "bluetooth", "mic", "brightness", "battery"].indexOf(root.openPanel) >= 0)
                        root.closePanel();

                }

                Item {
                    width: systemPopout.width
                    height: systemPopout.height

                    HoverHandler {
                        onHoveredChanged: hovered ? root.popoutEntered() : root.popoutExited()
                    }

                    SystemPopout {
                        id: systemPopout

                        title: root.systemPanelTitle()
                        body: root.systemPanelBody()
                        actions: root.systemPanelActions()
                        mode: root.openPanel
                        audioVolume: audio.json.volume || 0
                        audioMuted: !!audio.json.muted
                        micMuted: !!audio.json.micMuted
                        wifiIcon: network.json.icon || "󰤩"
                        wifiText: network.json.ssid || network.json.class || "Wi-Fi"
                        bluetoothIcon: bluetooth.json.icon || "󰂯"
                        brightnessPercent: brightness.json.percent || 0
                        onAction: (command, keepOpen) => {
                            root.run(command);
                            if (!keepOpen)
                                root.closePanel();

                        }
                    }
                }

            }

            PopupWindow {
                anchor.window: panel
                anchor.rect.x: Theme.railWidth + 8
                anchor.rect.y: Math.max(8, Math.min(panel.height - popout.height - 8, root.openPanelY - popout.height / 2))
                implicitWidth: 320
                implicitHeight: popout.height
                visible: ["updates", "privacy"].indexOf(root.openPanel) >= 0
                color: "transparent"

                Item {
                    width: popout.width
                    height: popout.height

                    HoverHandler {
                        onHoveredChanged: hovered ? root.popoutEntered() : root.popoutExited()
                    }

                    BasicPopout {
                        id: popout

                        width: 320
                        title: root.panelTitle()
                        body: root.panelBody()
                        actions: root.panelActions()
                        onAction: (command, keepOpen) => {
                            root.run(command);
                            if (!keepOpen)
                                root.closePanel();

                        }
                    }
                }

            }

        }

    }

    SystemClock {
        id: clock

        precision: SystemClock.Seconds
    }

}
