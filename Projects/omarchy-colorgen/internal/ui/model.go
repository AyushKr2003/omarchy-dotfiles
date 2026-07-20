// Package ui implements the Bubble Tea terminal UI for omarchy-colorgen.
package ui

import (
	"fmt"
	"os"
	"path/filepath"
	"sort"
	"strings"

	"github.com/charmbracelet/bubbles/key"
	"github.com/charmbracelet/bubbles/spinner"
	"github.com/charmbracelet/bubbles/textinput"
	tea "github.com/charmbracelet/bubbletea"

	"omarchy-colorgen/internal/iris"
	"omarchy-colorgen/internal/omarchy"
	"omarchy-colorgen/internal/palette"
	"omarchy-colorgen/internal/wallpaper"
)

type inputMode int

const (
	inputNone inputMode = iota
	inputFilter
	inputSave
	inputExport
	inputPath
)

// Model is the root Bubble Tea model.
type Model struct {
	keys    keyMap
	spinner spinner.Model
	input   textinput.Model

	screen screenState

	// Folder-picker state (shown on launch until a wallpaper folder is chosen).
	fpDir    string
	fpDirs   []string
	fpCursor int

	srcDir   string // the folder the current wallpaper list came from
	all      []wallpaper.Wallpaper
	filtered []wallpaper.Wallpaper
	cursor   int

	pickingIcons  bool
	allIcons      []string
	filteredIcons []string
	iconCursor    int

	mode  iris.Mode
	cache map[string]iris.Theme

	// thumbCache memoizes rendered wallpaper thumbnails by "path|colsxrows" so
	// View never re-decodes an image on a keystroke or spinner tick.
	thumbCache map[string]string

	theme      iris.Theme
	pal        palette.Palette
	haveTheme  bool
	generating bool

	inputMode  inputMode
	applyAfter bool // when saving, also run omarchy-theme-set

	iconTheme string // custom selected icon theme, empty means default Yaru logic

	status    string
	statusErr bool
	showHelp  bool

	showHidden bool
	kitty      bool
	omarchyOK  bool
	width      int
	height     int
	ready      bool
}

// New builds the initial model. The UI opens on the folder picker so the user
// chooses where their wallpapers live before anything is generated.
func New(mode iris.Mode) Model {
	sp := spinner.New()
	sp.Spinner = spinner.Dot

	ti := textinput.New()
	ti.Prompt = "> "
	ti.PromptStyle = promptStyle
	ti.CharLimit = 256

	m := Model{
		keys:          defaultKeys(),
		spinner:       sp,
		input:         ti,
		screen:        screenFolder,
		mode:          mode,
		cache:         make(map[string]iris.Theme),
		thumbCache:    make(map[string]string),
		kitty:         kittyAvailable(),
		omarchyOK:     omarchy.SetAvailable(),
		allIcons:      loadIconThemes(),
	}
	m.filteredIcons = m.allIcons
	m.initFolder(defaultStartDir())
	return m
}

func (m Model) Init() tea.Cmd {
	if m.generating {
		return m.spinner.Tick
	}
	return nil
}

// current returns the selected wallpaper, if any.
func (m Model) current() (wallpaper.Wallpaper, bool) {
	if m.cursor < 0 || m.cursor >= len(m.filtered) {
		return wallpaper.Wallpaper{}, false
	}
	return m.filtered[m.cursor], true
}

// regenerate returns a command that produces the palette for the current
// selection, using the cache when possible.
func (m *Model) regenerate() tea.Cmd {
	w, ok := m.current()
	if !ok {
		return nil
	}
	if t, cached := m.cache[cacheKey(w.Path, m.mode)]; cached {
		m.theme = t
		m.pal = palette.FromIris(t)
		m.haveTheme = true
		m.generating = false
		return nil
	}
	m.generating = true
	return tea.Batch(generateCmd(w.Path, m.mode), m.spinner.Tick)
}

func (m Model) Update(msg tea.Msg) (tea.Model, tea.Cmd) {
	switch msg := msg.(type) {
	case tea.WindowSizeMsg:
		m.width, m.height = msg.Width, msg.Height
		m.ready = true
		return m, nil

	case spinner.TickMsg:
		var cmd tea.Cmd
		m.spinner, cmd = m.spinner.Update(msg)
		if m.generating {
			return m, cmd
		}
		return m, nil

	case generatedMsg:
		// Ignore stale results if the selection/mode changed meanwhile.
		w, ok := m.current()
		if ok && msg.path == w.Path && msg.mode == m.mode {
			m.generating = false
			if msg.err != nil {
				m.haveTheme = false
				m.status = msg.err.Error()
				m.statusErr = true
			} else {
				m.cache[cacheKey(msg.path, msg.mode)] = msg.theme
				m.theme = msg.theme
				m.pal = palette.FromIris(msg.theme)
				m.haveTheme = true
				m.status = ""
				m.statusErr = false
			}
		}
		return m, nil

	case statusMsg:
		m.status = msg.text
		m.statusErr = msg.err
		return m, nil

	case tea.KeyMsg:
		if m.screen == screenFolder {
			if m.inputMode == inputPath {
				return m.updateInput(msg)
			}
			return m.updateFolder(msg)
		}
		if m.inputMode != inputNone {
			return m.updateInput(msg)
		}
		return m.updateNormal(msg)
	}

	// Forward unhandled messages to the active textinput so its cursor blink
	// and other internal state stays alive.
	if m.inputMode != inputNone {
		var cmd tea.Cmd
		m.input, cmd = m.input.Update(msg)
		return m, cmd
	}
	return m, nil
}

