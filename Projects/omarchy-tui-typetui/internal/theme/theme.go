// Package theme reads the active Omarchy color palette so the TUI matches
// whatever theme the user has selected system-wide. Omarchy stores the
// active theme's colors at ~/.config/omarchy/current/theme/colors.toml
// (older installs) or ~/.local/state/omarchy/current/theme/colors.toml
// (quattro). We check both, falling back to a built-in Tokyo Night-style
// palette if neither exists — e.g. when running outside Omarchy entirely.
package theme

import (
	"os"
	"path/filepath"

	"github.com/BurntSushi/toml"
	"github.com/charmbracelet/lipgloss"
)

// Theme holds the subset of the Omarchy color palette this app cares about.
// Field names match the keys used in Omarchy's colors.toml files.
type Theme struct {
	Mode    string `toml:"mode"`
	Accent  string `toml:"accent"`
	Bg      string `toml:"bg"`
	DarkBg  string `toml:"dark_bg"`
	LightBg string `toml:"lighter_bg"`
	Sel     string `toml:"selection"`
	Muted   string `toml:"muted"`
	DarkFg  string `toml:"dark_fg"`
	Fg      string `toml:"fg"`
	BrightF string `toml:"bright_fg"`

	Red     string `toml:"red"`
	Yellow  string `toml:"yellow"`
	Orange  string `toml:"orange"`
	Green   string `toml:"green"`
	Cyan    string `toml:"cyan"`
	Blue    string `toml:"blue"`
	Magenta string `toml:"magenta"`
	Brown   string `toml:"brown"`
}

// fallback is used when no Omarchy theme file can be found, so the app is
// still usable standalone (e.g. on a non-Omarchy machine for testing).
var fallback = Theme{
	Mode:    "dark",
	Accent:  "#7aa2f7",
	Bg:      "#1a1b26",
	DarkBg:  "#13141c",
	LightBg: "#24283b",
	Sel:     "#292e42",
	Muted:   "#414868",
	DarkFg:  "#565f89",
	Fg:      "#a9b1d6",
	BrightF: "#c0caf5",
	Red:     "#f7768e",
	Yellow:  "#e0af68",
	Orange:  "#eb927b",
	Green:   "#9ece6a",
	Cyan:    "#449dab",
	Blue:    "#7aa2f7",
	Magenta: "#ad8ee6",
	Brown:   "#75493d",
}

// candidatePaths returns, in priority order, the locations Omarchy may have
// written the active theme's colors.toml to.
func candidatePaths() []string {
	home, err := os.UserHomeDir()
	if err != nil {
		return nil
	}
	return []string{
		// Omarchy quattro path.
		filepath.Join(home, ".local", "state", "omarchy", "current", "theme", "colors.toml"),
		// Pre-quattro path, still used by some installs.
		filepath.Join(home, ".config", "omarchy", "current", "theme", "colors.toml"),
	}
}

// Load reads the active Omarchy theme. If OMARCHY_THEME_COLORS is set, that
// path is tried first, mirroring the env var Omarchy's own scripts respect.
func Load() Theme {
	t := fallback

	paths := []string{}
	if p := os.Getenv("OMARCHY_THEME_COLORS"); p != "" {
		paths = append(paths, p)
	}
	paths = append(paths, candidatePaths()...)

	for _, p := range paths {
		if p == "" {
			continue
		}
		data, err := os.ReadFile(p)
		if err != nil {
			continue
		}
		var parsed Theme
		if _, err := toml.Decode(string(data), &parsed); err != nil {
			continue
		}
		mergeNonEmpty(&t, parsed)
		return t
	}

	return t
}

// mergeNonEmpty copies any non-empty field from src into dst, leaving the
// fallback value in place for anything the parsed file didn't define.
func mergeNonEmpty(dst *Theme, src Theme) {
	set := func(field *string, val string) {
		if val != "" {
			*field = val
		}
	}
	set(&dst.Mode, src.Mode)
	set(&dst.Accent, src.Accent)
	set(&dst.Bg, src.Bg)
	set(&dst.DarkBg, src.DarkBg)
	set(&dst.LightBg, src.LightBg)
	set(&dst.Sel, src.Sel)
	set(&dst.Muted, src.Muted)
	set(&dst.DarkFg, src.DarkFg)
	set(&dst.Fg, src.Fg)
	set(&dst.BrightF, src.BrightF)
	set(&dst.Red, src.Red)
	set(&dst.Yellow, src.Yellow)
	set(&dst.Orange, src.Orange)
	set(&dst.Green, src.Green)
	set(&dst.Cyan, src.Cyan)
	set(&dst.Blue, src.Blue)
	set(&dst.Magenta, src.Magenta)
	set(&dst.Brown, src.Brown)
}

// Styles bundles the lipgloss styles derived from a Theme so the rest of the
// app never touches raw hex strings.
type Styles struct {
	Theme Theme

	Base       lipgloss.Style // default text on default background
	Dim        lipgloss.Style // muted/secondary text (untyped chars)
	Cursor     lipgloss.Style // current character to type
	Correct    lipgloss.Style // correctly typed character
	Incorrect  lipgloss.Style // incorrectly typed character
	Accent     lipgloss.Style // accent-colored text (titles, highlights)
	StatLabel  lipgloss.Style // stat row labels
	StatValue  lipgloss.Style // stat row values
	Border     lipgloss.Style // panel border
	HelpText   lipgloss.Style // footer key-hints
	ErrorText  lipgloss.Style // error/red messages
	SuccessTxt lipgloss.Style // success/green messages
}

// NewStyles builds a Styles bundle from a Theme.
func NewStyles(t Theme) Styles {
	base := lipgloss.NewStyle().Foreground(lipgloss.Color(t.Fg))
	return Styles{
		Theme: t,

		Base: base,
		Dim:  lipgloss.NewStyle().Foreground(lipgloss.Color(t.DarkFg)),
		Cursor: lipgloss.NewStyle().
			Foreground(lipgloss.Color(t.Bg)).
			Background(lipgloss.Color(t.Accent)).
			Bold(true),
		Correct:    lipgloss.NewStyle().Foreground(lipgloss.Color(t.BrightF)),
		Incorrect:  lipgloss.NewStyle().Foreground(lipgloss.Color(t.Bg)).Background(lipgloss.Color(t.Red)),
		Accent:     lipgloss.NewStyle().Foreground(lipgloss.Color(t.Accent)).Bold(true),
		StatLabel:  lipgloss.NewStyle().Foreground(lipgloss.Color(t.DarkFg)),
		StatValue:  lipgloss.NewStyle().Foreground(lipgloss.Color(t.Accent)).Bold(true),
		Border:     lipgloss.NewStyle().Foreground(lipgloss.Color(t.Muted)),
		HelpText:   lipgloss.NewStyle().Foreground(lipgloss.Color(t.DarkFg)),
		ErrorText:  lipgloss.NewStyle().Foreground(lipgloss.Color(t.Red)).Bold(true),
		SuccessTxt: lipgloss.NewStyle().Foreground(lipgloss.Color(t.Green)).Bold(true),
	}
}
