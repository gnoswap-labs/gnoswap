package int256

import (
	"testing"

	"gno.land/p/gnoswap/uint256"
	"gno.land/p/nt/ufmt"
)

func TestSetInt64(t *testing.T) {
	tests := []struct {
		x    int64
		want string
	}{
		{0, "0"},
		{1, "1"},
		{-1, "-1"},
		{9223372036854775807, "9223372036854775807"},
		{-9223372036854775808, "-9223372036854775808"},
	}

	for _, tc := range tests {
		var z Int
		z.SetInt64(tc.x)

		got := z.ToString()
		if got != tc.want {
			t.Errorf("SetInt64(%d) = %s, want %s", tc.x, got, tc.want)
		}
	}
}

func TestSetInt64MinValueOverflow(t *testing.T) {
	const minInt64 = -9223372036854775808 // -2^63
	const maxInt64 = 9223372036854775807  // 2^63 - 1

	tests := []struct {
		name string
		x    int64
		want string
	}{
		{
			name: "MinInt64 should not cause overflow",
			x:    minInt64,
			want: "-9223372036854775808",
		},
		{
			name: "MaxInt64 works correctly",
			x:    maxInt64,
			want: "9223372036854775807",
		},
		{
			name: "MinInt64 + 1",
			x:    minInt64 + 1,
			want: "-9223372036854775807",
		},
		{
			name: "Negative one",
			x:    -1,
			want: "-1",
		},
		{
			name: "Zero",
			x:    0,
			want: "0",
		},
	}

	for _, tc := range tests {
		t.Run(tc.name, func(t *testing.T) {
			var z Int
			z.SetInt64(tc.x)

			got := z.ToString()
			if got != tc.want {
				t.Errorf("SetInt64(%d) = %s, want %s", tc.x, got, tc.want)
			}

			// Verify sign is correct
			if tc.x < 0 {
				if !z.IsNegative() {
					t.Errorf("SetInt64(%d): expected IsNegative()=true, got false", tc.x)
				}
			} else if tc.x > 0 {
				if z.IsNegative() {
					t.Errorf("SetInt64(%d): expected IsNegative()=false, got true", tc.x)
				}
			} else { // tc.x == 0
				if z.IsNegative() {
					t.Errorf("SetInt64(0): expected IsNegative()=false (no -0), got true")
				}
			}
		})
	}
}

func TestSetUint64(t *testing.T) {
	tests := []struct {
		x    uint64
		want string
	}{
		{0, "0"},
		{1, "1"},
	}

	for _, tc := range tests {
		var z Int
		z.SetUint64(tc.x)

		got := z.ToString()
		if got != tc.want {
			t.Errorf("SetUint64(%d) = %s, want %s", tc.x, got, tc.want)
		}
	}
}

func TestUint64(t *testing.T) {
	tests := []struct {
		x    string
		want uint64
	}{
		{"0", 0},
		{"1", 1},
		{"9223372036854775807", 9223372036854775807},
		{"9223372036854775808", 9223372036854775808},
		{"18446744073709551615", 18446744073709551615},
		{"18446744073709551616", 0},
		{"18446744073709551617", 1},
		{"-1", 1},
		{"-18446744073709551615", 18446744073709551615},
		{"-18446744073709551616", 0},
		{"-18446744073709551617", 18446744073709551615},
	}

	for _, tc := range tests {
		z := MustFromDecimal(tc.x)

		got := z.Uint64()
		if got != tc.want {
			t.Errorf("Uint64(%s) = %d, want %d", tc.x, got, tc.want)
		}
	}
}

func TestInt64(t *testing.T) {
	tests := []struct {
		x    string
		want int64
	}{
		{"0", 0},
		{"1", 1},
		{"-1", -1},
		{"9223372036854775807", 9223372036854775807},
		{"-9223372036854775808", -9223372036854775808},
		{"9223372036854775808", -9223372036854775808},
		{"-9223372036854775809", 9223372036854775807},
		{"18446744073709551616", 0},
		{"18446744073709551617", 1},
		{"18446744073709551615", -1},
		{"-18446744073709551615", 1},
	}

	for _, tc := range tests {
		z := MustFromDecimal(tc.x)

		got := z.Int64()
		if got != tc.want {
			t.Errorf("Int64(%s) = %d, want %d", tc.x, got, tc.want)
		}
	}
}

