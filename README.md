# mouse-follows-focus

A tiny [Hammerspoon](https://www.hammerspoon.org/) config that keeps your **mouse pointer with your keyboard focus**. Whenever a window becomes focused — via `Cmd+Tab`, a click, Mission Control, a hotkey, or an app opening a new window — the pointer jumps to the center of that window.

The name is the deliberate inverse of X11's *focus follows mouse*: here focus leads, and the mouse follows it.

## Why

macOS decouples the mouse pointer from window focus. Switch apps with `Cmd+Tab` and the pointer stays wherever you left it, often on a different display entirely. Then you scroll, and the wrong window scrolls — because macOS delivers scroll events to the window *under the pointer*, not the focused one.

This config removes that gap:

- Scroll wheel and trackpad gestures always hit the window you're actually working in.
- Hover-dependent UI (tooltips, hover toolbars, editor gutters) reacts in the right window.
- On multi-monitor setups, the pointer follows you to the display you switched to instead of getting lost.

## How it works

The entire implementation is 14 lines (`init.lua`):

```lua
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
```

1. `hs.window.filter.new()` creates a copy of Hammerspoon's **default window filter** — it tracks standard, visible windows of non-hidden apps. Utility panels, floating palettes, and hidden apps are excluded, so the pointer isn't yanked around by transient UI.
2. `subscribe(windowFocused, ...)` fires the callback every time a tracked window takes focus.
3. `window:frame()` returns the window rect in **global screen coordinates** (origin at the top-left of the primary display, extending across all displays). Adding half the width and height gives the window's center point.
4. `hs.mouse.absolutePosition()` moves the pointer there instantly — no animation, no synthetic click, no interference with dragging.
5. The alert confirms the config loaded, which is useful feedback after every reload.

## Requirements

| | |
|---|---|
| **OS** | macOS 10.12+ (Hammerspoon's minimum; any modern macOS works) |
| **Hammerspoon** | Any recent version |
| **Permissions** | Accessibility access for Hammerspoon |
| **Hardware** | Nothing special — works with one display or many |

## Quick start

**1. Install Hammerspoon**

```sh
brew install --cask hammerspoon
```

Or download the `.zip` from [hammerspoon.org](https://www.hammerspoon.org/) and drag `Hammerspoon.app` into `/Applications`.

**2. Launch it and grant Accessibility access**

Open Hammerspoon. It will prompt for Accessibility permission — this is required, since moving the pointer and observing other apps' windows are both privileged operations. If you miss the prompt:

> System Settings → Privacy & Security → Accessibility → enable **Hammerspoon**

**3. Install the config**

Back up anything already there, then copy `init.lua` into place:

```sh
# from the repo directory
cp ~/.hammerspoon/init.lua ~/.hammerspoon/init.lua.bak 2>/dev/null
cp init.lua ~/.hammerspoon/init.lua
```

Prefer a symlink if you want to keep editing the file in this repo and have changes tracked in git:

```sh
ln -sf "$PWD/init.lua" ~/.hammerspoon/init.lua
```

**4. Reload**

Click the Hammerspoon menu bar icon → **Reload Config**. You should see the `Hammerspoon Loaded` alert.

**5. Test it**

`Cmd+Tab` between two apps. The pointer should snap to the center of each window as it takes focus.

**6. (Optional) Start at login**

Hammerspoon menu bar icon → **Preferences** → check **Launch Hammerspoon at login**. Without this, the config only runs while Hammerspoon is open.

## Adding it to an existing config

If you already have a `~/.hammerspoon/init.lua`, don't overwrite it. Either paste the `wf:subscribe(...)` block into your config, or drop this file in as a module:

```sh
cp init.lua ~/.hammerspoon/mouse_follows_focus.lua
```

Then in your own `init.lua`:

```lua
require("mouse_follows_focus")
```

Remove the `hs.alert.show("Hammerspoon Loaded")` line from the module if your main config already announces itself.

## Customization

All snippets below replace or extend the callback in `init.lua`. Reload the config after each change.

### Keep a persistent reference to the window filter

Hammerspoon garbage-collects window filters that nothing holds a reference to. `local wf` at file scope survives as long as the config is loaded, which is why the current code works — but if you move this into a function, promote it to a global (`wf = ...`) or store it in a table so it isn't collected.

### Only follow specific apps

Pass a list of app names to the filter instead of using the default:

```lua
local wf = hs.window.filter.new({"Cursor", "Code", "iTerm2", "Ghostty"})
```

### Follow everything *except* certain apps

```lua
local wf = hs.window.filter.new()
wf:setAppFilter("Figma", false)   -- never move the pointer for Figma
wf:setAppFilter("Photoshop", false)
```

Useful for apps where pointer position is part of the interaction (design tools, games, remote desktop clients).

### Don't move the pointer if it's already inside the window

Avoids a jarring jump when you focus a window by clicking it:

```lua
wf:subscribe(hs.window.filter.windowFocused, function(window)
    if not window then return end

    local frame = window:frame()
    local pos = hs.mouse.absolutePosition()

    if hs.geometry.point(pos):inside(frame) then return end

    hs.mouse.absolutePosition({
        x = frame.x + frame.w / 2,
        y = frame.y + frame.h / 2
    })
end)
```

### Aim somewhere other than the center

Center is a safe default, but it can land on a button or a link. To target, say, 25% down from the top:

```lua
hs.mouse.absolutePosition({
    x = frame.x + frame.w / 2,
    y = frame.y + frame.h * 0.25
})
```

Or nudge into the top-left quadrant, well away from most controls:

```lua
hs.mouse.absolutePosition({
    x = frame.x + 80,
    y = frame.y + 80
})
```

### Only move when focus changes displays

Keeps the pointer put during same-screen switches, and only recenters when you cross monitors:

```lua
wf:subscribe(hs.window.filter.windowFocused, function(window)
    if not window then return end

    local winScreen = window:screen()
    local mouseScreen = hs.mouse.getCurrentScreen()

    if mouseScreen and winScreen and mouseScreen:id() == winScreen:id() then
        return
    end

    local frame = window:frame()
    hs.mouse.absolutePosition({
        x = frame.x + frame.w / 2,
        y = frame.y + frame.h / 2
    })
end)
```

### Add a toggle hotkey

Turn the behavior off temporarily without unloading Hammerspoon:

```lua
local enabled = true

hs.hotkey.bind({"cmd", "alt", "ctrl"}, "M", function()
    enabled = not enabled
    hs.alert.show("mouse-follows-focus: " .. (enabled and "ON" or "OFF"))
end)

wf:subscribe(hs.window.filter.windowFocused, function(window)
    if not enabled or not window then return end

    local frame = window:frame()
    hs.mouse.absolutePosition({
        x = frame.x + frame.w / 2,
        y = frame.y + frame.h / 2
    })
end)
```

### Remove the startup alert

Delete the last line, or replace it with a quieter notification:

```lua
hs.alert.show("mouse-follows-focus ready", 0.5)   -- auto-dismisses in half a second
```

## Troubleshooting

**Nothing happens on window switch**

Check Accessibility permission first — it's the cause in most cases. In System Settings → Privacy & Security → Accessibility, toggle Hammerspoon **off and back on**, then quit and relaunch Hammerspoon. macOS silently invalidates the grant after app updates.

**No "Hammerspoon Loaded" alert on reload**

The config has a syntax error or isn't where Hammerspoon expects it. Open the Hammerspoon Console (menu bar icon → **Console**) and look for a red error. Confirm the file is at `~/.hammerspoon/init.lua`:

```sh
ls -l ~/.hammerspoon/init.lua
```

**Works for some apps but not others**

The default window filter ignores non-standard windows — panels, sheets, and windows belonging to hidden apps. Some Electron and Java apps report unusual window roles. Inspect what's actually being tracked from the Console:

```lua
hs.window.focusedWindow():subrole()
hs.window.focusedWindow():isStandard()
```

If a window reports `isStandard() == false`, override the filter for that app:

```lua
wf:setAppFilter("TheApp", { allowRoles = "*" })
```

**Pointer jumps while I'm dragging something**

Focus changes mid-drag are rare but possible. Use the "don't move if already inside" variant above, or add an app filter exclusion for the app where it happens.

**Pointer lands on the wrong monitor**

`window:frame()` uses global coordinates, so this should not occur. If it does, a display arrangement change may have gone unnoticed by a stale filter — reload the config. For a permanent fix, re-subscribe on screen changes:

```lua
hs.screen.watcher.new(function() hs.reload() end):start()
```

**Config doesn't run after a reboot**

Hammerspoon isn't set to launch at login. Enable it in Hammerspoon → Preferences.

## Uninstall

```sh
rm ~/.hammerspoon/init.lua
# restore your previous config if you backed one up
mv ~/.hammerspoon/init.lua.bak ~/.hammerspoon/init.lua 2>/dev/null
```

Reload the config (or quit Hammerspoon) to stop the behavior immediately. To remove Hammerspoon entirely:

```sh
brew uninstall --cask hammerspoon
rm -rf ~/.hammerspoon
```

## Repository layout

```
.
├── init.lua     # the entire implementation
└── README.md
```

## Reference

- [Hammerspoon API docs](https://www.hammerspoon.org/docs/)
- [`hs.window.filter`](https://www.hammerspoon.org/docs/hs.window.filter.html) — window tracking and event subscription
- [`hs.mouse`](https://www.hammerspoon.org/docs/hs.mouse.html) — pointer position
- [`hs.geometry`](https://www.hammerspoon.org/docs/hs.geometry.html) — points, rects, and containment checks
- [Getting Started with Hammerspoon](https://www.hammerspoon.org/go/) — the official Lua config primer
