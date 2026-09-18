package ui

import (
	"fmt"

	tea "github.com/charmbracelet/bubbletea"

	"omarchy-colorgen/internal/preview"
)

// Run starts the Bubble Tea program with the alt screen enabled.
func Run(m Model) error {
	p := tea.NewProgram(m, tea.WithAltScreen())
	defer func() {
		if m.kitty {
			fmt.Print(preview.WrapTmux("\x1b_Ga=d,d=A\x1b\\"))
		}
	}()
	_, err := p.Run()
	return err
}
