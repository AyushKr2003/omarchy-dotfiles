package wallpaper

import (
	"os"
	"path/filepath"
	"testing"
)

func TestIsImage(t *testing.T) {
	cases := map[string]bool{
		"photo.jpg":  true,
		"photo.jpeg": true,
		"photo.png":  true,
		"photo.webp": true,
		"photo.gif":  true,
		"photo.bmp":  true,
		"photo.JPG":  true,
		"photo.PNG":  true,
		"photo.txt":  false,
		"photo":      false,
		".jpg":       true,
	}
	for in, want := range cases {
		if got := IsImage(in); got != want {
			t.Errorf("IsImage(%q) = %v, want %v", in, got, want)
		}
	}
}

func TestScan_FindsImages(t *testing.T) {
	dir := t.TempDir()
	os.WriteFile(filepath.Join(dir, "a.jpg"), []byte(""), 0o644)
	os.WriteFile(filepath.Join(dir, "b.png"), []byte(""), 0o644)
	os.MkdirAll(filepath.Join(dir, "sub"), 0o755)
	os.WriteFile(filepath.Join(dir, "sub", "c.webp"), []byte(""), 0o644)
	os.WriteFile(filepath.Join(dir, "notes.txt"), []byte(""), 0o644)

	wps := Scan([]string{dir})
	if len(wps) != 3 {
		t.Fatalf("got %d wallpapers, want 3", len(wps))
	}
	// Sorted: a.jpg, b.png, sub/c.webp (grouped by dir, then name).
	if wps[0].Name != "a.jpg" || wps[1].Name != "b.png" || wps[2].Name != "c.webp" {
		t.Errorf("unexpected order: %+v", wps)
	}
}

func TestScan_EmptyDir(t *testing.T) {
	wps := Scan([]string{t.TempDir()})
	if len(wps) != 0 {
		t.Errorf("expected empty, got %d", len(wps))
	}
}

func TestScan_MissingDir(t *testing.T) {
	wps := Scan([]string{"/nonexistent/path"})
	if len(wps) != 0 {
		t.Errorf("expected empty, got %d", len(wps))
	}
}

func TestScan_Deduplicates(t *testing.T) {
	dir := t.TempDir()
	os.WriteFile(filepath.Join(dir, "a.jpg"), []byte(""), 0o644)
	wps := Scan([]string{dir, dir})
	if len(wps) != 1 {
		t.Errorf("got %d, want 1 (dedup)", len(wps))
	}
}

func TestScan_EmptyInput(t *testing.T) {
	wps := Scan(nil)
	if len(wps) != 0 {
		t.Errorf("expected empty, got %d", len(wps))
	}
	wps = Scan([]string{""})
	if len(wps) != 0 {
		t.Errorf("expected empty for empty string, got %d", len(wps))
	}
}

func TestFromPath_Valid(t *testing.T) {
	dir := t.TempDir()
	p := filepath.Join(dir, "test.jpg")
	os.WriteFile(p, []byte(""), 0o644)

	wp, ok := FromPath(p)
	if !ok {
		t.Fatal("FromPath returned false for valid file")
	}
	if wp.Name != "test.jpg" {
		t.Errorf("Name = %q", wp.Name)
	}
	if wp.Path != p {
		t.Errorf("Path = %q", p)
	}
}

func TestFromPath_Invalid(t *testing.T) {
	_, ok := FromPath("/nonexistent/file.jpg")
	if ok {
		t.Error("FromPath should return false for missing file")
	}
	_, ok = FromPath("readme.txt")
	if ok {
		t.Error("FromPath should return false for non-image")
	}
}

func TestFromPath_Dir(t *testing.T) {
	dir := t.TempDir()
	_, ok := FromPath(dir)
	if ok {
		t.Error("FromPath should return false for a directory")
	}
}

func TestDefaultDirs(t *testing.T) {
	t.Setenv("HOME", "/home/test")
	dirs := DefaultDirs()
	if len(dirs) == 0 {
		t.Fatal("DefaultDirs returned empty")
	}
	for _, d := range dirs {
		if d == "" {
			t.Error("DefaultDirs contains empty string")
		}
	}
}

func TestScan_GroupByParentDir(t *testing.T) {
	dir := t.TempDir()
	subA := filepath.Join(dir, "collection-a")
	subB := filepath.Join(dir, "collection-b")
	os.MkdirAll(subA, 0o755)
	os.MkdirAll(subB, 0o755)
	os.WriteFile(filepath.Join(subA, "img1.jpg"), []byte(""), 0o644)
	os.WriteFile(filepath.Join(subB, "img2.jpg"), []byte(""), 0o644)

	wps := Scan([]string{dir})
	if len(wps) != 2 {
		t.Fatalf("got %d, want 2", len(wps))
	}
	if wps[0].Group != "collection-a" || wps[1].Group != "collection-b" {
		t.Errorf("group mismatch: %+v", wps)
	}
}
