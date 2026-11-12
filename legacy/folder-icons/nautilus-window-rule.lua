-- Was in config/hypr/bindings.lua (section 8, Window Rules) while Nautilus
-- was Omarchy's file manager; Omarchy now ships Folio instead.

o.window("org.gnome.Nautilus", {
    float  = true,
    size   = { "min(1500, monitor_w * 0.92)", "min(850, monitor_h * 0.88)" },
    center = true,
})
