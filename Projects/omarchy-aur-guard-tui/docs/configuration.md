# Configuration

## Theme Integration

aur-guard reads the Omarchy theme from:

```
~/.local/state/omarchy/current/theme/colors.toml
~/.local/state/omarchy/current/theme.name
```

If these files don't exist, it falls back to Tokyo Night defaults.

### Theme Color Mapping

| TOML Key | Variable | Usage |
|----------|----------|-------|
| `bg` | `BG` | Main background |
| `dark_bg` | `DBG` | Darker panels (sidebar, header) |
| `darker_bg` | `DKR` | Darkest background (overlays) |
| `lighter_bg` | `LBG` | Borders, separators |
| `selection` | `SEL` | Selection highlight |
| `muted` | `MUT` | Dimmed text |
| `dark_fg` | `DFG` | Secondary text |
| `fg` | `FG` | Primary text |
| `bright_fg` | `BFG` | Bold/emphasized text |
| `accent` | `ACC` | Accent color (links, focus) |
| `red` | `RED` | Critical/errors |
| `yellow` | `YEL` | Warnings |
| `orange` | `ORG` | High severity |
| `green` | `GRN` | Clean/safe |
| `cyan` | `CYN` | Low severity/info |

## Cache

```
~/.cache/aur-guard/
├── {pkgname}.json        # Per-package scan cache
└── exports/
    └── aur-guard-{pkg}-{timestamp}.json   # Exported results
```

### Cache Contents

Each `{pkgname}.json` contains:
```json
{
  "hash": "sha256...",
  "content": "full PKGBUILD content...",
  "ts": 1234567890.0
}
```

Used for:
- Detecting PKGBUILD changes between scans
- Generating diffs for changed packages

## Minimum Terminal Size

- Width: 100 columns
- Height: 28 rows

If the terminal is smaller, an overlay is shown asking to resize.

## CLI Options

```
usage: aur-guard [-h] [--version] [--installed] [packages ...]

aur-guard -- AUR security scanner TUI

positional arguments:
  packages      Packages to pre-load

options:
  -h, --help    show this help message and exit
  --version     show program version and exit
  -i, --installed
                Load all installed AUR packages
```

## Dependencies

```
textual>=0.50.0
rich>=13.0
```

No other dependencies required. Uses only Python stdlib + Textual.
