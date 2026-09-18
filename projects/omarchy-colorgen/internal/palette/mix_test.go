package palette

import "testing"

func TestParseHex(t *testing.T) {
	c, err := ParseHex("#1e1e2e")
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}
	if c.R != 0x1e || c.G != 0x1e || c.B != 0x2e {
		t.Fatalf("got %+v", c)
	}
	if _, err := ParseHex("#zzzzzz"); err == nil {
		t.Fatal("expected error for invalid hex")
	}
	if _, err := ParseHex("#123"); err == nil {
		t.Fatal("expected error for short hex")
	}
}

func TestHexRoundTrip(t *testing.T) {
	in := "#a6e3a1"
	c := MustHex(in)
	if c.Hex() != in {
		t.Fatalf("round trip: got %s want %s", c.Hex(), in)
	}
}

// TestMixMatchesOmarchy pins the mix math to bin/omarchy-theme-color's awk
// results so the generated palette matches what Omarchy renders.
func TestMixMatchesOmarchy(t *testing.T) {
	cases := []struct {
		start, end string
		amount     float64
		want       string
	}{
		// dark_bg = mix(bg, #000000, 25%)
		{"#1e1e2e", "#000000", 0.25, "#171723"},
		// darker_bg = mix(bg, #000000, 50%)
		{"#1e1e2e", "#000000", 0.50, "#0f0f17"},
		// bright_red = mix(red, #ffffff, 20%)
		{"#f38ba8", "#ffffff", 0.20, "#f5a2b9"},
	}
	for _, c := range cases {
		got := Mix(MustHex(c.start), MustHex(c.end), c.amount).Hex()
		if got != c.want {
			t.Errorf("mix(%s,%s,%.2f) = %s want %s", c.start, c.end, c.amount, got, c.want)
		}
	}
}

func TestMixClamps(t *testing.T) {
	if got := Mix(MustHex("#ffffff"), MustHex("#000000"), -1).Hex(); got != "#ffffff" {
		t.Errorf("negative amount should clamp to start, got %s", got)
	}
	if got := Mix(MustHex("#ffffff"), MustHex("#000000"), 2).Hex(); got != "#000000" {
		t.Errorf("amount>1 should clamp to end, got %s", got)
	}
}
