# Keybindings

## Navigation

| Key | Action | Description |
|-----|--------|-------------|
| `Tab` | `toggle_focus_region` | Toggle focus between sidebar and main screen |
| `j` | `cursor_down` | Move package selection down when sidebar is focused |
| `k` | `cursor_up` | Move package selection up when sidebar is focused |
| `g` | `cursor_top` | Jump to first package when sidebar is focused |
| `G` | `cursor_bottom` | Jump to last package when sidebar is focused |
| `h` | `previous_tab` | Move to previous result tab when main screen is focused |
| `l` | `next_tab` | Move to next result tab when main screen is focused |
| `Ctrl+J` | `scroll_down` | Scroll active result tab content down |
| `Ctrl+K` | `scroll_up` | Scroll active result tab content up |

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
| `?` | `toggle_help` | Toggle help overlay |
| `Esc` | `dismiss_help` | Close help overlay / unfocus input |
| `q` | `quit` | Quit application |
| `Ctrl+C` | `quit` | Quit application |

## Mouse

| Action | Description |
|--------|-------------|
| Click on package | Select that package |

## Notes

- `Tab` and `Esc` use priority bindings so focus can be moved or dismissed from an input.
- Text entry keys are blocked by Input widgets while they have focus, which is standard Textual behavior.
- Sidebar navigation keys only act while the sidebar region is focused; result tab keys only act while the main screen is focused.
