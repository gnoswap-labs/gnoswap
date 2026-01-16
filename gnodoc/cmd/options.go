package cmd

// GlobalOptions contains common options for all commands.
type GlobalOptions struct {
	// IncludeTests includes test files (*_test.go, *_test.gno).
	IncludeTests bool

	// IgnoreParseErrors continues parsing even if some files fail.
	IgnoreParseErrors bool

	// ExportedOnly includes only exported symbols.
	ExportedOnly bool

	// SourceLinkBase is the base URL for source links.
	SourceLinkBase string

	// ModuleRoot specifies the module root directory.
	ModuleRoot string

	// Exclude patterns for files/directories.
	Exclude []string

	// OutputFile is the output filename.
	OutputFile string
}

// DefaultGlobalOptions returns the default global options.
func DefaultGlobalOptions() *GlobalOptions {
	return &GlobalOptions{
		IncludeTests:      false,
		IgnoreParseErrors: false,
		ExportedOnly:      true,
		OutputFile:        "README.md",
	}
}

// ExportOptions contains options for the export command.
type ExportOptions struct {
	GlobalOptions

	// Format is the output format (md).
	Format string

	// OutputDir is the output directory.
	OutputDir string

	// Filename is the output filename.
	Filename string
}

// DefaultExportOptions returns the default export options.
func DefaultExportOptions() *ExportOptions {
	return &ExportOptions{
		GlobalOptions: *DefaultGlobalOptions(),
		Format:        "md",
		OutputDir:     ".",
		Filename:      "README.md",
	}
}

// ListOptions contains options for the list command.
type ListOptions struct {
	// IncludeTests includes test packages.
	IncludeTests bool

	// Exclude patterns for packages.
	Exclude []string
}

// DefaultListOptions returns the default list options.
func DefaultListOptions() *ListOptions {
	return &ListOptions{
		IncludeTests: false,
		Exclude:      nil,
	}
}
