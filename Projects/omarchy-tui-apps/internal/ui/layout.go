package ui

import (
	"strings"

	"github.com/mattn/go-runewidth"
)

const (
	Gap       = 2 // blank columns between the two inner boxes
	ListPad   = 1 // horizontal padding inside list box (each side)
	PrevPad   = 1 // horizontal padding inside preview box (each side)
	FixedRows = 8
)

type Layout struct {
	InnerW, ListBW, ListBodyW, PrevBW, PrevBodyW, BodyH int
}

func ComputeLayout(w, h int) Layout {
	innerW := Max(0, w-2)
	prevBW := int(float64(innerW) * 0.46)
	listBW := Max(0, innerW-prevBW-Gap)
	return Layout{
		InnerW:    innerW,
		ListBW:    listBW,
		ListBodyW: Max(0, listBW-2-2*ListPad),
		PrevBW:    prevBW,
		PrevBodyW: Max(0, prevBW-2-2*PrevPad),
		BodyH:     Max(0, h-FixedRows),
	}
}

func IconPad(icon string, w int) string {
	cur := runewidth.StringWidth(icon)
	if cur >= w {
		return icon
	}
	pad := w - cur
	return strings.Repeat(" ", pad/2) + icon + strings.Repeat(" ", pad-pad/2)
}

func Truncate(s string, maxW int) string {
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

func WrapToLines(s string, maxW int) []string {
	if maxW <= 0 {
		return []string{s}
	}
	var lines []string
	for {
		if runewidth.StringWidth(s) <= maxW {
			lines = append(lines, s)
			break
		}
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

func StripANSI(s string) string {
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

func Vw(s string) int {
	return runewidth.StringWidth(StripANSI(s))
}

func Pad(s string, w int) string {
	n := w - Vw(s)
	if n <= 0 {
		return s
	}
	return s + strings.Repeat(" ", n)
}

func Max(a, b int) int {
	if a > b {
		return a
	}
	return b
}

func Min(a, b int) int {
	if a < b {
		return a
	}
	return b
}