func (m Model) updateNormal(msg tea.KeyMsg) (tea.Model, tea.Cmd) {
	switch {
	case key.Matches(msg, m.keys.Quit):
		return m, tea.Quit

	case key.Matches(msg, m.keys.Help):
		m.showHelp = !m.showHelp
		return m, nil

	case key.Matches(msg, m.keys.Icons):
		m.pickingIcons = !m.pickingIcons
		return m, nil

	case key.Matches(msg, m.keys.Up):
		if m.pickingIcons {
			if m.iconCursor > 0 {
				m.iconCursor--
				m.iconTheme = m.filteredIcons[m.iconCursor]
			}
			return m, nil
		}
		if m.cursor > 0 {
			m.cursor--
			return m, m.regenerate()
		}
		return m, nil

	case key.Matches(msg, m.keys.Down):
		if m.pickingIcons {
			if m.iconCursor < len(m.filteredIcons)-1 {
				m.iconCursor++
				m.iconTheme = m.filteredIcons[m.iconCursor]
			}
			return m, nil
		}
		if m.cursor < len(m.filtered)-1 {
			m.cursor++
			return m, m.regenerate()
		}
		return m, nil

	case key.Matches(msg, m.keys.Toggle):
		if m.mode == iris.Dark {
			m.mode = iris.Light
		} else {
			m.mode = iris.Dark
		}
		return m, m.regenerate()

	case key.Matches(msg, m.keys.Regen):
		if w, ok := m.current(); ok {
			delete(m.cache, cacheKey(w.Path, m.mode))
		}
		return m, m.regenerate()

	case key.Matches(msg, m.keys.Reload):
		if m.pickingIcons {
			m.allIcons = loadIconThemes()
			m.applyIconFilter("")
			return m, nil
		}
		dir := m.srcDir
		if dir == "" {
			dir = defaultStartDir()
		}
		m.all = wallpaper.Scan([]string{dir})
		m.applyFilter("")
		return m, m.regenerate()

	case key.Matches(msg, m.keys.Peek):
		if !m.kitty {
			m.setStatus("image peek needs a kitty terminal", true)
			return m, nil
		}
		if w, ok := m.current(); ok {
			return m, peekCmd(w.Path)
		}
		return m, nil

	case key.Matches(msg, m.keys.Filter):
		if m.pickingIcons {
			return m, m.beginInput(inputFilter, "filter icons: ", "")
		}
		return m, m.beginInput(inputFilter, "filter: ", "")

	case key.Matches(msg, m.keys.Open):
		// Reopen the folder picker to switch wallpaper directories.
		start := m.srcDir
		if start == "" {
			start = defaultStartDir()
		}
		m.screen = screenFolder
		m.initFolder(start)
		return m, nil

	case key.Matches(msg, m.keys.Save):
		return m.beginSave(false)

	case key.Matches(msg, m.keys.Apply):
		return m.beginSave(true)

	case key.Matches(msg, m.keys.Export):
		if !m.haveTheme {
			m.setStatus("nothing to export yet", true)
			return m, nil
		}
		return m, m.beginInput(inputExport, "export theme folder: ", defaultExportPath(m))
	}
	return m, nil
}

func (m Model) updateInput(msg tea.KeyMsg) (tea.Model, tea.Cmd) {
	switch {
	case key.Matches(msg, m.keys.Cancel):
		m.endInput()
		return m, nil

	case key.Matches(msg, m.keys.Confirm):
		val := strings.TrimSpace(m.input.Value())
		mode := m.inputMode
		m.endInput()
		return m.confirmInput(mode, val)
	}

	var cmd tea.Cmd
	m.input, cmd = m.input.Update(msg)
	if m.inputMode == inputFilter {
		if m.pickingIcons {
			m.applyIconFilter(m.input.Value())
			return m, cmd
		}
		m.applyFilter(m.input.Value())
		return m, tea.Batch(cmd, m.regenerate())
	}
	return m, cmd
}

