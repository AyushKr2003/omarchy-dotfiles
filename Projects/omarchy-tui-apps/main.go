package main

import (
	"bufio"
	"fmt"
	"os"
	"os/exec"
	"path/filepath"
	"sort"
	"strings"
	"syscall"
	"unicode"

	tea "github.com/charmbracelet/bubbletea"
	"github.com/charmbracelet/lipgloss"
	"github.com/mattn/go-runewidth"
)

const (
	iconApp      = "󱗼"
	iconTerminal = "" 
	iconFlatpak  = "󰏖"
	iconPrompt   = ""
)

func iconPad(icon string, w int) string {
	cur := runewidth.StringWidth(icon)
	if cur >= w {
		return icon
	}
	pad := w - cur
	return strings.Repeat(" ", pad/2) + icon + strings.Repeat(" ", pad-pad/2)
}

func truncate(s string, maxW int) string {
	if maxW <= 0 {
		return ""
	}
	if runewidth.StringWidth(s) <= maxW {
		return s
	}
	budget := maxW - 1
	cur := 0
	var out []rune
	for _, r := range s {
		rw := runewidth.RuneWidth(r)
		if cur+rw > budget {
			break
		}
		out = append(out, r)
		cur += rw
	}
	return string(out) + "…"
}

func wrapToLines(s string, maxW int) []string {
	if maxW <= 0 {
		return []string{s}
	}
	var lines []string
	for {
		if runewidth.StringWidth(s) <= maxW {
			lines = append(lines, s)
			break
		}
		cut := -1
		cur := 0
		for i, r := range s {
			rw := runewidth.RuneWidth(r)
			if cur+rw > maxW {
				break
			}
			if r == '/' && i > 0 {
				cut = i + 1
			}
			cur += rw
		}
		if cut <= 0 {
			cut = 0
			cur = 0
			for i, r := range s {
				rw := runewidth.RuneWidth(r)
				if cur+rw > maxW {
					cut = i
					break
				}
				cur += rw
			}
			if cut == 0 {
				break
			}
		}
		lines = append(lines, s[:cut])
		s = s[cut:]
	}
	return lines
}

// stripANSI removes escape sequences so we can measure visible width.
func stripANSI(s string) string {
	var out []rune
	inESC := false
	for _, r := range s {
		if inESC {
			if r == 'm' {
				inESC = false
			}
			continue
		}
		if r == '\x1b' {
			inESC = true
			continue
		}
		out = append(out, r)
	}
	return string(out)
}

func vw(s string) int { return runewidth.StringWidth(stripANSI(s)) }

// pad fills s to exactly w visible columns by appending spaces.
// If s is already >= w, it is returned as-is.
func pad(s string, w int) string {
	n := w - vw(s)
	if n <= 0 {
		return s
	}
	return s + strings.Repeat(" ", n)
}

// ─────────────────────────────────────────────────────────────────────────────
// App item
// ─────────────────────────────────────────────────────────────────────────────

type appItem struct {
	Icon, Name, SubTitle, ID, DesktopFile, SearchText, Exec string
	Terminal                                                  bool
	rawType, rawComment                                       string
}

// ─────────────────────────────────────────────────────────────────────────────
// Theme
// ─────────────────────────────────────────────────────────────────────────────

type theme struct{ fg, bg, accent, selBg, muted string }

func defaultTheme() theme {
	return theme{fg: "#c0caf5", bg: "#1a1b26", accent: "#7aa2f7", selBg: "#283457", muted: "#565f89"}
}

func loadTheme(tomlPath string) theme {
	t := defaultTheme()
	t.fg = readColor(tomlPath, "foreground", t.fg)
	t.bg = readColor(tomlPath, "background", t.bg)
	t.accent = readColor(tomlPath, "accent", t.accent)
	t.selBg = readColor(tomlPath, "color0", t.selBg)
	t.muted = readColor(tomlPath, "color8", t.muted)
	return t
}

func readColor(path, key, fallback string) string {
	f, err := os.Open(path)
	if err != nil {
		return fallback
	}
	defer f.Close()
	sc := bufio.NewScanner(f)
	for sc.Scan() {
		line := sc.Text()
		idx := strings.IndexByte(line, '=')
		if idx < 0 {
			continue
		}
		if strings.TrimSpace(line[:idx]) != key {
			continue
		}
		v := strings.TrimFunc(strings.TrimSpace(line[idx+1:]), func(r rune) bool {
			return r == '"' || unicode.IsSpace(r)
		})
		if v != "" {
			return v
		}
	}
	return fallback
}

