package palette

import (
	"testing"

	"omarchy-colorgen/internal/iris"
)

func sampleTheme() iris.Theme {
	return iris.Theme{
		Bg:            "#181825",
		Surface:       "#26263b",
		Fg:            "#daabf0",
		Dim:           "#54546e",
		Accent:        "#d9a8f0",
		Red:           "#eea0d9",
		Green:         "#54a2b6",
		Yellow:        "#eea0d9",
		Dark:          true,
		SyntaxKeyword: "#95d0c1",
		SyntaxFunc:    "#c1d095",
	}
}

func TestFromIrisMapping(t *testing.T) {
	p := FromIris(sampleTheme())

	if p.Mode != "dark" {
		t.Errorf("mode = %q want dark", p.Mode)
	}
	if p.Bg != "#181825" || p.Fg != "#daabf0" || p.Accent != "#d9a8f0" {
		t.Errorf("base passthrough wrong: %+v", p)
	}
	// blue <- accent, magenta <- syntax_keyword, cyan <- syntax_func
	if p.Blue != "#d9a8f0" {
		t.Errorf("blue = %q want accent", p.Blue)
	}
	if p.Magenta != "#95d0c1" {
		t.Errorf("magenta = %q want syntax_keyword", p.Magenta)
	}
	if p.Cyan != "#c1d095" {
		t.Errorf("cyan = %q want syntax_func", p.Cyan)
	}
	// surface -> selection/lighter_bg, dim -> muted/dark_fg
	if p.Selection != "#26263b" || p.LighterBg != "#26263b" {
		t.Errorf("surface mapping wrong: sel=%q lighter=%q", p.Selection, p.LighterBg)
	}
	if p.Muted != "#54546e" || p.DarkFg != "#54546e" {
		t.Errorf("dim mapping wrong: muted=%q dark_fg=%q", p.Muted, p.DarkFg)
	}
}

func TestFromIrisDerived(t *testing.T) {
	p := FromIris(sampleTheme())
	// dark_bg = mix(#181825, #000, 25%); darker = 50%
	if p.DarkBg != Darken(MustHex("#181825"), 0.25).Hex() {
		t.Errorf("dark_bg = %q", p.DarkBg)
	}
	if p.DarkerBg != Darken(MustHex("#181825"), 0.50).Hex() {
		t.Errorf("darker_bg = %q", p.DarkerBg)
	}
	if p.BrightRed != Lighten(MustHex("#eea0d9"), 0.20).Hex() {
		t.Errorf("bright_red = %q", p.BrightRed)
	}
	// orange = mix(red, yellow, 0.5); brown = darken(orange, 0.5)
	orange := Mix(MustHex("#eea0d9"), MustHex("#eea0d9"), 0.5).Hex()
	if p.Orange != orange {
		t.Errorf("orange = %q want %q", p.Orange, orange)
	}
}

func TestLightMode(t *testing.T) {
	th := sampleTheme()
	th.Dark = false
	if FromIris(th).Mode != "light" {
		t.Error("expected light mode")
	}
}
