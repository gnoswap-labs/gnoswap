package int256

import (
	"testing"

	"gno.land/p/gnoswap/uint256"
	"gno.land/p/nt/uassert"
)

func TestFromDecimal(t *testing.T) {
	tests := []struct {
		input   string
		wantErr bool
		want    string
	}{
		{"0", false, "0"},
		{"1", false, "1"},
		{"-1", false, "-1"},
		{"+1", false, "1"},
		{"0000000123456789", false, "123456789"},
		{"-0000000123456789", false, "-123456789"},
		{"00000000000000000000000000000000000000000000000000000000000000000000000000000000", false, "0"},
		{"0000000+123456789", true, ""},
		{"0000000+-123456789", true, ""},
		{"123456789", false, "123456789"},
		{"-123456789", false, "-123456789"},
		{"57896044618658097711785492504343953926634992332820282019728792003956564819967", false, "57896044618658097711785492504343953926634992332820282019728792003956564819967"},
		{"-57896044618658097711785492504343953926634992332820282019728792003956564819968", false, "-57896044618658097711785492504343953926634992332820282019728792003956564819968"},
		// overflow cases
		{"57896044618658097711785492504343953926634992332820282019728792003956564819968", true, ""},
		{"-57896044618658097711785492504343953926634992332820282019728792003956564819969", true, ""},
		// invalid inputs
		{"", true, ""},
		{"abc", true, ""},
		{"12.34", true, ""},
	}

	for _, tc := range tests {
		z, err := FromDecimal(tc.input)
		if tc.wantErr {
			if err == nil {
				t.Errorf("FromDecimal(%q) expected error, got nil", tc.input)
			}
			continue
		}
		if err != nil {
			t.Errorf("FromDecimal(%q) unexpected error: %v", tc.input, err)
			continue
		}
		if z.ToString() != tc.want {
			t.Errorf("FromDecimal(%q) = %s, want %s", tc.input, z.ToString(), tc.want)
		}
	}
}

func TestMustFromDecimal(t *testing.T) {
	// Valid cases should not panic
	validCases := []string{
		"0", "1", "-1", "123456789",
		"57896044618658097711785492504343953926634992332820282019728792003956564819967",
	}

	for _, tc := range validCases {
		func() {
			defer func() {
				if r := recover(); r != nil {
					t.Errorf("MustFromDecimal(%q) panicked unexpectedly: %v", tc, r)
				}
			}()
			z := MustFromDecimal(tc)
			if z == nil {
				t.Errorf("MustFromDecimal(%q) returned nil", tc)
			}
		}()
	}

	// Invalid cases should panic
	invalidCases := []string{
		"", "abc", "12.34",
		"57896044618658097711785492504343953926634992332820282019728792003956564819968",
	}

	for _, tc := range invalidCases {
		func() {
			defer func() {
				if r := recover(); r == nil {
					t.Errorf("MustFromDecimal(%q) should have panicked", tc)
				}
			}()
			MustFromDecimal(tc)
		}()
	}
}

func TestFromUint256(t *testing.T) {
	tests := []struct {
		name        string
		input       *uint256.Uint
		expect      string
		shouldPanic bool
	}{
		{name: "zero", input: uint256.NewUint(0), expect: "0"},
		{name: "one", input: uint256.NewUint(1), expect: "1"},
		{name: "max uint64", input: uint256.NewUint(^uint64(0)), expect: "18446744073709551615"},
		{
			name:   "max int256",
			input:  uint256.MustFromDecimal("57896044618658097711785492504343953926634992332820282019728792003956564819967"),
			expect: "57896044618658097711785492504343953926634992332820282019728792003956564819967",
		},
		{
			name:        "overflow at 2^255",
			input:       uint256.MustFromDecimal("57896044618658097711785492504343953926634992332820282019728792003956564819968"),
			shouldPanic: true,
		},
		{
			name:        "max uint256 overflows",
			input:       uint256.MustFromDecimal("115792089237316195423570985008687907853269984665640564039457584007913129639935"),
			shouldPanic: true,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			if tt.shouldPanic {
				uassert.PanicsContains(t, "int256: overflow", func() {
					FromUint256(tt.input)
				})
				return
			}

			got := FromUint256(tt.input)
			uassert.Equal(t, tt.expect, got.ToString())
		})
	}
}
