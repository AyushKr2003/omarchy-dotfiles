package ui

import (
	"fmt"
	"os"
	"path/filepath"
	"sort"
	"strings"

	"github.com/charmbracelet/bubbles/key"
	tea "github.com/charmbracelet/bubbletea"
	"github.com/charmbracelet/lipgloss"

	"omarchy-colorgen/internal/wallpaper"
)

type screenState int

const (
	screenFolder screenState = iota
	screenMain
)

// defaultStartDir opens the folder browser at $HOME.
func defaultStartDir() string {
	if home := os.Getenv("HOME"); home != "" {
		return home
	}
	return "."
}

// initFolder loads the browser at dir, listing its immediate subdirectories.
// Hidden directories are included only when m.showHidden is true.
func (m *Model) initFolder(dir string) {
	abs, err := filepath.Abs(dir)
	if err != nil {
		abs = dir
	}
	m.fpDir = abs
	m.fpCursor = 0
	m.fpDirs = m.fpDirs[:0]

	entries, err := os.ReadDir(abs)
	if err != nil {
		m.setStatus("cannot read "+abs+": "+err.Error(), true)
		return
	}
	var dirs []string
	for _, e := range entries {
		if !e.IsDir() {
			continue
		}
		if !m.showHidden && strings.HasPrefix(e.Name(), ".") {
			continue
		}
		dirs = append(dirs, e.Name())
	}
	sort.Strings(dirs)
	m.fpDirs = dirs
}

// folderRow describes one selectable line in the browser.
type folderRow struct {
	kind  string // "use" | "parent" | "dir"
	label string
	name  string
}

func (m Model) folderRows() []folderRow {
	rows := []folderRow{{kind: "use", label: "[ Use this folder ]"}}
	if parent := filepath.Dir(m.fpDir); parent != m.fpDir {
		rows = append(rows, folderRow{kind: "parent", label: ".."})
	}
	for _, d := range m.fpDirs {
		rows = append(rows, folderRow{kind: "dir", label: d + "/", name: d})
	}
	return rows
}

func (m Model) updateFolder(msg tea.KeyMsg) (tea.Model, tea.Cmd) {
	rows := m.folderRows()

	switch {
	case key.Matches(msg, m.keys.Quit):
		return m, tea.Quit

	case key.Matches(msg, m.keys.Up):
		if m.fpCursor > 0 {
			m.fpCursor--
		}
		return m, nil

	case key.Matches(msg, m.keys.Down):
		if m.fpCursor < len(rows)-1 {
			m.fpCursor++
		}
		return m, nil

	case key.Matches(msg, m.keys.FolderUp):
		if parent := filepath.Dir(m.fpDir); parent != m.fpDir {
			m.initFolder(parent)
		}
		return m, nil

	case key.Matches(msg, m.keys.FolderInto), key.Matches(msg, m.keys.Confirm):
		if m.fpCursor < 0 || m.fpCursor >= len(rows) {
			return m, nil
		}
		row := rows[m.fpCursor]
		switch row.kind {
		case "use":
			return m.chooseFolder(m.fpDir)
		case "parent":
			m.initFolder(filepath.Dir(m.fpDir))
			return m, nil
		case "dir":
			m.initFolder(filepath.Join(m.fpDir, row.name))
			return m, nil
		}

	case key.Matches(msg, m.keys.ToggleHidden):
		m.showHidden = !m.showHidden
		m.initFolder(m.fpDir)
		return m, nil

	case key.Matches(msg, m.keys.WritePath):
		m.inputMode = inputPath
		m.input.Prompt = "path: "
		m.input.SetValue(m.fpDir)
		m.input.CursorEnd()
		return m, m.input.Focus()
	}
	return m, nil
}

// chooseFolder scans dir for images and switches to the main screen.
func (m Model) chooseFolder(dir string) (tea.Model, tea.Cmd) {
	found := wallpaper.Scan([]string{dir})
	if len(found) == 0 {
		m.setStatus("no images found in "+dir, true)
		return m, nil
	}
	m.srcDir = dir
	m.all = found
	m.applyFilter("")
	m.cursor = 0
	m.screen = screenMain
	m.setStatus("", false)
	return m, m.regenerate()
}

func (m Model) folderView() string {
	if !m.ready {
		return "loading…"
	}

	title := titleStyle.Render("omarchy-colorgen") + "  " +
		mutedStyle.Render("choose your wallpaper folder")

	rows := m.folderRows()
	visible := m.height - 10
	if visible < 3 {
		visible = 3
	}
	start := 0
	if m.fpCursor >= visible {
		start = m.fpCursor - visible + 1
	}
	end := start + visible
	if end > len(rows) {
		end = len(rows)
	}

	hiddenLabel := fmt.Sprintf("  [hidden:%s]", map[bool]string{true: "on", false: "off"}[m.showHidden])
	path := paneTitleStyle.Render("📁 " + m.fpDir) + mutedStyle.Render(hiddenLabel)

	var inputLine string
	if m.inputMode == inputPath {
		inputLine = "\n" + m.input.View()
	}

	var lines []string
	for i := start; i < end; i++ {
		r := rows[i]
		label := r.label
		style := itemStyle
		switch r.kind {
		case "use":
			style = okStyle
		case "parent":
			style = itemGroupStyle
		}
		if i == m.fpCursor {
			lines = append(lines, selectedItemStyle.Render("▸ "+label))
		} else {
			lines = append(lines, style.Render("  "+label))
		}
	}
	list := strings.Join(lines, "\n")

	boxInner := path + "\n\n" + inputLine + list
	box := paneStyle.Width(min2(m.width-4, 70)).Render(boxInner)

	hint := mutedStyle.Render("  ↑/↓ · ← up · enter/→ open · ctrl+./. hidden · ctrl+p/p path · q quit")
	var status string
	if m.status != "" && m.statusErr {
		status = errStyle.Render("✗ " + m.status)
	}

	content := lipgloss.JoinVertical(lipgloss.Left, title, "", box, "", hint)
	if status != "" {
		content = lipgloss.JoinVertical(lipgloss.Left, content, status)
	}
	return lipgloss.Place(m.width, m.height, lipgloss.Center, lipgloss.Center, content)
}

func min2(a, b int) int {
	if a < b {
		return a
	}
	return b
}
