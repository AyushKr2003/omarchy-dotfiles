-- ╭─────────────────────────────────────────────────────────────────────────╮
-- │  Custom bindings — loaded after omarchy defaults.                       │
-- │  Uses helpers from default/hypr/helpers.lua:                            │
-- │    o.bind(keys, description, dispatcher, opts?)                         │
-- │    o.launch(cmd)                  → "uwsm-app -- cmd"                   │
-- │    o.launch_sole(match, cmd)      → focus if open, else launch          │
-- │    o.launch_webapp(url)           → omarchy-launch-webapp               │
-- │    o.launch_webapp_sole(n,url)    → focus webapp if open                │
-- │    o.bind_toggle(keys,desc,t)     → omarchy-toggle-<t>                  │
-- │    { omarchy = "x" }              → omarchy-launch-x (handles uwsm-app) │
-- │    { launch = "x" }               → uwsm-app -- x                       │
-- │    { tui = "x" }                  → omarchy-launch-tui 'x'              │
-- │    { webapp = "url" }             → omarchy-launch-webapp               │
-- │    { webapp = "url", focus=true } → focus or launch                     │
-- ╰─────────────────────────────────────────────────────────────────────────╯

-- ── 1. Terminals & Editors ───────────────────────────────────────────────────

hl.unbind("SUPER + RETURN")
o.bind("SUPER + RETURN", "Tmux (Work)", { launch = "omarchy-launch-terminal-tmux" })


hl.unbind("SUPER + T")
o.bind("SUPER + T", "Terminal", { omarchy = "terminal" })

hl.unbind("SUPER + SHIFT + T")
o.bind("SUPER + SHIFT + T", "Floating Terminal", { launch = "omarchy-launch-float-terminal" })

hl.unbind("SUPER + ALT + T")
o.bind("SUPER + ALT + T", "TypeTUI", { launch = "omarchy-launch-float-terminal typetui" })

hl.unbind("SUPER + CTRL + L")
o.bind("SUPER + CTRL + L", "Terminal Launcher", { launch = "omarchy-launch-float-terminal a -a" })

o.bind("SUPER + PAUSE", "Full System Info", hl.dsp.exec_cmd("xdg-terminal-exec fish -c full_sys", { float = true, size = "1220 680" }))
o.bind("SUPER + KP_Prior", "Full System Info", hl.dsp.exec_cmd("xdg-terminal-exec fish -c full_sys", { float = true, size = "1220 680" }))

hl.unbind("SUPER + SHIFT + N")
o.bind("SUPER + SHIFT + N", "VS Code", { launch = "code" })


-- ── 2. Browsers & Web Applications ──────────────────────────────────────────

hl.unbind("SUPER + W")
o.bind("SUPER + W", "Default Browser", { omarchy = "browser" })

hl.unbind("SUPER + ALT + B")
o.bind("SUPER + ALT + B", "QuteBrowser", { launch = "qutebrowser" })

hl.unbind("SUPER + B")
o.bind("SUPER + B", "Zen Browser", { launch = "zen-browser" })

hl.unbind("SUPER + SHIFT + B")
o.bind("SUPER + SHIFT + B", "QuteBrowser (Private)", { launch = "bash -c 'qutebrowser --basedir /tmp/qb-private-$(date +%s) --config $HOME/.config/qutebrowser/private.py --target window'" })

hl.unbind("SUPER + SHIFT + W")
o.bind("SUPER + SHIFT + W", "WhatsApp Web", { webapp = "https://web.whatsapp.com/", focus = true })


-- ── 3. File Managers ────────────────────────────────────────────────────────

o.bind("SUPER + E", "Nautilus File Manager", { omarchy = "nautilus" })

o.bind("SUPER + ALT + E", "File manager (cwd)", { omarchy = "nautilus-cwd" })

hl.unbind("SUPER + SHIFT + E")
o.bind("SUPER + SHIFT + E", "Superfile (TUI)", { launch = "omarchy-launch-float-terminal spf" })


