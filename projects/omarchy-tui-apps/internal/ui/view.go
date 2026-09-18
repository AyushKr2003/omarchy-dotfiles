package ui

import (
	"fmt"
	"strings"

	"github.com/charmbracelet/lipgloss"
	"omarchy-tui-apps/internal/desktop"
)

func (m Model) View() string {
	if m.width == 0 || m.height == 0 {
		return "loading…\n"
	}

	l := m.Lay()
	th := m.th

	mkCol := func(hex string) lipgloss.Style {
		return lipgloss.NewStyle().Foreground(lipgloss.Color(hex))
	}
	mkColBg := func(fg, bg string) lipgloss.Style {
		return lipgloss.NewStyle().Foreground(lipgloss.Color(fg)).Background(lipgloss.Color(bg))
	}
	bdrS := mkCol(th.Muted)
	accentS := mkCol(th.Accent).Bold(true)
	mutedS := mkCol(th.Muted)
	fgS := mkCol(th.Fg)
	selNameS := mkColBg(th.Accent, th.SelBg).Bold(true)
	selBgS := lipgloss.NewStyle().Background(lipgloss.Color(th.SelBg))
	selSubS := mkColBg(th.Muted, th.SelBg)

	const (
		TL = "╭"
		TR = "╮"
		BL = "╰"
		BR = "╯"
		H  = "─"
		V  = "│"
		LT = "├"
		RT = "┤"
	)

	var sb strings.Builder
	emit := func(s string) { sb.WriteString(s); sb.WriteByte('\n') }

	outerRow := func(inner string) string {
		w := Vw(inner)
		if w < l.InnerW {
			inner += strings.Repeat(" ", l.InnerW-w)
		}
		return inner
	}

	innerBox := func(content string, boxW, padding int) string {
		bodyW := Max(0, boxW-2-2*padding)
		return bdrS.Render(V) +
			strings.Repeat(" ", padding) +
			Pad(content, bodyW) +
			strings.Repeat(" ", padding) +
			bdrS.Render(V)
	}

	twoBoxRow := func(listContent, prevContent string) string {
		lBox := innerBox(listContent, l.ListBW, ListPad)
		pBox := innerBox(prevContent, l.PrevBW, PrevPad)
		inner := " " + lBox + strings.Repeat(" ", Gap) + pBox
		return inner
	}

	// inner top borders
	{
		lTop := TL + strings.Repeat(H, l.ListBW-2) + TR
		pTop := TL + strings.Repeat(H, l.PrevBW-2) + TR
		inner := " " + bdrS.Render(lTop) + strings.Repeat(" ", Gap) + bdrS.Render(pTop)
		emit(outerRow(inner))
	}

	// header row
	{
		hint := " [Ctrl+H: Show all]"
		if m.showAll {
			hint = " [Ctrl+H: Show filtered]"
		}
		hdrContent := accentS.Render(
			IconPad(desktop.IconApp, 3)+"Apps  "+
				IconPad(desktop.IconFlatpak, 3)+"Flatpaks  "+
				IconPad(desktop.IconTerminal, 3)+"Terminal") +
			mutedS.Render(hint)
		emit(outerRow(twoBoxRow(hdrContent, "")))
	}

	// header separator
	{
		lSep := LT + strings.Repeat(H, l.ListBW-2) + RT
		pMid := V + strings.Repeat(" ", l.PrevBW-2) + V
		inner := " " + bdrS.Render(lSep) + strings.Repeat(" ", Gap) + bdrS.Render(pMid)
		emit(outerRow(inner))
	}

	// search row
	{
		searchContent := accentS.Render(desktop.IconPrompt+" Apps  ") +
			fgS.Render(m.query) +
			mkCol(th.Accent).Render("█")
		emit(outerRow(twoBoxRow(searchContent, "")))
	}

	// search separator
	{
		lSep := LT + strings.Repeat(H, l.ListBW-2) + RT
		pMid := V + strings.Repeat(" ", l.PrevBW-2) + V
		inner := " " + bdrS.Render(lSep) + strings.Repeat(" ", Gap) + bdrS.Render(pMid)
		emit(outerRow(inner))
	}

	// body rows
	{
		prevLines := m.BuildPreviewLines(l.PrevBodyW, l.BodyH)

		for row := 0; row < l.BodyH; row++ {
			idx := m.offset + row

			var listContent string
			if idx < len(m.visible) {
				app := m.visible[idx]
				selected := idx == m.cursor

				const icW = 4
				nameMax := (l.ListBodyW - icW) * 6 / 10
				subMax := l.ListBodyW - icW - nameMax - 1

				ic := IconPad(app.Icon, 2)
				nameStr := Truncate(app.Name, nameMax)
				subStr := ""
				if app.SubTitle != "" && subMax > 3 {
					subStr = Truncate(app.SubTitle, subMax)
				}

				if selected {
					iP := selBgS.Render(" " + ic + " ")
					nP := selNameS.Render(nameStr)
					sP := ""
					if subStr != "" {
						sP = selSubS.Render(" " + subStr)
					}
					used := 1 + 2 + 1 + Vw(nameStr)
					if subStr != "" {
						used += 1 + Vw(subStr)
					}
					listContent = iP + nP + sP +
						selBgS.Render(strings.Repeat(" ", Max(0, l.ListBodyW-used)))
				} else {
					iP := " " + mutedS.Render(ic) + " "
					nP := fgS.Bold(true).Render(nameStr)
					sP := ""
					if subStr != "" {
						sP = mutedS.Render(" " + subStr)
					}
					used := 1 + 2 + 1 + Vw(nameStr)
					if subStr != "" {
						used += 1 + Vw(subStr)
					}
					listContent = iP + nP + sP +
						strings.Repeat(" ", Max(0, l.ListBodyW-used))
				}
			} else {
				listContent = strings.Repeat(" ", l.ListBodyW)
			}

			scrollChar := V
			if len(m.visible) > l.BodyH {
				thumbTop := m.offset * l.BodyH / len(m.visible)
				thumbH := Max(1, l.BodyH*l.BodyH/len(m.visible))
				if row >= thumbTop && row < thumbTop+thumbH {
					scrollChar = "┃"
				}
			}

			prevContent := ""
			if row < len(prevLines) {
				prevContent = prevLines[row]
			}

			lBox := bdrS.Render(V) +
				strings.Repeat(" ", ListPad) +
				Pad(listContent, l.ListBodyW) +
				strings.Repeat(" ", ListPad) +
				bdrS.Render(scrollChar)
			pBox := innerBox(prevContent, l.PrevBW, PrevPad)
			inner := " " + lBox + strings.Repeat(" ", Gap) + pBox
			emit(outerRow(inner))
		}
	}

	// inner bottom borders
	{
		total := len(m.visible)
		info := fmt.Sprintf(" %d/%d ", m.cursor+1, total)
		if total == 0 {
			info = " 0 "
		}
		infoW := Vw(info)
		avail := l.ListBW - 2
		ld := (avail - infoW) / 2
		rd := avail - infoW - ld
		if ld < 0 {
			ld, rd = 0, 0
			info = ""
		}
		lBot := bdrS.Render(BL+strings.Repeat(H, ld)) +
			mutedS.Render(info) +
			bdrS.Render(strings.Repeat(H, rd)+BR)
		pBot := bdrS.Render(BL + strings.Repeat(H, l.PrevBW-2) + BR)
		inner := " " + lBot + strings.Repeat(" ", Gap) + pBot
		emit(outerRow(inner))
	}

	if m.launchErr != "" {
		emit(mkCol("#f7768e").Render("error: " + m.launchErr))
	}

	return sb.String()
}
