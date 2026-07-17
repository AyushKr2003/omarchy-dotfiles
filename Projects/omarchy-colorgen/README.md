# omarchy-colorgen

Turn any wallpaper into a complete [Omarchy](https://omarchy.org) theme, from a
fast terminal UI. Pick an image, watch a live color palette and editor preview
update, then save, apply, or export a full theme folder.

Colors are generated with [`iris`](https://github.com/) and mapped through the
same derivation cascade Omarchy uses (`omarchy-theme-color`), so the result
looks native rather than "auto-generated".

## Features

- Folder picker on launch — browse to wherever your wallpapers live.
- Live preview: framed wallpaper thumbnail, the full palette as labeled
  swatches, and a mock Neovim buffer showing the syntax colors in context.
- Dark / light toggle (defaults to dark).
- Instant palette regeneration with per-wallpaper caching.
- Save into `~/.config/omarchy/themes/`, or apply immediately via
  `omarchy-theme-set`.
- Export a full theme folder (`colors.toml`, `icons.theme`, `preview.png`,
  `backgrounds/`) matching the first-party Omarchy theme layout.
- Optional full-resolution image peek in [Kitty](https://sw.kovidgoyal.net/kitty/).
- Headless mode for scripting.

## Requirements

- Go 1.24+ (build only)
- [`iris`](https://github.com/) on `PATH` — required, does the color extraction
- `omarchy-theme-set` on `PATH` — optional, needed only to apply themes
- A Kitty terminal — optional, needed only for the full-image peek (`w`)

Supported image formats: `jpg`, `jpeg`, `png`, `webp`, `gif`, `bmp`.

## Install

```bash
make install            # builds and installs to ~/.local/bin
# or
go build -o omarchy-colorgen .
```

## Usage

### Interactive

```bash
omarchy-colorgen
```

You start on the folder picker. Choose the directory that holds your
wallpapers, then browse the images and preview themes live.

### Keybindings

Folder picker:

| Key            | Action                          |
| -------------- | ------------------------------- |
| `↑`/`k` `↓`/`j`| Move                            |
| `enter` / `→` `l` | Open the highlighted folder  |
| `←` `h`        | Go up a directory               |
| `enter` on `[ Use this folder ]` | Pick the current folder |
| `q`            | Quit                            |

Main screen:

| Key            | Action                                   |
| -------------- | ---------------------------------------- |
| `↑`/`k` `↓`/`j`| Navigate wallpapers                      |
| `d`            | Toggle dark / light                      |
| `/`            | Filter the list                          |
| `g`            | Regenerate (bypass cache)                |
| `r`            | Reload the wallpaper list                |
| `o`            | Change wallpaper folder                  |
| `w`            | Peek full image (Kitty)                  |
| `s`            | Save theme to `~/.config/omarchy/themes` |
| `a`            | Save and apply (`omarchy-theme-set`)     |
| `e`            | Export a full theme folder               |
| `?`            | Toggle full help                         |
| `q`            | Quit                                     |

### Headless

Generate a theme without the UI:

```bash
# Print colors.toml to stdout
omarchy-colorgen --generate ~/Pictures/wall.jpg

# Light variant
omarchy-colorgen --generate wall.jpg --light

# Save under ~/.config/omarchy/themes/<name> and apply it
omarchy-colorgen --generate wall.jpg --name "Ocean" --apply

# Export a full theme folder to an arbitrary path
omarchy-colorgen --generate wall.jpg --export ./ocean-theme
```

| Flag              | Description                                             |
| ----------------- | ------------------------------------------------------- |
| `-g`, `--generate`| Wallpaper to generate from (enables headless mode)      |
| `--light`         | Generate a light theme (default is dark)                |
| `--name`          | Save under `~/.config/omarchy/themes/<slug>`            |
| `--apply`         | Run `omarchy-theme-set` after saving (implies `--name`) |
| `--export`        | Write a full theme folder to this path                  |
| `--version`       | Print version and exit                                  |

## How it works

1. `iris --json-only --dark {1|0|-1} <path>` extracts semantic colors from the
   image.
2. Those are mapped to Omarchy's `colors.toml` keys, and the derived shades
   (`dark_bg`, `darker_bg`, `bright_*`, `brown`, …) are computed with the same
   per-channel sRGB mix Omarchy's `omarchy-theme-color` uses.
3. A theme folder is written with `colors.toml`, an `icons.theme` (nearest Yaru
   accent), a generated `preview.png`, and the wallpaper under `backgrounds/`.
   The per-app config files (Alacritty, Hyprland, Waybar, …) are intentionally
   omitted: `omarchy-theme-set` renders those from templates on apply.

## Development

```bash
make build      # build the binary
make test       # go test ./...
make fmt        # gofmt -w .
make vet        # go vet ./...
```

## License

See [LICENSE](LICENSE).
