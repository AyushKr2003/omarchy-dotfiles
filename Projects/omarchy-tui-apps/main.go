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

// ─────────────────────────────────────────────────────────────────────────────
// Icons (Nerd Font)
// ─────────────────────────────────────────────────────────────────────────────

const (
	iconApp      = "󱗼" //"󰀻"
	iconTerminal = "" 
	iconFlatpak  = "󰏖"
	iconPrompt   = ""
)
// iconPad pads/trims icon to exactly `w` visible columns.
func iconPad(icon string, w int) string {
	cur := runewidth.StringWidth(icon)
	if cur >= w {
		return icon
	}
	pad := w - cur
	l := pad / 2
	r := pad - l
	return strings.Repeat(" ", l) + icon + strings.Repeat(" ", r)
}

// ─────────────────────────────────────────────────────────────────────────────
// String helpers
// ─────────────────────────────────────────────────────────────────────────────

// truncate cuts s to at most maxW visible columns, appending "…" if cut.
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


// wrapToLines wraps s into lines each at most maxW visible columns wide.
// Prefers breaking at '/' for paths; falls back to character-level.
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
		// find last '/' within maxW
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
			// no slash: hard cut
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

// ─────────────────────────────────────────────────────────────────────────────
// App item
// ─────────────────────────────────────────────────────────────────────────────

type appItem struct {
	Icon        string
	Name        string
	SubTitle    string
	ID          string
	DesktopFile string
	SearchText  string
	Exec        string
	Terminal    bool
	rawType     string
	rawComment  string
}

// ─────────────────────────────────────────────────────────────────────────────
// Theme
// ─────────────────────────────────────────────────────────────────────────────

type theme struct {
	fg, bg, accent, selBg, muted string
}

func defaultTheme() theme {
	return theme{
		fg:     "#c0caf5",
		bg:     "#1a1b26",
		accent: "#7aa2f7",
		selBg:  "#283457",
		muted:  "#565f89",
	}
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
		v := strings.TrimSpace(line[idx+1:])
		v = strings.TrimFunc(v, func(r rune) bool {
			return r == '"' || unicode.IsSpace(r)
		})
		if v != "" {
			return v
		}
	}
	return fallback
}

// ─────────────────────────────────────────────────────────────────────────────
// Model
// ─────────────────────────────────────────────────────────────────────────────

// Layout constants (terminal rows / cols consumed by chrome).
//
//	total height = 1 (border top) + 1 (header) + 1 (search) + bodyH + 1 (border bottom)
//	bodyH = height - 4
//	total width  = 1 (border left) + innerW + 1 (border right)
//	innerW = width - 2
const (
	chromeH = 4 // border(2) + header(1) + search(1)
	chromeW = 2 // border left + right
)

type model struct {
	th theme

	// all items before any query filter
	filteredItems []appItem // hidden-app-filtered, desktop-env-filtered
	allItems      []appItem // everything including hidden/NoDisplay

	// current displayed slice (after query filter)
	visible []appItem

	showAll bool
	query   string
	cursor  int // index into visible
	offset  int // first visible row in list viewport

	width, height int // terminal dimensions

	launchErr string
}

func newModel(filtered, all []appItem, showAll bool, th theme) model {
	m := model{
		th:            th,
		filteredItems: filtered,
		allItems:      all,
		showAll:       showAll,
	}
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
	// clamp cursor
	if m.cursor >= len(m.visible) {
		m.cursor = max(0, len(m.visible)-1)
	}
	m.clampOffset()
}

