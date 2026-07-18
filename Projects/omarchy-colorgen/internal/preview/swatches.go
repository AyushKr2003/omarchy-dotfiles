package preview

import (
	"fmt"
	"strings"

	"github.com/charmbracelet/lipgloss"

	"omarchy-colorgen/internal/palette"
)

// Swatches renders a labeled grid of palette colors. Each swatch shows the
// color as a background block with its hex value, so contrast is visible.
// When width > 0 the cells are sized to fit inside that many columns, and
// the grid auto-selects 4 or 2 columns based on the available width.
func Swatches(p palette.Palette, width int) string {
	type sw struct{ name, hex string }
	fourCol := [][]sw{
		{{"bg", p.Bg}, {"fg", p.Fg}, {"accent", p.Accent}, {"select", p.Selection}},
		{{"red", p.Red}, {"green", p.Green}, {"yellow", p.Yellow}, {"orange", p.Orange}},
		{{"blue", p.Blue}, {"magenta", p.Magenta}, {"cyan", p.Cyan}, {"brown", p.Brown}},
		{{"br.red", p.BrightRed}, {"br.grn", p.BrightGreen}, {"br.blu", p.BrightBlue}, {"br.mag", p.BrightMagenta}},
	}
	twoCol := [][]sw{
		{{"bg", p.Bg}, {"fg", p.Fg}},
		{{"accent", p.Accent}, {"select", p.Selection}},
		{{"red", p.Red}, {"green", p.Green}},
		{{"yellow", p.Yellow}, {"orange", p.Orange}},
		{{"blue", p.Blue}, {"magenta", p.Magenta}},
		{{"cyan", p.Cyan}, {"brown", p.Brown}},
		{{"br.red", p.BrightRed}, {"br.grn", p.BrightGreen}},
		{{"br.blu", p.BrightBlue}, {"br.mag", p.BrightMagenta}},
	}

	use4 := false
	nCol := 2
	cellW := 16
	if width > 0 {
		if width >= 56 {
			use4 = true
			cellW = (width - 8) / 4
			if cellW < 10 {
				cellW = 10
			}
		} else {
			cellW = (width - 4) / 2
			if cellW < 12 {
				cellW = 12
			}
		}
	} else {
		use4 = true
	}

	rows := twoCol
	if use4 {
		rows = fourCol
		nCol = 4
	}

	var lines []string
	for _, row := range rows {
		var cells []string
		for _, s := range row {
			cells = append(cells, swatchCell(s.name, s.hex, cellW, use4))
		}
		// Pad short rows to match column count for consistent alignment.
		for len(cells) < nCol {
			cells = append(cells, strings.Repeat(" ", cellW+2))
		}
		lines = append(lines, lipgloss.JoinHorizontal(lipgloss.Top, cells...))
	}
	return strings.Join(lines, "\n")
}

func swatchCell(name, hex string, w int, tall bool) string {
	fg := readableOn(hex)
	vPad := 0
	if tall {
		vPad = 1
	}
	block := lipgloss.NewStyle().
		Background(lipgloss.Color(hex)).
		Foreground(lipgloss.Color(fg)).
		Width(w).
		Padding(vPad, 1).
		Render(fmt.Sprintf("%-7s %s", name, hex))
	return block
}

// MockUI renders a small fake application window (title bar, code snippet using
// the syntax colors, and a status line) painted with the palette so the user
// can judge the theme in context. When width > 0 the card is sized to that
// many columns (including padding).
func MockUI(p palette.Palette, width int) string {
	bg := p.Bg

	cw := 46
	if width > 0 {
		cw = width
	}

	card := lipgloss.NewStyle().
		Background(lipgloss.Color(bg)).
		Foreground(lipgloss.Color(p.Fg)).
		Padding(1, 2).
		Width(cw)

	// Every inline piece must set its own background so ANSI resets from inner
	// style render calls don't clear the card's background for surrounding text.
	title := lipgloss.NewStyle().
		Foreground(lipgloss.Color(p.Accent)).
		Background(lipgloss.Color(bg)).
		Bold(true).
		Render("● ● ●  ~/project — nvim")

	kw := colorOr(p.SyntaxKeyword, p.Magenta)
	fn := colorOr(p.SyntaxFunc, p.Cyan)
	str := colorOr(p.SyntaxString, p.Green)
	com := colorOr(p.SyntaxComment, p.Muted)
	typ := colorOr(p.SyntaxType, p.Yellow)

	on := func(fg, text string) string {
		return lipgloss.NewStyle().
			Background(lipgloss.Color(bg)).
			Foreground(lipgloss.Color(fg)).
			Render(text)
	}
	line := func(parts ...string) string { return strings.Join(parts, "") }
	code := strings.Join([]string{
		on(com, "// build the greeting"),
		line(on(kw, "func "), on(fn, "greet"), on(p.Fg, "("), on(typ, "name string"), on(p.Fg, ") {")),
		line("  ", on(fn, "print"), on(p.Fg, "("), on(str, "\"hi, \""), on(p.Fg, " + name)")),
		on(p.Fg, "}"),
	}, "\n")

	prompt := line(
		on(p.Green, "user"),
		on(p.Muted, "@"),
		on(p.Blue, "omarchy"),
		on(p.Fg, " $ "),
		on(p.Accent, "omarchy theme set"),
	)

	sel := lipgloss.NewStyle().
		Background(lipgloss.Color(p.Selection)).
		Foreground(lipgloss.Color(p.BrightFg)).
		Render(" selected text ")

	body := strings.Join([]string{title, "", code, "", prompt, "", sel}, "\n")
	return card.Render(body)
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
