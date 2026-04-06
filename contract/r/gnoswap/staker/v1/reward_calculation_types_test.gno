package v1

import (
	"testing"

	utree "gno.land/p/gnoswap/uinttree"
	ufmt "gno.land/p/nt/ufmt/v0"
)

func TestEncodeUint(t *testing.T) {
	tests := []struct {
		name     string
		input    uint64
		expected string
	}{
		{"minimum value", 0, "00000000000000000000"},
		{"normal value", 12345, "00000000000000012345"},
		{"maximum value", 18446744073709551615, "18446744073709551615"},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			result := utree.EncodeUint(tt.input)
			if result != tt.expected {
				t.Errorf("EncodeUint(%d) = %s; want %s", tt.input, result, tt.expected)
			}
		})
	}
}

func TestDecodeUint(t *testing.T) {
	t.Run("valid inputs", func(t *testing.T) {
		tests := []struct {
			name     string
			input    string
			expected uint64
		}{
			{"minimum", "00000000000000000000", 0},
			{"normal", "00000000000000012345", 12345},
			{"maximum", "18446744073709551615", 18446744073709551615},
		}

		for _, tt := range tests {
			t.Run(tt.name, func(t *testing.T) {
				result := utree.DecodeUint(tt.input)
				if result != tt.expected {
					t.Errorf("DecodeUint(%s) = %d; want %d", tt.input, result, tt.expected)
				}
			})
		}
	})

	t.Run("invalid inputs should panic", func(t *testing.T) {
		invalidInputs := []string{
			"invalid",
			"18446744073709551616", // overflow
			"",                     // empty
			"abc123",               // mixed
		}

		for _, input := range invalidInputs {
			t.Run(ufmt.Sprintf("input_%s", input), func(t *testing.T) {
				defer func() {
					if r := recover(); r == nil {
						t.Errorf("DecodeUint(%s) should have panicked", input)
					}
				}()
				utree.DecodeUint(input)
			})
		}
	})
}

func TestUintTree(t *testing.T) {
	tree := utree.NewUintTree()

	// Test SetByInt64 and GetByInt64
	tree.SetByInt64(12345, "testValue")
	value, ok := tree.GetByInt64(12345)
	if !ok || value != "testValue" {
		t.Errorf("UintTree.GetByInt64(12345) = %v, %v; want testValue, true", value, ok)
	}

	// Test Has
	if !tree.Has(12345) {
		t.Errorf("UintTree.Has(12345) = false; want true")
	}

	// Test RemoveByInt64
	tree.RemoveByInt64(12345)
	if tree.Has(12345) {
		t.Errorf("UintTree.Has(12345) after Remove = true; want false")
	}

	// Test IterateByInt64
	tree.SetByInt64(100, "a")
	tree.SetByInt64(200, "b")
	tree.SetByInt64(300, "c")

	var keys []uint64
	var values []any

	tree.IterateByInt64(100, 300, func(key uint64, value any) bool {
		keys = append(keys, key)
		values = append(values, value)
		return false
	})

	// Verify results
	expectedKeys := []uint64{100, 200}
	expectedValues := []any{"a", "b"}

	if !compareUintSlices(t, keys, expectedKeys) || !compareInterfaces(t, values, expectedValues) {
		t.Errorf("UintTree.IterateByInt64() keys = %v, values = %v; want keys = %v, values = %v", keys, values, expectedKeys, expectedValues)
	}
}

// Helper function to compare slices of uint64
func compareUintSlices(t *testing.T, a, b []uint64) bool {
	t.Helper()
	if len(a) != len(b) {
		return false
	}
	for i := range a {
		if a[i] != b[i] {
			return false
		}
	}
	return true
}

// Helper function to compare slices of interfaces
func compareInterfaces(t *testing.T, a, b []any) bool {
	t.Helper()
	if len(a) != len(b) {
		return false
	}
	for i := range a {
		if a[i] != b[i] {
			return false
		}
	}
	return true
}
