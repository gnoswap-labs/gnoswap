package main

import (
	"testing"
)

func TestConvertLineMasksAndEscapes(t *testing.T) {
	patterns, err := ParseMaskPatterns("bytes_delta,fee_delta.amount")
	if err != nil {
		t.Fatalf("ParseMaskPatterns: %v", err)
	}

	conv := NewConverter("stdout", true, true, patterns)
	line := `EVENTS: [{"bytes_delta":2031,"fee_delta":{"denom":"ugnot","amount":203100}}]`

	got, ok := conv.ConvertLine(line)
	if !ok {
		t.Fatalf("expected line to be converted")
	}

	want := `stdout 'EVENTS: \[\{\"bytes_delta\":[0-9]+,\"fee_delta\":\{\"denom\":\"ugnot\",\"amount\":[0-9]+\}\}\]'`
	if got != want {
		t.Fatalf("ConvertLine mismatch\nwant: %s\ngot:  %s", want, got)
	}
}

func TestConvertLineKeepsEmptyWhenRequested(t *testing.T) {
	conv := NewConverter("stderr", true, false, nil)

	got, ok := conv.ConvertLine("   ")
	if !ok {
		t.Fatalf("expected empty line to be converted when skipEmpty=false")
	}

	want := `stderr ''`
	if got != want {
		t.Fatalf("ConvertLine mismatch\nwant: %s\ngot:  %s", want, got)
	}
}

func TestParseMaskPatternsErrors(t *testing.T) {
	if _, err := ParseMaskPatterns("foo.bar.baz"); err == nil {
		t.Fatalf("expected error for too many path segments")
	}

	if _, err := ParseMaskPatterns(""); err != nil {
		t.Fatalf("expected empty spec to be allowed: %v", err)
	}
}

func TestMetricMasking(t *testing.T) {
	conv := NewConverter("stdout", true, true, nil)

	got, ok := conv.ConvertLine("GAS USED:   6170090")
	if !ok {
		t.Fatalf("expected conversion")
	}
	want := `stdout 'GAS USED:   6[0-9]{6}'`
	if got != want {
		t.Fatalf("metric mask mismatch\nwant: %s\ngot:  %s", want, got)
	}

	got, ok = conv.ConvertLine("TOTAL TX COST:  105280200ugnot")
	if !ok {
		t.Fatalf("expected conversion")
	}
	want = `stdout 'TOTAL TX COST:  1[0-9]{8}ugnot'`
	if got != want {
		t.Fatalf("metric mask mismatch\nwant: %s\ngot:  %s", want, got)
	}
}

func TestCurrentTimeMasking(t *testing.T) {
	patterns, err := ParseMaskPatterns("currentTime,currentHeight")
	if err != nil {
		t.Fatalf("ParseMaskPatterns: %v", err)
	}

	conv := NewConverter("stdout", true, true, patterns)

	// Test attrs array format
	line := `[{"key":"currentTime","value":"1763004369"},{"key":"currentHeight","value":"17"}]`
	got, ok := conv.ConvertLine(line)
	if !ok {
		t.Fatalf("expected line to be converted")
	}

	want := `stdout '\[\{\"key\":\"currentTime\",\"value\":\"[0-9]+\"\},\{\"key\":\"currentHeight\",\"value\":\"[0-9]+\"\}\]'`
	if got != want {
		t.Fatalf("currentTime mask mismatch\nwant: %s\ngot:  %s", want, got)
	}

	// Test standard JSON format
	line2 := `{"currentTime":1763004369,"currentHeight":17}`
	got2, ok2 := conv.ConvertLine(line2)
	if !ok2 {
		t.Fatalf("expected line to be converted")
	}

	want2 := `stdout '\{\"currentTime\":[0-9]+,\"currentHeight\":[0-9]+\}'`
	if got2 != want2 {
		t.Fatalf("currentTime mask mismatch (standard format)\nwant: %s\ngot:  %s", want2, got2)
	}
}
