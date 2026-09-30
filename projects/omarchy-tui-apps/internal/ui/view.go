package ui

import (
	"fmt"
	"strings"

	"github.com/charmbracelet/lipgloss"
	"github.com/charmbracelet/x/ansi"
	"omarchy-tui-apps/internal/desktop"
	"omarchy-tui-apps/internal/theme"
)

const (
	boxTL = "╭"
	boxTR = "╮"
	boxBL = "╰"
	boxBR = "╯"
	boxH  = "─"
	boxV  = "│"
	boxLT = "├"
	boxRT = "┤"
)

// styles are derived from the theme once, and again whenever it changes.
type styles struct {
	border, muted, fg, name, accent, label, hi, err lipgloss.Style
	selPad, selBar, selName, selSub, selHi          lipgloss.Style
	iconApp, iconFlatpak, iconTerm                  lipgloss.Style
	selBg                                           lipgloss.TerminalColor
}

func newStyles(th theme.Theme) styles {
	fg := func(c lipgloss.TerminalColor) lipgloss.Style {
		return lipgloss.NewStyle().Foreground(c)
	}
	sel := func(c lipgloss.TerminalColor) lipgloss.Style {
		return fg(c).Background(th.SelBg)
	}
	return styles{
		border:      fg(th.Border),
		muted:       fg(th.Muted),
		fg:          fg(th.Fg),
		name:        fg(th.Fg),
		accent:      fg(th.Accent).Bold(true),
		label:       fg(th.Muted).Bold(true),
		hi:          fg(th.Accent).Bold(true),
		err:         fg(th.Red),
		selPad:      lipgloss.NewStyle().Background(th.SelBg),
		selBar:      sel(th.SelFg),
		selName:     sel(th.SelFg).Bold(true),
		selSub:      sel(th.SelMuted),
		selHi:       sel(th.SelFg).Bold(true).Underline(true),
		iconApp:     fg(th.Blue),
		iconFlatpak: fg(th.Magenta),
		iconTerm:    fg(th.Green),
		selBg:       th.SelBg,
	}
}

func (st styles) icon(app desktop.AppItem) lipgloss.Style {
	switch {
	case app.Flatpak:
		return st.iconFlatpak
	case app.Icon == desktop.IconTerminal:
		return st.iconTerm
	}
	return st.iconApp
}

func (m Model) View() string {
	if m.width == 0 || m.height == 0 {
		return ""
	}
	if m.width < minWidth || m.height < minHeight {
		return m.st.muted.Render(ansi.Truncate("window too small", m.width, "…"))
	}

	l := m.Lay()
	list := m.listBox(l)
	var prev []string
	if l.PrevW > 0 {
		prev = m.previewBox(l)
	}

	rows := make([]string, 0, m.height)
	for i, line := range list {
		row := " " + line
		if prev != nil {
			row += spaces(gap) + prev[i]
		}
		rows = append(rows, row)
	}
	rows = append(rows, m.footer())
	return strings.Join(rows, "\n")
}

// topBorder draws a box's top edge with a title on the left and an optional
// info label on the right, dropping whichever does not fit.
func (m Model) topBorder(w int, title, info string) string {
	st := m.st
	title, info = " "+title+" ", " "+info+" "
	if info == "  " || ansi.StringWidth(title)+ansi.StringWidth(info)+4 > w {
		info = ""
	}
	if ansi.StringWidth(title)+4 > w {
		title = ""
	}
	fill := w - 4 - ansi.StringWidth(title) - ansi.StringWidth(info)
	return st.border.Render(boxTL+boxH) + st.accent.Render(title) +
		st.border.Render(strings.Repeat(boxH, fill)) + st.muted.Render(info) +
		st.border.Render(boxH+boxTR)
}

