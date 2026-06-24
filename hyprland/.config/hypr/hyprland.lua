-- Main Hyprland entrypoint. Keep module order intentional:
-- hardware before monitors, environment before autostart, programs before binds,
-- rules after layout variables.

local function script_dir()
    local source = debug and debug.getinfo and debug.getinfo(1, "S").source or ""
    return source:match("^@(.+)/[^/]+$")
end

local function add_module_paths(root)
    if not root or root == "" then
        return
    end

    package.path = root .. "/?.lua;" .. root .. "/conf.d/?.lua;" .. package.path
end

add_module_paths(script_dir())

local config_home = os.getenv("XDG_CONFIG_HOME") or (os.getenv("HOME") and os.getenv("HOME") .. "/.config")
add_module_paths(config_home and config_home .. "/hypr")

require("hardware")
require("monitors")
require("environment")
require("autostart")
require("permissions")
require("appearance")
require("input")
require("binds")
require("rules")
require("window-routing")
