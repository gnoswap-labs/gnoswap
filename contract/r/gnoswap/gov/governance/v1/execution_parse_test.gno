package v1

import (
	"testing"

	uassert "gno.land/p/nt/uassert/v0"
)

func TestSplitExecutionsRaw(t *testing.T) {
	tests := []struct {
		name     string
		raw      string
		expected []string
	}{
		{
			name:     "empty string returns empty slice",
			raw:      "",
			expected: []string{},
		},
		{
			name:     "single execution returns one message",
			raw:      "pkg1*EXE*func1*EXE*param1",
			expected: []string{"pkg1*EXE*func1*EXE*param1"},
		},
		{
			name:     "multiple executions split by message separator",
			raw:      "pkg1*EXE*func1*EXE*param1*GOV*pkg2*EXE*func2*EXE*param2",
			expected: []string{"pkg1*EXE*func1*EXE*param1", "pkg2*EXE*func2*EXE*param2"},
		},
	}

	for _, tc := range tests {
		t.Run(tc.name, func(t *testing.T) {
			actual := splitExecutionsRaw(tc.raw)
			uassert.Equal(t, len(actual), len(tc.expected))
			for i := range tc.expected {
				uassert.Equal(t, actual[i], tc.expected[i])
			}
		})
	}
}
