// Package iris wraps the `iris` semantic color scheme generator CLI.
package iris

import (
	"context"
	"encoding/json"
	"errors"
	"fmt"
	"os/exec"
	"strings"
	"time"
)

// Mode selects iris's --dark flag value.
type Mode int

const (
	Auto  Mode = -1 // -1 = auto-detect from wallpaper
	Light Mode = 0  //  0 = force light
	Dark  Mode = 1  //  1 = force dark
)

func (m Mode) flag() string {
	switch m {
	case Light:
		return "0"
	case Dark:
		return "1"
	default:
		return "-1"
	}
}

// FlagString returns the --dark flag value for this mode ("-1", "0", "1").
func (m Mode) FlagString() string { return m.flag() }

// Label returns a human-readable mode name.
func (m Mode) Label() string {
	switch m {
	case Light:
		return "LIGHT"
	case Dark:
		return "DARK"
	default:
		return "AUTO"
	}
}

// Theme is the raw JSON payload emitted by `iris --json-only`.
type Theme struct {
	Bg      string  `json:"bg"`
	Surface string  `json:"surface"`
	Fg      string  `json:"fg"`
	Dim     string  `json:"dim"`
	Accent  string  `json:"accent"`
	Red     string  `json:"red"`
	Green   string  `json:"green"`
	Yellow  string  `json:"yellow"`
	Dark    bool    `json:"dark"`
	ToneL   float64 `json:"tone_l"`

	SyntaxKeyword  string `json:"syntax_keyword"`
	SyntaxString   string `json:"syntax_string"`
	SyntaxFunc     string `json:"syntax_func"`
	SyntaxType     string `json:"syntax_type"`
	SyntaxConst    string `json:"syntax_const"`
	SyntaxParam    string `json:"syntax_param"`
	SyntaxOperator string `json:"syntax_operator"`
	SyntaxComment  string `json:"syntax_comment"`
}

// ErrNotInstalled is returned when the iris binary cannot be found on PATH.
var ErrNotInstalled = errors.New("iris is not installed (see https://github.com/binarytsar/iris)")

// Available reports whether the iris binary is on PATH.
func Available() bool {
	_, err := exec.LookPath("iris")
	return err == nil
}

// Generate runs iris against wallpaper in the given mode and parses its JSON.
// A context deadline guards against a hung subprocess.
func Generate(wallpaper string, mode Mode) (Theme, error) {
	if !Available() {
		return Theme{}, ErrNotInstalled
	}

	ctx, cancel := context.WithTimeout(context.Background(), 30*time.Second)
	defer cancel()

	cmd := exec.CommandContext(ctx, "iris", "--json-only", "--dark", mode.flag(), wallpaper)
	out, err := cmd.Output()
	if err != nil {
		if ctx.Err() == context.DeadlineExceeded {
			return Theme{}, fmt.Errorf("iris timed out generating colors for %s", wallpaper)
		}
		var ee *exec.ExitError
		if errors.As(err, &ee) && len(ee.Stderr) > 0 {
			return Theme{}, fmt.Errorf("iris failed: %s", strings.TrimSpace(string(ee.Stderr)))
		}
		return Theme{}, fmt.Errorf("iris failed: %w", err)
	}

	var t Theme
	if err := json.Unmarshal(out, &t); err != nil {
		return Theme{}, fmt.Errorf("parsing iris output: %w", err)
	}
	if t.Bg == "" || t.Fg == "" || t.Accent == "" {
		return Theme{}, fmt.Errorf("iris returned an incomplete palette for %s", wallpaper)
	}
	return t, nil
}
