import QtQuick

QtObject {
    function trayOpensForward(items) {
        const tray = items.find((item) => {
            return item.id === "tray";
        });
        if (!tray || tray.region === "end")
            return false;

        if (tray.region === "start")
            return true;

        if (tray.region !== "centre")
            return false;

        const centre = items.filter((item) => {
            return item.region === "centre";
        }).sort((left, right) => {
            return left.order - right.order;
        });
        return centre.length > 0 && centre[centre.length - 1].id === "tray";
    }

    function applicationTrayAtStart(items) {
        return !trayOpensForward(items);
    }

    function normaliseOrders(items) {
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
        for (const region of regions) {
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
                const trayItem = members.splice(applicationTrayIndex, 1)[0];
                if (applicationTrayAtStart(items))
                    members.unshift(trayItem);
                else
                    members.push(trayItem);
            }
            for (let index = 0; index < members.length; ++index) {
                members[index].order = index;
                ordered.push(members[index]);
            }
        }
        return ordered;
    }

    function label(id) {
        const labels = {
            "application-tray": "Application tray",
            "bt": "Bluetooth",
            "notifications": "Notifications",
            "wifi": "Wi-Fi"
        };
        return labels[id] || id.charAt(0).toUpperCase() + id.slice(1);
    }

    function previewIcon(id) {
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

}
