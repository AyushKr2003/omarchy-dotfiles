# Local Settings Omarchy Plugin

Third-party settings panel for Omarchy shell configuration.

Install it at:

```text
~/.config/omarchy/plugins/local.settings/
```

Then run:

```bash
omarchy plugin rescan
omarchy plugin enable local.settings
```

Open it through the shell's generic plugin IPC:

```bash
omarchy-shell shell summon local.settings
```

Inside the panel you can:

- enable, disable, and rescan third-party plugins
- install a plugin from a local folder that contains `manifest.json`
- edit plugin settings declared by a plugin manifest
- adjust idle screensaver and lock timings
- edit the bar position, transparency, layout, and widget settings

The Plugins section is filtered into manageable views:

- `Third-party`: all user-installed plugins, including bar widgets
- `Built-in`: built-in non-bar Omarchy plugins
- `Configurable`: built-in non-bar Omarchy plugins with declared settings

Built-in bar widgets are intentionally managed from the Bar section instead.

The plugin writes through the shell's injected config mutator and plugin
registry, so it updates `~/.config/omarchy/shell.json` without requiring a
custom `shell.omarchySettings` IPC method.

Generic plugin settings use this manifest convention:

```json
{
  "settings": {
    "defaults": { "example": true },
    "schema": [
      { "key": "example", "type": "boolean", "label": "Example" }
    ]
  }
}
```

Bar widgets can keep using `barWidget.schema` or a built-in `settingsForm`.
