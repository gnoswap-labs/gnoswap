package txtar

import (
	"os"
	"os/exec"
	"path/filepath"
	"runtime"
	"strings"
	"sync"
	"testing"
	"time"

	"github.com/rogpeppe/go-internal/testscript"
)

// Runner provides functionality to run txtar tests with gno commands
type Runner struct {
	mu sync.RWMutex

	// gnoBinary is the path to the gno binary
	gnoBinary string

	// gnoRoot is the GNOROOT directory
	gnoRoot string

	// buildDir is where to build the gno binary
	buildDir string

	// homeDir is the GNOHOME directory
	homeDir string

	// setupFunc is an optional setup function
	setupFunc func(env *testscript.Env) error

	// envVars are additional environment variables
	envVars map[string]string

	// updateScripts enables updating expected outputs
	updateScripts bool

	// testWork keeps test work directories
	testWork bool

	// buildOnce ensures gno binary is built only once
	buildOnce sync.Once

	// verbose enables verbose output
	verbose bool
}

// Option is a functional option for configuring the Runner
type Option func(*Runner)

// New creates a new Runner with the given options
func New(opts ...Option) *Runner {
	r := &Runner{
		envVars: make(map[string]string),
	}

	for _, opt := range opts {
		opt(r)
	}

	return r
}

// WithGnoBinary sets the path to a pre-built gno binary
func WithGnoBinary(path string) Option {
	return func(r *Runner) {
		r.gnoBinary = path
	}
}

// WithGnoRoot sets the GNOROOT directory
func WithGnoRoot(path string) Option {
	return func(r *Runner) {
		r.gnoRoot = path
	}
}

// WithBuildDir sets the directory for building gno binary
func WithBuildDir(path string) Option {
	return func(r *Runner) {
		r.buildDir = path
	}
}

// WithHomeDir sets the GNOHOME directory
func WithHomeDir(path string) Option {
	return func(r *Runner) {
		r.homeDir = path
	}
}

// WithSetup sets a custom setup function
func WithSetup(setup func(env *testscript.Env) error) Option {
	return func(r *Runner) {
		r.setupFunc = setup
	}
}

// WithEnv sets additional environment variables
func WithEnv(key, value string) Option {
	return func(r *Runner) {
		r.envVars[key] = value
	}
}

// WithUpdateScripts enables updating expected outputs
func WithUpdateScripts(update bool) Option {
	return func(r *Runner) {
		r.updateScripts = update
	}
}

// WithTestWork keeps test work directories
func WithTestWork(keep bool) Option {
	return func(r *Runner) {
		r.testWork = keep
	}
}

// WithVerbose enables verbose output
func WithVerbose(verbose bool) Option {
	return func(r *Runner) {
		r.verbose = verbose
	}
}

// Run executes all txtar tests in the given directory
func (r *Runner) Run(t *testing.T, testDir string) {
	t.Helper()

	// Ensure test directory exists
	if _, err := os.Stat(testDir); os.IsNotExist(err) {
		t.Skipf("test directory %q does not exist", testDir)
		return
	}

	// Setup directories
	if r.homeDir == "" {
		r.homeDir = t.TempDir()
	}
	if r.buildDir == "" {
		r.buildDir = t.TempDir()
	}

	// Build or verify gno binary
	r.ensureGnoBinary(t)

	// Create testscript params
	p := testscript.Params{
		Dir:           testDir,
		UpdateScripts: r.updateScripts,
		TestWork:      r.testWork,
		Cmds:          make(map[string]func(ts *testscript.TestScript, neg bool, args []string)),
	}

	// Setup environment
	p.Setup = func(env *testscript.Env) error {
		// Set PATH to include gno binary
		binDir := filepath.Dir(r.gnoBinary)
		path := env.Getenv("PATH")
		if path == "" {
			path = binDir
		} else {
			path = binDir + string(os.PathListSeparator) + path
		}
		env.Setenv("PATH", path)

		// Set GNOHOME
		env.Setenv("GNOHOME", r.homeDir)

		// Set GNOROOT if available
		if r.gnoRoot != "" {
			env.Setenv("GNOROOT", r.gnoRoot)
		} else if gnoRoot := r.findGnoRoot(); gnoRoot != "" {
			env.Setenv("GNOROOT", gnoRoot)
		}

		// Set additional environment variables
		for k, v := range r.envVars {
			env.Setenv(k, v)
		}

		// Call custom setup if provided
		if r.setupFunc != nil {
			return r.setupFunc(env)
		}

		return nil
	}

	// Register gno command
	p.Cmds["gno"] = func(ts *testscript.TestScript, neg bool, args []string) {
		if r.verbose {
			ts.Logf("executing: gno %s", strings.Join(args, " "))
		}

		err := ts.Exec(r.gnoBinary, args...)
		if err != nil {
			ts.Logf("gno command error: %v", err)
		}

		success := err == nil
		if success == neg {
			ts.Fatalf("unexpected gno command result")
		}
	}

	// Register env command for checking environment variables
	p.Cmds["env"] = func(ts *testscript.TestScript, neg bool, args []string) {
		if len(args) == 0 {
			ts.Fatalf("env: missing variable name")
		}

		varName := args[0]
		value := ts.Getenv(varName)

		if len(args) == 1 {
			// Just check if variable is set
			exists := value != ""
			if exists == neg {
				if neg {
					ts.Fatalf("env variable %q is set but should not be", varName)
				} else {
					ts.Fatalf("env variable %q is not set", varName)
				}
			}
		} else if len(args) == 2 {
			// Check if variable has specific value
			expected := args[1]
			matches := value == expected
			if matches == neg {
				if neg {
					ts.Fatalf("env variable %q has value %q but should not", varName, value)
				} else {
					ts.Fatalf("env variable %q has value %q, expected %q", varName, value, expected)
				}
			}
		} else {
			ts.Fatalf("env: too many arguments")
		}
	}

	// Run tests
	testscript.Run(t, p)
}

