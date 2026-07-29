import QtQuick

QtObject {
    id: root

    property string openPanel: ""
    property string scriptRoot: ""
    property date now: new Date()
    property bool clockDateMode: false
    property var updates: ({
    })
    property real updatesLastUpdatedMs: 0
    property var bluetooth: ({
    })
    property var audio: ({
    })
    property var brightness: ({
    })
    property var network: ({
    })
    property var privacy: ({
    })
    property var caffeine: ({
    })

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
            "privacy": "Privacy",
            "caffeine": "Awake",
            "updates": "Updates"
        };
        return titles[openPanel] || "";
    }

    function systemPanelTitle() {
        const titles = {
            "audio": "Audio",
            "network": "Network",
            "bluetooth": "Bluetooth",
            "brightness": "Display"
        };
        return titles[openPanel] || "";
    }

    function systemPanelBody() {
        if (openPanel === "audio")
            return "";

        if (openPanel === "network")
            return (network.tooltip || "Network unavailable").split("\n").slice(1).join("\n");

        if (openPanel === "bluetooth")
            return bluetooth.tooltip || "Bluetooth unavailable";

        if (openPanel === "brightness")
            return (brightness.tooltip || "Brightness unavailable").split("\n").slice(1).join("\n");

        return "";
    }

    function systemPanelActions() {
        if (openPanel === "audio")
            return [action(audio.micMuted ? "Unmute mic" : "Mute mic", scriptRoot + "/control.sh mic-toggle", {
            "keepOpen": true
        }), action("Open app", "pavucontrol -t 3")];

        if (openPanel === "network")
            return [action(network.class === "disabled" ? "Enable" : "Disable", scriptRoot + "/control.sh wifi " + (network.class === "disabled" ? "on" : "off"), {
            "keepOpen": true
        }), action("Open app", scriptRoot + "/network/toggle-applet.sh")];

        if (openPanel === "bluetooth")
            return [action(bluetooth.class === "disabled" ? "Enable" : "Toggle", scriptRoot + "/control.sh bluetooth-toggle", {
            "keepOpen": true
        }), action("Open app", "blueman-manager")];

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
            const days = horizontal ? ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"] : ["Su", "Mo", "Tu", "We", "Th", "Fr", "Sa"];
            if (horizontal)
                return days[now.getDay()] + " " + twoDigit(now.getDate()) + "/" + twoDigit(now.getMonth() + 1) + "/" + now.getFullYear();

            return days[now.getDay()] + "\n" + twoDigit(now.getDate()) + "\n" + twoDigit(now.getMonth() + 1) + "\n" + twoDigit(now.getFullYear() % 100);
        }
        const hour = now.getHours() % 12 || 12;
        if (horizontal) {
            const ampmState = now.getHours() < 12 ? "AM" : "PM";
            return twoDigit(hour) + ":" + twoDigit(now.getMinutes()) + ":" + twoDigit(now.getSeconds()) + " " + ampmState;
        }
        return twoDigit(hour) + "\n" + twoDigit(now.getMinutes()) + "\n" + twoDigit(now.getSeconds());
    }

    function elapsedText(ms) {
        if (!ms || ms <= 0)
            return "Not fetched yet";

        const elapsed = Math.max(0, Math.floor((now.getTime() - ms) / 1000));
        if (elapsed < 5)
            return "Fetched just now";

        if (elapsed < 60)
            return "Fetched " + elapsed + "s ago";

        const minutes = Math.floor(elapsed / 60);
        if (minutes < 60)
            return "Fetched " + minutes + "m ago";

        const hours = Math.floor(minutes / 60);
        return hours < 24 ? "Fetched " + hours + "h ago" : "Fetched " + Math.floor(hours / 24) + "d ago";
    }

    function panelSubtitle() {
        if (openPanel === "updates")
            return elapsedText(updatesLastUpdatedMs);

        if (openPanel === "caffeine")
            return caffeine.active ? (caffeine.hypridleRunning ? "Awake warning" : "Hypridle paused") : "Hypridle active";

        return "";
    }

    function panelHeaderActionIcon() {
        return openPanel === "updates" ? "󰑐" : "";
    }

    function panelHeaderActionCommand() {
        return openPanel === "updates" ? "__refresh_updates" : "";
    }

    function panelHeaderStatus() {
        if (openPanel !== "caffeine" || !caffeine.active)
            return "";

        return caffeine.mode === "indefinite" ? "∞" : caffeine.label || "";
    }

    function panelBody() {
        if (openPanel === "updates")
            return updateBody();

        if (openPanel === "caffeine")
            return "";

        if (openPanel === "privacy")
            return privacy.tooltip || "Privacy status unavailable";

        return "";
    }

    function panelActions() {
        if (openPanel === "updates") {
            const updateRun = "kitty --class update --title update sh -c '" + scriptRoot + "/update/run.sh; echo Done - press enter; read'";
            const updateList = "kitty --class update-list --title update-list sh -c '" + scriptRoot + "/update/list.sh'";
            return [action("Run updates", updateRun, {
                "icon": "󰇚"
            }), action("List updates", updateList, {
                "icon": ""
            })];
        }
        if (openPanel === "caffeine")
            return [action("Off", scriptRoot + "/status/caffeine.sh off", {
            "id": "off",
            "icon": "󰒲",
            "keepOpen": true
        }), action("30 mins", scriptRoot + "/status/caffeine.sh 30m", {
            "id": "30m",
            "icon": "󰔟",
            "keepOpen": true
        }), action("1 hr", scriptRoot + "/status/caffeine.sh 1h", {
            "id": "1h",
            "icon": "󰞌",
            "keepOpen": true
        }), action("Indefinite", scriptRoot + "/status/caffeine.sh indefinite", {
            "id": "indefinite",
            "icon": "󰒳",
            "keepOpen": true
        })];

        return [];
    }

}
