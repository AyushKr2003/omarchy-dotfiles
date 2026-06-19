# aur-guard

AUR Security Scanner TUI for Arch Linux / Omarchy.

Scans AUR packages for malicious patterns, suspicious code, and reputation risks before installation.

## Quick Start

```bash
# Install once from the project root
pip install .

# Use as a standalone command
aur-guard                    # Launch empty
aur-guard firefox            # Pre-load specific package
aur-guard -i                 # Scan all installed AUR packages
aur-guard firefox vim -i     # Pre-load + all installed
```

For development, `python run.py ...` still calls the same entry point.

## Requirements

- Python 3.10+
- Textual 0.50+ installed automatically by `pip install .`
- JetBrainsMono Nerd Font (for icons)
- Omarchy theme integration (reads `~/.local/state/omarchy/current/theme/`)

## Documentation

- [Architecture](architecture.md) - Folder structure and module responsibilities
- [How It Works](flow.md) - Application flow and lifecycle
- [Security Engine](security.md) - How packages are analyzed
- [Keybindings](keybindings.md) - All keyboard shortcuts
- [Configuration](configuration.md) - Theme and settings
