-- When Super binds change, update the explicit model in ShortcutGuideWindow.qml.

-- Ignore maximise requests from apps.
hl.window_rule({ match = { class = ".*" }, suppress_event = "maximize" })

-- Fix some dragging issues with XWayland.
hl.window_rule({
    match = { class = "^$", title = "^$", xwayland = true, float = true, fullscreen = false, pin = false },
    no_focus = true,
})

-- Round floating dialogs/popups while keeping tiled windows square.
hl.window_rule({ match = { float = true }, rounding = 8 })

-- Keep external-monitor workspaces fully opaque, even when inactive.
for workspace = 11, 22 do
    hl.window_rule({ match = { workspace = tostring(workspace) }, opacity = "1.0 override 1.0 override 1.0 override" })
end

-- Float modal/dialogue windows globally
hl.window_rule({
    match = { modal = true },
    float = true,
})

-- Float every Thunar window/dialog
hl.window_rule({
    match = {
        class = "^(thunar|Thunar)$",
    },
    float = true,
})

-- Only resize normal Thunar browser windows
hl.window_rule({
    match = {
        class = "^(thunar|Thunar)$",
        initial_title = "^.* - Thunar$",
    },
    size = { 800, 600 },
})

-- File Roller
hl.window_rule({
    match = {
        class = "^(file-roller|org[.]gnome[.]FileRoller)$",
    },
    float = true,
    size = { 800, 600 },
})


-- File dialogs float and are centred.
hl.window_rule({ match = { title = "^(Open File|Open Files|Save File|Save As|Save Workspace|Select Folder|Open Folder|File Upload|Choose a wallpaper)$" }, float = true, size = { 800, 600 } })
hl.window_rule({ match = { title = "^(Open File|Open Files|Save File|Save As|Select Folder|Open Folder|File Upload|Choose a wallpaper)$" }, center = true })

-- The theme picker is a movable regular window which remains floating.
hl.window_rule({ match = { title = "^Blox Theme Picker$" }, float = true, center = true, size = { 1320, 860 } })
hl.window_rule({ match = { title = "^Blox Theme Application$" }, float = true, center = true })
hl.window_rule({ match = { class = "^org\\.quickshell$", title = "^Blox (Clipboard|Emoji Picker)$" }, float = true })
hl.window_rule({ match = { class = "^org\\.quickshell$", title = "^Blox Calendar (Event Details|New Event|Edit Event|Delete Event)$" }, float = true, pin = true })
hl.window_rule({
    match = {
        class = "^(xdg-desktop-portal-gtk)$",
        title = "^(Open File|Open Files|Save File|Save As|Select Folder|Open Folder|File Upload).*Zen Browser$",
    },
    float = true,
    center = true,
    size = { 800, 600 },
})
hl.window_rule({ match = { title = "^(File Operation Progress|Copying Files|Moving Files|Deleting Files)$" }, float = true, center = true })

-- Git clone dialog floats and is centred.
hl.window_rule({ match = { title = "^Choose a folder to clone .+ into$" }, float = true, center = true, size = { 800, 600 } })

hl.window_rule({ match = { class = "^(org.pulseaudio.pavucontrol)$" }, float = true, size = { 600, 400 } })
hl.window_rule({ match = { class = "^(blueman-manager)$" }, float = true, size = { 800, 600 } })
hl.window_rule({ match = { class = "^(zen)$", title = "^(Library)$" }, float = true, size = { 800, 600 } })
hl.window_rule({ match = { class = "^(nm-connection-editor)$" }, float = true, size = { 800, 600 } })
hl.window_rule({ match = { class = "^(nmtui)$", title = "^(nmtui)$" }, float = true, size = { 800, 600 } })
hl.window_rule({ match = { class = "^(todo)$", title = "^(todo)$" }, float = true, size = { 400, 300 }, pin = true, move = { 1100, 520 } })
hl.window_rule({ match = { class = "^(quickshell_todo)$", title = "^(quickshell_todo)$" }, float = true, pin = true })
hl.window_rule({ match = { class = "^(update)$", title = "^(update)$" }, float = true, size = { 860, 570 } })
hl.window_rule({ match = { class = "^(update-list)$", title = "^(update-list)$" }, float = true, size = { 400, 600 } })
hl.window_rule({
    match = { class = "^(floating-sudo)$" },
    float = true,
    center = true,
    size = { 720, 520 },
    opacity = "1.0 override 1.0 override 1.0 override",
})

hl.window_rule({ match = { title = "^(Fingerprint Enrollment)$" }, float = true, size = { 400, 600 } })
hl.window_rule({ match = { title = "^(Open folder as vault)$" }, float = true, size = { 800, 100 } })

hl.window_rule({ match = { class = "^(org.gnome.gedit)" }, float = true })
hl.window_rule({ match = { class = "^(org.gnome.gedit)$" }, size = { 800, 600 } })

hl.window_rule({ match = { class = "^(micro-active)$" }, float = true, size = { 480, 480 }, move = { "((monitor_w*0.74))", "((monitor_h*0.06))" } })

hl.window_rule({ match = { class = "^(nvidia-settings)$" }, float = true })
hl.window_rule({ match = { class = "^(nvidia-settings)$" }, size = { 800, 600 } })

hl.window_rule({
    match = { title = "^(Picture in picture|Picture-in-Picture).*" },
    float = true,
    pin = true,
    move = { "((monitor_w*0.69))", "((monitor_h*0.06))" },
    opacity = "1.0 override 1.0 override 1.0 override",
})

hl.window_rule({ match = { workspace = "name:special:magic" }, size = { 600, 500 }, float = true, move = { "((monitor_w*0.05))", "((monitor_h*0.07))" } })

-- Apps launch in correct locations.
hl.window_rule({ match = { class = "^(jetbrains-idea-ce)$", float = false }, workspace = "2 silent" })
hl.window_rule({ match = { class = "^(jetbrains-idea)$", float = false }, workspace = "2 silent" })
hl.window_rule({ match = { class = "^(discord)$" }, workspace = "5 silent" })

hl.config({
    xwayland = {
        force_zero_scaling = true,
    },
})

hl.layer_rule({ match = { namespace = "wofi" }, blur = true, ignore_alpha = 0.5 })
