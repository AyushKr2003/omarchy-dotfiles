package ui

import (
	"strings"

	tea "github.com/charmbracelet/bubbletea"
	"omarchy-tui-apps/internal/desktop"
	"omarchy-tui-apps/internal/launcher"
	"omarchy-tui-apps/internal/theme"
)

type Model struct {
	th            theme.Theme
	filteredItems []desktop.AppItem
	allItems      []desktop.AppItem
	visible       []desktop.AppItem
	showAll       bool
	query         string
	cursor        int
	offset        int
	width, height int
	launchErr     string
}

func NewModel(filtered, all []desktop.AppItem, showAll bool, th theme.Theme) Model {
	m := Model{th: th, filteredItems: filtered, allItems: all, showAll: showAll}
	m.RebuildVisible()
	return m
}

func (m *Model) RebuildVisible() {
	base := m.filteredItems
	if m.showAll {
		base = m.allItems
	}
	if m.query == "" {
		m.visible = base
	} else {
		q := strings.ToLower(m.query)
		var out []desktop.AppItem
		for _, a := range base {
			if strings.Contains(strings.ToLower(a.SearchText), q) {
				out = append(out, a)
			}
		}
		m.visible = out
	}
	if m.cursor >= len(m.visible) {
		m.cursor = Max(0, len(m.visible)-1)
	}
	m.ClampOffset()
}

func (m *Model) Lay() Layout { return ComputeLayout(m.width, m.height) }

func (m *Model) ClampOffset() {
	h := m.Lay().BodyH
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

func (m Model) Init() tea.Cmd { return nil }

func (m Model) Update(msg tea.Msg) (tea.Model, tea.Cmd) {
	switch msg := msg.(type) {
	case tea.WindowSizeMsg:
		m.width, m.height = msg.Width, msg.Height
		m.ClampOffset()
	case tea.KeyMsg:
		l := m.Lay()
		switch msg.String() {
		case "ctrl+c", "esc":
			return m, tea.Quit
		case "ctrl+h":
			m.showAll = !m.showAll
			m.cursor, m.offset = 0, 0
			m.RebuildVisible()
		case "up", "ctrl+p", "ctrl+k":
			if m.cursor > 0 {
				m.cursor--
				m.ClampOffset()
			}
		case "down", "ctrl+n", "ctrl+j":
			if m.cursor < len(m.visible)-1 {
				m.cursor++
				m.ClampOffset()
			}
		case "pgup":
			m.cursor = Max(0, m.cursor-l.BodyH)
			m.ClampOffset()
		case "pgdown":
			m.cursor = Min(len(m.visible)-1, m.cursor+l.BodyH)
			m.ClampOffset()
		case "home":
			m.cursor = 0
			m.ClampOffset()
		case "end":
			m.cursor = Max(0, len(m.visible)-1)
			m.ClampOffset()
		case "enter":
			if m.cursor < len(m.visible) {
				sel := m.visible[m.cursor]
				if err := launcher.LaunchApp(sel.ID, sel.DesktopFile); err != nil {
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
				m.RebuildVisible()
			}
		default:
			if msg.Type == tea.KeyRunes {
				m.query += string(msg.Runes)
				m.cursor, m.offset = 0, 0
				m.RebuildVisible()
			}
		}
	}
	return m, nil
}
