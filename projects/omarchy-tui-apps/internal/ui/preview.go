package ui

import (
	"fmt"

	"github.com/charmbracelet/lipgloss"
)

func (m Model) BuildPreviewLines(contentW, bodyH int) []string {
	th := m.th
	mkCol := func(hex string) lipgloss.Style {
		return lipgloss.NewStyle().Foreground(lipgloss.Color(hex))
	}
	accentS := mkCol(th.Accent).Bold(true)
	mutedS := mkCol(th.Muted)
	fgS := mkCol(th.Fg)

	lbl := func(k string) string { return mutedS.Render(fmt.Sprintf("%-10s", k)) }
	val := func(v string) string {
		if v == "" {
			v = "-"
		}
		return fgS.Render(Truncate(v, Max(0, contentW-10)))
	}
	block := func(v string) []string {
		if v == "" {
			v = "-"
		}
		var out []string
		for _, l := range WrapToLines(v, contentW) {
			out = append(out, fgS.Render(l))
		}
		return out
	}

	var lines []string
	add := func(s string) { lines = append(lines, s) }
	adds := func(ss []string) { lines = append(lines, ss...) }

	if len(m.visible) == 0 || m.cursor >= len(m.visible) {
		add(mutedS.Render("no selection"))
		for len(lines) < bodyH {
			lines = append(lines, "")
		}
		return lines
	}

	sel := m.visible[m.cursor]
	typeVal := sel.RawType
	if typeVal == "" {
		typeVal = "Application"
	}
	termVal := "false"
	if sel.Terminal {
		termVal = "true"
	}
	comment := sel.RawComment
	if comment == "" {
		comment = sel.SubTitle
	}

	add("")
	add(accentS.Render(Truncate(sel.Name, contentW)))
	if sel.SubTitle != "" {
		add(mutedS.Render(Truncate(sel.SubTitle, contentW)))
	}
	add("")
	add(lbl("Type") + val(typeVal))
	add(lbl("Terminal") + val(termVal))
	add(lbl("ID") + val(sel.ID))
	add("")
	add(mutedS.Render("Exec"))
	adds(block(sel.Exec))
	add("")
	add(mutedS.Render("Comment"))
	adds(block(comment))
	add("")
	add(mutedS.Render("Desktop file"))
	adds(block(sel.DesktopFile))

	for len(lines) < bodyH {
		lines = append(lines, "")
	}
	return lines
}
