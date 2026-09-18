// Package palette turns an iris theme into a full Omarchy colors.toml palette.
//
// The color math here deliberately mirrors bin/omarchy-theme-color from the
// Omarchy source tree: mixing is a per-channel linear interpolation on 0-255
// integer sRGB values with round-half-up. Keeping the math identical means the
// palette previewed in the TUI matches the theme Omarchy renders on apply.
package palette

import (
	"fmt"
	"math"
	"strings"
)

// RGB is an 8-bit sRGB color.
type RGB struct{ R, G, B uint8 }

// ParseHex parses "#rrggbb" or "rrggbb" (case-insensitive). It returns an error
// for any other shape so callers never silently mix garbage.
func ParseHex(s string) (RGB, error) {
	h := strings.TrimSpace(s)
	h = strings.TrimPrefix(h, "#")
	if len(h) != 6 {
		return RGB{}, fmt.Errorf("invalid hex color %q", s)
	}
	var v uint64
	for i := 0; i < 6; i++ {
		c := h[i]
		var d uint64
		switch {
		case c >= '0' && c <= '9':
			d = uint64(c - '0')
		case c >= 'a' && c <= 'f':
			d = uint64(c-'a') + 10
		case c >= 'A' && c <= 'F':
			d = uint64(c-'A') + 10
		default:
			return RGB{}, fmt.Errorf("invalid hex color %q", s)
		}
		v = v<<4 | d
	}
	return RGB{R: uint8(v >> 16), G: uint8(v >> 8), B: uint8(v)}, nil
}

// MustHex is ParseHex for compile-time-known constants used in mixing.
func MustHex(s string) RGB {
	c, err := ParseHex(s)
	if err != nil {
		panic(err)
	}
	return c
}

// Hex renders the color as a lowercase "#rrggbb" string.
func (c RGB) Hex() string {
	return fmt.Sprintf("#%02x%02x%02x", c.R, c.G, c.B)
}

var (
	black = RGB{0, 0, 0}
	white = RGB{255, 255, 255}
)

// Mix blends start toward end by amount (0..1), matching the awk mix_color in
// bin/omarchy-theme-color: linear per-channel interpolation with round-half-up.
func Mix(start, end RGB, amount float64) RGB {
	amount = math.Max(0, math.Min(1, amount))
	return RGB{
		R: lerp(start.R, end.R, amount),
		G: lerp(start.G, end.G, amount),
		B: lerp(start.B, end.B, amount),
	}
}

func lerp(a, b uint8, t float64) uint8 {
	v := float64(a)*(1-t) + float64(b)*t
	return uint8(math.Floor(v + 0.5))
}

// Darken mixes a color toward black by amount (0..1).
func Darken(c RGB, amount float64) RGB { return Mix(c, black, amount) }

// Lighten mixes a color toward white by amount (0..1).
func Lighten(c RGB, amount float64) RGB { return Mix(c, white, amount) }

// Luminance returns the simple channel-sum Omarchy uses for mode auto-detection
// (R+G+B, range 0..765).
func (c RGB) Luminance() int { return int(c.R) + int(c.G) + int(c.B) }

// Hue returns the HSV hue of the color in degrees (0..360). Grayscale colors
// return 0.
func (c RGB) Hue() float64 {
	r := float64(c.R) / 255
	g := float64(c.G) / 255
	b := float64(c.B) / 255

	maxc := math.Max(r, math.Max(g, b))
	minc := math.Min(r, math.Min(g, b))
	delta := maxc - minc
	if delta == 0 {
		return 0
	}

	var h float64
	switch maxc {
	case r:
		h = math.Mod((g-b)/delta, 6)
	case g:
		h = (b-r)/delta + 2
	default:
		h = (r-g)/delta + 4
	}
	h *= 60
	if h < 0 {
		h += 360
	}
	return h
}
