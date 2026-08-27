package staker

import (
	"testing"

	ufmt "gno.land/p/nt/ufmt/v0"
)

func TestEncodeUint(t *testing.T) {
	values := []uint64{0, 1, 255, 256, 12345, 9223372036854775807, 18446744073709551615}
	previous := ""
	for _, value := range values {
		key := EncodeUint(value)
		if len(key) != 8 {
			t.Errorf("EncodeUint(%d) length = %d; want 8", value, len(key))
		}
		if decoded := DecodeUint(key); decoded != value {
			t.Errorf("DecodeUint(EncodeUint(%d)) = %d", value, decoded)
		}
		if previous != "" && !(previous < key) {
			t.Errorf("EncodeUint keys are not ordered: %d", value)
		}
		previous = key
	}
}

func TestEncodeInt64(t *testing.T) {
	t.Run("positive values", func(t *testing.T) {
		tests := []struct {
			name  string
			input int64
		}{
			{"zero", 0},
			{"normal value", 12345},
			{"large value", 9223372036854775807}, // int64 max
		}

		for _, tt := range tests {
			t.Run(tt.name, func(t *testing.T) {
				key := EncodeInt64(tt.input)
				if len(key) != 8 {
					t.Errorf("EncodeInt64(%d) length = %d; want 8", tt.input, len(key))
				}
				if decoded := DecodeInt64(key); decoded != tt.input {
					t.Errorf("DecodeInt64(EncodeInt64(%d)) = %d", tt.input, decoded)
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
	t.Run("invalid inputs should panic", func(t *testing.T) {
		invalidInputs := []string{
			"",          // empty
			"short",     // too short
			"too long!", // too long
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
