// Package theme maps Omarchy's colors.toml onto the launcher's palette.
package theme

import (
	"fmt"
	"math"
	"os"
	"path/filepath"
	"strings"

	"github.com/charmbracelet/lipgloss"
)

type Theme struct {
	Fg     lipgloss.TerminalColor
	Muted  lipgloss.TerminalColor
	Border lipgloss.TerminalColor
	Accent lipgloss.TerminalColor

	SelBg    lipgloss.TerminalColor
	SelFg    lipgloss.TerminalColor
	SelMuted lipgloss.TerminalColor

	Red     lipgloss.TerminalColor
	Green   lipgloss.TerminalColor
	Blue    lipgloss.TerminalColor
	Magenta lipgloss.TerminalColor
}

// Terminal is the palette used when no Omarchy theme can be read. It only
// uses the terminal's own ANSI colors, so it still follows the terminal theme.
func Terminal() Theme {
	return Theme{
		Fg:       lipgloss.NoColor{},
		Muted:    lipgloss.Color("8"),
		Border:   lipgloss.Color("8"),
		Accent:   lipgloss.Color("4"),
		SelBg:    lipgloss.Color("4"),
		SelFg:    lipgloss.Color("0"),
		SelMuted: lipgloss.Color("0"),
		Red:      lipgloss.Color("1"),
		Green:    lipgloss.Color("2"),
		Blue:     lipgloss.Color("4"),
		Magenta:  lipgloss.Color("5"),
	}
}

// Source locates the active theme's colors.toml.
type Source struct {
	paths []string
}

// NewSource returns a Source for override if set, otherwise for the known
// locations of Omarchy's current theme.
func NewSource(override string) Source {
	if override != "" {
		return Source{paths: []string{override}}
	}
	home, _ := os.UserHomeDir()
	state := os.Getenv("XDG_STATE_HOME")
	if state == "" {
		state = filepath.Join(home, ".local/state")
	}
	return Source{paths: []string{
		filepath.Join(state, "omarchy/current/theme/colors.toml"),
		filepath.Join(home, ".config/omarchy/current/theme/colors.toml"),
	}}
}

// Read returns the raw contents of the first readable colors file.
func (s Source) Read() (string, bool) {
	for _, p := range s.paths {
		if b, err := os.ReadFile(p); err == nil && len(b) > 0 {
			return string(b), true
		}
	}
	return "", false
}

// Parse builds a Theme from colors.toml contents. Anything the file does not
// define falls back to the terminal's ANSI colors.
func Parse(raw string) Theme {
	kv := map[string]string{}
	for _, line := range strings.Split(raw, "\n") {
		key, val, ok := strings.Cut(line, "=")
		if !ok {
			continue
		}
		val = strings.TrimSpace(val)
		if i := strings.IndexByte(val, '#'); i >= 0 {
			val = val[i:]
		}
		if i := strings.IndexAny(val, "\"' \t"); i >= 0 {
			val = val[:i]
		}
		if _, ok := rgb(val); ok {
			kv[strings.TrimSpace(key)] = val
		}
	}
	get := func(keys ...string) (string, bool) {
		for _, k := range keys {
			if v, ok := kv[k]; ok {
				return v, true
			}
		}
		return "", false
	}
	set := func(dst *lipgloss.TerminalColor, keys ...string) {
		if v, ok := get(keys...); ok {
			*dst = lipgloss.Color(v)
		}
	}

	t := Terminal()
	fg, hasFg := get("foreground", "fg")
	bg, hasBg := get("background", "bg")

	set(&t.Fg, "foreground", "fg")
	set(&t.Red, "red", "color1")
	set(&t.Green, "green", "color2")
	set(&t.Blue, "blue", "color4")
	set(&t.Magenta, "magenta", "color5")

	accent, hasAccent := get("accent", "blue", "color4")
	if hasAccent {
		t.Accent = lipgloss.Color(accent)
	}

	muted, hasMuted := get("muted", "dark_foreground", "color8")
	if !hasMuted && hasFg && hasBg {
		muted, hasMuted = mix(bg, fg, 0.45), true
	}
	if hasMuted {
		t.Muted = lipgloss.Color(muted)
		t.Border = t.Muted
	}

	sel, hasSel := get("selection", "selection_background")
	if !hasSel && hasFg && hasBg {
		sel, hasSel = mix(bg, fg, 0.14), true
	}
	if hasSel {
		// Pick readable text for the selection: themes disagree on whether
		// "selection" is a subtle tint or a loud highlight.
		var cands []string
		if hasAccent {
			cands = append(cands, accent)
		}
		if v, ok := get("selection_foreground"); ok {
			cands = append(cands, v)
		}
		if hasFg {
			cands = append(cands, fg)
		}
		if hasBg {
			cands = append(cands, bg)
		}
		if selFg, ok := readable(sel, cands); ok {
			t.SelBg = lipgloss.Color(sel)
			t.SelFg = lipgloss.Color(selFg)
			t.SelMuted = t.SelFg
			if hasMuted && contrast(muted, sel) >= 2.5 {
				t.SelMuted = lipgloss.Color(muted)
			}
		}
	}
	return t
}

// readable returns the first candidate with solid contrast against bg, or
// failing that the one with the most contrast.
func readable(bg string, cands []string) (string, bool) {
	best, bestC := "", 0.0
	for _, c := range cands {
		cc := contrast(c, bg)
		if cc >= 3 {
			return c, true
		}
		if cc > bestC {
			best, bestC = c, cc
		}
	}
	return best, best != ""
}

func rgb(hex string) ([3]float64, bool) {
	var out [3]float64
	if !strings.HasPrefix(hex, "#") {
		return out, false
	}
	h := hex[1:]
	if len(h) == 3 {
		h = string([]byte{h[0], h[0], h[1], h[1], h[2], h[2]})
	}
	if len(h) != 6 {
		return out, false
	}
	var r, g, b uint8
	if n, err := fmt.Sscanf(h, "%02x%02x%02x", &r, &g, &b); err != nil || n != 3 {
		return out, false
	}
	return [3]float64{float64(r), float64(g), float64(b)}, true
}

func mix(a, b string, amount float64) string {
	ca, _ := rgb(a)
	cb, _ := rgb(b)
	var o [3]int
	for i := range o {
		o[i] = int(math.Round(ca[i] + (cb[i]-ca[i])*amount))
	}
	return fmt.Sprintf("#%02x%02x%02x", o[0], o[1], o[2])
}

func luminance(hex string) float64 {
	c, _ := rgb(hex)
	lin := func(v float64) float64 {
		v /= 255
		if v <= 0.03928 {
			return v / 12.92
		}
		return math.Pow((v+0.055)/1.055, 2.4)
	}
	return 0.2126*lin(c[0]) + 0.7152*lin(c[1]) + 0.0722*lin(c[2])
}

func contrast(a, b string) float64 {
	la, lb := luminance(a), luminance(b)
	if la < lb {
		la, lb = lb, la
	}
	return (la + 0.05) / (lb + 0.05)
}
