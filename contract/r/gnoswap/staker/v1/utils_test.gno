package v1

import (
	"testing"

	"gno.land/p/demo/tokens/grc721"
	u256 "gno.land/p/gnoswap/uint256"
	"gno.land/p/nt/uassert"
)

func TestPoolPathAlign(t *testing.T) {
	tests := []struct {
		input       string
		expected    string
		shouldPanic bool
	}{
		// Valid cases
		{"baz:bar:500", "bar:baz:500", false},
		{"bar:baz:500", "bar:baz:500", false},
		{"foo:bar:300", "bar:foo:300", false},
		{"bar:foo:300", "bar:foo:300", false},

		// Invalid cases
		{"invalid:path", "", true}, // Missing fee
		{"bar:baz", "", true},      // Too few components
		{"", "", true},             // Empty string
	}

	for _, tt := range tests {
		if tt.shouldPanic {
			// Test for panic
			defer func() {
				if r := recover(); r == nil {
					t.Errorf("poolPathAlign(%s) did not panic as expected", tt.input)
				}
			}()
			_ = poolPathAlign(tt.input)
		} else {
			// Test normal cases
			result := poolPathAlign(tt.input)
			if result != tt.expected {
				t.Errorf("poolPathAlign(%s) = %s; want %s", tt.input, result, tt.expected)
			}
		}
	}
}

func TestPoolPathDivide(t *testing.T) {
	tests := []struct {
		name        string
		input       string
		expected0   string
		expected1   string
		expectedFee string
		shouldPanic bool
	}{
		// Valid cases
		{"Valid pool path", "bar:baz:500", "bar", "baz", "500", false},
		{"Another valid pool path", "foo:bar:300", "foo", "bar", "300", false},

		// Invalid cases
		{"Missing fee", "bar:baz", "", "", "", true},
		{"Too few components", "bar", "", "", "", true},
		{"Empty string", "", "", "", "", true},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			if tt.shouldPanic {
				// Test for panic cases
				defer func() {
					if r := recover(); r == nil {
						t.Errorf("poolPathDivide(%s) did not panic as expected", tt.input)
					}
				}()
				_, _, _ = poolPathDivide(tt.input)
			} else {
				// Test for normal cases
				pToken0, pToken1, fee := poolPathDivide(tt.input)
				if pToken0 != tt.expected0 || pToken1 != tt.expected1 || fee != tt.expectedFee {
					t.Errorf(
						"poolPathDivide(%s) = (%s, %s, %s); want (%s, %s, %s)",
						tt.input, pToken0, pToken1, fee, tt.expected0, tt.expected1, tt.expectedFee,
					)
				}
			}
		})
	}
}

func TestTid(t *testing.T) {
	tests := []struct {
		name        string
		input       any
		expected    string
		shouldPanic bool
	}{
		{
			name:        "Panic - nil",
			input:       nil,
			expected:    "[GNOSWAP-STAKER-022] requested data not found || positionId is nil",
			shouldPanic: true,
		},
		{
			name:        "Panic - unsupported type",
			input:       float64(1),
			expected:    "[GNOSWAP-STAKER-007] invalid input data || unsupported positionId type(unknown)",
			shouldPanic: true,
		},
		{
			name:        "Success - string",
			input:       "1",
			expected:    "1",
			shouldPanic: false,
		},
		{
			name:        "Success - int",
			input:       int(1),
			expected:    "1",
			shouldPanic: false,
		},
		{
			name:        "Success - uint64",
			input:       uint64(1),
			expected:    "1",
			shouldPanic: false,
		},
		{
			name:        "Success - grc721.TokenID",
			input:       grc721.TokenID("1"),
			expected:    "1",
			shouldPanic: false,
		},
	}
	for _, tc := range tests {
		t.Run(tc.name, func(t *testing.T) {
			defer func() {
				r := recover()
				if r == nil {
					if tc.shouldPanic {
						t.Errorf(">>> %s: expected panic but got none", tc.name)
						return
					}
				} else {
					switch r.(type) {
					case string:
						if r.(string) != tc.expected {
							t.Errorf(">>> %s: got panic %v, want %v", tc.name, r, tc.expected)
						}
					case error:
						if r.(error).Error() != tc.expected {
							t.Errorf(">>> %s: got panic %v, want %v", tc.name, r.(error).Error(), tc.expected)
						}
					default:
						t.Errorf(">>> %s: got panic %v, want %v", tc.name, r, tc.expected)
					}
				}
			}()

			if !tc.shouldPanic {
				got := positionIdFrom(tc.input)
				uassert.Equal(t, tc.expected, string(got))
			} else {
				positionIdFrom(tc.input)
			}
		})
	}
}

