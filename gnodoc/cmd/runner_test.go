package cmd

import (
	"bytes"
	"os"
	"path/filepath"
	"strings"
	"testing"
)

func createTestPackage(t *testing.T) string {
	t.Helper()

	tmpDir, err := os.MkdirTemp("", "gnodoc-cmd-test-*")
	if err != nil {
		t.Fatalf("failed to create temp dir: %v", err)
	}

	content := `// Package testpkg provides test functionality.
package testpkg

// Value is a constant.
const Value = 42

// Foo is a type.
type Foo struct {
	ID int
}

// NewFoo creates a new Foo.
func NewFoo() *Foo {
	return &Foo{}
}
`
	if err := os.WriteFile(filepath.Join(tmpDir, "foo.go"), []byte(content), 0644); err != nil {
		t.Fatalf("failed to write test file: %v", err)
	}

	return tmpDir
}

func TestRunner_Run_BasicCommand(t *testing.T) {
	tmpDir := createTestPackage(t)
	defer os.RemoveAll(tmpDir)

	var stdout, stderr bytes.Buffer
	r := NewRunner(&stdout, &stderr)

	// Run with path argument
	code := r.Run([]string{tmpDir})

	if code != ExitSuccess {
		t.Errorf("expected ExitSuccess, got %v: %s", code, stderr.String())
	}

	// Check output file was created
	outputPath := filepath.Join(".", "README.md")
	content, err := os.ReadFile(outputPath)
	if err != nil {
		t.Fatalf("failed to read output file: %v", err)
	}
	defer os.Remove(outputPath)

	// Verify content contains expected sections
	if !strings.Contains(string(content), "# testpkg") {
		t.Error("expected package name in output")
	}
	if !strings.Contains(string(content), "Foo") {
		t.Error("expected Foo type in output")
	}
}

func TestRunner_Run_WithOutputOption(t *testing.T) {
	tmpDir := createTestPackage(t)
	defer os.RemoveAll(tmpDir)

	outDir, err := os.MkdirTemp("", "gnodoc-out-*")
	if err != nil {
		t.Fatalf("failed to create output dir: %v", err)
	}
	defer os.RemoveAll(outDir)

	var stdout, stderr bytes.Buffer
	r := NewRunner(&stdout, &stderr)

	// Run with --out option
	code := r.Run([]string{"--out=" + outDir, tmpDir})

	if code != ExitSuccess {
		t.Errorf("expected ExitSuccess, got %v: %s", code, stderr.String())
	}

	// Check output file in specified directory
	outputPath := filepath.Join(outDir, "README.md")
	if _, err := os.Stat(outputPath); os.IsNotExist(err) {
		t.Error("output file not created in specified directory")
	}
}

func TestRunner_Run_InvalidPath(t *testing.T) {
	var stdout, stderr bytes.Buffer
	r := NewRunner(&stdout, &stderr)

	code := r.Run([]string{"/nonexistent/path"})

	if code != ExitError {
		t.Errorf("expected ExitError, got %v", code)
	}
}

func TestRunner_Run_NoArgs(t *testing.T) {
	var stdout, stderr bytes.Buffer
	r := NewRunner(&stdout, &stderr)

	code := r.Run([]string{})

	// Should show help or error
	if code != ExitError {
		t.Errorf("expected ExitError for no args, got %v", code)
	}
}

func TestRunner_Export(t *testing.T) {
	tmpDir := createTestPackage(t)
	defer os.RemoveAll(tmpDir)

	outDir, err := os.MkdirTemp("", "gnodoc-export-*")
	if err != nil {
		t.Fatalf("failed to create output dir: %v", err)
	}
	defer os.RemoveAll(outDir)

	var stdout, stderr bytes.Buffer
	r := NewRunner(&stdout, &stderr)

	code := r.Run([]string{"export", "--out=" + outDir, "--filename=docs.md", tmpDir})

	if code != ExitSuccess {
		t.Errorf("expected ExitSuccess, got %v: %s", code, stderr.String())
	}

	// Check custom filename
	outputPath := filepath.Join(outDir, "docs.md")
	if _, err := os.Stat(outputPath); os.IsNotExist(err) {
		t.Error("output file not created with custom filename")
	}
}

func TestRunner_List(t *testing.T) {
	tmpDir := createTestPackage(t)
	defer os.RemoveAll(tmpDir)

	var stdout, stderr bytes.Buffer
	r := NewRunner(&stdout, &stderr)

	code := r.Run([]string{"list", tmpDir})

	if code != ExitSuccess {
		t.Errorf("expected ExitSuccess, got %v: %s", code, stderr.String())
	}

	// Should output package path
	output := stdout.String()
	if !strings.Contains(output, tmpDir) {
		t.Errorf("expected package path in output, got: %s", output)
	}
}

