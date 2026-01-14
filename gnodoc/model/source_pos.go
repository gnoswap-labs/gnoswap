package model

import "fmt"

// SourcePos represents a position in a source file.
// It contains the filename, line number, and column number.
type SourcePos struct {
	Filename string
	Line     int
	Column   int
}

// IsValid reports whether the position is valid.
// A position is valid if it has a non-empty filename and a positive line number.
// Column is optional (can be zero).
func (p SourcePos) IsValid() bool {
	return p.Filename != "" && p.Line > 0
}

// String returns a string representation of the position.
// Format: "filename:line:column" or "filename:line" if column is zero.
// Returns "-" for invalid positions.
func (p SourcePos) String() string {
	if !p.IsValid() {
		return "-"
	}
	if p.Column > 0 {
		return fmt.Sprintf("%s:%d:%d", p.Filename, p.Line, p.Column)
	}
	return fmt.Sprintf("%s:%d", p.Filename, p.Line)
}
