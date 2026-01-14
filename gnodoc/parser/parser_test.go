package parser

import (
	"os"
	"path/filepath"
	"testing"
)

func TestParser_ParsePackage(t *testing.T) {
	// Create temp directory with test files
	tmpDir, err := os.MkdirTemp("", "gnodoc-test-*")
	if err != nil {
		t.Fatalf("failed to create temp dir: %v", err)
	}
	defer os.RemoveAll(tmpDir)

	// Write test Go file
	testFile := filepath.Join(tmpDir, "foo.go")
	content := `// Package foo provides foo functionality.
//
// This is a detailed description.
package foo

// MaxSize is the maximum size.
const MaxSize = 1024

// DefaultName is the default name.
var DefaultName = "foo"

// Foo represents a foo.
type Foo struct {
	// ID is the unique identifier.
	ID int
	// Name is the name.
	Name string
}

// NewFoo creates a new Foo.
func NewFoo(id int, name string) *Foo {
	return &Foo{ID: id, Name: name}
}

// String returns a string representation.
func (f *Foo) String() string {
	return f.Name
}
`
	if err := os.WriteFile(testFile, []byte(content), 0644); err != nil {
		t.Fatalf("failed to write test file: %v", err)
	}

	// Parse package
	p := New(DefaultOptions())
	pkg, err := p.ParsePackage(tmpDir)
	if err != nil {
		t.Fatalf("ParsePackage failed: %v", err)
	}

	// Verify package info
	if pkg.Name != "foo" {
		t.Errorf("expected package name 'foo', got %q", pkg.Name)
	}

	// Verify doc
	if pkg.Doc == "" {
		t.Error("expected package doc")
	}

	// Verify constants
	if len(pkg.Consts) == 0 {
		t.Error("expected constants")
	}

	// Verify variables
	if len(pkg.Vars) == 0 {
		t.Error("expected variables")
	}

	// Verify types
	if len(pkg.Types) == 0 {
		t.Error("expected types")
	}

	// Check Foo type exists with methods and constructors
	foundFoo := false
	for _, typ := range pkg.Types {
		if typ.Name == "Foo" {
			foundFoo = true
			if len(typ.Methods) == 0 {
				t.Error("expected Foo to have methods")
			}
			if len(typ.Fields) == 0 {
				t.Error("expected Foo to have fields")
			}
			// NewFoo should be in constructors (go/doc groups NewXxx as constructors)
			foundNewFoo := false
			for _, ctor := range typ.Constructors {
				if ctor.Name == "NewFoo" {
					foundNewFoo = true
					break
				}
			}
			if !foundNewFoo {
				t.Error("expected NewFoo in Foo's constructors")
			}
			break
		}
	}
	if !foundFoo {
		t.Error("expected Foo type")
	}
}

func TestParser_ParsePackage_IgnoreTests(t *testing.T) {
	tmpDir, err := os.MkdirTemp("", "gnodoc-test-*")
	if err != nil {
		t.Fatalf("failed to create temp dir: %v", err)
	}
	defer os.RemoveAll(tmpDir)

	// Write main file
	mainFile := filepath.Join(tmpDir, "main.go")
	mainContent := `package main

func Main() {}
`
	if err := os.WriteFile(mainFile, []byte(mainContent), 0644); err != nil {
		t.Fatalf("failed to write main file: %v", err)
	}

	// Write test file
	testFile := filepath.Join(tmpDir, "main_test.go")
	testContent := `package main

func TestMain() {}
`
	if err := os.WriteFile(testFile, []byte(testContent), 0644); err != nil {
		t.Fatalf("failed to write test file: %v", err)
	}

	// Parse without tests
	opts := DefaultOptions()
	opts.IncludeTests = false

	p := New(opts)
	pkg, err := p.ParsePackage(tmpDir)
	if err != nil {
		t.Fatalf("ParsePackage failed: %v", err)
	}

	// Should not include test files
	for _, f := range pkg.Files {
		if f.IsTestFile() {
			t.Error("should not include test files")
		}
	}
}

func TestParser_ParsePackage_IncludeTests(t *testing.T) {
	tmpDir, err := os.MkdirTemp("", "gnodoc-test-*")
	if err != nil {
		t.Fatalf("failed to create temp dir: %v", err)
	}
	defer os.RemoveAll(tmpDir)

	// Write main file
	mainFile := filepath.Join(tmpDir, "main.go")
	mainContent := `package main

func Main() {}
`
	if err := os.WriteFile(mainFile, []byte(mainContent), 0644); err != nil {
		t.Fatalf("failed to write main file: %v", err)
	}

	// Write test file
	testFile := filepath.Join(tmpDir, "main_test.go")
	testContent := `package main

func TestMain() {}
`
	if err := os.WriteFile(testFile, []byte(testContent), 0644); err != nil {
		t.Fatalf("failed to write test file: %v", err)
	}

	// Parse with tests
	opts := DefaultOptions()
	opts.IncludeTests = true

	p := New(opts)
	pkg, err := p.ParsePackage(tmpDir)
	if err != nil {
		t.Fatalf("ParsePackage failed: %v", err)
	}

	// Should include test files
	hasTestFile := false
	for _, f := range pkg.Files {
		if f.IsTestFile() {
			hasTestFile = true
			break
		}
	}
	if !hasTestFile {
		t.Error("should include test files")
	}
}

func TestParser_ParsePackage_InvalidDir(t *testing.T) {
	p := New(DefaultOptions())
	_, err := p.ParsePackage("/nonexistent/path")
	if err == nil {
		t.Error("expected error for nonexistent path")
	}
}

func TestParser_ParsePackage_EmptyDir(t *testing.T) {
	tmpDir, err := os.MkdirTemp("", "gnodoc-test-*")
	if err != nil {
		t.Fatalf("failed to create temp dir: %v", err)
	}
	defer os.RemoveAll(tmpDir)

	p := New(DefaultOptions())
	_, err = p.ParsePackage(tmpDir)
	if err == nil {
		t.Error("expected error for empty directory")
	}
}
