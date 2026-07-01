package ui

import (
	"fmt"
	"math/rand"
	"time"

	tea "github.com/charmbracelet/bubbletea"
	"github.com/charmbracelet/lipgloss"

	"typetui/internal/snippets"
	"typetui/internal/stats"
	"typetui/internal/theme"
)

// screen identifies which view of the app is currently active.
type screen int

const (
	screenSelect screen = iota
	screenLoading
	screenTyping
	screenResults
)

// source identifies where the active snippet should come from.
type source int

const (
	sourceLocal source = iota
	sourceGitHub
)

// practiceMode mirrors MonkeyType's "words" vs "time" mode toggle.
type practiceMode int

const (
	modeWords practiceMode = iota
	modeTime
)

// timeOptions mirrors MonkeyType's classic 15/30/60/120 second presets.
var timeOptions = []int{15, 30, 60, 120}

// wordCountOptions presets for words mode.
var wordCountOptions = []int{10, 25, 50, 100}

// Selection-screen focus sections, cycled through with Tab / Shift+Tab.
const (
	focusLang      = 0
	focusMode      = 1
	focusWordCount = 2 // only when mode is words
	focusDuration  = 3 // only when mode is time
	focusSource    = 4
)

// fetchResultMsg is sent once a (possibly network) snippet fetch completes.
type fetchResultMsg struct {
	snippet snippets.Snippet
	err     error
}

// tickMsg drives the live timer while typing.
type tickMsg time.Time

// Model is the root bubbletea model for the whole app.
type Model struct {
	styles theme.Styles
	rng    *rand.Rand

	screen screen
	width  int
	height int

	// Selection screen state.
	focus      int
	langIndex  int
	srcIndex   int
	modeIndex  int
	timeIndex  int
	wordIndex  int
	selectErr  string

	// Active snippet + typing state.
	snippet     snippets.Snippet
	target      []rune
	typed       []rune
	correctness []bool
	session     stats.Session
	loadingMsg  string
	timedOut    bool

	// Per-second raw WPM history for the results graph.
	wpmHistory []float64

	// Results screen state.
	result stats.Result
}

// New builds the initial Model.
func New() Model {
	t := theme.Load()
	return Model{
		styles:    theme.NewStyles(t),
		rng:       rand.New(rand.NewSource(time.Now().UnixNano())),
		screen:    screenSelect,
		focus:     focusLang,
		timeIndex: 1,
		wordIndex: 1,
	}
}

// Init satisfies tea.Model.
func (m Model) Init() tea.Cmd {
	return tickCmd()
}

func tickCmd() tea.Cmd {
	return tea.Tick(time.Second, func(t time.Time) tea.Msg {
		return tickMsg(t)
	})
}

func (m Model) mode() practiceMode {
	return practiceMode(m.modeIndex)
}

func (m Model) timeLimit() time.Duration {
	return time.Duration(timeOptions[m.timeIndex]) * time.Second
}

func (m Model) wordLimit() int {
	return wordCountOptions[m.wordIndex]
}

// Update satisfies tea.Model.
func (m Model) Update(msg tea.Msg) (tea.Model, tea.Cmd) {
	switch msg := msg.(type) {
	case tea.WindowSizeMsg:
		m.width = msg.Width
		m.height = msg.Height
		return m, nil

	case tickMsg:
		if m.screen == screenTyping {
			m.recordWPM()
			if m.mode() == modeTime && m.session.Elapsed() >= m.timeLimit() {
				m.recordWPM()
				m.timedOut = true
				m.result = m.session.Finish()
				m.screen = screenResults
			}
		}
		return m, tickCmd()

	case fetchResultMsg:
		return m.handleFetchResult(msg)

	case tea.KeyMsg:
		switch m.screen {
		case screenSelect:
			return m.updateSelect(msg)
		case screenLoading:
			return m.updateLoading(msg)
		case screenTyping:
			return m.updateTyping(msg)
		case screenResults:
			return m.updateResults(msg)
		}
	}
	return m, nil
}

// --- View ------------------------------------------------------------------

// View satisfies tea.Model.
func (m Model) View() string {
	switch m.screen {
	case screenSelect:
		return m.viewSelect()
	case screenLoading:
		return m.viewLoading()
	case screenTyping:
		return m.viewTyping()
	case screenResults:
		return m.viewResults()
	}
	return ""
}

// frame centers boxed content for the select/loading/results screens.
func (m Model) frame(content string) string {
	box := lipgloss.NewStyle().
		BorderStyle(lipgloss.RoundedBorder()).
		BorderForeground(lipgloss.Color(m.styles.Theme.Muted)).
		Padding(1, 3)

	rendered := box.Render(content)

	if m.width > 0 && m.height > 0 {
		return lipgloss.Place(m.width, m.height, lipgloss.Center, lipgloss.Center, rendered)
	}
	return rendered
}

// recordWPM records the current raw-WPM as a data point for the results graph.
func (m *Model) recordWPM() {
	elapsed := m.session.Elapsed()
	if elapsed <= 0 {
		return
	}
	minutes := elapsed.Minutes()
	rawWords := float64(len(m.typed)) / 5.0
	m.wpmHistory = append(m.wpmHistory, rawWords/minutes)
}

func formatDuration(d time.Duration) string {
	d = d.Round(time.Second)
	m := d / time.Minute
	d -= m * time.Minute
	s := d / time.Second
	return fmt.Sprintf("%02d:%02d", m, s)
}
