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

hl.unbind("SUPER + Q")
o.bind("SUPER + Q", "Close window", hl.dsp.window.close())

hl.unbind("SUPER + B")
o.bind("SUPER + B", "Open Chromium", "chromium")

hl.unbind("SUPER + W")
o.bind("SUPER + W", "Browser", { omarchy = "browser" })

hl.unbind("SUPER + CTRL + L")
o.bind("SUPER + CTRL + L", "Toggle workspace layout", "omarchy-hyprland-workspace-layout-toggle")

hl.unbind("SUPER + L")
o.bind("SUPER + L", "Lock system", "omarchy-system-lock")

hl.unbind("SUPER + Z")
o.bind("SUPER + Z", "Resize", hl.dsp.window.resize(), { mouse = true })

hl.unbind("SUPER + SHIFT + N")
o.bind("SUPER + SHIFT + N", "Editor", "code")

hl.unbind("SUPER + SHIFT + RETURN")
o.bind(
	"SUPER + SHIFT + RETURN",
	"Floating Terminal",
	"xdg-terminal-exec --app-id=org.omarchy.terminal --title=Omarchy -e fish"
)

hl.unbind("SUPER + SHIFT + O")
o.bind("SUPER + SHIFT + O", "Toggle window floating/tiling", hl.dsp.window.float({ action = "toggle" }))

hl.unbind("SUPER + SHIFT + B")
o.bind("SUPER + SHIFT + B", "Browser (private)", "chromium --incognito")

hl.unbind("SUPER + SHIFT + E")
o.bind("SUPER + SHIFT + E", "Yazi", " xdg-terminal-exec --app-id=org.omarchy.terminal --title=Omarchy -e fish -c yazi")

o.bind("SUPER + CTRL + RIGHT", "Next workspace", hl.dsp.focus({ workspace = "e+1" }))
o.bind("SUPER + CTRL + LEFT", "Next workspace", hl.dsp.focus({ workspace = "e-1" }))

o.bind("SUPER + E", "File manager", { omarchy = "nautilus" })

hl.unbind("SUPER + SHIFT + W")
o.bind("SUPER + SHIFT + W", "WhatsApp", { webapp = "https://web.whatsapp.com/", focus = true })

hl.unbind("SUPER + TAB")
o.bind("SUPER + TAB", "Overview", "omarchy-shell shell toggle local.overview")

hl.unbind("SUPER + T")
o.bind("SUPER + T", "Toggle focus floating/tiling", function()
	local active = hl.get_active_window()

	if active and active.floating then
		hl.dispatch(hl.dsp.focus({ window = "tiled" }))
	else
		hl.dispatch(hl.dsp.focus({ window = "floating" }))
	end
end)

hl.unbind("SUPER + I")
o.bind("SUPER + I", "Quickshell Settings", "omarchy-shell shell summon local.settings")
o.window("^(org.quickshell)$", { no_screen_share = true, tag = "+floating-window" })
