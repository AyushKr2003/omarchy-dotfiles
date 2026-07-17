package preview

import (
	"fmt"
	"strings"

	"github.com/charmbracelet/lipgloss"

	"omarchy-colorgen/internal/palette"
)

// Swatches renders a labeled grid of palette colors. Each swatch shows the
// color as a background block with its hex value, so contrast is visible.
func Swatches(p palette.Palette) string {
	type sw struct{ name, hex string }
	rows := [][]sw{
		{{"bg", p.Bg}, {"fg", p.Fg}, {"accent", p.Accent}, {"select", p.Selection}},
		{{"red", p.Red}, {"green", p.Green}, {"yellow", p.Yellow}, {"orange", p.Orange}},
		{{"blue", p.Blue}, {"magenta", p.Magenta}, {"cyan", p.Cyan}, {"brown", p.Brown}},
		{{"br.red", p.BrightRed}, {"br.grn", p.BrightGreen}, {"br.blu", p.BrightBlue}, {"br.mag", p.BrightMagenta}},
	}

	var lines []string
	for _, row := range rows {
		var cells []string
		for _, s := range row {
			cells = append(cells, swatchCell(s.name, s.hex))
		}
		lines = append(lines, lipgloss.JoinHorizontal(lipgloss.Top, cells...))
	}
	return strings.Join(lines, "\n")
}

func swatchCell(name, hex string) string {
	fg := readableOn(hex)
	block := lipgloss.NewStyle().
		Background(lipgloss.Color(hex)).
		Foreground(lipgloss.Color(fg)).
		Width(16).
		Padding(0, 1).
		Render(fmt.Sprintf("%-7s %s", name, hex))
	return block
}

// MockUI renders a small fake application window (title bar, code snippet using
// the syntax colors, and a status line) painted with the palette so the user
// can judge the theme in context.
func MockUI(p palette.Palette) string {
	card := lipgloss.NewStyle().
		Background(lipgloss.Color(p.Bg)).
		Foreground(lipgloss.Color(p.Fg)).
		Padding(1, 2).
		Width(46)

	title := lipgloss.NewStyle().
		Foreground(lipgloss.Color(p.Accent)).
		Bold(true).
		Render("● ● ●  ~/project — nvim")

	kw := colorOr(p.SyntaxKeyword, p.Magenta)
	fn := colorOr(p.SyntaxFunc, p.Cyan)
	str := colorOr(p.SyntaxString, p.Green)
	com := colorOr(p.SyntaxComment, p.Muted)
	typ := colorOr(p.SyntaxType, p.Yellow)

	line := func(parts ...string) string { return strings.Join(parts, "") }
	code := strings.Join([]string{
		style(com, "// build the greeting"),
		line(style(kw, "func "), style(fn, "greet"), style(p.Fg, "("), style(typ, "name string"), style(p.Fg, ") {")),
		line("  ", style(fn, "print"), style(p.Fg, "("), style(str, "\"hi, \""), style(p.Fg, " + name)")),
		style(p.Fg, "}"),
	}, "\n")

	prompt := line(
		style(p.Green, "user"),
		style(p.Muted, "@"),
		style(p.Blue, "omarchy"),
		style(p.Fg, " $ "),
		style(p.Accent, "omarchy theme set"),
	)

	sel := lipgloss.NewStyle().
		Background(lipgloss.Color(p.Selection)).
		Foreground(lipgloss.Color(p.BrightFg)).
		Render(" selected text ")

	body := strings.Join([]string{title, "", code, "", prompt, "", sel}, "\n")
	return card.Render(body)
}

func style(hex, text string) string {
	return lipgloss.NewStyle().Foreground(lipgloss.Color(hex)).Render(text)
}

func colorOr(primary, fallback string) string {
	if primary == "" {
		return fallback
	}
	return primary
}

// readableOn returns black or white depending on the background's brightness so
// swatch labels stay legible.
func readableOn(hex string) string {
	c, err := palette.ParseHex(hex)
	if err != nil {
		return "#ffffff"
	}
	// Perceived luminance (Rec. 601-ish) on 0..255.
	lum := 0.299*float64(c.R) + 0.587*float64(c.G) + 0.114*float64(c.B)
	if lum > 140 {
		return "#000000"
	}
	return "#ffffff"
}
