# Local Overview Omarchy Plugin

Third-party Omarchy shell plugin for the Hyprland workspace overview.

## Install

Copy this folder to:

```text
~/.config/omarchy/plugins/local.overview/
```

Then rescan and enable it:

```bash
omarchy plugin rescan
omarchy plugin enable local.overview
```

## Toggle

Use Omarchy shell IPC:

```bash
omarchy-shell shell toggle local.overview
```

Example Hyprland binding:

```conf
bind = SUPER, TAB, exec, omarchy-shell shell toggle local.overview
```

The old direct overview IPC target is also kept available while the plugin is loaded:

```bash
omarchy-shell overview toggle
```

## Configure

Settings are read inline from `~/.config/omarchy/shell.json`, inside the
`plugins` entry for `local.overview`:

```json
{
  "id": "local.overview",
  "rows": "2",
  "columns": "5",
  "hideEmptyRows": "true",
  "showSpecialWorkspaces": "false",
  "specialWorkspaceColumns": "5",
  "showIcons": "false"
}
```

Only those six options are read for now. Values may be strings, as shown
above, or native JSON booleans/numbers.

The plugin manifest also declares these options in `settings.schema`, so
`local.settings` can render an editor for them from its Plugins section.

Internally this mirrors Omarchy panels: the plugin exposes `settings` and
`setting(name, fallback)`, and the overview config reads values like
`setting("rows", 2)`.

## Theme

The plugin bridges its local `Color` and `Style` names to Omarchy's
`qs.Commons.Color` and `qs.Commons.Style`, so it follows the active shell
theme instead of loading a separate theme or config file.
