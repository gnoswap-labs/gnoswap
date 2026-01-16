package model

import "testing"

func TestDocParam_ZeroValue(t *testing.T) {
	var param DocParam

	if param.Name != "" {
		t.Errorf("expected empty Name, got %q", param.Name)
	}
	if param.Type != "" {
		t.Errorf("expected empty Type, got %q", param.Type)
	}
}

func TestDocParam_String(t *testing.T) {
	tests := []struct {
		name     string
		param    DocParam
		expected string
	}{
		{
			name:     "named parameter",
			param:    DocParam{Name: "x", Type: "int"},
			expected: "x int",
		},
		{
			name:     "unnamed parameter",
			param:    DocParam{Name: "", Type: "string"},
			expected: "string",
		},
		{
			name:     "pointer type",
			param:    DocParam{Name: "p", Type: "*Foo"},
			expected: "p *Foo",
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			got := tt.param.String()
			if got != tt.expected {
				t.Errorf("String() = %q, want %q", got, tt.expected)
			}
		})
	}
}

func TestDocReceiver_ZeroValue(t *testing.T) {
	var recv DocReceiver

	if recv.Name != "" {
		t.Errorf("expected empty Name, got %q", recv.Name)
	}
	if recv.Type != "" {
		t.Errorf("expected empty Type, got %q", recv.Type)
	}
}

func TestDocReceiver_String(t *testing.T) {
	tests := []struct {
		name     string
		recv     DocReceiver
		expected string
	}{
		{
			name:     "value receiver",
			recv:     DocReceiver{Name: "f", Type: "Foo"},
			expected: "(f Foo)",
		},
		{
			name:     "pointer receiver",
			recv:     DocReceiver{Name: "f", Type: "*Foo"},
			expected: "(f *Foo)",
		},
		{
			name:     "unnamed receiver",
			recv:     DocReceiver{Name: "", Type: "Foo"},
			expected: "(Foo)",
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			got := tt.recv.String()
			if got != tt.expected {
				t.Errorf("String() = %q, want %q", got, tt.expected)
			}
		})
	}
}

func TestDocReceiver_IsPointer(t *testing.T) {
	tests := []struct {
		name     string
		recv     DocReceiver
		expected bool
	}{
		{
			name:     "value receiver",
			recv:     DocReceiver{Name: "f", Type: "Foo"},
			expected: false,
		},
		{
			name:     "pointer receiver",
			recv:     DocReceiver{Name: "f", Type: "*Foo"},
			expected: true,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			got := tt.recv.IsPointer()
			if got != tt.expected {
				t.Errorf("IsPointer() = %v, want %v", got, tt.expected)
			}
		})
	}
}
