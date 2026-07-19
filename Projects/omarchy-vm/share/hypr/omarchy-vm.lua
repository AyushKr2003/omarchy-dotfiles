-- Kali VM / Parrot VM: tell the SPICE/remote-viewer window it's fullscreen
-- while Hyprland keeps it tiled normally, and opt it out of Omarchy's
-- default window opacity so the VM display isn't dimmed. Both VMs launch
-- remote-viewer with the same `-t` window-title convention (confirmed
-- directly in bin/omarchy-kali-vm and bin/omarchy-parrot-vm: `-t 'Kali VM'`
-- / `-t 'Parrot VM'`), and share the same window class since remote-viewer
-- is a single binary (virt-viewer) regardless of which VM it connects to.
--
-- See: https://wiki.hypr.land/Configuring/Basics/Window-Rules/
--
-- NOTE: fullscreen_state/tag/opacity field names and value formats are
-- carried over from the old `windowrule = fullscreen_state 0 2, ...` conf
-- syntax. Verify these against Hyprland's Lua window-rule API before
-- shipping -- the mapping from classic windowrule fields to o.window()'s
-- rules table has not been independently confirmed for every field here.

o.window(
  { class = "remote-viewer" },
  {
    fullscreen_state = "0 2",
    tag = "-default-opacity",
    opacity = "1 1",
  }
)

