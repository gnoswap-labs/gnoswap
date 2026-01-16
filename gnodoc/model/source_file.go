package model

import "strings"

// SourceFile represents a source file in the package.
// Used for file listing and source link generation.
type SourceFile struct {
	Name string
	Path string
}

// BaseName returns the base name of the file.
func (f SourceFile) BaseName() string {
	return f.Name
}

// IsTestFile reports whether this is a test file.
func (f SourceFile) IsTestFile() bool {
	return strings.HasSuffix(f.Name, "_test.go")
}
