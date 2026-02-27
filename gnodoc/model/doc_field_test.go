package model

import "testing"

func TestDocField_ZeroValue(t *testing.T) {
	var field DocField

	if field.Name != "" {
		t.Errorf("expected empty Name, got %q", field.Name)
	}
	if field.Type != "" {
		t.Errorf("expected empty Type, got %q", field.Type)
	}
	if field.Tag != "" {
		t.Errorf("expected empty Tag, got %q", field.Tag)
	}
}

func TestDocField_WithValues(t *testing.T) {
	field := DocField{
		DocNode: DocNode{
			Name:     "ID",
			Kind:     KindField,
			Summary:  "ID is the unique identifier.",
			Exported: true,
		},
		Type: "int64",
		Tag:  `json:"id"`,
	}

	if field.Name != "ID" {
		t.Errorf("expected Name 'ID', got %q", field.Name)
	}
	if field.Type != "int64" {
		t.Errorf("expected Type 'int64', got %q", field.Type)
	}
	if field.Tag != `json:"id"` {
		t.Errorf("expected Tag 'json:\"id\"', got %q", field.Tag)
	}
}

func TestDocField_HasTag(t *testing.T) {
	tests := []struct {
		name     string
		field    DocField
		expected bool
	}{
		{
			name:     "no tag",
			field:    DocField{},
			expected: false,
		},
		{
			name:     "has tag",
			field:    DocField{Tag: `json:"name"`},
			expected: true,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			got := tt.field.HasTag()
			if got != tt.expected {
				t.Errorf("HasTag() = %v, want %v", got, tt.expected)
			}
		})
	}
}

func TestDocField_TagValue(t *testing.T) {
	tests := []struct {
		name     string
		field    DocField
		tagKey   string
		expected string
	}{
		{
			name:     "no tag",
			field:    DocField{},
			tagKey:   "json",
			expected: "",
		},
		{
			name:     "json tag",
			field:    DocField{Tag: `json:"name,omitempty"`},
			tagKey:   "json",
			expected: "name,omitempty",
		},
		{
			name:     "multiple tags",
			field:    DocField{Tag: `json:"id" xml:"id" db:"user_id"`},
			tagKey:   "db",
			expected: "user_id",
		},
		{
			name:     "tag not found",
			field:    DocField{Tag: `json:"id"`},
			tagKey:   "xml",
			expected: "",
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			got := tt.field.TagValue(tt.tagKey)
			if got != tt.expected {
				t.Errorf("TagValue(%q) = %q, want %q", tt.tagKey, got, tt.expected)
			}
		})
	}
}
