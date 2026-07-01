package ui

import (
	"fmt"
	"strings"

	tea "github.com/charmbracelet/bubbletea"
	"github.com/charmbracelet/lipgloss"
)

// --- Typing screen ---------------------------------------------------------

func (m Model) updateTyping(msg tea.KeyMsg) (tea.Model, tea.Cmd) {
	switch msg.String() {
	case "ctrl+c":
		return m, tea.Quit
	case "esc":
		m.screen = screenSelect
		return m, nil
	}

	switch msg.Type {
	case tea.KeyBackspace:
		if len(m.typed) > 0 {
			m.typed = m.typed[:len(m.typed)-1]
			m.correctness = m.correctness[:len(m.correctness)-1]
		}
		return m, nil

	case tea.KeyEnter:
		return m.typeRune('\n')

	case tea.KeyTab:
		model := m
		for i := 0; i < 4; i++ {
			next, cmd := model.typeRune(' ')
			model = next.(Model)
			if model.screen == screenResults {
				return model, cmd
			}
		}
		return model, nil

	case tea.KeySpace:
		return m.typeRune(' ')

	case tea.KeyRunes:
		model := m
		for _, r := range msg.Runes {
			next, cmd := model.typeRune(r)
			model = next.(Model)
			if model.screen == screenResults {
				return model, cmd
			}
		}
		return model, nil
	}

	return m, nil
}

// typeRune registers one typed character against the target text and
// advances the session.
func (m Model) typeRune(r rune) (tea.Model, tea.Cmd) {
	if len(m.target) == 0 {
		return m, nil
	}

	m.session.Start()

	pos := len(m.typed) % len(m.target)
	correct := m.target[pos] == r

	m.typed = append(m.typed, r)
	m.correctness = append(m.correctness, correct)
	m.session.RecordKeystroke(correct)

	atEnd := len(m.typed)%len(m.target) == 0

	if m.mode() == modeWords {
		wordsTyped := len(m.typed) / 5
		if wordsTyped >= m.wordLimit() || atEnd {
			m.recordWPM()
			m.result = m.session.Finish()
			m.screen = screenResults
		}
	} else if atEnd {
		// time mode: just keep going
	}

	return m, nil
}

// --- View ------------------------------------------------------------------

