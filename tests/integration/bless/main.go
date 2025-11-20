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
	config         *Configuration
	patterns       []MaskPattern
	stdoutConv     Converter
	stderrConv     Converter
	stdoutPrefixes []string
}

const (
	outputStdout      = "stdout"
	outputStderr      = "stderr"
	maxScannerBuffer  = 1024 * 1024 // 1MB
	initialBufferSize = 64 * 1024   // 64KB
	passwordPrompt    = "Enter password."
	okOutput          = "OK!"
)

var defaultStdoutPrefixes = []string{
	"GAS USED:",
	"STORAGE DELTA:",
	"TOTAL TX COST:",
	"EVENTS:",
}

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

	flag.StringVar(&config.TestName, "test", "",
		"testdata name (without extension), e.g. gnoswap_swap_gns_wugnot")
	flag.StringVar(&config.IntegrationDir, "integration-dir",
		filepath.Join("gno.land", "pkg", "integration"),
		"path to the integration package")
	flag.StringVar(&config.MaskSpec, "mask", DefaultMaskSpec,
		"mask overrides passed to testscriptfmt")
	flag.BoolVar(&config.DryRun, "dry-run", false,
		"print updated script to stdout instead of writing the file")

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
		config:         config,
		patterns:       patterns,
		stdoutConv:     NewConverter(outputStdout, true, true, patterns),
		stderrConv:     NewConverter(outputStderr, true, true, patterns),
		stdoutPrefixes: defaultStdoutPrefixes,
	}, nil
}

// Process executes the main workflow
func (sp *ScriptProcessor) Process() error {
	scriptPath := sp.getScriptPath()

	// Sanitize script and set up restoration
	if err := sp.withSanitizedScript(scriptPath, func() error {
		return sp.processTest(scriptPath)
	}); err != nil {
		return err
	}

	return nil
}

// withSanitizedScript temporarily sanitizes the script and restores it after the function completes
func (sp *ScriptProcessor) withSanitizedScript(scriptPath string, fn func() error) error {
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

	return fn()
}

// processTest runs the test and updates the script
func (sp *ScriptProcessor) processTest(scriptPath string) error {
	// Run tests and capture output
	lines, testErr := sp.runTest()
	if testErr != nil {
		fmt.Fprintf(os.Stderr, "warning: go test returned an error: %v (continuing with captured output)\n", testErr)
	}

	// Parse command outputs
	cmdOutputs := sp.parseCommandOutputs(lines)
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

	return scanOutput(&output), err
}

