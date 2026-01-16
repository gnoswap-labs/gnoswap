package model

// DocIndexItem represents an item in the documentation index/TOC.
type DocIndexItem struct {
	Name     string
	Kind     SymbolKind
	Anchor   string
	Exported bool
}

// AnchorLink returns the HTML anchor link for this item.
func (i DocIndexItem) AnchorLink() string {
	return "#" + i.Anchor
}

// NewIndexFromNode creates a DocIndexItem from a DocNode.
func NewIndexFromNode(node DocNode) DocIndexItem {
	return DocIndexItem{
		Name:     node.Name,
		Kind:     node.Kind,
		Anchor:   node.AnchorID(),
		Exported: node.Exported,
	}
}
