package model

import "strings"

// SymbolKind represents the kind of a documented symbol.
type SymbolKind string

const (
	KindConst  SymbolKind = "const"
	KindVar    SymbolKind = "var"
	KindFunc   SymbolKind = "func"
	KindType   SymbolKind = "type"
	KindMethod SymbolKind = "method"
	KindField  SymbolKind = "field"
)

// String returns the string representation of the symbol kind.
func (k SymbolKind) String() string {
	return string(k)
}

// DocNode is the common base for all documented symbols.
// It contains shared metadata like name, documentation, position, and export status.
type DocNode struct {
	Name      string
	Kind      SymbolKind
	Summary   string
	Doc       string
	Signature string
	Decl      string
	Exported  bool
	Pos       SourcePos
	Deprecated []DocDeprecated
}

// IsExported reports whether the symbol is exported.
// It returns the value of the Exported field.
func (n DocNode) IsExported() bool {
	return n.Exported
}

// HasDoc reports whether the symbol has non-empty documentation.
func (n DocNode) HasDoc() bool {
	return strings.TrimSpace(n.Doc) != ""
}

// AnchorID returns the HTML anchor ID for this symbol.
// Currently returns the symbol name.
func (n DocNode) AnchorID() string {
	return n.Name
}
