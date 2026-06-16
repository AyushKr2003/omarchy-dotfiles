# Architecture

## Folder Structure

```
omarchy-aur-guard-tui/
├── run.py                  # Entry point (thin wrapper)
├── aur_guard/              # Main package
│   ├── __init__.py         # Package docstring
│   ├── __main__.py         # CLI argument parsing + main()
│   ├── app.py              # Textual App class + all UI logic
│   ├── scanner.py          # Security engine + AUR API
│   ├── css.py              # All CSS styles (f-string)
│   ├── theme.py            # Omarchy theme loader
│   ├── views.py            # Welcome, Loading, ScanResult views
│   ├── widgets.py          # PkgItem sidebar widget
│   └── icons.py            # Nerd Font icon constants
├── docs/                   # This documentation
├── .venv/                  # Virtual environment
└── __pycache__/            # Compiled bytecode
```

## Module Responsibilities

### `run.py`
Thin entry point. Imports and calls `main()` from `__main__.py`.

### `__main__.py`
CLI argument parsing with `argparse`:
- `packages` (positional) - Package names to pre-load
- `--installed` / `-i` - Auto-load all installed AUR packages

Calls `AurGuardApp(preload=...).run()`.

### `app.py`
The core Textual App class `AurGuardApp`. Handles:
- **Compose**: Builds the full UI layout (header, sidebar, content area, overlays)
- **State**: Tracks packages, scan results, selection, active scans
- **Bindings**: All keyboard shortcuts (j/k, /, a, r, S, d, e, ?, q)
- **Actions**: Methods triggered by keybindings
- **Scanning**: Threaded scan launchers (`_launch_scan`, `_batch_scan`)
- **Views**: Switches content between Welcome, Loading, ScanResult

### `scanner.py`
The security analysis engine. Contains:
- **`RULES`**: 30+ regex patterns for malicious code detection
- **`analyze()`**: Pattern matching against PKGBUILD content
- **`score_pkg()`**: Reputation scoring from AUR metadata
- **`verdict()`**: Combines score + findings into final verdict
- **`full_scan()`**: Orchestrates the complete scan pipeline
- **AUR API**: `aur_info()`, `fetch_pkgbuild()`, `fetch_install()`
- **Cache**: JSON-based caching in `~/.cache/aur-guard/`

### `css.py`
Single `CSS` f-string containing all Textual CSS. Imports colors from `theme.py`.

### `theme.py`
Loads Omarchy theme from `~/.local/state/omarchy/current/theme/colors.toml`.
Falls back to Tokyo Night defaults. Exports color constants: `BG`, `FG`, `ACC`, `RED`, etc.

### `views.py`
Three view widgets:
- **`WelcomeView`**: Landing screen with keybinding hints
- **`LoadingView`**: Progress display during scans
- **`ScanView`**: Full result display with tabs (Overview, Findings, PKGBUILD, Diff)

### `widgets.py`
- **`PkgItem`**: Sidebar list item. Shows package name + verdict icon.
  - CSS classes for verdict coloring (`verdict-critical`, `verdict-high`, etc.)
  - Posts `PkgItem.Selected` message on click

### `icons.py`
Nerd Font icon constants. All SMP codepoints (U+F0000+):
- `APP` - Home/app icon
- `CRITICAL` - Shield alert
- `WARNING` - Exclamation triangle
- `CLEAN` - Check circle
- `LOADING` - Spinner
- `SEARCH` - Magnify
- `TERMINAL` - Console
- `OVERVIEW` - List bulleted
- `HELP` - Help circle

## Data Flow

```
User Input
    │
    ▼
┌─────────────┐
│  App.py     │  Keybinding / Button press
│  Actions    │
└─────┬───────┘
      │
      ▼
┌─────────────┐
│ Scanner.py  │  full_scan(pkgname)
│             │──► aur_info()      (AUR RPC API)
│             │──► fetch_pkgbuild() (cgit)
│             │──► fetch_install()  (cgit)
│             │──► analyze()        (regex rules)
│             │──► score_pkg()      (reputation)
│             │──► verdict()        (combine)
└─────┬───────┘
      │
      ▼
┌─────────────┐
│ Views.py    │  ScanView(result)
│ Widgets.py  │  PkgItem(verdict)
└─────────────┘
```

## State Management

`AurGuardApp` maintains:
- `_packages: list[str]` - Ordered list of package names
- `_results: dict[str, dict]` - Scan results keyed by package name
- `_sel: int` - Currently selected index (-1 = none)
- `_scanning: set[str]` - Packages currently being scanned
- `_list_items: list[PkgItem]` - Sidebar widget instances

## Threading Model

Scans run in background threads via Textual's `@work(thread=True)`:
- `_launch_scan()` - Single package scan
- `_batch_scan()` - Multi-package scan with progress overlay

UI updates are marshaled back to the main thread via `call_from_thread()`.