// ─────────────────────────────────────────────────────────────────────────────
// Layout
// ─────────────────────────────────────────────────────────────────────────────
//
// Every row is W columns wide.
//
// ╭──────────────────────── W-2 dashes ────────────────────────╮   fixed outer top
// │ ╭── listBW ──╮  ╭── prevBW ──╮                             │   inner tops
// │ │  header    │  │            │                             │
// │ ├────────────┤  ├────────────┤                             │   hSep
// │ │  search    │  │            │                             │
// │ ├────────────┤  │            │                             │   sSep
// │ │  rows…     │  │  preview…  │                             │
// │ ╰────────────╯  ╰────────────╯                             │   inner bots
// ╰──────────────────────── W-2 dashes ────────────────────────╯   fixed outer bot
//
// innerW  = W - 2                  (between the two outer │ chars)
// prevBW  = floor(innerW * 0.46)   preview box total width
// listBW  = innerW - prevBW - gap  list box total width  (gap=2 spaces)
//
// Each inner box is drawn with its own ╭╮╰╯ and │ on left+right.
// listBodyW = listBW - 2 - 2*listPad
// prevBodyW = prevBW - 2 - 2*prevPad
//
// fixedRows = 8:
//   outer-top + inner-top + header + hSep + search + sSep + inner-bot + outer-bot

const (
	gap      = 2 // blank columns between the two inner boxes
	listPad  = 1 // horizontal padding inside list box (each side)
	prevPad  = 1 // horizontal padding inside preview box (each side)
	fixedRows = 8
)

type layout struct {
	innerW, listBW, listBodyW, prevBW, prevBodyW, bodyH int
}

func computeLayout(w, h int) layout {
	innerW   := max(0, w-2)
	prevBW   := int(float64(innerW) * 0.46)
	listBW   := max(0, innerW-prevBW-gap)
	return layout{
		innerW:    innerW,
		listBW:    listBW,
		listBodyW: max(0, listBW-2-2*listPad),
		prevBW:    prevBW,
		prevBodyW: max(0, prevBW-2-2*prevPad),
		bodyH:     max(0, h-fixedRows),
	}
}

// ─────────────────────────────────────────────────────────────────────────────
// Model
// ─────────────────────────────────────────────────────────────────────────────

type model struct {
	th            theme
	filteredItems []appItem
	allItems      []appItem
	visible       []appItem
	showAll       bool
	query         string
	cursor        int
	offset        int
	width, height int
	launchErr     string
}

func newModel(filtered, all []appItem, showAll bool, th theme) model {
	m := model{th: th, filteredItems: filtered, allItems: all, showAll: showAll}
	m.rebuildVisible()
	return m
}

func (m *model) rebuildVisible() {
	base := m.filteredItems
	if m.showAll {
		base = m.allItems
	}
	if m.query == "" {
		m.visible = base
	} else {
		q := strings.ToLower(m.query)
		var out []appItem
		for _, a := range base {
			if strings.Contains(strings.ToLower(a.SearchText), q) {
				out = append(out, a)
			}
		}
		m.visible = out
	}
	if m.cursor >= len(m.visible) {
		m.cursor = max(0, len(m.visible)-1)
	}
	m.clampOffset()
}

func (m *model) lay() layout { return computeLayout(m.width, m.height) }

func (m *model) clampOffset() {
	h := m.lay().bodyH
	if h <= 0 {
		m.offset = 0
		return
	}
	if m.cursor < m.offset {
		m.offset = m.cursor
	}
	if m.cursor >= m.offset+h {
		m.offset = m.cursor - h + 1
	}
	if m.offset < 0 {
		m.offset = 0
	}
}

func (m model) Init() tea.Cmd { return nil }

