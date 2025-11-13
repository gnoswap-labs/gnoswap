package main

import (
	"bufio"
	"bytes"
	"errors"
	"flag"
	"fmt"
	"os"
	"os/exec"
	"path/filepath"
	"strings"
)

// Configuration holds all command-line flags
type Configuration struct {
	TestName       string
	IntegrationDir string
	MaskSpec       string
	DryRun         bool
}

// CommandOutput represents the output of a single command execution
type CommandOutput struct {
	Command string
	Stdout  []string
	Stderr  []string
}

// ScriptProcessor handles script file operations
type ScriptProcessor struct {
	config   *Configuration
	patterns []MaskPattern
}

var stdoutPrefixes = []string{
	"GAS USED:",
	"STORAGE DELTA:",
	"TOTAL TX COST:",
	"EVENTS:",
}

const (
	outputStdout = "stdout"
	outputStderr = "stderr"
)

func main() {
	config := parseFlags()
	
	if err := validateConfig(config); err != nil {
		exitWithError(err)
	}

	processor, err := NewScriptProcessor(config)
	if err != nil {
		exitWithError(err)
	}

	if err := processor.Process(); err != nil {
		exitWithError(err)
	}
}

// parseFlags parses and returns command-line flags
func parseFlags() *Configuration {
	config := &Configuration{}
	
	flag.StringVar(&config.TestName, "test", "", "testdata name (without extension), e.g. gnoswap_swap_gns_wugnot")
	flag.StringVar(&config.IntegrationDir, "integration-dir", 
		filepath.Join("gno.land", "pkg", "integration"), 
		"path to the integration package")
	flag.StringVar(&config.MaskSpec, "mask", DefaultMaskSpec, "mask overrides passed to testscriptfmt")
	flag.BoolVar(&config.DryRun, "dry-run", false, "print updated script to stdout instead of writing the file")
	
	flag.Parse()
	
	return config
}

// validateConfig checks if the configuration is valid
func validateConfig(config *Configuration) error {
	if config.TestName == "" {
		return errors.New("missing -test flag (e.g. -test gnoswap_swap_gns_wugnot)")
	}
	return nil
}

// NewScriptProcessor creates a new ScriptProcessor with parsed mask patterns
func NewScriptProcessor(config *Configuration) (*ScriptProcessor, error) {
	patterns, err := ParseMaskPatterns(config.MaskSpec)
	if err != nil {
		return nil, fmt.Errorf("failed to parse mask patterns: %w", err)
	}
	
	return &ScriptProcessor{
		config:   config,
		patterns: patterns,
	}, nil
}

// Process executes the main workflow
func (sp *ScriptProcessor) Process() error {
	scriptPath := sp.getScriptPath()
	
	// Sanitize script and set up restoration
	restoreFn, err := sp.sanitizeScript(scriptPath)
	if err != nil {
		return fmt.Errorf("failed to sanitize script: %w", err)
	}
	if restoreFn != nil {
		defer func() {
			if err := restoreFn(); err != nil {
				fmt.Fprintf(os.Stderr, "restore error: %v\n", err)
			}
		}()
	}

	// Run tests and capture output
	lines, testErr := sp.runTest()
	if testErr != nil {
		fmt.Fprintf(os.Stderr, "warning: go test returned an error: %v (continuing with captured output)\n", testErr)
	}

	// Parse command outputs
	cmdOutputs := parseCommandOutputs(lines)
	if len(cmdOutputs) == 0 {
		return errors.New("no commands with [stdout] or [stderr] output were captured")
	}

	// Update script with new outputs
	return sp.updateScript(scriptPath, cmdOutputs)
}

// getScriptPath returns the full path to the test script
func (sp *ScriptProcessor) getScriptPath() string {
	return filepath.Join(sp.config.IntegrationDir, "testdata", sp.config.TestName+".txtar")
}

// runTest executes the go test command and captures output
func (sp *ScriptProcessor) runTest() ([]string, error) {
	testPattern := fmt.Sprintf("Testdata/%s", sp.config.TestName)
	cmd := exec.Command("go", "test", "-v", ".", "-run", testPattern)
	cmd.Dir = sp.config.IntegrationDir

	var output bytes.Buffer
	cmd.Stdout = &output
	cmd.Stderr = &output

	err := cmd.Run()
	
	return sp.scanOutput(&output), err
}

