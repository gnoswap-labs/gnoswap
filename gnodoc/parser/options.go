package parser

// Options controls the parsing behavior.
type Options struct {
	// IncludeTests includes test files (*_test.go, *_test.gno).
	IncludeTests bool

	// IgnoreParseErrors continues parsing even if some files fail.
	IgnoreParseErrors bool

	// ExportedOnly includes only exported symbols.
	ExportedOnly bool
}

// DefaultOptions returns the default parser options.
func DefaultOptions() *Options {
	return &Options{
		IncludeTests:      false,
		IgnoreParseErrors: false,
		ExportedOnly:      true,
	}
}
