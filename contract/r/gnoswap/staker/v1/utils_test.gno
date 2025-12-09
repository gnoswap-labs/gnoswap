package v1

import (
	"math"
	"testing"

	"gno.land/p/demo/tokens/grc721"
	"gno.land/p/nt/uassert"
)

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

func TestSafeMulDivInt64(t *testing.T) {
	tests := []struct {
		name        string
		a           int64
		b           int64
		c           int64
		expected    int64
		shouldPanic bool
		panicMsg    string
	}{
		// Normal cases
		{
			name:     "simple multiplication and division",
			a:        1000,
			b:        50,
			c:        100, // PERCENTAGE_DENOMINATOR
			expected: 500,
		},
		{
			name:     "100% of value",
			a:        1000,
			b:        100,
			c:        100,
			expected: 1000,
		},
		{
			name:     "10% of value",
			a:        1000,
			b:        10,
			c:        100,
			expected: 100,
		},
		// Zero cases
		{
			name:     "a is zero",
			a:        0,
			b:        100,
			c:        100,
			expected: 0,
		},
		{
			name:     "b is zero",
			a:        100,
			b:        0,
			c:        100,
			expected: 0,
		},
		{
			name:     "both a and b are zero",
			a:        0,
			b:        0,
			c:        100,
			expected: 0,
		},
		// Division by zero
		{
			name:        "division by zero",
			a:           100,
			b:           50,
			c:           0,
			shouldPanic: true,
			panicMsg:    "division by zero in safeMulDivInt64",
		},
		// Result is zero after division (too small)
		{
			name:        "result too small - becomes zero",
			a:           1,
			b:           1,
			c:           100,
			shouldPanic: false,
		},
		// Negative values
		{
			name:     "negative a",
			a:        -1000,
			b:        50,
			c:        100,
			expected: -500,
		},
		{
			name:     "negative b",
			a:        1000,
			b:        -50,
			c:        100,
			expected: -500,
		},
		{
			name:     "both negative",
			a:        -1000,
			b:        -50,
			c:        100,
			expected: 500,
		},
		// Large values
		{
			name:     "large values within range",
			a:        1000000000000,
			b:        50,
			c:        100,
			expected: 500000000000,
		},
		{
			name:        "int64 overflow on final conversion",
			a:           math.MaxInt64,
			b:           200,
			c:           100,
			shouldPanic: true,
			panicMsg:    "[GNOSWAP-STAKER-032] overflow",
		},
		{
			name:     "minInt64 allow negative value",
			a:        math.MinInt64,
			b:        -100,
			c:        -100,
			expected: math.MinInt64,
		},
		{
			name:        "minInt64 overflow on positive value",
			a:           math.MinInt64,
			b:           -100,
			c:           100,
			shouldPanic: true,
			panicMsg:    "[GNOSWAP-STAKER-032] overflow",
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			if tt.shouldPanic {
				defer func() {
					r := recover()
					if r == nil {
						t.Errorf("expected panic but got none")
						return
					}
					panicStr, ok := r.(string)
					if !ok {
						// Handle error type
						if err, isErr := r.(error); isErr {
							panicStr = err.Error()
						}
					}
					if panicStr != tt.panicMsg {
						t.Errorf("expected panic message %q, got %q", tt.panicMsg, panicStr)
					}
				}()
				safeMulDivInt64(tt.a, tt.b, tt.c)
			} else {
				result := safeMulDivInt64(tt.a, tt.b, tt.c)
				uassert.Equal(t, result, tt.expected)
			}
		})
	}
}

func TestSafeMulInt64(t *testing.T) {
	overflowMsg := "int64 multiplication overflow"
	underflowMsg := "int64 multiplication underflow"

	tests := []struct {
		name        string
		a, b        int64
		want        int64
		shouldPanic bool
		panicMsg    string
	}{
		{
			name: "simple positive multiplication",
			a:    3, b: 4,
			want: 12,
		},
		{
			name: "simple negative multiplication",
			a:    -3, b: 4,
			want: -12,
		},
		{
			name: "simple negative negative multiplication",
			a:    -3, b: -4,
			want: 12,
		},
		{
			name: "a is zero",
			a:    0, b: 123456,
			want: 0,
		},
		{
			name: "b is zero",
			a:    987654, b: 0,
			want: 0,
		},
		{
			name: "positive overflow",
			a:    math.MaxInt64 / 2, b: 3, // 1.5 * 3 > MaxInt64
			shouldPanic: true,
			panicMsg:    overflowMsg,
		},
		{
			name: "negative negative overflow",
			a:    -math.MaxInt64 / 2, b: -3,
			shouldPanic: true,
			panicMsg:    overflowMsg,
		},
		{
			name: "positive negative underflow",
			a:    math.MaxInt64, b: -2,
			shouldPanic: true,
			panicMsg:    underflowMsg,
		},
		{
			name: "MinInt64 * -1 overflows",
			a:    math.MinInt64, b: -1,
			shouldPanic: true,
			panicMsg:    overflowMsg,
		},
		{
			name: "MinInt64 * 1 OK",
			a:    math.MinInt64, b: 1,
			want: math.MinInt64,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			if tt.shouldPanic {
				uassert.PanicsContains(t, tt.panicMsg, func() {
					safeMulInt64(tt.a, tt.b)
				})
			} else {
				result := safeMulInt64(tt.a, tt.b)
				uassert.Equal(t, result, tt.want)
			}
		})
	}
}