func TestFormatUint(t *testing.T) {
	tests := []struct {
		name        string
		input       any
		expected    string
		shouldPanic bool
	}{
		// Valid uint8 cases
		{"uint8 zero", uint8(0), "0", false},
		{"uint8 one", uint8(1), "1", false},
		{"uint8 max", uint8(255), "255", false},
		// Valid uint32 cases
		{"uint32 zero", uint32(0), "0", false},
		{"uint32 one", uint32(1), "1", false},
		{"uint32 max", uint32(4294967295), "4294967295", false},
		// Valid uint64 cases
		{"uint64 zero", uint64(0), "0", false},
		{"uint64 one", uint64(1), "1", false},
		{"uint64 max", uint64(18446744073709551615), "18446744073709551615", false},
		// Invalid type cases
		{"invalid type int", int(1), "", true},
		{"invalid type string", "123", "", true},
		{"invalid type float64", float64(1.5), "", true},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			if tt.shouldPanic {
				uassert.PanicsContains(t, "invalid type for Unsigned", func() {
					formatUint(tt.input)
				})
			} else {
				result := formatUint(tt.input)
				uassert.Equal(t, tt.expected, result)
			}
		})
	}
}

func TestFormatAnyInt(t *testing.T) {
	tests := []struct {
		name        string
		input       any
		expected    string
		shouldPanic bool
	}{
		// Valid int32 cases
		{"int32 zero", int32(0), "0", false},
		{"int32 positive", int32(123), "123", false},
		{"int32 negative", int32(-123), "-123", false},
		{"int32 max", int32(2147483647), "2147483647", false},
		{"int32 min", int32(-2147483648), "-2147483648", false},
		// Valid int64 cases
		{"int64 zero", int64(0), "0", false},
		{"int64 positive", int64(123), "123", false},
		{"int64 negative", int64(-123), "-123", false},
		{"int64 max", int64(9223372036854775807), "9223372036854775807", false},
		{"int64 min", int64(-9223372036854775808), "-9223372036854775808", false},
		// Valid int cases
		{"int zero", int(0), "0", false},
		{"int positive", int(123), "123", false},
		{"int negative", int(-123), "-123", false},
		// Invalid type cases
		{"invalid type uint", uint(1), "", true},
		{"invalid type string", "123", "", true},
		{"invalid type float64", float64(1.5), "", true},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			if tt.shouldPanic {
				uassert.PanicsContains(t, "invalid type for Signed", func() {
					formatAnyInt(tt.input)
				})
			} else {
				result := formatAnyInt(tt.input)
				uassert.Equal(t, tt.expected, result)
			}
		})
	}
}

func TestFormatBool(t *testing.T) {
	tests := []struct {
		name     string
		input    bool
		expected string
	}{
		{"true value", true, "true"},
		{"false value", false, "false"},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			result := formatBool(tt.input)
			uassert.Equal(t, tt.expected, result)
		})
	}
}

func TestMax(t *testing.T) {
	tests := []struct {
		name     string
		x        int64
		y        int64
		expected int64
	}{
		{"x greater than y", 10, 5, 10},
		{"y greater than x", 5, 10, 10},
		{"x equals y", 5, 5, 5},
		{"both zero", 0, 0, 0},
		{"negative numbers", -5, -10, -5},
		{"mixed signs", -5, 10, 10},
		{"max int64", 9223372036854775807, 1, 9223372036854775807},
		{"min int64", -9223372036854775808, -1, -1},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			result := max(tt.x, tt.y)
			uassert.Equal(t, tt.expected, result)
		})
	}
}

func TestMin(t *testing.T) {
	tests := []struct {
		name     string
		x        uint64
		y        uint64
		expected uint64
	}{
		{"x less than y", 5, 10, 5},
		{"y less than x", 10, 5, 5},
		{"x equals y", 5, 5, 5},
		{"both zero", 0, 0, 0},
		{"max uint64", 18446744073709551615, 1, 1},
		{"one is zero", 0, 100, 0},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			result := min(tt.x, tt.y)
			uassert.Equal(t, tt.expected, result)
		})
	}
}

func TestContains(t *testing.T) {
	tests := []struct {
		name     string
		slice    []string
		item     string
		expected bool
	}{
		{"item exists", []string{"foo", "bar", "baz"}, "bar", true},
		{"item not exists", []string{"foo", "bar", "baz"}, "qux", false},
		{"empty slice", []string{}, "foo", false},
		{"empty item", []string{"foo", "", "bar"}, "", true},
		{"case sensitive - different case", []string{"Foo", "Bar"}, "foo", false},
		{"single item match", []string{"foo"}, "foo", true},
		{"single item no match", []string{"foo"}, "bar", false},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			result := contains(tt.slice, tt.item)
			uassert.Equal(t, tt.expected, result)
		})
	}
}

