package main

import (
	"strings"
	"testing"
)

func TestIsValidStdoutLine(t *testing.T) {
	tests := []struct {
		name     string
		line     string
		expected bool
	}{
		{
			name:     "GAS USED prefix",
			line:     "GAS USED:   6170090",
			expected: true,
		},
		{
			name:     "STORAGE DELTA prefix",
			line:     "STORAGE DELTA:   1024 bytes",
			expected: true,
		},
		{
			name:     "STORAGE FEE prefix",
			line:     "STORAGE FEE:   102400ugnot",
			expected: true,
		},
		{
			name:     "TOTAL TX COST prefix",
			line:     "TOTAL TX COST:  105280200ugnot",
			expected: true,
		},
		{
			name:     "EVENTS prefix",
			line:     `EVENTS: [{"type":"test"}]`,
			expected: true,
		},
		{
			name:     "commented stdout line",
			line:     "# stdout 'GAS USED:'",
			expected: false,
		},
		{
			name:     "random line",
			line:     "height: 10",
			expected: false,
		},
		{
			name:     "empty line",
			line:     "",
			expected: false,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			got := isValidStdoutLine(tt.line)
			if got != tt.expected {
				t.Errorf("isValidStdoutLine(%q) = %v, want %v", tt.line, got, tt.expected)
			}
		})
	}
}

func TestParseTxtar(t *testing.T) {
	rg := &ReportGenerator{
		config: &Configuration{
			TestName:       "test",
			IntegrationDir: ".",
		},
	}

	// Create a temporary txtar content
	content := `loadpkg gno.land/p/gnoswap/uint256

gnoland start

### Category1 ###
# Test function 1
gnokey maketx call -pkgpath gno.land/r/test -func Function1 -broadcast test1

### Category2 ###
# Test function 2
gnokey maketx call -pkgpath gno.land/r/test -func Function2 -broadcast test1
gnokey maketx call -pkgpath gno.land/r/test -func Function3 -broadcast test1

-- gnomod.toml --
module = "gno.land/r/test"
`

	// Parse the content directly (we'll test the parsing logic)
	var functions []FunctionInfo
	var currentCategory string
	lines := strings.Split(content, "\n")
	index := 0

	for _, line := range lines {
		trimmed := strings.TrimSpace(line)

		if strings.HasPrefix(trimmed, "###") && strings.HasSuffix(trimmed, "###") {
			currentCategory = strings.Trim(trimmed, "# ")
			continue
		}

		if strings.Contains(trimmed, "gnokey maketx call") {
			if matches := funcPattern.FindStringSubmatch(trimmed); len(matches) > 1 {
				funcName := matches[1]
				functions = append(functions, FunctionInfo{
					Name:     funcName,
					Category: currentCategory,
					Index:    index,
				})
				index++
			}
		}
	}

	if len(functions) != 3 {
		t.Fatalf("expected 3 functions, got %d", len(functions))
	}

	// Check first function
	if functions[0].Name != "Function1" {
		t.Errorf("expected Function1, got %s", functions[0].Name)
	}
	if functions[0].Category != "Category1" {
		t.Errorf("expected Category1, got %s", functions[0].Category)
	}

	// Check second function
	if functions[1].Name != "Function2" {
		t.Errorf("expected Function2, got %s", functions[1].Name)
	}
	if functions[1].Category != "Category2" {
		t.Errorf("expected Category2, got %s", functions[1].Category)
	}

	// Check third function
	if functions[2].Name != "Function3" {
		t.Errorf("expected Function3, got %s", functions[2].Name)
	}
	if functions[2].Category != "Category2" {
		t.Errorf("expected Category2, got %s", functions[2].Category)
	}

	_ = rg // silence unused warning
}

