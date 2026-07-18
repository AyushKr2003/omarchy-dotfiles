// Package preview renders live theme previews for the terminal: a portable
// half-block wallpaper thumbnail plus color swatches and a mock UI.
package preview

import (
	"bytes"
	"encoding/base64"
	"fmt"
	"image"
	_ "image/gif"
	_ "image/jpeg"
	"image/png"
	"os"
	"strings"

	_ "golang.org/x/image/bmp"
	"golang.org/x/image/draw"
	_ "golang.org/x/image/webp"
)

// Thumbnail decodes the image at path and renders it as a truecolor half-block
// mosaic sized to fit cols x rows terminal cells. Each cell packs two vertical
// pixels via the upper-half-block glyph, so the effective pixel grid is
// cols x (rows*2). Returns an error string block on failure so the UI stays alive.
func Thumbnail(path string, cols, rows int) string {
	if cols < 1 || rows < 1 {
		return ""
	}
	img, err := decode(path)
	if err != nil {
		return dim(fmt.Sprintf("(preview unavailable: %v)", err))
	}

	pxW := cols
	pxH := rows * 2

	// Preserve the source aspect ratio. Each cell holds two vertical pixels via
	// half-blocks and terminal cells are ~2x taller than wide, so a half-block
	// subpixel is effectively square: scale uniformly to fit the cols x (rows*2)
	// pixel box.
	bounds := img.Bounds()
	srcW, srcH := bounds.Dx(), bounds.Dy()
	if srcW == 0 || srcH == 0 {
		return ""
	}
	scale := min(float64(pxW)/float64(srcW), float64(pxH)/float64(srcH))
	dstW := max(1, int(float64(srcW)*scale))
	dstH := max(1, int(float64(srcH)*scale))

	dst := image.NewRGBA(image.Rect(0, 0, dstW, dstH))
	draw.CatmullRom.Scale(dst, dst.Bounds(), img, bounds, draw.Over, nil)

	var b strings.Builder
	for y := 0; y < dstH; y += 2 {
		for x := 0; x < dstW; x++ {
			tr, tg, tb := rgb(dst, x, y)
			if y+1 < dstH {
				br, bg, bb := rgb(dst, x, y+1)
				// Foreground = top pixel (upper half block), background = bottom.
				fmt.Fprintf(&b, "\x1b[38;2;%d;%d;%dm\x1b[48;2;%d;%d;%dm\u2580", tr, tg, tb, br, bg, bb)
			} else {
				fmt.Fprintf(&b, "\x1b[38;2;%d;%d;%dm\u2580", tr, tg, tb)
			}
		}
		b.WriteString("\x1b[0m\n")
	}
	return strings.TrimRight(b.String(), "\n")
}

// KittyThumbnail encodes the wallpaper as a Kitty terminal inline image sized
// to fit cols x rows cells. The escape sequence embeds a resized PNG so the
// terminal renders the actual wallpaper instead of a half-block approximation.
//
// The output wraps the image in save/restore-cursor sequences
// (ESC[s / ESC[u) so the image is placed at the correct cursor position,
// then emits rows placeholder newlines so Bubble Tea's layout engine
// reserves the correct visual height.
func KittyThumbnail(path string, cols, rows int) string {
	if cols < 1 || rows < 1 {
		return ""
	}
	img, err := decode(path)
	if err != nil {
		return dim(fmt.Sprintf("(preview unavailable: %v)", err))
	}

	bounds := img.Bounds()
	srcW, srcH := bounds.Dx(), bounds.Dy()
	if srcW == 0 || srcH == 0 {
		return ""
	}
	scale := min(float64(cols)/float64(srcW), float64(rows*2)/float64(srcH))
	dstW := max(1, int(float64(srcW)*scale))
	dstH := max(1, int(float64(srcH)*scale))

	dst := image.NewRGBA(image.Rect(0, 0, dstW, dstH))
	draw.CatmullRom.Scale(dst, dst.Bounds(), img, bounds, draw.Over, nil)

	var pngBuf bytes.Buffer
	if err := png.Encode(&pngBuf, dst); err != nil {
		return dim(fmt.Sprintf("(preview encode failed: %v)", err))
	}
	b64 := base64.StdEncoding.EncodeToString(pngBuf.Bytes())

	// Kitty escape, wrapped in save/restore cursor so the image is placed
	// at the current position and placeholder newlines reserve visual height.
	escape := fmt.Sprintf("\x1b_Ga=T,f=100,c=%d,r=%d;%s\x1b\\", cols, rows, b64)
	return fmt.Sprintf("\x1b[s%s\x1b[u%s", escape, strings.Repeat("\n", rows))
}

func decode(path string) (image.Image, error) {
	f, err := os.Open(path)
	if err != nil {
		return nil, err
	}
	defer f.Close()
	img, _, err := image.Decode(f)
	return img, err
}

func rgb(img *image.RGBA, x, y int) (int, int, int) {
	i := img.PixOffset(x, y)
	return int(img.Pix[i]), int(img.Pix[i+1]), int(img.Pix[i+2])
}

func dim(s string) string { return "\x1b[2m" + s + "\x1b[0m" }

func min(a, b float64) float64 {
	if a < b {
		return a
	}
	return b
}

func max(a, b int) int {
	if a > b {
		return a
	}
	return b
}