func (m Model) listBox(l Layout) []string {
	st := m.st
	inner := l.ListW - 2
	edge := st.border.Render(boxV)
	lines := make([]string, 0, l.BodyH+4)

	title := desktop.IconApp + " Apps"
	if m.showAll {
		title = desktop.IconApp + " All apps"
	}
	count := "0"
	if n := len(m.visible); n > 0 {
		count = fmt.Sprintf("%d/%d", m.cursor+1, n)
	}
	lines = append(lines, m.topBorder(l.ListW, title, count))

	// search row: " <prompt> query▎ "
	prompt := " " + desktop.IconPrompt + " "
	queryW := inner - ansi.StringWidth(prompt) - 2
	var search string
	if m.query == "" {
		search = st.accent.Render(prompt) + st.accent.Render("▎") +
			st.muted.Render(ansi.Truncate("Search apps", max(0, queryW), "…"))
	} else {
		search = st.accent.Render(prompt) + st.fg.Render(tail(m.query, queryW)) +
			st.accent.Render("▎")
	}
	lines = append(lines, edge+fit(search, inner)+edge)
	lines = append(lines, st.border.Render(boxLT+strings.Repeat(boxH, inner)+boxRT))

	// scrollbar thumb, drawn over the right edge
	thumbTop, thumbH := 0, 0
	if n := len(m.visible); n > l.BodyH {
		thumbH = max(1, l.BodyH*l.BodyH/n)
		thumbTop = m.offset * (l.BodyH - thumbH) / (n - l.BodyH)
	}

	for row := 0; row < l.BodyH; row++ {
		idx := m.offset + row
		var content string
		switch {
		case idx < len(m.visible):
			content = m.listRow(m.visible[idx], idx == m.cursor, inner)
		case row == 0 && len(m.visible) == 0:
			content = fit(st.muted.Render("   No matching apps"), inner)
		default:
			content = spaces(inner)
		}
		right := edge
		if row >= thumbTop && row < thumbTop+thumbH {
			right = st.accent.Render("┃")
		}
		lines = append(lines, edge+content+right)
	}

	lines = append(lines, st.border.Render(boxBL+strings.Repeat(boxH, inner)+boxBR))
	return lines
}

// listRow renders one app as exactly w cells:
// bar, space, icon (2), space, name column, [2 spaces, subtitle column], space.
func (m Model) listRow(app desktop.AppItem, selected bool, w int) string {
	st := m.st
	pad, bar, icon, name, sub, hi := lipgloss.NewStyle(), " ", st.icon(app), st.name, st.muted, st.hi
	if selected {
		pad, bar, name, sub, hi = st.selPad, "▌", st.selName, st.selSub, st.selHi
		icon = icon.Background(st.selBg)
	}

	avail := w - 6
	nameW, subW := avail, 0
	if col := min(max(avail*45/100, 14), 32); avail-col-2 >= 10 {
		nameW, subW = col, avail-col-2
	}

	nm := ansi.Truncate(app.Name, nameW, "…")
	out := st.selBar.Render(bar)
	if !selected {
		out = bar
	}
	out += pad.Render(" ") + icon.Render(IconPad(app.Icon, 2)) + pad.Render(" ") +
		highlight(nm, m.tokens, name, hi) + pad.Render(spaces(nameW-ansi.StringWidth(nm)))
	if subW > 0 {
		out += pad.Render("  ") + sub.Render(fit(app.SubTitle, subW))
	}
	return out + pad.Render(" ")
}

func (m Model) footer() string {
	st := m.st
	w := m.width - 2
	switch {
	case m.launchErr != "":
		return " " + st.err.Render(ansi.Truncate("error: "+m.launchErr, w, "…"))
	case m.launching:
		return " " + st.muted.Render(ansi.Truncate("launching…", w, "…"))
	}
	toggle := "all apps"
	if m.showAll {
		toggle = "hide extras"
	}
	hints := [][2]string{
		{"↑↓", "move"}, {"enter", "launch"}, {"ctrl+h", toggle}, {"ctrl+u", "clear"}, {"esc", "quit"},
	}
	var out string
	used := 0
	for i, h := range hints {
		sep := ""
		if i > 0 {
			sep = "   "
		}
		need := ansi.StringWidth(sep + h[0] + " " + h[1])
		if used+need > w {
			break
		}
		out += sep + st.fg.Render(h[0]) + " " + st.muted.Render(h[1])
		used += need
	}
	return " " + out
}
