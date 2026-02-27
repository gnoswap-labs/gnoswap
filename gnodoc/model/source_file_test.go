package model

import "testing"

func TestSourceFile_ZeroValue(t *testing.T) {
	var f SourceFile

	if f.Name != "" {
		t.Errorf("expected empty Name, got %q", f.Name)
	}
	if f.Path != "" {
		t.Errorf("expected empty Path, got %q", f.Path)
	}
}

func TestSourceFile_BaseName(t *testing.T) {
	tests := []struct {
		name     string
		file     SourceFile
		expected string
	}{
		{
			name:     "simple filename",
			file:     SourceFile{Name: "foo.go", Path: "/path/to/foo.go"},
			expected: "foo.go",
		},
		{
			name:     "name takes precedence",
			file:     SourceFile{Name: "bar.go", Path: "/path/to/different.go"},
			expected: "bar.go",
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			got := tt.file.BaseName()
			if got != tt.expected {
				t.Errorf("BaseName() = %q, want %q", got, tt.expected)
			}
		})
	}
}

func TestSourceFile_IsTestFile(t *testing.T) {
	tests := []struct {
		name     string
		file     SourceFile
		expected bool
	}{
		{
			name:     "regular file",
			file:     SourceFile{Name: "foo.go"},
			expected: false,
		},
		{
			name:     "test file",
			file:     SourceFile{Name: "foo_test.go"},
			expected: true,
		},
		{
			name:     "example test file",
			file:     SourceFile{Name: "example_test.go"},
			expected: true,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			got := tt.file.IsTestFile()
			if got != tt.expected {
				t.Errorf("IsTestFile() = %v, want %v", got, tt.expected)
			}
		})
	}
}
