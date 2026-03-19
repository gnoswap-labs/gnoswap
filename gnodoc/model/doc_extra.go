package model

import "strings"

// DocExample represents an example code block.
type DocExample struct {
	Name   string
	Doc    string
	Code   string
	Output string
	Pos    SourcePos
}

// HasOutput reports whether this example has expected output.
func (e DocExample) HasOutput() bool {
	return e.Output != ""
}

// Suffix returns the example suffix (part after "Example" or "Example_").
// For "Example_Foo" returns "Foo", for "Example" returns "".
func (e DocExample) Suffix() string {
	const prefix = "Example"
	if !strings.HasPrefix(e.Name, prefix) {
		return e.Name
	}
	suffix := e.Name[len(prefix):]
	if strings.HasPrefix(suffix, "_") {
		return suffix[1:]
	}
	return suffix
}

// DocNote represents a note annotation in documentation.
// Common kinds: BUG, TODO, NOTE, FIXME, HACK, WARNING.
type DocNote struct {
	Kind string
	Body string
	Pos  SourcePos
}

// IsBug reports whether this is a BUG note.
func (n DocNote) IsBug() bool {
	return n.Kind == "BUG"
}

// DocDeprecated represents a deprecation notice.
type DocDeprecated struct {
	Body string
	Pos  SourcePos
}
