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
	return renderASCII(img, cols, rows)
}

// ThumbnailBytes decodes image bytes and renders a half-block thumbnail.
func ThumbnailBytes(data []byte, cols, rows int) string {
	if cols < 1 || rows < 1 {
		return ""
	}
	img, _, err := image.Decode(bytes.NewReader(data))
	if err != nil {
		return dim(fmt.Sprintf("(preview unavailable: %v)", err))
	}
	return renderASCII(img, cols, rows)
}

func renderASCII(img image.Image, cols, rows int) string {
	pxW := cols
	pxH := rows * 2

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
	return KittyThumbnailWithID(path, cols, rows, 1)
}

func KittyThumbnailWithID(path string, cols, rows, imgID int) string {
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
	scale := 1.0
	maxDim := float64(max(srcW, srcH))
	if maxDim > 800.0 {
		scale = 800.0 / maxDim
	}
	dstW := max(1, int(float64(srcW)*scale))
	dstH := max(1, int(float64(srcH)*scale))

	dst := image.NewRGBA(image.Rect(0, 0, dstW, dstH))
	draw.CatmullRom.Scale(dst, dst.Bounds(), img, bounds, draw.Over, nil)

	var pngBuf bytes.Buffer
	if err := png.Encode(&pngBuf, dst); err != nil {
		return dim(fmt.Sprintf("(preview encode failed: %v)", err))
	}
	b64 := base64.StdEncoding.EncodeToString(pngBuf.Bytes())

	imgRatio := float64(srcW) / float64(srcH)
	actualCols := cols
	actualRows := int(float64(cols) / (imgRatio * 2.0))
	if actualRows > rows {
		actualRows = rows
		actualCols = int(float64(rows) * imgRatio * 2.0)
	}
	if actualCols < 1 { actualCols = 1 }
	if actualRows < 1 { actualRows = 1 }

	escape := kittyEscapeWithID(b64, actualCols, actualRows, imgID)
	var lines []string
	lines = append(lines, fmt.Sprintf("\x1b[s%s\x1b[u%s", escape, strings.Repeat(" ", actualCols)))
	for i := 1; i < actualRows; i++ {
		lines = append(lines, strings.Repeat(" ", actualCols))
	}
	return strings.Join(lines, "\n")
}

func kittyEscape(b64 string, cols, rows int) string {
	return kittyEscapeWithID(b64, cols, rows, 0)
}

func kittyEscapeWithID(b64 string, cols, rows, imgID int) string {
	chunkSize := 4096
	var b strings.Builder
	
	// Delete any previous image at cursor position and delete by image ID if specified
	if imgID > 0 {
		b.WriteString(fmt.Sprintf("\x1b_Ga=d,d=I,i=%d\x1b\\", imgID))
	}
	b.WriteString("\x1b_Ga=d,d=C\x1b\\")

	idParam := ""
	if imgID > 0 {
		idParam = fmt.Sprintf(",i=%d", imgID)
	}

	if len(b64) <= chunkSize {
		b.WriteString(fmt.Sprintf("\x1b_Ga=T,f=100,q=2%s,c=%d,r=%d;%s\x1b\\", idParam, cols, rows, b64))
		return b.String()
	}
	
	b.WriteString(fmt.Sprintf("\x1b_Ga=T,f=100,q=2%s,c=%d,r=%d,m=1;%s\x1b\\", idParam, cols, rows, b64[:chunkSize]))
	b64 = b64[chunkSize:]
	
	for len(b64) > chunkSize {
		b.WriteString(fmt.Sprintf("\x1b_Gm=1;%s\x1b\\", b64[:chunkSize]))
		b64 = b64[chunkSize:]
	}
	
	if len(b64) > 0 {
		b.WriteString(fmt.Sprintf("\x1b_Gm=0;%s\x1b\\", b64))
	} else {
		b.WriteString("\x1b_Gm=0;\x1b\\")
	}
	
	return b.String()
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

// KittyThumbnailBytes encodes image bytes as a Kitty terminal inline image.
func KittyThumbnailBytes(data []byte, cols, rows int) string {
	return KittyThumbnailBytesWithID(data, cols, rows, 0)
}

func KittyThumbnailBytesWithID(data []byte, cols, rows, imgID int) string {
	if cols < 1 || rows < 1 {
		return ""
	}
	
	actualCols, actualRows := cols, rows
	config, _, err := image.DecodeConfig(bytes.NewReader(data))
	if err == nil && config.Width > 0 && config.Height > 0 {
		imgRatio := float64(config.Width) / float64(config.Height)
		actualRows = int(float64(cols) / (imgRatio * 2.0))
		if actualRows > rows {
			actualRows = rows
			actualCols = int(float64(rows) * imgRatio * 2.0)
		}
		if actualCols < 1 { actualCols = 1 }
		if actualRows < 1 { actualRows = 1 }
	}
	
	b64 := base64.StdEncoding.EncodeToString(data)
	escape := kittyEscapeWithID(b64, actualCols, actualRows, imgID)
	var lines []string
	lines = append(lines, fmt.Sprintf("\x1b[s%s\x1b[u%s", escape, strings.Repeat(" ", actualCols)))
	for i := 1; i < actualRows; i++ {
		lines = append(lines, strings.Repeat(" ", actualCols))
	}
	return strings.Join(lines, "\n")
}

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
