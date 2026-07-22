package ui

import (
	"fmt"
	"os"
	"os/exec"
	"path/filepath"
	"strings"

	"github.com/charmbracelet/lipgloss"

	"omarchy-colorgen/internal/omarchy"
	"omarchy-colorgen/internal/preview"
)

// kittyDeleteAll sends Kitty graphics protocol escape sequences to delete all
// previously rendered images and placements, preventing ghosting/overlap on redraws.
const kittyDeleteAll = "\x1b_Ga=d,d=A\x1b\\\x1b_Ga=d,d=a\x1b\\\x1b_Ga=d,d=I,i=1\x1b\\\x1b_Ga=d,d=I,i=2\x1b\\\x1b_Ga=d,d=I,i=3\x1b\\"

func (m Model) View() string {
	if !m.ready {
		return "loading…"
	}
	if m.screen == screenFolder {
		return m.folderView()
	}
	if m.width < 60 || m.height < 20 {
		return "terminal too small — resize to at least 60x20"
	}

	title := titleStyle.Render("omarchy-colorgen") + "  " +
		mutedStyle.Render("wallpaper → Omarchy theme")

	modeBadge := badgeDark.Render(" DARK ")
	if m.mode.Label() == "LIGHT" {
		modeBadge = badgeLight.Render(" LIGHT ")
	}
	header := lipgloss.JoinHorizontal(lipgloss.Center,
		title, strings.Repeat(" ", max0(m.width-lipgloss.Width(title)-lipgloss.Width(modeBadge)-2)), modeBadge)

	footer := m.footerView()
	headerH := lipgloss.Height(header)
	footerH := lipgloss.Height(footer)

	body := m.renderBody(headerH, footerH)
	// Clear all previous Kitty images before rendering new frame to prevent overlap
	var prefix string
	if m.kitty {
		prefix = preview.WrapTmux(kittyDeleteAll)
	}
	return prefix + lipgloss.JoinVertical(lipgloss.Left, header, body, footer)
}

func (m Model) renderBody(headerH, footerH int) string {
	// Account for top+bottom pane borders (+2 lines) plus spacing so total height never exceeds m.height
	bodyH := m.height - headerH - footerH - 3
	if bodyH < 4 {
		bodyH = 4
	}
	leftW := 34
	if leftW > m.width/2 {
		leftW = m.width / 2
	}
	rightW := m.width - leftW - 4

	left := paneStyle.Width(leftW).Height(bodyH).Render(m.pickerView(leftW, bodyH))
	right := paneStyle.Width(rightW).Height(bodyH).Render(m.previewView(rightW, bodyH))
	return lipgloss.JoinHorizontal(lipgloss.Top, left, right)
}

func (m Model) pickerView(w, h int) string {
	if m.pickingIcons {
		return m.iconPickerView(w, h)
	}
	var b strings.Builder
	b.WriteString(paneTitleStyle.Render(fmt.Sprintf("Wallpapers (%d)", len(m.filtered))))
	b.WriteString("\n\n")

	cur, hasCurrent := m.current()
	groupOverhead := 0
	if hasCurrent {
		groupOverhead = 2
	}
	rows := h - 3 - groupOverhead
	if rows < 1 {
		rows = 1
	}
	start := 0
	if m.cursor >= rows {
		start = m.cursor - rows + 1
	}
	end := start + rows
	if end > len(m.filtered) {
		end = len(m.filtered)
	}

	inner := w - 2
	if len(m.filtered) == 0 {
		b.WriteString(mutedStyle.Render("no wallpapers found\npress 'o' to open a path"))
		return b.String()
	}

	for i := start; i < end; i++ {
		wp := m.filtered[i]
		label := truncate(wp.Name, inner-2)
		line := "  " + label
		if i == m.cursor {
			line = selectedItemStyle.Width(inner).Render("▸ " + label)
		} else {
			line = itemStyle.Render("  " + label)
		}
		b.WriteString(line)
		b.WriteString("\n")
	}
	if hasCurrent {
		b.WriteString("\n")
		b.WriteString(itemGroupStyle.Render(truncate(cur.Group+"/", inner)))
	}
	return b.String()
}