-- ── 4. Window Management & Workspaces ───────────────────────────────────────

hl.unbind("SUPER + Q")
o.bind("SUPER + Q", "Close window", hl.dsp.window.close())

o.bind("SUPER + SHIFT + Q", "Force kill window", hl.dsp.exec_cmd("hyprctl kill"))

hl.unbind("SUPER + Z")
o.bind("SUPER + Z", "Resize window", hl.dsp.window.resize(), { mouse = true })

hl.unbind("SUPER + SHIFT + O")
o.bind("SUPER + SHIFT + O", "Toggle floating / tiling", hl.dsp.window.float({ action = "toggle" }))

hl.unbind("SUPER + L")
o.bind("SUPER + L", "Lock system", "omarchy-system-lock")

-- o.bind("SUPER + CTRL + RIGHT", "Next workspace", hl.dsp.focus({ workspace = "e+1" }))
-- o.bind("SUPER + CTRL + LEFT", "Previous workspace", hl.dsp.focus({ workspace = "e-1" }))
--

-- ===== Smart next/prev workspace (skip repeated empty workspaces) =====
local TOTAL_WORKSPACES = 10

local function wrap_id(n)
    return ((n - 1) % TOTAL_WORKSPACES) + 1
end

local function occupied_set()
    local occ = {}
    local workspaces = hl.get_workspaces()
    if workspaces ~= nil then
        for _, ws in ipairs(workspaces) do
            if ws ~= nil and ws.id ~= nil and ws.windows ~= nil and ws.windows > 0 then
                occ[ws.id] = true
            end
        end
    end
    return occ
end

local function next_workspace(direction)
    local cur = hl.get_active_workspace()
    if cur == nil or cur.id == nil then
        return nil
    end

    local occ = occupied_set()
    local pos = wrap_id(cur.id + direction)

    if occ[cur.id] then
        return pos
    else
        local steps = 0
        while not occ[pos] and steps < TOTAL_WORKSPACES do
            pos = wrap_id(pos + direction)
            steps = steps + 1
        end
        return pos
    end
end

_G.SmartWorkspace = { next = next_workspace }

o.bind("SUPER + CTRL + RIGHT", "Next workspace",
    function()
        local target = next_workspace(1)
        if target ~= nil then
            hl.dispatch(hl.dsp.focus({ workspace = tostring(target) }))
        end
    end)

o.bind("SUPER + CTRL + LEFT", "Previous workspace",
    function()
        local target = next_workspace(-1)
        if target ~= nil then
            hl.dispatch(hl.dsp.focus({ workspace = tostring(target) }))
        end
    end)


hl.unbind("SUPER + S")
o.bind("SUPER + S", "Toggle scratchpad", hl.dsp.workspace.toggle_special("scratch"))
hl.unbind("SUPER + SHIFT + S")
o.bind("SUPER + SHIFT + S", "Move window to scratchpad", hl.dsp.window.move({ workspace = "special:scratch", follow = false }))

-- ── 5. Shell Plugins & Custom Menus ─────────────────────────────────────────

hl.unbind("SUPER + TAB")
o.bind("SUPER + TAB", "Overview", "omarchy-shell shell toggle omarchy-overview")

hl.unbind("SUPER + I")
o.bind("SUPER + I", "Omarchy Settings", "omarchy-shell shell summon shell.settings")

hl.unbind("SUPER + M")
o.bind("SUPER + M", "Manga Reader", "omarchy-shell shell toggle local.manga")

hl.unbind("SUPER + ALT + S")
o.bind("SUPER + ALT + S", "Shaders", "omarchy-menu-shaders")

hl.unbind("SUPER + SHIFT + M")
o.bind("SUPER + SHIFT + M", "Omarchy Manual", "omarchy-shell shell toggle omarchy.manual")

-- ── 6. Hardware & Mouse Controls ────────────────────────────────────────────

o.bind("SUPER + Prior", "Brightness +5%", "omarchy-brightness-display +5%", { locked = true, repeating = true })
o.bind("SUPER + Next", "Brightness -5%", "omarchy-brightness-display 5%-", { locked = true, repeating = true })

