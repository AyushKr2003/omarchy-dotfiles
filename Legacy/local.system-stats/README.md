# Local System Stats Omarchy Plugin

Third-party clone of `omarchy.system-stats` with a click-open details panel.

Install it at:

```text
~/.config/omarchy/plugins/local.system-stats/
```

Then run:

```bash
omarchy plugin rescan
omarchy plugin enable local.system-stats
```

Add it to the bar from `local.settings` or with:

```bash
omarchy plugin bar add local.system-stats
```

This plugin does not launch `btop` on click. Left click opens a themed panel
with CPU, GPU, memory, disk, and load details.