func (m Model) iconPickerView(w, h int) string {
	var b strings.Builder
	b.WriteString(paneTitleStyle.Render(fmt.Sprintf("Icon Themes (%d)", len(m.filteredIcons))))
	b.WriteString("\n\n")

	rows := h - 3
	if rows < 1 {
		rows = 1
	}
	start := 0
	if m.iconCursor >= rows {
		start = m.iconCursor - rows + 1
	}
	end := start + rows
	if end > len(m.filteredIcons) {
		end = len(m.filteredIcons)
	}

	inner := w - 2
	if len(m.filteredIcons) == 0 {
		b.WriteString(mutedStyle.Render("no icon themes found"))
		return b.String()
	}

	for i := start; i < end; i++ {
		name := m.filteredIcons[i]
		label := truncate(name, inner-2)
		line := "  " + label
		if i == m.iconCursor {
			line = selectedItemStyle.Width(inner).Render("▸ " + label)
		} else {
			line = itemStyle.Render("  " + label)
		}
		b.WriteString(line)
		b.WriteString("\n")
	}
	return b.String()
}

func (m Model) previewView(w, h int) string {
	if m.generating {
		return m.spinner.View() + " generating palette…"
	}
	if !m.haveTheme {
		if m.status != "" {
			return errStyle.Render(m.status)
		}
		return mutedStyle.Render("select a wallpaper to preview")
	}

	inner := w - 4
	if inner < 1 {
		inner = 1
	}
	contentH := h - 2

	var bottomSection string
	if h > 24 && inner >= 66 {
		half := (inner - 2) / 2
		paletteHalf := lipgloss.JoinVertical(lipgloss.Left,
			sectionLabelStyle.Render("PALETTE"), preview.Swatches(m.pal, half))
		editorHalf := lipgloss.JoinVertical(lipgloss.Left,
			sectionLabelStyle.Render("EDITOR"), preview.MockUI(m.pal, half))
		bottomSection = lipgloss.JoinHorizontal(lipgloss.Top,
			paletteHalf, spacerStyle.Render(""), editorHalf)
	} else if h > 24 {
		paletteFull := lipgloss.JoinVertical(lipgloss.Left,
			sectionLabelStyle.Render("PALETTE"), preview.Swatches(m.pal, 0))
		editorFull := lipgloss.JoinVertical(lipgloss.Left,
			sectionLabelStyle.Render("EDITOR"), preview.MockUI(m.pal, 0))
		bottomSection = lipgloss.JoinVertical(lipgloss.Left,
			paletteFull, "", editorFull)
	} else {
		bottomSection = lipgloss.JoinVertical(lipgloss.Left,
			sectionLabelStyle.Render("PALETTE"), preview.Swatches(m.pal, 0))
	}
	bottomH := lipgloss.Height(bottomSection)

	// Background: wallpaper art fills remaining space above palette/editor.
	// Layout: label + art → 2 spacer rows → bottom → 2 bottom margin (padded by pane).
	bgArtRows := contentH - 5 - bottomH
	if bgArtRows < 1 {
		bgArtRows = 1
	}

	var bgSection string
	if cur, ok := m.current(); ok {
		if inner > 30 {
			bgCols := (inner * 2) / 3
			logoCols := inner - bgCols - 4

			// Split available height
			logoRows := bgArtRows / 2
			iconRows := bgArtRows - logoRows - 2 // -2 for label/margin

			art := m.thumbnail(cur.Path, bgCols, bgArtRows)
			logoArt := m.unlockThumbnail(m.pal.Foreground, logoCols, logoRows)
			iconArt := m.iconMockup(m.pal.Accent, logoCols, iconRows)
			
			bgBlock := lipgloss.JoinVertical(lipgloss.Left, sectionLabelStyle.Render("BACKGROUND"), art)
			logoBlock := lipgloss.JoinVertical(lipgloss.Left, sectionLabelStyle.Render("BOOT LOGO"), logoArt)
			iconBlock := lipgloss.JoinVertical(lipgloss.Left, sectionLabelStyle.Render("ICONS"), iconArt)
			
			rightCol := lipgloss.JoinVertical(lipgloss.Left, logoBlock, "\n\n", iconBlock)
			
			bgSection = lipgloss.JoinHorizontal(lipgloss.Top, bgBlock, spacerStyle.Width(4).Render(""), rightCol)
		} else if inner > 8 {
			art := m.thumbnail(cur.Path, inner, bgArtRows)
			bgSection = lipgloss.JoinVertical(lipgloss.Left,
				sectionLabelStyle.Render("BACKGROUND"), art)
		}
	}
	if bgSection == "" {
		return bottomSection
	}

	return strings.Join([]string{bgSection, bottomSection}, "\n\n\n")
}