func TestRunner_Help(t *testing.T) {
	var stdout, stderr bytes.Buffer
	r := NewRunner(&stdout, &stderr)

	code := r.Run([]string{"--help"})

	// Help should succeed
	if code != ExitSuccess {
		t.Errorf("expected ExitSuccess for --help, got %v", code)
	}

	// Should contain usage info
	output := stdout.String()
	if !strings.Contains(output, "gnodoc") {
		t.Error("expected usage info in output")
	}
}

func createTestPackageWithUnexported(t *testing.T) string {
	t.Helper()

	tmpDir, err := os.MkdirTemp("", "gnodoc-cmd-test-*")
	if err != nil {
		t.Fatalf("failed to create temp dir: %v", err)
	}

	content := `// Package mixedpkg has exported and unexported symbols.
package mixedpkg

// PublicConst is exported.
const PublicConst = 1

// privateConst is unexported.
const privateConst = 2

// PublicFunc is exported.
func PublicFunc() {}

// privateFunc is unexported.
func privateFunc() {}

// PublicType is exported.
type PublicType struct{}

// privateType is unexported.
type privateType struct{}
`
	if err := os.WriteFile(filepath.Join(tmpDir, "mixed.go"), []byte(content), 0644); err != nil {
		t.Fatalf("failed to write test file: %v", err)
	}

	return tmpDir
}

func TestRunner_ExportedOnlyFlag(t *testing.T) {
	tmpDir := createTestPackageWithUnexported(t)
	defer os.RemoveAll(tmpDir)

	outDir, err := os.MkdirTemp("", "gnodoc-out-*")
	if err != nil {
		t.Fatalf("failed to create output dir: %v", err)
	}
	defer os.RemoveAll(outDir)

	var stdout, stderr bytes.Buffer
	r := NewRunner(&stdout, &stderr)

	// Run with --exported-only flag (explicit)
	code := r.Run([]string{"--exported-only", "--out=" + outDir, tmpDir})

	if code != ExitSuccess {
		t.Errorf("expected ExitSuccess, got %v: %s", code, stderr.String())
	}

	outputPath := filepath.Join(outDir, "README.md")
	content, err := os.ReadFile(outputPath)
	if err != nil {
		t.Fatalf("failed to read output file: %v", err)
	}

	// Should contain exported symbols
	if !strings.Contains(string(content), "PublicConst") {
		t.Error("expected PublicConst in output")
	}
	if !strings.Contains(string(content), "PublicFunc") {
		t.Error("expected PublicFunc in output")
	}
	if !strings.Contains(string(content), "PublicType") {
		t.Error("expected PublicType in output")
	}

	// Should NOT contain unexported symbols
	if strings.Contains(string(content), "privateConst") {
		t.Error("unexpected privateConst in output with --exported-only")
	}
	if strings.Contains(string(content), "privateFunc") {
		t.Error("unexpected privateFunc in output with --exported-only")
	}
	if strings.Contains(string(content), "privateType") {
		t.Error("unexpected privateType in output with --exported-only")
	}
}

func createTestPackageWithParseError(t *testing.T) string {
	t.Helper()

	tmpDir, err := os.MkdirTemp("", "gnodoc-cmd-test-*")
	if err != nil {
		t.Fatalf("failed to create temp dir: %v", err)
	}

	// Valid file
	validContent := `package partialerr

// Valid is a valid function.
func Valid() {}
`
	if err := os.WriteFile(filepath.Join(tmpDir, "valid.go"), []byte(validContent), 0644); err != nil {
		t.Fatalf("failed to write valid file: %v", err)
	}

	// Invalid file with syntax error
	invalidContent := `package partialerr

func Invalid( {
	// syntax error
}
`
	if err := os.WriteFile(filepath.Join(tmpDir, "invalid.go"), []byte(invalidContent), 0644); err != nil {
		t.Fatalf("failed to write invalid file: %v", err)
	}

	return tmpDir
}

