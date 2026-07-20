package ui

import "github.com/charmbracelet/bubbles/key"

type keyMap struct {
	Up         key.Binding
	Down       key.Binding
	Toggle     key.Binding
	Filter     key.Binding
	Open       key.Binding
	Peek       key.Binding
	Save       key.Binding
	Apply      key.Binding
	Export     key.Binding
	Reload     key.Binding
	Regen      key.Binding
	Help       key.Binding
	Quit       key.Binding
	Confirm    key.Binding
	Cancel     key.Binding
	FolderUp    key.Binding
	FolderInto  key.Binding
	ToggleHidden key.Binding
	WritePath   key.Binding
	Icons       key.Binding
}

func defaultKeys() keyMap {
	return keyMap{
		Up:           key.NewBinding(key.WithKeys("up", "k"), key.WithHelp("↑/k", "up")),
		Down:         key.NewBinding(key.WithKeys("down", "j"), key.WithHelp("↓/j", "down")),
		Toggle:       key.NewBinding(key.WithKeys("d"), key.WithHelp("d", "dark/light")),
		Filter:       key.NewBinding(key.WithKeys("/"), key.WithHelp("/", "filter")),
		Open:         key.NewBinding(key.WithKeys("o"), key.WithHelp("o", "change folder")),
		Peek:         key.NewBinding(key.WithKeys("w"), key.WithHelp("w", "peek image")),
		Save:         key.NewBinding(key.WithKeys("s"), key.WithHelp("s", "save theme")),
		Apply:        key.NewBinding(key.WithKeys("a"), key.WithHelp("a", "apply theme")),
		Export:       key.NewBinding(key.WithKeys("e"), key.WithHelp("e", "export folder")),
		Reload:       key.NewBinding(key.WithKeys("r"), key.WithHelp("r", "reload")),
		Regen:        key.NewBinding(key.WithKeys("g"), key.WithHelp("g", "regenerate")),
		Help:         key.NewBinding(key.WithKeys("?"), key.WithHelp("?", "help")),
		Quit:         key.NewBinding(key.WithKeys("q", "ctrl+c"), key.WithHelp("q", "quit")),
		Confirm:      key.NewBinding(key.WithKeys("enter"), key.WithHelp("enter", "confirm")),
		Cancel:       key.NewBinding(key.WithKeys("esc"), key.WithHelp("esc", "cancel")),
		FolderUp:     key.NewBinding(key.WithKeys("left", "h"), key.WithHelp("←/h", "up dir")),
		FolderInto:   key.NewBinding(key.WithKeys("right", "l"), key.WithHelp("→/l", "open dir")),
		ToggleHidden: key.NewBinding(key.WithKeys("ctrl+.", "."), key.WithHelp("ctrl+./.", "hidden")),
		WritePath:    key.NewBinding(key.WithKeys("ctrl+p", "p"), key.WithHelp("ctrl+p/p", "path")),
		Icons:        key.NewBinding(key.WithKeys("i"), key.WithHelp("i", "toggle icons/wallpapers")),
	}
}

// shortHelp is the compact keybinding row shown in the footer.
func (k keyMap) shortHelp() []key.Binding {
	return []key.Binding{k.Up, k.Down, k.Toggle, k.Icons, k.Filter, k.Save, k.Apply, k.Export, k.Quit}
}
