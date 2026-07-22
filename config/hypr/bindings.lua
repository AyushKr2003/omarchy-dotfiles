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

-- ── Terminals & editors ───────────────────────────────────────────────────

-- Full system info
o.bind("SUPER + PAUSE", "float" ,hl.dsp.exec_cmd("xdg-terminal-exec fish -c full_sys", { float = true, size= "1220 680" }))

hl.unbind("SUPER + RETURN")
o.bind("SUPER  + RETURN", "Tmux", o.launch("omarchy-launch-terminal bash -c 'tmux attach -t Work || tmux new -s Work'"))

hl.unbind("SUPER + T")
o.bind("SUPER + T", "Terminal", { omarchy = "terminal" })

hl.unbind("SUPER + SHIFT + T")
o.bind(
	"SUPER + SHIFT + T",
	"Floating Tmux",
	o.launch("xdg-terminal-exec --app-id=org.omarchy.terminal --title=Omarchy -e fish")
)

-- Floating terminal — xdg-terminal-exec is a GUI app, needs uwsm-app
hl.unbind("SUPER + SHIFT + RETURN")
o.bind(
	"SUPER + SHIFT + RETURN",
	"Floating Tmux",
  hl.dsp.exec_cmd("omarchy-launch-terminal bash -c 'tmux attach -t Float || tmux new -s Float'", {float=true, size="875 600"})
)

hl.unbind("SUPER + ALT + T")
o.bind("SUPER + ALT + T", "TypeTUI", "xdg-terminal-exec --app-id=TUI.float -e typetui")

-- Editor → VS Code
hl.unbind("SUPER + SHIFT + N")
o.bind("SUPER + SHIFT + N", "Editor", o.launch("code"))

-- ── Window management overrides ───────────────────────────────────────────

-- Close window
hl.unbind("SUPER + Q")
o.bind("SUPER + Q", "Close window", hl.dsp.window.close())

-- Forcefully kill focused window
o.bind("SUPER + SHIFT + Q", "Forcefully kill window", hl.dsp.exec_cmd("hyprctl kill"))

-- Resize with mouse
hl.unbind("SUPER + Z")
o.bind("SUPER + Z", "Resize window", hl.dsp.window.resize(), { mouse = true })

-- Toggle float/tile
hl.unbind("SUPER + SHIFT + O")
o.bind("SUPER + SHIFT + O", "Toggle window floating/tiling", hl.dsp.window.float({ action = "toggle" }))


-- ── Lock & workspace ─────────────────────────────────────────────────────

hl.unbind("SUPER + L")
o.bind("SUPER + L", "Lock system", "omarchy-system-lock")

-- hl.unbind("SUPER + ALT + L")
-- o.bind("SUPER + ALT + L", "Toggle workspace layout", "omarchy-hyprland-workspace-layout-toggle")

o.bind("SUPER + CTRL + RIGHT", "Next workspace", hl.dsp.focus({ workspace = "e+1" }))
o.bind("SUPER + CTRL + LEFT", "Previous workspace", hl.dsp.focus({ workspace = "e-1" }))

-- ── Applications ─────────────────────────────────────────────────────────

-- Default Browser
hl.unbind("SUPER + W")
o.bind("SUPER + W", "Browser", "omarchy-launch-browser")

-- QuteBrowser — GUI app, needs uwsm-app
hl.unbind("SUPER + B")
o.bind("SUPER + B", "QuteBrowser", o.launch("qutebrowser"))

-- Private QuteBrowser — qutebrowser is a GUI app, needs uwsm-app
hl.unbind("SUPER + SHIFT + B")
o.bind(
	"SUPER + SHIFT + B",
	"QuteBrowser (private)",
	o.launch(
		"bash -c 'qutebrowser --basedir /tmp/qb-private-$(date +%s) "
			.. "--config $HOME/.config/qutebrowser/private.py --target window'"
	)
)

-- File manager shorthand
o.bind("SUPER + E", "File manager", { omarchy = "nautilus" })

-- Yazi — xdg-terminal-exec is a GUI app, needs uwsm-app
hl.unbind("SUPER + SHIFT + E")
o.bind(
	"SUPER + SHIFT + E",
	"Superfile",
	o.launch("xdg-terminal-exec --app-id=TUI.float -e fish -c spf")
)

