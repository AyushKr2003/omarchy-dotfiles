package ui

import (
	"strings"

	"github.com/charmbracelet/x/ansi"
	"omarchy-tui-apps/internal/desktop"
)

// previewBox renders the details box, the same height as the list box.
func (m Model) previewBox(l Layout) []string {
	st := m.st
	inner := l.PrevW - 2
	edge := st.border.Render(boxV)

	lines := make([]string, 0, l.BodyH+4)
	lines = append(lines, m.topBorder(l.PrevW, "Details", ""))
	for _, line := range m.previewLines(inner-2, l.BodyH+2) {
		lines = append(lines, edge+" "+fit(line, inner-2)+" "+edge)
	}
	lines = append(lines, st.border.Render(boxBL+strings.Repeat(boxH, inner)+boxBR))
	return lines
}

// previewLines returns exactly h lines describing the selected app.
func (m Model) previewLines(w, h int) []string {
	st := m.st
	var lines []string
	add := func(s string) { lines = append(lines, s) }
	section := func(label, value string) {
		if value == "" {
			return
		}
		add("")
		add(st.label.Render(label))
		for _, l := range wrap(value, w) {
			add(st.fg.Render(l))
		}
	}

	if m.cursor < len(m.visible) && w > 0 {
		sel := m.visible[m.cursor]
		icon := IconPad(sel.Icon, 2) + " "
		indent := spaces(ansi.StringWidth(icon))
		textW := max(0, w-ansi.StringWidth(icon))

		kind := "Desktop app"
		switch {
		case sel.Flatpak:
			kind = "Flatpak"
		case sel.Icon == desktop.IconTerminal:
			kind = "Terminal app"
		}

		add("")
		add(st.icon(sel).Render(icon) + st.accent.Render(ansi.Truncate(sel.Name, textW, "…")))
		if sel.SubTitle != "" {
			add(indent + st.muted.Render(ansi.Truncate(sel.SubTitle, textW, "…")))
		}
		add(indent + st.icon(sel).Render(ansi.Truncate(kind, textW, "…")))

		if sel.RawComment != sel.SubTitle {
			section("Comment", sel.RawComment)
		}
		section("Exec", sel.Exec)
		section("ID", sel.ID)
		section("Desktop file", sel.DesktopFile)
	} else {
		add("")
		add(st.muted.Render("No selection"))
	}

	for len(lines) < h {
		add("")
	}
	return lines[:h]
}
