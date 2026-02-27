package cmd

import "testing"

func TestGlobalOptions_Default(t *testing.T) {
	opts := DefaultGlobalOptions()

	if opts.IncludeTests {
		t.Error("IncludeTests should be false by default")
	}
	if opts.IgnoreParseErrors {
		t.Error("IgnoreParseErrors should be false by default")
	}
	if !opts.ExportedOnly {
		t.Error("ExportedOnly should be true by default")
	}
	if opts.OutputFile != "README.md" {
		t.Errorf("OutputFile should be 'README.md', got %q", opts.OutputFile)
	}
}

func TestExportOptions_Default(t *testing.T) {
	opts := DefaultExportOptions()

	if opts.Format != "md" {
		t.Errorf("Format should be 'md', got %q", opts.Format)
	}
	if opts.OutputDir != "." {
		t.Errorf("OutputDir should be '.', got %q", opts.OutputDir)
	}
	if opts.Filename != "README.md" {
		t.Errorf("Filename should be 'README.md', got %q", opts.Filename)
	}
}

func TestListOptions_Default(t *testing.T) {
	opts := DefaultListOptions()

	if opts.IncludeTests {
		t.Error("IncludeTests should be false by default")
	}
	if len(opts.Exclude) != 0 {
		t.Error("Exclude should be empty by default")
	}
}
