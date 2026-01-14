package cmd

import (
	"flag"
	"fmt"
	"io"
	"os"
	"path/filepath"
	"strings"

	"gnodoc/parser"
	"gnodoc/render"
)

const usageText = `gnodoc - Generate Markdown documentation for Go/Gno packages

Usage:
  gnodoc [options] <path>         Generate README.md for package
  gnodoc export [options] <path>  Export documentation to file
  gnodoc list [options] <path>    List packages in module

Options:
  --out=DIR              Output directory (default: current directory)
  --output-file=NAME     Output filename (default: README.md)
  --include-tests        Include test files
  --ignore-parse-errors  Continue on parse errors
  --exported-only        Only include exported symbols (default)
  --all                  Include all symbols
  --source-link-base=URL Base URL for source links
  --help                 Show this help

Export Options:
  --format=md            Output format (default: md)
  --filename=NAME        Output filename (default: README.md)

List Options:
  --exclude=PATTERN      Exclude packages matching pattern
`

// Runner executes CLI commands.
type Runner struct {
	stdout io.Writer
	stderr io.Writer
}

// NewRunner creates a new CLI runner.
func NewRunner(stdout, stderr io.Writer) *Runner {
	return &Runner{
		stdout: stdout,
		stderr: stderr,
	}
}

// Run executes the CLI with the given arguments.
func (r *Runner) Run(args []string) ExitCode {
	if len(args) == 0 {
		fmt.Fprintln(r.stderr, "error: no path specified")
		fmt.Fprintln(r.stderr, "Run 'gnodoc --help' for usage")
		return ExitError
	}

	// Check for help flag
	for _, arg := range args {
		if arg == "--help" || arg == "-h" {
			fmt.Fprint(r.stdout, usageText)
			return ExitSuccess
		}
	}

	// Check for subcommand
	switch args[0] {
	case "export":
		return r.runExport(args[1:])
	case "list":
		return r.runList(args[1:])
	default:
		return r.runDefault(args)
	}
}

// runDefault handles the default command: gnodoc <path>
func (r *Runner) runDefault(args []string) ExitCode {
	opts := DefaultGlobalOptions()

	fs := flag.NewFlagSet("gnodoc", flag.ContinueOnError)
	fs.SetOutput(r.stderr)

	var outDir string
	fs.StringVar(&outDir, "out", ".", "Output directory")
	fs.StringVar(&opts.OutputFile, "output-file", "README.md", "Output filename")
	fs.BoolVar(&opts.IncludeTests, "include-tests", false, "Include test files")
	fs.BoolVar(&opts.IgnoreParseErrors, "ignore-parse-errors", false, "Continue on parse errors")
	fs.StringVar(&opts.SourceLinkBase, "source-link-base", "", "Base URL for source links")

	var all bool
	var exportedOnly bool
	var exclude string
	fs.BoolVar(&all, "all", false, "Include all symbols")
	fs.BoolVar(&exportedOnly, "exported-only", true, "Only include exported symbols (default)")
	fs.StringVar(&exclude, "exclude", "", "Exclude patterns (comma-separated)")

	if err := fs.Parse(args); err != nil {
		return ExitError
	}

	// --all overrides --exported-only
	if all {
		opts.ExportedOnly = false
	} else if exportedOnly {
		opts.ExportedOnly = true
	}

	// Parse exclude patterns
	if exclude != "" {
		opts.Exclude = strings.Split(exclude, ",")
	}

	remaining := fs.Args()
	if len(remaining) == 0 {
		fmt.Fprintln(r.stderr, "error: no path specified")
		return ExitError
	}

	pkgPath := remaining[0]
	return r.generateDoc(pkgPath, outDir, opts)
}

// runExport handles the export subcommand.
func (r *Runner) runExport(args []string) ExitCode {
	opts := DefaultExportOptions()

	fs := flag.NewFlagSet("export", flag.ContinueOnError)
	fs.SetOutput(r.stderr)

	fs.StringVar(&opts.Format, "format", "md", "Output format")
	fs.StringVar(&opts.OutputDir, "out", ".", "Output directory")
	fs.StringVar(&opts.Filename, "filename", "README.md", "Output filename")
	fs.BoolVar(&opts.IncludeTests, "include-tests", false, "Include test files")
	fs.BoolVar(&opts.IgnoreParseErrors, "ignore-parse-errors", false, "Continue on parse errors")
	fs.StringVar(&opts.SourceLinkBase, "source-link-base", "", "Base URL for source links")

	var all bool
	var exportedOnly bool
	var exclude string
	fs.BoolVar(&all, "all", false, "Include all symbols")
	fs.BoolVar(&exportedOnly, "exported-only", true, "Only include exported symbols (default)")
	fs.StringVar(&exclude, "exclude", "", "Exclude patterns (comma-separated)")

	if err := fs.Parse(args); err != nil {
		return ExitError
	}

	// --all overrides --exported-only
	if all {
		opts.ExportedOnly = false
	} else if exportedOnly {
		opts.ExportedOnly = true
	}

	// Parse exclude patterns
	if exclude != "" {
		opts.Exclude = strings.Split(exclude, ",")
	}

	remaining := fs.Args()
	if len(remaining) == 0 {
		fmt.Fprintln(r.stderr, "error: no path specified")
		return ExitError
	}

	pkgPath := remaining[0]

	// Override output file with filename option
	opts.OutputFile = opts.Filename

	return r.generateDoc(pkgPath, opts.OutputDir, &opts.GlobalOptions)
}