// scanOutput scans the command output into lines
func (sp *ScriptProcessor) scanOutput(output *bytes.Buffer) []string {
	scanner := bufio.NewScanner(output)
	scanner.Buffer(make([]byte, 0, 64*1024), 1024*1024)

	var lines []string
	for scanner.Scan() {
		lines = append(lines, scanner.Text())
	}

	if err := scanner.Err(); err != nil {
		fmt.Fprintf(os.Stderr, "scanner error: %v\n", err)
	}

	return lines
}

// parseCommandOutputs extracts command outputs from test output lines
func parseCommandOutputs(lines []string) []CommandOutput {
	var outputs []CommandOutput
	currentIdx := -1
	currentSection := ""

	for _, raw := range lines {
		line := strings.TrimLeft(raw, " \t")
		trimmed := strings.TrimSpace(raw)

		// Handle command lines
		if strings.HasPrefix(line, "> ") {
			cmdText := strings.TrimSpace(line[2:])
			
			if isExpectationCommand(cmdText) {
				currentIdx = -1
				currentSection = ""
				continue
			}

			outputs = append(outputs, CommandOutput{Command: cmdText})
			currentIdx = len(outputs) - 1
			currentSection = ""
			continue
		}

		// Handle section markers
		if handleSectionMarker(trimmed, &currentSection) {
			continue
		}

		// Collect output if we're in a section
		if currentSection == "" || currentIdx == -1 {
			continue
		}

		text := strings.TrimSpace(raw)
		if text == "" {
			continue
		}

		// Filter out password prompts from stderr
		if currentSection == outputStderr && text == "Enter password." {
			continue
		}

		// Add output to appropriate section
		if currentSection == outputStdout {
			if shouldKeepStdoutLine(text, outputs[currentIdx].Command) {
				outputs[currentIdx].Stdout = append(outputs[currentIdx].Stdout, text)
			}
		} else if shouldKeepStderrLine(text) {
			outputs[currentIdx].Stderr = append(outputs[currentIdx].Stderr, text)
		}
	}

	return outputs
}

// handleSectionMarker checks if the line is a section marker and updates the current section
func handleSectionMarker(trimmed string, currentSection *string) bool {
	switch trimmed {
	case "[stdout]":
		*currentSection = outputStdout
		return true
	case "[stderr]":
		*currentSection = outputStderr
		return true
	}

	// Reset section on headers
	if strings.HasPrefix(trimmed, "## ") || strings.HasPrefix(trimmed, "###") {
		*currentSection = ""
		return true
	}

	return false
}

// shouldKeepStdoutLine determines if a stdout line should be kept
func shouldKeepStdoutLine(line, cmd string) bool {
	line = strings.TrimSpace(line)
	if line == "" || strings.HasPrefix(line, "## ") {
		return false
	}

	if strings.Contains(cmd, "gnokey query vm/qeval") || line == "OK!" {
		return true
	}

	for _, prefix := range stdoutPrefixes {
		if strings.HasPrefix(line, prefix) {
			return true
		}
	}

	return false
}

// shouldKeepStderrLine determines if a stderr line should be kept
func shouldKeepStderrLine(line string) bool {
	line = strings.TrimSpace(line)
	if line == "" {
		return false
	}

	unwantedPrefixes := []string{"## ", "--- ", "===", "PASS", "FAIL", "ok ", "?"}
	for _, prefix := range unwantedPrefixes {
		if strings.HasPrefix(line, prefix) {
			return false
		}
	}

	return true
}

// updateScript updates the script file with new command outputs
func (sp *ScriptProcessor) updateScript(path string, outputs []CommandOutput) error {
	info, err := os.Stat(path)
	if err != nil {
		return fmt.Errorf("failed to stat file: %w", err)
	}

	content, err := os.ReadFile(path)
	if err != nil {
		return fmt.Errorf("failed to read file: %w", err)
	}

	newContent := sp.buildUpdatedContent(content, outputs)

	if sp.config.DryRun {
		fmt.Print(newContent)
		return nil
	}

	return os.WriteFile(path, []byte(newContent), info.Mode())
}