-- WhatsApp
hl.unbind("SUPER + SHIFT + W")
o.bind("SUPER + SHIFT + W", "WhatsApp", { webapp = "https://web.whatsapp.com/", focus = true })

-- ── Shell plugins & menus ─────────────────────────────────────────────────

hl.unbind("SUPER + TAB")
o.bind("SUPER + TAB", "Overview", "omarchy-shell shell toggle local.overview")

hl.unbind("SUPER + I")
o.bind("SUPER + I", "Quickshell Settings", "omarchy-shell shell summon local.settings")

-- Terminal app launcher — xdg-terminal-exec is a GUI app, needs uwsm-app
hl.unbind("SUPER + CTRL + L")
o.bind(
	"SUPER + CTRL + L",
	"Terminal launcher",
	o.launch("xdg-terminal-exec --app-id=TUI.float -e fish -c 'a -a'")
)

hl.unbind("SUPER + M")
o.bind("SUPER + M", "Manga", "omarchy-shell shell toggle local.manga")

-- ── Keybinding menus ──────────────────────────────────────────────────────

o.bind("SUPER + CTRL + K", "Nvim keybindings", "omarchy-menu-nvim-keybindings")
o.bind("SUPER + SHIFT + K", "Qute keybindings", "omarchy-menu-qutebrowser-keybindings")

-- ── Brightness ────────────────────────────────────────────────────────────

o.bind("SUPER + Prior", "Brightness up", "omarchy-brightness-display +5%", { locked = true, repeating = true })
o.bind("SUPER + Next", "Brightness down", "omarchy-brightness-display 5%-", { locked = true, repeating = true })

-- ── Orbit mouse button ────────────────────────────────────────────────────

o.bind(
	"mouse:276",
	"Orbit press",
	"~/.config/omarchy/plugins/local.orbit/scripts/orbit-press.sh --button 276",
	{ locked = true }
)
o.bind(
	"mouse:276",
	"Orbit release fallback",
	"~/.config/omarchy/plugins/local.orbit/scripts/orbit-release.sh",
	{ locked = true, release = true }
)

-- Keyboard-driven cursor (ydotool)
o.bind("SUPER + CTRL + ALT + M", "Enter keyboard cursor mode", function()
  hl.exec_cmd("omarchy-notification-send --app-name 'cursor-mode' -u critical -g 󰍽 'Cursor Mode' 'Keyboard mouse control: ON'")
  hl.dispatch(hl.dsp.submap("cursor"))
end)

hl.define_submap("cursor", function()
  -- Continuous movement while held
  o.bind("H", "Cursor left",  "ydotool mousemove -- -15 0", { repeating = true })
  o.bind("J", "Cursor down",  "ydotool mousemove -- 0 15",  { repeating = true })
  o.bind("K", "Cursor up",    "ydotool mousemove -- 0 -15", { repeating = true })
  o.bind("L", "Cursor right", "ydotool mousemove -- 15 0",  { repeating = true })

  -- Clicks (0xC0 = left, 0xC1 = right, 0xC2 = middle)
  o.bind("S", "Left click",   "ydotool click 0xC0")
  o.bind("D", "Middle click", "ydotool click 0xC2")
  o.bind("F", "Right click",  "ydotool click 0xC1")

  -- Scroll
  o.bind("E", "Scroll up",   "ydotool mousemove -w -x 0 -y -5", { repeating = true })
  o.bind("R", "Scroll down", "ydotool mousemove -w -x 0 -y 5",  { repeating = true })

  -- Exit back to normal Hyprland binds
  o.bind("ESCAPE", "Exit cursor mode", function()
    hl.exec_cmd("omarchy-shell -q notifications dismiss 'Cursor Mode'")
    hl.dispatch(hl.dsp.submap("reset"))
  end)
end)









-- ── Window rules ─────────────────────────────────────────────────────────

-- Omarchy Settings: floating, no screen share
o.window({ title = "^(Omarchy Settings)$" }, { no_screen_share = true, tag = "+floating-window" })

-- Manga: floating, fixed size/position
o.window({ title = "^(Manga)$" }, {
  float = true,
  size = { 560, 1043 },
  move = { 5, 31 },
  tag = "+manga-window",
})


 -- Our custom lua files
require("hypr.hyprNiri")
