# Worklog

A local work-history log for [Omarchy](https://omarchyplugins.com/).

![preview](./preview.png)

Log what you worked on, right from your bar. Each entry has a title, an
optional long-note body, a date, and a status. Entries are stored locally in
`~/.local/state/omarchy/settings/worklog.history.json` — no accounts, no
network.

## Features

- Add an entry from the bar popup (Enter to confirm) or the Quick Add overlay
- Long notes: open any entry to view and edit its full text in a popup
- Status per entry — Todo / In progress / Done — cycled from the list or set
  in the detail popup
- Click any row to open its detail view; the trash icon removes it directly
- Live entry counter in the panel header
- Keyboard friendly: Esc closes, Tab switches panels, Ctrl+Enter saves notes

## Quick Add Shortcut

Worklog exposes the global shortcut action `worklog:quick-add`. Bind it
to any key combination in your Hyprland bindings, for example:

```lua
o.bind("SUPER SHIFT, T", nil, hl.dsp.global("worklog:quick-add"))
```

Reload Hyprland after adding the binding. Press the shortcut, enter a title,
and press Enter to save and open the new entry. Escape or clicking outside the
dialog closes it without adding. The plugin does not modify Hyprland
configuration.

## Installation

Worklog is a bar widget for the Omarchy shell (Quickshell).

Enable it with the Omarchy CLI:

```sh
omarchy plugin enable worklog
```

## Removal

```sh
omarchy plugin remove worklog
```

This removes the plugin and its bar entry. Your saved entries live in
`~/.local/state/omarchy/settings/worklog.history.json`; delete that file to
clear your data.

## Requirements

- Omarchy (Quickshell shell). No other external dependencies.

## License

[MIT](LICENSE)