// viewTyping renders a three-section layout with bordered bars,
// scrolled code viewport, and an optional finger-coloured keyboard.
func (m Model) viewTyping() string {
	elapsed := m.session.Elapsed()

	// ── build styled code string + track cursor line ──────────────────
	var b strings.Builder
	cursorLine := 0
	var nextChar rune = ' '
	if len(m.target) > 0 {
		cycle := len(m.typed) / len(m.target)
		cycleStart := cycle * len(m.target)
		cursorPos := len(m.typed) % len(m.target)
		nextChar = m.target[cursorPos]

		for _, r := range m.target[:cursorPos] {
			if r == '\n' {
				cursorLine++
			}
		}

		for i, r := range m.target {
			ch := string(r)
			if r == '\n' {
				ch = "\u21b5\n"
			}
			typedIdx := cycleStart + i
			isTyped := i < cursorPos && typedIdx < len(m.typed)
			switch {
			case isTyped:
				if m.correctness[typedIdx] {
					b.WriteString(m.styles.Correct.Render(ch))
				} else if r == '\n' {
					b.WriteString(m.styles.Incorrect.Render("\u21b5") + "\n")
				} else {
					b.WriteString(m.styles.Incorrect.Render(ch))
				}
			case i == cursorPos:
				if r == '\n' {
					b.WriteString(m.styles.Cursor.Render(" ") + "\n")
				} else {
					b.WriteString(m.styles.Cursor.Render(ch))
				}
			default:
				b.WriteString(m.styles.Dim.Render(ch))
			}
		}
	}

	// ── header & footer ───────────────────────────────────────────────
	src := m.snippet.Source
	if src == "local" {
		src = "local bank"
	}
	meta := m.styles.Dim.Render(fmt.Sprintf("%s \u00b7 %s \u00b7 %s", m.snippet.Language.Label(), src, m.snippet.Path))

	var timerText string
	if m.mode() == modeTime {
		remaining := m.timeLimit() - elapsed
		if remaining < 0 {
			remaining = 0
		}
		timerText = formatDuration(remaining)
	} else {
		timerText = formatDuration(elapsed)
	}
	timer := m.styles.StatValue.Render(timerText)

	var wordCount string
	if m.mode() == modeWords {
		words := len(m.typed) / 5
		wordCount = m.styles.StatValue.Render(fmt.Sprintf("%d / %d words", words, m.wordLimit()))
	}

	var progress string
	if m.mode() == modeTime {
		progress = m.styles.Dim.Render(fmt.Sprintf("%d typed", len(m.typed)))
	} else {
		progress = m.styles.Dim.Render(fmt.Sprintf("%d / %d", len(m.typed), len(m.target)))
	}

	var header string
	if m.mode() == modeWords {
		header = meta + "\n" + timer + "   " + wordCount + "   " + progress
	} else {
		header = meta + "\n" + timer + "   " + progress
	}
	help := m.styles.HelpText.Render("esc to cancel and pick a new snippet")
	codeStr := b.String()

	if m.width <= 0 || m.height <= 0 || len(m.target) == 0 {
		return header + "\n\n" + codeStr + "\n\n" + help
	}

	// ── three-section layout (inside outer border) ────────────────────
	innerW := m.width - 2
	innerH := m.height - 2

	borderColor := lipgloss.Color(m.styles.Theme.Muted)
	topBarStyle := lipgloss.NewStyle().
		Width(innerW).
		Padding(1, 2).
		Border(lipgloss.NormalBorder()).
		BorderForeground(borderColor).
		BorderTop(false).
		BorderRight(false).
		BorderBottom(true).
		BorderLeft(false)
	bottomBarStyle := lipgloss.NewStyle().
		Width(innerW).
		Padding(1, 2).
		Border(lipgloss.NormalBorder()).
		BorderForeground(borderColor).
		BorderTop(true).
		BorderRight(false).
		BorderBottom(false).
		BorderLeft(false)
	topBarStr := topBarStyle.Render(header)
	bottomBarStr := bottomBarStyle.Render(help)

	topLines := lipgloss.Height(topBarStr)
	bottomLines := lipgloss.Height(bottomBarStr)
	middleHeight := innerH - topLines - bottomLines - 2
	if middleHeight < 1 {
		middleHeight = 1
	}

	// ── decide whether to show the keyboard ───────────────────────────
	const kbdTotal = 6
	showKeyboard := middleHeight >= kbdTotal+3
	codeHeight := middleHeight
	if showKeyboard {
		codeHeight = middleHeight - kbdTotal
	}

	// ── dim filler: pad codeStr to at least codeHeight lines ─────────
	var dimBuf strings.Builder
	for _, r := range m.target {
		ch := string(r)
		if r == '\n' {
			ch = "\u21b5\n"
		}
		dimBuf.WriteString(m.styles.Dim.Render(ch))
	}
	dimStr := dimBuf.String()
	dimLines := strings.Count(dimStr, "\n") + 1
	for dimLines > 0 && strings.Count(codeStr, "\n")+1 < codeHeight {
		codeStr += dimStr
	}

	// ── scroll to keep cursor visible in the code viewport ───────────
	allLines := strings.Split(codeStr, "\n")
	totalLines := len(allLines)
	viewOffset := cursorLine - codeHeight/3
	if viewOffset < 0 {
		viewOffset = 0
	}
	maxOffset := totalLines - codeHeight
	if maxOffset < 0 {
		maxOffset = 0
	}
	if viewOffset > maxOffset {
		viewOffset = maxOffset
	}
	endLine := viewOffset + codeHeight
	if endLine > totalLines {
		endLine = totalLines
	}
	visible := strings.Join(allLines[viewOffset:endLine], "\n")

	// ── assemble middle ───────────────────────────────────────────────
	var middleStr string
	if showKeyboard {
		sep := m.styles.Dim.Render(strings.Repeat("\u2500", innerW-4))
		kbd := m.renderKeyboard(nextChar, innerW)
		middleStr = visible + "\n" + sep + "\n" + kbd
	} else {
		middleStr = visible
	}
	middle := lipgloss.NewStyle().Width(innerW).Height(middleHeight).Render(middleStr)

	// ── wrap everything in an outer border ────────────────────────────
	outer := lipgloss.NewStyle().
		Border(lipgloss.NormalBorder()).
		BorderForeground(borderColor)
	return outer.Render(topBarStr + "\n" + middle + "\n" + bottomBarStr)
}
