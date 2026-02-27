package model

import "testing"

func TestSourcePos_ZeroValue(t *testing.T) {
	var pos SourcePos

	if pos.Filename != "" {
		t.Errorf("expected empty filename, got %q", pos.Filename)
	}
	if pos.Line != 0 {
		t.Errorf("expected line 0, got %d", pos.Line)
	}
	if pos.Column != 0 {
		t.Errorf("expected column 0, got %d", pos.Column)
	}
}

func TestSourcePos_IsValid(t *testing.T) {
	tests := []struct {
		name     string
		pos      SourcePos
		expected bool
	}{
		{
			name:     "zero value is invalid",
			pos:      SourcePos{},
			expected: false,
		},
		{
			name:     "valid position",
			pos:      SourcePos{Filename: "foo.go", Line: 1, Column: 1},
			expected: true,
		},
		{
			name:     "missing filename is invalid",
			pos:      SourcePos{Line: 1, Column: 1},
			expected: false,
		},
		{
			name:     "zero line is invalid",
			pos:      SourcePos{Filename: "foo.go", Line: 0, Column: 1},
			expected: false,
		},
		{
			name:     "zero column is valid (column is optional)",
			pos:      SourcePos{Filename: "foo.go", Line: 1, Column: 0},
			expected: true,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			got := tt.pos.IsValid()
			if got != tt.expected {
				t.Errorf("IsValid() = %v, want %v", got, tt.expected)
			}
		})
	}
}

func TestSourcePos_String(t *testing.T) {
	tests := []struct {
		name     string
		pos      SourcePos
		expected string
	}{
		{
			name:     "full position",
			pos:      SourcePos{Filename: "foo.go", Line: 10, Column: 5},
			expected: "foo.go:10:5",
		},
		{
			name:     "without column",
			pos:      SourcePos{Filename: "bar.go", Line: 42, Column: 0},
			expected: "bar.go:42",
		},
		{
			name:     "invalid position",
			pos:      SourcePos{},
			expected: "-",
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			got := tt.pos.String()
			if got != tt.expected {
				t.Errorf("String() = %q, want %q", got, tt.expected)
			}
		})
	}
}
