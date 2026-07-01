// Package stats computes WPM and accuracy from a completed typing session.
package stats

import "time"

// Result holds the final computed stats for one typing run.
type Result struct {
	WPM         float64 // words per minute, standard 5-chars-per-word convention
	RawWPM      float64 // WPM including incorrect keystrokes, before correction
	Accuracy    float64 // percentage of correct keystrokes, 0-100
	Duration    time.Duration
	TotalChars  int
	CorrectRune int
	ErrorCount  int // number of keystrokes that were wrong at the time typed
}

// Session accumulates the raw counters needed to compute a Result. It is
// driven by the UI as the user types: call Start once, then RecordKeystroke
// for every character typed (correct or not), then Finish to get the Result.
type Session struct {
	start      time.Time
	end        time.Time
	started    bool
	totalChars int
	correct    int
	errors     int // total wrong keystrokes, including ones later corrected
}

// Start marks the beginning of the timed session. Safe to call multiple
// times; only the first call takes effect, so callers can call it
// unconditionally on the first keystroke.
func (s *Session) Start() {
	if s.started {
		return
	}
	s.started = true
	s.start = time.Now()
}

// RecordKeystroke registers one typed character. correct indicates whether
// it matched the expected character at the time it was typed.
func (s *Session) RecordKeystroke(correct bool) {
	s.totalChars++
	if correct {
		s.correct++
	} else {
		s.errors++
	}
}

// Finish stops the timer and computes the final Result. Call this once, when
// the snippet is fully typed (or the user quits early).
func (s *Session) Finish() Result {
	if !s.started {
		s.start = time.Now()
	}
	s.end = time.Now()

	d := s.end.Sub(s.start)
	minutes := d.Minutes()
	if minutes <= 0 {
		minutes = 1.0 / 60.0 // avoid divide-by-zero on near-instant finishes
	}

	// Standard typing convention: one "word" = 5 characters.
	rawWords := float64(s.totalChars) / 5.0
	correctWords := float64(s.correct) / 5.0

	accuracy := 100.0
	if s.totalChars > 0 {
		accuracy = float64(s.correct) / float64(s.totalChars) * 100.0
	}

	return Result{
		WPM:         correctWords / minutes,
		RawWPM:      rawWords / minutes,
		Accuracy:    accuracy,
		Duration:    d,
		TotalChars:  s.totalChars,
		CorrectRune: s.correct,
		ErrorCount:  s.errors,
	}
}

// Elapsed returns time since Start was called, or zero if not yet started.
// Useful for a live timer display while typing.
func (s *Session) Elapsed() time.Duration {
	if !s.started {
		return 0
	}
	return time.Since(s.start)
}
