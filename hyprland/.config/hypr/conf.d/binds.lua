local programs = require("programs")
local mainMod = "SUPER"

local function exec(cmd)
    return hl.dsp.exec_cmd(cmd)
end

local function shortcut_guide(action)
    hl.dispatch(exec("~/.config/quickshell/blox/scripts/ipc.sh shortcutGuide " .. action))
end

local shortcut_guide_cursor
local shortcut_guide_cursor_timer = hl.timer(function()
    local cursor = hl.get_cursor_pos()
    if cursor and shortcut_guide_cursor
        and (cursor.x ~= shortcut_guide_cursor.x or cursor.y ~= shortcut_guide_cursor.y) then
        shortcut_guide("delay")
    end
    shortcut_guide_cursor = cursor
end, { timeout = 50, type = "repeat" })
shortcut_guide_cursor_timer:set_enabled(false)

local function super_bind(keys, action, options)
    hl.bind(mainMod .. " + " .. keys, function()
        shortcut_guide("cancel")
        if type(action) == "function" then
            action()
        else
            hl.dispatch(action)
        end
    end, options)
end

-- Keep the Super bind list mirrored in Quickshell's ShortcutGuideWindow.qml.
local function resize_active_width(ratio)
    return function()
        local window = hl.get_active_window()
        local monitor = window and window.monitor
        if not monitor then
            return
        end

        local workspace = window.workspace
        if not window.floating and workspace and workspace.tiled_layout == "master" then
            local window_centre = window.at.x + (window.size.x / 2)
            local monitor_centre = monitor.x + (monitor.width / 2)
            local master_ratio = window_centre < monitor_centre and ratio or (1 - ratio)

            hl.dispatch(hl.dsp.layout(string.format("mfact exact %.2f", master_ratio)))
            return
        end

        hl.dispatch(hl.dsp.window.resize({
            x = math.floor(monitor.width * ratio),
            y = window.size.y,
            window = window,
        }))
    end
end

local function adjust_active_width(delta)
    return function()
        local window = hl.get_active_window()
        local monitor = window and window.monitor
        if not monitor then
            return
        end

        local workspace = window.workspace
        if not window.floating and workspace and workspace.tiled_layout == "master" then
            local window_centre = window.at.x + (window.size.x / 2)
            local monitor_centre = monitor.x + (monitor.width / 2)
            local master_delta = window_centre < monitor_centre and delta or -delta

            hl.dispatch(hl.dsp.layout(string.format("mfact %+.2f", master_delta)))
            return
        end

        local current_ratio = window.size.x / monitor.width
        local target_ratio = math.max(0.05, math.min(1, current_ratio + delta))
        hl.dispatch(hl.dsp.window.resize({
            x = math.floor(monitor.width * target_ratio),
            y = window.size.y,
            window = window,
        }))
    end
end

local function toggle_active_pin()
    return function()
        local window = hl.get_active_window()
        if not window then
            return
        end

        if window.pinned then
            hl.dispatch(hl.dsp.window.pin({ action = "disable", window = window }))
            hl.dispatch(hl.dsp.window.float({ action = "disable", window = window }))
            return
        end

        if not window.floating then
            hl.dispatch(hl.dsp.window.float({ action = "set", window = window }))
        end

        hl.dispatch(hl.dsp.window.pin({ action = "enable", window = window }))
    end
end

local function swap_active_with_master()
    local active = hl.get_active_window()
    local monitor = active and active.monitor
    local workspace = active and active.workspace
    if not monitor or not workspace or active.floating or workspace.tiled_layout ~= "master" then
        return
    end

    local active_centre = active.at.x + (active.size.x / 2)
    local monitor_centre = monitor.x + (monitor.width / 2)
    if active_centre >= monitor_centre then
        hl.dispatch(hl.dsp.layout("swapwithmaster auto"))
        return
    end

    local largest
    local largest_area = -1
    for _, window in ipairs(hl.get_workspace_windows(workspace)) do
        local area = window.size.x * window.size.y
        if not window.floating and window.stable_id ~= active.stable_id and area > largest_area then
            largest = window
            largest_area = area
        end
    end

    if largest then
        hl.dispatch(hl.dsp.window.swap({ target = largest, window = active }))
    end
end

for _, key in ipairs({ "SUPER_L", "SUPER_R" }) do
    hl.bind(key, function()
        shortcut_guide_cursor = hl.get_cursor_pos()
        shortcut_guide_cursor_timer:set_enabled(true)
        shortcut_guide("arm")
    end, { non_consuming = true, transparent = true, ignore_mods = true })
    hl.bind(mainMod .. " + " .. key, function()
        shortcut_guide_cursor_timer:set_enabled(false)
        shortcut_guide_cursor = nil
        shortcut_guide("release")
    end, { release = true, non_consuming = true, transparent = true })
end

hl.bind("Escape", function()
    shortcut_guide("close")
end, { non_consuming = true, transparent = true, ignore_mods = true })

hl.bind(mainMod .. " + SHIFT + slash", function()
    shortcut_guide("toggle")
end)

super_bind("T", exec(programs.terminal))
super_bind("Q", exec("/home/blox/.local/bin/ktr killactive"))
super_bind("L", exec("~/.config/quickshell/blox/scripts/power/safe.sh lock"))
super_bind("E", exec(programs.file_manager))
super_bind("M", exec("kitty --class micro-active -e /home/blox/.local/bin/micro"))
super_bind("space", exec(programs.menu))
super_bind("N", exec("~/.config/quickshell/blox/scripts/ipc.sh notifications toggle"))
super_bind("SHIFT + O", exec("~/.config/hypr/scripts/toggle-orca.sh"))