// scanOutput scans the command output into lines
func scanOutput(output *bytes.Buffer) []string {
	scanner := bufio.NewScanner(output)
	scanner.Buffer(make([]byte, 0, initialBufferSize), maxScannerBuffer)

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
func (sp *ScriptProcessor) parseCommandOutputs(lines []string) []CommandOutput {
	parser := &outputParser{
		processor: sp,
		outputs:   make([]CommandOutput, 0, 10),
	}

	for _, raw := range lines {
		parser.parseLine(raw)
	}

	return parser.outputs
}

// outputParser maintains state while parsing command outputs
type outputParser struct {
	processor      *ScriptProcessor
	outputs        []CommandOutput
	currentIdx     int
	currentSection string
}

// parseLine processes a single line of test output
func (p *outputParser) parseLine(raw string) {
	line := strings.TrimLeft(raw, " \t")
	trimmed := strings.TrimSpace(raw)

	// Handle command lines
	if strings.HasPrefix(line, "> ") {
		p.handleCommandLine(line)
		return
	}

	// Handle section markers
	if p.handleSectionMarker(trimmed) {
		return
	}

	// Collect output if we're in a valid section
	if p.currentSection == "" || p.currentIdx < 0 {
		return
	}

	text := strings.TrimSpace(raw)
	if text == "" {
		return
	}

	p.addOutputLine(text)
}

// handleCommandLine processes a command line (starting with "> ")
func (p *outputParser) handleCommandLine(line string) {
	cmdText := strings.TrimSpace(line[2:])

	if isExpectationCommand(cmdText) {
		p.resetState()
		return
	}

	p.outputs = append(p.outputs, CommandOutput{Command: cmdText})
	p.currentIdx = len(p.outputs) - 1
	p.currentSection = ""
}

// handleSectionMarker checks if the line is a section marker and updates state
func (p *outputParser) handleSectionMarker(trimmed string) bool {
	switch trimmed {
	case "[stdout]":
		p.currentSection = outputStdout
		return true
	case "[stderr]":
		p.currentSection = outputStderr
		return true
	}

	// Reset section on headers
	if strings.HasPrefix(trimmed, "## ") || strings.HasPrefix(trimmed, "###") {
		p.currentSection = ""
		return true
	}

	return false
}

// addOutputLine adds a line to the current command's output
func (p *outputParser) addOutputLine(text string) {
	if p.currentSection == outputStderr && text == passwordPrompt {
		return // Filter out password prompts
	}

	currentOutput := &p.outputs[p.currentIdx]

	if p.currentSection == outputStdout {
		if p.shouldKeepStdoutLine(text, currentOutput.Command) {
			currentOutput.Stdout = append(currentOutput.Stdout, text)
		}
	} else if shouldKeepStderrLine(text) {
		currentOutput.Stderr = append(currentOutput.Stderr, text)
	}
}

// resetState resets the parser state
func (p *outputParser) resetState() {
	p.currentIdx = -1
	p.currentSection = ""
}

// shouldKeepStdoutLine determines if a stdout line should be kept
func (p *outputParser) shouldKeepStdoutLine(line, cmd string) bool {
	line = strings.TrimSpace(line)
	if line == "" || strings.HasPrefix(line, "## ") {
		return false
	}

	// Keep query results and OK messages
	if strings.Contains(cmd, "gnokey query vm/qeval") || line == okOutput {
		return true
	}

	// Check against known prefixes
	for _, prefix := range p.processor.stdoutPrefixes {
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

	// Filter out test framework output
	unwantedPrefixes := []string{"#", "--- ", "===", "PASS", "FAIL", "ok ", "?"}
	for _, prefix := range unwantedPrefixes {
		if strings.HasPrefix(line, prefix) {
			return false
		}
	}

	return true
}

// updateScript updates the script file with new command outputs
func (sp *ScriptProcessor) updateScript(path string, outputs []CommandOutput) error {
	resolvedPath, info, err := sp.resolveScriptPath(path)
	if err != nil {
		return err
	}

	content, err := os.ReadFile(resolvedPath)
	if err != nil {
		return fmt.Errorf("failed to read file: %w", err)
	}

	newContent := sp.buildUpdatedContent(content, outputs)

	if sp.config.DryRun {
		fmt.Print(newContent)
		return nil
	}

	return os.WriteFile(resolvedPath, []byte(newContent), info.Mode())
}

// resolveScriptPath resolves symlinks and returns the file info
func (sp *ScriptProcessor) resolveScriptPath(path string) (string, os.FileInfo, error) {
	resolvedPath, err := filepath.EvalSymlinks(path)
	if err != nil {
		return "", nil, fmt.Errorf("failed to resolve symlink: %w", err)
	}

	info, err := os.Stat(resolvedPath)
	if err != nil {
		return "", nil, fmt.Errorf("failed to stat file: %w", err)
	}

	return resolvedPath, info, nil
}

// buildUpdatedContent constructs the updated script content
func (sp *ScriptProcessor) buildUpdatedContent(content []byte, outputs []CommandOutput) string {
	lines := normalizeLines(content)
	builder := &scriptBuilder{
		processor: sp,
		outputs:   outputs,
		result:    make([]string, 0, len(lines)+100),
	}

	for _, line := range lines {
		builder.processLine(line)
	}

	return builder.finalize()
}

// scriptBuilder helps construct the updated script
type scriptBuilder struct {
	processor     *ScriptProcessor
	outputs       []CommandOutput
	result        []string
	outputIdx     int
	inFileSection bool
}

// processLine processes a single line of the original script
func (sb *scriptBuilder) processLine(line string) {
	trimmed := strings.TrimSpace(line)

	// Skip expectation commands
	if isExpectationCommand(trimmed) {
		return
	}

	sb.result = append(sb.result, line)

	// Track file sections
	if strings.HasPrefix(trimmed, "-- ") {
		sb.inFileSection = true
	}

	// Add output for command lines
	if !sb.inFileSection && isCommandLine(trimmed) && sb.outputIdx < len(sb.outputs) {
		sb.addCommandOutput()
	}
}

// addCommandOutput adds the output for the current command
func (sb *scriptBuilder) addCommandOutput() {
	output := sb.outputs[sb.outputIdx]
	sb.outputIdx++

	formatted := sb.formatOutput(output)
	sb.result = append(sb.result, formatted...)
}

// formatOutput formats command output using converters
func (sb *scriptBuilder) formatOutput(output CommandOutput) []string {
	var lines []string

	for _, stdoutLine := range output.Stdout {
		if formatted, ok := sb.processor.stdoutConv.ConvertLine(stdoutLine); ok {
			lines = append(lines, formatted)
		}
	}

	for _, stderrLine := range output.Stderr {
		if formatted, ok := sb.processor.stderrConv.ConvertLine(stderrLine); ok {
			lines = append(lines, formatted)
		}
	}

	return lines
}

// finalize completes the script building and returns the result
func (sb *scriptBuilder) finalize() string {
	newContent := strings.Join(sb.result, "\n")
	if !strings.HasSuffix(newContent, "\n") {
		newContent += "\n"
	}
	return newContent
}

// normalizeLines splits content into lines with normalized line endings
func normalizeLines(content []byte) []string {
	text := strings.ReplaceAll(string(content), "\r\n", "\n")
	return strings.Split(text, "\n")
}

// sanitizeScript removes expectation commands from the script
func (sp *ScriptProcessor) sanitizeScript(path string) (func() error, error) {
	resolvedPath, info, err := sp.resolveScriptPath(path)
	if err != nil {
		return nil, err
	}

	original, err := os.ReadFile(resolvedPath)
	if err != nil {
		return nil, fmt.Errorf("failed to read script: %w", err)
	}

	sanitized, changed := stripExpectations(original)
	if !changed {
		return nil, nil // No changes needed
	}

	if err := os.WriteFile(resolvedPath, sanitized, info.Mode()); err != nil {
		return nil, fmt.Errorf("failed to write sanitized script: %w", err)
	}

	// Return restoration function only if in dry-run mode
	if sp.config.DryRun {
		return createRestoreFunction(resolvedPath, original, info.Mode()), nil
	}

	return nil, nil
}

// createRestoreFunction returns a function that restores the original content
func createRestoreFunction(path string, content []byte, mode os.FileMode) func() error {
	return func() error {
		return os.WriteFile(path, content, mode)
	}
}

// stripExpectations removes expectation commands from content
func stripExpectations(content []byte) ([]byte, bool) {
	lines := normalizeLines(content)
	hasTrailingNewline := strings.HasSuffix(string(content), "\n")

	var result []string
	for _, line := range lines {
		if !isExpectationCommand(strings.TrimSpace(line)) {
			result = append(result, line)
		}
	}

	newContent := strings.Join(result, "\n")
	if hasTrailingNewline && !strings.HasSuffix(newContent, "\n") {
		newContent += "\n"
	}

	return []byte(newContent), newContent != string(content)
}

// isExpectationCommand checks if a line is an expectation command
func isExpectationCommand(line string) bool {
	line = strings.TrimSpace(line)
	if line == "" {
		return false
	}
	return strings.HasPrefix(line, "stdout") || strings.HasPrefix(line, "stderr")
}

// isCommandLine checks if a line is a command line
func isCommandLine(line string) bool {
	if line == "" {
		return false
	}

	// Filter out comments
	if strings.HasPrefix(line, "#") || strings.HasPrefix(line, "//") {
		return false
	}

	// Filter out txtar separators or metadata
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
