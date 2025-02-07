package scriptgen

import (
	"os"
	"path/filepath"
	"strings"
	"testing"
)

func TestDerivePackagePath(t *testing.T) {
	// create temporary directory and create dummy gno.mod file and gno file inside
	tempDir, err := os.MkdirTemp("", "test")
	if err != nil {
		t.Fatal(err)
	}
	defer os.RemoveAll(tempDir)

	// write dummy gno.mod file (example: module gno.land/p/dummymodule)
	modContent := "module gno.land/p/dummymodule"
	modPath := filepath.Join(tempDir, "gno.mod")
	if err := os.WriteFile(modPath, []byte(modContent), 0o644); err != nil {
		t.Fatal(err)
	}

	// create dummy gno file in sub directory
	subDir := filepath.Join(tempDir, "sub")
	if err := os.Mkdir(subDir, 0o755); err != nil {
		t.Fatal(err)
	}
	dummyFilePath := filepath.Join(subDir, "dummy.gno")
	dummyContent := "package dummy\n\nfunc Dummy() {}\n"
	if err := os.WriteFile(dummyFilePath, []byte(dummyContent), 0o644); err != nil {
		t.Fatal(err)
	}

	pkgPath, err := DerivePackagePath(dummyFilePath)
	if err != nil {
		t.Fatalf("Expected no error, got %v", err)
	}
	expected := "gno.land/p/dummymodule"
	if pkgPath != expected {
		t.Fatalf("Expected package path %s, got %s", expected, pkgPath)
	}
}

func TestFallbackDerivePackagePath(t *testing.T) {
	// "some/path/contract/p/dummymodule/somefile.gno" → "gno.land/p/dummymodule"
	testPath := filepath.Join("some", "path", "contract", "p", "dummymodule", "somefile.gno")
	got := FallbackDerivePackagePath(testPath)
	expected := "gno.land/p/dummymodule"
	if got != expected {
		t.Errorf("FallbackDerivePackagePath(%q) = %q; want %q", testPath, got, expected)
	}

	// if contract is not found, pkgType is empty string and "gno.land/" is returned
	testPath2 := filepath.Join("some", "other", "path", "file.gno")
	got2 := FallbackDerivePackagePath(testPath2)
	expected2 := "gno.land/"
	if got2 != expected2 {
		t.Errorf("FallbackDerivePackagePath(%q) = %q; want %q", testPath2, got2, expected2)
	}
}

func TestGetDefaultArg(t *testing.T) {
	tests := []struct {
		typ      string
		expected string
	}{
		{"string", "\"\""},
		{"int", "0"},
		{"bool", "false"},
		{"std.Address", "\"g1defaultaddress000000000000000000000000\""},
		{"unknownType", "\"<default>\""},
	}

	for _, tt := range tests {
		result := GetDefaultArg(tt.typ)
		if result != tt.expected {
			t.Errorf("For type %s, expected %s, got %s", tt.typ, tt.expected, result)
		}
	}
}

func TestProcessFile(t *testing.T) {
	tempDir, err := os.MkdirTemp("", "processfile_test")
	if err != nil {
		t.Fatal(err)
	}
	defer os.RemoveAll(tempDir)

	modContent := "module gno.land/p/dummymodule"
	modPath := filepath.Join(tempDir, "gno.mod")
	if err := os.WriteFile(modPath, []byte(modContent), 0o644); err != nil {
		t.Fatal(err)
	}

	contractDir := filepath.Join(tempDir, "contract", "p", "dummymodule")
	if err := os.MkdirAll(contractDir, 0o755); err != nil {
		t.Fatal(err)
	}

	dummyFilePath := filepath.Join(contractDir, "dummy.gno")
	dummyContent := `package dummy

import "std"

func Hello(name string, addr std.Address) {}
`
	if err := os.WriteFile(dummyFilePath, []byte(dummyContent), 0o644); err != nil {
		t.Fatal(err)
	}

	cmds, err := ProcessFile(dummyFilePath)
	if err != nil {
		t.Fatalf("ProcessFile failed: %v", err)
	}

	// Construct expected command string
	// Package path should be "gno.land/p/dummymodule" as read
	// from the module declaration in gno.mod via DerivePackagePath
	expectedPkgPath := "gno.land/p/dummymodule"
	expectedFuncName := "Hello"
	// Arguments: first arg is string → `""`, second is std.Address → `"g1defaultaddress000000000000000000000000"`
	expectedArgs := []string{"\"\"", "\"g1defaultaddress000000000000000000000000\""}
	expectedCmd := "gnokey maketx call -pkgpath " + expectedPkgPath +
		" -func " + expectedFuncName
	for _, arg := range expectedArgs {
		expectedCmd += " -args " + arg
	}
	expectedCmd += " -gas-fee 1ugnot -gas-wanted 3000000000 -broadcast -chainid=tendermint_test test1"

	found := false
	for _, cmd := range cmds {
		if strings.TrimSpace(cmd) == strings.TrimSpace(expectedCmd) {
			found = true
			break
		}
	}
	if !found {
		t.Errorf("Expected command:\n%s\nGot:\n%v", expectedCmd, cmds)
	}
}
