-- Niri mode: shared key-binding behavior.
--
-- All actual state and layout/animation/gesture changes now live in the
-- `omarchy-toggle-niri-mode` script and the Lua flag file it writes at
-- ~/.local/state/omarchy/toggles/hypr/niri-mode.lua — that flag file is
-- auto-sourced by default/hypr/toggles.lua on every config load, exactly
-- like Omarchy's own toggles/flags.lua, toggles/window-no-gaps.lua, etc.
-- That's what gives niri mode automatic, robust persistence across
-- `hyprctl reload` and reboot: no state file re-implementation, and no
-- plugin-polling timer needed for THIS part — the scrolloverview plugin
-- config block further down still needs one, see the comment there.
--
-- This file only has to do two things:
--   1. Know whether niri mode is currently on (by checking the same flag
--      file), so a couple of *shared* keybinds can branch their behavior.
--   2. Bind the toggle key itself to the omarchy-style script, the same
--      way Omarchy binds SUPER+CTRL+I to omarchy-toggle-idle.

local state_file = (os.getenv("HOME") or "") .. "/.local/state/omarchy/toggles/hypr/niri-mode.lua"

local function niriModeEnabled()
	local f = io.open(state_file, "r")
	if f then
		f:close()
		return true
	end
	return false
end

-- 3-finger gesture set, applied unconditionally on every config load/reload
-- (this file is always sourced, unlike the niri-mode flag file, which only
-- exists while niri mode is on) — so this is what makes gestures correct in
-- BOTH states, including right after a toggle:
--   niri mode ON:  vertical swipe = switch workspace, horizontal = focus
--   niri mode OFF: horizontal swipe = switch workspace (Hyprland default)
--
-- Hyprland errors if you try to rebind an already-bound gesture direction
-- WITHOUT unsetting it first ("overshadow"), but it also errors if you try
-- to unset a direction that was never bound in the first place — so we
-- can't just unconditionally unset everything every time (pcall doesn't
-- help here either: this isn't a catchable Lua error, Hyprland reports it
-- straight to its own config-error overlay).
--
-- So instead we remember which set we bound last time, using a real global
-- (not `local`) — Hyprland keeps the same Lua VM alive across `hyprctl
-- reload`, so this survives reloads and only comes back nil on an actual
-- fresh Hyprland start, which is exactly when nothing is bound yet.
local function applyGestures(niri, isInitial)
	if not isInitial then
		if _G.__niriGestureMode == "niri" then
			hl.gesture({ fingers = 3, direction = "vertical", action = "unset" })
			hl.gesture({ fingers = 3, direction = "left", action = "unset" })
			hl.gesture({ fingers = 3, direction = "right", action = "unset" })
		elseif _G.__niriGestureMode == "normal" then
			hl.gesture({ fingers = 3, direction = "horizontal", action = "unset" })
		end
	end

	if niri then
		hl.gesture({ fingers = 3, direction = "vertical", action = "workspace" })
		hl.gesture({
			fingers = 3,
			direction = "left",
			action = function()
				hl.dispatch(hl.dsp.focus({ direction = "r" }))
			end,
		})
		hl.gesture({
			fingers = 3,
			direction = "right",
			action = function()
				hl.dispatch(hl.dsp.focus({ direction = "l" }))
			end,
		})
		_G.__niriGestureMode = "niri"
	else
		hl.gesture({ fingers = 3, direction = "horizontal", action = "workspace" })
		_G.__niriGestureMode = "normal"
	end
end

applyGestures(niriModeEnabled(), _G.__niriGestureMode == nil)

-- Overview toggle (behavior depends on niri mode state)
hl.unbind("SUPER + TAB")
o.bind("SUPER + TAB", "Overview", function()
	if niriModeEnabled() then
		if hl.plugin and hl.plugin.scrolloverview then
			hl.plugin.scrolloverview.overview("toggle")
		end
	else
		hl.dispatch(hl.dsp.exec_cmd("omarchy-shell shell toggle local.overview"))
	end
end)

-- Workspace navigation: normal mode uses LEFT/RIGHT, niri mode uses UP/DOWN
hl.unbind("SUPER + CTRL + RIGHT")
o.bind("SUPER + CTRL + RIGHT", "Next workspace (normal)", function()
	if not niriModeEnabled() then
		hl.dispatch(hl.dsp.focus({ workspace = "e+1" }))
	end
end)

hl.unbind("SUPER + CTRL + LEFT")
o.bind("SUPER + CTRL + LEFT", "Previous workspace (normal)", function()
	if not niriModeEnabled() then
		hl.dispatch(hl.dsp.focus({ workspace = "e-1" }))
	end
end)

hl.unbind("SUPER + CTRL + UP")
o.bind("SUPER + CTRL + UP", "Next workspace (niri)", function()
	if niriModeEnabled() then
		hl.dispatch(hl.dsp.focus({ workspace = "e+1" }))
	end
end)

hl.unbind("SUPER + CTRL + DOWN")
o.bind("SUPER + CTRL + DOWN", "Previous workspace (niri)", function()
	if niriModeEnabled() then
		hl.dispatch(hl.dsp.focus({ workspace = "e-1" }))
	end
end)

-- Toggle niri mode — same pattern Omarchy uses for idle/nightlight/bar:
-- o.bind_toggle(keys, description, "niri-mode") shells out to
-- omarchy-toggle-niri-mode, which flips the flag file and reloads Hyprland.
hl.unbind("SUPER + ALT + L")
o.bind("SUPER + ALT + L", "Toggle niri mode", "bash $HOME/.local/bin/omarchy-toggle-niri-mode")

-- .config/hypr/hyprland.lua
--
-- hyprpm loads plugins AFTER the rest of the config has already been parsed,
-- so on a fresh login `hl.plugin.scrolloverview` doesn't exist yet at the
-- moment this file runs — setting plugin.scrolloverview.* config keys right
-- now throws "unknown config key" errors that vanish a second later once the
-- plugin actually finishes loading and a background reload picks it up. On
-- a plain `hyprctl reload` (plugin already loaded) it works immediately, so
-- we only need to poll on the fresh-login path.
local function applyScrolloverviewConfig()
	hl.config({
		plugin = {
			scrolloverview = {
				gesture_distance = 300, -- how far is the "max" for the gesture
				scale = 0.5, -- preferred overview scale
				workspace_gap = 100,
				layout = "vertical", -- vertical or horizontal
				wallpaper = 2, -- 0: global only, 1: per-workspace only, 2: both
				blur = true, -- blur only the main overview wallpaper

				shadow = {
					enabled = true,
					range = 50,
					render_power = 3,
					color = 0xee1a1a1a,
				},
			},
		},
	})
end

if hl.plugin and hl.plugin.scrolloverview then
	applyScrolloverviewConfig()
else
	hl.on("hyprland.start", function()
		local pluginCheckTimer
		pluginCheckTimer = hl.timer(function()
			if hl.plugin and hl.plugin.scrolloverview then
				pluginCheckTimer:set_enabled(false)
				applyScrolloverviewConfig()
			end
		end, { timeout = 500, type = "repeat" })
	end)
end
