package txtar

import (
	"context"
	"fmt"
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

type Runner struct {
	gnoBinary string // gnoBinary is the path to the gno executable
	gnoRoot   string // gnoRoot is the GNOROOT directory (optional; auto-discovered if empty)
	buildDir  string // buildDir is where to place the built/installed gno binary
	homeDir   string // homeDir is the GNOHOME directory

	setupFunc func(env *testscript.Env) error
	envVars   map[string]string

	// flags
	updateScripts bool
	testWork      bool
	verbose       bool

	// build controls
	buildOnce  sync.Once
	gnoVersion string
	cacheBuild bool // cache binary under UserCacheDir for reuse
}

// Option is a functional option for configuring the Runner.
type Option func(*Runner)

func New(opts ...Option) *Runner {
	r := &Runner{envVars: make(map[string]string)}
	for _, opt := range opts {
		opt(r)
	}
	return r
}

func WithGnoBinary(path string) Option {
	return func(r *Runner) {
		r.gnoBinary = path
	}
}

func WithGnoRoot(path string) Option {
	return func(r *Runner) {
		r.gnoRoot = path
	}
}

func WithBuildDir(path string) Option {
	return func(r *Runner) {
		r.buildDir = path
	}
}

func WithHomeDir(path string) Option {
	return func(r *Runner) {
		r.homeDir = path
	}
}

// WithSetup sets a custom setup function.
func WithSetup(setup func(env *testscript.Env) error) Option {
	return func(r *Runner) {
		r.setupFunc = setup
	}
}

// WithEnv sets an additional environment variable (single key/value).
func WithEnv(key, value string) Option {
	return func(r *Runner) {
		r.envVars[key] = value
	}
}

// WithEnvs sets multiple additional environment variables.
func WithEnvs(kv map[string]string) Option {
	return func(r *Runner) {
		for k, v := range kv {
			r.envVars[k] = v
		}
	}
}

// WithUpdateScripts enables updating expected outputs.
func WithUpdateScripts(update bool) Option {
	return func(r *Runner) {
		r.updateScripts = update
	}
}

// WithTestWork keeps test work directories.
func WithTestWork(keep bool) Option {
	return func(r *Runner) {
		r.testWork = keep
	}
}

// WithVerbose enables verbose output.
func WithVerbose(verbose bool) Option {
	return func(r *Runner) {
		r.verbose = verbose
	}
}

// WithGnoVersion pins the gno module version for go install (e.g. "v0.42.0" or "latest").
func WithGnoVersion(version string) Option {
	return func(r *Runner) {
		r.gnoVersion = version
	}
}

// WithBuildCache enables or disables build caching under UserCacheDir.
func WithBuildCache(enable bool) Option {
	return func(r *Runner) {
		r.cacheBuild = enable
	}
}

func (r *Runner) Run(t *testing.T, testDir string) {
	t.Helper()

	// ensure test dir exists
	if fi, err := os.Stat(testDir); err != nil || !fi.IsDir() {
		t.Skipf("test directory %q does not exist or is not a directory", testDir)
		return
	}

	// setup directories
	if r.homeDir == "" {
		r.homeDir = os.TempDir()
	}
	if r.buildDir == "" && !r.cacheBuild {
		r.buildDir = os.TempDir()
	}

	// Build or verify gno binary.
	r.ensureGnoBinary(t)

	// Create testscript params.
	p := testscript.Params{
		Dir:           testDir,
		UpdateScripts: r.updateScripts,
		TestWork:      r.testWork,
		Cmds:          make(map[string]func(ts *testscript.TestScript, neg bool, args []string)),
	}

	// Setup environment for each testscript run.
	p.Setup = func(env *testscript.Env) error {
		// Prepend gno bin dir to PATH so that "exec gno ..." or custom "gno" cmd works.
		binDir := filepath.Dir(r.gnoBinary)
		path := env.Getenv("PATH")
		if path == "" {
			path = binDir
		} else {
			path = binDir + string(os.PathListSeparator) + path
		}
		env.Setenv("PATH", path)

		// Set GNOHOME.
		env.Setenv("GNOHOME", r.homeDir)

		// Set GNOROOT if available (prefer already discovered value).
		if r.gnoRoot != "" {
			env.Setenv("GNOROOT", r.gnoRoot)
		} else {
			// Best effort: discover once more (fast if cached by go tool).
			ctx := withTestDeadline(t)
			if gnoRoot, err := r.findGnoRoot(ctx); err == nil && gnoRoot != "" {
				env.Setenv("GNOROOT", gnoRoot)
			}
		}

		// Additional environment variables.
		for k, v := range r.envVars {
			env.Setenv(k, v)
		}

		// Custom setup hook.
		if r.setupFunc != nil {
			return r.setupFunc(env)
		}

		return nil
	}

	// Register "gno" command so scripts can write `gno ...` (not `exec gno ...`).
	p.Cmds["gno"] = func(ts *testscript.TestScript, neg bool, args []string) {
		if r.verbose {
			ts.Logf("$ gno %s", strings.Join(args, " "))
		}
		err := ts.Exec(r.gnoBinary, args...)
		// neg == true means the command is expected to fail.
		if (err == nil) == neg {
			if neg {
				ts.Fatalf("gno succeeded but failure was expected (args=%q)", args)
			}
			ts.Fatalf("gno failed (args=%q): %v", args, err)
		}
	}

	// Register "checkenv" (avoid clashing with testscript's built-in env handling).
	p.Cmds["checkenv"] = func(ts *testscript.TestScript, neg bool, args []string) {
		if len(args) == 0 {
			ts.Fatalf("checkenv: missing variable name")
		}
		varName := args[0]
		value := ts.Getenv(varName)

		switch len(args) {
		case 1:
			// Just check if variable is set.
			exists := value != ""
			if exists == neg {
				if neg {
					ts.Fatalf("checkenv: %q is set (%q) but should not", varName, value)
				}
				ts.Fatalf("checkenv: %q is not set", varName)
			}
		case 2:
			// Check if variable has specific value.
			expected := args[1]
			matches := value == expected
			if matches == neg {
				if neg {
					ts.Fatalf("checkenv: %q matched %q but should not", varName, value)
				}
				ts.Fatalf("checkenv: %q=%q, want %q", varName, value, expected)
			}
		default:
			ts.Fatalf("checkenv: too many arguments")
		}
	}

	// Run tests.
	testscript.Run(t, p)
}

func (r *Runner) RunFiles(t *testing.T, files ...string) {
	t.Helper()

	for _, file := range files {
		name := filepath.Base(file)
		t.Run(name, func(t *testing.T) {
			temp := t.TempDir()
			content, err := os.ReadFile(file)
			if err != nil {
				t.Fatalf("failed to read file %q: %v", file, err)
			}
			tempFile := filepath.Join(temp, name)
			if err := os.WriteFile(tempFile, content, 0o644); err != nil {
				t.Fatalf("failed to write file %q: %v", tempFile, err)
			}
			r.Run(t, temp)
		})
	}
}

func (r *Runner) ensureGnoBinary(t *testing.T) {
	t.Helper()

	if r.gnoBinary != "" {
		// verify binary exists
		if fi, err := os.Stat(r.gnoBinary); err != nil && fi.Mode().IsRegular() {
			return
		}
		t.Logf("specified gno binary %q does not exist", r.gnoBinary)
	}

	var buildErr error
	r.buildOnce.Do(func() {
		buildErr = r.buildGnoBinary(t)
	})
	if buildErr != nil {
		t.Fatal(buildErr)
	}
}

// buildGnoBinary builds or installs the gno binary.
func (r *Runner) buildGnoBinary(t *testing.T) error {
	t.Helper()

	ctx := withTestDeadline(t)

	version := r.gnoVersion
	if version == "" {
		version = "latest"
	}

	// decide output binary path
	binName := "gno"
	if runtime.GOOS == "windows" {
		binName += ".exe"
	}

	var outBin string
	if r.cacheBuild {
		cacheDir, err := os.UserCacheDir()
		if err != nil {
			return err
		}
		key := fmt.Sprintf(
			"gno-%s-%s-%s-%s",
			version, runtime.GOOS, runtime.GOARCH, strings.TrimSpace(runtime.Version()))
		outDir := filepath.Join(cacheDir, "gnotxtar", key)
		if err := os.MkdirAll(outDir, 0o755); err != nil {
			return err
		}
		outBin = filepath.Join(outDir, binName)
	} else {
		if r.buildDir == "" {
			r.buildDir = os.TempDir()
		}
		if err := os.MkdirAll(r.buildDir, 0o755); err != nil {
			return err
		}
		outBin = filepath.Join(r.buildDir, binName)
	}

	// if already exists, reuse it
	if fi, err := os.Stat(outBin); err == nil && fi.Mode().IsRegular() {
		r.gnoBinary = outBin
		return nil
	}

	start := time.Now()
	t.Logf("building gno binary to %s (version=%s)", outBin, version)

	// Try to build from local source first (fast dev loop).
	if root, err := r.findGnoRoot(ctx); err == nil && root != "" {
		src := filepath.Join(root, "gnovm", "cmd", "gno")
		if st, err := os.Stat(src); err == nil && st.IsDir() {
			cmd := exec.CommandContext(ctx, "go", "build", "-o", outBin, ".")
			cmd.Dir = src
			cmd.Env = os.Environ()
			if output, err := cmd.CombinedOutput(); err == nil {
				r.gnoBinary = outBin
				r.gnoRoot = root
				t.Logf("built gno from local source in %v", time.Since(start))
				return nil
			} else {
				t.Logf("local build failed; falling back to go install:\n%s", string(output))
			}
		}
	}

	// Fall back to installing from module.
	gobin := filepath.Dir(outBin)
	if err := os.MkdirAll(gobin, 0o755); err != nil {
		return err
	}
	mod := "github.com/gnolang/gno/gnovm/cmd/gno@" + version

	cmd := exec.CommandContext(ctx, "go", "install", "-modcacherw", mod)
	cmd.Env = append(os.Environ(), "GOBIN="+gobin)

	if output, err := cmd.CombinedOutput(); err != nil {
		t.Logf("go install output:\n%s", string(output))
		return fmt.Errorf("go install %s: %w", mod, err)
	}

	r.gnoBinary = outBin
	t.Logf("installed %s in %v", mod, time.Since(start))
	return nil
}

func (r *Runner) findGnoRoot(ctx context.Context) (string, error) {
	if root := os.Getenv("GNOROOT"); root != "" {
		return root, nil
	}
	return goListModuleDir(ctx, "github.com/gnolang/gno")
}

// goListModuleDir returns the module directory for the given module path
func goListModuleDir(ctx context.Context, mod string) (string, error) {
	cmd := exec.CommandContext(ctx, "go", "list", "-m", "-f", "{{.Dir}}", mod)
	cmd.Env = os.Environ()
	out, err := cmd.Output()
	if err != nil {
		return "", err
	}
	dir := strings.TrimSpace(string(out))
	if dir == "" {
		return "", fmt.Errorf("empty module directory for %s", mod)
	}
	return dir, nil
}

// withTestDeadline returns a context honoring testing.T's deadline (with a small buffer).
func withTestDeadline(t *testing.T) context.Context {
	ctx := context.Background()
	if dl, ok := t.Deadline(); ok {
		// Add a small buffer to avoid hitting the exact deadline during process cleanup.
		buf := 15 * time.Second
		if buf > 0 && dl.After(time.Now().Add(buf)) {
			var cancel context.CancelFunc
			ctx, cancel = context.WithDeadline(ctx, dl.Add(-buf))
			t.Cleanup(cancel)
			return ctx
		}
		var cancel context.CancelFunc
		ctx, cancel = context.WithDeadline(ctx, dl)
		t.Cleanup(cancel)
	}
	return ctx
}
