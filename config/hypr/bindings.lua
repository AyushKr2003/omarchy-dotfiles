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

hl.unbind("SUPER + SHIFT + RETURN")
o.bind("SUPER + SHIFT + RETURN", "Herdr", { launch = "omarchy-launch-terminal-herdr" })

hl.unbind("SUPER + T")
o.bind("SUPER + T", "Terminal", { omarchy = "terminal" })

hl.unbind("SUPER + SHIFT + T")
o.bind("SUPER + SHIFT + T", "Floating Terminal", { launch = "omarchy-launch-float-terminal" })

hl.unbind("SUPER + ALT + T")
o.bind("SUPER + ALT + T", "TypeTUI", { launch = "omarchy-launch-float-terminal typetui" })

hl.unbind("SUPER + CTRL + L")
o.bind("SUPER + CTRL + L", "Terminal Launcher", { launch = "omarchy-launch-float-terminal a -a" })

o.bind("SUPER + PAUSE", "Full System Info", hl.dsp.exec_cmd("xdg-terminal-exec fish -c full_sys", { float = true, size = "1220 680" }))

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

o.bind("SUPER + CTRL + RIGHT", "Next workspace", hl.dsp.focus({ workspace = "e+1" }))
o.bind("SUPER + CTRL + LEFT", "Previous workspace", hl.dsp.focus({ workspace = "e-1" }))


-- ── 5. Shell Plugins & Custom Menus ─────────────────────────────────────────

hl.unbind("SUPER + TAB")
o.bind("SUPER + TAB", "Overview", "omarchy-shell shell toggle local.overview")

hl.unbind("SUPER + I")
o.bind("SUPER + I", "Omarchy Settings", "omarchy-shell shell summon local.settings")

hl.unbind("SUPER + M")
o.bind("SUPER + M", "Manga Reader", "omarchy-shell shell toggle local.manga")

-- hl.unbind("SUPER + CTRL + T")
-- o.bind("SUPER + CTRL + T", "System Monitor", "omarchy-shell shell toggle local.system")


-- ── 6. Hardware & Mouse Controls ────────────────────────────────────────────

o.bind("SUPER + Prior", "Brightness +5%", "omarchy-brightness-display +5%", { locked = true, repeating = true })
o.bind("SUPER + Next", "Brightness -5%", "omarchy-brightness-display 5%-", { locked = true, repeating = true })

o.bind("mouse:275", "Orbit Press", "~/.config/omarchy/plugins/local.orbit/scripts/orbit-press.sh --button 275", { locked = true })
o.bind("mouse:275", "Orbit Release", "~/.config/omarchy/plugins/local.orbit/scripts/orbit-release.sh", { locked = true, release = true })


-- ── 7. Keyboard Mouse Control (Submap) ──────────────────────────────────────

o.bind("SUPER + CTRL + ALT + M", "Enter keyboard cursor mode", function()
  hl.exec_cmd("omarchy-notification-send --app-name 'cursor-mode' -u critical -g 󰍽 'Cursor Mode' 'Keyboard mouse control: ON'")
  hl.dispatch(hl.dsp.submap("cursor"))
end)

hl.define_submap("cursor", function()
  -- Directional movement
  o.bind("H", "Cursor left",  "ydotool mousemove -- -15 0", { repeating = true })
  o.bind("J", "Cursor down",  "ydotool mousemove -- 0 15",  { repeating = true })
  o.bind("K", "Cursor up",    "ydotool mousemove -- 0 -15", { repeating = true })
  o.bind("L", "Cursor right", "ydotool mousemove -- 15 0",  { repeating = true })

  -- Mouse clicks
  o.bind("S", "Left click",   "ydotool click 0xC0")
  o.bind("D", "Middle click", "ydotool click 0xC2")
  o.bind("F", "Right click",  "ydotool click 0xC1")

  -- Scroll controls
  o.bind("E", "Scroll up",   "ydotool mousemove -w -x 0 -y -5", { repeating = true })
  o.bind("R", "Scroll down", "ydotool mousemove -w -x 0 -y 5",  { repeating = true })

  -- Exit submap
  o.bind("ESCAPE", "Exit cursor mode", function()
    hl.exec_cmd("omarchy-shell -q notifications dismiss 'Cursor Mode'")
    hl.dispatch(hl.dsp.submap("reset"))
  end)
end)


-- ── 8. Window Rules ─────────────────────────────────────────────────────────

-- Omarchy Settings
o.window({ title = "^(Omarchy Settings)$" }, { no_screen_share = true, tag = "+floating-window" })

-- Manga Panel
o.window({ title = "^(Manga)$" }, {
  float = true,
  size = { 560, 1043 },
  move = { 5, 31 },
  tag = "+manga-window",
})


-- ── 9. Sub-Modules ──────────────────────────────────────────────────────────

require("hypr.hyprNiri")
