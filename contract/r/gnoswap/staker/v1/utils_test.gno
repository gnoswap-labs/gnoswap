package v1

import (
	"math"
	"testing"

	uassert "gno.land/p/nt/uassert/v0"
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
		name     string
		input    uint64
		expected string
	}{
		{
			name:     "Success - uint64 min",
			input:    uint64(0),
			expected: "0",
		},
		{
			name:     "Success - uint64",
			input:    uint64(1),
			expected: "1",
		},
		{
			name:     "Success - uint64 1<<63",
			input:    uint64(9223372036854775808),
			expected: "9223372036854775808",
		},
		{
			name:     "Success - uint64 max",
			input:    uint64(math.MaxUint64),
			expected: "18446744073709551615",
		},
	}
	for _, tc := range tests {
		t.Run(tc.name, func(t *testing.T) {
			got := positionIdFrom(tc.input)
			uassert.Equal(t, tc.expected, string(got))
		})
	}
}
