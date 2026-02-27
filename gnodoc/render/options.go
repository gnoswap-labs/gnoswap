package render

// RenderOptions controls the Markdown rendering behavior.
type RenderOptions struct {
	// ExportedOnly renders only exported symbols when true.
	ExportedOnly bool

	// IncludeIndex includes the Index section when true.
	IncludeIndex bool

	// IncludeExamples includes the Examples section when true.
	IncludeExamples bool

	// IncludeNotes includes the Notes/Bugs section when true.
	IncludeNotes bool

	// SourceLinkBase is the base URL for source links.
	// If empty, source links are not generated.
	// Example: "https://github.com/user/repo/blob/main"
	SourceLinkBase string

	// OutputFileName is the name of the output file.
	// Defaults to "README.md" if empty.
	OutputFileName string
}

// DefaultOptions returns the default render options.
func DefaultOptions() *RenderOptions {
	return &RenderOptions{
		ExportedOnly:    true,
		IncludeIndex:    true,
		IncludeExamples: true,
		IncludeNotes:    true,
		OutputFileName:  "README.md",
	}
}

// ShouldRender reports whether a symbol should be rendered
// based on its export status and the ExportedOnly option.
func (o *RenderOptions) ShouldRender(exported bool) bool {
	if !o.ExportedOnly {
		return true
	}
	return exported
}
