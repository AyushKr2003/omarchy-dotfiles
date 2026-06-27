# omarchy-dotfiles

My personal dotfiles, tools, and shell plugins on top of [Omarchy](https://github.com/basecamp/omarchy).

## Install

```bash
git clone https://github.com/AyushKr2003/omarchy-dotfiles.git ~/omarchy-dotfiles
cd ~/omarchy-dotfiles
./install.sh
```

## What's included

**Shell plugins** (`Projects/omarchy-shell-plugins/`) — custom Omarchy bar widgets:
- `local.clock` — clock with calendar popup
- `local.sysstat` — compact system stats
- `local.weather` — weather pill with detail popup
- `local.overview` — workspace overview with live previews
- `local.settings` — settings UI for shell and plugins

**Other projects:**
- `omarchy-aur-guard-tui/` — TUI security scanner for AUR packages
- `omarchy-tui-apps/` — terminal app launcher built with Go + Bubbletea
- `omarchy-menu-nvim-keybindings/` — searchable Vim/LazyVim keybinding reference
- `omarchy-menu-qute-keybinds/` — searchable Qutebrowser keybinding reference
- `orbit/` — radial menu plugin (see [`orbit/README.md`](orbit/README.md))
- `fastfetch-config/` — theme-aware fastfetch setup
