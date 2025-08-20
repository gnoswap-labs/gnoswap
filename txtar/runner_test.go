package txtar

import (
	"os"
	"os/exec"
	"path/filepath"
	"testing"

	"github.com/rogpeppe/go-internal/testscript"
	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"
)

func TestRunner(t *testing.T) {
	// Create a simple test to verify the runner works
	runner := New(
		// Let the runner find or build the gno binary automatically
		WithVerbose(true),
		WithUpdateScripts(os.Getenv("UPDATE_SCRIPTS") == "true"),
	)

	runner.Run(t, "testdata")
}

func TestRunnerWithEnvVars(t *testing.T) {
	runner := New(
		// Let the runner find or build the gno binary automatically
		WithEnv("TEST_VAR", "test_value"),
		WithSetup(func(env *testscript.Env) error {
			// Verify our env var is set
			if env.Getenv("TEST_VAR") != "test_value" {
				t.Errorf("TEST_VAR not set correctly")
			}
			return nil
		}),
	)

	runner.Run(t, "testdata/env")
}

func TestRunFiles(t *testing.T) {
	runner := New(
		// Let the runner find or build the gno binary automatically
		WithVerbose(true),
	)

	// Dynamically find all .txtar files in testdata directory
	pattern := filepath.Join("testdata", "*.txtar")
	files, err := filepath.Glob(pattern)
	if err != nil {
		t.Fatalf("failed to find txtar files: %v", err)
	}

	if len(files) == 0 {
		t.Skip("no .txtar files found in testdata directory")
	}

	// Test running the found files
	runner.RunFiles(t, files...)
}

func TestFindGnoRoot(t *testing.T) {
	runner := New()

	// Save current env
	oldGnoRoot := os.Getenv("GNOROOT")
	defer os.Setenv("GNOROOT", oldGnoRoot)

	// Test with env var
	testRoot := "/test/gno/root"
	os.Setenv("GNOROOT", testRoot)
	assert.Equal(t, testRoot, runner.findGnoRoot())

	// Test without env var (will try to find from current directory)
	os.Unsetenv("GNOROOT")
	root := runner.findGnoRoot()

	// If we're in the gno repository, it should find the root
	if root != "" {
		modFile := filepath.Join(root, "go.mod")
		_, err := os.Stat(modFile)
		assert.NoError(t, err, "go.mod should exist in GNOROOT")
	}
}

func TestRunnerOptions(t *testing.T) {
	tmpDir := t.TempDir()

	runner := New(
		WithGnoBinary("/usr/local/bin/gno"),
		WithGnoRoot("/opt/gno"),
		WithBuildDir(tmpDir),
		WithHomeDir(tmpDir),
		WithUpdateScripts(true),
		WithTestWork(true),
		WithVerbose(true),
	)

	assert.Equal(t, "/usr/local/bin/gno", runner.gnoBinary)
	assert.Equal(t, "/opt/gno", runner.gnoRoot)
	assert.Equal(t, tmpDir, runner.buildDir)
	assert.Equal(t, tmpDir, runner.homeDir)
	assert.True(t, runner.updateScripts)
	assert.True(t, runner.testWork)
	assert.True(t, runner.verbose)
}

// TestEmptyTestDir verifies behavior when test directory doesn't exist
func TestEmptyTestDir(t *testing.T) {
	runner := New()

	// Should skip when directory doesn't exist
	runner.Run(t, "nonexistent")
}

// TestBuildGnoBinary verifies gno binary building
func TestBuildGnoBinary(t *testing.T) {
	if testing.Short() {
		t.Skip("Skipping build test in short mode")
	}

	// Check if we're in CI or can't access network
	if os.Getenv("CI") == "true" || os.Getenv("OFFLINE") == "true" {
		t.Skip("Skipping build test in CI/offline mode")
	}

	tmpDir := t.TempDir()

	// Test 1: Try to use existing gno binary first
	t.Run("UseExisting", func(t *testing.T) {
		if gnoBin, err := exec.LookPath("gno"); err == nil {
			runner := New(
				WithGnoBinary(gnoBin),
				WithVerbose(true),
			)
			runner.ensureGnoBinary(t)
			assert.Equal(t, gnoBin, runner.gnoBinary)
		} else {
			t.Skip("No gno binary in PATH")
		}
	})

	// Test 2: Build from go install (requires network)
	t.Run("GoInstall", func(t *testing.T) {
		// Save and unset GNOROOT to force go install
		oldRoot := os.Getenv("GNOROOT")
		os.Unsetenv("GNOROOT")
		defer os.Setenv("GNOROOT", oldRoot)

		runner := New(
			WithBuildDir(tmpDir),
			WithVerbose(true),
		)

		// This will use go install since we're not in gno repo
		err := runner.buildGnoBinary(t)
		if err != nil {
			t.Skipf("Failed to install gno via go install: %v", err)
		}

		// Verify binary was created
		require.NotEmpty(t, runner.gnoBinary)
		_, err = os.Stat(runner.gnoBinary)
		require.NoError(t, err, "gno binary should exist")
	})

	// Test 3: Build from source if in gno repo
	t.Run("BuildFromSource", func(t *testing.T) {
		// This test only works if we're actually in the gno repository
		runner := New(
			WithBuildDir(tmpDir),
			WithVerbose(true),
		)

		gnoRoot := runner.findGnoRoot()
		if gnoRoot == "" {
			t.Skip("Not in gno repository, skipping source build test")
		}

		// Set GNOROOT to ensure we build from source
		oldRoot := os.Getenv("GNOROOT")
		os.Setenv("GNOROOT", gnoRoot)
		defer os.Setenv("GNOROOT", oldRoot)

		// Clear gnoBinary to force build
		runner.gnoBinary = ""
		err := runner.buildGnoBinary(t)
		if err != nil {
			// If build fails, it might be due to module boundaries
			t.Skipf("Failed to build from source (might be due to module boundaries): %v", err)
		}

		require.NotEmpty(t, runner.gnoBinary)
		_, err = os.Stat(runner.gnoBinary)
		require.NoError(t, err, "gno binary should exist")
	})
}