func TestRunner_PartialError(t *testing.T) {
	tmpDir := createTestPackageWithParseError(t)
	defer os.RemoveAll(tmpDir)

	outDir, err := os.MkdirTemp("", "gnodoc-out-*")
	if err != nil {
		t.Fatalf("failed to create output dir: %v", err)
	}
	defer os.RemoveAll(outDir)

	var stdout, stderr bytes.Buffer
	r := NewRunner(&stdout, &stderr)

	// Run with --ignore-parse-errors flag
	code := r.Run([]string{"--ignore-parse-errors", "--out=" + outDir, tmpDir})

	// Should return ExitPartialError (2) not ExitSuccess (0)
	if code != ExitPartialError {
		t.Errorf("expected ExitPartialError (2), got %v", code)
	}

	// Output file should still be created
	outputPath := filepath.Join(outDir, "README.md")
	content, err := os.ReadFile(outputPath)
	if err != nil {
		t.Fatalf("failed to read output file: %v", err)
	}

	// Should contain the valid function
	if !strings.Contains(string(content), "Valid") {
		t.Error("expected Valid function in output")
	}
}

func TestRunner_AllFlag(t *testing.T) {
	tmpDir := createTestPackageWithUnexported(t)
	defer os.RemoveAll(tmpDir)

	outDir, err := os.MkdirTemp("", "gnodoc-out-*")
	if err != nil {
		t.Fatalf("failed to create output dir: %v", err)
	}
	defer os.RemoveAll(outDir)

	var stdout, stderr bytes.Buffer
	r := NewRunner(&stdout, &stderr)

	// Run with --all flag
	code := r.Run([]string{"--all", "--out=" + outDir, tmpDir})

	if code != ExitSuccess {
		t.Errorf("expected ExitSuccess, got %v: %s", code, stderr.String())
	}

	outputPath := filepath.Join(outDir, "README.md")
	content, err := os.ReadFile(outputPath)
	if err != nil {
		t.Fatalf("failed to read output file: %v", err)
	}

	// Should contain exported symbols
	if !strings.Contains(string(content), "PublicConst") {
		t.Error("expected PublicConst in output")
	}
	if !strings.Contains(string(content), "PublicFunc") {
		t.Error("expected PublicFunc in output")
	}
	if !strings.Contains(string(content), "PublicType") {
		t.Error("expected PublicType in output")
	}

	// Should also contain unexported symbols with --all
	if !strings.Contains(string(content), "privateConst") {
		t.Error("expected privateConst in output with --all")
	}
	if !strings.Contains(string(content), "privateFunc") {
		t.Error("expected privateFunc in output with --all")
	}
	if !strings.Contains(string(content), "privateType") {
		t.Error("expected privateType in output with --all")
	}
}

func createTestPackageWithMultipleFiles(t *testing.T) string {
	t.Helper()

	tmpDir, err := os.MkdirTemp("", "gnodoc-cmd-test-*")
	if err != nil {
		t.Fatalf("failed to create temp dir: %v", err)
	}

	// Main file
	mainContent := `package multipkg

// MainFunc is from main.go.
func MainFunc() {}
`
	if err := os.WriteFile(filepath.Join(tmpDir, "main.go"), []byte(mainContent), 0644); err != nil {
		t.Fatalf("failed to write main file: %v", err)
	}

	// Generated file (to be excluded)
	genContent := `package multipkg

// GeneratedFunc is from generated.go.
func GeneratedFunc() {}
`
	if err := os.WriteFile(filepath.Join(tmpDir, "generated.go"), []byte(genContent), 0644); err != nil {
		t.Fatalf("failed to write generated file: %v", err)
	}

	return tmpDir
}

func TestRunner_ExcludeFlag(t *testing.T) {
	tmpDir := createTestPackageWithMultipleFiles(t)
	defer os.RemoveAll(tmpDir)

	outDir, err := os.MkdirTemp("", "gnodoc-out-*")
	if err != nil {
		t.Fatalf("failed to create output dir: %v", err)
	}
	defer os.RemoveAll(outDir)

	var stdout, stderr bytes.Buffer
	r := NewRunner(&stdout, &stderr)

	// Run with --exclude flag
	code := r.Run([]string{"--exclude=generated*", "--out=" + outDir, tmpDir})

	if code != ExitSuccess {
		t.Errorf("expected ExitSuccess, got %v: %s", code, stderr.String())
	}

	outputPath := filepath.Join(outDir, "README.md")
	content, err := os.ReadFile(outputPath)
	if err != nil {
		t.Fatalf("failed to read output file: %v", err)
	}

	// Should have MainFunc
	if !strings.Contains(string(content), "MainFunc") {
		t.Error("expected MainFunc in output")
	}

	// Should NOT have GeneratedFunc (excluded)
	if strings.Contains(string(content), "GeneratedFunc") {
		t.Error("unexpected GeneratedFunc in output (should be excluded)")
	}
}
