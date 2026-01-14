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
