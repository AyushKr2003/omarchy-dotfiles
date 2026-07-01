package ui

import (
	"fmt"
	"math/rand"
	"strings"

	tea "github.com/charmbracelet/bubbletea"
	"github.com/charmbracelet/lipgloss"

	"typetui/internal/snippets"
	"typetui/internal/stats"
)

// --- Selection screen ------------------------------------------------------

func (m Model) updateSelect(msg tea.KeyMsg) (tea.Model, tea.Cmd) {
	switch msg.String() {
	case "ctrl+c", "q":
		return m, tea.Quit

	case "up", "k":
		if m.focus == focusLang && m.langIndex > 0 {
			m.langIndex--
		}
	case "down", "j":
		if m.focus == focusLang && m.langIndex < len(snippets.Languages)-1 {
			m.langIndex++
		}

	case "left", "h":
		switch m.focus {
		case focusMode:
			m.modeIndex = 1 - m.modeIndex
		case focusWordCount:
			if m.wordIndex > 0 {
				m.wordIndex--
			}
		case focusDuration:
			if m.timeIndex > 0 {
				m.timeIndex--
			}
		case focusSource:
			m.srcIndex = 1 - m.srcIndex
		}

	case "right", "l":
		switch m.focus {
		case focusMode:
			m.modeIndex = 1 - m.modeIndex
		case focusWordCount:
			if m.wordIndex < len(wordCountOptions)-1 {
				m.wordIndex++
			}
		case focusDuration:
			if m.timeIndex < len(timeOptions)-1 {
				m.timeIndex++
			}
		case focusSource:
			m.srcIndex = 1 - m.srcIndex
		}

	case "tab":
		m.focus++
		for m.focus <= focusSource {
			skip := (m.mode() == modeWords && m.focus == focusDuration) ||
				(m.mode() == modeTime && m.focus == focusWordCount)
			if !skip {
				break
			}
			m.focus++
		}
		if m.focus > focusSource {
			m.focus = 0
		}
	case "shift+tab":
		m.focus--
		for m.focus >= 0 {
			skip := (m.mode() == modeWords && m.focus == focusDuration) ||
				(m.mode() == modeTime && m.focus == focusWordCount)
			if !skip {
				break
			}
			m.focus--
		}
		if m.focus < 0 {
			m.focus = focusSource
		}

	case "enter", " ":
		m.selectErr = ""
		m.screen = screenLoading
		m.loadingMsg = "Fetching snippet…"
		lang := snippets.Languages[m.langIndex]
		src := source(m.srcIndex)
		return m, fetchSnippetCmd(lang, src, m.rng)
	}
	return m, nil
}

func fetchSnippetCmd(lang snippets.Language, src source, r *rand.Rand) tea.Cmd {
	return func() tea.Msg {
		if src == sourceGitHub {
			snip, err := snippets.FetchRandomGitHub(lang, r)
			if err == nil {
				return fetchResultMsg{snippet: snip}
			}
			localSnip, localErr := snippets.RandomLocal(lang, r)
			if localErr != nil {
				return fetchResultMsg{err: fmt.Errorf("github failed (%v) and local fallback failed (%v)", err, localErr)}
			}
			return fetchResultMsg{snippet: localSnip}
		}

		snip, err := snippets.RandomLocal(lang, r)
		return fetchResultMsg{snippet: snip, err: err}
	}
}

func (m Model) handleFetchResult(msg fetchResultMsg) (tea.Model, tea.Cmd) {
	if msg.err != nil {
		m.screen = screenSelect
		m.selectErr = msg.err.Error()
		return m, nil
	}

	m.snippet = msg.snippet
	m.target = []rune(strings.ReplaceAll(msg.snippet.Code, "\t", "    "))
	m.typed = nil
	m.correctness = nil
	m.session = stats.Session{}
	m.wpmHistory = nil
	m.timedOut = false
	m.screen = screenTyping
	return m, nil
}

// --- Loading screen --------------------------------------------------------

func (m Model) updateLoading(msg tea.KeyMsg) (tea.Model, tea.Cmd) {
	switch msg.String() {
	case "ctrl+c", "q", "esc":
		m.screen = screenSelect
		return m, nil
	}
	return m, nil
}

// --- Views -----------------------------------------------------------------

func (m Model) viewSelect() string {
	title := m.styles.Accent.Render("typetui") + m.styles.Dim.Render("  — code typing practice")

	var langLines []string
	for i, lang := range snippets.Languages {
		marker := "  "
		style := m.styles.Base
		if i == m.langIndex {
			marker = m.styles.Accent.Render("▸ ")
			style = m.styles.Accent
		}
		langLines = append(langLines, marker+style.Render(lang.Label()))
	}
	langBlock := strings.Join(langLines, "\n")

	srcLabel := func(idx int, label string) string {
		if m.srcIndex == idx {
			return m.styles.Accent.Render("[" + label + "]")
		}
		return m.styles.Dim.Render(" " + label + " ")
	}
	srcLine := srcLabel(0, "Local bank") + "   " + srcLabel(1, "GitHub fetch")

	modeLabel := func(idx int, label string) string {
		if m.modeIndex == idx {
			return m.styles.Accent.Render("[" + label + "]")
		}
		return m.styles.Dim.Render(" " + label + " ")
	}
	modeLine := modeLabel(0, "Words") + "   " + modeLabel(1, "Time")

	secStyle := func(focused bool) lipgloss.Style {
		if focused {
			return m.styles.Accent
		}
		return m.styles.Dim
	}

	var wordCountBlock string
	if m.mode() == modeWords {
		var parts []string
		for i, words := range wordCountOptions {
			label := fmt.Sprintf("%dw", words)
			if i == m.wordIndex {
				parts = append(parts, m.styles.Accent.Render("["+label+"]"))
			} else {
				parts = append(parts, m.styles.Dim.Render(" "+label+" "))
			}
		}
		wordCountBlock = "\n\n" +
			secStyle(m.focus == focusWordCount).Render("Word count") + "\n" +
			strings.Join(parts, "  ")
	}

	var durBlock string
	if m.mode() == modeTime {
		var parts []string
		for i, secs := range timeOptions {
			label := fmt.Sprintf("%ds", secs)
			if i == m.timeIndex {
				parts = append(parts, m.styles.Accent.Render("["+label+"]"))
			} else {
				parts = append(parts, m.styles.Dim.Render(" "+label+" "))
			}
		}
		durBlock = "\n\n" +
			secStyle(m.focus == focusDuration).Render("Duration") + "\n" +
			strings.Join(parts, "  ")
	}

	help := m.styles.HelpText.Render("↑↓ lang   tab focus   ←→ change   enter start   q quit")

	var errLine string
	if m.selectErr != "" {
		errLine = "\n" + m.styles.ErrorText.Render("Error: " + m.selectErr)
	}

	content := title + "\n\n" +
		secStyle(m.focus == focusLang).Render("Language") + "\n" + langBlock + "\n\n" +
		secStyle(m.focus == focusMode).Render("Mode") + "\n" + modeLine +
		wordCountBlock + durBlock + "\n\n" +
		secStyle(m.focus == focusSource).Render("Source") + "\n" + srcLine + "\n" +
		errLine + "\n\n" +
		help

	return m.frame(content)
}

func (m Model) viewLoading() string {
	content := m.styles.Accent.Render(m.loadingMsg) + "\n\n" +
		m.styles.HelpText.Render("esc to cancel")
	return m.frame(content)
}