// runList handles the list subcommand.
func (r *Runner) runList(args []string) ExitCode {
	opts := DefaultListOptions()

	fs := flag.NewFlagSet("list", flag.ContinueOnError)
	fs.SetOutput(r.stderr)

	fs.BoolVar(&opts.IncludeTests, "include-tests", false, "Include test packages")

	var exclude string
	fs.StringVar(&exclude, "exclude", "", "Exclude pattern (comma-separated)")

	if err := fs.Parse(args); err != nil {
		return ExitError
	}

	if exclude != "" {
		opts.Exclude = strings.Split(exclude, ",")
	}

	remaining := fs.Args()
	if len(remaining) == 0 {
		fmt.Fprintln(r.stderr, "error: no path specified")
		return ExitError
	}

	pkgPath := remaining[0]
	return r.listPackages(pkgPath, opts)
}

// generateDoc generates documentation for a package.
func (r *Runner) generateDoc(pkgPath, outDir string, opts *GlobalOptions) ExitCode {
	// Parse package
	parserOpts := &parser.Options{
		IncludeTests:      opts.IncludeTests,
		IgnoreParseErrors: opts.IgnoreParseErrors,
		ExportedOnly:      opts.ExportedOnly,
		Exclude:           opts.Exclude,
	}

	p := parser.New(parserOpts)
	pkg, err := p.ParsePackage(pkgPath)
	if err != nil {
		fmt.Fprintf(r.stderr, "error: %v\n", err)
		return ExitError
	}

	// Render to Markdown
	renderOpts := render.DefaultOptions()
	renderOpts.ExportedOnly = opts.ExportedOnly
	renderOpts.SourceLinkBase = opts.SourceLinkBase
	renderOpts.OutputFileName = opts.OutputFile

	renderer := render.NewMarkdownRenderer(renderOpts)
	content := renderer.Render(pkg)

	// Ensure output directory exists
	if err := os.MkdirAll(outDir, 0755); err != nil {
		fmt.Fprintf(r.stderr, "error: cannot create output directory: %v\n", err)
		return ExitError
	}

	// Write output file
	outputPath := filepath.Join(outDir, opts.OutputFile)
	if err := os.WriteFile(outputPath, []byte(content), 0644); err != nil {
		fmt.Fprintf(r.stderr, "error: cannot write output file: %v\n", err)
		return ExitError
	}

	fmt.Fprintf(r.stdout, "Documentation written to %s\n", outputPath)

	// Return partial error if some files failed to parse
	if p.HadParseErrors() {
		return ExitPartialError
	}
	return ExitSuccess
}

// listPackages lists packages in a module.
func (r *Runner) listPackages(rootPath string, opts *ListOptions) ExitCode {
	// Check if path exists
	info, err := os.Stat(rootPath)
	if err != nil {
		fmt.Fprintf(r.stderr, "error: %v\n", err)
		return ExitError
	}

	if !info.IsDir() {
		// Single file, just print the directory
		fmt.Fprintln(r.stdout, filepath.Dir(rootPath))
		return ExitSuccess
	}

	// Walk directory to find packages
	packages := []string{}

	err = filepath.Walk(rootPath, func(path string, info os.FileInfo, err error) error {
		if err != nil {
			return nil // Skip errors
		}

		if !info.IsDir() {
			return nil
		}

		// Check for Go/Gno files
		entries, err := os.ReadDir(path)
		if err != nil {
			return nil
		}

		hasGoFile := false
		for _, entry := range entries {
			name := entry.Name()
			if strings.HasSuffix(name, ".go") || strings.HasSuffix(name, ".gno") {
				// Skip test files if not included
				if !opts.IncludeTests && (strings.HasSuffix(name, "_test.go") || strings.HasSuffix(name, "_test.gno")) {
					continue
				}
				hasGoFile = true
				break
			}
		}

		if hasGoFile {
			// Check exclude patterns
			excluded := false
			for _, pattern := range opts.Exclude {
				if matched, _ := filepath.Match(pattern, filepath.Base(path)); matched {
					excluded = true
					break
				}
			}

			if !excluded {
				packages = append(packages, path)
			}
		}

		return nil
	})

	if err != nil {
		fmt.Fprintf(r.stderr, "error: %v\n", err)
		return ExitError
	}

	// Print packages
	for _, pkg := range packages {
		fmt.Fprintln(r.stdout, pkg)
	}

	return ExitSuccess
}
