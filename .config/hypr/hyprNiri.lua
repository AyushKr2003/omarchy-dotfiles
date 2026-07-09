-- hyprpm add https://github.com/yayuuu/hyprland-scroll-overview.git
-- hyprland.lua
--
-- hyprpm update
-- hyprpm add https://github.com/yayuuu/hyprland-scroll-overview.git
-- hyprpm enable scrolloverview
--

-- hyprpm add https://github.com/yayuuu/hyprland-scroll-overview.git
-- hyprland.lua

-- Persist niri mode state across reboots/reloads
local stateFile = (os.getenv("HOME") or "") .. "/.local/state/niri-mode-toggle"

local function readSavedState()
	local f = io.open(stateFile, "r")
	if not f then return false end
	local content = f:read("*a")
	f:close()
	return content:match("^%s*(.-)%s*$") == "true"
end

local function saveState(enabled)
	local f = io.open(stateFile, "w")
	if f then
		f:write(enabled and "true" or "false")
		f:close()
	end
end

local niriModeEnabled = readSavedState()

local originalLayout = "dwindle"      -- replace with your actual default layout
local originalAnimation = {
	leaf = "workspaces",
	enabled = false,
	speed = 7,                     -- must be > 0
	bezier = "default",
	style = "slide",
}

-- Overview toggle (behavior depends on niri mode state)
hl.unbind("SUPER + TAB")
o.bind("SUPER + TAB", "overview niri", function()
	if niriModeEnabled then
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
	if not niriModeEnabled then
		hl.dispatch(hl.dsp.focus({ workspace = "e+1" }))
	end
end)

hl.unbind("SUPER + CTRL + LEFT")
o.bind("SUPER + CTRL + LEFT", "Previous workspace (normal)", function()
	if not niriModeEnabled then
		hl.dispatch(hl.dsp.focus({ workspace = "e-1" }))
	end
end)

hl.unbind("SUPER + CTRL + UP")
o.bind("SUPER + CTRL + UP", "Next workspace (niri)", function()
	if niriModeEnabled then
		hl.dispatch(hl.dsp.focus({ workspace = "e+1" }))
	end
end)

hl.unbind("SUPER + CTRL + DOWN")
o.bind("SUPER + CTRL + DOWN", "Previous workspace (niri)", function()
	if niriModeEnabled then
		hl.dispatch(hl.dsp.focus({ workspace = "e-1" }))
	end
end)

-- Gesture sets: swap via "unset" to avoid overshadow errors
-- local function setGestures(niri, isInitial)
-- 	if niri then
-- 		if not isInitial then
-- 			hl.gesture({ fingers = 3, direction = "horizontal", action = "unset" })
-- 		end
-- 		hl.gesture({ fingers = 3, direction = "vertical", action = "workspace" })
-- 		hl.gesture({
-- 			fingers = 3,
-- 			direction = "left",
-- 			action = function()
-- 				hl.dispatch(hl.dsp.focus({ direction = "r" }))
-- 			end,
-- 		})
-- 		hl.gesture({
-- 			fingers = 3,
-- 			direction = "right",
-- 			action = function()
-- 				hl.dispatch(hl.dsp.focus({ direction = "l" }))
-- 			end,
-- 		})
-- 	else
-- 		if not isInitial then
-- 			hl.gesture({ fingers = 3, direction = "vertical", action = "unset" })
-- 			hl.gesture({ fingers = 3, direction = "left", action = "unset" })
-- 			hl.gesture({ fingers = 3, direction = "right", action = "unset" })
-- 		end
-- 		hl.gesture({ fingers = 3, direction = "horizontal", action = "workspace" })
-- 	end
-- end

local function enableNiriMode(isInitial)
	hl.config({
		general = { layout = "scrolling" },
		scrolling = { column_width = 1.0},
	})
	hl.animation({
		leaf = "workspaces",
		enabled = true,
		speed = 3,
		bezier = "easeOutQuint",
		style = "slidevert",
	})
	-- setGestures(true, isInitial)
	saveState(true)
	if not isInitial then
		hl.dispatch(hl.dsp.exec_cmd("omarchy bar position left"))
		hl.dispatch(hl.dsp.exec_cmd(o.notify("Niri mode enabled")))
	end
end

local function disableNiriMode(isInitial)
	hl.config({
		general = { layout = originalLayout },
	})
	hl.animation(originalAnimation)
	-- setGestures(false, isInitial)
	saveState(false)
	if not isInitial then
		hl.dispatch(hl.dsp.exec_cmd("omarchy bar position top"))
		hl.dispatch(hl.dsp.exec_cmd("notify-send -u low 'Niri mode' 'Disabled'"))
	end
end

-- Poll every 500ms until scrolloverview plugin is loaded, then apply saved state.
-- This is necessary because hyprpm loads plugins AFTER the config runs,
-- so even hyprland.start fires too early for hl.plugin.scrolloverview to exist.
-- Apply saved state on every config load (handles both boot AND hyprctl reload)
local function applySavedState(isInitial)
	if niriModeEnabled then
		enableNiriMode(isInitial)
	else
		disableNiriMode(isInitial)
	end
end

if hl.plugin and hl.plugin.scrolloverview then
	-- Plugin already loaded — this is a config reload, apply immediately
	applySavedState(true)
else
	-- Plugin not loaded yet — this is actual first boot, poll until ready
	hl.on("hyprland.start", function()
		local pluginCheckTimer
		pluginCheckTimer = hl.timer(function()
			if hl.plugin and hl.plugin.scrolloverview then
				pluginCheckTimer:set_enabled(false)
				applySavedState(true)
			end
		end, { timeout = 500, type = "repeat" })
	end)
end
hl.unbind("SUPER + ALT + L")
o.bind("SUPER + ALT + L", "toggle niri mode", function()
	niriModeEnabled = not niriModeEnabled
	if niriModeEnabled then
		enableNiriMode(false)
	else
		disableNiriMode(false)
	end
end)

-- .config/hypr/hyprland.lua
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