// thumbnail returns a half-block ANSI wallpaper preview at the given cell
// size, memoized so View does not re-decode the image on every keystroke. The
// cache map is shared across model copies (maps are reference types), so
// writing here from a value receiver persists between renders.
func (m Model) thumbnail(path string, cols, rows int) string {
	key := fmt.Sprintf("%s|%dx%d|kitty:%v", path, cols, rows, m.kitty)
	if s, ok := m.thumbCache[key]; ok {
		return s
	}
	var s string
	if m.kitty {
		s = preview.KittyThumbnail(path, cols, rows)
	} else {
		s = preview.Thumbnail(path, cols, rows)
	}
	m.thumbCache[key] = s
	return s
}

func (m Model) unlockThumbnail(fg string, cols, rows int) string {
	if cols < 1 || rows < 1 {
		return ""
	}
	key := fmt.Sprintf("logo|%s|%dx%d|kitty:%v", fg, cols, rows, m.kitty)
	if s, ok := m.thumbCache[key]; ok {
		return s
	}

	pngKey := "logo:" + fg
	pngBytes, ok := m.pngCache[pngKey]
	if !ok {
		var err error
		pngBytes, err = omarchy.UnlockPNGBytes(fg)
		if err != nil || len(pngBytes) == 0 {
			return "\x1b[2m(logo error)\x1b[0m"
		}
		if m.pngCache == nil {
			m.pngCache = make(map[string][]byte)
		}
		m.pngCache[pngKey] = pngBytes
	}

	var s string
	if m.kitty {
		s = preview.KittyThumbnailBytesWithID(pngBytes, cols, rows, 2)
	} else {
		s = preview.ThumbnailBytes(pngBytes, cols, rows)
	}
	m.thumbCache[key] = s
	return s
}

func (m Model) iconMockup(accent string, cols, rows int) string {
	if cols < 1 || rows < 1 {
		return ""
	}

	themeName := m.iconTheme
	if themeName == "" {
		themeName = omarchy.IconTheme(accent)
	}

	fileStyle := lipgloss.NewStyle().Foreground(lipgloss.Color(m.pal.Foreground))

	key := fmt.Sprintf("icongrid|%s|%dx%d|kitty:%v", themeName, cols, rows, m.kitty)
	if s, ok := m.thumbCache[key]; ok && s != "" && s != "ERR" {
		return s
	}

	pngKey := "icon:" + themeName + "|" + m.pal.Background
	pngBytes, ok := m.pngCache[pngKey]
	if !ok {
		pngBytes = themeIconBytes(themeName, m.pal.Background)
		if m.pngCache == nil {
			m.pngCache = make(map[string][]byte)
		}
		if len(pngBytes) > 0 {
			m.pngCache[pngKey] = pngBytes
		} else {
			m.pngCache[pngKey] = nil
		}
	}

	var grid string
	if len(pngBytes) > 0 {
		if m.kitty {
			grid = preview.KittyThumbnailBytesWithID(pngBytes, cols, rows, 3)
		} else {
			grid = preview.ThumbnailBytes(pngBytes, cols, rows)
		}
		m.thumbCache[key] = grid
	} else {
		m.thumbCache[key] = "ERR"
		grid = fileStyle.Render("(icon preview unavailable)")
	}

	var b strings.Builder
	b.WriteString(mutedStyle.Render("Theme: ") + fileStyle.Render(themeName) + "\n\n")
	b.WriteString(grid)

	return b.String()
}