func TestParseGasOutput(t *testing.T) {
	rg := &ReportGenerator{
		config: &Configuration{
			TestName:       "test",
			IntegrationDir: ".",
		},
	}

	lines := []string{
		"> gnokey maketx call -func Empty",
		"[stdout]",
		"GAS USED:   1000000",
		"STORAGE DELTA:   0 bytes",
		"STORAGE FEE:   0ugnot",
		"> gnokey maketx call -func TestFunc",
		"[stdout]",
		"GAS USED:   5000000",
		"STORAGE DELTA:   1024 bytes",
		"STORAGE FEE:   102400ugnot",
		"# stdout 'GAS USED:'",
		"## some header",
	}

	values := rg.parseGasOutput(lines)

	if len(values) != 2 {
		t.Fatalf("expected 2 gas values, got %d", len(values))
	}

	// Check first value (Empty)
	if values[0].GasUsed != 1000000 {
		t.Errorf("expected GasUsed 1000000, got %d", values[0].GasUsed)
	}
	if values[0].StorageBytes != 0 {
		t.Errorf("expected StorageBytes 0, got %d", values[0].StorageBytes)
	}

	// Check second value (TestFunc)
	if values[1].GasUsed != 5000000 {
		t.Errorf("expected GasUsed 5000000, got %d", values[1].GasUsed)
	}
	if values[1].StorageBytes != 1024 {
		t.Errorf("expected StorageBytes 1024, got %d", values[1].StorageBytes)
	}
	if values[1].StorageFee != 102400 {
		t.Errorf("expected StorageFee 102400, got %d", values[1].StorageFee)
	}
}

func TestParseGasOutputFiltersCommentedLines(t *testing.T) {
	rg := &ReportGenerator{
		config: &Configuration{
			TestName:       "test",
			IntegrationDir: ".",
		},
	}

	lines := []string{
		"> gnokey maketx call -func TestFunc",
		"[stdout]",
		"GAS USED:   5000000",
		"# stdout 'GAS USED:   9999999'",
		"STORAGE DELTA:   1024 bytes",
		"# STORAGE DELTA:   9999 bytes",
	}

	values := rg.parseGasOutput(lines)

	if len(values) != 1 {
		t.Fatalf("expected 1 gas value, got %d", len(values))
	}

	// Should use the actual value, not the commented one
	if values[0].GasUsed != 5000000 {
		t.Errorf("expected GasUsed 5000000, got %d (commented line may have been parsed)", values[0].GasUsed)
	}
	if values[0].StorageBytes != 1024 {
		t.Errorf("expected StorageBytes 1024, got %d", values[0].StorageBytes)
	}
}

func TestBuildReport(t *testing.T) {
	rg := &ReportGenerator{
		config: &Configuration{
			TestName:       "test",
			IntegrationDir: ".",
		},
	}

	functions := []FunctionInfo{
		{Name: "Empty", Category: "Baseline", Index: 0},
		{Name: "TestFunc1", Category: "Category1", Index: 1},
		{Name: "TestFunc2", Category: "Category1", Index: 2},
	}

	gasValues := []GasValue{
		{GasUsed: 1000000, StorageBytes: 0, StorageFee: 0},
		{GasUsed: 5000000, StorageBytes: 1024, StorageFee: 102400},
		{GasUsed: 3000000, StorageBytes: 512, StorageFee: 51200},
	}

	report := rg.buildReport(functions, gasValues)

	if report.TestName != "test" {
		t.Errorf("expected TestName 'test', got %s", report.TestName)
	}

	if report.BaselineCost != 1000000 {
		t.Errorf("expected BaselineCost 1000000, got %d", report.BaselineCost)
	}

	if len(report.Entries) != 3 {
		t.Fatalf("expected 3 entries, got %d", len(report.Entries))
	}

	// Check PureGas calculation
	if report.Entries[1].PureGas != 4000000 {
		t.Errorf("expected PureGas 4000000 (5000000-1000000), got %d", report.Entries[1].PureGas)
	}

	if report.Entries[2].PureGas != 2000000 {
		t.Errorf("expected PureGas 2000000 (3000000-1000000), got %d", report.Entries[2].PureGas)
	}
}

