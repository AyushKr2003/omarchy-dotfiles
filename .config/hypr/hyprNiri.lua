-- hyprpm add https://github.com/yayuuu/hyprland-scroll-overview.git

-- hyprland.lua
hl.unbind("SUPER + TAB")
o.bind("SUPER + TAB", "overview niri", function()
	if hl.plugin and hl.plugin.scrolloverview then
		hl.plugin.scrolloverview.overview("toggle")
	end
end)

hl.config({
	general = {
		-- Change to niri-like side-scrolling layout.
		layout = "scrolling",
	},
	scrolling = {
		-- See only one column per screen instead of two.
		column_width = 0.5,
	},
})

-- Enable touchpad gestures for changing workspaces.
-- See https://wiki.hypr.land/Configuring/Advanced-and-Cool/Gestures/
hl.gesture({ fingers = 3, direction = "vertical", action = "workspace" })

-- Enable touchpad gestures for moving focus (helpful on scrolling layout).
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

hl.animation({
	leaf = "workspaces",
	enabled = true,
	speed = 3,
	bezier = "easeOutQuint",
	style = "slidevert",
})
