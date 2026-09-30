package ui

import (
	"strings"
	"unicode"

	"github.com/charmbracelet/lipgloss"
	"github.com/charmbracelet/x/ansi"
)

const (
	gap             = 1  // blank columns between the list and preview boxes
	chromeRows      = 5  // top border, search, separator, bottom border, footer
	minWidth        = 24 // below this the UI is replaced by a notice
	minHeight       = 7
	previewMinWidth = 76 // narrower terminals show the list only
)

// Layout holds the outer widths of the two boxes and the number of list rows.
// PrevW is 0 when the preview is hidden.
type Layout struct {
	ListW, PrevW, BodyH int
}

func ComputeLayout(w, h int) Layout {
	inner := max(0, w-2)
	l := Layout{ListW: inner, BodyH: max(0, h-chromeRows)}
	if w >= previewMinWidth {
		l.PrevW = inner * 42 / 100
		l.ListW = inner - gap - l.PrevW
	}
	return l
}

func spaces(n int) string {
	return strings.Repeat(" ", max(0, n))
}

// fit truncates or pads s (which may contain ANSI styling) to exactly w cells.
func fit(s string, w int) string {
	if w <= 0 {
		return ""
	}
	if ansi.StringWidth(s) > w {
		s = ansi.Truncate(s, w, "…")
	}
	return s + spaces(w-ansi.StringWidth(s))
}

// tail keeps the end of s when it is wider than w, for text being typed.
func tail(s string, w int) string {
	over := ansi.StringWidth(s) - w
	if over <= 0 {
		return s
	}
	return ansi.TruncateLeft(s, over+1, "…")
}

func IconPad(icon string, w int) string {
	pad := w - ansi.StringWidth(icon)
	if pad <= 0 {
		return icon
	}
	return spaces(pad/2) + icon + spaces(pad-pad/2)
}

// wrap breaks s into lines of at most w cells, preferring to break after a
// space or a path separator.
func wrap(s string, w int) []string {
	if w <= 0 {
		return nil
	}
	var lines []string
	for ansi.StringWidth(s) > w {
		cut, soft, cur := 0, 0, 0
		for i, r := range s {
			rw := ansi.StringWidth(string(r))
			if cur+rw > w {
				cut = i
				break
			}
			cur += rw
			if r == ' ' || r == '/' {
				soft = i + 1
			}
		}
		if soft > 0 {
			cut = soft
		}
		if cut == 0 {
			break
		}
		lines = append(lines, strings.TrimRight(s[:cut], " "))
		s = strings.TrimLeft(s[cut:], " ")
	}
	return append(lines, s)
}

// highlight renders s in base, with the first occurrence of each query token
// rendered in hi.
func highlight(s string, tokens []string, base, hi lipgloss.Style) string {
	if len(tokens) == 0 || s == "" {
		return base.Render(s)
	}
	rs := []rune(s)
	low := make([]rune, len(rs))
	for i, r := range rs {
		low[i] = unicode.ToLower(r)
	}
	mark := make([]bool, len(rs))
	for _, t := range tokens {
		tr := []rune(t)
		for i := 0; i+len(tr) <= len(low); i++ {
			if string(low[i:i+len(tr)]) == t {
				for j := range tr {
					mark[i+j] = true
				}
				break
			}
		}
	}
	var sb strings.Builder
	for i := 0; i < len(rs); {
		j := i
		for j < len(rs) && mark[j] == mark[i] {
			j++
		}
		if mark[i] {
			sb.WriteString(hi.Render(string(rs[i:j])))
		} else {
			sb.WriteString(base.Render(string(rs[i:j])))
		}
		i = j
	}
	return sb.String()
}
