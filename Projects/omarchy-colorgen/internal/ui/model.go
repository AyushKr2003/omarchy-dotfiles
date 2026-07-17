// Package ui implements the Bubble Tea terminal UI for omarchy-colorgen.
package ui

import (
	"fmt"
	"os"
	"path/filepath"
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

	status    string
	statusErr bool
	showHelp  bool

	kitty     bool
	omarchyOK bool
	width     int
	height    int
	ready     bool
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
		keys:      defaultKeys(),
		spinner:   sp,
		input:     ti,
		screen:    screenFolder,
		mode:      mode,
		cache:     make(map[string]iris.Theme),
		kitty:     kittyAvailable(),
		omarchyOK: omarchy.SetAvailable(),
	}
	m.initFolder(defaultStartDir())
	return m
}

func (m Model) Init() tea.Cmd {
	return m.spinner.Tick
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
	return generateCmd(w.Path, m.mode)
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
		return m, cmd

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
			return m.updateFolder(msg)
		}
		if m.inputMode != inputNone {
			return m.updateInput(msg)
		}
		return m.updateNormal(msg)
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

	case key.Matches(msg, m.keys.Up):
		if m.cursor > 0 {
			m.cursor--
			return m, m.regenerate()
		}
		return m, nil

	case key.Matches(msg, m.keys.Down):
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
		m.beginInput(inputFilter, "filter: ", "")
		return m, nil

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
		m.beginInput(inputExport, "export theme folder: ", defaultExportPath(m))
		return m, nil
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
		if err := omarchy.Build(dir, m.pal, w.Path); err != nil {
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
	}
	return m, nil
}

func (m Model) saveTheme(name string, apply bool) (tea.Model, tea.Cmd) {
	if !m.haveTheme {
		m.setStatus("generate a palette first", true)
		return m, nil
	}
	w, _ := m.current()
	dir, err := omarchy.WriteTheme(name, m.pal, w.Path)
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
	m.beginInput(inputSave, label, def)
	return m, nil
}

func (m *Model) beginInput(mode inputMode, prompt, value string) {
	m.inputMode = mode
	m.input.Prompt = prompt
	m.input.SetValue(value)
	m.input.CursorEnd()
	m.input.Focus()
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
