#!/usr/bin/env python3
"""
Custom Hyprland Workspace Display Script for Waybar
Provides hybrid icon behavior: shows app icons when windows present, falls back to workspace state icons
"""

import json
import subprocess
import sys
from typing import Dict, List, Optional

# ==================== CONFIGURATION ====================

# Workspace state icons (fallback when no windows)
STATE_ICONS = {
    "active": "",
    "default": "󰻃",
    "empty": "󰄰",
    "urgent": "󰗖",
    "special": "󰘼",
    "special_active": "󰘻",
}

# Application class to icon mapping
APP_ICONS = {
    # Development
      "code": "󰨞",
      "Code": "󰨞",
      "VSCodium": "󰨞",
      "code-oss": "󰨞",

      "jetbrains-idea": "",
      "jetbrains-idea-ce": "",
      
      # Terminals
      "kitty": "",
      "Alacritty": "",
      "foot": "",
      "org.wezfurlong.wezterm": " ",
      
      # Browsers
      "zen": "",
      "Zen-browser": "",
      "Helium": "",
      "helium": "",
      "firefox": "",
      "Firefox": "",
      "chromium": "",
      "Google-chrome": "",
      "Brave-browser": "",
      
      # Communication
      "discord": "",
      "Discord": "",
      "Slack": "󰒱",
      "teams": "󰊻",
      "title<Signal": "󰍡",
      "title<WhatsApp.*": "",
      
      # File managers
      "thunar": "󰉋",
      "Thunar": "󰉋",
      "dolphin": "󰉋",
      "Dolphin": "󰉋",
      "nemo": "󰉋",
      "Nemo": "󰉋",
      "pcmanfm": "󰉋",
      "Pcmanfm": "󰉋",
      
      # Media
      "mpv": "",
      "mpv": "",
      "vlc": "󰕼",
      "spotify": "",
      "Spotify": "",
      
      # Productivity
      "obsidian": "󱞁",
      "obsidian": "󱞁",
      "Obsidian": "󱞁",
      "libreoffice.*": "󰈙",
      "ONLYOFFICE.*": "󰈙",
      
      # System
      "pavucontrol": "󰕾",
      "blueman-manager": "󰂯",
      "nm-connection-editor": "󱚾",
      
      
   
      "steam": "󰓓",
      "gimp": "",
      "com.github.maoschanz.drawing": "󱇣",
      "Drawing": "󱇣",
}

# Icon for unknown applications (not in APP_ICONS)
UNKNOWN_APP_ICON = "?"

# Persistent workspaces (always shown)
PERSISTENT_WORKSPACES = [1, 2, 3, 4, 5]

# ==================== SCRIPT LOGIC ====================

def run_hyprctl(command: str) -> dict:
    """Run hyprctl command and return JSON output"""
    try:
        result = subprocess.run(
            ["hyprctl", "-j"] + command.split(),
            capture_output=True,
            text=True,
            check=True
        )
        return json.loads(result.stdout)
    except (subprocess.CalledProcessError, json.JSONDecodeError) as e:
        print(f"Error running hyprctl: {e}", file=sys.stderr)
        return {}

def get_workspaces() -> List[dict]:
    """Get all workspaces from Hyprland"""
    return run_hyprctl("workspaces")

def get_clients() -> List[dict]:
    """Get all window clients from Hyprland"""
    return run_hyprctl("clients")

def get_active_workspace() -> int:
    """Get the currently active workspace ID"""
    active = run_hyprctl("activeworkspace")
    return active.get("id", 1)

def get_app_icon(window_class: str, title: str = "") -> str:
    """
    Get icon for application. Priority:
    1. Exact class match in APP_ICONS
    2. Title match (for special cases)
    3. UNKNOWN_APP_ICON
    """
    # Try exact class match
    if window_class in APP_ICONS:
        return APP_ICONS[window_class]
    
    # Try title matching for special cases
    if "nvim" in title.lower():
        return ""
    if "youtube" in title.lower():
        return ""
    
    return UNKNOWN_APP_ICON

def get_workspace_windows(workspace_id: int, clients: List[dict]) -> List[dict]:
    """Get all windows in a specific workspace"""
    return [
        client for client in clients
        if client.get("workspace", {}).get("id") == workspace_id
    ]

def get_workspace_icon(workspace_id: int, clients: List[dict], active_id: int, is_special: bool = False) -> str:
    """
    Get the icon to display for a workspace.
    Logic:
    1. If workspace has windows, show the icon of the FIRST/PRIMARY window
    2. If workspace is empty:
       - Active: show active icon
       - Persistent: show default icon
       - Empty: show empty icon
    """
    windows = get_workspace_windows(workspace_id, clients)
    
    # Special workspace handling
    if is_special:
        if not windows:
            return ""  # Empty special - will be hidden by CSS
        if workspace_id == active_id:
            return STATE_ICONS["special_active"]
        return STATE_ICONS["special"]
    
    # Has windows - show app icon of first window
    if windows:
        # Get the first window (you could sort by size, focus, etc.)
        primary_window = windows[0]
        window_class = primary_window.get("class", "")
        window_title = primary_window.get("title", "")
        return get_app_icon(window_class, window_title)
    
    # Empty workspace - show state icon
    is_active = workspace_id == active_id
    is_persistent = workspace_id in PERSISTENT_WORKSPACES
    
    if is_active:
        return STATE_ICONS["active"]
    elif is_persistent:
        return STATE_ICONS["default"]
    else:
        return STATE_ICONS["empty"]

def generate_waybar_output():
    """Generate JSON output for Waybar custom module"""
    workspaces = get_workspaces()
    clients = get_clients()
    active_id = get_active_workspace()
    
    workspace_data = []
    
    # Regular workspaces (ensure persistent ones are included)
    all_workspace_ids = set(PERSISTENT_WORKSPACES)
    all_workspace_ids.update(ws["id"] for ws in workspaces if ws["id"] > 0)
    
    for ws_id in sorted(all_workspace_ids):
        windows = get_workspace_windows(ws_id, clients)
        icon = get_workspace_icon(ws_id, clients, active_id)
        
        workspace_data.append({
            "id": ws_id,
            "icon": icon,
            "active": ws_id == active_id,
            "windows": len(windows),
            "empty": len(windows) == 0
        })
    
    # Special workspaces
    special_workspaces = [ws for ws in workspaces if ws["id"] < 0]
    for ws in special_workspaces:
        ws_id = ws["id"]
        windows = get_workspace_windows(ws_id, clients)
        
        # Skip empty special workspaces
        if not windows:
            continue
            
        icon = get_workspace_icon(ws_id, clients, active_id, is_special=True)
        
        workspace_data.append({
            "id": ws_id,
            "icon": icon,
            "active": ws_id == active_id,
            "windows": len(windows),
            "special": True
        })
    
    # Format for Waybar
    text = "\n".join(ws["icon"] for ws in workspace_data)
    tooltip = "\n".join(
        f"Workspace {ws['id']}: {ws['windows']} windows"
        for ws in workspace_data
    )
    
    output = {
        "text": text,
        "tooltip": tooltip,
        "class": "active" if any(ws["active"] for ws in workspace_data) else ""
    }
    
    print(json.dumps(output))

def main():
    """Main entry point"""
    try:
        generate_waybar_output()
    except Exception as e:
        print(f"Error: {e}", file=sys.stderr)
        print(json.dumps({"text": "ERROR", "tooltip": str(e)}))
        sys.exit(1)

if __name__ == "__main__":
    main()
