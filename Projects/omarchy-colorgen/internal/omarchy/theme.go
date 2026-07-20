package omarchy

import (
	"bytes"
	_ "embed"
	"errors"
	"fmt"
	"io"
	"os"
	"os/exec"
	"path/filepath"
	"regexp"
	"strings"

	"omarchy-colorgen/internal/palette"
	"omarchy-colorgen/internal/preview"
)

//go:embed logo.svg
var logoSVG []byte

// ThemesDir is where user themes live.
func ThemesDir() string {
	return filepath.Join(os.Getenv("HOME"), ".config", "omarchy", "themes")
}

// SetAvailable reports whether omarchy-theme-set is on PATH.
func SetAvailable() bool {
	_, err := exec.LookPath("omarchy-theme-set")
	return err == nil
}

var slugRe = regexp.MustCompile(`[^a-z0-9-]+`)

// Slug normalizes a user-supplied theme name into an Omarchy theme directory
// name: lowercase, spaces/underscores to dashes, stray characters dropped.
func Slug(name string) string {
	s := strings.ToLower(strings.TrimSpace(name))
	s = strings.ReplaceAll(s, " ", "-")
	s = strings.ReplaceAll(s, "_", "-")
	s = slugRe.ReplaceAllString(s, "")
	s = strings.Trim(s, "-")
	return s
}

// Build populates an existing directory with a full Omarchy theme layout,
// matching the first-party themes under omarchy-repo/themes: colors.toml, a
// backgrounds/ directory holding the wallpaper, icons.theme, preview.png, and a
// light.mode marker for light themes. Config files (alacritty, hyprland, waybar,
// …) are intentionally omitted: omarchy-theme-set renders those from templates
// on apply, so shipping them here would only fight the generator.
func Build(dir string, p palette.Palette, wallpaper string) error {
	bgDir := filepath.Join(dir, "backgrounds")
	if err := os.MkdirAll(bgDir, 0o755); err != nil {
		return err
	}

	if err := os.WriteFile(filepath.Join(dir, "colors.toml"), []byte(ColorsTOML(p, wallpaper)), 0o644); err != nil {
		return err
	}

	if err := os.WriteFile(filepath.Join(dir, "icons.theme"), []byte(iconTheme(p.Accent)+"\n"), 0o644); err != nil {
		return err
	}

	// A generated preview is best-effort; a failure here should not abort a save.
	_ = preview.RenderPNG(p, filepath.Join(dir, "preview.png"))

	// Also generate the Plymouth/SDDM unlock.png from the embedded SVG logo
	_ = RenderUnlockPNG(p.Foreground, filepath.Join(dir, "unlock.png"))

	if p.Mode == "light" {
		if err := os.WriteFile(filepath.Join(dir, "light.mode"), nil, 0o644); err != nil {
			return err
		}
	}

	if wallpaper != "" {
		dst := filepath.Join(bgDir, filepath.Base(wallpaper))
		if err := copyFile(wallpaper, dst); err != nil {
			return fmt.Errorf("copying wallpaper: %w", err)
		}
	}
	return nil
}

// WriteTheme builds a full theme under ~/.config/omarchy/themes/<slug>/ and
// returns the theme directory path.
func WriteTheme(name string, p palette.Palette, wallpaper string) (string, error) {
	slug := Slug(name)
	if slug == "" {
		return "", errors.New("theme name is empty after normalization")
	}
	dir := filepath.Join(ThemesDir(), slug)
	if err := Build(dir, p, wallpaper); err != nil {
		return "", err
	}
	return dir, nil
}

// Apply runs `omarchy-theme-set <slug>` to render and activate the theme.
func Apply(name string) error {
	if !SetAvailable() {
		return errors.New("omarchy-theme-set not found on PATH")
	}
	slug := Slug(name)
	cmd := exec.Command("omarchy-theme-set", slug)
	if out, err := cmd.CombinedOutput(); err != nil {
		msg := strings.TrimSpace(string(out))
		if msg == "" {
			return err
		}
		return fmt.Errorf("%s", msg)
	}
	return nil
}

// iconTheme picks the closest Yaru icon accent for the palette accent color,
// matching the "Yaru-<color>" values first-party themes ship in icons.theme.
func iconTheme(accent string) string {
	c, err := palette.ParseHex(accent)
	if err != nil {
		return "Yaru-blue"
	}
	// Near-grayscale accents fall back to the neutral Yaru theme.
	if maxByte(c.R, c.G, c.B)-minByte(c.R, c.G, c.B) < 24 {
		return "Yaru"
	}
	switch h := c.Hue(); {
	case h < 15 || h >= 345:
		return "Yaru-red"
	case h < 45:
		return "Yaru-orange"
	case h < 70:
		return "Yaru-yellow"
	case h < 155:
		return "Yaru-olive"
	case h < 185:
		return "Yaru-sage"
	case h < 260:
		return "Yaru-blue"
	case h < 300:
		return "Yaru-purple"
	default:
		return "Yaru-magenta"
	}
}

func maxByte(vs ...uint8) uint8 {
	m := vs[0]
	for _, v := range vs[1:] {
		if v > m {
			m = v
		}
	}
	return m
}

func minByte(vs ...uint8) uint8 {
	m := vs[0]
	for _, v := range vs[1:] {
		if v < m {
			m = v
		}
	}
	return m
}

// Export writes just the colors.toml content to an arbitrary path.
func Export(path string, p palette.Palette, wallpaper string) error {
	if d := filepath.Dir(path); d != "" {
		if err := os.MkdirAll(d, 0o755); err != nil {
			return err
		}
	}
	return os.WriteFile(path, []byte(ColorsTOML(p, wallpaper)), 0o644)
}

func copyFile(src, dst string) error {
	in, err := os.Open(src)
	if err != nil {
		return err
	}
	defer in.Close()

	out, err := os.Create(dst)
	if err != nil {
		return err
	}
	defer out.Close()

	if _, err := io.Copy(out, in); err != nil {
		return err
	}
	return out.Close()
}

// RenderUnlockPNG uses ImageMagick to render the embedded SVG logo into a
// 801x188 transparent PNG, tinted exactly to the provided foreground color.
// This matches the size and properties expected by Omarchy Plymouth/SDDM.
func RenderUnlockPNG(fg, outPath string) error {
	// Ensure the hex color is prefixed with '#'
	if !strings.HasPrefix(fg, "#") {
		fg = "#" + fg
	}

	cmd := exec.Command("magick", "-background", "none", "svg:-", "-resize", "x188", "-channel", "RGB", "+level-colors", fg+","+fg, outPath)
	cmd.Stdin = bytes.NewReader(logoSVG)
	
	if out, err := cmd.CombinedOutput(); err != nil {
		return fmt.Errorf("magick error: %w, output: %s", err, string(out))
	}
	return nil
}

// UnlockPNGBytes returns the rendered unlock.png as raw PNG bytes.
func UnlockPNGBytes(fg string) ([]byte, error) {
	if !strings.HasPrefix(fg, "#") {
		fg = "#" + fg
	}
	cmd := exec.Command("magick", "-background", "none", "svg:-", "-resize", "x188", "-channel", "RGB", "+level-colors", fg+","+fg, "png:-")
	cmd.Stdin = bytes.NewReader(logoSVG)
	return cmd.Output()
}
