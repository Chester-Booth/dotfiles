#!/usr/bin/env python3
import json
import subprocess


def hypr_json(*args):
    try:
        out = subprocess.check_output(["hyprctl", *args, "-j"], text=True, stderr=subprocess.DEVNULL)
        return json.loads(out)
    except Exception:
        return None


ICON_RULES = [
    (("t3",), ""),
    (("intellij", "idea"), ""),
    (("code",), "󰨞"),
    (("zen",), "󰈹"),
    (("helium",), ""),
    (("zen", "helium", "firefox", "chrome", "brave"), ""),
    (("discord", "vesktop"), ""),
    (("slack",), "󰒱"),
    (("teams",), "󰊻"),
    (("thunar", "dolphin", "nemo", "pcmanfm"), "󰉋"),
    (("obsidian",), "󱞁"),
    (("obs",), "󰕧"),
    (("steam",), "󰓓"),
    (("prism", "minecraft"), "󰍳"),
    (("gimp",), ""),
    (("electron",), ""),
    (("drawing",), "󱇣"),
    (("kitty", "wezterm", "alacritty", "foot"), ""),
]


def app_name(client):
    return client.get("class") or client.get("initialClass") or ""


def icon_match(value):
    app = (value or "").lower()
    for index, (terms, icon) in enumerate(ICON_RULES):
        if any(term in app for term in terms):
            return index, icon
    return len(ICON_RULES), "󰻃"


def icon_for(value):
    return icon_match(value)[1]


def priority_client(clients):
    if not clients:
        return None

    return min(
        clients,
        key=lambda client: (
            icon_match(app_name(client))[0],
            client.get("focusHistoryID", 999999),
        ),
    )


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

workspace_ids = set(range(1, 6))
workspace_ids.update(
    workspace_id
    for workspace_id, workspace_clients in by_workspace.items()
    if workspace_id > 5 and workspace_clients
)

items = []
for workspace_id in sorted(workspace_ids):
    workspace_clients = by_workspace.get(workspace_id, [])
    focused = workspace_id == active_id
    chosen = priority_client(workspace_clients)
    urgent_client = next((client for client in workspace_clients if client.get("urgent")), None)

    app = ""
    title = ""
    if chosen:
        app = app_name(chosen)
        title = chosen.get("title") or ""

    items.append({
        "id": workspace_id,
        "active": focused,
        "urgent": workspace_id in urgent,
        "urgentAddress": urgent_client.get("address", "") if urgent_client else "",
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
