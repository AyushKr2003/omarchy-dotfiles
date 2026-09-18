package palette

import "omarchy-colorgen/internal/iris"

// Palette is a fully expanded Omarchy color set, ready to render as colors.toml.
// Every field maps to a colors.toml key. Values are "#rrggbb" strings.
type Palette struct {
	Mode   string // "dark" or "light"
	Accent string

	Background        string
	DarkBackground    string
	DarkerBackground  string
	LighterBackground string
	Selection         string
	Muted             string
	DarkForeground    string
	Foreground        string
	LightForeground   string
	BrightForeground  string

	Red     string
	Yellow  string
	Orange  string
	Green   string
	Cyan    string
	Blue    string
	Magenta string
	Brown   string

	BrightRed     string
	BrightYellow  string
	BrightGreen   string
	BrightCyan    string
	BrightBlue    string
	BrightMagenta string

	// Syntax colors are carried through from iris for the preview mock-up.
	// They are not part of the Omarchy colors.toml schema.
	SyntaxKeyword  string
	SyntaxString   string
	SyntaxFunc     string
	SyntaxType     string
	SyntaxConst    string
	SyntaxParam    string
	SyntaxOperator string
	SyntaxComment  string
}

// FromIris expands an iris theme into a full Omarchy palette.
//
// The base mapping follows iris's own terminal-palette convention
// (color4=accent, color5=syntax_keyword, color6=syntax_func, color7=dim,
// color8=surface); derived shades follow bin/omarchy-theme-color exactly.
func FromIris(t iris.Theme) Palette {
	bg := parse(t.Bg)
	fg := parse(t.Fg)
	surface := parse(t.Surface)
	dim := parse(t.Dim)

	red := parse(t.Red)
	green := parse(t.Green)
	yellow := parse(t.Yellow)
	blue := parse(t.Accent)           // color4
	magenta := parse(t.SyntaxKeyword) // color5
	cyan := parse(t.SyntaxFunc)       // color6

	// orange: Omarchy falls back orange->yellow, but a blend of red+yellow
	// yields a truer orange while staying inside the wallpaper's palette.
	orange := Mix(red, yellow, 0.5)
	brown := Darken(orange, 0.5)

	mode := "dark"
	if !t.Dark {
		mode = "light"
	}

	return Palette{
		Mode:   mode,
		Accent: t.Accent,

		Background:        bg.Hex(),
		DarkBackground:    Darken(bg, 0.25).Hex(),
		DarkerBackground:  Darken(bg, 0.50).Hex(),
		LighterBackground: surface.Hex(),
		Selection:         surface.Hex(),
		Muted:             dim.Hex(),
		DarkForeground:    dim.Hex(),
		Foreground:        fg.Hex(),
		LightForeground:   fg.Hex(),
		BrightForeground:  fg.Hex(),

		Red:     red.Hex(),
		Yellow:  yellow.Hex(),
		Orange:  orange.Hex(),
		Green:   green.Hex(),
		Cyan:    cyan.Hex(),
		Blue:    blue.Hex(),
		Magenta: magenta.Hex(),
		Brown:   brown.Hex(),

		BrightRed:     Lighten(red, 0.20).Hex(),
		BrightYellow:  Lighten(yellow, 0.20).Hex(),
		BrightGreen:   Lighten(green, 0.20).Hex(),
		BrightCyan:    Lighten(cyan, 0.20).Hex(),
		BrightBlue:    Lighten(blue, 0.20).Hex(),
		BrightMagenta: Lighten(magenta, 0.20).Hex(),

		SyntaxKeyword:  t.SyntaxKeyword,
		SyntaxString:   t.SyntaxString,
		SyntaxFunc:     t.SyntaxFunc,
		SyntaxType:     t.SyntaxType,
		SyntaxConst:    t.SyntaxConst,
		SyntaxParam:    t.SyntaxParam,
		SyntaxOperator: t.SyntaxOperator,
		SyntaxComment:  t.SyntaxComment,
	}
}

// parse tolerates bad input by falling back to black; iris output is validated
// upstream, so this only guards against unexpected empty fields.
func parse(s string) RGB {
	c, err := ParseHex(s)
	if err != nil {
		return RGB{}
	}
	return c
}
