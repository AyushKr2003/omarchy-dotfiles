package ui

import (
	"fmt"
	"strings"
	"time"

	tea "github.com/charmbracelet/bubbletea"

	"typetui/internal/snippets"
)

// --- Results screen --------------------------------------------------------

func (m Model) updateResults(msg tea.KeyMsg) (tea.Model, tea.Cmd) {
	switch msg.String() {
	case "ctrl+c", "q":
		return m, tea.Quit
	case "r":
		m.screen = screenLoading
		m.loadingMsg = "Fetching snippet…"
		lang := snippets.Languages[m.langIndex]
		src := source(m.srcIndex)
		return m, fetchSnippetCmd(lang, src, m.rng)
	case "enter", "esc":
		m.screen = screenSelect
		return m, nil
	}
	return m, nil
}

// --- View ------------------------------------------------------------------

func (m Model) viewResults() string {
	r := m.result

	// ── header ──────────────────────────────────────────────────────
	title := m.styles.Accent.Render("Results")
	modeLabel := fmt.Sprintf("Words %dw", m.wordLimit())
	if m.mode() == modeTime {
		modeLabel = fmt.Sprintf("Time %ds", timeOptions[m.timeIndex])
	}
	meta := m.styles.Dim.Render(fmt.Sprintf("%s · %s · %s", m.snippet.Language.Label(), modeLabel, m.snippet.Path))

	var timeoutNote string
	if m.timedOut {
		timeoutNote = " " + m.styles.Dim.Render("(timed out)")
	}

	// ── stats in a side-by-side grid ────────────────────────────────
	stat := func(label, value string) string {
		return m.styles.StatLabel.Render(fmt.Sprintf("%-10s", label)) +
			m.styles.StatValue.Render(value)
	}
	stats := stat("WPM", fmt.Sprintf("%-6s", fmt.Sprintf("%.1f", r.WPM))) + "  " +
		stat("Accuracy", fmt.Sprintf("%.1f%%", r.Accuracy)) + "\n" +
		stat("Raw", fmt.Sprintf("%-6s", fmt.Sprintf("%.1f", r.RawWPM))) + "  " +
		stat("Time", formatDuration(r.Duration)) + "\n" +
		stat("Errors", fmt.Sprintf("%d", r.ErrorCount))

	// ── divider (matches graph width) ──────────────────────────────
	gw := m.width - 20
	if gw < 40 {
		gw = 40
	}
	if gw > 160 {
		gw = 160
	}
	ng := len(m.wpmHistory)
	if ng > gw {
		ng = gw
	}
	if ng < 2 {
		ng = 2
	}
	kg := 1
	if ng > 0 {
		kg = gw / ng
	}
	if kg < 1 {
		kg = 1
	}
	if kg > 3 {
		kg = 3
	}
	div := m.styles.Dim.Render(strings.Repeat("─", ng*kg+7))

	// ── graph ───────────────────────────────────────────────────────
	graph := m.renderWPMGraph(r.Duration)
	var graphBlock string
	if graph != "" {
		graphBlock = "\n" + div + "\n" +
			m.styles.Dim.Render("Raw WPM over time") + "\n\n" +
			m.styles.Base.Render(graph)
		graphBlock += "\n"
	}

	// ── footer ──────────────────────────────────────────────────────
	help := m.styles.HelpText.Render("r retry   enter menu   q quit")

	content := title + " " + meta + timeoutNote + "\n\n" +
		stats + graphBlock + "\n\n" +
		div + "\n" +
		help
	return m.frame(content)
}

