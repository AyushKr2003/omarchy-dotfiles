# Local Sysstat

`local.sysstat` is a third-party Omarchy shell bar widget for compact system
stats. It keeps the stock system-stats icon, removes the `btop` click action,
and opens a themed panel with horizontal rows for CPU, GPU, memory, and disk.

## Settings

- `refreshSeconds`: polling interval in seconds.
- `diskPath`: filesystem path used for disk usage.
- `showGpu`: show or hide the GPU row.

Install it by placing this folder at:

```bash
~/.config/omarchy/plugins/local.sysstat
```

Then rescan and add it to the bar:

```bash
omarchy plugin rescan
omarchy plugin enable local.sysstat
omarchy plugin bar add local.sysstat
```
