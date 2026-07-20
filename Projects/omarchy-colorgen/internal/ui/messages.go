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

// kittyAvailable reports whether the terminal supports the Kitty graphics protocol.
// Supports Kitty, Ghostty, WezTerm, Konsole natively, and tmux pass-through.
func kittyAvailable() bool {
	if os.Getenv("KITTY_WINDOW_ID") != "" ||
		os.Getenv("GHOSTTY_RESOURCES_DIR") != "" ||
		os.Getenv("GHOSTTY_BIN_DIR") != "" ||
		os.Getenv("WEZTERM_PANE") != "" ||
		os.Getenv("WEZTERM_EXECUTABLE") != "" ||
		os.Getenv("KONSOLE_VERSION") != "" {
		return true
	}
	term := strings.ToLower(os.Getenv("TERM"))
	return strings.Contains(term, "kitty") ||
		strings.Contains(term, "ghostty") ||
		strings.Contains(term, "wezterm")
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
