# typetui

A terminal code-typing practice tool, built with [Bubble Tea](https://github.com/charmbracelet/bubbletea).
Think MonkeyType, but for code — and themed to match your active [Omarchy](https://omarchy.org) theme automatically.

## Features

- **Languages**: Go, Python, JavaScript
- **Snippet sources**:
  - **Local bank** (default) — bundled, idiomatic snippets, no network required
  - **GitHub fetch** — pulls a random real file from a curated set of well-known
    repos per language (`gin-gonic/gin`, `psf/requests`, `lodash/lodash`, etc.),
    trimmed to a reasonable typing length. Falls back to the local bank
    automatically if the network is unavailable.
- **Stats**: WPM, raw WPM, accuracy, time, error count — shown on completion
- **Omarchy theming**: reads your active theme's `colors.toml` at startup
  (`~/.local/state/omarchy/current/theme/colors.toml`, with a fallback to
  the older `~/.config/omarchy/current/theme/colors.toml` path) so the
  app's colors always match your system theme. Works standalone (with a
  built-in Tokyo Night-style palette) if Omarchy isn't present.

## Build

Requires Go 1.22+.

```bash
go build -o typetui .
```

## Run

```bash
./typetui
```

## Controls

**Selection screen**
- `↑`/`↓` or `j`/`k` — choose language
- `←`/`→`, `h`/`l`, or `Tab` — toggle source (local bank / GitHub fetch)
- `Enter` / `Space` — start
- `q` / `Ctrl+C` — quit

**Typing screen**
- Type the snippet as shown; correct characters highlight, mistakes are
  marked in red. Backspace works normally.
- `Esc` — cancel and return to the selection screen

**Results screen**
- `r` / `Enter` / `Space` — retry with the same language/source
- `Esc` — back to selection screen
- `q` / `Ctrl+C` — quit

## Project layout

```
main.go                        entrypoint
internal/
  theme/      theme.go         Omarchy colors.toml reader + lipgloss styles
  snippets/   snippets.go      local bank loader + GitHub fetch logic
              bank/            embedded snippet files (go/python/javascript)
  stats/      stats.go         WPM/accuracy calculation
  ui/         ui.go            bubbletea model: select → typing → results
```

### Adding more local snippets

Drop a new file into `internal/snippets/bank/<language>/`. For Go snippets,
name the file `name.go.txt` (not `.go`) — this keeps `go build` from trying
to compile it as a package, since snippet files intentionally have no
`package` clause. The `.txt` suffix is stripped automatically when the
snippet is displayed in the UI. Python and JavaScript snippets use their
normal `.py` / `.js` extensions since those aren't picked up by the Go
toolchain.

### Adding more GitHub seed repos

Edit the `seedRepos` map in `internal/snippets/snippets.go`. Keep repos
well-known and idiomatic — the fetcher already filters out test files,
vendored code, and minified/generated output, but a low-quality seed repo
will still produce low-quality snippets.