func (m model) Update(msg tea.Msg) (tea.Model, tea.Cmd) {
	switch msg := msg.(type) {
	case tea.WindowSizeMsg:
		m.width, m.height = msg.Width, msg.Height
		m.clampOffset()
	case tea.KeyMsg:
		l := m.lay()
		switch msg.String() {
		case "ctrl+c", "esc":
			return m, tea.Quit
		case "ctrl+h":
			m.showAll = !m.showAll
			m.cursor, m.offset = 0, 0
			m.rebuildVisible()
		case "up", "ctrl+p", "ctrl+k":
			if m.cursor > 0 {
				m.cursor--
				m.clampOffset()
			}
		case "down", "ctrl+n", "ctrl+j":
			if m.cursor < len(m.visible)-1 {
				m.cursor++
				m.clampOffset()
			}
		case "pgup":
			m.cursor = max(0, m.cursor-l.bodyH)
			m.clampOffset()
		case "pgdown":
			m.cursor = min(len(m.visible)-1, m.cursor+l.bodyH)
			m.clampOffset()
		case "home":
			m.cursor = 0
			m.clampOffset()
		case "end":
			m.cursor = max(0, len(m.visible)-1)
			m.clampOffset()
		case "enter":
			if m.cursor < len(m.visible) {
				sel := m.visible[m.cursor]
				if err := launchApp(sel.ID, sel.DesktopFile); err != nil {
					m.launchErr = err.Error()
				} else {
					return m, tea.Quit
				}
			}
		case "backspace":
			if len(m.query) > 0 {
				runes := []rune(m.query)
				m.query = string(runes[:len(runes)-1])
				m.cursor, m.offset = 0, 0
				m.rebuildVisible()
			}
		default:
			if msg.Type == tea.KeyRunes {
				m.query += string(msg.Runes)
				m.cursor, m.offset = 0, 0
				m.rebuildVisible()
			}
		}
	}
	return m, nil
}

// ─────────────────────────────────────────────────────────────────────────────
// View
// ─────────────────────────────────────────────────────────────────────────────

