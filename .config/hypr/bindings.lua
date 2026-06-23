-- Application bindings.
o.bind("SUPER + RETURN", "Terminal", { omarchy = "terminal" })
o.bind("SUPER + ALT + RETURN", "Tmux", { omarchy = "terminal-tmux" })
o.bind("SUPER + SHIFT + RETURN", "Browser", { omarchy = "browser" })
o.bind("SUPER + SHIFT + F", "File manager", { omarchy = "nautilus" })
o.bind("SUPER + ALT + SHIFT + F", "File manager (cwd)", { omarchy = "nautilus-cwd" })
o.bind("SUPER + SHIFT + B", "Browser", { omarchy = "browser" })
o.bind("SUPER + SHIFT + ALT + B", "Browser (private)", "chromium --incognito")
o.bind("SUPER + SHIFT + M", "Music", { omarchy = "or-focus spotify" })
o.bind("SUPER + SHIFT + ALT + M", "Music TUI", { tui = "cliamp", focus = true })
o.bind("SUPER + SHIFT + N", "Editor", { omarchy = "editor" })
o.bind("SUPER + SHIFT + D", "Docker", { tui = "lazydocker" })
o.bind("SUPER + SHIFT + G", "Signal", { launch = "signal-desktop", focus = "^signal$" })
o.bind("SUPER + SHIFT + O", "Obsidian", { launch = "obsidian", focus = "^obsidian$" })
o.bind("SUPER + SHIFT + W", "Typora", { launch = "typora --enable-wayland-ime" })
o.bind("SUPER + SHIFT + SLASH", "Passwords", { launch = "1password" })

-- Web app bindings.
o.bind("SUPER + SHIFT + A", "ChatGPT", { webapp = "https://chatgpt.com" })
o.bind("SUPER + SHIFT + ALT + A", "Grok", { webapp = "https://grok.com" })
o.bind("SUPER + SHIFT + C", "Calendar", { webapp = "https://app.hey.com/calendar/weeks/" })
o.bind("SUPER + SHIFT + E", "Email", { webapp = "https://app.hey.com" })
o.bind("SUPER + SHIFT + Y", "YouTube", { webapp = "https://youtube.com/" })
o.bind("SUPER + SHIFT + ALT + G", "WhatsApp", { webapp = "https://web.whatsapp.com/", focus = true })
o.bind(
	"SUPER + SHIFT + CTRL + G",
	"Google Messages",
	{ webapp = "https://messages.google.com/web/conversations", focus = true }
)
o.bind("SUPER + SHIFT + P", "Google Photos", { webapp = "https://photos.google.com/", focus = true })
o.bind("SUPER + SHIFT + S", "Google Maps", { webapp = "https://maps.google.com/", focus = true })
o.bind("SUPER + SHIFT + X", "X", { webapp = "https://x.com/" })
o.bind("SUPER + SHIFT + ALT + X", "X Post", { webapp = "https://x.com/compose/post" })

-- Add extra bindings below.
-- o.bind("SUPER + SHIFT + R", "SSH", "alacritty -e ssh your-server")

-- Overwrite existing bindings with hl.unbind() first if needed.
-- hl.unbind("SUPER + SPACE")
-- o.bind("SUPER + SPACE", "Omarchy menu", "omarchy-menu")

-- Logitech MX Keys examples:
-- o.bind("SUPER + SHIFT + S", nil, "omarchy-capture-screenshot")
-- o.bind("SUPER + H", nil, "voxtype record toggle")
-- o.bind("SUPER + PERIOD", nil, { omarchy = "walker -m symbols" })

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
o.bind("SUPER + PAUSE", "float" ,hl.dsp.exec_cmd("xdg-terminal-exec fish -c full_sys", { float = true, size= "1120 680" }))

-- Floating terminal — xdg-terminal-exec is a GUI app, needs uwsm-app
hl.unbind("SUPER + SHIFT + RETURN")
o.bind(
	"SUPER + SHIFT + RETURN",
	"Floating Terminal",
	o.launch("xdg-terminal-exec --app-id=org.omarchy.terminal --title=Omarchy -e fish")
)

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

-- Toggle focus between tiled and floating
hl.unbind("SUPER + T")
o.bind("SUPER + T", "Toggle focus floating/tiling", function()
	local active = hl.get_active_window()
	if active and active.floating then
		hl.dispatch(hl.dsp.focus({ window = "tiled" }))
	else
		hl.dispatch(hl.dsp.focus({ window = "floating" }))
	end
end)

-- ── Lock & workspace ─────────────────────────────────────────────────────

hl.unbind("SUPER + L")
o.bind("SUPER + L", "Lock system", "omarchy-system-lock")

hl.unbind("SUPER + ALT + L")
o.bind("SUPER + ALT + L", "Toggle workspace layout", "omarchy-hyprland-workspace-layout-toggle")

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
	o.launch("xdg-terminal-exec --app-id=org.omarchy.terminal --title=Omarchy -c spf")
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
	o.launch("xdg-terminal-exec --app-id=org.omarchy.terminal --title=Omarchy -e fish -c 'a -a'")
)

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
	"~/.config/omarchy/plugins/orbit/scripts/orbit-press.sh --button 276",
	{ locked = true }
)
o.bind(
	"mouse:276",
	"Orbit release fallback",
	"~/.config/omarchy/plugins/orbit/scripts/orbit-release.sh",
	{ locked = true, release = true }
)

-- Keyboard-driven cursor (ydotool)
o.bind("SUPER + CTRL + ALT + M", "Enter keyboard cursor mode", function()
  hl.exec_cmd("notify-send -a 'cursor-mode' -u low -t 0 'Cursor Mode' 'Keyboard mouse control: ON'")
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
  o.bind("E", "Scroll up",   "ydotool mousemove -w -x 0 -y -10", { repeating = true })
  o.bind("R", "Scroll down", "ydotool mousemove -w -x 0 -y 10",  { repeating = true })

  -- Exit back to normal Hyprland binds
  o.bind("ESCAPE", "Exit cursor mode", function()
    hl.exec_cmd("makoctl dismiss -a 'cursor-mode'")
    hl.dispatch(hl.dsp.submap("reset"))
  end)
end)









-- ── Window rules ─────────────────────────────────────────────────────────

o.window("^(org.quickshell)$", { no_screen_share = true, tag = "+floating-window" })