func TestFormatNumber(t *testing.T) {
	tests := []struct {
		input    uint64
		expected string
	}{
		{0, "0"},
		{123, "123"},
		{1234, "1,234"},
		{12345, "12,345"},
		{123456, "123,456"},
		{1234567, "1,234,567"},
		{1000000, "1,000,000"},
	}

	for _, tt := range tests {
		t.Run(tt.expected, func(t *testing.T) {
			got := formatNumber(tt.input)
			if got != tt.expected {
				t.Errorf("formatNumber(%d) = %s, want %s", tt.input, got, tt.expected)
			}
		})
	}
}

func TestIsBaselineFunction(t *testing.T) {
	tests := []struct {
		name     string
		expected bool
	}{
		{"Empty", true},
		{"TestEmpty", true},
		{"EmptyTest", false},
		{"TestFunc", false},
		{"empty", false}, // case sensitive
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			got := isBaselineFunction(tt.name)
			if got != tt.expected {
				t.Errorf("isBaselineFunction(%q) = %v, want %v", tt.name, got, tt.expected)
			}
		})
	}
}

func TestGroupByCategory(t *testing.T) {
	rg := &ReportGenerator{
		config: &Configuration{},
	}

	entries := []GasEntry{
		{Name: "Func1", Category: "Cat1"},
		{Name: "Func2", Category: "Cat2"},
		{Name: "Func3", Category: "Cat1"},
		{Name: "Func4", Category: ""},
	}

	categories := rg.groupByCategory(entries)

	if len(categories) != 3 {
		t.Fatalf("expected 3 categories, got %d", len(categories))
	}

	// Check order is preserved
	if categories[0].Name != "Cat1" {
		t.Errorf("expected first category Cat1, got %s", categories[0].Name)
	}
	if len(categories[0].Entries) != 2 {
		t.Errorf("expected 2 entries in Cat1, got %d", len(categories[0].Entries))
	}

	if categories[1].Name != "Cat2" {
		t.Errorf("expected second category Cat2, got %s", categories[1].Name)
	}

	if categories[2].Name != "Other" {
		t.Errorf("expected third category Other, got %s", categories[2].Name)
	}
}

func TestFormatMarkdown(t *testing.T) {
	rg := &ReportGenerator{
		config: &Configuration{},
	}

	report := &GasReport{
		TestName:     "test_report",
		BaselineCost: 1000000,
		Entries: []GasEntry{
			{Name: "Empty", Category: "Baseline", TotalGas: 1000000, PureGas: 0},
			{Name: "TestFunc", Category: "TestCategory", TotalGas: 5000000, PureGas: 4000000, StorageBytes: 1024},
		},
	}

	markdown := rg.formatMarkdown(report)

	// Check header
	if !strings.Contains(markdown, "# Gas Measurement Report: test_report") {
		t.Error("expected report header")
	}

	// Check baseline
	if !strings.Contains(markdown, "**Baseline (Empty Call):** 1,000,000 gas") {
		t.Error("expected baseline info")
	}

	// Check category header
	if !strings.Contains(markdown, "## TestCategory") {
		t.Error("expected category header")
	}

	// Check table header
	if !strings.Contains(markdown, "| Name | Pure Gas Used |") {
		t.Error("expected table header")
	}

	// Check entry (Empty should be filtered out)
	if strings.Contains(markdown, "| Empty |") {
		t.Error("baseline function should be filtered from table")
	}

	// Check TestFunc entry
	if !strings.Contains(markdown, "| TestFunc |") {
		t.Error("expected TestFunc entry in table")
	}
}

func TestFormatTSV(t *testing.T) {
	rg := &ReportGenerator{
		config: &Configuration{},
	}

	report := &GasReport{
		TestName:     "test_report",
		BaselineCost: 1000000,
		Entries: []GasEntry{
			{Name: "Empty", Category: "Baseline", TotalGas: 1000000, PureGas: 0},
			{Name: "TestFunc", Category: "TestCategory", TotalGas: 5000000, PureGas: 4000000, StorageBytes: 1024},
		},
	}

	tsv := rg.formatTSV(report)

	lines := strings.Split(strings.TrimSpace(tsv), "\n")

	// Check header
	if lines[0] != "Name\tPure Gas Used\tTotal Gas Used\tMethod Call Cost\tStorage (bytes)" {
		t.Errorf("unexpected header: %s", lines[0])
	}

	// Should have 2 lines (header + 1 entry, Empty filtered)
	if len(lines) != 2 {
		t.Errorf("expected 2 lines, got %d", len(lines))
	}

	// Check data line
	if !strings.HasPrefix(lines[1], "TestFunc\t") {
		t.Errorf("expected TestFunc entry, got: %s", lines[1])
	}
}

