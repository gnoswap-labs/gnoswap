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

func TestParser_ParsePackage_ImportPath(t *testing.T) {
	// This test validates that we can resolve import paths.
	// We use a standard library package that should always exist.
	p := New(DefaultOptions())
	pkg, err := p.ParsePackage("fmt")
	if err != nil {
		t.Skipf("Could not resolve import path 'fmt': %v (might not have Go installed properly)", err)
	}

	if pkg.Name != "fmt" {
		t.Errorf("expected package name 'fmt', got %q", pkg.Name)
	}

	// Should have some functions (like Printf)
	if len(pkg.Funcs) == 0 && len(pkg.Types) == 0 {
		t.Error("expected functions or types in fmt package")
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

func TestParser_ValueSpec_TypeValuePos(t *testing.T) {
	tmpDir, err := os.MkdirTemp("", "gnodoc-test-*")
	if err != nil {
		t.Fatalf("failed to create temp dir: %v", err)
	}
	defer os.RemoveAll(tmpDir)

	// Write file with typed constants and variables
	testFile := filepath.Join(tmpDir, "values.go")
	content := `package values

// TypedConst has an explicit type.
const TypedConst int = 42

// UntypedConst has an inferred type.
const UntypedConst = "hello"

// TypedVar has an explicit type.
var TypedVar float64 = 3.14

// UntypedVar has an inferred type.
var UntypedVar = true
`
	if err := os.WriteFile(testFile, []byte(content), 0644); err != nil {
		t.Fatalf("failed to write test file: %v", err)
	}

	p := New(DefaultOptions())
	pkg, err := p.ParsePackage(tmpDir)
	if err != nil {
		t.Fatalf("ParsePackage failed: %v", err)
	}

	// Check constants
	foundTypedConst := false
	for _, group := range pkg.Consts {
		for _, spec := range group.Specs {
			if spec.Name == "TypedConst" {
				foundTypedConst = true
				if spec.Type != "int" {
					t.Errorf("TypedConst expected type 'int', got %q", spec.Type)
				}
				if spec.Value != "42" {
					t.Errorf("TypedConst expected value '42', got %q", spec.Value)
				}
				if spec.Pos.Line == 0 {
					t.Error("TypedConst expected non-zero line position")
				}
			}
		}
	}
	if !foundTypedConst {
		t.Error("expected TypedConst in constants")
	}

	// Check variables
	foundTypedVar := false
	for _, group := range pkg.Vars {
		for _, spec := range group.Specs {
			if spec.Name == "TypedVar" {
				foundTypedVar = true
				if spec.Type != "float64" {
					t.Errorf("TypedVar expected type 'float64', got %q", spec.Type)
				}
				if spec.Value != "3.14" {
					t.Errorf("TypedVar expected value '3.14', got %q", spec.Value)
				}
				if spec.Pos.Line == 0 {
					t.Error("TypedVar expected non-zero line position")
				}
			}
		}
	}
	if !foundTypedVar {
		t.Error("expected TypedVar in variables")
	}
}

func TestParser_ExcludeFiles(t *testing.T) {
	tmpDir, err := os.MkdirTemp("", "gnodoc-test-*")
	if err != nil {
		t.Fatalf("failed to create temp dir: %v", err)
	}
	defer os.RemoveAll(tmpDir)

	// Write main file
	mainFile := filepath.Join(tmpDir, "main.go")
	mainContent := `package testpkg

// MainFunc is from main.go.
func MainFunc() {}
`
	if err := os.WriteFile(mainFile, []byte(mainContent), 0644); err != nil {
		t.Fatalf("failed to write main file: %v", err)
	}

	// Write generated file (should be excluded)
	genFile := filepath.Join(tmpDir, "generated.go")
	genContent := `package testpkg

// GeneratedFunc is from generated.go.
func GeneratedFunc() {}
`
	if err := os.WriteFile(genFile, []byte(genContent), 0644); err != nil {
		t.Fatalf("failed to write generated file: %v", err)
	}

	// Parse with exclude pattern
	opts := DefaultOptions()
	opts.Exclude = []string{"generated*"}

	p := New(opts)
	pkg, err := p.ParsePackage(tmpDir)
	if err != nil {
		t.Fatalf("ParsePackage failed: %v", err)
	}

	// Should have MainFunc
	foundMain := false
	for _, fn := range pkg.Funcs {
		if fn.Name == "MainFunc" {
			foundMain = true
		}
	}
	if !foundMain {
		t.Error("expected MainFunc in result")
	}

	// Should NOT have GeneratedFunc
	for _, fn := range pkg.Funcs {
		if fn.Name == "GeneratedFunc" {
			t.Error("unexpected GeneratedFunc in result (should be excluded)")
		}
	}
}

func TestParser_ParsePackage_PartialError(t *testing.T) {
	tmpDir, err := os.MkdirTemp("", "gnodoc-test-*")
	if err != nil {
		t.Fatalf("failed to create temp dir: %v", err)
	}
	defer os.RemoveAll(tmpDir)

	// Write valid file
	validFile := filepath.Join(tmpDir, "valid.go")
	validContent := `package testpkg

// Valid is a valid function.
func Valid() {}
`
	if err := os.WriteFile(validFile, []byte(validContent), 0644); err != nil {
		t.Fatalf("failed to write valid file: %v", err)
	}

	// Write invalid file
	invalidFile := filepath.Join(tmpDir, "invalid.go")
	invalidContent := `package testpkg

func Invalid( {
	// syntax error
}
`
	if err := os.WriteFile(invalidFile, []byte(invalidContent), 0644); err != nil {
		t.Fatalf("failed to write invalid file: %v", err)
	}

	// Without IgnoreParseErrors - should fail
	opts := DefaultOptions()
	opts.IgnoreParseErrors = false
	p := New(opts)
	_, err = p.ParsePackage(tmpDir)
	if err == nil {
		t.Error("expected error without IgnoreParseErrors")
	}

	// With IgnoreParseErrors - should succeed with partial result
	opts.IgnoreParseErrors = true
	p = New(opts)
	pkg, err := p.ParsePackage(tmpDir)
	if err != nil {
		t.Fatalf("expected success with IgnoreParseErrors, got: %v", err)
	}

	// Should have the valid function
	foundValid := false
	for _, fn := range pkg.Funcs {
		if fn.Name == "Valid" {
			foundValid = true
			break
		}
	}
	if !foundValid {
		t.Error("expected Valid function in result")
	}

	// Should report partial failure
	if !p.HadParseErrors() {
		t.Error("expected HadParseErrors to return true")
	}
}

func TestParser_ValueSpec_MultipleNamesSingleValue(t *testing.T) {
	tmpDir, err := os.MkdirTemp("", "gnodoc-test-*")
	if err != nil {
		t.Fatalf("failed to create temp dir: %v", err)
	}
	defer os.RemoveAll(tmpDir)

	testFile := filepath.Join(tmpDir, "multi.go")
	content := `package multi

const (
	A, B = 1
)

var (
	X, Y = 2
)
`
	if err := os.WriteFile(testFile, []byte(content), 0644); err != nil {
		t.Fatalf("failed to write test file: %v", err)
	}

	p := New(DefaultOptions())
	pkg, err := p.ParsePackage(tmpDir)
	if err != nil {
		t.Fatalf("ParsePackage failed: %v", err)
	}

	wantConst := map[string]string{"A": "1", "B": "1"}
	for _, group := range pkg.Consts {
		for _, spec := range group.Specs {
			if want, ok := wantConst[spec.Name]; ok {
				if spec.Value != want {
					t.Errorf("%s expected value %q, got %q", spec.Name, want, spec.Value)
				}
				delete(wantConst, spec.Name)
			}
		}
	}
	if len(wantConst) > 0 {
		t.Errorf("missing const specs: %v", wantConst)
	}

	wantVar := map[string]string{"X": "2", "Y": "2"}
	for _, group := range pkg.Vars {
		for _, spec := range group.Specs {
			if want, ok := wantVar[spec.Name]; ok {
				if spec.Value != want {
					t.Errorf("%s expected value %q, got %q", spec.Name, want, spec.Value)
				}
				delete(wantVar, spec.Name)
			}
		}
	}
	if len(wantVar) > 0 {
		t.Errorf("missing var specs: %v", wantVar)
	}
}

func TestParser_ModuleRoot_RelativePath(t *testing.T) {
	tmpDir, err := os.MkdirTemp("", "gnodoc-test-*")
	if err != nil {
		t.Fatalf("failed to create temp dir: %v", err)
	}
	defer os.RemoveAll(tmpDir)

	pkgDir := filepath.Join(tmpDir, "subpkg")
	if err := os.MkdirAll(pkgDir, 0755); err != nil {
		t.Fatalf("failed to create package dir: %v", err)
	}

	testFile := filepath.Join(pkgDir, "foo.go")
	content := `package subpkg

// Hello says hi.
func Hello() {}
`
	if err := os.WriteFile(testFile, []byte(content), 0644); err != nil {
		t.Fatalf("failed to write test file: %v", err)
	}

	opts := DefaultOptions()
	opts.ModuleRoot = tmpDir

	p := New(opts)
	pkg, err := p.ParsePackage("subpkg")
	if err != nil {
		t.Fatalf("ParsePackage failed: %v", err)
	}

	if pkg.Name != "subpkg" {
		t.Errorf("expected package name 'subpkg', got %q", pkg.Name)
	}

	if len(pkg.Funcs) == 0 {
		t.Fatal("expected functions in package")
	}

	got := pkg.Funcs[0].Pos.Filename
	want := filepath.ToSlash(filepath.Join("subpkg", "foo.go"))
	if got != want {
		t.Errorf("expected relative filename %q, got %q", want, got)
	}
}
