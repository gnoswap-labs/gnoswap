package model

import "strings"

// DocPackage represents documentation for a package.
// This is the root type that contains all package documentation.
type DocPackage struct {
	Name       string
	ImportPath string
	ModulePath string
	Summary    string
	Doc        string
	Files      []SourceFile
	Consts     []DocValueGroup
	Vars       []DocValueGroup
	Funcs      []DocFunc
	Types      []DocType
	Examples   []DocExample
	Notes      []DocNote
	Deprecated []DocDeprecated
	Index      []DocIndexItem
}

// HasDoc reports whether the package has documentation.
func (p DocPackage) HasDoc() bool {
	return strings.TrimSpace(p.Doc) != ""
}

// ExportedFuncs returns only the exported functions.
func (p DocPackage) ExportedFuncs() []DocFunc {
	var result []DocFunc
	for _, f := range p.Funcs {
		if f.IsExported() {
			result = append(result, f)
		}
	}
	return result
}

// ExportedTypes returns only the exported types.
func (p DocPackage) ExportedTypes() []DocType {
	var result []DocType
	for _, t := range p.Types {
		if t.IsExported() {
			result = append(result, t)
		}
	}
	return result
}

// HasExamples reports whether the package has any examples.
func (p DocPackage) HasExamples() bool {
	return len(p.Examples) > 0
}

// HasNotes reports whether the package has any notes.
func (p DocPackage) HasNotes() bool {
	return len(p.Notes) > 0
}

// BuildIndex constructs the Index field from package contents.
// It creates index items for all exported constants, variables, functions, and types.
func (p *DocPackage) BuildIndex() {
	p.Index = nil

	// Add constants
	for _, group := range p.Consts {
		for _, spec := range group.Specs {
			if spec.IsExported() {
				p.Index = append(p.Index, NewIndexFromNode(spec.DocNode))
			}
		}
	}

	// Add variables
	for _, group := range p.Vars {
		for _, spec := range group.Specs {
			if spec.IsExported() {
				p.Index = append(p.Index, NewIndexFromNode(spec.DocNode))
			}
		}
	}

	// Add functions
	for _, fn := range p.Funcs {
		if fn.IsExported() {
			p.Index = append(p.Index, NewIndexFromNode(fn.DocNode))
		}
	}

	// Add types
	for _, typ := range p.Types {
		if typ.IsExported() {
			p.Index = append(p.Index, NewIndexFromNode(typ.DocNode))
		}
	}
}
