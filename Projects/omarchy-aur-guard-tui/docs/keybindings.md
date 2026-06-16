# Keybindings

## Navigation

| Key | Action | Description |
|-----|--------|-------------|
| `j` | `cursor_down` | Move selection down |
| `k` | `cursor_up` | Move selection up |

## Package Management

| Key | Action | Description |
|-----|--------|-------------|
| `/` | `focus_search` | Focus the search input |
| `a` | `focus_add` | Focus the add package input |
| `Enter` | (in add input) | Add the typed package |
| `r` | `rescan` | Rescan current package (clears cache) |
| `S` | `scan_installed` | Scan all installed AUR packages |
| `d` | `remove_pkg` | Remove current package from list |

## Output

| Key | Action | Description |
|-----|--------|-------------|
| `e` | `export` | Export current result as JSON |

## UI

| Key | Action | Description |
|-----|--------|-------------|
| `Ctrl+H` | `show_help` | Toggle help overlay |
| `Esc` | `dismiss_help` | Close help overlay / unfocus input |
| `q` | `quit` | Quit application |
| `Ctrl+C` | `quit` | Quit application |

## Mouse

| Action | Description |
|--------|-------------|
| Click on package | Select that package |

## Notes

- `Ctrl+H` and `Esc` use `priority=True` bindings, so they work even when an Input field has focus
- All other keys are blocked by Input widgets when they have focus (standard Textual behavior)
- When no package is selected, `Ctrl+H` shows the help overlay with all keybindings
