package omarchy

import (
	"os"
	"path/filepath"
	"strings"
	"testing"

	"omarchy-colorgen/internal/palette"
)

func samplePalette() palette.Palette {
	return palette.Palette{
		Mode: "dark", Accent: "#d9a8f0",
		Background: "#181825", DarkBackground: "#111119", DarkerBackground: "#0c0c12",
		LighterBackground: "#26263b", Selection: "#26263b", Muted: "#54546e",
		DarkForeground: "#54546e", Foreground: "#daabf0", LightForeground: "#daabf0", BrightForeground: "#daabf0",
		Red: "#eea0d9", Yellow: "#eea0d9", Orange: "#eea0d9", Green: "#54a2b6",
		Cyan: "#c1d095", Blue: "#d9a8f0", Magenta: "#95d0c1", Brown: "#77506c",
		BrightRed: "#f1b3e1", BrightYellow: "#f1b3e1", BrightGreen: "#76b5c5",
		BrightCyan: "#cdd9aa", BrightBlue: "#e1b9f3", BrightMagenta: "#aad9cd",
	}
}

func TestColorsTOMLShape(t *testing.T) {
	out := ColorsTOML(samplePalette(), "/path/to/wall.png")

	for _, want := range []string{
		"mode = \"dark\"",
		"accent = \"#d9a8f0\"",
		"background = \"#181825\"",
		"dark_background = \"#111119\"",
		"selection = \"#26263b\"",
		"bright_magenta = \"#aad9cd\"",
		"# Source wallpaper: /path/to/wall.png",
	} {
		if !strings.Contains(out, want) {
			t.Errorf("colors.toml missing %q\n---\n%s", want, out)
		}
	}
}

func TestSlug(t *testing.T) {
	cases := map[string]string{
		"My Cool Theme":  "my-cool-theme",
		"forest_night":   "forest-night",
		"  Spaces  ":     "spaces",
		"weird!!chars??": "weirdchars",
		"--dashes--":     "dashes",
	}
	for in, want := range cases {
		if got := Slug(in); got != want {
			t.Errorf("Slug(%q) = %q want %q", in, got, want)
		}
	}
}

func TestExport(t *testing.T) {
	dir := t.TempDir()
	path := filepath.Join(dir, "sub", "colors.toml")
	if err := Export(path, samplePalette(), "wall.png"); err != nil {
		t.Fatalf("export: %v", err)
	}
	data, err := os.ReadFile(path)
	if err != nil {
		t.Fatalf("read: %v", err)
	}
	if !strings.Contains(string(data), "background = \"#181825\"") {
		t.Error("exported file missing expected content")
	}
}

func TestWriteTheme(t *testing.T) {
	dir := t.TempDir()
	t.Setenv("HOME", dir)

	// A wallpaper file to copy.
	wall := filepath.Join(dir, "wall.png")
	if err := os.WriteFile(wall, []byte("fake"), 0o644); err != nil {
		t.Fatal(err)
	}

	themeDir, err := WriteTheme("Test Theme", samplePalette(), wall)
	if err != nil {
		t.Fatalf("write theme: %v", err)
	}
	if filepath.Base(themeDir) != "test-theme" {
		t.Errorf("theme dir = %q", themeDir)
	}
	if _, err := os.Stat(filepath.Join(themeDir, "colors.toml")); err != nil {
		t.Error("colors.toml not written")
	}
	if _, err := os.Stat(filepath.Join(themeDir, "icons.theme")); err != nil {
		t.Error("icons.theme not written")
	}
	if _, err := os.Stat(filepath.Join(themeDir, "backgrounds", "wall.png")); err != nil {
		t.Error("wallpaper not copied into backgrounds/")
	}
}