func (m model) View() string {
	if m.width == 0 || m.height == 0 {
		return "loading…\n"
	}

	l  := m.lay()
	th := m.th

	// styles
	mkCol := func(hex string) lipgloss.Style {
		return lipgloss.NewStyle().Foreground(lipgloss.Color(hex))
	}
	mkColBg := func(fg, bg string) lipgloss.Style {
		return lipgloss.NewStyle().Foreground(lipgloss.Color(fg)).Background(lipgloss.Color(bg))
	}
	bdrS     := mkCol(th.muted)
	accentS  := mkCol(th.accent).Bold(true)
	mutedS   := mkCol(th.muted)
	fgS      := mkCol(th.fg)
	selNameS := mkColBg(th.accent, th.selBg).Bold(true)
	selBgS   := lipgloss.NewStyle().Background(lipgloss.Color(th.selBg))
	selSubS  := mkColBg(th.muted, th.selBg)

	const (
		TL = "╭"; TR = "╮"; BL = "╰"; BR = "╯"
		H  = "─"; V  = "│"; LT = "├"; RT = "┤"
	)

	var sb strings.Builder
	emit := func(s string) { sb.WriteString(s); sb.WriteByte('\n') }

	// outerRow wraps pre-built inner content between the outer │ chars.
	// inner must be EXACTLY l.innerW visible columns — we enforce this here.
	outerRow := func(inner string) string {
		// measure and pad/trim to innerW
		w := vw(inner)
		if w < l.innerW {
			inner += strings.Repeat(" ", l.innerW-w)
		}
		return inner                       // outer left and right borders are drawn as part of inner content now
		// return bdrS.Render(V) + inner + bdrS.Render(V)

	}

	// innerBox builds one row of an inner box:
	//   │ <pad> <content padded to bodyW> <pad> │
	// total visible width = boxW
	innerBox := func(content string, boxW, padding int) string {
		bodyW := max(0, boxW-2-2*padding)
		return bdrS.Render(V) +
			strings.Repeat(" ", padding) +
			pad(content, bodyW) +
			strings.Repeat(" ", padding) +
			bdrS.Render(V)
	}

	// twoBoxRow builds the inner content of one row with both boxes side by side:
	//   " " + listBox + "  " + prevBox + trailing
	// total = innerW
	twoBoxRow := func(listContent, prevContent string) string {
		lBox := innerBox(listContent, l.listBW, listPad)
		pBox := innerBox(prevContent, l.prevBW, prevPad)
		inner := " " + lBox + strings.Repeat(" ", gap) + pBox
		return inner // outerRow will pad to innerW
	}

	// ── outer top border ─────────────────────────────────────────────────
	// emit(bdrS.Render(TL + strings.Repeat(H, l.innerW) + TR))

	// ── inner top borders ─────────────────────────────────────────────────
	{
		lTop := TL + strings.Repeat(H, l.listBW-2) + TR
		pTop := TL + strings.Repeat(H, l.prevBW-2) + TR
		inner := " " + bdrS.Render(lTop) + strings.Repeat(" ", gap) + bdrS.Render(pTop)
		emit(outerRow(inner))
	}

	// ── header row ───────────────────────────────────────────────────────
	{
		hint := " [Ctrl+H: Show all]"
		if m.showAll {
			hint = " [Ctrl+H: Show filtered]"
		}
		hdrContent := accentS.Render(
			iconPad(iconApp, 3)+"Apps  "+
				iconPad(iconFlatpak, 3)+"Flatpaks  "+
				iconPad(iconTerminal, 3)+"Terminal") +
			mutedS.Render(hint)
		emit(outerRow(twoBoxRow(hdrContent, "")))
	}

	// ── header separator ─────────────────────────────────────────────────
	{
		lSep := LT + strings.Repeat(H, l.listBW-2) + RT
		pSep := LT + strings.Repeat(H, l.prevBW-2) + RT
		inner := " " + bdrS.Render(lSep) + strings.Repeat(" ", gap) + bdrS.Render(pSep)
		emit(outerRow(inner))
	}

	// ── search row ───────────────────────────────────────────────────────
	{
		searchContent := accentS.Render(iconPrompt+" Apps  ") +
			fgS.Render(m.query) +
			mkCol(th.accent).Render("█")
		emit(outerRow(twoBoxRow(searchContent, "")))
	}

	// ── search separator (list only; preview continues unbroken) ─────────
	{
		lSep := LT + strings.Repeat(H, l.listBW-2) + RT
		// preview: just a plain row with no separator
		pMid := V + strings.Repeat(" ", l.prevBW-2) + V
		inner := " " + bdrS.Render(lSep) + strings.Repeat(" ", gap) + bdrS.Render(pMid)
		emit(outerRow(inner))
	}

	// ── body rows ────────────────────────────────────────────────────────
	{
		prevLines := m.buildPreviewLines(l.prevBodyW, l.bodyH)

		for row := 0; row < l.bodyH; row++ {
			idx := m.offset + row

			// list content
			var listContent string
			if idx < len(m.visible) {
				app      := m.visible[idx]
				selected := idx == m.cursor

				const icW = 4 // " " + icon(2) + " "
				nameMax := (l.listBodyW - icW) * 6 / 10
				subMax  := l.listBodyW - icW - nameMax - 1

				ic      := iconPad(app.Icon, 2)
				nameStr := truncate(app.Name, nameMax)
				subStr  := ""
				if app.SubTitle != "" && subMax > 3 {
					subStr = truncate(app.SubTitle, subMax)
				}

				if selected {
					iP := selBgS.Render(" " + ic + " ")
					nP := selNameS.Render(nameStr)
					sP := ""
					if subStr != "" {
						sP = selSubS.Render(" " + subStr)
					}
					used := 1 + 2 + 1 + vw(nameStr)
					if subStr != "" {
						used += 1 + vw(subStr)
					}
					listContent = iP + nP + sP +
						selBgS.Render(strings.Repeat(" ", max(0, l.listBodyW-used)))
				} else {
					iP := " " + mutedS.Render(ic) + " "
					nP := fgS.Bold(true).Render(nameStr)
					sP := ""
					if subStr != "" {
						sP = mutedS.Render(" " + subStr)
					}
					used := 1 + 2 + 1 + vw(nameStr)
					if subStr != "" {
						used += 1 + vw(subStr)
					}
					listContent = iP + nP + sP +
						strings.Repeat(" ", max(0, l.listBodyW-used))
				}
			} else {
				listContent = strings.Repeat(" ", l.listBodyW)
			}

			// scroll indicator replaces the list box right │
			scrollChar := V
			if len(m.visible) > l.bodyH {
				thumbTop := m.offset * l.bodyH / len(m.visible)
				thumbH   := max(1, l.bodyH*l.bodyH/len(m.visible))
				if row >= thumbTop && row < thumbTop+thumbH {
					scrollChar = "┃"
				}
			}

			// preview content
			prevContent := ""
			if row < len(prevLines) {
				prevContent = prevLines[row]
			}

			// assemble: list box uses scrollChar instead of right │
			lBox := bdrS.Render(V) +
				strings.Repeat(" ", listPad) +
				pad(listContent, l.listBodyW) +
				strings.Repeat(" ", listPad) +
				bdrS.Render(scrollChar)
			pBox := innerBox(prevContent, l.prevBW, prevPad)
			inner := " " + lBox + strings.Repeat(" ", gap) + pBox
			emit(outerRow(inner))
		}
	}

	// ── inner bottom borders ──────────────────────────────────────────────
	{
		total := len(m.visible)
		info := fmt.Sprintf(" %d/%d ", m.cursor+1, total)
		if total == 0 {
			info = " 0 "
		}
		infoW := runewidth.StringWidth(info)
		avail := l.listBW - 2
		ld    := (avail - infoW) / 2
		rd    := avail - infoW - ld
		if ld < 0 {
			ld, rd = 0, 0
			info = ""
		}
		lBot := bdrS.Render(BL+strings.Repeat(H, ld)) +
			mutedS.Render(info) +
			bdrS.Render(strings.Repeat(H, rd)+BR)
		pBot := bdrS.Render(BL + strings.Repeat(H, l.prevBW-2) + BR)
		inner := " " + lBot + strings.Repeat(" ", gap) + pBot
		emit(outerRow(inner))
	}

	// ── outer bottom border ───────────────────────────────────────────────
	// emit(bdrS.Render(BL + strings.Repeat(H, l.innerW) + BR))

	if m.launchErr != "" {
		emit(mkCol("#f7768e").Render("error: " + m.launchErr))
	}

	return sb.String()
}

