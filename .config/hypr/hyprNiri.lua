-- hyprpm add https://github.com/yayuuu/hyprland-scroll-overview.git
-- hyprland.lua
--
-- hyprpm update
-- hyprpm add https://github.com/yayuuu/hyprland-scroll-overview.git
-- hyprpm enable scrolloverview
--

local niriModeEnabled = false
local originalLayout = "dwindle"      -- replace with your actual default layout
local originalAnimation = {
	leaf = "workspaces",
	enabled = false,
	speed = 7,                     -- must be > 0, fix from earlier error
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

-- Gesture sets: registered/unregistered via "unset" instead of stacking
local function setGestures(niri, isInitial)
	if niri then
		if not isInitial then
			hl.gesture({ fingers = 3, direction = "horizontal", action = "unset" })
		end

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
	else
		if not isInitial then
			hl.gesture({ fingers = 3, direction = "vertical", action = "unset" })
			hl.gesture({ fingers = 3, direction = "left", action = "unset" })
			hl.gesture({ fingers = 3, direction = "right", action = "unset" })
		end

		hl.gesture({ fingers = 3, direction = "horizontal", action = "workspace" })
	end
end

-- Start in default (non-niri) state — true flags this as initial load, no unset needed
setGestures(false, true)


local function enableNiriMode()
	hl.config({
		general = { layout = "scrolling" },
		scrolling = { column_width = 0.5 },
	})
	hl.animation({
		leaf = "workspaces",
		enabled = true,
		speed = 3,
		bezier = "easeOutQuint",
		style = "slidevert",
	})
	hl.dispatch(hl.dsp.exec_cmd("omarchy style bar position left"))
	hl.dispatch(hl.dsp.exec_cmd(o.notify("Niri mode enabled")))
	setGestures(true)
end

local function disableNiriMode()
	hl.config({
		general = { layout = originalLayout },
	})
	hl.animation(originalAnimation)
	hl.dispatch(hl.dsp.exec_cmd("omarchy style bar position top"))
	hl.dispatch(hl.dsp.exec_cmd("notify-send -u low 'Niri mode' 'Disabled'"))
	setGestures(false)
end

hl.unbind("SUPER + ALT + L")
o.bind("SUPER + ALT + L", "toggle niri mode", function()
	niriModeEnabled = not niriModeEnabled
	if niriModeEnabled then
		enableNiriMode()
	else
		disableNiriMode()
	end
end)
