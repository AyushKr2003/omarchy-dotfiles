package ui

import (
	"sort"
	"strings"
	"time"
	"unicode"

	tea "github.com/charmbracelet/bubbletea"
	"omarchy-tui-apps/internal/desktop"
	"omarchy-tui-apps/internal/launcher"
	"omarchy-tui-apps/internal/theme"
)

// themePoll is how often the theme file is re-read to follow theme switches.
const themePoll = 500 * time.Millisecond

type themeTickMsg struct{}

type launchMsg struct{ err error }

type Model struct {
	themeSrc      theme.Source
	themeRaw      string
	st            styles
	filteredItems []desktop.AppItem
	allItems      []desktop.AppItem
	visible       []desktop.AppItem
	showAll       bool
	query         string
	tokens        []string
	cursor        int
	offset        int
	width, height int
	launching     bool
	launchErr     string
}

func NewModel(filtered, all []desktop.AppItem, showAll bool, src theme.Source) Model {
	m := Model{themeSrc: src, filteredItems: filtered, allItems: all, showAll: showAll}
	th := theme.Terminal()
	if raw, ok := src.Read(); ok {
		m.themeRaw = raw
		th = theme.Parse(raw)
	}
	m.st = newStyles(th)
	m.RebuildVisible()
	return m
}

func (m *Model) RebuildVisible() {
	base := m.filteredItems
	if m.showAll {
		base = m.allItems
	}
	m.tokens = strings.Fields(strings.ToLower(m.query))
	if len(m.tokens) == 0 {
		m.visible = base
	} else {
		q := strings.Join(m.tokens, " ")
		var out []desktop.AppItem
		ranks := map[string]int{}
		for _, a := range base {
			if matchesAll(a.SearchText, m.tokens) {
				out = append(out, a)
				ranks[a.ID] = rank(strings.ToLower(a.Name), q, m.tokens[0])
			}
		}
		sort.SliceStable(out, func(i, j int) bool {
			return ranks[out[i].ID] < ranks[out[j].ID]
		})
		m.visible = out
	}
	m.cursor = max(0, min(m.cursor, len(m.visible)-1))
	m.ClampOffset()
}

func matchesAll(text string, tokens []string) bool {
	for _, t := range tokens {
		if !strings.Contains(text, t) {
			return false
		}
	}
	return true
}

// rank orders matches so that hits on the name beat hits on the description.
func rank(name, query, first string) int {
	switch {
	case name == query:
		return 0
	case strings.HasPrefix(name, query):
		return 1
	}
	for _, w := range strings.Fields(name) {
		if strings.HasPrefix(w, first) {
			return 2
		}
	}
	if strings.Contains(name, first) {
		return 3
	}
	return 4
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
	m.offset = max(0, min(m.offset, len(m.visible)-h))
}

func (m *Model) moveTo(i int) {
	m.cursor = max(0, min(i, len(m.visible)-1))
	m.ClampOffset()
}

func (m *Model) setQuery(q string) {
	m.query = q
	m.cursor, m.offset = 0, 0
	m.launchErr = ""
	m.RebuildVisible()
}

func themeTick() tea.Cmd {
	return tea.Tick(themePoll, func(time.Time) tea.Msg { return themeTickMsg{} })
}

func (m Model) Init() tea.Cmd { return themeTick() }

func (m Model) Update(msg tea.Msg) (tea.Model, tea.Cmd) {
	switch msg := msg.(type) {
	case tea.WindowSizeMsg:
		m.width, m.height = msg.Width, msg.Height
		m.ClampOffset()
	case themeTickMsg:
		// A theme switch swaps the directory, so the file can be briefly
		// missing; keep the current colors until it is readable again.
		if raw, ok := m.themeSrc.Read(); ok && raw != m.themeRaw {
			m.themeRaw = raw
			m.st = newStyles(theme.Parse(raw))
		}
		return m, themeTick()
	case launchMsg:
		m.launching = false
		if msg.err == nil {
			return m, tea.Quit
		}
		m.launchErr = msg.err.Error()
	case tea.KeyMsg:
		page := max(1, m.Lay().BodyH)
		switch msg.String() {
		case "ctrl+c", "esc":
			return m, tea.Quit
		case "ctrl+h":
			m.showAll = !m.showAll
			m.cursor, m.offset = 0, 0
			m.RebuildVisible()
		case "up", "ctrl+p", "ctrl+k", "shift+tab":
			m.moveTo(m.cursor - 1)
		case "down", "ctrl+n", "ctrl+j", "tab":
			m.moveTo(m.cursor + 1)
		case "pgup":
			m.moveTo(m.cursor - page)
		case "pgdown":
			m.moveTo(m.cursor + page)
		case "home":
			m.moveTo(0)
		case "end":
			m.moveTo(len(m.visible) - 1)
		case "enter":
			if !m.launching && m.cursor < len(m.visible) {
				sel := m.visible[m.cursor]
				m.launching = true
				m.launchErr = ""
				return m, func() tea.Msg { return launchMsg{launcher.LaunchApp(sel)} }
			}
		case "backspace":
			if runes := []rune(m.query); len(runes) > 0 {
				m.setQuery(string(runes[:len(runes)-1]))
			}
		case "ctrl+w":
			q := strings.TrimRightFunc(m.query, unicode.IsSpace)
			m.setQuery(q[:strings.LastIndexFunc(q, unicode.IsSpace)+1])
		case "ctrl+u":
			m.setQuery("")
		default:
			if msg.Alt || (msg.Type != tea.KeyRunes && msg.Type != tea.KeySpace) {
				break
			}
			text := strings.Map(func(r rune) rune {
				if unicode.IsControl(r) {
					return -1
				}
				return r
			}, string(msg.Runes))
			if text != "" {
				m.setQuery(m.query + text)
			}
		}
	}
	return m, nil
}
