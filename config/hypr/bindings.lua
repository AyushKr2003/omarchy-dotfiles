-- ╭─────────────────────────────────────────────────────────────────────────╮
-- │  Custom bindings — loaded after omarchy defaults.                       │
-- │  Uses helpers from default/hypr/helpers.lua:                            │
-- │    o.bind(keys, description, dispatcher, opts?)                         │
-- │    o.rebind(keys|{keys...}, ...)  → unbind first, then o.bind (below)   │
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


-- Replaces Omarchy's o.rebind (helpers.lua). o is global and this file loads
-- before looknfeel.lua, autostart.lua and the bar plugins, so they get it too.
--   o.rebind("SUPER + X", desc, dispatcher, opts?)
--   o.rebind({ "SUPER + X", "SUPER + Y" }, desc, dispatcher, opts?)  -- same action on several keys
-- Unbinding a key nothing holds is harmless, so it works as a plain bind too.
-- Don't use it for a key with separate press/release binds (it'd drop the press).
function o.rebind(keys, description, dispatcher, options)
  if type(keys) == "string" then keys = { keys } end
  for _, key in ipairs(keys) do
    local opts = {}
    for k, v in pairs(options or {}) do opts[k] = v end
    hl.unbind(key)
    o.bind(key, description, dispatcher, opts)
  end
end


-- ── 1. Terminals & Editors ───────────────────────────────────────────────────

o.rebind("SUPER + RETURN", "Tmux (Work)", { launch = "omarchy-launch-terminal-tmux" })
o.rebind("SUPER + T", "Terminal", { omarchy = "terminal" })
o.rebind("SUPER + SHIFT + T", "Floating Terminal", { launch = "omarchy-launch-float-terminal" })
o.rebind("SUPER + CTRL + L", "Terminal Launcher", { launch = "omarchy-launch-float-terminal a -a" })
o.rebind({ "SUPER + PAUSE", "SUPER + KP_Prior" }, "Full System Info", hl.dsp.exec_cmd("xdg-terminal-exec fish -c full_sys", { float = true, size = "1220 680" }))
o.rebind("SUPER + SHIFT + N", "VS Code", { launch = "code" })

-- ── 2. Browsers & Web Applications ──────────────────────────────────────────

o.rebind("SUPER + W", "Default Browser", { omarchy = "browser" })
o.rebind("SUPER + ALT + B", "QuteBrowser", { launch = "qutebrowser" })
o.rebind("SUPER + B", "Zen Browser", { launch = "zen-browser" })
o.rebind("SUPER + SHIFT + B", "QuteBrowser (Incognito)", { launch = "bash -c 'd=$(mktemp -d /dev/shm/qb-incognito.XXXXXX); mkdir -p \"$d/config\"; cp ~/.config/qutebrowser/{config.py,theme.py,startpage.html} \"$d/config/\" 2>/dev/null; qutebrowser --basedir \"$d\" -s content.private_browsing true file://$HOME/.config/qutebrowser/startpage.html; rm -rf \"$d\"'" })
o.rebind("SUPER + CTRL + W", "WhatsApp Web", { webapp = "https://web.whatsapp.com/", focus = true })
o.rebind("SUPER + SHIFT + W", "WhatsApp Web", "zapfast")

-- ── 3. File Managers ────────────────────────────────────────────────────────

o.bind("SUPER + E", "Nautilus File Manager", { omarchy = "nautilus" })
o.bind("SUPER + ALT + E", "File manager (cwd)", { omarchy = "nautilus-cwd" })
o.rebind("SUPER + SHIFT + E", "Flea", { launch = "flea" })
-- o.bind("SUPER + SHIFT + E", "Flea", { launch = "strata" })

-- ── 4. Window Management & Workspaces ───────────────────────────────────────

o.rebind("SUPER + Q", "Close window", hl.dsp.window.close())
o.rebind("SUPER + SHIFT + Q", "Force kill window", hl.dsp.exec_cmd("hyprctl kill"))
o.rebind("SUPER + Z", "Resize window", hl.dsp.window.resize(), { mouse = true })
o.rebind("SUPER + SHIFT + O", "Toggle floating / tiling", hl.dsp.window.float({ action = "toggle" }))

