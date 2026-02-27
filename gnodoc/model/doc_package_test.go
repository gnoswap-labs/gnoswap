package model

import "testing"

func TestDocPackage_ZeroValue(t *testing.T) {
	var pkg DocPackage

	if pkg.Name != "" {
		t.Errorf("expected empty Name, got %q", pkg.Name)
	}
	if pkg.ImportPath != "" {
		t.Errorf("expected empty ImportPath, got %q", pkg.ImportPath)
	}
	if len(pkg.Files) != 0 {
		t.Errorf("expected empty Files")
	}
	if len(pkg.Consts) != 0 {
		t.Errorf("expected empty Consts")
	}
	if len(pkg.Vars) != 0 {
		t.Errorf("expected empty Vars")
	}
	if len(pkg.Funcs) != 0 {
		t.Errorf("expected empty Funcs")
	}
	if len(pkg.Types) != 0 {
		t.Errorf("expected empty Types")
	}
}

func TestDocPackage_WithValues(t *testing.T) {
	pkg := DocPackage{
		Name:       "mypkg",
		ImportPath: "example.com/mypkg",
		ModulePath: "example.com",
		Summary:    "Package mypkg provides utilities.",
		Doc:        "Package mypkg provides utilities.\n\nMore details here.",
		Files: []SourceFile{
			{Name: "foo.go", Path: "/path/to/foo.go"},
		},
		Consts: []DocValueGroup{
			{
				Specs: []DocValueSpec{
					{DocNode: DocNode{Name: "MaxSize", Exported: true}},
				},
			},
		},
		Funcs: []DocFunc{
			{DocNode: DocNode{Name: "NewFoo", Exported: true}},
		},
		Types: []DocType{
			{DocNode: DocNode{Name: "Foo", Exported: true}},
		},
	}

	if pkg.Name != "mypkg" {
		t.Errorf("expected Name 'mypkg', got %q", pkg.Name)
	}
	if len(pkg.Files) != 1 {
		t.Errorf("expected 1 file, got %d", len(pkg.Files))
	}
	if len(pkg.Consts) != 1 {
		t.Errorf("expected 1 const group, got %d", len(pkg.Consts))
	}
}

func TestDocPackage_HasDoc(t *testing.T) {
	tests := []struct {
		name     string
		pkg      DocPackage
		expected bool
	}{
		{
			name:     "no doc",
			pkg:      DocPackage{},
			expected: false,
		},
		{
			name:     "has doc",
			pkg:      DocPackage{Doc: "Package foo provides bar."},
			expected: true,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			got := tt.pkg.HasDoc()
			if got != tt.expected {
				t.Errorf("HasDoc() = %v, want %v", got, tt.expected)
			}
		})
	}
}

func TestDocPackage_ExportedFuncs(t *testing.T) {
	pkg := DocPackage{
		Funcs: []DocFunc{
			{DocNode: DocNode{Name: "NewFoo", Exported: true}},
			{DocNode: DocNode{Name: "helper", Exported: false}},
			{DocNode: DocNode{Name: "Process", Exported: true}},
		},
	}

	exported := pkg.ExportedFuncs()
	if len(exported) != 2 {
		t.Fatalf("expected 2 exported funcs, got %d", len(exported))
	}
	if exported[0].Name != "NewFoo" {
		t.Errorf("expected first func 'NewFoo', got %q", exported[0].Name)
	}
	if exported[1].Name != "Process" {
		t.Errorf("expected second func 'Process', got %q", exported[1].Name)
	}
}

func TestDocPackage_ExportedTypes(t *testing.T) {
	pkg := DocPackage{
		Types: []DocType{
			{DocNode: DocNode{Name: "Foo", Exported: true}},
			{DocNode: DocNode{Name: "internal", Exported: false}},
			{DocNode: DocNode{Name: "Bar", Exported: true}},
		},
	}

	exported := pkg.ExportedTypes()
	if len(exported) != 2 {
		t.Fatalf("expected 2 exported types, got %d", len(exported))
	}
	if exported[0].Name != "Foo" {
		t.Errorf("expected first type 'Foo', got %q", exported[0].Name)
	}
	if exported[1].Name != "Bar" {
		t.Errorf("expected second type 'Bar', got %q", exported[1].Name)
	}
}

func TestDocPackage_BuildIndex(t *testing.T) {
	pkg := DocPackage{
		Consts: []DocValueGroup{
			{
				Specs: []DocValueSpec{
					{DocNode: DocNode{Name: "MaxSize", Kind: KindConst, Exported: true}},
				},
			},
		},
		Funcs: []DocFunc{
			{DocNode: DocNode{Name: "NewFoo", Kind: KindFunc, Exported: true}},
		},
		Types: []DocType{
			{DocNode: DocNode{Name: "Foo", Kind: KindType, Exported: true}},
		},
	}

	pkg.BuildIndex()

	if len(pkg.Index) != 3 {
		t.Fatalf("expected 3 index items, got %d", len(pkg.Index))
	}

	// Check that all items are present
	names := make(map[string]bool)
	for _, item := range pkg.Index {
		names[item.Name] = true
	}
	if !names["MaxSize"] {
		t.Error("expected MaxSize in index")
	}
	if !names["NewFoo"] {
		t.Error("expected NewFoo in index")
	}
	if !names["Foo"] {
		t.Error("expected Foo in index")
	}
}

func TestDocPackage_HasExamples(t *testing.T) {
	tests := []struct {
		name     string
		pkg      DocPackage
		expected bool
	}{
		{
			name:     "no examples",
			pkg:      DocPackage{},
			expected: false,
		},
		{
			name: "has examples",
			pkg: DocPackage{
				Examples: []DocExample{{Name: "Example"}},
			},
			expected: true,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			got := tt.pkg.HasExamples()
			if got != tt.expected {
				t.Errorf("HasExamples() = %v, want %v", got, tt.expected)
			}
		})
	}
}

func TestDocPackage_HasNotes(t *testing.T) {
	tests := []struct {
		name     string
		pkg      DocPackage
		expected bool
	}{
		{
			name:     "no notes",
			pkg:      DocPackage{},
			expected: false,
		},
		{
			name: "has notes",
			pkg: DocPackage{
				Notes: []DocNote{{Kind: "BUG", Body: "known issue"}},
			},
			expected: true,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			got := tt.pkg.HasNotes()
			if got != tt.expected {
				t.Errorf("HasNotes() = %v, want %v", got, tt.expected)
			}
		})
	}
}
