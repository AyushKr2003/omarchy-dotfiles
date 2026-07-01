package ui

import (
	"strings"

	"github.com/charmbracelet/lipgloss"
)

// renderKeyboard returns a finger-coloured QWERTY keyboard flanked by
// hand/finger diagrams (exactly 5 lines: 4 key rows + space bar).
// The finger that should press nextChar is highlighted on both the key
// and the corresponding finger column in the hand art.
func (m Model) renderKeyboard(nextChar rune, availWidth int) string {
	t := m.styles.Theme

	// ── shift & base key ─────────────────────────────────────────────
	needsShift := (nextChar >= 'A' && nextChar <= 'Z') ||
		strings.ContainsRune(`~!@#$%^&*()_+{}|:"<>?`, nextChar)
	shiftedToBase := map[rune]rune{
		'~': '`', '!': '1', '@': '2', '#': '3', '$': '4', '%': '5',
		'^': '6', '&': '7', '*': '8', '(': '9', ')': '0', '_': '-',
		'+': '=', '{': '[', '}': ']', '|': '\\', ':': ';', '"': '\'',
		'<': ',', '>': '.', '?': '/',
	}
	baseChar := nextChar
	if nextChar >= 'A' && nextChar <= 'Z' {
		baseChar = nextChar - 'A' + 'a'
	}
	if b, ok := shiftedToBase[nextChar]; ok {
		baseChar = b
	}
	isEnter := nextChar == '\n'
	isSpace := nextChar == ' '

	// ── colors & styles ───────────────────────────────────────────────
	fingerFg := [9]lipgloss.Color{
		lipgloss.Color(t.Red),     // 0 L-pinky
		lipgloss.Color(t.Orange),  // 1 L-ring
		lipgloss.Color(t.Blue),    // 2 L-middle
		lipgloss.Color(t.Green),   // 3 L-index
		lipgloss.Color(t.Green),   // 4 R-index
		lipgloss.Color(t.Cyan),    // 5 R-middle
		lipgloss.Color(t.Orange),  // 6 R-ring
		lipgloss.Color(t.Red),     // 7 R-pinky
		lipgloss.Color(t.Magenta), // 8 thumb
	}
	activeStyle := lipgloss.NewStyle().
		Background(lipgloss.Color(t.BrightF)).
		Foreground(lipgloss.Color(t.DarkBg)).
		Bold(true)
	shiftHiStyle := lipgloss.NewStyle().
		Background(lipgloss.Color(t.Red)).
		Foreground(lipgloss.Color(t.BrightF)).
		Bold(true)
	fgStyle := func(finger int) lipgloss.Style {
		return lipgloss.NewStyle().Foreground(fingerFg[finger])
	}

	// ── key layout ────────────────────────────────────────────────────
	type kDef struct {
		label  string
		lower  rune
		upper  rune
		finger int
	}
	rows := [][]kDef{
		{{"`", '`', '~', 0}, {"1", '1', '!', 0}, {"2", '2', '@', 1},
			{"3", '3', '#', 2}, {"4", '4', '$', 3}, {"5", '5', '%', 3},
			{"6", '6', '^', 4}, {"7", '7', '&', 4}, {"8", '8', '*', 5},
			{"9", '9', '(', 6}, {"0", '0', ')', 7}, {"-", '-', '_', 7},
			{"=", '=', '+', 7}, {"\u232b", 0, 0, 7}},
		{{"\u21e5", 0, 0, 0}, {"q", 'q', 'Q', 0}, {"w", 'w', 'W', 1},
			{"e", 'e', 'E', 2}, {"r", 'r', 'R', 3}, {"t", 't', 'T', 3},
			{"y", 'y', 'Y', 4}, {"u", 'u', 'U', 4}, {"i", 'i', 'I', 5},
			{"o", 'o', 'O', 6}, {"p", 'p', 'P', 7}, {"[", '[', '{', 7},
			{"]", ']', '}', 7}, {"\\", '\\', '|', 7}},
		{{"\u21ea", 0, 0, 0}, {"a", 'a', 'A', 0}, {"s", 's', 'S', 1},
			{"d", 'd', 'D', 2}, {"f", 'f', 'F', 3}, {"g", 'g', 'G', 3},
			{"h", 'h', 'H', 4}, {"j", 'j', 'J', 4}, {"k", 'k', 'K', 5},
			{"l", 'l', 'L', 6}, {";", ';', ':', 7}, {"'", '\'', '"', 7},
			{"\u21b5", 0, 0, 7}},
		{{"\u21e7", 0, 0, 0}, {"z", 'z', 'Z', 0}, {"x", 'x', 'X', 1},
			{"c", 'c', 'C', 2}, {"v", 'v', 'V', 3}, {"b", 'b', 'B', 3},
			{"n", 'n', 'N', 4}, {"m", 'm', 'M', 4}, {",", ',', '<', 5},
			{".", '.', '>', 6}, {"/", '/', '?', 7}, {"\u21e7", 0, 0, 7}},
	}

	// ── active finger ─────────────────────────────────────────────────
	activeFinger := 8 // default: thumb (space)
	if !isSpace {
		for _, row := range rows {
			for _, k := range row {
				if (k.lower != 0 && k.lower == baseChar) ||
					(k.label == "\u21b5" && isEnter) {
					activeFinger = k.finger
				}
			}
		}
	}

	// ── build keyboard row strings ────────────────────────────────────
	renderKey := func(label string, finger int, active, shiftHi bool) string {
		padded := " " + label + " "
		switch {
		case active:
			return activeStyle.Render(padded)
		case shiftHi:
			return shiftHiStyle.Render(padded)
		default:
			return fgStyle(finger).Render(padded)
		}
	}

	kbdLines := make([]string, 5) // 4 key rows + space
	for ri, row := range rows {
		var buf strings.Builder
		for ki, k := range row {
			if ki > 0 {
				buf.WriteString(" ")
			}
			isActive := (k.lower != 0 && k.lower == baseChar) ||
				(k.label == "\u21b5" && isEnter)
			buf.WriteString(renderKey(k.label, k.finger, isActive, needsShift && k.label == "\u21e7"))
		}
		kbdLines[ri] = buf.String()
	}
	// Space bar
	spaceContent := "          space          "
	if isSpace {
		kbdLines[4] = activeStyle.Render(spaceContent)
	} else {
		kbdLines[4] = fgStyle(8).Render(spaceContent)
	}

	// Normalise all keyboard lines to the same visual width.
	maxKbdW := 0
	for _, l := range kbdLines {
		if w := lipgloss.Width(l); w > maxKbdW {
			maxKbdW = w
		}
	}
	for i, l := range kbdLines {
		align := lipgloss.Left
		if i == 4 {
			align = lipgloss.Center
		}
		kbdLines[i] = lipgloss.NewStyle().Width(maxKbdW).Align(align).Render(l)
	}

	// ── finger / hand art ────────────────────────────────────────────
	type fCol struct {
		idx   int
		label string
	}
	leftCols := []fCol{{0, "p"}, {1, "r"}, {2, "m"}, {3, "i"}}
	rightCols := []fCol{{4, "i"}, {5, "m"}, {6, "r"}, {7, "p"}}

	renderFCol := func(ch string, fingerIdx int) string {
		if fingerIdx == activeFinger {
			return activeStyle.Render(ch)
		}
		return fgStyle(fingerIdx).Render(ch)
	}

	fingerRow := func(cols []fCol, ch string, useLabel bool) string {
		var buf strings.Builder
		for ci, c := range cols {
			if ci > 0 {
				buf.WriteString(" ")
			}
			label := ch
			if useLabel {
				label = c.label
			}
			buf.WriteString(renderFCol(label, c.idx))
		}
		return buf.String()
	}

	sideW := lipgloss.Width(fingerRow(leftCols, "|", false))

	thumbCh := "\u25be"
	thumbActive := activeFinger == 8

	makeThumb := func(side string) string {
		var rendered string
		if thumbActive {
			rendered = activeStyle.Render(thumbCh)
		} else {
			rendered = fgStyle(8).Render(thumbCh)
		}
		gap := strings.Repeat(" ", sideW-1)
		if side == "left" {
			return gap + rendered
		}
		return rendered + gap
	}

	leftArt := [5]string{
		fingerRow(leftCols, "", true),
		fingerRow(leftCols, "┃", false),
		fingerRow(leftCols, "┃", false),
		fingerRow(leftCols, "┃", false),
		makeThumb("left"),
	}
	rightArt := [5]string{
		fingerRow(rightCols, "", true),
		fingerRow(rightCols, "┃", false),
		fingerRow(rightCols, "┃", false),
		fingerRow(rightCols, "┃", false),
		makeThumb("right"),
	}

	// ── compose rows and centre in availWidth ─────────────────────────
	totalW := sideW + 2 + maxKbdW + 2 + sideW
	leftMargin := (availWidth - totalW) / 2
	if leftMargin < 0 {
		leftMargin = 0
	}
	pad := strings.Repeat(" ", leftMargin)

	var sb strings.Builder
	for i := 0; i < 5; i++ {
		rightPad := lipgloss.NewStyle().Width(sideW).Render(rightArt[i])
		sb.WriteString(pad)
		sb.WriteString(leftArt[i])
		sb.WriteString("  ")
		sb.WriteString(kbdLines[i])
		sb.WriteString("  ")
		sb.WriteString(rightPad)
		if i < 4 {
			sb.WriteString("\n")
		}
	}
	return sb.String()
}
