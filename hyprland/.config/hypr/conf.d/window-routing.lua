local function window_class(window)
    return ((window and (window.class or window.initial_class)) or ""):lower()
end

local function is_code_window(window)
    return window_class(window) == "code"
end

local function idea_open()
    for _, window in ipairs(hl.get_windows()) do
        if window_class(window):find("jetbrains%-idea") then
            return true
        end
    end

    return false
end

hl.on("window.open", function(window)
    if not is_code_window(window) or window.floating then
        return
    end

    local target_workspace = idea_open() and "4" or "2"
    hl.dispatch(hl.dsp.window.move({
        workspace = target_workspace,
        follow = false,
        window = window,
    }))
end)
