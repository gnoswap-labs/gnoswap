package model

import "testing"

func TestDocValueSpec_ZeroValue(t *testing.T) {
	var spec DocValueSpec

	if spec.Name != "" {
		t.Errorf("expected empty Name, got %q", spec.Name)
	}
	if spec.Type != "" {
		t.Errorf("expected empty Type, got %q", spec.Type)
	}
	if spec.Value != "" {
		t.Errorf("expected empty Value, got %q", spec.Value)
	}
}

func TestDocValueSpec_WithValues(t *testing.T) {
	spec := DocValueSpec{
		DocNode: DocNode{
			Name:     "MaxSize",
			Kind:     KindConst,
			Summary:  "MaxSize is the maximum size.",
			Exported: true,
		},
		Type:  "int",
		Value: "1024",
	}

	if spec.Name != "MaxSize" {
		t.Errorf("expected Name 'MaxSize', got %q", spec.Name)
	}
	if spec.Type != "int" {
		t.Errorf("expected Type 'int', got %q", spec.Type)
	}
	if spec.Value != "1024" {
		t.Errorf("expected Value '1024', got %q", spec.Value)
	}
	if !spec.IsExported() {
		t.Error("expected spec to be exported")
	}
}

func TestDocValueGroup_ZeroValue(t *testing.T) {
	var group DocValueGroup

	if group.Name != "" {
		t.Errorf("expected empty Name, got %q", group.Name)
	}
	if len(group.Specs) != 0 {
		t.Errorf("expected empty Specs, got %d items", len(group.Specs))
	}
}

func TestDocValueGroup_WithSpecs(t *testing.T) {
	group := DocValueGroup{
		DocNode: DocNode{
			Name: "",
			Kind: KindConst,
			Doc:  "Size constants.",
			Pos:  SourcePos{Filename: "const.go", Line: 10},
		},
		Specs: []DocValueSpec{
			{
				DocNode: DocNode{Name: "KB", Kind: KindConst, Exported: true},
				Type:    "int",
				Value:   "1024",
			},
			{
				DocNode: DocNode{Name: "MB", Kind: KindConst, Exported: true},
				Type:    "int",
				Value:   "1024 * KB",
			},
		},
	}

	if len(group.Specs) != 2 {
		t.Errorf("expected 2 specs, got %d", len(group.Specs))
	}
	if group.Specs[0].Name != "KB" {
		t.Errorf("expected first spec name 'KB', got %q", group.Specs[0].Name)
	}
}

func TestDocValueGroup_Names(t *testing.T) {
	group := DocValueGroup{
		Specs: []DocValueSpec{
			{DocNode: DocNode{Name: "A"}},
			{DocNode: DocNode{Name: "B"}},
			{DocNode: DocNode{Name: "C"}},
		},
	}

	names := group.Names()
	if len(names) != 3 {
		t.Errorf("expected 3 names, got %d", len(names))
	}
	expected := []string{"A", "B", "C"}
	for i, name := range names {
		if name != expected[i] {
			t.Errorf("Names()[%d] = %q, want %q", i, name, expected[i])
		}
	}
}

func TestDocValueGroup_HasExported(t *testing.T) {
	tests := []struct {
		name     string
		group    DocValueGroup
		expected bool
	}{
		{
			name:     "empty group",
			group:    DocValueGroup{},
			expected: false,
		},
		{
			name: "all unexported",
			group: DocValueGroup{
				Specs: []DocValueSpec{
					{DocNode: DocNode{Name: "a", Exported: false}},
					{DocNode: DocNode{Name: "b", Exported: false}},
				},
			},
			expected: false,
		},
		{
			name: "has exported",
			group: DocValueGroup{
				Specs: []DocValueSpec{
					{DocNode: DocNode{Name: "A", Exported: true}},
					{DocNode: DocNode{Name: "b", Exported: false}},
				},
			},
			expected: true,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			got := tt.group.HasExported()
			if got != tt.expected {
				t.Errorf("HasExported() = %v, want %v", got, tt.expected)
			}
		})
	}
}
