package render

import "testing"

func TestRenderOptions_Default(t *testing.T) {
	opts := DefaultOptions()

	if !opts.ExportedOnly {
		t.Error("expected ExportedOnly to be true by default")
	}
	if !opts.IncludeIndex {
		t.Error("expected IncludeIndex to be true by default")
	}
	if !opts.IncludeExamples {
		t.Error("expected IncludeExamples to be true by default")
	}
	if opts.SourceLinkBase != "" {
		t.Error("expected empty SourceLinkBase by default")
	}
}

func TestRenderOptions_WithSourceLink(t *testing.T) {
	opts := DefaultOptions()
	opts.SourceLinkBase = "https://github.com/example/repo/blob/main"

	if opts.SourceLinkBase != "https://github.com/example/repo/blob/main" {
		t.Errorf("unexpected SourceLinkBase: %q", opts.SourceLinkBase)
	}
}

func TestRenderOptions_ShouldRenderSymbol(t *testing.T) {
	tests := []struct {
		name         string
		exported     bool
		exportedOnly bool
		expected     bool
	}{
		{
			name:         "exported symbol with ExportedOnly",
			exported:     true,
			exportedOnly: true,
			expected:     true,
		},
		{
			name:         "unexported symbol with ExportedOnly",
			exported:     false,
			exportedOnly: true,
			expected:     false,
		},
		{
			name:         "unexported symbol without ExportedOnly",
			exported:     false,
			exportedOnly: false,
			expected:     true,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			opts := &RenderOptions{ExportedOnly: tt.exportedOnly}
			got := opts.ShouldRender(tt.exported)
			if got != tt.expected {
				t.Errorf("ShouldRender(%v) = %v, want %v", tt.exported, got, tt.expected)
			}
		})
	}
}