-- Move focus with mainMod + arrow keys.
super_bind("left", hl.dsp.focus({ direction = "l" }))
super_bind("right", hl.dsp.focus({ direction = "r" }))
super_bind("up", hl.dsp.focus({ direction = "u" }))
super_bind("down", hl.dsp.focus({ direction = "d" }))

-- Move the active window with mainMod + SHIFT + arrow keys.
super_bind("SHIFT + left", hl.dsp.window.move({ direction = "l" }))
super_bind("SHIFT + right", hl.dsp.window.move({ direction = "r" }))
super_bind("SHIFT + up", hl.dsp.window.move({ direction = "u" }))
super_bind("SHIFT + down", hl.dsp.window.move({ direction = "d" }))

-- Switch workspaces with mainMod + [0-9].
for key = 1, 9 do
    super_bind(tostring(key), hl.dsp.focus({ workspace = tostring(key) }))
end
super_bind("0", hl.dsp.focus({ workspace = "10" }))

-- Move active window to a workspace with mainMod + SHIFT + [0-9].
for key = 1, 9 do
    super_bind("SHIFT + " .. key, hl.dsp.window.move({ workspace = tostring(key) }))
end
super_bind("SHIFT + 0", hl.dsp.window.move({ workspace = "10" }))

-- Special workspace.
super_bind("grave", hl.dsp.workspace.toggle_special("magic"))
super_bind("SHIFT + grave", hl.dsp.window.move({ workspace = "special:magic" }))

-- DP-1 workspaces.
for index = 1, 10 do
    local key = "F" .. index
    local workspace = tostring(index + 10)
    super_bind(key, hl.dsp.focus({ workspace = workspace }))
    super_bind("SHIFT + " .. key, hl.dsp.window.move({ workspace = workspace }))
end

-- HDMI-A-1 workspaces.
super_bind("F11", hl.dsp.focus({ workspace = "21" }))
super_bind("F12", hl.dsp.focus({ workspace = "22" }))
super_bind("SHIFT + F11", hl.dsp.window.move({ workspace = "21" }))
super_bind("SHIFT + F12", hl.dsp.window.move({ workspace = "22" }))

-- Scroll through existing workspaces with mainMod + scroll.
super_bind("mouse_down", hl.dsp.focus({ workspace = "e+1" }))
super_bind("mouse_up", hl.dsp.focus({ workspace = "e-1" }))

-- Tab through existing workspaces with mainMod + tab.
super_bind("SHIFT + Tab", hl.dsp.focus({ workspace = "m-1" }), { repeating = true })
super_bind("Tab", hl.dsp.focus({ workspace = "m+1" }), { repeating = true })

-- Move/resize windows with mainMod + LMB/RMB and dragging.
hl.bind(mainMod .. " + mouse:272", function()
    shortcut_guide("cancel")
end, { non_consuming = true, transparent = true })
hl.bind(mainMod .. " + mouse:273", function()
    shortcut_guide("cancel")
end, { non_consuming = true, transparent = true })
hl.bind(mainMod .. " + mouse:272", hl.dsp.window.drag(), { mouse = true })
hl.bind(mainMod .. " + mouse:273", hl.dsp.window.resize(), { mouse = true })

-- Let Quickshell dismiss native picker windows only for real outside clicks.
hl.bind("mouse:272", hl.dsp.event("blox-picker-click"), { click = true, non_consuming = true })
hl.bind("mouse:273", hl.dsp.event("blox-picker-click"), { click = true, non_consuming = true })
hl.bind("mouse:274", hl.dsp.event("blox-picker-click"), { click = true, non_consuming = true })

-- Resize the active window to a percentage of its monitor width.
super_bind("code:87", resize_active_width(0.70))
super_bind("code:88", resize_active_width(0.50))
super_bind("code:89", resize_active_width(0.30))
super_bind("code:83", adjust_active_width(0.05), { repeating = true })
super_bind("code:85", adjust_active_width(-0.05), { repeating = true })
super_bind("code:90", toggle_active_pin())
super_bind("code:84", swap_active_with_master)
super_bind("code:79", hl.dsp.window.float({ action = "toggle" }))
super_bind("code:80", hl.dsp.window.fullscreen({ mode = "maximized", action = "toggle" }))
super_bind("code:81", hl.dsp.window.fullscreen({ mode = "fullscreen", action = "toggle" }))

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
hl.bind("XF86TouchpadOn", exec("~/.config/quickshell/blox/scripts/osd/control.sh touchpad-on"), { locked = true })
hl.bind("XF86TouchpadOff", exec("~/.config/quickshell/blox/scripts/osd/control.sh touchpad-off"), { locked = true })
hl.bind("XF86PowerOff", exec("~/.config/quickshell/blox/scripts/ipc.sh power toggle"), { locked = true })

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
super_bind("SHIFT + S", exec([[bash -c 'pgrep -x slurp >/dev/null && pkill -x slurp || hyprshot -m region']]))
super_bind("ALT + S", exec([[bash -c 'pgrep -x slurp >/dev/null && pkill -x slurp || hyprshot -m region --freeze --cursor']]))
super_bind("SHIFT + T", exec("~/.config/hypr/scripts/ocr-region-to-clipboard.sh"))

-- Colour picker toggle.
super_bind("SHIFT + C", exec([[bash -c 'pgrep -x hyprpicker >/dev/null && pkill -x hyprpicker || hyprpicker -a &']]))

-- Clipboard manager toggle.
super_bind("V", exec("~/.config/quickshell/blox/scripts/ipc.sh launcher clipboard"))

-- Toggle bar.
super_bind("backslash", exec("~/.config/quickshell/blox/scripts/ipc.sh bar toggle"))

-- Emoji picker.
super_bind("period", exec("~/.config/quickshell/blox/scripts/ipc.sh launcher emoji"))