-- float at 875x600, centred and pinned; press again to unpin and tile it
-- into the workspace you are on
o.rebind("SUPER + O", "Pop window out (float & pin)", function()
  local window = hl.get_active_window()
  if window == nil or window.address == nil then return end
  local target = "address:" .. window.address

  if window.pinned then
    -- unpin, then tile on whatever workspace is active now
    local ws = hl.get_active_workspace()
    hl.dispatch(hl.dsp.window.pin({ window = target }))
    if ws ~= nil and ws.id ~= nil then
      hl.dispatch(hl.dsp.window.move({ workspace = tostring(ws.id), follow = false, window = target }))
    end
    if window.floating then
      hl.dispatch(hl.dsp.window.float({ window = target, action = "toggle" }))
    end
  else
    if not window.floating then
      hl.dispatch(hl.dsp.window.float({ window = target, action = "toggle" }))
    end
    hl.dispatch(hl.dsp.window.resize({ window = target, x = 875, y = 600, exact = true }))
    hl.dispatch(hl.dsp.window.center({ window = target }))
    hl.dispatch(hl.dsp.window.pin({ window = target }))
    hl.dispatch(hl.dsp.window.alter_zorder({ window = target, mode = "top" }))
  end
end)

-- SUPER + R on a floating (or pinned) window enters a move mode:
-- h/j/k/l nudge it 40px (CTRL for 10px), SHIFT + h/l narrower / wider and
-- SHIFT + k/j shorter / taller by 40px, Escape / Return / SUPER + R leave.
local function nudge(x, y)
  return hl.dsp.window.move({ x = x, y = y, relative = true })
end

local function grow(x, y)
  return hl.dsp.window.resize({ x = x, y = y, relative = true })
end

o.rebind("SUPER + R", "Move floating window (hjkl)", function()
  local window = hl.get_active_window()
  if window ~= nil and window.floating then
    hl.dispatch(hl.dsp.submap("float-move"))
    hl.exec_cmd("omarchy-notification-send -u critical -g 󰆾 'Move mode' 'hjkl move · CTRL fine · SHIFT resize · Esc exit'")
  end
end)

-- after the rebind above, which would also clear SUPER + R inside the submap
hl.define_submap("float-move", function()
  for key, dir in pairs({ H = { -1, 0 }, J = { 0, 1 }, K = { 0, -1 }, L = { 1, 0 } }) do
    o.bind(key, "Move floating window", nudge(dir[1] * 40, dir[2] * 40), { repeating = true })
    o.bind("CTRL + " .. key, "Move floating window (fine)", nudge(dir[1] * 10, dir[2] * 10), { repeating = true })
    o.bind("SHIFT + " .. key, "Resize floating window", grow(dir[1] * 40, dir[2] * 40), { repeating = true })
  end
  for _, key in ipairs({ "ESCAPE", "RETURN", "SUPER + R" }) do
    o.bind(key, "Leave move mode", function()
      hl.dispatch(hl.dsp.submap("reset"))
      hl.exec_cmd("omarchy-notification-dismiss 'Move mode'")
    end)
  end
end)


o.rebind("SUPER + L", "Lock system", "omarchy-system-lock")
o.rebind("SUPER + TAB", "Omarchy overview", "omarchy-shell shell toggle omarchy-overview")

-- ===== Smart next/prev workspace (skip repeated empty workspaces) =====
-- Omarchy binds these to "Move grouped window focus"; o.rebind drops that,
-- otherwise both actions fire on every press.

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

o.rebind("SUPER + CTRL + RIGHT", "Next workspace",
    function()
        local target = next_workspace(1)
        if target ~= nil then
            hl.dispatch(hl.dsp.focus({ workspace = tostring(target) }))
        end
    end)

o.rebind("SUPER + CTRL + LEFT", "Previous workspace",
    function()
        local target = next_workspace(-1)
        if target ~= nil then
            hl.dispatch(hl.dsp.focus({ workspace = tostring(target) }))
        end
    end)


-- o.rebind("SUPER + S", "Toggle scratchpad", hl.dsp.workspace.toggle_special("scratch"))
-- o.rebind("SUPER + SHIFT + S", "Move window to scratchpad", hl.dsp.window.move({ workspace = "special:scratch", follow = false }))

-- ── 5. Shell Plugins & Custom Menus ─────────────────────────────────────────

o.rebind("SUPER + ALT + S", "Shaders", "omarchy-menu-shaders")


-- ── 6. Hardware & Mouse Controls ────────────────────────────────────────────

o.bind("XF86Launch6", "Mute microphone", "omarchy-audio-input-mute", { locked = true })
o.bind("SUPER + Prior", "Brightness +5%", "omarchy-brightness-display +5%", { locked = true, repeating = true })
o.bind("SUPER + Next", "Brightness -5%", "omarchy-brightness-display 5%-", { locked = true, repeating = true })

