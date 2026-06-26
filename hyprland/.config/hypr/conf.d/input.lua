hl.config({
    input = {
        kb_layout = "gb",
        kb_variant = "",
        kb_model = "",
        kb_options = "fkeys:basic_13-24",
        kb_rules = "",

        follow_mouse = 1,
        sensitivity = 0,

        touchpad = {
            natural_scroll = false,
            disable_while_typing = false,
            scroll_factor = 0.4,
        },
    },

    gestures = {
        workspace_swipe_invert = false,
    },
})

hl.gesture({ fingers = 3, direction = "horizontal", action = "workspace" })
hl.gesture({ fingers = 3, direction = "up", action = "special", workspace_name = "magic" })
hl.gesture({
    fingers = 3,
    direction = "down",
    action = function()
        hl.exec_cmd("quickshell ipc -c blox call notifications toggle")
    end,
})

hl.device({
    name = "epic-mouse-v1",
    sensitivity = -0.5,
})
