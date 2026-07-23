import QtQuick

QtObject {
    id: root

    property string openPanel: ""
    property string scriptRoot: ""
    property date now: new Date()
    property bool clockDateMode: false
    property var updates: ({})
    property real updatesLastUpdatedMs: 0
    property var todo: ({})
    property var calendar: ({})
    property var bluetooth: ({})
    property var audio: ({})
    property var brightness: ({})
    property var network: ({})
    property var privacy: ({})
    property var touchpad: ({})
    property var system: ({})
    property var battery: ({})
    property var caffeine: ({})
    property string notificationTooltip: ""

    function action(label, command, extra) {
        const value = {
            "label": label,
            "command": command
        };
        if (extra) {
            for (const key in extra) value[key] = extra[key]
        }
        return value;
    }

    function powerCommand(kind) {
        if (kind === "update-shutdown")
            return "kitty --class update-shutdown --title update-shutdown sh -c '" + scriptRoot + "/update/run.sh; " + scriptRoot + "/power/safe.sh shutdown'";

        return scriptRoot + "/power/safe.sh " + kind;
    }

    function updateSummary() {
        const text = updates.tooltip || "";
        const match = text.match(/([0-9]+)\s+repo updates,\s+([0-9]+)\s+AUR updates/);
        if (match)
            return (parseInt(match[1]) + parseInt(match[2])) + " updates";
        if (updates.class === "zero")
            return "0 updates";
        return text || "Check updates";
    }

    function updateBody() {
        const text = updates.tooltip || "";
        const match = text.match(/([0-9]+)\s+repo updates,\s+([0-9]+)\s+AUR updates/i);
        if (match) {
            const repo = parseInt(match[1]);
            const aur = parseInt(match[2]);
            return repo + " repo updates, " + aur + " yay updates\n" + (repo + aur) + " total updates";
        }
        if (updates.class === "zero")
            return "0 repo updates, 0 yay updates\n0 total updates";
        return text || "Update status unavailable";
    }

    function panelTitle() {
        const titles = {
            "audio": "Audio", "battery": "Battery", "bluetooth": "Bluetooth",
            "brightness": "Brightness", "calendar": "Calendar", "extras": "Extras",
            "fan": "Fan", "gpu": "GPU", "network": "Network",
            "notifications": "Notifications", "power": "Power", "privacy": "Privacy",
            "caffeine": "Awake", "todo": "Todo", "updates": "Updates"
        };
        return titles[openPanel] || "";
    }

    function systemPanelTitle() {
        const titles = {
            "audio": "Audio", "network": "Network", "bluetooth": "Bluetooth",
            "mic": "Microphone", "brightness": "Display", "system": "Performance",
            "battery": "Battery"
        };
        return titles[openPanel] || panelTitle();
    }

    function systemPanelBody() {
        if (openPanel === "audio") return "";
        if (openPanel === "network") return (network.tooltip || "Network unavailable").split("\n").slice(1).join("\n");
        if (openPanel === "bluetooth") return bluetooth.tooltip || "Bluetooth unavailable";
        if (openPanel === "mic") return audio.micMuted ? "Microphone muted" : "Microphone open";
        if (openPanel === "brightness") return (brightness.tooltip || "Brightness unavailable").split("\n").slice(1).join("\n");
        if (openPanel === "system") return "Fan\n" + (system.profile || "Unknown") + "\n\nGPU\n" + (system.gpuLabel || "GPU unavailable");
        if (openPanel === "battery") return battery.tooltip || "Battery unavailable";
        return panelBody();
    }

    function systemPanelActions() {
        if (openPanel === "audio")
            return [action(audio.micMuted ? "Unmute mic" : "Mute mic", scriptRoot + "/control.sh mic-toggle", {"keepOpen": true}), action("Open app", "pavucontrol -t 3")];
        if (openPanel === "network")
            return [action(network.class === "disabled" ? "Enable" : "Disable", scriptRoot + "/control.sh wifi " + (network.class === "disabled" ? "on" : "off"), {"keepOpen": true}), action("Open app", scriptRoot + "/network/toggle-applet.sh")];
        if (openPanel === "bluetooth")
            return [action(bluetooth.class === "disabled" ? "Enable" : "Toggle", scriptRoot + "/control.sh bluetooth-toggle", {"keepOpen": true}), action("Open app", "blueman-manager")];
        if (openPanel === "mic")
            return [action(audio.micMuted ? "Unmute" : "Mute", scriptRoot + "/control.sh mic-toggle", {"keepOpen": true}), action("Open app", "pavucontrol -t 4")];
        return [];
    }

    function updateIcon() {
        const value = updates.class || updates.alt || "zero";
        return value === "error" ? "" : value === "zero" ? "󰅠" : value === "lessfifty" ? "󰅢" : "󰧠";
    }

    function twoDigit(value) {
        return value < 10 ? "0" + value : String(value);
    }

    function railClockText(horizontal) {
        if (clockDateMode) {
            const days = horizontal
                ? ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"]
                : ["Su", "Mo", "Tu", "We", "Th", "Fr", "Sa"];

            if (horizontal) {
                return days[now.getDay()]
                    + " " + twoDigit(now.getDate())
                    + "/" + twoDigit(now.getMonth() + 1)
                    + "/" + now.getFullYear();
            }

            return days[now.getDay()]
                + "\n" + twoDigit(now.getDate())
                + "\n" + twoDigit(now.getMonth() + 1)
                + "\n" + twoDigit(now.getFullYear() % 100);
        }

        const hour = now.getHours() % 12 || 12;

        if (horizontal) {
            const ampmState = now.getHours() < 12 ? "AM" : "PM";

            return twoDigit(hour)
                + ":" + twoDigit(now.getMinutes())
                + ":" + twoDigit(now.getSeconds())
                + " " + ampmState;
        }

        return twoDigit(hour)
            + "\n" + twoDigit(now.getMinutes())
            + "\n" + twoDigit(now.getSeconds());
    }

    function elapsedText(ms) {
        if (!ms || ms <= 0) return "Not fetched yet";
        const elapsed = Math.max(0, Math.floor((now.getTime() - ms) / 1000));
        if (elapsed < 5) return "Fetched just now";
        if (elapsed < 60) return "Fetched " + elapsed + "s ago";
        const minutes = Math.floor(elapsed / 60);
        if (minutes < 60) return "Fetched " + minutes + "m ago";
        const hours = Math.floor(minutes / 60);
        return hours < 24 ? "Fetched " + hours + "h ago" : "Fetched " + Math.floor(hours / 24) + "d ago";
    }

    function panelSubtitle() {
        if (openPanel === "updates") return elapsedText(updatesLastUpdatedMs);
        if (openPanel === "caffeine") return caffeine.active ? (caffeine.hypridleRunning ? "Awake warning" : "Hypridle paused") : "Hypridle active";
        return "";
    }

    function panelHeaderActionIcon() {
        return openPanel === "updates" ? "󰑐" : "";
    }

    function panelHeaderActionCommand() {
        return openPanel === "updates" ? "__refresh_updates" : "";
    }

    function panelHeaderStatus() {
        if (openPanel !== "caffeine" || !caffeine.active) return "";
        return caffeine.mode === "indefinite" ? "∞" : caffeine.label || "";
    }

    function panelBody() {
        if (openPanel === "power") return "Session actions use the guarded power backend, including the micro guard.";
        if (openPanel === "todo") return todo.tooltip || "Todo status unavailable";
        if (openPanel === "calendar") return Qt.formatDateTime(now, "dddd, dd MMMM yyyy");
        if (openPanel === "extras") return "Tray/menu placeholder\n" + (updates.tooltip || "Update status unavailable") + "\n" + (bluetooth.tooltip || "Bluetooth unavailable") + "\n" + (audio.micMuted ? "Mic muted" : "Mic open") + "\n" + (brightness.tooltip || "Brightness unavailable") + "\n" + (privacy.tooltip || "Privacy unavailable");
        if (openPanel === "updates") return updateBody();
        if (openPanel === "caffeine") return "";
        if (openPanel === "bluetooth") return bluetooth.tooltip || "Bluetooth status unavailable";
        if (openPanel === "brightness") return brightness.tooltip || "Brightness status unavailable";
        if (openPanel === "privacy") return privacy.tooltip || "Privacy status unavailable";
        if (openPanel === "audio") return audio.tooltip || "Audio status unavailable";
        if (openPanel === "network") return (network.tooltip || "Network unavailable") + "\n\n" + (bluetooth.tooltip || "Bluetooth unavailable");
        if (openPanel === "notifications") return notificationTooltip;
        if (openPanel === "touchpad") return touchpad.tooltip || "Touchpad status unavailable";
        if (openPanel === "fan") return "Fan profile: " + (system.profile || "Unknown") + "\n" + (system.fanRpm || "N/A") + " RPM";
        if (openPanel === "gpu") return system.gpuLabel || "GPU status unavailable";
        if (openPanel === "battery") return battery.tooltip || "Battery status unavailable";
        return "";
    }

    function panelActions(panel) {
        const current = panel || openPanel;
        const updateRun = "kitty --class update --title update sh -c '" + scriptRoot + "/update/run.sh; echo Done - press enter; read'";
        const updateList = "kitty --class update-list --title update-list sh -c '" + scriptRoot + "/update/list.sh'";
        if (current === "power") return [action("Lock", scriptRoot + "/power/safe.sh lock"), action("Sleep", scriptRoot + "/power/safe.sh sleep"), action("Hibernate", scriptRoot + "/power/safe.sh hibernate"), action("Reboot", scriptRoot + "/power/safe.sh reboot", {"danger": true}), action("Shut down", scriptRoot + "/power/safe.sh shutdown", {"danger": true})];
        if (current === "todo") return [action("Cycle file", scriptRoot + "/todo/cycle.sh"), action("Open editor", scriptRoot + "/todo/open.sh")];
        if (current === "calendar") return [action("Open calendar", "xdg-open 'https://calendar.google.com/calendar/u/0/r/week'")];
        if (current === "updates") return [action("Run updates", updateRun, {"icon": "󰇚"}), action("List updates", updateList, {"icon": ""})];
        if (current === "bluetooth") return [action(bluetooth.class === "disabled" ? "Enable Bluetooth" : "Toggle Bluetooth", scriptRoot + "/control.sh bluetooth-toggle"), action("Bluetooth manager", "blueman-manager")];
        if (current === "brightness") return [action("Brightness up", scriptRoot + "/control.sh brightness-up 5"), action("Brightness down", scriptRoot + "/control.sh brightness-down 5"), action("Toggle sunset", scriptRoot + "/display/hyprsunset-toggle.sh")];
        if (current === "audio") return [action(audio.muted ? "Unmute output" : "Mute output", scriptRoot + "/control.sh audio-toggle"), action("Volume up", scriptRoot + "/control.sh audio-up 5"), action("Volume down", scriptRoot + "/control.sh audio-down 5"), action("Audio settings", "pavucontrol -t 3")];
        if (current === "network") return [action(network.class === "disabled" ? "Enable Wi-Fi" : "Toggle Wi-Fi", scriptRoot + "/control.sh wifi " + (network.class === "disabled" ? "on" : "off")), action("Network applet", scriptRoot + "/network/toggle-applet.sh"), action(bluetooth.class === "disabled" ? "Enable Bluetooth" : "Toggle Bluetooth", scriptRoot + "/control.sh bluetooth-toggle"), action("Bluetooth manager", "blueman-manager")];
        if (current === "notifications") return [action("Clear notifications", "__clear_notifications")];
        if (current === "caffeine") return [action("Off", scriptRoot + "/status/caffeine.sh off", {"id": "off", "icon": "󰒲", "keepOpen": true}), action("30 mins", scriptRoot + "/status/caffeine.sh 30m", {"id": "30m", "icon": "󰔟", "keepOpen": true}), action("1 hr", scriptRoot + "/status/caffeine.sh 1h", {"id": "1h", "icon": "󰞌", "keepOpen": true}), action("Indefinite", scriptRoot + "/status/caffeine.sh indefinite", {"id": "indefinite", "icon": "󰒳", "keepOpen": true})];
        if (current === "fan") return [action("Performance", scriptRoot + "/control.sh fan-profile performance"), action("Balanced", scriptRoot + "/control.sh fan-profile balanced"), action("Quiet", scriptRoot + "/control.sh fan-profile quiet")];
        if (current === "gpu") return [action("Gaming: GPU + 144Hz", scriptRoot + "/gpu/set-mode.sh gaming"), action("Performance: GPU + 60Hz", scriptRoot + "/gpu/set-mode.sh performance"), action("High refresh: iGPU + 144Hz", scriptRoot + "/gpu/set-mode.sh high-refresh"), action("Eco: iGPU + 60Hz", scriptRoot + "/gpu/set-mode.sh eco")];
        if (current === "extras") return [action("Run updates", updateRun), action("List updates", updateList), ...panelActions("bluetooth"), action(audio.micMuted ? "Unmute microphone" : "Mute microphone", scriptRoot + "/control.sh mic-toggle"), action("Microphone settings", "pavucontrol -t 4"), ...panelActions("brightness")];
        return [];
    }
}
