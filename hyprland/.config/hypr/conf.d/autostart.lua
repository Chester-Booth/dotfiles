hl.on("hyprland.start", function()
    -- 1. Update systemd environment variables first.
    hl.exec_cmd("dbus-update-activation-environment --systemd WAYLAND_DISPLAY XDG_CURRENT_DESKTOP GTK_THEME GDK_BACKEND QT_QPA_PLATFORM QT_QPA_PLATFORMTHEME XCURSOR_SIZE HYPRCURSOR_SIZE ELECTRON_OZONE_PLATFORM_HINT SDL_VIDEODRIVER MOZ_ENABLE_WAYLAND HYPRSHOT_DIR TERMINAL")
    hl.exec_cmd("systemctl --user import-environment SSH_AUTH_SOCK")
    hl.exec_cmd("dbus-update-activation-environment --systemd SSH_AUTH_SOCK")

    -- 2. Then start the authentication agent.
    hl.exec_cmd([[bash -c "sleep 1 && systemctl --user restart hyprpolkitagent"]])

    -- 3. Other apps.
    hl.exec_cmd("quickshell --no-duplicate --path ~/.config/quickshell/blox")
    hl.exec_cmd("hyprpaper")
    hl.exec_cmd("blueman-applet")
    hl.exec_cmd("hypridle")
    hl.exec_cmd("systemctl --user restart swayosd")
    hl.exec_cmd("~/.config/quickshell/blox/scripts/display/blue-light-mode.sh")
    hl.exec_cmd("vicinae server")
    hl.exec_cmd("zen-browser")

    -- Cloud sync is handled by user systemd timers.
end)
