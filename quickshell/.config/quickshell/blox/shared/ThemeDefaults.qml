import QtQuick

QtObject {
    function defaultWidgetItems() {
        return [{
            "id": "todo",
            "name": "Todo",
            "type": "custom",
            "enabled": true,
            "content_command": "$SCRIPT_ROOT/widgets/todo-content.sh",
            "left_click_command": "$SCRIPT_ROOT/widgets/cycle-todo.sh",
            "right_click_command": "$SCRIPT_ROOT/widgets/open-todo-editor.sh",
            "interval_ms": 60000,
            "visibility": "empty-workspace",
            "anchor": "top-left",
            "offset_x": 20,
            "offset_y": 20,
            "width": 0,
            "height": 0,
            "shape": "auto",
            "options": {
            }
        }, {
            "id": "calendar",
            "name": "Calendar",
            "type": "custom",
            "enabled": true,
            "content_command": "$SCRIPT_ROOT/widgets/gcal-content.sh",
            "left_click_command": "$SCRIPT_ROOT/widgets/cycle-gcal.sh",
            "right_click_command": "$SCRIPT_ROOT/widgets/open-gcal.sh",
            "interval_ms": 60000,
            "visibility": "empty-workspace",
            "anchor": "bottom-right",
            "offset_x": 20,
            "offset_y": 20,
            "width": 0,
            "height": 0,
            "shape": "auto",
            "options": {
            }
        }];
    }

    function defaultBarItems() {
        return [{
            "id": "power",
            "enabled": true,
            "region": "start",
            "order": 0
        }, {
            "id": "notes",
            "enabled": true,
            "region": "start",
            "order": 1
        }, {
            "id": "workspaces",
            "enabled": true,
            "region": "start",
            "order": 2
        }, {
            "id": "clock",
            "enabled": true,
            "region": "centre",
            "order": 0
        }, {
            "id": "battery",
            "enabled": true,
            "region": "end",
            "order": 0,
            "display": "toggle"
        }, {
            "id": "tray",
            "enabled": true,
            "region": "end",
            "order": 1
        }, {
            "id": "notifications",
            "enabled": true,
            "region": "end",
            "order": 2
        }, {
            "id": "wifi",
            "enabled": true,
            "region": "end",
            "order": 3
        }, {
            "id": "sound",
            "enabled": true,
            "region": "end",
            "order": 4
        }, {
            "id": "privacy",
            "enabled": true,
            "region": "hidden",
            "order": 0
        }, {
            "id": "awake",
            "enabled": true,
            "region": "hidden",
            "order": 1
        }, {
            "id": "display",
            "enabled": true,
            "region": "hidden",
            "order": 2
        }, {
            "id": "bt",
            "enabled": true,
            "region": "hidden",
            "order": 3
        }, {
            "id": "updates",
            "enabled": true,
            "region": "hidden",
            "order": 4
        }, {
            "id": "fan",
            "enabled": true,
            "region": "hidden",
            "order": 5,
            "visibility": "normal"
        }, {
            "id": "gpu",
            "enabled": true,
            "region": "hidden",
            "order": 6,
            "visibility": "normal"
        }, {
            "id": "application-tray",
            "enabled": true,
            "region": "hidden",
            "order": 7
        }, {
            "id": "touchpad",
            "enabled": true,
            "region": "hidden",
            "order": 8,
            "visibility": "normal"
        }];
    }

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

    function resolvedBarItems(overrides) {
        const items = defaultBarItems();
        const byId = {
        };
        for (let index = 0; index < overrides.length; index++) byId[overrides[index].id] = overrides[index]
        if (byId["tray"] && !byId["application-tray"]) {
            byId["application-tray"] = Object.assign({
            }, byId["tray"], {
                "id": "application-tray"
            });
            byId["tray"] = null;
        }
        for (let index = 0; index < items.length; index++) {
            const override = byId[items[index].id];
            if (override)
                items[index] = Object.assign({
            }, items[index], override);

        }
        const applicationTray = items.find((item) => {
            return item.id === "application-tray";
        });
        applicationTray.region = "hidden";
        const hidden = items.filter((item) => {
            return item.region === "hidden" && item.id !== "application-tray";
        }).sort((left, right) => {
            return left.order - right.order;
        });
        if (trayOpensForward(items))
            hidden.push(applicationTray);
        else
            hidden.unshift(applicationTray);
        for (let index = 0; index < hidden.length; index++) hidden[index].order = index
        return items;
    }

    function barItemsForRegion(items, region) {
        return items.filter((item) => {
            return item.enabled && item.region === region;
        }).sort((left, right) => {
            return left.order - right.order;
        });
    }

}
