# Omarchy Browser Startpage

A minimalist, terminal-inspired local start page with an animated cat companion, based on [kencx/startpage](https://github.com/kencx/startpage) and integrated into Omarchy's live theming system.

![startpage](startpage.gif)

## Features

- **Animated cat illustration** (`cat.gif`)
- **Dynamic Omarchy theming**: Automatically synchronizes with your active Omarchy theme (Catppuccin, Tokyo Night, Nord, Gruvbox, etc.)
- **Responsive design**: Seamlessly scales from full-screen 4K displays down to split tiling windows in Hyprland
- **Entry point**: Served at `~/.config/browser-default/default.html` so your browser configuration never needs updating

## How It Stays Themed

`colors.css` is dynamically regenerated on every theme change by the Omarchy hook:
```
~/.config/omarchy/hooks/theme-set.d/30-browser-default-homepage
```

`style.css` references CSS custom variables (`--bg`, `--fg`, `--accent`, `--muted`, etc.) exported by `colors.css`. Every time you run `omarchy theme set <theme>`, the startpage updates its color scheme instantly without needing any external browser extensions.

## Homepage Setup

Your browser opens this page locally via:
```
file:///home/shadow/.config/browser-default/default.html
```

## Structure

| File | Description |
|---|---|
| `default.html` | Startpage markup (entry point) |
| `style.css` | Typography, layout, animations, responsive grid |
| `colors.css` | Dynamically generated theme colors from Omarchy hook |
| `cat.gif` | Cat companion animation (credit: [Avogado6](https://twitter.com/avogado6)) |
| `startpage.gif` | Preview graphic |
| `LICENSE` | MIT License |

## Credits

- Original startpage by [kencx](https://github.com/kencx/startpage)
- Artwork by [Avogado6](https://twitter.com/avogado6)
- Theming integration for [Omarchy](https://omarchy.org/)
