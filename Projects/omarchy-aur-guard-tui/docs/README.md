# aur-guard

AUR Security Scanner TUI for Arch Linux / Omarchy.

Scans AUR packages for malicious patterns, suspicious code, and reputation risks before installation.

## Quick Start

```bash
# From project root
python run.py                    # Launch empty
python run.py firefox            # Pre-load specific package
python run.py -i                 # Scan all installed AUR packages
python run.py firefox vim -i     # Pre-load + all installed
```

## Requirements

- Python 3.14+
- Textual 8.x (`pip install textual`)
- JetBrainsMono Nerd Font (for icons)
- Omarchy theme integration (reads `~/.local/state/omarchy/current/theme/`)

## Documentation

- [Architecture](architecture.md) - Folder structure and module responsibilities
- [How It Works](flow.md) - Application flow and lifecycle
- [Security Engine](security.md) - How packages are analyzed
- [Keybindings](keybindings.md) - All keyboard shortcuts
- [Configuration](configuration.md) - Theme and settings
