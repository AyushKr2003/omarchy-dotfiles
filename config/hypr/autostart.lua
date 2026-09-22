-- Extra autostart processes.
-- o.launch_on_start("my-service")

-- o.launch_on_start("hyprpm reload")

-- daz.toggl-track logs into its own plugin folder by default; the shell
-- watches that folder and reloads every plugin (and the whole Omacale bar)
-- on each write, so the bar flickers forever. Keep its log out of there.
hl.env("OMARCHY_TOGGL_LOG_DIR", os.getenv("HOME") .. "/.local/state/omarchy/toggl-track")

-- BEGIN CURSOR CONFIG
hl.env("XCURSOR_THEME", "volantes_cursors")
hl.env("XCURSOR_SIZE", "28")
hl.env("HYPRCURSOR_THEME", "volantes_cursors")
hl.env("HYPRCURSOR_SIZE", "28")

o.launch_on_start("hyprctl setcursor volantes_cursors 28")
o.launch_on_start("gsettings set org.gnome.desktop.interface cursor-theme 'volantes_cursors'")
o.launch_on_start("gsettings set org.gnome.desktop.interface cursor-size 28")
o.launch_on_start("dbus-update-activation-environment --systemd WAYLAND_DISPLAY XDG_CURRENT_DESKTOP XCURSOR_THEME XCURSOR_SIZE HYPRCURSOR_THEME HYPRCURSOR_SIZE")
-- END CURSOR CONFIG
