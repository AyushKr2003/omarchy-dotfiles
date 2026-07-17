package ui

import (
	"os"
	"os/exec"
	"strings"

	tea "github.com/charmbracelet/bubbletea"

	"omarchy-colorgen/internal/iris"
)

// generatedMsg carries the result of an iris run back into Update.
type generatedMsg struct {
	path  string
	mode  iris.Mode
	theme iris.Theme
	err   error
}

// statusMsg sets a transient status line (used by save/apply/export flows).
type statusMsg struct {
	text string
	err  bool
}

// generateCmd runs iris asynchronously for the given wallpaper and mode.
func generateCmd(path string, mode iris.Mode) tea.Cmd {
	return func() tea.Msg {
		t, err := iris.Generate(path, mode)
		return generatedMsg{path: path, mode: mode, theme: t, err: err}
	}
}

// cacheKey uniquely identifies an iris result.
func cacheKey(path string, mode iris.Mode) string {
	return path + "\x00" + mode.FlagString()
}

// kittyAvailable reports whether the terminal can display images via kitten icat.
func kittyAvailable() bool {
	if _, err := exec.LookPath("kitten"); err != nil {
		return false
	}
	if os.Getenv("KITTY_WINDOW_ID") != "" {
		return true
	}
	return strings.Contains(strings.ToLower(os.Getenv("TERM")), "kitty")
}

// peekCmd shows the wallpaper full-size via kitten icat and waits for a keypress,
// suspending the TUI while it runs.
func peekCmd(path string) tea.Cmd {
	script := `clear; kitten icat --align=center "$1"; printf '\n[ press Enter to return ]'; read -r _`
	c := exec.Command("bash", "-c", script, "peek", path)
	return tea.ExecProcess(c, func(err error) tea.Msg {
		if err != nil {
			return statusMsg{text: "image preview failed: " + err.Error(), err: true}
		}
		return statusMsg{text: ""}
	})
}
