package theme

import (
	"bufio"
	"os"
	"strings"
	"unicode"
)

type Theme struct {
	Fg     string
	Bg     string
	Accent string
	SelBg  string
	Muted  string
}

func DefaultTheme() Theme {
	return Theme{
		Fg:     "#c0caf5",
		Bg:     "#1a1b26",
		Accent: "#7aa2f7",
		SelBg:  "#283457",
		Muted:  "#565f89",
	}
}

func LoadTheme(tomlPath string) Theme {
	t := DefaultTheme()
	t.Fg = ReadColor(tomlPath, "foreground", t.Fg)
	t.Bg = ReadColor(tomlPath, "background", t.Bg)
	t.Accent = ReadColor(tomlPath, "accent", t.Accent)
	t.SelBg = ReadColor(tomlPath, "color0", t.SelBg)
	t.Muted = ReadColor(tomlPath, "color8", t.Muted)
	return t
}

func ReadColor(path, key, fallback string) string {
	f, err := os.Open(path)
	if err != nil {
		return fallback
	}
	defer f.Close()

	sc := bufio.NewScanner(f)
	for sc.Scan() {
		line := sc.Text()
		idx := strings.IndexByte(line, '=')
		if idx < 0 {
			continue
		}
		if strings.TrimSpace(line[:idx]) != key {
			continue
		}
		v := strings.TrimFunc(strings.TrimSpace(line[idx+1:]), func(r rune) bool {
			return r == '"' || unicode.IsSpace(r)
		})
		if v != "" {
			return v
		}
	}
	return fallback
}
