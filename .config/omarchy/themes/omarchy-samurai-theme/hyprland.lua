-- This file is not a full hyprland configuration.
-- It is intended to be included in your main hyprland.conf.

  local activeBorderColor = "#89b4fa"

hl.config({
    general = {
        col = {
            active_border = activeBorderColor,
        },
    },

    group = {
        col = {
            border_active = activeBorderColor,
        },
    },
})
