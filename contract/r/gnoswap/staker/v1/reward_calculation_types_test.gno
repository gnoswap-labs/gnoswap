package v1

import (
	"testing"

	"gno.land/p/nt/ufmt"
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
			result := EncodeUint(tt.input)
			if result != tt.expected {
				t.Errorf("EncodeUint(%d) = %s; want %s", tt.input, result, tt.expected)
			}
		})
	}
}

func TestEncodeInt64(t *testing.T) {
	t.Run("positive values", func(t *testing.T) {
		tests := []struct {
			name     string
			input    int64
			expected string
		}{
			{"zero", 0, "00000000000000000000"},
			{"normal value", 12345, "00000000000000012345"},
			{"large value", 9223372036854775807, "09223372036854775807"}, // int64 max
		}

		for _, tt := range tests {
			t.Run(tt.name, func(t *testing.T) {
				result := EncodeInt64(tt.input)
				if result != tt.expected {
					t.Errorf("EncodeInt64(%d) = %s; want %s", tt.input, result, tt.expected)
				}
			})
		}
	})

	t.Run("negative values should panic", func(t *testing.T) {
		negativeValues := []int64{-1, -123, -9223372036854775808} // int64 min

		for _, val := range negativeValues {
			t.Run(ufmt.Sprintf("value_%d", val), func(t *testing.T) {
				defer func() {
					if r := recover(); r == nil {
						t.Errorf("EncodeInt64(%d) should have panicked", val)
					}
				}()
				EncodeInt64(val)
			})
		}
	})
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
				result := DecodeUint(tt.input)
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
			"abc123",              // mixed
		}

		for _, input := range invalidInputs {
			t.Run(ufmt.Sprintf("input_%s", input), func(t *testing.T) {
				defer func() {
					if r := recover(); r == nil {
						t.Errorf("DecodeUint(%s) should have panicked", input)
					}
				}()
				DecodeUint(input)
			})
		}
	})
}

func TestUintTree(t *testing.T) {
	tree := NewUintTree()

	// Test set and Get
	tree.set(12345, "testValue")
	value, ok := tree.Get(12345)
	if !ok || value != "testValue" {
		t.Errorf("UintTree.Get(12345) = %v, %v; want testValue, true", value, ok)
	}

	// Test Has
	if !tree.Has(12345) {
		t.Errorf("UintTree.Has(12345) = false; want true")
	}

	// Test remove
	tree.remove(12345)
	if tree.Has(12345) {
		t.Errorf("UintTree.Has(12345) after Remove = true; want false")
	}

	// Test Iterate
	tree.set(100, "a")
	tree.set(200, "b")
	tree.set(300, "c")

	var keys []uint64
	var values []any

	tree.Iterate(100, 300, func(key int64, value any) bool {
		keys = append(keys, uint64(key))
		values = append(values, value)
		return false
	})

	// Verify results
	expectedKeys := []uint64{100, 200}
	expectedValues := []any{"a", "b"}

	if !compareUintSlices(t, keys, expectedKeys) || !compareInterfaces(t, values, expectedValues) {
		t.Errorf("UintTree.Iterate() keys = %v, values = %v; want keys = %v, values = %v", keys, values, expectedKeys, expectedValues)
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
