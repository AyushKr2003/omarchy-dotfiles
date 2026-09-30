package ui

import (
	"strings"
	"testing"

	tea "github.com/charmbracelet/bubbletea"
	"github.com/charmbracelet/x/ansi"
	"omarchy-tui-apps/internal/desktop"
	"omarchy-tui-apps/internal/theme"
)

func testApps() []desktop.AppItem {
	var apps []desktop.AppItem
	for _, n := range []string{"Alacritty", "Btop", "Chromium", "Files", "Firefox", "Kitty", "LibreOffice Writer", "Text Editor"} {
		apps = append(apps, desktop.AppItem{
			Icon:        desktop.IconApp,
			Name:        n,
			SubTitle:    "A fairly long generic description of " + n,
			ID:          strings.ToLower(n),
			DesktopFile: "/usr/share/applications/" + strings.ToLower(n) + ".desktop",
			SearchText:  strings.ToLower(n),
			Exec:        "/usr/bin/" + strings.ToLower(n) + " --some-flag %U",
		})
	}
	return apps
}

func sized(m Model, w, h int) Model {
	next, _ := m.Update(tea.WindowSizeMsg{Width: w, Height: h})
	return next.(Model)
}

func key(m Model, s string) Model {
	msg := tea.KeyMsg{Type: tea.KeyRunes, Runes: []rune(s)}
	if s == " " {
		msg = tea.KeyMsg{Type: tea.KeySpace, Runes: []rune(s)}
	}
	next, _ := m.Update(msg)
	return next.(Model)
}

// The view must fill the window exactly at every size, including ones too
// small to lay out, without panicking.
func TestViewFitsWindow(t *testing.T) {
	apps := testApps()
	base := NewModel(apps, apps, false, theme.NewSource("/nonexistent"))
	for w := 1; w <= 140; w++ {
		for _, h := range []int{1, 6, 7, 8, 12, 40} {
			for _, q := range []string{"", "fire", "zzzz"} {
				m := key(sized(base, w, h), q)
				lines := strings.Split(m.View(), "\n")
				if len(lines) > h {
					t.Fatalf("%dx%d q=%q: %d lines", w, h, q, len(lines))
				}
				if w >= minWidth && h >= minHeight && len(lines) != h {
					t.Fatalf("%dx%d q=%q: %d lines, want %d", w, h, q, len(lines), h)
				}
				for i, l := range lines {
					if got := ansi.StringWidth(l); got > w {
						t.Fatalf("%dx%d q=%q: line %d is %d wide", w, h, q, i, got)
					}
				}
			}
		}
	}
}

func TestSearch(t *testing.T) {
	apps := testApps()
	m := sized(NewModel(apps, apps, false, theme.NewSource("/nonexistent")), 100, 20)

	m = key(m, "text")
	m = key(m, " ")
	m = key(m, "ed")
	if m.query != "text ed" || len(m.visible) != 1 || m.visible[0].Name != "Text Editor" {
		t.Fatalf("query %q matched %v", m.query, m.visible)
	}

	m.setQuery("e")
	if m.visible[0].Name != "Text Editor" {
		t.Fatalf("name-word matches should rank first, got %q", m.visible[0].Name)
	}

	m.setQuery("zzzz")
	next, _ := m.Update(tea.KeyMsg{Type: tea.KeyPgDown})
	if c := next.(Model).cursor; c != 0 {
		t.Fatalf("cursor left the list: %d", c)
	}
}
