# omarchy-tui-apps (`apps` / `a`)

A fast, sleek TUI application launcher built with [BubbleTea](https://github.com/charmbracelet/bubbletea) and [Lipgloss](https://github.com/charmbracelet/lipgloss) for Omarchy.

## Features

- ⚡ **Instant Search**: Search all desktop applications, Flatpaks, and terminal apps.
- 🎨 **Theme-Aware**: Automatically syncs colors with Omarchy's `colors.toml`.
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
