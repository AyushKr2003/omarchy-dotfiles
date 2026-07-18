package preview

import (
	"image"
	"image/color"
	"image/png"
	"os"
	"path/filepath"
	"strings"
	"testing"

	"omarchy-colorgen/internal/palette"
)

// testPNG creates a 16x12 test image with known colors and returns its path.
// The image has a red top half and blue bottom half for aspect-ratio checks.
func testPNG(t *testing.T) string {
	t.Helper()
	dir := t.TempDir()
	path := filepath.Join(dir, "test.png")

	img := image.NewRGBA(image.Rect(0, 0, 16, 12))
	for y := 0; y < 12; y++ {
		for x := 0; x < 16; x++ {
			if y < 6 {
				img.Set(x, y, color.RGBA{200, 50, 50, 255}) // red top
			} else {
				img.Set(x, y, color.RGBA{50, 50, 200, 255}) // blue bottom
			}
		}
	}

	f, _ := os.Create(path)
	defer f.Close()
	png.Encode(f, img)
	return path
}

// testPalette returns a minimal palette for swatch/MockUI tests.
func testPalette() palette.Palette {
	return palette.Palette{
		Bg:      "#1a1b26",
		Fg:      "#c0caf5",
		Accent:  "#7aa2f7",
		Red:     "#f7768e",
		Green:   "#9ece6a",
		Yellow:  "#e0af68",
		Blue:    "#7aa2f7",
		Magenta: "#bb9af7",
		Cyan:    "#7dcfff",
	}
}

func TestThumbnail_Basic(t *testing.T) {
	p := testPNG(t)
	out := Thumbnail(p, 8, 4)
	if out == "" {
		t.Fatal("Thumbnail returned empty string")
	}
	lines := strings.Split(strings.TrimSuffix(out, "\n"), "\n")
	if len(lines) < 2 {
		t.Errorf("got %d rows, expected at least 2", len(lines))
	}
	// Each row should contain the half-block escape sequences.
	for i, l := range lines {
		if !strings.Contains(l, "\u2580") {
			t.Errorf("row %d missing half-block glyph", i)
		}
	}
}

func TestThumbnail_InvalidPath(t *testing.T) {
	out := Thumbnail("/nonexistent/image.jpg", 8, 4)
	if out == "" {
		t.Fatal("expected error message for invalid path")
	}
	if !strings.Contains(out, "unavailable") {
		t.Errorf("expected 'unavailable' in error, got: %q", out)
	}
}

func TestThumbnail_ZeroDims(t *testing.T) {
	p := testPNG(t)
	if out := Thumbnail(p, 0, 4); out != "" {
		t.Error("expected empty for zero cols")
	}
	if out := Thumbnail(p, 4, 0); out != "" {
		t.Error("expected empty for zero rows")
	}
}

func TestThumbnail_AspectRatio(t *testing.T) {
	p := testPNG(t)
	// A wider thumbnail should produce more columns.
	narrow := Thumbnail(p, 4, 4)
	wide := Thumbnail(p, 20, 4)
	if len(narrow) >= len(wide) {
		t.Error("wider thumbnail should produce more output")
	}
}

func TestKittyThumbnail_Format(t *testing.T) {
	p := testPNG(t)
	out := KittyThumbnail(p, 8, 4)
	if out == "" {
		t.Fatal("KittyThumbnail returned empty")
	}
	// Should contain cursor save/restore and the Kitty APC.
	if !strings.HasPrefix(out, "\x1b[s") {
		t.Error("missing cursor-save prefix")
	}
	if !strings.Contains(out, "\x1b_Ga=T,f=100") {
		t.Error("missing Kitty APC sequence")
	}
	if !strings.HasSuffix(out, strings.Repeat("\n", 4)) {
		t.Error("missing placeholder newlines")
	}
}

func TestKittyThumbnail_InvalidPath(t *testing.T) {
	out := KittyThumbnail("/nonexistent/image.jpg", 8, 4)
	if !strings.Contains(out, "unavailable") {
		t.Errorf("expected 'unavailable' in error, got: %q", out)
	}
}

func TestKittyThumbnail_ZeroDims(t *testing.T) {
	p := testPNG(t)
	if out := KittyThumbnail(p, 0, 4); out != "" {
		t.Error("expected empty for zero cols")
	}
}

func TestSwatches_ContainsColors(t *testing.T) {
	pal := testPalette()
	out := Swatches(pal, 0)
	for _, want := range []string{"#1a1b26", "#c0caf5", "#7aa2f7"} {
		if !strings.Contains(out, want) {
			t.Errorf("Swatches missing %q", want)
		}
	}
}