func TestSafeConvertToInt64(t *testing.T) {
	tests := []struct {
		name        string
		input       string
		expected    int64
		shouldPanic bool
	}{
		{"zero", "0", 0, false},
		{"one", "1", 1, false},
		{"max int64", "9223372036854775807", 9223372036854775807, false},
		{"overflow by 1", "9223372036854775808", 0, true},
		{"max uint64", "18446744073709551615", 0, true},
		{"large overflow", "123456789012345678901234567890", 0, true},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			value := u256.MustFromDecimal(tt.input)
			if tt.shouldPanic {
				uassert.PanicsContains(t, "overflows int64 range", func() {
					safeConvertToInt64(value)
				})
			} else {
				result := safeConvertToInt64(value)
				uassert.Equal(t, tt.expected, result)
			}
		})
	}
}

func TestSafeMulInt64(t *testing.T) {
	tests := []struct {
		name        string
		a           int64
		b           int64
		expected    int64
		shouldPanic bool
	}{
		// Valid cases
		{"zero * zero", 0, 0, 0, false},
		{"zero * positive", 0, 100, 0, false},
		{"zero * negative", 0, -100, 0, false},
		{"positive * zero", 100, 0, 0, false},
		{"positive * positive", 10, 20, 200, false},
		{"negative * negative", -10, -20, 200, false},
		{"positive * negative", 10, -20, -200, false},
		{"negative * positive", -10, 20, -200, false},
		{"one * value", 1, 12345, 12345, false},
		{"value * one", 12345, 1, 12345, false},
		// Overflow cases
		{"positive overflow", 9223372036854775807, 2, 0, true},
		{"negative overflow", -9223372036854775808, 2, 0, true},
		{"mixed underflow", 9223372036854775807, -2, 0, true},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			if tt.shouldPanic {
				uassert.PanicsContains(t, "int64 multiplication", func() {
					safeMulInt64(tt.a, tt.b)
				})
			} else {
				result := safeMulInt64(tt.a, tt.b)
				uassert.Equal(t, tt.expected, result)
			}
		})
	}
}

func TestSafeAddInt64(t *testing.T) {
	tests := []struct {
		name        string
		a           int64
		b           int64
		expected    int64
		shouldPanic bool
	}{
		// Valid cases
		{"zero + zero", 0, 0, 0, false},
		{"positive + positive", 100, 200, 300, false},
		{"negative + negative", -100, -200, -300, false},
		{"positive + negative", 100, -50, 50, false},
		{"negative + positive", -100, 50, -50, false},
		{"max safe add", 9223372036854775806, 1, 9223372036854775807, false},
		{"min safe add", -9223372036854775807, -1, -9223372036854775808, false},
		// Overflow cases
		{"positive overflow", 9223372036854775807, 1, 0, true},
		{"negative underflow", -9223372036854775808, -1, 0, true},
		{"large positive overflow", 9223372036854775807, 9223372036854775807, 0, true},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			if tt.shouldPanic {
				uassert.PanicsContains(t, "int64 addition", func() {
					safeAddInt64(tt.a, tt.b)
				})
			} else {
				result := safeAddInt64(tt.a, tt.b)
				uassert.Equal(t, tt.expected, result)
			}
		})
	}
}

func TestSafeSubInt64(t *testing.T) {
	tests := []struct {
		name        string
		a           int64
		b           int64
		expected    int64
		shouldPanic bool
	}{
		// Valid cases
		{"zero - zero", 0, 0, 0, false},
		{"positive - positive", 100, 50, 50, false},
		{"negative - negative", -100, -50, -50, false},
		{"positive - negative", 100, -50, 150, false},
		{"negative - positive", -100, 50, -150, false},
		{"max safe sub", -9223372036854775807, 1, -9223372036854775808, false},
		{"result zero", 100, 100, 0, false},
		// Overflow cases
		{"positive overflow", 9223372036854775807, -1, 0, true},
		{"negative underflow", -9223372036854775808, 1, 0, true},
		{"large underflow", -9223372036854775807, 9223372036854775807, 0, true},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			if tt.shouldPanic {
				uassert.PanicsContains(t, "int64 subtraction", func() {
					safeSubInt64(tt.a, tt.b)
				})
			} else {
				result := safeSubInt64(tt.a, tt.b)
				uassert.Equal(t, tt.expected, result)
			}
		})
	}
}
