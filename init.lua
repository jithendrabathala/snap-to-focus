local wf = hs.window.filter.new()

wf:subscribe(hs.window.filter.windowFocused, function(window)
    if not window then return end

    local frame = window:frame()

    hs.mouse.absolutePosition({
        x = frame.x + frame.w / 2,
        y = frame.y + frame.h / 2
    })
end)

hs.alert.show("Hammerspoon Loaded")
