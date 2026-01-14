package render

import "testing"

func TestToAnchor(t *testing.T) {
	tests := []struct {
		name     string
		input    string
		expected string
	}{
		{
			name:     "simple lowercase",
			input:    "foo",
			expected: "foo",
		},
		{
			name:     "mixed case to lowercase",
			input:    "NewFoo",
			expected: "newfoo",
		},
		{
			name:     "camelCase",
			input:    "myFunction",
			expected: "myfunction",
		},
		{
			name:     "with underscore",
			input:    "My_Type",
			expected: "my_type",
		},
		{
			name:     "with spaces",
			input:    "My Type",
			expected: "my-type",
		},
		{
			name:     "special characters removed",
			input:    "foo*bar",
			expected: "foobar",
		},
		{
			name:     "numbers preserved",
			input:    "Foo123",
			expected: "foo123",
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			got := ToAnchor(tt.input)
			if got != tt.expected {
				t.Errorf("ToAnchor(%q) = %q, want %q", tt.input, got, tt.expected)
			}
		})
	}
}

func TestAnchorRegistry_Register(t *testing.T) {
	reg := NewAnchorRegistry()

	// First registration should return the anchor as-is
	a1 := reg.Register("foo")
	if a1 != "foo" {
		t.Errorf("first registration: got %q, want %q", a1, "foo")
	}

	// Second registration of same anchor should get suffix
	a2 := reg.Register("foo")
	if a2 != "foo-1" {
		t.Errorf("second registration: got %q, want %q", a2, "foo-1")
	}

	// Third registration should increment suffix
	a3 := reg.Register("foo")
	if a3 != "foo-2" {
		t.Errorf("third registration: got %q, want %q", a3, "foo-2")
	}

	// Different anchor should not have suffix
	a4 := reg.Register("bar")
	if a4 != "bar" {
		t.Errorf("different anchor: got %q, want %q", a4, "bar")
	}
}

func TestAnchorRegistry_RegisterName(t *testing.T) {
	reg := NewAnchorRegistry()

	// RegisterName should convert to anchor and register
	a1 := reg.RegisterName("NewFoo")
	if a1 != "newfoo" {
		t.Errorf("first registration: got %q, want %q", a1, "newfoo")
	}

	// Same name should get suffix
	a2 := reg.RegisterName("NewFoo")
	if a2 != "newfoo-1" {
		t.Errorf("second registration: got %q, want %q", a2, "newfoo-1")
	}
}

func TestAnchorRegistry_Get(t *testing.T) {
	reg := NewAnchorRegistry()

	// Register some anchors
	reg.RegisterName("Foo")
	reg.RegisterName("Bar")

	// Get should return the registered anchor
	if got := reg.Get("Foo"); got != "foo" {
		t.Errorf("Get(Foo) = %q, want %q", got, "foo")
	}

	// Get for unregistered should return empty
	if got := reg.Get("Unknown"); got != "" {
		t.Errorf("Get(Unknown) = %q, want empty", got)
	}
}

func TestMethodAnchor(t *testing.T) {
	tests := []struct {
		name       string
		typeName   string
		methodName string
		expected   string
	}{
		{
			name:       "simple method",
			typeName:   "Foo",
			methodName: "Bar",
			expected:   "foo.bar",
		},
		{
			name:       "pointer receiver stripped",
			typeName:   "*Foo",
			methodName: "Process",
			expected:   "foo.process",
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			got := MethodAnchor(tt.typeName, tt.methodName)
			if got != tt.expected {
				t.Errorf("MethodAnchor(%q, %q) = %q, want %q",
					tt.typeName, tt.methodName, got, tt.expected)
			}
		})
	}
}
