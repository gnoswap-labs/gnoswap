package model

import "testing"

// DocExample tests

func TestDocExample_ZeroValue(t *testing.T) {
	var ex DocExample

	if ex.Name != "" {
		t.Errorf("expected empty Name, got %q", ex.Name)
	}
	if ex.Doc != "" {
		t.Errorf("expected empty Doc, got %q", ex.Doc)
	}
	if ex.Code != "" {
		t.Errorf("expected empty Code, got %q", ex.Code)
	}
	if ex.Output != "" {
		t.Errorf("expected empty Output, got %q", ex.Output)
	}
}

func TestDocExample_WithValues(t *testing.T) {
	ex := DocExample{
		Name:   "Example_Foo",
		Doc:    "Example demonstrates Foo usage.",
		Code:   `fmt.Println("hello")`,
		Output: "hello",
		Pos:    SourcePos{Filename: "example_test.go", Line: 10},
	}

	if ex.Name != "Example_Foo" {
		t.Errorf("expected Name 'Example_Foo', got %q", ex.Name)
	}
	if !ex.Pos.IsValid() {
		t.Error("expected valid Pos")
	}
}

func TestDocExample_HasOutput(t *testing.T) {
	tests := []struct {
		name     string
		ex       DocExample
		expected bool
	}{
		{
			name:     "no output",
			ex:       DocExample{},
			expected: false,
		},
		{
			name:     "has output",
			ex:       DocExample{Output: "hello"},
			expected: true,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			got := tt.ex.HasOutput()
			if got != tt.expected {
				t.Errorf("HasOutput() = %v, want %v", got, tt.expected)
			}
		})
	}
}

func TestDocExample_Suffix(t *testing.T) {
	tests := []struct {
		name     string
		ex       DocExample
		expected string
	}{
		{
			name:     "no suffix",
			ex:       DocExample{Name: "Example"},
			expected: "",
		},
		{
			name:     "with suffix",
			ex:       DocExample{Name: "Example_Foo"},
			expected: "Foo",
		},
		{
			name:     "with type suffix",
			ex:       DocExample{Name: "ExampleMyType_Method"},
			expected: "MyType_Method",
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			got := tt.ex.Suffix()
			if got != tt.expected {
				t.Errorf("Suffix() = %q, want %q", got, tt.expected)
			}
		})
	}
}

// DocNote tests

func TestDocNote_ZeroValue(t *testing.T) {
	var note DocNote

	if note.Kind != "" {
		t.Errorf("expected empty Kind, got %q", note.Kind)
	}
	if note.Body != "" {
		t.Errorf("expected empty Body, got %q", note.Body)
	}
}

func TestDocNote_WithValues(t *testing.T) {
	note := DocNote{
		Kind: "BUG",
		Body: "This function has a known issue.",
		Pos:  SourcePos{Filename: "foo.go", Line: 42},
	}

	if note.Kind != "BUG" {
		t.Errorf("expected Kind 'BUG', got %q", note.Kind)
	}
	if note.Body != "This function has a known issue." {
		t.Errorf("expected Body 'This function has a known issue.', got %q", note.Body)
	}
}

func TestDocNote_IsBug(t *testing.T) {
	tests := []struct {
		name     string
		note     DocNote
		expected bool
	}{
		{
			name:     "BUG note",
			note:     DocNote{Kind: "BUG"},
			expected: true,
		},
		{
			name:     "TODO note",
			note:     DocNote{Kind: "TODO"},
			expected: false,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			got := tt.note.IsBug()
			if got != tt.expected {
				t.Errorf("IsBug() = %v, want %v", got, tt.expected)
			}
		})
	}
}

// DocDeprecated tests

func TestDocDeprecated_ZeroValue(t *testing.T) {
	var dep DocDeprecated

	if dep.Body != "" {
		t.Errorf("expected empty Body, got %q", dep.Body)
	}
}

func TestDocDeprecated_WithValues(t *testing.T) {
	dep := DocDeprecated{
		Body: "Use NewFoo instead.",
		Pos:  SourcePos{Filename: "foo.go", Line: 10},
	}

	if dep.Body != "Use NewFoo instead." {
		t.Errorf("expected Body 'Use NewFoo instead.', got %q", dep.Body)
	}
	if !dep.Pos.IsValid() {
		t.Error("expected valid Pos")
	}
}
