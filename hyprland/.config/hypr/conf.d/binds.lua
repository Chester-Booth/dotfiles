local programs = require("programs")
local mainMod = "SUPER"

local function exec(cmd)
    return hl.dsp.exec_cmd(cmd)
end

hl.bind(mainMod .. " + T", exec(programs.terminal))
hl.bind(mainMod .. " + Q", exec("/home/blox/.local/bin/ktr killactive"))
hl.bind(mainMod .. " + L", exec("~/.config/quickshell/blox/scripts/power/safe.sh lock"))
hl.bind(mainMod .. " + E", exec(programs.file_manager))
hl.bind(mainMod .. " + F", hl.dsp.window.float())
hl.bind(mainMod .. " + M", exec("kitty --class micro-active -e micro"))
hl.bind(mainMod .. " + space", exec(programs.menu))
hl.bind(mainMod .. " + N", exec("swaync-client -t -sw"))
hl.bind(mainMod .. " + SHIFT + O", exec("~/.config/hypr/scripts/toggle-orca.sh"))
hl.bind(mainMod .. " + P", hl.dsp.window.pseudo())
hl.bind(mainMod .. " + J", hl.dsp.layout("togglesplit"))

-- Move focus with mainMod + arrow keys.
hl.bind(mainMod .. " + left", hl.dsp.focus({ direction = "l" }))
hl.bind(mainMod .. " + right", hl.dsp.focus({ direction = "r" }))
hl.bind(mainMod .. " + up", hl.dsp.focus({ direction = "u" }))
hl.bind(mainMod .. " + down", hl.dsp.focus({ direction = "d" }))

-- Switch workspaces with mainMod + [0-9].
for key = 1, 9 do
    hl.bind(mainMod .. " + " .. key, hl.dsp.focus({ workspace = tostring(key) }))
end
hl.bind(mainMod .. " + 0", hl.dsp.focus({ workspace = "10" }))

-- Move active window to a workspace with mainMod + SHIFT + [0-9].
for key = 1, 9 do
    hl.bind(mainMod .. " + SHIFT + " .. key, hl.dsp.window.move({ workspace = tostring(key) }))
end
hl.bind(mainMod .. " + SHIFT + 0", hl.dsp.window.move({ workspace = "10" }))

-- Special workspace.
hl.bind(mainMod .. " + grave", hl.dsp.workspace.toggle_special("magic"))
hl.bind(mainMod .. " + SHIFT + grave", hl.dsp.window.move({ workspace = "special:magic" }))

-- DP-1 workspaces.
for index = 1, 10 do
    local key = "F" .. index
    local workspace = tostring(index + 10)
    hl.bind(mainMod .. " + " .. key, hl.dsp.focus({ workspace = workspace }))
    hl.bind(mainMod .. " + SHIFT + " .. key, hl.dsp.window.move({ workspace = workspace }))
end

-- HDMI-A-1 workspaces.
hl.bind(mainMod .. " + F11", hl.dsp.focus({ workspace = "21" }))
hl.bind(mainMod .. " + F12", hl.dsp.focus({ workspace = "22" }))
hl.bind(mainMod .. " + SHIFT + F11", hl.dsp.window.move({ workspace = "21" }))
hl.bind(mainMod .. " + SHIFT + F12", hl.dsp.window.move({ workspace = "22" }))

-- Scroll through existing workspaces with mainMod + scroll.
hl.bind(mainMod .. " + mouse_down", hl.dsp.focus({ workspace = "e+1" }))
hl.bind(mainMod .. " + mouse_up", hl.dsp.focus({ workspace = "e-1" }))

-- Tab through existing workspaces with mainMod + tab.
hl.bind(mainMod .. " + SHIFT + Tab", hl.dsp.focus({ workspace = "m-1" }), { repeating = true })
hl.bind(mainMod .. " + Tab", hl.dsp.focus({ workspace = "m+1" }), { repeating = true })

-- Move/resize windows with mainMod + LMB/RMB and dragging.
hl.bind(mainMod .. " + mouse:272", hl.dsp.window.drag(), { mouse = true })
hl.bind(mainMod .. " + mouse:273", hl.dsp.window.resize(), { mouse = true })

