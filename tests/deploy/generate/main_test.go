package main

import (
	"os"
	"path/filepath"
	"strings"
	"testing"
	"text/template"
)

// setupTestDirectory creates a temporary directory structure for testing
func setupTestDirectory(t *testing.T) string {
	t.Helper()
	tempDir, err := os.MkdirTemp("", "gnoswap-test-*")
	if err != nil {
		t.Fatal(err)
	}

	// Create test directory structure with gno.mod files
	dirs := []string{
		"contract/p/gnoswap/uint256",
		"contract/p/gnoswap/int256",
		"contract/p/gnoswap/gnsmath",
		"contract/r/gnoswap/test_token", // This should not be discovered as a package
		"contract/r/gnoswap/test_token/usdc",
		"contract/r/gnoswap/test_token/foo",
		"contract/r/gnoswap/gns",
		"contract/r/gnoswap/gnft",
		"contract/r/gnoswap/pool",
		"contract/r/gnoswap/router",
	}

	for _, dir := range dirs {
		err := os.MkdirAll(filepath.Join(tempDir, dir), 0o755)
		if err != nil {
			t.Fatal(err)
		}

		// Only create gno.mod in actual package directories
		if dir != "contract/r/gnoswap/test_token" {
			err = os.WriteFile(filepath.Join(tempDir, dir, "gno.mod"), []byte("module test"), 0o644)
			if err != nil {
				t.Fatal(err)
			}
		}
	}

	return tempDir
}

// cleanupTestDirectory removes the temporary test directory
func cleanupTestDirectory(t *testing.T, dir string) {
	t.Helper()
	err := os.RemoveAll(dir)
	if err != nil {
		t.Fatal(err)
	}
}

func TestPackageDiscovery(t *testing.T) {
	// Save original working directory
	originalDir, err := os.Getwd()
	if err != nil {
		t.Fatal(err)
	}
	defer os.Chdir(originalDir)

	testDir := setupTestDirectory(t)
	defer cleanupTestDirectory(t, testDir)

	// Change to test directory
	err = os.Chdir(testDir)
	if err != nil {
		t.Fatal(err)
	}

	packages, err := discoverPackages()
	if err != nil {
		t.Fatal(err)
	}

	// Verify discovered packages
	expectedPackages := map[string]bool{
		"uint256": false,
		"int256":  false,
		"gnsmath": false,
		"usdc":    false,
		"foo":     false,
		"gns":     false,
		"gnft":    false,
		"pool":    false,
		"router":  false,
	}

	for _, pkg := range packages {
		if _, exists := expectedPackages[pkg.Name]; !exists {
			t.Errorf("Unexpected package discovered: %s", pkg.Name)
		}
		expectedPackages[pkg.Name] = true
	}

	for pkgName, found := range expectedPackages {
		if !found {
			t.Errorf("Expected package not discovered: %s", pkgName)
		}
	}
}

func TestInvalidDirectory(t *testing.T) {
	originalDir, err := os.Getwd()
	if err != nil {
		t.Fatal(err)
	}
	defer os.Chdir(originalDir)

	testDir := setupTestDirectory(t)
	defer cleanupTestDirectory(t, testDir)

	// Create an invalid directory without gno.mod
	invalidDir := filepath.Join(testDir, "contract/p/gnoswap/invalid")
	err = os.MkdirAll(invalidDir, 0o755)
	if err != nil {
		t.Fatal(err)
	}

	err = os.Chdir(testDir)
	if err != nil {
		t.Fatal(err)
	}

	packages, err := discoverPackages()
	if err != nil {
		t.Fatal(err)
	}

	// check that invalid directory was not discovered
	for _, pkg := range packages {
		if pkg.Name == "invalid" {
			t.Error("Invalid directory without gno.mod was incorrectly discovered as a package")
		}
	}
}

func TestTemplateGeneration(t *testing.T) {
	testPackage := Package{
		Name:    "test",
		Path:    "p/gnoswap/test",
		PkgPath: "gno.land/p/gnoswap/test",
		IsRealm: false,
	}

	tmpl := template.Must(template.New("deploy").Parse(deployTemplate))
	var result strings.Builder
	err := tmpl.Execute(&result, testPackage)
	if err != nil {
		t.Fatal(err)
	}

	expected := `deploy-test:
	$(info ************ deploy test ************)
	@echo "" | gnokey maketx addpkg -pkgdir $(ROOT_DIR)/contract/p/gnoswap/test -pkgpath gno.land/p/gnoswap/test -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 100000000ugnot -gas-wanted 100000000 -memo "" gnoswap_admin
	@echo

`

	if result.String() != expected {
		t.Errorf("Template generation failed.\nExpected:\n%s\nGot:\n%s", expected, result.String())
	}
}

func TestPackageCategories(t *testing.T) {
	packages := []Package{
		{Name: "usdc", Path: "r/gnoswap/test_token/usdc", IsRealm: true},
		{Name: "uint256", Path: "p/gnoswap/uint256", IsRealm: false},
		{Name: "gns", Path: "r/gnoswap/gns", IsRealm: true},
		{Name: "pool", Path: "r/gnoswap/pool", IsRealm: true},
	}

	var testTokens []string
	var libraries []string
	var baseTokens []string
	var gnoswapRealms []string

	for _, pkg := range packages {
		deployName := "deploy-" + pkg.Name

		if strings.HasPrefix(pkg.Path, "r/gnoswap/test_token/") {
			testTokens = append(testTokens, deployName)
		} else if !pkg.IsRealm {
			libraries = append(libraries, deployName)
		} else if pkg.Name == "gns" || pkg.Name == "gnft" {
			baseTokens = append(baseTokens, deployName)
		} else if pkg.IsRealm {
			gnoswapRealms = append(gnoswapRealms, deployName)
		}
	}

	// Verify categorization
	if len(testTokens) != 1 || testTokens[0] != "deploy-usdc" {
		t.Error("Test token categorization failed")
	}
	if len(libraries) != 1 || libraries[0] != "deploy-uint256" {
		t.Error("Library categorization failed")
	}
	if len(baseTokens) != 1 || baseTokens[0] != "deploy-gns" {
		t.Error("Base token categorization failed")
	}
	if len(gnoswapRealms) != 1 || gnoswapRealms[0] != "deploy-pool" {
		t.Error("Gnoswap realm categorization failed")
	}
}

func TestEmptyDirectory(t *testing.T) {
	originalDir, err := os.Getwd()
	if err != nil {
		t.Fatal(err)
	}
	defer os.Chdir(originalDir)

	testDir := setupTestDirectory(t)
	defer cleanupTestDirectory(t, testDir)

	// remove all contents but keep the root directories
	dirsToEmpty := []string{"contract/p/gnoswap", "contract/r/gnoswap"}
	for _, dir := range dirsToEmpty {
		entries, err := os.ReadDir(filepath.Join(testDir, dir))
		if err != nil {
			t.Fatal(err)
		}
		for _, entry := range entries {
			err = os.RemoveAll(filepath.Join(testDir, dir, entry.Name()))
			if err != nil {
				t.Fatal(err)
			}
		}
	}

	// change to test directory
	err = os.Chdir(testDir)
	if err != nil {
		t.Fatal(err)
	}

	packages, err := discoverPackages()
	if err != nil {
		t.Fatal(err)
	}

	if len(packages) != 0 {
		t.Error("Expected no packages in empty directory")
	}
}
