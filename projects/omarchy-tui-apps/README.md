# omarchy-tui-apps (`apps` / `a`)

A fast, sleek TUI application launcher built with [BubbleTea](https://github.com/charmbracelet/bubbletea) and [Lipgloss](https://github.com/charmbracelet/lipgloss) for Omarchy.

## Features

- ⚡ **Instant Search**: Search all desktop applications, Flatpaks, and terminal apps.
- 🎨 **Theme-Aware**: Reads the active Omarchy theme (`~/.local/state/omarchy/current/theme/colors.toml`) and re-colors live when the theme changes. Falls back to the terminal's ANSI palette when no theme is found.
- 🔍 **Rich Preview Panel**: Displays exec command, desktop file path, terminal status, and app comments.

## Installation

Build and install the package using `makepkg`:

```bash
makepkg -dsi
```

> **Note**: The `-d` flag skips pacman system dependency checks when using Go installed via `mise` or user environment managers.

## Usage

Launch the launcher directly from terminal or keybindings:

```bash
apps
# or show all apps including terminal executables
a -a
```

## Keys

| Key | Action |
|-----|--------|
| `↑`/`↓`, `Ctrl+P`/`Ctrl+N`, `Ctrl+K`/`Ctrl+J`, `Shift+Tab`/`Tab` | Move selection |
| `PgUp`/`PgDn`, `Home`/`End` | Jump |
| `Enter` | Launch |
| `Ctrl+H` | Toggle hidden / NoDisplay apps |
| `Ctrl+W` / `Ctrl+U` | Delete word / clear search |
| `Esc` | Quit |

## Environment

- `OMARCHY_THEME_COLORS`: path to a `colors.toml` to use instead of the active theme.
- `OMARCHY_LAUNCHER_HIDES`: path to the list of desktop IDs to hide.
- `INCLUDE_TERMINAL_APPS`: set to anything but `true` to leave out terminal apps.