// renderWPMGraph draws an ASCII bar chart of raw WPM over time.
func (m Model) renderWPMGraph(duration time.Duration) string {
	const graphH = 5
	if len(m.wpmHistory) < 2 {
		return ""
	}

	availW := m.width - 20
	if availW < 40 {
		availW = 40
	}
	if availW > 160 {
		availW = 160
	}

	maxWPM := 0.0
	for _, v := range m.wpmHistory {
		if v > maxWPM {
			maxWPM = v
		}
	}
	roundTo := 10.0
	if maxWPM < 50 {
		roundTo = 5.0
	}
	if maxWPM < 10 {
		roundTo = 2.0
	}
	maxWPM = float64(int(maxWPM/roundTo)+1) * roundTo

	// Downsample to fit, taking the peak WPM per bucket so bursts
	// are preserved instead of being averaged away.
	n := len(m.wpmHistory)
	if n > availW {
		n = availW
	}
	if n < 2 {
		n = 2
	}
	step := float64(len(m.wpmHistory)) / float64(n)
	downsampled := make([]float64, n)
	for i := range downsampled {
		start := int(float64(i) * step)
		end := int(float64(i+1) * step)
		if end > len(m.wpmHistory) {
			end = len(m.wpmHistory)
		}
		if start >= end {
			continue
		}
		maxV := 0.0
		for _, v := range m.wpmHistory[start:end] {
			if v > maxV {
				maxV = v
			}
		}
		downsampled[i] = maxV
	}

	// Stretch factor: when fewer data points than available columns,
	// repeat each bar character so the graph fills the width.
	k := 1
	if n > 0 {
		k = availW / n
	}
	if k < 1 {
		k = 1
	}
	if k > 3 {
		k = 3
	}
	totalBars := n * k

	yLabels := make([]string, graphH)
	for i := range yLabels {
		val := maxWPM - float64(i)*maxWPM/float64(graphH)
		yLabels[i] = fmt.Sprintf("%4.0f ┤ ", val)
	}

	rows := make([]string, graphH)
	for row := 0; row < graphH; row++ {
		threshold := maxWPM - float64(row)*maxWPM/float64(graphH)
		nextThreshold := maxWPM - float64(row+1)*maxWPM/float64(graphH)
		var line strings.Builder
		line.WriteString(yLabels[row])
		for _, wpm := range downsampled {
			var ch rune
			switch {
			case wpm >= threshold:
				ch = '█'
			case wpm >= nextThreshold && nextThreshold > 0:
				fill := (wpm - nextThreshold) / (threshold - nextThreshold)
				blocks := []rune{' ', '▁', '▂', '▃', '▄', '▅', '▆', '▇', '█'}
				idx := int(fill * 8)
				if idx < 0 {
					idx = 0
				}
				if idx > 8 {
					idx = 8
				}
				ch = blocks[idx]
			default:
				ch = ' '
			}
			for j := 0; j < k; j++ {
				line.WriteRune(ch)
			}
		}
		rows[row] = line.String()
	}

	// ── x-axis line ──────────────────────────────────────────────────
	totalSec := int(duration.Seconds())
	if totalSec < 1 {
		totalSec = 1
	}
	secLabel := fmt.Sprintf("%ds", totalSec)

	var xAxis strings.Builder
	xAxis.WriteString("     └")
	xAxis.WriteString(strings.Repeat("─", totalBars+1))
	xAxis.WriteRune('\n')

	lineWidth := totalBars + 7
	labels := make([]byte, lineWidth)
	for i := range labels {
		labels[i] = ' '
	}

	labels[5] = '0'
	if 6 < lineWidth {
		labels[6] = 's'
	}

	endStart := 7 + totalBars - len(secLabel)
	if endStart >= 5 && endStart+len(secLabel) <= lineWidth {
		copy(labels[endStart:], secLabel)
	}

	if totalSec >= 12 {
		midSec := totalSec / 2
		midLabel := fmt.Sprintf("%ds", midSec)
		midStart := 6 + (totalBars+1)/2 - len(midLabel)/2
		if midStart > 5 && midStart+len(midLabel) <= lineWidth {
			copy(labels[midStart:], midLabel)
		}
	}

	xAxis.Write(labels)

	return strings.Join(rows, "\n") + "\n" + xAxis.String()
}