func TestInt64EdgeCases(t *testing.T) {
	const minInt64 = -9223372036854775808 // -2^63
	const maxInt64 = 9223372036854775807  // 2^63 - 1

	tests := []struct {
		name        string
		setupInt    func() *Int
		want        int64
		description string
	}{
		{
			name: "MinInt64 from SetInt64",
			setupInt: func() *Int {
				z := new(Int)
				return z.SetInt64(minInt64)
			},
			want:        minInt64,
			description: "SetInt64(MinInt64) should round-trip correctly",
		},
		{
			name: "MaxInt64 from SetInt64",
			setupInt: func() *Int {
				z := new(Int)
				return z.SetInt64(maxInt64)
			},
			want:        maxInt64,
			description: "SetInt64(MaxInt64) should round-trip correctly",
		},
		{
			name: "Magnitude 2^63 with negative sign",
			setupInt: func() *Int {
				// Create Int with magnitude = 2^63 and neg = true
				z := new(Int)
				z.abs = uint256.NewUint(1 << 63)
				z.neg = true
				return z
			},
			want:        minInt64,
			description: "Magnitude 2^63 with neg=true should return MinInt64",
		},
		{
			name: "Magnitude 2^63 with positive sign",
			setupInt: func() *Int {
				// Create Int with magnitude = 2^63 and neg = false
				z := new(Int)
				z.abs = uint256.NewUint(1 << 63)
				z.neg = false
				return z
			},
			want:        minInt64, // Wraps around due to two's complement
			description: "Magnitude 2^63 with neg=false wraps to MinInt64",
		},
		{
			name: "Large positive value wrapping",
			setupInt: func() *Int {
				// 2^64 - 1 (max uint64)
				z := new(Int)
				z.abs = uint256.NewUint(18446744073709551615)
				z.neg = false
				return z
			},
			want:        -1,
			description: "Max uint64 wraps to -1 in int64",
		},
		{
			name: "Negative large value",
			setupInt: func() *Int {
				// -(2^64 - 1)
				z := new(Int)
				z.abs = uint256.NewUint(18446744073709551615)
				z.neg = true
				return z
			},
			want:        1,
			description: "-(Max uint64) becomes 1 due to two's complement",
		},
		{
			name: "Zero",
			setupInt: func() *Int {
				return Zero()
			},
			want:        0,
			description: "Zero should return 0",
		},
		{
			name: "Negative zero prevention",
			setupInt: func() *Int {
				z := new(Int)
				z.abs = uint256.NewUint(0)
				z.neg = true // This should be normalized to false
				return z
			},
			want:        0,
			description: "Negative zero should return 0",
		},
	}

	for _, tc := range tests {
		t.Run(tc.name, func(t *testing.T) {
			z := tc.setupInt()
			got := z.Int64()

			if got != tc.want {
				t.Errorf("%s: got %d, want %d", tc.description, got, tc.want)
			}
		})
	}
}

// TestInt64RoundTrip verifies that SetInt64 and Int64 work correctly together
func TestInt64RoundTrip(t *testing.T) {
	// Test all interesting int64 values
	values := []int64{
		0, 1, -1,
		127, -128, // int8 boundaries
		32767, -32768, // int16 boundaries
		2147483647, -2147483648, // int32 boundaries
		9223372036854775807, -9223372036854775808, // int64 boundaries (MaxInt64, MinInt64)
		1234567890, -1234567890,
	}

	for _, v := range values {
		t.Run(ufmt.Sprintf("RoundTrip_%d", v), func(t *testing.T) {
			z := new(Int)
			z.SetInt64(v)

			got := z.Int64()
			if got != v {
				t.Errorf("Round trip failed: SetInt64(%d).Int64() = %d", v, got)
			}
		})
	}
}

func TestNeg(t *testing.T) {
	tests := []struct {
		x    string
		want string
	}{
		{"0", "0"},
		{"1", "-1"},
		{"-1", "1"},
		{"9223372036854775807", "-9223372036854775807"},
		{"-18446744073709551615", "18446744073709551615"},
	}

	for _, tc := range tests {
		z := MustFromDecimal(tc.x)
		z.Neg(z)

		got := z.ToString()
		if got != tc.want {
			t.Errorf("Neg(%s) = %s, want %s", tc.x, got, tc.want)
		}
	}
}

func TestSet(t *testing.T) {
	tests := []struct {
		x    string
		want string
	}{
		{"0", "0"},
		{"1", "1"},
		{"-1", "-1"},
		{"9223372036854775807", "9223372036854775807"},
		{"-18446744073709551615", "-18446744073709551615"},
	}

	for _, tc := range tests {
		z := MustFromDecimal(tc.x)
		z.Set(z)

		got := z.ToString()
		if got != tc.want {
			t.Errorf("set(%s) = %s, want %s", tc.x, got, tc.want)
		}
	}
}

func TestToString(t *testing.T) {
	tests := []struct {
		name     string
		setup    func() *Int
		expected string
	}{
		{
			name: "Zero from subtraction",
			setup: func() *Int {
				minusThree := MustFromDecimal("-3")
				three := MustFromDecimal("3")
				return Zero().Add(minusThree, three)
			},
			expected: "0",
		},
		{
			name: "Zero from right shift",
			setup: func() *Int {
				return Zero().Rsh(One(), 1234)
			},
			expected: "0",
		},
		{
			name: "Positive number",
			setup: func() *Int {
				return MustFromDecimal("42")
			},
			expected: "42",
		},
		{
			name: "Negative number",
			setup: func() *Int {
				return MustFromDecimal("-42")
			},
			expected: "-42",
		},
		{
			name: "Large positive number",
			setup: func() *Int {
				return MustFromDecimal("57896044618658097711785492504343953926634992332820282019728792003956564819967")
			},
			expected: "57896044618658097711785492504343953926634992332820282019728792003956564819967",
		},
		{
			name: "Large negative number",
			setup: func() *Int {
				return MustFromDecimal("-57896044618658097711785492504343953926634992332820282019728792003956564819968")
			},
			expected: "-57896044618658097711785492504343953926634992332820282019728792003956564819968",
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			z := tt.setup()
			result := z.ToString()
			if result != tt.expected {
				t.Errorf("ToString() = %s, want %s", result, tt.expected)
			}
		})
	}
}
