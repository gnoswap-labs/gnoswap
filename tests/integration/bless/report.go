package main

import (
	"bufio"
	"bytes"
	"fmt"
	"os"
	"os/exec"
	"path/filepath"
	"regexp"
	"sort"
	"strconv"
	"strings"
)

// GasReport represents a gas measurement report
type GasReport struct {
	TestName     string
	BaselineCost uint64 // Empty function call cost
	Entries      []GasEntry
}

// GasEntry represents a single function's gas measurement
type GasEntry struct {
	Category     string
	Name         string
	TotalGas     uint64
	PureGas      uint64 // TotalGas - BaselineCost
	StorageBytes int64
	StorageFee   uint64
}

// ReportGenerator generates gas measurement reports
type ReportGenerator struct {
	config      *Configuration
	baselineCost uint64
}

var (
	// Regex patterns for parsing test output
	gasUsedPattern     = regexp.MustCompile(`GAS USED:\s+(\d+)`)
	storageDeltaPattern = regexp.MustCompile(`STORAGE DELTA:\s+(-?\d+)\s+bytes`)
	storageFeePattern   = regexp.MustCompile(`STORAGE FEE:\s+(\d+)ugnot`)
)

// NewReportGenerator creates a new report generator
func NewReportGenerator(config *Configuration) *ReportGenerator {
	return &ReportGenerator{
		config: config,
	}
}

// Generate runs the test and generates a markdown report
func (rg *ReportGenerator) Generate() (string, error) {
	report, err := rg.buildGasReport()
	if err != nil {
		return "", err
	}
	return rg.formatMarkdown(report), nil
}

// GenerateTSV runs the test and generates a TSV report
func (rg *ReportGenerator) GenerateTSV() (string, error) {
	report, err := rg.buildGasReport()
	if err != nil {
		return "", err
	}
	return rg.formatTSV(report), nil
}

// buildGasReport runs the test and builds the gas report
func (rg *ReportGenerator) buildGasReport() (*GasReport, error) {
	scriptPath := rg.getScriptPath()

	// Parse txtar to get function names and categories
	functions, err := rg.parseTxtar(scriptPath)
	if err != nil {
		return nil, fmt.Errorf("failed to parse txtar: %w", err)
	}

	// Run test and capture output
	output, err := rg.runTest()
	if err != nil {
		fmt.Fprintf(os.Stderr, "warning: test returned error: %v\n", err)
	}

	// Parse gas values from output
	gasValues := rg.parseGasOutput(output)

	// Build report
	return rg.buildReport(functions, gasValues), nil
}

// getScriptPath returns the full path to the test script
func (rg *ReportGenerator) getScriptPath() string {
	return filepath.Join(rg.config.IntegrationDir, "testdata", rg.config.TestName+".txtar")
}

// FunctionInfo holds metadata about a function from txtar
type FunctionInfo struct {
	Name     string
	Category string
	Index    int // Order in file
}

// funcPattern matches -func FunctionName in gnokey commands
var funcPattern = regexp.MustCompile(`-func\s+(\w+)`)