o.bind("mouse:275", "Orbit Press", "~/.config/omarchy/plugins/local.orbit/scripts/orbit-press.sh --button 275", { locked = true })
o.bind("mouse:275", "Orbit Release", "~/.config/omarchy/plugins/local.orbit/scripts/orbit-release.sh", { locked = true, release = true })


-- ── 7. Keyboard Mouse Control ─────────────────────────────────────────────

-- Handled by fievel (~/.config/fievel/fievel.config), not Hyprland:
-- SUPER + CTRL + M toggles mouse mode. fievel reads the keyboard directly.

-- ── 8. Window Rules ─────────────────────────────────────────────────────────

-- Omarchy Settings
o.window({ title = "^(Omarchy Settings)$" }, { tag = "+floating-window" })

-- Manga Panel
o.window({ title = "^(Manga)$" }, {
  float = true,
  size = { 560, 1043 },
  move = { 5, 31 },
  tag = "+manga-window",
})





-- ╭─────────────────────────────────────────────────────────────────────────╮
-- │  Omacale keybindings — paste into ~/.config/hypr/bindings.lua           │
-- │  Each action is an IPC call into the running Omarchy shell:             │
-- │    omarchy-shell omacale <launcher|dashboard|session|settings|close>    │
-- │  Keys below are unbound in a stock Omarchy install. Check yours with:   │
-- │    omarchy menu keybindings --print                                     │
-- ╰─────────────────────────────────────────────────────────────────────────╯

-- ── Drawers ─────────────────────────────────────────────────────────────────

o.bind("SUPER + A", "Omacale launcher", "omarchy-shell omacale launcher")
o.bind("SUPER + D", "Omacale dashboard", "omarchy-shell omacale dashboard")
o.bind("SUPER + N", "Omacale notifications sidebar", "omarchy-shell omacale sidebar")
o.bind("SUPER + U", "Omacale quick toggles", "omarchy-shell omacale utilities")
-- o.bind("SUPER + SHIFT + ESCAPE", "Omacale session menu", "omarchy-shell omacale session")
o.bind("SUPER + SHIFT + I", "Omacale settings", "omarchy-shell omacale settings")

-- ── Dashboard tabs ──────────────────────────────────────────────────────────

o.bind("SUPER + ALT + D", "Omacale media", "omarchy-shell omacale dashboardTab media")
o.bind("SUPER + ALT + P", "Omacale performance", "omarchy-shell omacale dashboardTab performance")

-- ── Frame ───────────────────────────────────────────────────────────────────
-- SUPER + SHIFT + SPACE ("Toggle top bar") already hides/shows Omacale's
-- frame too; Omacale follows Omarchy's bar-off toggle.

-- ── Optional: make Omacale the main launcher ────────────────────────────────
-- These replace Omarchy defaults, so they are commented out. Remove the
-- leading "--" to use them. The picker binds open the launcher's carousel, or
-- Omarchy's own menu when Settings › Keybinds › Picker says "Omarchy default".
o.rebind("SUPER + SPACE", "Omacale launcher", "omarchy-shell omacale launcher")           -- was: Omarchy menu
o.rebind("SUPER + ESCAPE", "Omacale session menu", "omarchy-shell omacale session")      -- was: System menu
o.rebind("SUPER + CTRL + SPACE", "Omacale wallpaper picker", "omarchy-shell omacale wallpapers")       -- was: Background switcher
o.rebind("SUPER + SHIFT + CTRL + SPACE", "Omacale theme picker", "omarchy-shell omacale themes")       -- was: Theme menu
o.rebind("SUPER + TAB", "Omacale workspace overview", "omarchy-shell omacale overview")                -- was: Next workspace

-- Omacale look'n'feel (Caelestia styling). Keep your own tweaks below it.
pcall(dofile, os.getenv("HOME") .. "/.config/omarchy/plugins/omacale.bar/omacale.lua")
