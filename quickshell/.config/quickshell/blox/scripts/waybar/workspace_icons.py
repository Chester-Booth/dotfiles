#!/usr/bin/env python3
import socket
import os
import subprocess
import json
import sys
import time

# --- CONFIGURATION ---
PRIORITY = {
    "code": "󰨞",
    "zen": "󰖟",
    "helium": "󰖟",
    "firefox": "󰖟",
    "obsidian": "󰈚",
    "kitty": "",
    "discord": "",
    "jetbrains-idea-ce": "",
    "jetbrains-idea": "",
    "thunar": "󰉋",
    "com.github.maoschanz.drawing": "󱇣",
    "drawing": "󱇣"
}

ICON_DEFAULT = "󰻃"
# ---------------------

def get_hyprctl_json(command):
    try:
        output = subprocess.check_output(f"hyprctl -j {command}", shell=True)
        return json.loads(output)
    except Exception:
        return {}

def update_workspaces():
    clients = get_hyprctl_json("clients")
    workspaces = get_hyprctl_json("workspaces")
    
    # Map Windows to Workspaces
    ws_windows = {}
    for client in clients:
        ws_id = client["workspace"]["id"]
        c_class = client["class"].lower()
        if ws_id not in ws_windows:
            ws_windows[ws_id] = []
        ws_windows[ws_id].append(c_class)

    # Identify Target Workspaces (Persistent 1-5 + Existing)
    target_ids = list(range(1, 6))
    for ws in workspaces:
        if ws["id"] not in target_ids:
            target_ids.append(ws["id"])
    target_ids = sorted(list(set(target_ids)))

    ws_new_names = {}
    icon_counts = {}

    for ws_id in target_ids:
        print(f"Processing workspace ID: {ws_id}")
        # --- SPECIAL WORKSPACE ---
        if ws_id == -99 or ws_id < -1:
            print("Processing special workspace.")
            # If it has windows -> Name "magic" (Waybar shows Icon)
            # If empty -> Name "special:magic" (Hyprland hides it automatically)
            if ws_windows.get(ws_id):
                print("Special workspace with windows detected.")
                final_name = "magic"
            else:
                print("Special workspace empty.")
                final_name = "-98"

        # --- STANDARD WORKSPACE ---
        else:
            classes = ws_windows.get(ws_id, [])
            desired_icon = ICON_DEFAULT
            found_app = False
            
            # 1. Check Priority Apps
            if classes:
                for app_keyword, app_icon in PRIORITY.items():
                    if any(app_keyword in c for c in classes):
                        desired_icon = app_icon
                        found_app = True
                        break
            
            # 2. If Empty -> Use ID String ("1", "2")
            # This avoids the duplicate name bug.
            if not classes:
                desired_icon = str(ws_id)

            # 3. Handle Duplicates
            # If it's a number (empty), keep as is.
            if desired_icon.isdigit():
                final_name = desired_icon
            # If it's an icon, ensure uniqueness (󰖟, 󰖟_2)
            elif desired_icon not in icon_counts:
                icon_counts[desired_icon] = 1
                final_name = desired_icon
            else:
                icon_counts[desired_icon] += 1
                final_name = f"{desired_icon}_{icon_counts[desired_icon]}"
            
        ws_new_names[ws_id] = final_name

    # Apply Renames
    current_names = {ws["id"]: ws["name"] for ws in workspaces}

    for ws_id, new_name in ws_new_names.items():
        if current_names.get(ws_id) == new_name:
            continue
        
        # Don't fight with Hyprland's default special name
        if ws_id == -99 and new_name == "special:magic" and "special" in current_names.get(ws_id, ""):
            continue

        subprocess.run(f"hyprctl dispatch renameworkspace {ws_id} '{new_name}'", shell=True)

def listen():
    signature = os.environ.get('HYPRLAND_INSTANCE_SIGNATURE')
    xdg_runtime = os.environ.get('XDG_RUNTIME_DIR') or f"/run/user/{os.getuid()}"
    
    paths = [
        f"{xdg_runtime}/hypr/{signature}/.socket2.sock",
        f"/tmp/hypr/{signature}/.socket2.sock"
    ]

    sock_path = None
    for p in paths:
        if os.path.exists(p):
            sock_path = p
            break

    if not sock_path:
        return

    update_workspaces()

    with socket.socket(socket.AF_UNIX, socket.SOCK_STREAM) as client:
        try:
            client.connect(sock_path)
            while True:
                data = client.recv(1024)
                if not data:
                    break
                data_str = data.decode("utf-8")
                
                # We only care about CONTENT changes (windows moving/opening/closing)
                # We IGNORE "workspace>>" (focus changes) to prevent sticking bugs.
                if any(x in data_str for x in ["openwindow", "closewindow", "movewindow"]):
                    time.sleep(0.05) # Tiny buffer for JSON update
                    update_workspaces()
                    
        except Exception:
            pass

if __name__ == "__main__":
    try:
        listen()
    except KeyboardInterrupt:
        sys.exit(0)