func (m Model) footerView() string {
	if m.inputMode != inputNone {
		return m.input.View()
	}

	var status string
	if m.status != "" {
		if m.statusErr {
			status = errStyle.Render("✗ " + m.status)
		} else {
			status = okStyle.Render("✓ " + m.status)
		}
	}

	var help string
	if m.showHelp {
		help = m.fullHelp()
	} else {
		var parts []string
		for _, k := range m.keys.shortHelp() {
			h := k.Help()
			parts = append(parts, mutedStyle.Render(h.Key)+" "+h.Desc)
		}
		help = strings.Join(parts, mutedStyle.Render(" · "))
	}

	if status != "" {
		return status + "\n" + help
	}
	return help + "\n" + mutedStyle.Render("press ? for all keys")
}

func (m Model) fullHelp() string {
	lines := []string{
		"↑/k, ↓/j  navigate wallpapers",
		"d         toggle dark / light (default dark)",
		"/         filter list      o  change wallpaper folder",
		"g         regenerate       r  reload wallpaper list",
		"w         peek full image (kitty)",
		"s         save theme       a  save + apply (omarchy-theme-set)",
		"e         export full theme folder",
		"?         toggle help      q  quit",
	}
	return mutedStyle.Render(strings.Join(lines, "\n"))
}

func truncate(s string, n int) string {
	if n < 1 {
		return ""
	}
	if lipgloss.Width(s) <= n {
		return s
	}
	if n <= 1 {
		return "…"
	}
	return s[:n-1] + "…"
}

func max0(n int) int {
	if n < 0 {
		return 0
	}
	return n
}

func themeIconBytes(themeName string, bgColor string) []byte {
	dirs := []string{
		filepath.Join(os.Getenv("HOME"), ".local/share/icons"),
		"/usr/share/icons",
	}
	
	// findIconInTheme searches in the given theme for an icon by name and category
	findIconInTheme := func(theme, name, category string) string {
		for _, base := range dirs {
			themeDir := filepath.Join(base, theme)
			if _, err := os.Stat(themeDir); err == nil {
				for _, size := range []string{"256x256", "256x256@2x", "128x128", "scalable", "48x48", "64x64"} {
					for _, ext := range []string{".png", ".svg"} {
						p := filepath.Join(themeDir, size, category, name+ext)
						if _, err := os.Stat(p); err == nil {
							return p
						}
					}
				}
			}
		}
		return ""
	}

	// Folder icons live in colored themes (Yaru-blue, etc.)
	folderPath := findIconInTheme(themeName, "folder", "places")
	if folderPath == "" {
		// Fall back to base Yaru
		folderPath = findIconInTheme("Yaru", "folder", "places")
	}
	if folderPath == "" {
		return nil
	}

	// File/mimetype icons only exist in the base Yaru theme, not colored variants
	filePath := findIconInTheme(themeName, "text-x-generic", "mimetypes")
	if filePath == "" {
		filePath = findIconInTheme("Yaru", "text-x-generic", "mimetypes")
	}
	if filePath == "" {
		filePath = findIconInTheme("Yaru", "text-plain", "mimetypes")
	}
	if filePath == "" {
		filePath = folderPath
	}

	// Use terminal background color for montage, fallback to dark grey
	bg := bgColor
	if bg == "" {
		bg = "#1e1e2e"
	}

	cmd := exec.Command("magick", "montage", "-background", bg,
		"-label", "Documents", folderPath,
		"-label", "Downloads", folderPath,
		"-label", "Pictures", folderPath,
		"-label", "report.txt", filePath,
		"-geometry", "128x128+15+10", "-tile", "2x2",
		"-font", "Liberation-Sans", "-pointsize", "14",
		"-fill", "#cccccc",
		"png:-")
	out, _ := cmd.Output()
	return out
}
