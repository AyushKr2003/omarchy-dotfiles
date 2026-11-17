-- Extra autostart processes.
-- o.launch_on_start("my-service")

-- o.launch_on_start("hyprpm reload")

-- BEGIN CURSOR CONFIG
-- "Bibata-Material-Omarchy" and "Volantes-Omarchy" follow the theme accent
-- (omarchy-cursor-material / omarchy-cursor-volantes, rebuilt by the theme-set
-- hooks). Switch with omarchy-cursor-switch (SUPER+SHIFT+CTRL+C), which
-- rewrites the line below. Stock cursor: "volantes_cursors".
local cursor_theme = "Volantes-Omarchy"
local cursor_size = 28

hl.env("XCURSOR_THEME", cursor_theme)
hl.env("XCURSOR_SIZE", tostring(cursor_size))
hl.env("HYPRCURSOR_THEME", cursor_theme)
hl.env("HYPRCURSOR_SIZE", tostring(cursor_size))

-- Run on reload too, so editing cursor_theme/cursor_size applies on save.
local function apply_cursor()
  hl.exec_cmd("hyprctl setcursor " .. cursor_theme .. " " .. cursor_size)
  hl.exec_cmd("gsettings set org.gnome.desktop.interface cursor-theme '" .. cursor_theme .. "'")
  hl.exec_cmd("gsettings set org.gnome.desktop.interface cursor-size " .. cursor_size)
  hl.exec_cmd("dbus-update-activation-environment --systemd WAYLAND_DISPLAY XDG_CURRENT_DESKTOP XCURSOR_THEME XCURSOR_SIZE HYPRCURSOR_THEME HYPRCURSOR_SIZE")
end

hl.on("hyprland.start", apply_cursor)
hl.on("config.reloaded", apply_cursor)
-- END CURSOR CONFIG