// RunFiles runs specific txtar files
func (r *Runner) RunFiles(t *testing.T, files ...string) {
	t.Helper()

	for _, file := range files {
		name := filepath.Base(file)
		t.Run(name, func(t *testing.T) {
			// Create a temporary directory with just this file
			tmpDir := t.TempDir()
			content, err := os.ReadFile(file)
			if err != nil {
				t.Fatalf("failed to read file %s: %v", file, err)
			}

			tmpFile := filepath.Join(tmpDir, name)
			if err := os.WriteFile(tmpFile, content, 0o644); err != nil {
				t.Fatalf("failed to write temp file: %v", err)
			}

			r.Run(t, tmpDir)
		})
	}
}

// ensureGnoBinary ensures that a gno binary is available
func (r *Runner) ensureGnoBinary(t *testing.T) {
	t.Helper()

	if r.gnoBinary != "" {
		// Verify the binary exists
		if _, err := os.Stat(r.gnoBinary); err == nil {
			return
		}
		t.Logf("specified gno binary %q not found, will build one", r.gnoBinary)
	}

	// Build gno binary once
	var buildErr error
	r.buildOnce.Do(func() {
		buildErr = r.buildGnoBinary(t)
	})
	if buildErr != nil {
		t.Fatal(buildErr)
	}
}

// buildGnoBinary builds the gno binary
func (r *Runner) buildGnoBinary(t *testing.T) error {
	t.Helper()

	gnoBin := filepath.Join(r.buildDir, "gno")
	if runtime.GOOS == "windows" {
		gnoBin += ".exe"
	}

	t.Logf("building gno binary to %s", gnoBin)
	start := time.Now()

	// Try to build from local source first
	if gnoRoot := r.findGnoRoot(); gnoRoot != "" {
		gnoCmd := filepath.Join(gnoRoot, "gnovm", "cmd", "gno")
		if _, err := os.Stat(gnoCmd); err == nil {
			// Build from local source
			// Use absolute path and set working directory to avoid module issues
			cmd := exec.Command("go", "build", "-o", gnoBin, ".")
			cmd.Dir = filepath.Join(gnoRoot, "gnovm", "cmd", "gno")
			cmd.Env = os.Environ()

			if output, err := cmd.CombinedOutput(); err != nil {
				t.Logf("build from source failed: %s", output)
				// Don't return error, fall back to go install
			} else {
				r.gnoBinary = gnoBin
				r.gnoRoot = gnoRoot
				t.Logf("built gno binary from source in %v", time.Since(start))
				return nil
			}
		}
	}

	// Fall back to installing from module
	cmd := exec.Command("go", "install", "-modcacherw", "github.com/gnolang/gno/gnovm/cmd/gno@latest")
	cmd.Env = append(os.Environ(), "GOBIN="+r.buildDir)

	if output, err := cmd.CombinedOutput(); err != nil {
		t.Logf("install output: %s", output)
		return err
	}

	r.gnoBinary = gnoBin
	t.Logf("installed gno binary in %v", time.Since(start))
	return nil
}

// findGnoRoot attempts to find the GNOROOT directory
func (r *Runner) findGnoRoot() string {
	// Check environment variable
	if root := os.Getenv("GNOROOT"); root != "" {
		return root
	}

	// Check if we're in a gno repository
	cwd, err := os.Getwd()
	if err != nil {
		return ""
	}

	// Walk up the directory tree looking for go.mod with module github.com/gnolang/gno
	dir := cwd
	for {
		modFile := filepath.Join(dir, "go.mod")
		if content, err := os.ReadFile(modFile); err == nil {
			if strings.Contains(string(content), "module github.com/gnolang/gno\n") {
				return dir
			}
		}

		parent := filepath.Dir(dir)
		if parent == dir {
			break
		}
		dir = parent
	}

	// Try to find parent directory if we're in a subdirectory
	parent := filepath.Dir(cwd)
	if parent != cwd && parent != "/" {
		modFile := filepath.Join(parent, "go.mod")
		if content, err := os.ReadFile(modFile); err == nil {
			if strings.Contains(string(content), "module github.com/gnolang/gno\n") {
				return parent
			}
		}
	}

	return ""
}