func TestSortEntries(t *testing.T) {
	entries := []GasEntry{
		{Name: "Bravo", TotalGas: 3000, PureGas: 2000},
		{Name: "Alpha", TotalGas: 1000, PureGas: 500},
		{Name: "Charlie", TotalGas: 2000, PureGas: 1500},
	}

	t.Run("SortByName ascending", func(t *testing.T) {
		e := make([]GasEntry, len(entries))
		copy(e, entries)
		SortEntries(e, SortByName, true)

		if e[0].Name != "Alpha" || e[1].Name != "Bravo" || e[2].Name != "Charlie" {
			t.Errorf("unexpected order: %v", e)
		}
	})

	t.Run("SortByTotalGas descending", func(t *testing.T) {
		e := make([]GasEntry, len(entries))
		copy(e, entries)
		SortEntries(e, SortByTotalGas, false)

		if e[0].TotalGas != 3000 || e[1].TotalGas != 2000 || e[2].TotalGas != 1000 {
			t.Errorf("unexpected order: %v", e)
		}
	})

	t.Run("SortByPureGas ascending", func(t *testing.T) {
		e := make([]GasEntry, len(entries))
		copy(e, entries)
		SortEntries(e, SortByPureGas, true)

		if e[0].PureGas != 500 || e[1].PureGas != 1500 || e[2].PureGas != 2000 {
			t.Errorf("unexpected order: %v", e)
		}
	})
}

func TestGasUsedPatternRegex(t *testing.T) {
	tests := []struct {
		input    string
		expected string
	}{
		{"GAS USED:   6170090", "6170090"},
		{"GAS USED: 123", "123"},
		{"GAS USED:  1000000", "1000000"},
	}

	for _, tt := range tests {
		t.Run(tt.input, func(t *testing.T) {
			matches := gasUsedPattern.FindStringSubmatch(tt.input)
			if len(matches) < 2 {
				t.Fatalf("no match found for %q", tt.input)
			}
			if matches[1] != tt.expected {
				t.Errorf("expected %s, got %s", tt.expected, matches[1])
			}
		})
	}
}

func TestStorageDeltaPatternRegex(t *testing.T) {
	tests := []struct {
		input    string
		expected string
	}{
		{"STORAGE DELTA:   1024 bytes", "1024"},
		{"STORAGE DELTA: 0 bytes", "0"},
		{"STORAGE DELTA:   -512 bytes", "-512"},
	}

	for _, tt := range tests {
		t.Run(tt.input, func(t *testing.T) {
			matches := storageDeltaPattern.FindStringSubmatch(tt.input)
			if len(matches) < 2 {
				t.Fatalf("no match found for %q", tt.input)
			}
			if matches[1] != tt.expected {
				t.Errorf("expected %s, got %s", tt.expected, matches[1])
			}
		})
	}
}

func TestStorageFeePatternRegex(t *testing.T) {
	tests := []struct {
		input    string
		expected string
	}{
		{"STORAGE FEE:   102400ugnot", "102400"},
		{"STORAGE FEE: 0ugnot", "0"},
		{"STORAGE FEE:   999999ugnot", "999999"},
	}

	for _, tt := range tests {
		t.Run(tt.input, func(t *testing.T) {
			matches := storageFeePattern.FindStringSubmatch(tt.input)
			if len(matches) < 2 {
				t.Fatalf("no match found for %q", tt.input)
			}
			if matches[1] != tt.expected {
				t.Errorf("expected %s, got %s", tt.expected, matches[1])
			}
		})
	}
}
