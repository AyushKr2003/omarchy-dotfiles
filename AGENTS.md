# AI Development Instructions

This repo is the source of truth for my personal Omarchy dotfiles, tools, and
third-party Omarchy shell plugins.

## Workspace

- Main repo: `$HOME/omarchy-dotfiles`
- Third-party Omarchy shell plugins: `Projects/omarchy-shell-plugins/`
- Custom terminal/TUI tools: `Projects/omarchy-tui-apps/`
- Reference Omarchy distro repo: `omarchy-repo/`
- Old or unused experiments: `Legacy/`

Do all new custom plugin/tool development in this repo. Do not use
`~/.config/quickshell` for new work.

## Important Rules

- Do not edit `omarchy-repo/` unless I explicitly ask. It is only a reference
  clone of upstream Omarchy.
- Do not edit Omarchy managed source under `~/.local/share/omarchy/`.
- Third-party plugin ids must use my local namespace, usually `local.*`.
- Development copies of plugins belong in:

  ```text
  $HOME/omarchy-dotfiles/Projects/omarchy-shell-plugins/<plugin-id>
  ```

- Live installed plugins, when needed for testing, are copied to:

  ```text
  ~/.config/omarchy/plugins/<plugin-id>
  ```

- Only edit live `~/.config/omarchy/shell.json` when I explicitly ask to enable,
  replace, or reorder widgets in the actual bar.
- Keep existing user changes. Never reset, delete, or revert unrelated files.

## Omarchy Plugin Pattern

Each plugin should have a `manifest.json` with a namespaced id such as:

```json
{
  "schemaVersion": 1,
  "id": "local.example",
  "name": "Local Example",
  "version": "1.0.0",
  "author": "AyushKr2003",
  "kinds": ["bar-widget"],
  "entryPoints": {
    "barWidget": "Panel.qml"
  }
}
```

For bar widgets that open panels, prefer this QML shape:

```qml
import QtQuick
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Ui

Panel {
  id: root
  moduleName: "local.example"
  ipcTarget: "local.example"

  WidgetButton {
    id: button
    bar: root.bar
    onPressed: function(mouseButton) {
      if (mouseButton === Qt.LeftButton) root.toggle()
    }
  }

  KeyboardPanel {
    anchorItem: button
    owner: root
    bar: root.bar
    open: root.opened
  }
}
```

Use `setting("key", defaultValue)` for plugin options. Put configurable options
in the manifest `barWidget.defaults` and `barWidget.schema`, so `local.settings`
can discover and edit them.

## Theme And UI Style

- Use Omarchy shell imports: `qs.Ui` and `qs.Commons`.
- Use Omarchy theme values where possible:
  - `Color.accent`
  - `Color.foreground`
  - `Style.font.*`
  - `Style.spacing.*`
  - `Style.cornerRadius`
  - `Style.normalFillFor(...)`
  - `Style.normalBorderFor(...)`
- For bar widgets, use `root.bar.foreground` and `root.bar.fontFamily` when
  available.
- Keep panels compact, practical, and consistent with built-in Omarchy panels.
- Avoid marketing/landing-page style UI in shell tools.
- Do not add hover popups unless I ask. I usually prefer click-to-open panels.

## Existing Plugins

Current custom plugins are in `Projects/omarchy-shell-plugins/`:

- `local.clock` - clock bar widget with calendar panel.
- `local.overview` - overview plugin.
- `local.settings` - settings UI for Omarchy shell/plugins.
- `local.weather` may exist in live config or older workspace, but new work
  should be done here if it is added to this repo.
- `local.system-stats` - older stats plugin with graph-style panel.
- `local.sysstat` - compact system stats plugin with horizontal rows and mini
  bars.

## Validation Commands

Run these from `$HOME/omarchy-dotfiles` after changing a plugin:

```bash
omarchy plugin validate Projects/omarchy-shell-plugins/<plugin-id>
qmllint -I omarchy-repo/shell Projects/omarchy-shell-plugins/<plugin-id>/<entry-qml>
jq . Projects/omarchy-shell-plugins/<plugin-id>/manifest.json
```

If the plugin has helper scripts, run them directly too:

```bash
bash Projects/omarchy-shell-plugins/<plugin-id>/<script>.sh
```

For installed/live testing:

```bash
omarchy plugin rescan
omarchy plugin enable <plugin-id>
omarchy plugin bar add <plugin-id>
omarchy-restart-shell
```

Only run live install/enable commands when appropriate for the task.

## Useful References

- Shell docs: `omarchy-repo/shell/README.md`
- Plugin docs: `omarchy-repo/shell/plugins/README.md`
- Built-in shell plugins: `omarchy-repo/shell/plugins/`
- Built-in panel examples:
  - `omarchy-repo/shell/plugins/panels/network/Panel.qml`
  - `omarchy-repo/shell/plugins/panels/audio/Panel.qml`
  - `omarchy-repo/shell/plugins/panels/bluetooth/Panel.qml`
  - `omarchy-repo/shell/plugins/panels/weather/Panel.qml`
- Built-in bar widgets: `omarchy-repo/shell/plugins/bar/widgets/`

## Preferred Workflow

1. Read the relevant existing plugin and upstream reference files first.
2. Make a focused change in `Projects/omarchy-shell-plugins/<plugin-id>`.
3. Keep plugin settings in `manifest.json` schemas whenever possible.
4. Validate with `omarchy plugin validate`, `qmllint`, `jq`, and any helper
   script tests.
5. Summarize what changed and what was verified.

