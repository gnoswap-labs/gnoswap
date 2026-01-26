package model

import "testing"

func TestDocIndexItem_ZeroValue(t *testing.T) {
	var item DocIndexItem

	if item.Name != "" {
		t.Errorf("expected empty Name, got %q", item.Name)
	}
	if item.Kind != "" {
		t.Errorf("expected empty Kind, got %q", item.Kind)
	}
	if item.Anchor != "" {
		t.Errorf("expected empty Anchor, got %q", item.Anchor)
	}
	if item.Exported {
		t.Error("expected Exported to be false")
	}
}

func TestDocIndexItem_WithValues(t *testing.T) {
	item := DocIndexItem{
		Name:     "NewFoo",
		Kind:     KindFunc,
		Anchor:   "NewFoo",
		Exported: true,
	}

	if item.Name != "NewFoo" {
		t.Errorf("expected Name 'NewFoo', got %q", item.Name)
	}
	if item.Kind != KindFunc {
		t.Errorf("expected Kind 'func', got %q", item.Kind)
	}
	if item.Anchor != "NewFoo" {
		t.Errorf("expected Anchor 'NewFoo', got %q", item.Anchor)
	}
	if !item.Exported {
		t.Error("expected Exported to be true")
	}
}

func TestDocIndexItem_AnchorLink(t *testing.T) {
	tests := []struct {
		name     string
		item     DocIndexItem
		expected string
	}{
		{
			name:     "simple anchor",
			item:     DocIndexItem{Anchor: "Foo"},
			expected: "#Foo",
		},
		{
			name:     "empty anchor",
			item:     DocIndexItem{},
			expected: "#",
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			got := tt.item.AnchorLink()
			if got != tt.expected {
				t.Errorf("AnchorLink() = %q, want %q", got, tt.expected)
			}
		})
	}
}

func TestNewIndexFromNode(t *testing.T) {
	node := DocNode{
		Name:     "MyFunc",
		Kind:     KindFunc,
		Exported: true,
	}

	item := NewIndexFromNode(node)

	if item.Name != "MyFunc" {
		t.Errorf("expected Name 'MyFunc', got %q", item.Name)
	}
	if item.Kind != KindFunc {
		t.Errorf("expected Kind 'func', got %q", item.Kind)
	}
	if item.Anchor != "MyFunc" {
		t.Errorf("expected Anchor 'MyFunc', got %q", item.Anchor)
	}
	if !item.Exported {
		t.Error("expected Exported to be true")
	}
}