// ─────────────────────────────────────────────────────────────────────────────
// Preview lines
// ─────────────────────────────────────────────────────────────────────────────

func (m model) buildPreviewLines(contentW, bodyH int) []string {
	th := m.th
	mkCol := func(hex string) lipgloss.Style {
		return lipgloss.NewStyle().Foreground(lipgloss.Color(hex))
	}
	accentS := mkCol(th.accent).Bold(true)
	mutedS  := mkCol(th.muted)
	fgS     := mkCol(th.fg)

	lbl   := func(k string) string { return mutedS.Render(fmt.Sprintf("%-10s", k)) }
	val   := func(v string) string {
		if v == "" { v = "-" }
		return fgS.Render(truncate(v, max(0, contentW-10)))
	}
	block := func(v string) []string {
		if v == "" { v = "-" }
		var out []string
		for _, l := range wrapToLines(v, contentW) {
			out = append(out, fgS.Render(l))
		}
		return out
	}

	var lines []string
	add  := func(s string)    { lines = append(lines, s) }
	adds := func(ss []string) { lines = append(lines, ss...) }

	if len(m.visible) == 0 || m.cursor >= len(m.visible) {
		add(mutedS.Render("no selection"))
		for len(lines) < bodyH { lines = append(lines, "") }
		return lines
	}

	sel     := m.visible[m.cursor]
	typeVal := sel.rawType
	if typeVal == "" { typeVal = "Application" }
	termVal := "false"
	if sel.Terminal { termVal = "true" }
	comment := sel.rawComment
	if comment == "" { comment = sel.SubTitle }

	add("")
	add(accentS.Render(truncate(sel.Name, contentW)))
	if sel.SubTitle != "" {
		add(mutedS.Render(truncate(sel.SubTitle, contentW)))
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

	for len(lines) < bodyH { lines = append(lines, "") }
	return lines
}

// ─────────────────────────────────────────────────────────────────────────────
// Desktop scanner
// ─────────────────────────────────────────────────────────────────────────────

type desktopEntry struct {
	entryType, name, genericName, comment, exec string
	terminal, hidden, noDisplay                  bool
	onlyShowIn, notShowIn                        []string
}

func parseDesktopFile(path string) (desktopEntry, bool) {
	f, err := os.Open(path)
	if err != nil {
		return desktopEntry{}, false
	}
	defer f.Close()
	var e desktopEntry
	inEntry := false
	sc := bufio.NewScanner(f)
	for sc.Scan() {
		line := strings.TrimRight(sc.Text(), "\r")
		if strings.HasPrefix(line, "[") {
			inEntry = line == "[Desktop Entry]"
			continue
		}
		if !inEntry {
			continue
		}
		idx := strings.IndexByte(line, '=')
		if idx < 0 {
			continue
		}
		key := strings.TrimSpace(line[:idx])
		val := strings.TrimSpace(line[idx+1:])
		switch key {
		case "Type":        if e.entryType == ""  { e.entryType = val }
		case "Name":        if e.name == ""        { e.name = val }
		case "GenericName": if e.genericName == "" { e.genericName = val }
		case "Comment":     if e.comment == ""     { e.comment = val }
		case "Exec":        if e.exec == ""        { e.exec = val }
		case "Terminal":    if !e.terminal         { e.terminal = strings.EqualFold(val, "true") }
		case "Hidden":      e.hidden = strings.EqualFold(val, "true")
		case "NoDisplay":   e.noDisplay = strings.EqualFold(val, "true")
		case "OnlyShowIn":  if e.onlyShowIn == nil { e.onlyShowIn = splitSemi(val) }
		case "NotShowIn":   if e.notShowIn == nil  { e.notShowIn = splitSemi(val) }
		}
	}
	return e, true
}

func splitSemi(s string) []string {
	var out []string
	for _, p := range strings.Split(s, ";") {
		if p != "" {
			out = append(out, p)
		}
	}
	return out
}

type scanCfg struct {
	hiddenIDs       map[string]bool
	currentDesktops []string
	includeTerminal bool
}

func desktopID(dir, path string) string {
	rel, _ := filepath.Rel(dir, path)
	rel = strings.TrimSuffix(rel, ".desktop")
	return strings.ReplaceAll(rel, "/", "-")
}

func isFlatpakDir(dir string) bool {
	return strings.Contains(dir, "flatpak/exports/share/applications")
}

func matchesDesktop(list, current []string) bool {
	for _, d := range current {
		if d == "" { continue }
		for _, c := range list {
			if c == d { return true }
		}
	}
	return false
}

func isTerminalExec(exec string) bool {
	return strings.HasPrefix(exec, "xdg-terminal-exec") ||
		strings.Contains(exec, " xdg-terminal-exec ")
}

func scanDir(dir string, cfg scanCfg, seenAll, seenFilt map[string]bool) (all, filt []appItem) {
	entries, err := os.ReadDir(dir)
	if err != nil {
		return
	}
	isFP := isFlatpakDir(dir)
	var paths []string
	for _, e := range entries {
		if e.IsDir() {
			a, f := scanDir(filepath.Join(dir, e.Name()), cfg, seenAll, seenFilt)
			all = append(all, a...)
			filt = append(filt, f...)
			continue
		}
		if strings.HasSuffix(e.Name(), ".desktop") {
			paths = append(paths, filepath.Join(dir, e.Name()))
		}
	}
	sort.Strings(paths)
	for _, path := range paths {
		e, ok := parseDesktopFile(path)
		if !ok || (e.entryType != "" && e.entryType != "Application") {
			continue
		}
		if e.name == "" || e.exec == "" {
			continue
		}
		id   := desktopID(dir, path)
		icon := iconApp
		if isFP {
			icon = iconFlatpak
		} else if e.terminal || isTerminalExec(e.exec) {
			icon = iconTerminal
		}
		sub := e.genericName
		if sub == "" { sub = e.comment }
		item := appItem{
			Icon: icon, Name: e.name, SubTitle: sub,
			ID: id, DesktopFile: path,
			SearchText: strings.TrimSpace(e.name + " " + sub + " " + e.comment + " " + id),
			Exec: e.exec, Terminal: e.terminal,
			rawType: e.entryType, rawComment: e.comment,
		}
		if !seenAll[id] {
			seenAll[id] = true
			if cfg.includeTerminal || !e.terminal {
				all = append(all, item)
			}
		}
		if seenFilt[id] || cfg.hiddenIDs[id] || e.hidden || e.noDisplay { continue }
		if len(e.onlyShowIn) > 0 && !matchesDesktop(e.onlyShowIn, cfg.currentDesktops) { continue }
		if len(e.notShowIn) > 0 && matchesDesktop(e.notShowIn, cfg.currentDesktops) { continue }
		if !cfg.includeTerminal && e.terminal { continue }
		seenFilt[id] = true
		filt = append(filt, item)
	}
	return
}

func readHides(path string) map[string]bool {
	out := make(map[string]bool)
	f, err := os.Open(path)
	if err != nil { return out }
	defer f.Close()
	sc := bufio.NewScanner(f)
	for sc.Scan() {
		id := strings.TrimSuffix(strings.TrimRight(sc.Text(), "\r\n"), ".desktop")
		if id != "" { out[id] = true }
	}
	return out
}

// ─────────────────────────────────────────────────────────────────────────────
// Launch
// ─────────────────────────────────────────────────────────────────────────────

func launchApp(id, desktopFile string) error {
	if p, err := exec.LookPath("gtk-launch"); err == nil {
		if exec.Command(p, id).Start() == nil { return nil }
	}
	if p, err := exec.LookPath("gio"); err == nil {
		if exec.Command(p, "launch", desktopFile).Start() == nil { return nil }
	}
	line := rawExec(desktopFile)
	if line == "" {
		return fmt.Errorf("no Exec= in %s", desktopFile)
	}
	var parts []string
	for _, p := range strings.Fields(line) {
		if len(p) == 2 && p[0] == '%' { continue }
		parts = append(parts, p)
	}
	if len(parts) == 0 {
		return fmt.Errorf("empty exec")
	}
	cmd := exec.Command(parts[0], parts[1:]...)
	cmd.SysProcAttr = &syscall.SysProcAttr{Setsid: true}
	return cmd.Start()
}

func rawExec(desktopFile string) string {
	f, err := os.Open(desktopFile)
	if err != nil { return "" }
	defer f.Close()
	sc := bufio.NewScanner(f)
	for sc.Scan() {
		line := strings.TrimRight(sc.Text(), "\r")
		if strings.HasPrefix(line, "Exec=") {
			return strings.TrimPrefix(line, "Exec=")
		}
	}
	return ""
}

// ─────────────────────────────────────────────────────────────────────────────
// Main
// ─────────────────────────────────────────────────────────────────────────────

func main() {
	showAll := false
	for _, a := range os.Args[1:] {
		if a == "-a" || a == "--all" { showAll = true }
	}

	home           := os.Getenv("HOME")
	themeFile      := envOr("OMARCHY_THEME_COLORS", filepath.Join(home, ".config/omarchy/current/theme/colors.toml"))
	hidesFile      := envOr("OMARCHY_LAUNCHER_HIDES", filepath.Join(home, ".local/share/omarchy/default/omarchy/launcher.hides"))
	includeTerminal := envOr("INCLUDE_TERMINAL_APPS", "true") == "true"
	desktopEnv     := envOr("XDG_CURRENT_DESKTOP", envOr("XDG_SESSION_DESKTOP", envOr("DESKTOP_SESSION", "")))

	cfg := scanCfg{
		hiddenIDs:       readHides(hidesFile),
		currentDesktops: strings.Split(desktopEnv, ":"),
		includeTerminal: includeTerminal,
	}

	var dirs []string
	dirs = append(dirs, filepath.Join(home, ".local/share/applications"))
	for _, d := range strings.Split(envOr("XDG_DATA_DIRS", "/usr/local/share:/usr/share"), ":") {
		dirs = append(dirs, filepath.Join(d, "applications"))
	}
	dirs = append(dirs,
		filepath.Join(home, ".nix-profile/share/applications"),
		"/var/lib/flatpak/exports/share/applications",
		filepath.Join(home, ".local/share/flatpak/exports/share/applications"),
	)

	seenAll, seenFilt := map[string]bool{}, map[string]bool{}
	var allApps, filtApps []appItem
	for _, dir := range dirs {
		a, f := scanDir(dir, cfg, seenAll, seenFilt)
		allApps  = append(allApps, a...)
		filtApps = append(filtApps, f...)
	}
	if len(allApps) == 0 && len(filtApps) == 0 {
		fmt.Fprintln(os.Stderr, "no launchable desktop applications found")
		os.Exit(1)
	}

	sortFn := func(apps []appItem) {
		sort.SliceStable(apps, func(i, j int) bool {
			return strings.ToLower(apps[i].Name) < strings.ToLower(apps[j].Name)
		})
	}
	sortFn(allApps)
	sortFn(filtApps)

	th := loadTheme(themeFile)
	m  := newModel(filtApps, allApps, showAll, th)
	p  := tea.NewProgram(m, tea.WithAltScreen())
	if _, err := p.Run(); err != nil {
		fmt.Fprintln(os.Stderr, err)
		os.Exit(1)
	}
}

func envOr(key, def string) string {
	if v := os.Getenv(key); v != "" { return v }
	return def
}

func max(a, b int) int {
	if a > b { return a }
	return b
}

func min(a, b int) int {
	if a < b { return a }
	return b
}