// buildUpdatedContent constructs the updated script content
func (sp *ScriptProcessor) buildUpdatedContent(content []byte, outputs []CommandOutput) string {
	lines := strings.Split(strings.ReplaceAll(string(content), "\r\n", "\n"), "\n")

	stdoutConv := NewConverter(outputStdout, true, true, sp.patterns)
	stderrConv := NewConverter(outputStderr, true, true, sp.patterns)

	var (
		result        []string
		outputIdx     int
		inFileSection bool
	)

	for _, line := range lines {
		trimmed := strings.TrimSpace(line)
		
		// Skip expectation commands
		if isExpectationCommand(trimmed) {
			continue
		}

		result = append(result, line)

		// Track file sections
		if strings.HasPrefix(trimmed, "-- ") {
			inFileSection = true
		}

		if inFileSection || !isCommandLine(trimmed) || outputIdx >= len(outputs) {
			continue
		}

		// Add output for this command
		output := outputs[outputIdx]
		outputIdx++

		result = append(result, sp.formatOutput(output, stdoutConv, stderrConv)...)
	}

	newContent := strings.Join(result, "\n")
	if !strings.HasSuffix(newContent, "\n") {
		newContent += "\n"
	}

	return newContent
}

// formatOutput formats command output using converters
func (sp *ScriptProcessor) formatOutput(output CommandOutput, stdoutConv, stderrConv Converter) []string {
	var lines []string

	for _, stdoutLine := range output.Stdout {
		if formatted, ok := stdoutConv.ConvertLine(stdoutLine); ok {
			lines = append(lines, formatted)
		}
	}

	for _, stderrLine := range output.Stderr {
		if formatted, ok := stderrConv.ConvertLine(stderrLine); ok {
			lines = append(lines, formatted)
		}
	}

	return lines
}

// sanitizeScript removes expectation commands from the script
func (sp *ScriptProcessor) sanitizeScript(path string) (func() error, error) {
	info, err := os.Stat(path)
	if err != nil {
		return nil, fmt.Errorf("failed to stat script: %w", err)
	}

	original, err := os.ReadFile(path)
	if err != nil {
		return nil, fmt.Errorf("failed to read script: %w", err)
	}

	sanitized, changed := stripExpectations(original)
	if !changed {
		return nil, nil
	}

	if err := os.WriteFile(path, sanitized, info.Mode()); err != nil {
		return nil, fmt.Errorf("failed to write sanitized script: %w", err)
	}

	// Return restoration function only if not in dry-run mode
	if sp.config.DryRun {
		return func() error { 
			return os.WriteFile(path, original, info.Mode()) 
		}, nil
	}

	return nil, nil
}

// stripExpectations removes expectation commands from content
func stripExpectations(content []byte) ([]byte, bool) {
	text := strings.ReplaceAll(string(content), "\r\n", "\n")
	lines := strings.Split(text, "\n")

	var result []string
	for _, line := range lines {
		if !isExpectationCommand(strings.TrimSpace(line)) {
			result = append(result, line)
		}
	}

	newContent := strings.Join(result, "\n")
	if strings.HasSuffix(text, "\n") && !strings.HasSuffix(newContent, "\n") {
		newContent += "\n"
	}

	if newContent == text {
		return []byte(text), false
	}

	return []byte(newContent), true
}

// isExpectationCommand checks if a line is an expectation command
func isExpectationCommand(line string) bool {
	line = strings.TrimSpace(line)
	return line != "" && (strings.HasPrefix(line, "stdout") || strings.HasPrefix(line, "stderr"))
}

// isCommandLine checks if a line is a command line
func isCommandLine(line string) bool {
	if line == "" {
		return false
	}

	// Comments
	if strings.HasPrefix(line, "#") || strings.HasPrefix(line, "//") {
		return false
	}

	// Txtar separators or metadata
	if strings.HasPrefix(line, "--") {
		return false
	}

	return true
}

// exitWithError prints an error and exits
func exitWithError(err error) {
	fmt.Fprintf(os.Stderr, "error: %v\n", err)
	os.Exit(1)
}