o.bind("mouse:275", "Orbit Press", "~/.config/omarchy/plugins/local.orbit/scripts/orbit-press.sh --button 275", { locked = true })
o.bind("mouse:275", "Orbit Release", "~/.config/omarchy/plugins/local.orbit/scripts/orbit-release.sh", { locked = true, release = true })


-- ── 7. Keyboard Mouse Control ─────────────────────────────────────────────

-- Handled by fievel (~/.config/fievel/fievel.config), not Hyprland:
-- SUPER + CTRL + M toggles mouse mode. fievel reads the keyboard directly.

-- ── 8. Window Rules ─────────────────────────────────────────────────────────

-- Flea 
o.window("com.thisisgm.flea", { tag = "+floating-window" })
o.window("io.github.lgse.Strata", { tag = "+floating-window" })
o.window("org.gnome.Nautilus", {
    float  = true,
    size   = { "min(1500, monitor_w * 0.92)", "min(850, monitor_h * 0.88)" },
    center = true,
})



-- ── 9. Bar-specific binds ───────────────────────────────────────────────────
-- Follows bar.id in ~/.config/omarchy/shell.json, so only the active bar's
-- keys are bound. Switch bars with omarchy-bar-switch (it runs hyprctl reload).

-- "omacale", "hanko" or "default". looknfeel.lua uses it too.
function o.active_bar()
  local f = io.open(os.getenv("HOME") .. "/.config/omarchy/shell.json")
  if not f then return "default" end
  local json = f:read("*a")
  f:close()
  local id = json:match('"id"%s*:%s*"([%w_-]+)%.bar"')
  if id == "omacale" or id == "hanko" then return id end
  return "default"
end

o.bind("SUPER + SHIFT + CTRL + B", "Pick bar (Omacale / Hanko / Omarchy)", "omarchy-launch-floating-terminal-with-presentation omarchy-bar-switch pick")

local bar = o.active_bar()

if bar == "hanko" then
  o.rebind("SUPER + TAB", "Hanko overview", "omarchy-shell hanko overview")          -- was: Next workspace
  o.rebind("SUPER + SHIFT + I", "Hanko settings", "omarchy-shell hanko settings")
  -- Bar focus: the bar takes the keyboard. Left/Right walk it, Enter clicks,
  -- Menu right-clicks, Up/Down volume, 1-9 workspace, Esc lets go.
  o.bind("SUPER + CTRL + 0", "Hanko bar focus", "omarchy-shell hanko barFocus")

elseif bar == "omacale" then
  -- Drawers
  o.bind("SUPER + CTRL + 0", "Omacale bar focus", "omarchy-shell omacale barFocus")
  o.bind("SUPER + D", "Omacale dashboard", "omarchy-shell omacale dashboard")
  o.bind("SUPER + N", "Omacale notifications sidebar", "omarchy-shell omacale sidebar")
  o.bind("SUPER + U", "Omacale quick toggles", "omarchy-shell omacale utilities")
  -- o.bind("SUPER + SHIFT + ESCAPE", "Omacale session menu", "omarchy-shell omacale session")
  o.rebind("SUPER + SHIFT + I", "Omacale settings", "omarchy-shell omacale settings")
  o.rebind("SUPER + CTRL + V", "Omacale clipboard", "omarchy-shell omacale clipboard")                 -- was: Clipboard manager

  -- Dashboard tabs
  o.bind("SUPER + ALT + D", "Omacale media", "omarchy-shell omacale dashboardTab media")
  o.bind("SUPER + ALT + P", "Omacale performance", "omarchy-shell omacale dashboardTab performance")

  -- Frame: SUPER + SHIFT + SPACE ("Toggle top bar") already hides/shows
  -- Omacale's frame too.

  -- Omacale as the main launcher
  o.rebind("SUPER + SPACE", "Omacale launcher", "omarchy-shell omacale launcher")                      -- was: Omarchy menu
  o.rebind("SUPER + ALT + SPACE", "Omacale menu", "omarchy-shell omacale menu")
  o.rebind("SUPER + ESCAPE", "Omacale session menu", "omarchy-shell omacale session")                  -- was: System menu
  o.rebind("SUPER + CTRL + SPACE", "Omacale wallpaper picker", "omarchy-shell omacale wallpapers")     -- was: Background switcher
  o.rebind("SUPER + SHIFT + CTRL + SPACE", "Omacale theme picker", "omarchy-shell omacale themes")     -- was: Theme menu
  o.rebind("SUPER + TAB", "Omacale workspace overview", "omarchy-shell omacale overview")              -- was: Next workspace
end
