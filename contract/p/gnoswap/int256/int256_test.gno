// ported from github.com/mempooler/int256
package int256

import (
	"testing"

	"gno.land/p/nt/uassert"
	"gno.land/p/nt/ufmt"
)

func TestSign(t *testing.T) {
	tests := []struct {
		x    string
		want int
	}{
		{"0", 0},
		{"1", 1},
		{"-1", -1},
	}

	for _, tt := range tests {
		z := MustFromDecimal(tt.x)
		got := z.Sign()
		if got != tt.want {
			t.Errorf("Sign(%s) = %d, want %d", tt.x, got, tt.want)
		}
	}
}

func TestSetString(t *testing.T) {
	tests := []struct {
		input    string
		wantErr  bool
		wantVal  string
		wantSign bool
	}{
		{"123", false, "123", false},
		{"+123", false, "123", false},
		{"-123", false, "123", true},
		{"9223372036854775807", false, "9223372036854775807", false},
		{"-9223372036854775808", false, "9223372036854775808", true},

		{"++123", true, "", false},
		{"--123", true, "", false},
		{"+-123", true, "", false},
		{"-+123", true, "", false},
		{"+++123", true, "", false},
		{"---123", true, "", false},
		{"+-+-123", true, "", false},
		{"922337203-6854775807", true, "", false},

		{"1+23", true, "", false},
		{"1-23", true, "", false},
		{"12+3", true, "", false},

		// scientific notation not allowed
		{"-1e23", true, "", false},
		{"1e-23", true, "", false},
		{"1e+23", true, "", false},

		{"", true, "", false},
		{"+", true, "", false},
		{"-", true, "", false},
		{"+-", true, "", false},
	}

	for _, tt := range tests {
		z, err := new(Int).SetString(tt.input)

		if tt.wantErr {
			if err == nil {
				t.Errorf("SetString(%q) = %v, want error", tt.input, z)
			}
			continue
		}

		if err != nil {
			println("ERROR", err.Error(), tt.input)
			t.Errorf("SetString(%q) returned unexpected error: %v", tt.input, err)
			continue
		}

		if got := z.Abs().ToString(); got != tt.wantVal {
			t.Errorf("SetString(%q).abs = %s, want %s", tt.input, got, tt.wantVal)
		}

		if got := z.IsNeg(); got != tt.wantSign {
			t.Errorf("SetString(%q).neg = %v, want %v", tt.input, got, tt.wantSign)
		}
	}
}

func TestAbsWithPanicCases(t *testing.T) {
	tests := []struct {
		x, want   string
		wantErr   bool
		wantPanic bool
	}{
		{"0", "0", false, false},
		{"1", "1", false, false},
		{"-1", "1", false, false},
		{"-2", "2", false, false},
		// Int256 min value overflow: out of range, FromDecimal should error
		{"-115792089237316195423570985008687907853269984665640564039457584007913129639935", "", true, false},
		// Int256 most negative value: FromDecimal succeeds, Abs() panics
		{"-57896044618658097711785492504343953926634992332820282019728792003956564819968", "57896044618658097711785492504343953926634992332820282019728792003956564819968", false, true},
	}

	for _, tc := range tests {
		x, err := FromDecimal(tc.x)

		// Check if FromDecimal returned expected error
		if tc.wantErr {
			if err == nil {
				t.Errorf("FromDecimal(%s) expected error, but got nil", tc.x)
			}
			continue
		}

		// If we expect no error, but got one
		if err != nil {
			t.Errorf("FromDecimal(%s) returned unexpected error: %v", tc.x, err)
			continue
		}

		// At this point, x should not be nil
		if x == nil {
			t.Errorf("FromDecimal(%s) returned nil without error", tc.x)
			continue
		}

		if tc.wantPanic {
			uassert.PanicsContains(t, "int256: overflow", func() {
				x.Abs()
			})
			ufmt.Printf("Abs(%s) correctly panicked with overflow\n", tc.x)
		} else {
			got := x.Abs()
			if got.ToString() != tc.want {
				t.Errorf("Abs(%s) = %v, want %v", tc.x, got.ToString(), tc.want)
			}
		}
	}
}
