package main

import (
	"fmt"
	"os"
	"path/filepath"
	"sort"
	"strings"

	tea "github.com/charmbracelet/bubbletea"
	"omarchy-tui-apps/internal/desktop"
	"omarchy-tui-apps/internal/theme"
	"omarchy-tui-apps/internal/ui"
)

const usage = `Usage: apps [-a]

  -a, --all    start with hidden and NoDisplay apps shown (toggle with ctrl+h)
  -h, --help   show this help
`

func main() {
	showAll := false
	for _, a := range os.Args[1:] {
		switch a {
		case "-a", "--all":
			showAll = true
		case "-h", "--help":
			fmt.Print(usage)
			return
		default:
			fmt.Fprintf(os.Stderr, "apps: unknown argument %q\n%s", a, usage)
			os.Exit(2)
		}
	}

	home := os.Getenv("HOME")
	omarchyPath := envOr("OMARCHY_PATH", "/usr/share/omarchy")
	hidesFile := envOr("OMARCHY_LAUNCHER_HIDES", firstExisting(
		filepath.Join(omarchyPath, "default/omarchy/launcher.hides"),
		filepath.Join(home, ".local/share/omarchy/default/omarchy/launcher.hides"),
	))
	includeTerminal := envOr("INCLUDE_TERMINAL_APPS", "true") == "true"
	desktopEnv := envOr("XDG_CURRENT_DESKTOP", envOr("XDG_SESSION_DESKTOP", envOr("DESKTOP_SESSION", "")))

	cfg := desktop.ScanCfg{
		HiddenIDs:       desktop.ReadHides(hidesFile),
		CurrentDesktops: strings.Split(desktopEnv, ":"),
		IncludeTerminal: includeTerminal,
	}

	var dirs []string
	dirs = append(dirs, filepath.Join(envOr("XDG_DATA_HOME", filepath.Join(home, ".local/share")), "applications"))
	for _, d := range strings.Split(envOr("XDG_DATA_DIRS", "/usr/local/share:/usr/share"), ":") {
		dirs = append(dirs, filepath.Join(d, "applications"))
	}
	dirs = append(dirs,
		filepath.Join(home, ".nix-profile/share/applications"),
		"/var/lib/flatpak/exports/share/applications",
		filepath.Join(home, ".local/share/flatpak/exports/share/applications"),
	)

	seenAll, seenFilt := map[string]bool{}, map[string]bool{}
	var allApps, filtApps []desktop.AppItem
	for _, dir := range dirs {
		a, f := desktop.ScanDir(dir, cfg, seenAll, seenFilt)
		allApps = append(allApps, a...)
		filtApps = append(filtApps, f...)
	}
	if len(allApps) == 0 && len(filtApps) == 0 {
		fmt.Fprintln(os.Stderr, "no launchable desktop applications found")
		os.Exit(1)
	}

	sortFn := func(apps []desktop.AppItem) {
		sort.SliceStable(apps, func(i, j int) bool {
			return strings.ToLower(apps[i].Name) < strings.ToLower(apps[j].Name)
		})
	}
	sortFn(allApps)
	sortFn(filtApps)

	src := theme.NewSource(os.Getenv("OMARCHY_THEME_COLORS"))
	m := ui.NewModel(filtApps, allApps, showAll, src)
	p := tea.NewProgram(m, tea.WithAltScreen())
	if _, err := p.Run(); err != nil {
		fmt.Fprintln(os.Stderr, err)
		os.Exit(1)
	}
}

func envOr(key, def string) string {
	if v := os.Getenv(key); v != "" {
		return v
	}
	return def
}

func firstExisting(paths ...string) string {
	for _, p := range paths {
		if _, err := os.Stat(p); err == nil {
			return p
		}
	}
	return paths[0]
}