// parseTxtar extracts function names and categories from the txtar file
func (rg *ReportGenerator) parseTxtar(path string) ([]FunctionInfo, error) {
	content, err := os.ReadFile(path)
	if err != nil {
		return nil, err
	}

	var functions []FunctionInfo
	var currentCategory string
	lines := strings.Split(string(content), "\n")
	index := 0

	for _, line := range lines {
		trimmed := strings.TrimSpace(line)

		// Category header (### Category ###)
		if strings.HasPrefix(trimmed, "###") && strings.HasSuffix(trimmed, "###") {
			currentCategory = strings.Trim(trimmed, "# ")
			continue
		}

		// Parse function name from gnokey maketx call command
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

	return functions, nil
}

// runTest executes the integration test and captures output
func (rg *ReportGenerator) runTest() ([]string, error) {
	testPattern := fmt.Sprintf("Testdata/%s", rg.config.TestName)
	cmd := exec.Command("go", "test", "-v", ".", "-run", testPattern)
	cmd.Dir = rg.config.IntegrationDir

	var output bytes.Buffer
	cmd.Stdout = &output
	cmd.Stderr = &output

	err := cmd.Run()

	scanner := bufio.NewScanner(&output)
	var lines []string
	for scanner.Scan() {
		lines = append(lines, scanner.Text())
	}

	return lines, err
}

// GasValue holds parsed gas metrics for a single command
type GasValue struct {
	GasUsed      uint64
	StorageBytes int64
	StorageFee   uint64
}

// parseGasOutput extracts gas values from test output
func (rg *ReportGenerator) parseGasOutput(lines []string) []GasValue {
	var values []GasValue
	var current GasValue
	inCommand := false

	for _, line := range lines {
		trimmed := strings.TrimSpace(line)

		// Start of a new command output
		if strings.HasPrefix(trimmed, "> gnokey maketx call") {
			if inCommand {
				values = append(values, current)
			}
			current = GasValue{}
			inCommand = true
			continue
		}

		if !inCommand {
			continue
		}

		// Only parse lines that START with known stdout prefixes
		// This filters out commented lines like "# stdout 'GAS USED:'"
		if !isValidStdoutLine(trimmed) {
			continue
		}

		// Parse GAS USED
		if matches := gasUsedPattern.FindStringSubmatch(trimmed); len(matches) > 1 {
			current.GasUsed, _ = strconv.ParseUint(matches[1], 10, 64)
		}

		// Parse STORAGE DELTA
		if matches := storageDeltaPattern.FindStringSubmatch(trimmed); len(matches) > 1 {
			current.StorageBytes, _ = strconv.ParseInt(matches[1], 10, 64)
		}

		// Parse STORAGE FEE
		if matches := storageFeePattern.FindStringSubmatch(trimmed); len(matches) > 1 {
			current.StorageFee, _ = strconv.ParseUint(matches[1], 10, 64)
		}
	}

	// Don't forget the last command
	if inCommand {
		values = append(values, current)
	}

	return values
}

// isValidStdoutLine checks if a line starts with a known stdout prefix.
// Used to filter out commented lines like "# stdout 'GAS USED:'"
func isValidStdoutLine(line string) bool {
	for prefix := range defaultStdoutPrefixes {
		if strings.HasPrefix(line, prefix) {
			return true
		}
	}
	return false
}

// buildReport creates a GasReport from parsed data
func (rg *ReportGenerator) buildReport(functions []FunctionInfo, gasValues []GasValue) *GasReport {
	report := &GasReport{
		TestName: rg.config.TestName,
	}

	// Find baseline (Empty function - exact match or ends with Empty)
	for i, fn := range functions {
		if (fn.Name == "Empty" || strings.HasSuffix(fn.Name, "Empty")) && i < len(gasValues) {
			report.BaselineCost = gasValues[i].GasUsed
			break
		}
	}

	// Build entries
	for i, fn := range functions {
		if i >= len(gasValues) {
			break
		}

		gv := gasValues[i]
		entry := GasEntry{
			Category:     fn.Category,
			Name:         fn.Name,
			TotalGas:     gv.GasUsed,
			StorageBytes: gv.StorageBytes,
			StorageFee:   gv.StorageFee,
		}

		// Calculate pure gas (excluding baseline)
		if gv.GasUsed > report.BaselineCost {
			entry.PureGas = gv.GasUsed - report.BaselineCost
		}

		report.Entries = append(report.Entries, entry)
	}

	return report
}

// formatMarkdown generates a markdown table from the report
func (rg *ReportGenerator) formatMarkdown(report *GasReport) string {
	var sb strings.Builder

	sb.WriteString(fmt.Sprintf("# Gas Measurement Report: %s\n\n", report.TestName))
	sb.WriteString(fmt.Sprintf("**Baseline (Empty Call):** %s gas\n\n", formatNumber(report.BaselineCost)))

	// Group entries by category
	categories := rg.groupByCategory(report.Entries)

	for _, cat := range categories {
		// Filter out Empty/baseline entries
		var entries []GasEntry
		for _, entry := range cat.Entries {
			if isBaselineFunction(entry.Name) {
				continue
			}
			entries = append(entries, entry)
		}

		// Skip empty categories
		if len(entries) == 0 {
			continue
		}

		if cat.Name != "" {
			sb.WriteString(fmt.Sprintf("## %s\n\n", cat.Name))
		}

		sb.WriteString("| Name | Pure Gas Used | Total Gas Used | Method Call Cost | Storage (bytes) |\n")
		sb.WriteString("|------|---------------|----------------|------------------|----------------|\n")

		for _, entry := range entries {
			sb.WriteString(fmt.Sprintf("| %s | %s | %s | %s | %d |\n",
				entry.Name,
				formatNumber(entry.PureGas),
				formatNumber(entry.TotalGas),
				formatNumber(report.BaselineCost),
				entry.StorageBytes,
			))
		}

		sb.WriteString("\n")
	}

	return sb.String()
}

// isBaselineFunction checks if a function is used for baseline measurement
func isBaselineFunction(name string) bool {
	return name == "Empty" || strings.HasSuffix(name, "Empty")
}

// formatTSV generates a TSV format report (all entries, no category grouping)
func (rg *ReportGenerator) formatTSV(report *GasReport) string {
	var sb strings.Builder

	// Header
	sb.WriteString("Name\tPure Gas Used\tTotal Gas Used\tMethod Call Cost\tStorage (bytes)\n")

	// All entries (excluding baseline)
	for _, entry := range report.Entries {
		if isBaselineFunction(entry.Name) {
			continue
		}

		sb.WriteString(fmt.Sprintf("%s\t%d\t%d\t%d\t%d\n",
			entry.Name,
			entry.PureGas,
			entry.TotalGas,
			report.BaselineCost,
			entry.StorageBytes,
		))
	}

	return sb.String()
}

// Category groups entries by category
type Category struct {
	Name    string
	Entries []GasEntry
}

// groupByCategory groups entries by their category, preserving order
func (rg *ReportGenerator) groupByCategory(entries []GasEntry) []Category {
	categoryMap := make(map[string][]GasEntry)
	var categoryOrder []string
	seen := make(map[string]bool)

	for _, entry := range entries {
		cat := entry.Category
		if cat == "" {
			cat = "Other"
		}

		if !seen[cat] {
			seen[cat] = true
			categoryOrder = append(categoryOrder, cat)
		}

		categoryMap[cat] = append(categoryMap[cat], entry)
	}

	var categories []Category
	for _, name := range categoryOrder {
		categories = append(categories, Category{
			Name:    name,
			Entries: categoryMap[name],
		})
	}

	return categories
}

// formatNumber formats a number with thousands separators
func formatNumber(n uint64) string {
	str := strconv.FormatUint(n, 10)
	if len(str) <= 3 {
		return str
	}

	var result []byte
	for i, c := range str {
		if i > 0 && (len(str)-i)%3 == 0 {
			result = append(result, ',')
		}
		result = append(result, byte(c))
	}

	return string(result)
}

// SortBy defines sort options for the report
type SortBy int

const (
	SortByName SortBy = iota
	SortByTotalGas
	SortByPureGas
)

// SortEntries sorts entries by the specified criteria
func SortEntries(entries []GasEntry, by SortBy, ascending bool) {
	sort.Slice(entries, func(i, j int) bool {
		var less bool
		switch by {
		case SortByName:
			less = entries[i].Name < entries[j].Name
		case SortByTotalGas:
			less = entries[i].TotalGas < entries[j].TotalGas
		case SortByPureGas:
			less = entries[i].PureGas < entries[j].PureGas
		}

		if ascending {
			return less
		}
		return !less
	})
}