func (m *model) clampOffset() {
	h := m.listHeight()
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

// listHeight returns the number of rows available for list items.
func (m *model) listHeight() int {
	return max(0, m.height-chromeH)
}

// listWidth returns the column width for the list pane.
func (m *model) listWidth() int {
	innerW := max(0, m.width-chromeW)
	previewW := int(float64(innerW) * 0.46)
	return max(0, innerW-previewW-1) // -1 for divider column
}

// previewWidth returns the column width for the preview pane (including the │ border col).
func (m *model) previewWidth() int {
	innerW := max(0, m.width-chromeW)
	return int(float64(innerW) * 0.46)
}

func (m model) Init() tea.Cmd { return nil }

func (m model) Update(msg tea.Msg) (tea.Model, tea.Cmd) {
	switch msg := msg.(type) {

	case tea.WindowSizeMsg:
		m.width = msg.Width
		m.height = msg.Height
		m.clampOffset()
		return m, nil

	case tea.KeyMsg:
		switch msg.String() {

		case "ctrl+c", "esc":
			return m, tea.Quit

		case "ctrl+h":
			m.showAll = !m.showAll
			m.cursor = 0
			m.offset = 0
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
			m.cursor = max(0, m.cursor-m.listHeight())
			m.clampOffset()

		case "pgdown":
			m.cursor = min(len(m.visible)-1, m.cursor+m.listHeight())
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

		case "backspace", "ctrl+h ":
			if len(m.query) > 0 {
				runes := []rune(m.query)
				m.query = string(runes[:len(runes)-1])
				m.cursor = 0
				m.offset = 0
				m.rebuildVisible()
			}

		default:
			// printable rune → append to query
			if msg.Type == tea.KeyRunes {
				m.query += string(msg.Runes)
				m.cursor = 0
				m.offset = 0
				m.rebuildVisible()
			}
		}
	}
	return m, nil
}

// ─────────────────────────────────────────────────────────────────────────────
// View  – one strings.Builder pass, row by row
// ─────────────────────────────────────────────────────────────────────────────

func (m model) View() string {
	if m.width == 0 || m.height == 0 {
		return "loading…\n"
	}

	th := m.th
	W := m.width
	H := m.height
	innerW := W - chromeW          // content columns between the two border chars
	lW := m.listWidth()            // list pane width
	pW := m.previewWidth()         // preview pane width (includes │ col)
	pContentW := max(0, pW-2)      // usable preview content width (strip │ and 1 padding col)
	bodyH := max(0, H-chromeH)     // rows for list+preview body

	// lipgloss colour helpers (only used for ANSI colour codes, not layout)
	col := func(hex string) lipgloss.Style {
		return lipgloss.NewStyle().Foreground(lipgloss.Color(hex))
	}
	bg := func(hex string) lipgloss.Style {
		return lipgloss.NewStyle().Background(lipgloss.Color(hex))
	}
	both := func(fg, bgHex string) lipgloss.Style {
		return lipgloss.NewStyle().
			Foreground(lipgloss.Color(fg)).
			Background(lipgloss.Color(bgHex))
	}

	accentS := col(th.accent).Bold(true)
	mutedS  := col(th.muted)
	fgS     := col(th.fg)
	borderS := col(th.muted)

	selNameS := both(th.accent, th.selBg).Bold(true)
	selBgS   := bg(th.selBg)
	selSubS  := both(th.muted, th.selBg)

	// round-corner border chars
	const (
		tl = "╭"; tr = "╮"; bl = "╰"; br = "╯"
		h  = "─"; v  = "│"
	)

	var sb strings.Builder
	writeln := func(line string) {
		sb.WriteString(line)
		sb.WriteByte('\n')
	}

	// ── ROW 0: top border ─────────────────────────────────────────────────
	writeln(borderS.Render(tl + strings.Repeat(h, innerW) + tr))

	// ── ROW 1: header ─────────────────────────────────────────────────────
	{
		// "󱗼  Apps  󰏖  Flatpaks    Terminal  [hint]"
		apI  := iconPad("󱗼", 4) // wider app icon
		fpI  := iconPad(iconFlatpak, 3)
		tmI  := iconPad(iconTerminal, 3)
		hint := " [Ctrl+H: Show all]"
		if m.showAll {
			hint = " [Ctrl+H: Show filtered]"
		}
		content := accentS.Render(apI+"Apps  "+fpI+"Flatpaks  "+tmI+"Terminal") +
			mutedS.Render(hint)
		// pad to innerW
		raw := stripANSI(content) // visible width
		padded := content + strings.Repeat(" ", max(0, innerW-runewidth.StringWidth(raw)))
		writeln(borderS.Render(v) + padded + borderS.Render(v))
	}

	// ── ROW 2: search ─────────────────────────────────────────────────────
	{
		prompt := accentS.Render(iconPrompt+" Apps  ")
		cursor := "█"
		rawLen := runewidth.StringWidth(iconPrompt+" Apps  ") +
			runewidth.StringWidth(m.query) + 1
		// pad to innerW
		line := prompt + fgS.Render(m.query) + col(th.accent).Render(cursor) +
			strings.Repeat(" ", max(0, innerW-rawLen))
		writeln(borderS.Render(v) + line + borderS.Render(v))
	}

	// ── ROWS 3 … 3+bodyH-1: body (list | preview) ────────────────────────
	{
		// Pre-render the preview lines so we can join them with list rows
		prevLines := m.buildPreviewLines(pContentW, bodyH)

		for row := 0; row < bodyH; row++ {
			idx := m.offset + row // index into m.visible

			// ── list cell ──────────────────────────────────────────────
			var listCell string
			if idx < len(m.visible) {
				app := m.visible[idx]
				selected := idx == m.cursor

				const iconColW = 5 // fixed: 1 space + icon(3) + 1 space
				nameMax := (lW - iconColW) * 55 / 100
				subMax  := lW - iconColW - nameMax - 2

				iconStr := iconPad(app.Icon, 3)
				nameStr := truncate(app.Name, nameMax)
				subStr  := ""
				if app.SubTitle != "" && subMax > 3 {
					subStr = truncate(app.SubTitle, subMax)
				}

				if selected {
					iconPart := selBgS.Render(" " + iconStr + " ")
					namePart := selNameS.Render(nameStr)
					var cell string
					if subStr != "" {
						subPart := selSubS.Render("  " + subStr)
						cell = iconPart + namePart + subPart
					} else {
						cell = iconPart + namePart
					}
					// pad to lW with selBg
					visW := 1 + 3 + 1 + runewidth.StringWidth(nameStr)
					if subStr != "" {
						visW += 2 + runewidth.StringWidth(subStr)
					}
					listCell = cell + selBgS.Render(strings.Repeat(" ", max(0, lW-visW)))
				} else {
					iconPart := " " + mutedS.Render(iconStr) + " "
					namePart := fgS.Bold(true).Render(nameStr)
					var cell string
					if subStr != "" {
						subPart := mutedS.Render("  " + subStr)
						cell = iconPart + namePart + subPart
					} else {
						cell = iconPart + namePart
					}
					visW := 1 + 3 + 1 + runewidth.StringWidth(nameStr)
					if subStr != "" {
						visW += 2 + runewidth.StringWidth(subStr)
					}
					listCell = cell + strings.Repeat(" ", max(0, lW-visW))
				}
			} else {
				// empty row
				listCell = strings.Repeat(" ", lW)
			}

			// ── preview cell ───────────────────────────────────────────
			var prevCell string
			if row < len(prevLines) {
				pl := prevLines[row]
				visW := runewidth.StringWidth(stripANSI(pl))
				prevCell = borderS.Render(v) + " " + pl +
					strings.Repeat(" ", max(0, pContentW-visW))
			} else {
				prevCell = borderS.Render(v) + strings.Repeat(" ", pW-1)
			}

			// ── scroll indicator embedded in divider column ──────────
			divider := borderS.Render(v)
			if len(m.visible) > bodyH {
				thumbTop := m.offset * bodyH / len(m.visible)
				thumbH   := max(1, bodyH*bodyH/len(m.visible))
				thumbBot := thumbTop + thumbH - 1
				if row >= thumbTop && row <= thumbBot {
					divider = mutedS.Render("┃")
				} else {
					divider = mutedS.Render("│")
				}
			}
			writeln(borderS.Render(v) + listCell + divider + prevCell + borderS.Render(v))
		}
	}

	// ── last row: bottom border ────────────────────────────────────────────
	{
		// show item count + scroll position in the border
		total := len(m.visible)
		info := fmt.Sprintf(" %d/%d ", m.cursor+1, total)
		if total == 0 {
			info = " 0 results "
		}
		infoW := runewidth.StringWidth(info)
		leftDashes  := (innerW - infoW) / 2
		rightDashes := innerW - infoW - leftDashes
		bottomRow := borderS.Render(bl) +
			borderS.Render(strings.Repeat(h, leftDashes)) +
			mutedS.Render(info) +
			borderS.Render(strings.Repeat(h, rightDashes)) +
			borderS.Render(br)
		writeln(bottomRow)
	}

	// error line (outside the box, only when set)
	if m.launchErr != "" {
		writeln(col("#f7768e").Render("error: " + m.launchErr))
	}

	return sb.String()
}

// stripANSI removes ANSI escape sequences for width measurement.
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

// buildPreviewLines builds the preview panel as a slice of styled strings,
// each at most contentW visible columns wide, total bodyH rows.
func (m model) buildPreviewLines(contentW, bodyH int) []string {
	th := m.th
	col := func(hex string) lipgloss.Style {
		return lipgloss.NewStyle().Foreground(lipgloss.Color(hex))
	}
	accentS := col(th.accent).Bold(true)
	mutedS  := col(th.muted)
	fgS     := col(th.fg)

	label := func(k string) string {
		return mutedS.Render(fmt.Sprintf("%-10s", k))
	}
	val := func(v string) string {
		if v == "" {
			v = "-"
		}
		return fgS.Render(truncate(v, contentW-10))
	}
	block := func(v string) []string {
		if v == "" {
			v = "-"
		}
		ls := wrapToLines(v, contentW)
		var out []string
		for _, l := range ls {
			out = append(out, fgS.Render(l))
		}
		return out
	}

	var lines []string
	addLine := func(s string) { lines = append(lines, s) }
	addLines := func(ss []string) {
		for _, s := range ss {
			lines = append(lines, s)
		}
	}

	if len(m.visible) == 0 || m.cursor >= len(m.visible) {
		addLine(mutedS.Render("no selection"))
		return lines
	}

	sel := m.visible[m.cursor]
	typeVal := sel.rawType
	if typeVal == "" {
		typeVal = "Application"
	}
	termVal := "false"
	if sel.Terminal {
		termVal = "true"
	}
	comment := sel.rawComment
	if comment == "" {
		comment = sel.SubTitle
	}

	addLine("")
	addLine(accentS.Render(truncate(sel.Name, contentW)))
	if sel.SubTitle != "" {
		addLine(mutedS.Render(truncate(sel.SubTitle, contentW)))
	}
	addLine("")
	addLine(label("Type") + val(typeVal))
	addLine(label("Terminal") + val(termVal))
	addLine(label("ID") + val(sel.ID))
	addLine("")
	addLine(mutedS.Render("Exec"))
	addLines(block(sel.Exec))
	addLine("")
	addLine(mutedS.Render("Comment"))
	addLines(block(comment))
	addLine("")
	addLine(mutedS.Render("Desktop file"))
	addLines(block(sel.DesktopFile))

	// pad to bodyH
	for len(lines) < bodyH {
		lines = append(lines, "")
	}
	return lines
}

// ─────────────────────────────────────────────────────────────────────────────
// Desktop file scanner (unchanged from original)
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
		v   := strings.TrimSpace(line[idx+1:])
		switch key {
		case "Type":
			if e.entryType == "" { e.entryType = v }
		case "Name":
			if e.name == "" { e.name = v }
		case "GenericName":
			if e.genericName == "" { e.genericName = v }
		case "Comment":
			if e.comment == "" { e.comment = v }
		case "Exec":
			if e.exec == "" { e.exec = v }
		case "Terminal":
			if !e.terminal { e.terminal = strings.EqualFold(v, "true") }
		case "Hidden":
			e.hidden = strings.EqualFold(v, "true")
		case "NoDisplay":
			e.noDisplay = strings.EqualFold(v, "true")
		case "OnlyShowIn":
			if e.onlyShowIn == nil { e.onlyShowIn = splitSemi(v) }
		case "NotShowIn":
			if e.notShowIn == nil { e.notShowIn = splitSemi(v) }
		}
	}
	return e, true
}

