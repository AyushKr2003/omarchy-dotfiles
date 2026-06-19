# Application Flow

## Startup

```
aur-guard console script / run.py
  └─► aur_guard.__main__:main()
        ├─► Parse CLI args (packages, --installed)
        ├─► If --installed: get_installed_aur() → pacman -Qm
        └─► AurGuardApp(preload=...).run()
              ├─► compose() builds UI
              │     ├─ Header bar (title, theme, counts)
              │     ├─ Sidebar (search, package list, add bar)
              │     ├─ Content area (WelcomeView)
              │     ├─ Footer
              │     ├─ Too-small overlay (hidden)
              │     ├─ Batch overlay (hidden)
              │     └─ Help overlay (hidden)
              └─► on_mount()
                    ├─► If packages pre-loaded: sync list, select first
                    └─► Unfocus all widgets
```

## Adding a Package

```
User types package name in add bar → Enter
  │
  ▼
on_input_submitted() [if add-pkg-input]
  ├─► _add_pkg(pkgname)
  │     ├─ If already in list: select it
  │     ├─ Else: append to _packages
  │     ├─► _sync_list()  (update sidebar)
  │     └─► _launch_scan(pkgname)
  │
  ▼
_launch_scan() [@work(thread=True)]
  ├─► Show LoadingView
  ├─► full_scan(pkgname)  [in background thread]
  │     ├─► aur_info()       → AUR RPC API
  │     ├─► score_pkg()      → reputation score
  │     ├─► fetch_pkgbuild() → PKGBUILD content
  │     ├─► analyze()        → regex pattern matching
  │     ├─► fetch_install()  → .install file (if exists)
  │     ├─► analyze()        → .install pattern matching
  │     ├─► Cache comparison → detect PKGBUILD changes
  │     └─► verdict()        → final verdict
  ├─► Store result in _results[pkgname]
  └─► Switch to ScanView(result)
```

## Scanning All Installed

```
User presses S
  │
  ▼
action_scan_installed()
  ├─► get_installed_aur() → pacman -Qm
  ├─► Add any new packages to _packages
  ├─► _sync_list()
  └─► _batch_scan(packages)
        │
        ▼
      _batch_scan() [@work(thread=True)]
        ├─► Show batch overlay with progress bar
        ├─► For each package:
        │     ├─► Update progress display
        │     └─► full_scan(pkg) → _results[pkg]
        └─► Hide overlay, sync list
```

## Navigation

```
j / k  →  action_cursor_down / action_cursor_up
  │
  ▼
_select(idx)
  ├─► Clamp index to valid range
  ├─► _sync_list()  (highlight active item)
  ├─► If result exists: show ScanView
  └─► If no result: _launch_scan(pkg)
```

## Rescanning

```
User presses r
  │
  ▼
action_rescan()
  ├─► Delete cached PKGBUILD
  ├─► Remove from _results
  └─► _launch_scan(pkg)  (fresh scan)
```

## Removing a Package

```
User presses d
  │
  ▼
action_remove_pkg()
  ├─► Remove from _packages
  ├─► Remove from _results
  ├─► Remove PkgItem widget
  ├─► Adjust selection
  └─► Show WelcomeView if list empty
```

## Exporting

```
User presses e
  │
  ▼
action_export()
  ├─► Get current package result
  ├─► Create ~/.cache/aur-guard/exports/
  ├─► Write JSON file: aur-guard-{pkg}-{timestamp}.json
  └─► Show notification
```

## Help Overlay

```
User presses ?
  │
  ▼
action_show_help()
  └─► Toggle #help-overlay display

User presses Esc
  │
  ▼
action_dismiss_help()
  └─► Hide #help-overlay
```

## Resize Handling

```
Terminal resized
  │
  ▼
on_resize()
  ├─► Check dimensions vs MIN_WIDTH/MIN_HEIGHT
  ├─► If too small: show #too-small-overlay
  └─► If OK: hide overlay
```
