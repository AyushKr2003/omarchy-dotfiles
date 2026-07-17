// Package wallpaper discovers candidate wallpaper images on disk.
package wallpaper

import (
	"os"
	"path/filepath"
	"sort"
	"strings"
)

// Wallpaper is a single discovered image.
type Wallpaper struct {
	Path  string // absolute path
	Name  string // file name
	Group string // parent directory name (e.g. the background collection)
}

var imageExts = map[string]bool{
	".jpg":  true,
	".jpeg": true,
	".png":  true,
	".webp": true,
	".gif":  true,
	".bmp":  true,
}

// IsImage reports whether path has a supported image extension.
func IsImage(path string) bool {
	return imageExts[strings.ToLower(filepath.Ext(path))]
}

// DefaultDirs returns the directories scanned when no path is supplied.
func DefaultDirs() []string {
	home := os.Getenv("HOME")
	return []string{
		filepath.Join(home, ".config", "omarchy", "backgrounds"),
		filepath.Join(home, "Pictures", "Wallpapers"),
		filepath.Join(home, "Pictures", "wallpapers"),
	}
}

// Scan walks the given directories (recursively) and returns sorted, unique
// image files. Missing directories are skipped silently.
func Scan(dirs []string) []Wallpaper {
	seen := make(map[string]bool)
	var out []Wallpaper

	for _, dir := range dirs {
		if dir == "" {
			continue
		}
		_ = filepath.WalkDir(dir, func(path string, d os.DirEntry, err error) error {
			if err != nil {
				return nil
			}
			if d.IsDir() || !IsImage(path) {
				return nil
			}
			abs, aerr := filepath.Abs(path)
			if aerr != nil {
				abs = path
			}
			if seen[abs] {
				return nil
			}
			seen[abs] = true
			out = append(out, Wallpaper{
				Path:  abs,
				Name:  d.Name(),
				Group: filepath.Base(filepath.Dir(abs)),
			})
			return nil
		})
	}

	sort.Slice(out, func(i, j int) bool {
		if out[i].Group != out[j].Group {
			return out[i].Group < out[j].Group
		}
		return out[i].Name < out[j].Name
	})
	return out
}

// FromPath builds a Wallpaper from an explicit file path (used by headless mode
// and the file browser).
func FromPath(path string) (Wallpaper, bool) {
	if !IsImage(path) {
		return Wallpaper{}, false
	}
	if info, err := os.Stat(path); err != nil || info.IsDir() {
		return Wallpaper{}, false
	}
	abs, err := filepath.Abs(path)
	if err != nil {
		abs = path
	}
	return Wallpaper{
		Path:  abs,
		Name:  filepath.Base(abs),
		Group: filepath.Base(filepath.Dir(abs)),
	}, true
}