func splitSemi(s string) []string {
	parts := strings.Split(s, ";")
	out := parts[:0]
	for _, p := range parts {
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
			all  = append(all, a...)
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
		id := desktopID(dir, path)
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
		if seenFilt[id] || cfg.hiddenIDs[id] || e.hidden || e.noDisplay {
			continue
		}
		if len(e.onlyShowIn) > 0 && !matchesDesktop(e.onlyShowIn, cfg.currentDesktops) {
			continue
		}
		if len(e.notShowIn) > 0 && matchesDesktop(e.notShowIn, cfg.currentDesktops) {
			continue
		}
		if !cfg.includeTerminal && e.terminal {
			continue
		}
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
		id := strings.TrimRight(sc.Text(), "\r\n")
		id = strings.TrimSuffix(id, ".desktop")
		if id != "" { out[id] = true }
	}
	return out
}

// ─────────────────────────────────────────────────────────────────────────────
// Launch
// ─────────────────────────────────────────────────────────────────────────────

func launchApp(id, desktopFile string) error {
	if p, err := exec.LookPath("gtk-launch"); err == nil {
		if err := exec.Command(p, id).Start(); err == nil {
			return nil
		}
	}
	if p, err := exec.LookPath("gio"); err == nil {
		if err := exec.Command(p, "launch", desktopFile).Start(); err == nil {
			return nil
		}
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

	home := os.Getenv("HOME")
	themeFile      := envOr("OMARCHY_THEME_COLORS",
		filepath.Join(home, ".config/omarchy/current/theme/colors.toml"))
	hidesFile      := envOr("OMARCHY_LAUNCHER_HIDES",
		filepath.Join(home, ".local/share/omarchy/default/omarchy/launcher.hides"))
	includeTerminal := envOr("INCLUDE_TERMINAL_APPS", "true") == "true"
	desktopEnv     := envOr("XDG_CURRENT_DESKTOP",
		envOr("XDG_SESSION_DESKTOP", envOr("DESKTOP_SESSION", "")))

	cfg := scanCfg{
		hiddenIDs:       readHides(hidesFile),
		currentDesktops: strings.Split(desktopEnv, ":"),
		includeTerminal: includeTerminal,
	}

	dataDirs := strings.Split(envOr("XDG_DATA_DIRS", "/usr/local/share:/usr/share"), ":")
	var dirs []string
	dirs = append(dirs, filepath.Join(home, ".local/share/applications"))
	for _, d := range dataDirs {
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

// ─────────────────────────────────────────────────────────────────────────────
// Helpers
// ─────────────────────────────────────────────────────────────────────────────

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