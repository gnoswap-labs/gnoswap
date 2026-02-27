package model

import "testing"

func TestTypeKind_String(t *testing.T) {
	tests := []struct {
		kind     TypeKind
		expected string
	}{
		{TypeKindStruct, "struct"},
		{TypeKindInterface, "interface"},
		{TypeKindAlias, "alias"},
		{TypeKindOther, "other"},
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

func TestDocType_ZeroValue(t *testing.T) {
	var typ DocType

	if typ.Name != "" {
		t.Errorf("expected empty Name, got %q", typ.Name)
	}
	if typ.TypeKind != "" {
		t.Errorf("expected empty TypeKind, got %q", typ.TypeKind)
	}
	if len(typ.Fields) != 0 {
		t.Errorf("expected empty Fields")
	}
	if len(typ.Methods) != 0 {
		t.Errorf("expected empty Methods")
	}
	if len(typ.Constructors) != 0 {
		t.Errorf("expected empty Constructors")
	}
}

func TestDocType_IsStruct(t *testing.T) {
	tests := []struct {
		name     string
		typ      DocType
		expected bool
	}{
		{
			name:     "struct type",
			typ:      DocType{TypeKind: TypeKindStruct},
			expected: true,
		},
		{
			name:     "interface type",
			typ:      DocType{TypeKind: TypeKindInterface},
			expected: false,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			got := tt.typ.IsStruct()
			if got != tt.expected {
				t.Errorf("IsStruct() = %v, want %v", got, tt.expected)
			}
		})
	}
}

func TestDocType_IsInterface(t *testing.T) {
	tests := []struct {
		name     string
		typ      DocType
		expected bool
	}{
		{
			name:     "interface type",
			typ:      DocType{TypeKind: TypeKindInterface},
			expected: true,
		},
		{
			name:     "struct type",
			typ:      DocType{TypeKind: TypeKindStruct},
			expected: false,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			got := tt.typ.IsInterface()
			if got != tt.expected {
				t.Errorf("IsInterface() = %v, want %v", got, tt.expected)
			}
		})
	}
}

func TestDocType_HasMethods(t *testing.T) {
	tests := []struct {
		name     string
		typ      DocType
		expected bool
	}{
		{
			name:     "no methods",
			typ:      DocType{},
			expected: false,
		},
		{
			name: "has methods",
			typ: DocType{
				Methods: []DocFunc{
					{DocNode: DocNode{Name: "String"}},
				},
			},
			expected: true,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			got := tt.typ.HasMethods()
			if got != tt.expected {
				t.Errorf("HasMethods() = %v, want %v", got, tt.expected)
			}
		})
	}
}

func TestDocType_HasConstructors(t *testing.T) {
	tests := []struct {
		name     string
		typ      DocType
		expected bool
	}{
		{
			name:     "no constructors",
			typ:      DocType{},
			expected: false,
		},
		{
			name: "has constructors",
			typ: DocType{
				Constructors: []DocFunc{
					{DocNode: DocNode{Name: "NewFoo"}},
				},
			},
			expected: true,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			got := tt.typ.HasConstructors()
			if got != tt.expected {
				t.Errorf("HasConstructors() = %v, want %v", got, tt.expected)
			}
		})
	}
}

func TestDocType_ExportedFields(t *testing.T) {
	typ := DocType{
		Fields: []DocField{
			{DocNode: DocNode{Name: "ID", Exported: true}},
			{DocNode: DocNode{Name: "name", Exported: false}},
			{DocNode: DocNode{Name: "Value", Exported: true}},
		},
	}

	exported := typ.ExportedFields()
	if len(exported) != 2 {
		t.Fatalf("expected 2 exported fields, got %d", len(exported))
	}
	if exported[0].Name != "ID" {
		t.Errorf("expected first field 'ID', got %q", exported[0].Name)
	}
	if exported[1].Name != "Value" {
		t.Errorf("expected second field 'Value', got %q", exported[1].Name)
	}
}

func TestDocType_ExportedMethods(t *testing.T) {
	typ := DocType{
		Methods: []DocFunc{
			{DocNode: DocNode{Name: "String", Exported: true}},
			{DocNode: DocNode{Name: "validate", Exported: false}},
			{DocNode: DocNode{Name: "Process", Exported: true}},
		},
	}

	exported := typ.ExportedMethods()
	if len(exported) != 2 {
		t.Fatalf("expected 2 exported methods, got %d", len(exported))
	}
	if exported[0].Name != "String" {
		t.Errorf("expected first method 'String', got %q", exported[0].Name)
	}
	if exported[1].Name != "Process" {
		t.Errorf("expected second method 'Process', got %q", exported[1].Name)
	}
}
