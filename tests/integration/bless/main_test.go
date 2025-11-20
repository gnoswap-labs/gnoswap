package main

import "testing"

func TestShouldKeepStdoutLine(t *testing.T) {
	// Create a processor with default prefixes for testing
	config := &Configuration{
		TestName:       "test",
		IntegrationDir: ".",
		MaskSpec:       DefaultMaskSpec,
		DryRun:         false,
	}

	processor, err := NewScriptProcessor(config)
	if err != nil {
		t.Fatalf("failed to create processor: %v", err)
	}

	// Create a parser with the processor
	parser := &outputParser{
		processor: processor,
	}

	t.Run("QueryKeepsAll", func(t *testing.T) {
		if !parser.shouldKeepStdoutLine("true", "gnokey query vm/qeval --data ...") {
			t.Fatalf("expected vm/qeval result to be included")
		}
	})

	t.Run("NonQueryFilters", func(t *testing.T) {
		if parser.shouldKeepStdoutLine("height: 10", "gnokey maketx send ...") {
			t.Fatalf("unexpected line kept")
		}

		if !parser.shouldKeepStdoutLine("GAS USED: 123", "gnokey maketx send ...") {
			t.Fatalf("expected GAS USED to be kept")
		}

		if !parser.shouldKeepStdoutLine("OK!", "gnokey maketx send ...") {
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
