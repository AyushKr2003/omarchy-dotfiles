package ui

import "github.com/charmbracelet/lipgloss"

// The chrome uses a fixed, theme-agnostic palette so the app frame stays legible
// regardless of the generated colors (which are shown only inside the preview).
var (
	colHeader = lipgloss.Color("#7aa2f7")
	colBorder = lipgloss.Color("#3b4261")
	colMuted  = lipgloss.Color("#565f89")
	colText   = lipgloss.Color("#c0caf5")
	colOK     = lipgloss.Color("#9ece6a")
	colErr    = lipgloss.Color("#f7768e")
	colSel    = lipgloss.Color("#7aa2f7")
	colSelFg  = lipgloss.Color("#1a1b26")
)

var (
	titleStyle = lipgloss.NewStyle().
			Foreground(colSelFg).Background(colHeader).Bold(true).Padding(0, 1)

	paneStyle = lipgloss.NewStyle().
			Border(lipgloss.RoundedBorder()).BorderForeground(colBorder).Padding(0, 1)

	paneTitleStyle = lipgloss.NewStyle().Foreground(colHeader).Bold(true)

	itemStyle         = lipgloss.NewStyle().Foreground(colText)
	itemGroupStyle    = lipgloss.NewStyle().Foreground(colMuted)
	selectedItemStyle = lipgloss.NewStyle().Foreground(colSelFg).Background(colSel)

	mutedStyle = lipgloss.NewStyle().Foreground(colMuted)
	okStyle    = lipgloss.NewStyle().Foreground(colOK)
	errStyle   = lipgloss.NewStyle().Foreground(colErr)

	badgeDark = lipgloss.NewStyle().
			Foreground(lipgloss.Color("#c0caf5")).Background(lipgloss.Color("#1f2335")).Bold(true).Padding(0, 1)
	badgeLight = lipgloss.NewStyle().
			Foreground(lipgloss.Color("#1a1b26")).Background(lipgloss.Color("#e0af68")).Bold(true).Padding(0, 1)

	promptStyle = lipgloss.NewStyle().Foreground(colHeader)

	// thumbFrameStyle wraps the wallpaper thumbnail in a subtle frame so it
	// reads as a distinct preview tile, like a file manager's image pane.
	thumbFrameStyle = lipgloss.NewStyle().
			Border(lipgloss.RoundedBorder()).BorderForeground(colBorder)

	// sectionLabelStyle heads each preview section (palette, editor).
	sectionLabelStyle = lipgloss.NewStyle().
				Foreground(colMuted).Bold(true)
)
