hl.env("XCURSOR_THEME", "Bibata-Modern-Classic")
hl.env("XCURSOR_SIZE", "20")
hl.env("HYPRCURSOR_SIZE", "20")

-- Keep the compositor's session type available to apps and user services.
hl.env("XDG_SESSION_TYPE", "wayland")
hl.env("GDK_BACKEND", "wayland,x11")
hl.env("QT_QPA_PLATFORM", "wayland;xcb")
hl.env("QT_QPA_PLATFORMTHEME", "gtk3")
hl.env("SDL_VIDEODRIVER", "wayland")
hl.env("MOZ_ENABLE_WAYLAND", "1")
hl.env("HYPRSHOT_DIR", "/home/blox/Pictures/Screenshots")

hl.env("TERMINAL", "kitty")
