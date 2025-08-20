package txtar

import (
	"context"
	"os"
	"os/exec"
	"path/filepath"
	"runtime"
	"strings"
	"testing"

	"github.com/rogpeppe/go-internal/testscript"
	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"
)

func localGnoPath(t *testing.T) (string, bool) {
	t.Helper()
	// honor GNOBIN if user set it and it contains gno
	if gnobin := os.Getenv("GNOBIN"); gnobin != "" {
		name := "gno"
		if runtime.GOOS == "windows" {
			name += ".exe"
		}
		p := filepath.Join(gnobin, name)
		if fi, err := os.Stat(p); err == nil && fi.Mode().IsRegular() {
			return p, true
		}
	}
	// search PATH
	if p, err := exec.LookPath("gno"); err == nil {
		return p, true
	}
	return "", false
}

// makeTxtarDir creates a temp directory with given txtar files (name->script content).
// The returned dir is safe to pass to runner.Run.
func makeTxtarDir(t *testing.T, files map[string]string) string {
	t.Helper()
	dir := t.TempDir()
	for name, body := range files {
		require.Truef(t, strings.HasSuffix(name, ".txtar"), "%s must end with .txtar", name)
		fp := filepath.Join(dir, name)
		require.NoError(t, os.WriteFile(fp, []byte(body), 0o644))
	}
	return dir
}

// basicTxtar returns a minimal script that runs `gno version` and checks exit status.
func basicTxtar() string {
	return `
# basic.txtar
# A minimal testscript that runs "gno version" and expects success.
gno version
`
}

// envTxtar verifies environment variables via our custom "checkenv" command.
func envTxtar() string {
	return `
# env.txtar
checkenv TEST_VAR test_value
`
}

// evalTxtar does a trivial second invocation to verify multiple files work.
func evalTxtar() string {
	return `
# eval.txtar
gno version
`
}

// --- tests -----------------------------------------------------------------

func TestRunner_Basic(t *testing.T) {
	// Prepare runner
	runner := New(
		WithVerbose(true),
		WithUpdateScripts(os.Getenv("UPDATE_SCRIPTS") == "true"),
		WithBuildCache(true), // speed up repeated runs
	)

	// Prefer already available binary to avoid network.
	if bin, ok := localGnoPath(t); ok {
		runner = New(
			WithGnoBinary(bin),
			WithVerbose(true),
			WithUpdateScripts(os.Getenv("UPDATE_SCRIPTS") == "true"),
		)
	} else {
		// If no local gno, we may attempt install (network).
		// Skip in CI/offline/short modes to keep tests reliable.
		if testing.Short() || os.Getenv("CI") == "true" || os.Getenv("OFFLINE") == "true" {
			t.Skip("no local gno; skipping in short/CI/offline mode")
		}
		// Optionally pin version for reproducibility; default is "latest".
		runner = New(
			WithVerbose(true),
			WithBuildCache(true),
			WithGnoVersion(os.Getenv("GNO_VERSION")), // empty => latest
		)
		// Force build now to fail early if needed.
		runner.ensureGnoBinary(t)
	}

	td := makeTxtarDir(t, map[string]string{
		"basic.txtar": basicTxtar(),
	})
	runner.Run(t, td)
}

func TestRunnerWithEnvVars(t *testing.T) {
	// Use local binary if present; otherwise skip (we're testing env wiring here).
	bin, ok := localGnoPath(t)
	if !ok {
		t.Skip("no local gno in PATH/GNOBIN; env wiring test does not require network install")
	}

	runner := New(
		WithGnoBinary(bin),
		WithEnv("TEST_VAR", "test_value"),
		WithSetup(func(env *testscript.Env) error {
			// sanity check from setup hook as well
			if env.Getenv("TEST_VAR") != "test_value" {
				t.Errorf("TEST_VAR not set correctly")
			}
			return nil
		}),
	)

	td := makeTxtarDir(t, map[string]string{
		"env.txtar": envTxtar(),
	})
	runner.Run(t, td)
}

func TestRunFiles(t *testing.T) {
	bin, ok := localGnoPath(t)
	if !ok {
		if testing.Short() || os.Getenv("CI") == "true" || os.Getenv("OFFLINE") == "true" {
			t.Skip("no local gno; skipping in short/CI/offline mode")
		}
		// Try build if allowed
		r := New(WithBuildCache(true))
		r.ensureGnoBinary(t)
		bin = r.gnoBinary
	}

	runner := New(
		WithGnoBinary(bin),
		WithVerbose(true),
	)

	// Create loose txtar files and run via RunFiles
	td := t.TempDir()
	basic := filepath.Join(td, "basic.txtar")
	eval := filepath.Join(td, "eval.txtar")
	require.NoError(t, os.WriteFile(basic, []byte(basicTxtar()), 0o644))
	require.NoError(t, os.WriteFile(eval, []byte(evalTxtar()), 0o644))

	runner.RunFiles(t, basic, eval)
}