-- Laptop multimedia keys for volume and LCD brightness.
hl.bind("XF86AudioRaiseVolume", exec("~/.config/quickshell/blox/scripts/osd/control.sh volume-up 2"), { repeating = true, locked = true })
hl.bind("XF86AudioLowerVolume", exec("~/.config/quickshell/blox/scripts/osd/control.sh volume-down 2"), { repeating = true, locked = true })
hl.bind("XF86AudioMute", exec("~/.config/quickshell/blox/scripts/osd/control.sh volume-mute"), { repeating = true, locked = true })
hl.bind("XF86AudioMicMute", exec("~/.config/quickshell/blox/scripts/osd/control.sh mic-mute"), { repeating = true, locked = true })
hl.bind("XF86MonBrightnessUp", exec("~/.config/quickshell/blox/scripts/osd/control.sh brightness-up 2"), { repeating = true, locked = true })
hl.bind("XF86MonBrightnessDown", exec("~/.config/quickshell/blox/scripts/osd/control.sh brightness-down 2"), { repeating = true, locked = true })
hl.bind("XF86KbdBrightnessUp", exec("~/.config/quickshell/blox/scripts/osd/control.sh keyboard-up 1"), { repeating = true, locked = true })
hl.bind("XF86KbdBrightnessDown", exec("~/.config/quickshell/blox/scripts/osd/control.sh keyboard-down 1"), { repeating = true, locked = true })
hl.bind("XF86KbdLightOnOff", exec("~/.config/quickshell/blox/scripts/osd/control.sh keyboard-toggle"), { repeating = true, locked = true })
hl.bind("Caps_Lock", exec("~/.config/quickshell/blox/scripts/osd/control.sh caps"), { locked = true })
hl.bind("XF86WebCam", exec("~/.config/quickshell/blox/scripts/osd/control.sh camera-toggle"), { locked = true })
hl.bind("XF86TouchpadToggle", exec("~/.config/quickshell/blox/scripts/osd/control.sh touchpad-toggle"), { locked = true })
hl.bind("XF86PowerOff", exec("quickshell ipc -c blox call power toggle"), { locked = true })

-- Requires playerctl.
hl.bind("XF86AudioNext", exec("playerctl next"), { locked = true })
hl.bind("XF86AudioPause", exec("playerctl play-pause"), { locked = true })
hl.bind("XF86AudioPlay", exec("playerctl play-pause"), { locked = true })
hl.bind("XF86AudioPrev", exec("playerctl previous"), { locked = true })
hl.bind("XF86Launch1", exec([[bash -c 'pgrep -x slurp >/dev/null && pkill -x slurp || ~/.config/hypr/scripts/ocr-region-to-clipboard.sh']]), { locked = true })

-- Numpad / key to play/pause music.
hl.bind("KP_Divide", exec("playerctl play-pause"), { locked = true })

-- Numpad * key for F13.
hl.bind("KP_Multiply", hl.dsp.send_shortcut({ mods = "", key = "F13", window = "activewindow" }), { repeating = true })

-- Numpad + - for ctrl tab.
hl.bind("KP_Subtract", hl.dsp.send_shortcut({ mods = "CONTROL", key = "TAB", window = "activewindow" }), { repeating = true })
hl.bind("KP_Add", hl.dsp.send_shortcut({ mods = "CONTROL SHIFT", key = "TAB", window = "activewindow" }), { repeating = true })

-- Screenshot region capture.
hl.bind("Print", exec("hyprshot -m output"))
hl.bind(mainMod .. " + SHIFT + S", exec([[bash -c 'pgrep -x slurp >/dev/null && pkill -x slurp || hyprshot -m region']]))
hl.bind(mainMod .. " + ALT + S", exec([[bash -c 'pgrep -x slurp >/dev/null && pkill -x slurp || hyprshot -m region --freeze --cursor']]))
hl.bind(mainMod .. " + SHIFT + T", exec("~/.config/hypr/scripts/ocr-region-to-clipboard.sh"))

-- Colour picker toggle.
hl.bind(mainMod .. " + SHIFT + C", exec([[bash -c 'pgrep -x hyprpicker >/dev/null && pkill -x hyprpicker || hyprpicker -a &']]))

-- Clipboard manager toggle.
hl.bind(mainMod .. " + V", exec([[vicinae deeplink 'vicinae://launch/clipboard/history']]))

-- Toggle bar.
hl.bind(mainMod .. " + backslash", exec("quickshell ipc -c blox call bar toggle"))

-- Emoji picker.
hl.bind(mainMod .. " + period", exec([[vicinae deeplink 'vicinae://launch/core/search-emojis']]))