func (m Model) confirmInput(mode inputMode, val string) (tea.Model, tea.Cmd) {
	switch mode {
	case inputFilter:
		return m, nil

	case inputExport:
		if val == "" {
			return m, nil
		}
		w, _ := m.current()
		dir := expand(val)
		if err := omarchy.Build(dir, m.pal, w.Path, m.iconTheme); err != nil {
			m.setStatus("export failed: "+err.Error(), true)
		} else {
			m.setStatus("exported theme folder → "+val, false)
		}
		return m, nil

	case inputSave:
		if val == "" {
			m.setStatus("theme name required", true)
			return m, nil
		}
		return m.saveTheme(val, m.applyAfter)

	case inputPath:
		if val == "" {
			return m, nil
		}
		val = expand(val)
		info, err := os.Stat(val)
		if err != nil || !info.IsDir() {
			m.setStatus("not a directory: "+val, true)
			return m, nil
		}
		m.initFolder(val)
		return m, nil
	}
	return m, nil
}

func (m Model) saveTheme(name string, apply bool) (tea.Model, tea.Cmd) {
	if !m.haveTheme {
		m.setStatus("generate a palette first", true)
		return m, nil
	}
	w, _ := m.current()
	dir, err := omarchy.WriteTheme(name, m.pal, w.Path, m.iconTheme)
	if err != nil {
		m.setStatus("save failed: "+err.Error(), true)
		return m, nil
	}
	if !apply {
		m.setStatus("saved theme → "+dir, false)
		return m, nil
	}
	if !m.omarchyOK {
		m.setStatus("saved, but omarchy-theme-set not found", true)
		return m, nil
	}
	if err := omarchy.Apply(name); err != nil {
		m.setStatus("apply failed: "+err.Error(), true)
		return m, nil
	}
	m.setStatus("applied theme '"+omarchy.Slug(name)+"'", false)
	return m, nil
}

func (m *Model) beginSave(apply bool) (tea.Model, tea.Cmd) {
	if !m.haveTheme {
		m.setStatus("generate a palette first", true)
		return m, nil
	}
	m.applyAfter = apply
	def := ""
	if w, ok := m.current(); ok {
		def = suggestName(w.Name)
	}
	label := "save as: "
	if apply {
		label = "apply as: "
	}
	return m, m.beginInput(inputSave, label, def)
}

func (m *Model) beginInput(mode inputMode, prompt, value string) tea.Cmd {
	m.inputMode = mode
	m.input.Prompt = prompt
	m.input.SetValue(value)
	m.input.CursorEnd()
	return m.input.Focus()
}

func (m *Model) endInput() {
	m.inputMode = inputNone
	m.input.Blur()
	m.input.SetValue("")
}

func (m *Model) setStatus(text string, isErr bool) {
	m.status = text
	m.statusErr = isErr
}

func (m *Model) applyFilter(q string) {
	q = strings.ToLower(strings.TrimSpace(q))
	if q == "" {
		m.filtered = m.all
	} else {
		var out []wallpaper.Wallpaper
		for _, w := range m.all {
			if strings.Contains(strings.ToLower(w.Name), q) ||
				strings.Contains(strings.ToLower(w.Group), q) {
				out = append(out, w)
			}
		}
		m.filtered = out
	}
	if m.cursor >= len(m.filtered) {
		m.cursor = len(m.filtered) - 1
	}
	if m.cursor < 0 {
		m.cursor = 0
	}
}

func (m *Model) applyIconFilter(q string) {
	q = strings.ToLower(strings.TrimSpace(q))
	if q == "" {
		m.filteredIcons = m.allIcons
	} else {
		var out []string
		for _, name := range m.allIcons {
			if strings.Contains(strings.ToLower(name), q) {
				out = append(out, name)
			}
		}
		m.filteredIcons = out
	}
	if m.iconCursor >= len(m.filteredIcons) {
		m.iconCursor = len(m.filteredIcons) - 1
	}
	if m.iconCursor < 0 {
		m.iconCursor = 0
	}
	if len(m.filteredIcons) > 0 {
		m.iconTheme = m.filteredIcons[m.iconCursor]
	} else {
		m.iconTheme = ""
	}
}

func suggestName(fileName string) string {
	base := strings.TrimSuffix(fileName, filepath.Ext(fileName))
	return omarchy.Slug(base)
}

func defaultExportPath(m Model) string {
	name := "colorgen"
	if w, ok := m.current(); ok {
		name = suggestName(w.Name)
	}
	return fmt.Sprintf("./%s-theme", name)
}

func expand(p string) string {
	if strings.HasPrefix(p, "~/") {
		return filepath.Join(os.Getenv("HOME"), p[2:])
	}
	if p == "~" {
		return os.Getenv("HOME")
	}
	return p
}

func loadIconThemes() []string {
	var themes []string
	seen := make(map[string]bool)
	
	dirs := []string{
		"/usr/share/icons",
		filepath.Join(os.Getenv("HOME"), ".local/share/icons"),
	}
	
	for _, d := range dirs {
		entries, err := os.ReadDir(d)
		if err != nil {
			continue
		}
		for _, e := range entries {
			if e.IsDir() {
				// verify it has an index.theme
				if _, err := os.Stat(filepath.Join(d, e.Name(), "index.theme")); err == nil {
					if !seen[e.Name()] {
						seen[e.Name()] = true
						themes = append(themes, e.Name())
					}
				}
			}
		}
	}
	
	sort.Strings(themes)
	return themes
}
