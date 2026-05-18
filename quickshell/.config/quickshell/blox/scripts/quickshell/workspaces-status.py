#!/usr/bin/env python3
import json
import subprocess


def hypr_json(*args):
    try:
        out = subprocess.check_output(["hyprctl", *args, "-j"], text=True, stderr=subprocess.DEVNULL)
        return json.loads(out)
    except Exception:
        return None


def icon_for(value):
    app = (value or "").lower()
    if "t3" in app:
        return ""
    if any(term in app for term in ("intellij", "idea")):
        return ""
    if "code" in app:
        return "󰨞"
    if "zen" in app:
        return "󰈹"
    if "helium" in app:
        return ""
    if any(browser in app for browser in ("zen", "helium", "firefox", "chrome", "brave")):
        return ""
    if any(term in app for term in ("discord", "vesktop")):
        return ""
    if "slack" in app:
        return "󰒱"
    if "teams" in app:
        return "󰊻"
    if any(files in app for files in ("thunar", "dolphin", "nemo", "pcmanfm")):
        return "󰉋"
    if "obsidian" in app:
        return "󱞁"
    if "obs" in app:
        return "󰕧"
    if "steam" in app:
        return "󰓓"
    if any(term in app for term in ("prism", "minecraft")):
        return "󰍳"
    if "gimp" in app:
        return ""
    if "electron" in app:
        return ""
    if "drawing" in app:
        return "󱇣"
    if any(term in app for term in ("kitty", "wezterm", "alacritty", "foot")):
        return ""
    return "󰻃"


active = hypr_json("activeworkspace") or {}
clients = hypr_json("clients") or []

active_id = active.get("id")
active_name = str(active.get("name", ""))
by_workspace = {}
urgent = set()

for client in clients:
    workspace = client.get("workspace") or {}
    workspace_id = workspace.get("id")
    if workspace_id is None:
        continue

    by_workspace.setdefault(workspace_id, []).append(client)
    if client.get("urgent"):
        urgent.add(workspace_id)

items = []
for workspace_id in range(1, 6):
    workspace_clients = by_workspace.get(workspace_id, [])
    focused = workspace_id == active_id
    chosen = None

    if focused:
        chosen = next((client for client in workspace_clients if client.get("focusHistoryID") == 0), None)

    if chosen is None and workspace_clients:
        chosen = workspace_clients[0]

    app = ""
    title = ""
    if chosen:
        app = chosen.get("class") or chosen.get("initialClass") or ""
        title = chosen.get("title") or ""

    items.append({
        "id": workspace_id,
        "active": focused,
        "urgent": workspace_id in urgent,
        "empty": len(workspace_clients) == 0,
        "icon": "󰗖" if workspace_id in urgent else (icon_for(app) if chosen else "󰄰"),
        "tooltip": f"Workspace {workspace_id}" + (f"\\n{app}\\n{title}" if app or title else ""),
    })

special_active = active_name.startswith("special")
special_clients = [
    client for client in clients
    if str((client.get("workspace") or {}).get("name", "")).startswith("special")
]
print(json.dumps({
    "main": items,
    "special": {
        "active": special_active,
        "occupied": len(special_clients) > 0,
        "icon": "󰘻" if special_active else "󰘼",
        "tooltip": "Special workspace" + (f"\\n{len(special_clients)} window(s)" if special_clients else ""),
    },
}))
