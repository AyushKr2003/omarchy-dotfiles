package ui

import (
	"fmt"
	"math"
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
		m.loadingMsg = "Fetching snippet\u2026"
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

	// ── header ──────────────────────────────────────────────────────────
	meta := m.styles.Dim.Render(
		fmt.Sprintf("  %s \u00b7 %s \u00b7 %s", m.snippet.Language.Label(), m.modeLabel(), m.snippet.Path))

	var timeoutNote string
	if m.timedOut {
		timeoutNote = " " + m.styles.Dim.Render("(timed out)")
	}

	// ── stats (single row) ──────────────────────────────────────────────
	sep := m.styles.Dim.Render("   \u00b7   ")
	stat := func(label, value string) string {
		return m.styles.StatLabel.Render(label+"  ") + m.styles.StatValue.Render(value)
	}
	stats := stat("    WPM", fmt.Sprintf("%.1f", r.WPM)) + sep +
		stat("Raw", fmt.Sprintf("%.1f", r.RawWPM)) + sep +
		stat("Accuracy", fmt.Sprintf("%.1f%%", r.Accuracy)) + sep +
		stat("Time", formatDuration(r.Duration)) + sep +
		stat("Errors", fmt.Sprintf("%d", r.ErrorCount))

	// ── graph ───────────────────────────────────────────────────────────
	graphW := m.width - 20
	if graphW < 50 {
		graphW = 50
	}
	if graphW > 80 {
		graphW = 80
	}

	graph := m.renderWPMGraph(r.Duration, graphW)
	div := m.styles.Dim.Render(strings.Repeat("\u2500", graphW+7))

	// ── footer ──────────────────────────────────────────────────────────
	help := m.styles.HelpText.Render("     r retry            \u00b7            enter/esc menu            \u00b7            q quit")

	content := meta + timeoutNote + "\n\n" + stats + "\n\n"
	if graph != "" {
		content += div + "\n" +
			m.styles.Dim.Render("  Raw WPM over time") + "\n\n" +
			m.styles.Base.Render(graph) + "\n" + div + "\n"
	} else {
		content += div + "\n"
	}
	content += help

	return m.frame(content)
}

func (m Model) modeLabel() string {
	if m.mode() == modeTime {
		return fmt.Sprintf("Time %ds", timeOptions[m.timeIndex])
	}
	return fmt.Sprintf("Words %dw", m.wordLimit())
}

// renderWPMGraph draws a compact line graph of raw WPM over time.
func (m Model) renderWPMGraph(duration time.Duration, graphW int) string {
	const graphH = 4
	if len(m.wpmHistory) < 2 {
		return ""
	}

	// Find data range, skipping noisy startup spikes.
	minWPM := math.MaxFloat64
	maxWPM := 0.0
	startIdx := 3
	if startIdx >= len(m.wpmHistory) {
		startIdx = 0
	}
	for _, v := range m.wpmHistory[startIdx:] {
		if v < minWPM {
			minWPM = v
		}
		if v > maxWPM {
			maxWPM = v
		}
	}
	if minWPM > maxWPM {
		minWPM = 0
	}

	// Expand range by 20% for visual breathing room.
	rng := maxWPM - minWPM
	pad := rng * 0.2
	if pad < 3 {
		pad = 3
	}
	lo := minWPM - pad
	hi := maxWPM + pad
	if lo < 0 {
		lo = 0
	}
	rng = hi - lo
	if rng < 1 {
		rng = 1
	}

	// Interpolate across full width.
	n := graphW
	pts := make([]float64, n)
	last := len(m.wpmHistory) - 1
	for i := 0; i < n; i++ {
		pos := float64(i) / float64(n-1) * float64(last)
		idx := int(pos)
		frac := pos - float64(idx)
		next := idx + 1
		if next > last {
			next = last
		}
		pts[i] = m.wpmHistory[idx]*(1-frac) + m.wpmHistory[next]*frac
	}

	// Y-axis with clean tick labels.
	tick := rng / float64(graphH-1)
	base := math.Pow(10, math.Floor(math.Log10(tick)))
	tick = math.Ceil(tick/base) * base
	hi = math.Ceil(hi/base) * base
	lo = hi - tick*float64(graphH-1)
	if lo < 0 {
		lo = 0
		hi = tick * float64(graphH-1)
	}
	labels := make([]string, graphH)
	for i := range labels {
		val := hi - float64(i)*tick
		labels[i] = fmt.Sprintf("%4.0f\u2502", val)
	}

	// Scale to y-position.
	scaled := make([]float64, n)
	for i, v := range pts {
		scaled[i] = float64(graphH-1) - (v-lo)/(hi-lo)*float64(graphH-1)
	}

	// Draw on grid.
	grid := make([][]rune, graphH)
	for y := range grid {
		grid[y] = make([]rune, n)
	}
	for x := 0; x < n-1; x++ {
		y1 := scaled[x]
		y2 := scaled[x+1]
		dy := y2 - y1
		steps := int(math.Abs(dy)) + 1
		if steps < 1 {
			steps = 1
		}
		for s := 1; s < steps; s++ {
			t := float64(s) / float64(steps)
			cy := int(math.Round(y1 + dy*t))
			if cy >= 0 && cy < graphH && grid[cy][x] == 0 {
				if dy > 0 {
					grid[cy][x] = '\u2572'
				} else {
					grid[cy][x] = '\u2571'
				}
			}
		}
	}
	for x := 0; x < n; x++ {
		y := int(math.Round(scaled[x]))
		if y < 0 {
			y = 0
		}
		if y >= graphH {
			y = graphH - 1
		}
		grid[y][x] = '\u25CF'
	}

	// Build rows.
	rows := make([]string, graphH)
	for y := range rows {
		var b strings.Builder
		b.WriteString(labels[y])
		for x := 0; x < n; x++ {
			ch := grid[y][x]
			if ch == 0 {
				ch = ' '
			}
			b.WriteRune(ch)
		}
		rows[y] = b.String()
	}

	// X-axis.
	totalSec := int(duration.Seconds())
	if totalSec < 1 {
		totalSec = 1
	}
	secLabel := fmt.Sprintf("%ds", totalSec)

	var xAxis strings.Builder
	xAxis.WriteString("    \u2514")
	xAxis.WriteString(strings.Repeat("\u2500", n))
	xAxis.WriteRune('\n')

	lw := n + 5
	lb := make([]byte, lw)
	for i := range lb {
		lb[i] = ' '
	}
	if 5 < lw {
		lb[5] = '0'
	}
	if 6 < lw {
		lb[6] = 's'
	}
	endStart := 5 + n - len(secLabel)
	if endStart >= 5 && endStart+len(secLabel) <= lw {
		copy(lb[endStart:], secLabel)
	}
	if totalSec >= 12 {
		midSec := totalSec / 2
		midLabel := fmt.Sprintf("%ds", midSec)
		midStart := 5 + n/2 - len(midLabel)/2
		if midStart > 5 && midStart+len(midLabel) <= lw {
			copy(lb[midStart:], midLabel)
		}
	}
	xAxis.Write(lb)

	return strings.Join(rows, "\n") + "\n" + xAxis.String()
}
