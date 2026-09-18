package preview

import (
	"image"
	"image/color"
	"image/png"
	"os"

	"golang.org/x/image/font"
	"golang.org/x/image/font/basicfont"
	"golang.org/x/image/math/fixed"

	"omarchy-colorgen/internal/palette"
)

// RenderPNG writes a swatch-grid preview image for the palette to path. The
// layout mirrors the on-screen swatches so a saved theme carries a real
// preview.png like the first-party Omarchy themes.
func RenderPNG(p palette.Palette, path string) error {
	type sw struct{ name, hex string }
	rows := [][]sw{
		{{"background", p.Background}, {"foreground", p.Foreground}, {"accent", p.Accent}, {"selection", p.Selection}},
		{{"red", p.Red}, {"green", p.Green}, {"yellow", p.Yellow}, {"orange", p.Orange}},
		{{"blue", p.Blue}, {"magenta", p.Magenta}, {"cyan", p.Cyan}, {"brown", p.Brown}},
		{{"br_red", p.BrightRed}, {"br_green", p.BrightGreen}, {"br_blue", p.BrightBlue}, {"br_magenta", p.BrightMagenta}},
	}

	const (
		cols  = 4
		cellW = 220
		cellH = 90
		pad   = 24
		gap   = 12
	)
	rowsN := len(rows)
	w := pad*2 + cols*cellW + (cols-1)*gap
	h := pad*2 + rowsN*cellH + (rowsN-1)*gap

	img := image.NewRGBA(image.Rect(0, 0, w, h))
	fill(img, img.Bounds(), mustColor(p.Background))

	for r, row := range rows {
		for c, s := range row {
			x0 := pad + c*(cellW+gap)
			y0 := pad + r*(cellH+gap)
			rect := image.Rect(x0, y0, x0+cellW, y0+cellH)
			fill(img, rect, mustColor(s.hex))

			label := mustColor(readableOn(s.hex))
			drawText(img, x0+12, y0+28, label, s.name)
			drawText(img, x0+12, y0+52, label, s.hex)
		}
	}

	f, err := os.Create(path)
	if err != nil {
		return err
	}
	defer f.Close()
	return png.Encode(f, img)
}

func fill(img *image.RGBA, r image.Rectangle, c color.RGBA) {
	for y := r.Min.Y; y < r.Max.Y; y++ {
		for x := r.Min.X; x < r.Max.X; x++ {
			img.SetRGBA(x, y, c)
		}
	}
}

func drawText(img *image.RGBA, x, y int, c color.RGBA, s string) {
	d := &font.Drawer{
		Dst:  img,
		Src:  image.NewUniform(c),
		Face: basicfont.Face7x13,
		Dot:  fixed.P(x, y),
	}
	d.DrawString(s)
}

func mustColor(hex string) color.RGBA {
	rgb, err := palette.ParseHex(hex)
	if err != nil {
		return color.RGBA{A: 255}
	}
	return color.RGBA{R: rgb.R, G: rgb.G, B: rgb.B, A: 255}
}
