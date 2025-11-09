package main

import "testing"

func TestShouldKeepStdoutLine(t *testing.T) {
	t.Run("QueryKeepsAll", func(t *testing.T) {
		if !shouldKeepStdoutLine("true", "gnokey query vm/qeval --data ...") {
			t.Fatalf("expected vm/qeval result to be included")
		}
	})

	t.Run("NonQueryFilters", func(t *testing.T) {
		if shouldKeepStdoutLine("height: 10", "gnokey maketx send ...") {
			t.Fatalf("unexpected line kept")
		}

		if !shouldKeepStdoutLine("GAS USED: 123", "gnokey maketx send ...") {
			t.Fatalf("expected GAS USED to be kept")
		}

		if !shouldKeepStdoutLine("OK!", "gnokey maketx send ...") {
			t.Fatalf("expected OK! to be kept")
		}
	})
}

func TestShouldKeepStderrLine(t *testing.T) {
	if shouldKeepStderrLine("## Check created pool (0.019s)") {
		t.Fatalf("expected ## line to be filtered out")
	}

	if !shouldKeepStderrLine("stderr message") {
		t.Fatalf("expected generic stderr to be kept")
	}
}