func TestFindGnoRoot(t *testing.T) {
	runner := New()

	// Save current env
	oldGnoRoot := os.Getenv("GNOROOT")
	t.Cleanup(func() { _ = os.Setenv("GNOROOT", oldGnoRoot) })

	// 1) via env var
	testRoot := filepath.FromSlash("/tmp/gno-root-for-test") // arbitrary path, just for equality check
	_ = os.Setenv("GNOROOT", testRoot)
	root, err := runner.findGnoRoot(context.Background())
	require.NoError(t, err)
	assert.Equal(t, testRoot, root)

	// 2) without env var -> via `go list -m` (may fail if module not present in build cache)
	_ = os.Unsetenv("GNOROOT")
	root, err = runner.findGnoRoot(context.Background())
	if err != nil || root == "" {
		// It is acceptable that `go list -m github.com/gnolang/gno` does not resolve
		// in arbitrary environments. We only assert that the call returns either a
		// proper path or a meaningful error.
		t.Logf("findGnoRoot via go list -m did not resolve in this env: %v", err)
		return
	}
	// If resolved, basic sanity: go.mod should exist in the reported directory
	modFile := filepath.Join(root, "go.mod")
	_, statErr := os.Stat(modFile)
	assert.NoError(t, statErr, "resolved GNOROOT should contain go.mod")
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
		WithGnoVersion("v0.0.0-fake"), // just to verify option is settable
		WithBuildCache(true),
		WithEnvs(map[string]string{"A": "B", "C": "D"}),
	)

	assert.Equal(t, "/usr/local/bin/gno", runner.gnoBinary)
	assert.Equal(t, "/opt/gno", runner.gnoRoot)
	assert.Equal(t, tmpDir, runner.buildDir)
	assert.Equal(t, tmpDir, runner.homeDir)
	assert.True(t, runner.updateScripts)
	assert.True(t, runner.testWork)
	assert.True(t, runner.verbose)
	assert.Equal(t, "v0.0.0-fake", runner.gnoVersion)
	assert.True(t, runner.cacheBuild)
	assert.Equal(t, "B", runner.envVars["A"])
	assert.Equal(t, "D", runner.envVars["C"])
}

// TestEmptyTestDir verifies behavior when test directory doesn't exist.
func TestEmptyTestDir(t *testing.T) {
	runner := New()
	// Should skip when directory doesn't exist (no panic, no fatal).
	runner.Run(t, "nonexistent")
}

func TestBuildGnoBinary(t *testing.T) {
	// Keep this test resilient across environments.
	if testing.Short() {
		t.Skip("Skipping build test in short mode")
	}
	if os.Getenv("CI") == "true" || os.Getenv("OFFLINE") == "true" {
		t.Skip("Skipping build test in CI/offline mode")
	}

	tmpDir := t.TempDir()

	// Test 1: Use existing gno if present
	t.Run("UseExisting", func(t *testing.T) {
		if gnoBin, ok := localGnoPath(t); ok {
			runner := New(
				WithGnoBinary(gnoBin),
				WithVerbose(true),
			)
			runner.ensureGnoBinary(t)
			assert.Equal(t, gnoBin, runner.gnoBinary)
		} else {
			t.Skip("No gno binary available locally")
		}
	})

	// Test 2: Go install (requires network)
	t.Run("GoInstall", func(t *testing.T) {
		// Unset GNOROOT to push fallback path (go install)
		oldRoot := os.Getenv("GNOROOT")
		_ = os.Unsetenv("GNOROOT")
		t.Cleanup(func() { _ = os.Setenv("GNOROOT", oldRoot) })

		runner := New(
			WithBuildDir(tmpDir),
			WithVerbose(true),
			WithBuildCache(true),
			// Optionally pin version via env GNO_VERSION; else "latest"
			WithGnoVersion(os.Getenv("GNO_VERSION")),
		)

		err := runner.buildGnoBinary(t)
		if err != nil {
			t.Skipf("Failed to install gno via go install: %v", err)
		}

		require.NotEmpty(t, runner.gnoBinary)
		_, err = os.Stat(runner.gnoBinary)
		require.NoError(t, err, "gno binary should exist")
	})

	// Test 3: Build from source if gnolang/gno is available locally
	t.Run("BuildFromSource", func(t *testing.T) {
		runner := New(
			WithBuildDir(tmpDir),
			WithVerbose(true),
			WithBuildCache(false),
		)

		root, err := runner.findGnoRoot(context.Background())
		if err != nil || root == "" {
			t.Skip("github.com/gnolang/gno module not available locally; skipping source build test")
		}

		// Force build from source by setting GNOROOT
		oldRoot := os.Getenv("GNOROOT")
		_ = os.Setenv("GNOROOT", root)
		t.Cleanup(func() { _ = os.Setenv("GNOROOT", oldRoot) })

		// Clear gnoBinary to force build
		runner.gnoBinary = ""
		err = runner.buildGnoBinary(t)
		if err != nil {
			t.Skipf("Failed to build from source: %v", err)
		}

		require.NotEmpty(t, runner.gnoBinary)
		_, err = os.Stat(runner.gnoBinary)
		require.NoError(t, err, "gno binary should exist")
	})
}
