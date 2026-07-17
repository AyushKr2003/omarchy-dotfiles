package ui

import tea "github.com/charmbracelet/bubbletea"

// Run starts the Bubble Tea program with the alt screen enabled.
func Run(m Model) error {
	p := tea.NewProgram(m, tea.WithAltScreen())
	_, err := p.Run()
	return err
}
