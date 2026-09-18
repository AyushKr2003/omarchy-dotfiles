package desktop

import (
	"bufio"
	"os"
	"path/filepath"
	"sort"
	"strings"
)

const (
	IconApp      = "󱗼"
	IconTerminal = ""
	IconFlatpak  = "󰏖"
	IconPrompt   = ""
)

type AppItem struct {
	Icon        string
	Name        string
	SubTitle    string
	ID          string
	DesktopFile string
	SearchText  string
	Exec        string
	Terminal    bool
	RawType     string
	RawComment  string
}

type DesktopEntry struct {
	EntryType   string
	Name        string
	GenericName string
	Comment     string
	Exec        string
	Terminal    bool
	Hidden      bool
	NoDisplay   bool
	OnlyShowIn  []string
	NotShowIn   []string
}

type ScanCfg struct {
	HiddenIDs       map[string]bool
	CurrentDesktops []string
	IncludeTerminal bool
}

func ParseDesktopFile(path string) (DesktopEntry, bool) {
	f, err := os.Open(path)
	if err != nil {
		return DesktopEntry{}, false
	}
	defer f.Close()

	var e DesktopEntry
	inEntry := false
	sc := bufio.NewScanner(f)
	for sc.Scan() {
		line := strings.TrimRight(sc.Text(), "\r")
		if strings.HasPrefix(line, "[") {
			inEntry = line == "[Desktop Entry]"
			continue
		}
		if !inEntry {
			continue
		}
		idx := strings.IndexByte(line, '=')
		if idx < 0 {
			continue
		}
		key := strings.TrimSpace(line[:idx])
		val := strings.TrimSpace(line[idx+1:])
		switch key {
		case "Type":
			if e.EntryType == "" {
				e.EntryType = val
			}
		case "Name":
			if e.Name == "" {
				e.Name = val
			}
		case "GenericName":
			if e.GenericName == "" {
				e.GenericName = val
			}
		case "Comment":
			if e.Comment == "" {
				e.Comment = val
			}
		case "Exec":
			if e.Exec == "" {
				e.Exec = val
			}
		case "Terminal":
			if !e.Terminal {
				e.Terminal = strings.EqualFold(val, "true")
			}
		case "Hidden":
			e.Hidden = strings.EqualFold(val, "true")
		case "NoDisplay":
			e.NoDisplay = strings.EqualFold(val, "true")
		case "OnlyShowIn":
			if e.OnlyShowIn == nil {
				e.OnlyShowIn = SplitSemi(val)
			}
		case "NotShowIn":
			if e.NotShowIn == nil {
				e.NotShowIn = SplitSemi(val)
			}
		}
	}
	return e, true
}

func SplitSemi(s string) []string {
	var out []string
	for _, p := range strings.Split(s, ";") {
		if p != "" {
			out = append(out, p)
		}
	}
	return out
}

func DesktopID(dir, path string) string {
	rel, _ := filepath.Rel(dir, path)
	rel = strings.TrimSuffix(rel, ".desktop")
	return strings.ReplaceAll(rel, "/", "-")
}

func IsFlatpakDir(dir string) bool {
	return strings.Contains(dir, "flatpak/exports/share/applications")
}

func MatchesDesktop(list, current []string) bool {
	for _, d := range current {
		if d == "" {
			continue
		}
		for _, c := range list {
			if c == d {
				return true
			}
		}
	}
	return false
}

func IsTerminalExec(exec string) bool {
	return strings.HasPrefix(exec, "xdg-terminal-exec") ||
		strings.Contains(exec, " xdg-terminal-exec ")
}

func ScanDir(dir string, cfg ScanCfg, seenAll, seenFilt map[string]bool) (all, filt []AppItem) {
	entries, err := os.ReadDir(dir)
	if err != nil {
		return
	}
	isFP := IsFlatpakDir(dir)
	var paths []string
	for _, e := range entries {
		if e.IsDir() {
			a, f := ScanDir(filepath.Join(dir, e.Name()), cfg, seenAll, seenFilt)
			all = append(all, a...)
			filt = append(filt, f...)
			continue
		}
		if strings.HasSuffix(e.Name(), ".desktop") {
			paths = append(paths, filepath.Join(dir, e.Name()))
		}
	}
	sort.Strings(paths)
	for _, path := range paths {
		e, ok := ParseDesktopFile(path)
		if !ok || (e.EntryType != "" && e.EntryType != "Application") {
			continue
		}
		if e.Name == "" || e.Exec == "" {
			continue
		}
		id := DesktopID(dir, path)
		icon := IconApp
		if isFP {
			icon = IconFlatpak
		} else if e.Terminal || IsTerminalExec(e.Exec) {
			icon = IconTerminal
		}
		sub := e.GenericName
		if sub == "" {
			sub = e.Comment
		}
		item := AppItem{
			Icon:        icon,
			Name:        e.Name,
			SubTitle:    sub,
			ID:          id,
			DesktopFile: path,
			SearchText:  strings.TrimSpace(e.Name + " " + sub + " " + e.Comment + " " + id),
			Exec:        e.Exec,
			Terminal:    e.Terminal,
			RawType:     e.EntryType,
			RawComment:  e.Comment,
		}
		if !seenAll[id] {
			seenAll[id] = true
			if cfg.IncludeTerminal || !e.Terminal {
				all = append(all, item)
			}
		}
		if seenFilt[id] || cfg.HiddenIDs[id] || e.Hidden || e.NoDisplay {
			continue
		}
		if len(e.OnlyShowIn) > 0 && !MatchesDesktop(e.OnlyShowIn, cfg.CurrentDesktops) {
			continue
		}
		if len(e.NotShowIn) > 0 && MatchesDesktop(e.NotShowIn, cfg.CurrentDesktops) {
			continue
		}
		if !cfg.IncludeTerminal && e.Terminal {
			continue
		}
		seenFilt[id] = true
		filt = append(filt, item)
	}
	return
}

func ReadHides(path string) map[string]bool {
	out := make(map[string]bool)
	f, err := os.Open(path)
	if err != nil {
		return out
	}
	defer f.Close()
	sc := bufio.NewScanner(f)
	for sc.Scan() {
		id := strings.TrimSuffix(strings.TrimRight(sc.Text(), "\r\n"), ".desktop")
		if id != "" {
			out[id] = true
		}
	}
	return out
}