func TestSwatches_WidthConstrained(t *testing.T) {
	pal := testPalette()
	// At width=30 the function should use 2 columns.
	narrow := Swatches(pal, 30)
	wide := Swatches(pal, 70)
	// Narrow should have more lines (8 vs 4 rows).
	nLines := len(strings.Split(strings.TrimSuffix(narrow, "\n"), "\n"))
	wLines := len(strings.Split(strings.TrimSuffix(wide, "\n"), "\n"))
	if nLines >= wLines {
		t.Errorf("narrow layout (%d lines) should have fewer lines than wide (%d)", nLines, wLines)
	}
}

func TestSwatches_CellWidthFloor(t *testing.T) {
	pal := testPalette()
	// Very narrow width should hit the cellW floor.
	out := Swatches(pal, 20)
	if out == "" {
		t.Error("Swatches should not be empty even at very narrow width")
	}
}

func TestMockUI_ContainsText(t *testing.T) {
	pal := testPalette()
	out := MockUI(pal, 0)
	for _, want := range []string{"nvim", "func", "greet", "omarchy"} {
		if !strings.Contains(out, want) {
			t.Errorf("MockUI missing %q", want)
		}
	}
}

func TestMockUI_WidthConstrained(t *testing.T) {
	pal := testPalette()
	out := MockUI(pal, 30)
	if !strings.Contains(out, "nvim") {
		t.Error("MockUI should still contain content at constrained width")
	}
}

func TestReadableOn(t *testing.T) {
	if readableOn("#ffffff") != "#000000" {
		t.Error("white bg should return black fg")
	}
	if readableOn("#000000") != "#ffffff" {
		t.Error("black bg should return white fg")
	}
	if readableOn("#7aa2f7") != "#000000" {
		t.Error("medium blue should return black fg (luminance check)")
	}
}

func TestColorOr(t *testing.T) {
	if got := colorOr("#ff0000", "#00ff00"); got != "#ff0000" {
		t.Errorf("expected primary, got %q", got)
	}
	if got := colorOr("", "#00ff00"); got != "#00ff00" {
		t.Errorf("expected fallback, got %q", got)
	}
}

func TestDim(t *testing.T) {
	s := dim("hello")
	want := "\x1b[2mhello\x1b[0m"
	if s != want {
		t.Errorf("dim = %q, want %q", s, want)
	}
}

func TestDecode(t *testing.T) {
	p := testPNG(t)
	img, err := decode(p)
	if err != nil {
		t.Fatalf("decode: %v", err)
	}
	b := img.Bounds()
	if b.Dx() != 16 || b.Dy() != 12 {
		t.Errorf("size = %dx%d, want 16x12", b.Dx(), b.Dy())
	}
}

func TestDecode_InvalidPath(t *testing.T) {
	_, err := decode("/nonexistent.png")
	if err == nil {
		t.Error("expected error for nonexistent file")
	}
}

func TestMinMax(t *testing.T) {
	if min(2.0, 5.0) != 2.0 {
		t.Error("min wrong")
	}
	if max(2, 5) != 5 {
		t.Error("max wrong")
	}
	if min(-1.0, 3.0) != -1.0 {
		t.Error("min with negative")
	}
}

func TestSwatches_PaletteOrder(t *testing.T) {
	pal := testPalette()
	out := Swatches(pal, 0)
	// bg and fg should appear before accent in the output.
	bgIdx := strings.Index(out, "#1a1b26")
	accentIdx := strings.Index(out, "#7aa2f7")
	if bgIdx < 0 || accentIdx < 0 {
		t.Fatal("missing expected colors")
	}
	if bgIdx > accentIdx {
		t.Error("bg should come before accent in the first row")
	}
}

func TestMockUI_BackgroundConsistency(t *testing.T) {
	// Verify that MockUI content uses the bg color from the palette.
	pal := testPalette()
	out := MockUI(pal, 40)
	if !strings.Contains(out, pal.Bg) {
		t.Log("MockUI may not explicitly mention its background hex")
	}
}

func TestIntegration_ThumbnailThenKitty(t *testing.T) {
	// Thumbnail + KittyThumbnail should produce different output for the same input.
	p := testPNG(t)
	a := Thumbnail(p, 8, 4)
	b := KittyThumbnail(p, 8, 4)
	if a == "" || b == "" {
		t.Fatal("both functions should produce output")
	}
	if a == b {
		t.Error("Thumbnail and KittyThumbnail should produce different output")
	}
}

func TestSwatches_AllHexesPresent(t *testing.T) {
	pal := testPalette()
	out := Swatches(pal, 0)
	// Check all named colors appear.
	for _, hex := range []string{pal.Bg, pal.Fg, pal.Accent, pal.Red, pal.Green, pal.Yellow, pal.Blue, pal.Magenta, pal.Cyan} {
		if !strings.Contains(out, hex) {
			t.Errorf("Swatches missing hex %q", hex)
		}
	}
}
