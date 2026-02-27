package model

import "testing"

func TestSymbolKind_String(t *testing.T) {
	tests := []struct {
		kind     SymbolKind
		expected string
	}{
		{KindConst, "const"},
		{KindVar, "var"},
		{KindFunc, "func"},
		{KindType, "type"},
		{KindMethod, "method"},
		{KindField, "field"},
	}

	for _, tt := range tests {
		t.Run(tt.expected, func(t *testing.T) {
			got := tt.kind.String()
			if got != tt.expected {
				t.Errorf("String() = %q, want %q", got, tt.expected)
			}
		})
	}
}

func TestDocNode_ZeroValue(t *testing.T) {
	var node DocNode

	if node.Name != "" {
		t.Errorf("expected empty Name, got %q", node.Name)
	}
	if node.Kind != "" {
		t.Errorf("expected empty Kind, got %q", node.Kind)
	}
	if node.Exported {
		t.Errorf("expected Exported to be false")
	}
}

func TestDocNode_IsExported(t *testing.T) {
	tests := []struct {
		name     string
		node     DocNode
		expected bool
	}{
		{
			name:     "exported name starts with uppercase",
			node:     DocNode{Name: "Foo", Exported: true},
			expected: true,
		},
		{
			name:     "unexported name starts with lowercase",
			node:     DocNode{Name: "foo", Exported: false},
			expected: false,
		},
		{
			name:     "explicit unexported flag",
			node:     DocNode{Name: "Bar", Exported: false},
			expected: false,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			got := tt.node.IsExported()
			if got != tt.expected {
				t.Errorf("IsExported() = %v, want %v", got, tt.expected)
			}
		})
	}
}

func TestDocNode_HasDoc(t *testing.T) {
	tests := []struct {
		name     string
		node     DocNode
		expected bool
	}{
		{
			name:     "no doc",
			node:     DocNode{},
			expected: false,
		},
		{
			name:     "has doc",
			node:     DocNode{Doc: "This is documentation."},
			expected: true,
		},
		{
			name:     "whitespace only doc",
			node:     DocNode{Doc: "   "},
			expected: false,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			got := tt.node.HasDoc()
			if got != tt.expected {
				t.Errorf("HasDoc() = %v, want %v", got, tt.expected)
			}
		})
	}
}

func TestDocNode_AnchorID(t *testing.T) {
	tests := []struct {
		name     string
		node     DocNode
		expected string
	}{
		{
			name:     "function",
			node:     DocNode{Name: "NewFoo", Kind: KindFunc},
			expected: "NewFoo",
		},
		{
			name:     "type",
			node:     DocNode{Name: "MyType", Kind: KindType},
			expected: "MyType",
		},
		{
			name:     "const",
			node:     DocNode{Name: "MaxSize", Kind: KindConst},
			expected: "MaxSize",
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			got := tt.node.AnchorID()
			if got != tt.expected {
				t.Errorf("AnchorID() = %q, want %q", got, tt.expected)
			}
		})
	}
}
