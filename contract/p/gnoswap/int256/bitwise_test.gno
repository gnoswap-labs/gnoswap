package int256

import (
	"testing"

	"gno.land/p/nt/uassert"
)

func TestOr(t *testing.T) {
	tests := []struct {
		name       string
		x, y, want string
	}{
		{"all zeroes", "0", "0", "0"},
		{"all ones", "-1", "-1", "-1"},
		{"mixed", "-1", "0", "-1"},
	}

	for _, tc := range tests {
		t.Run(tc.name, func(t *testing.T) {
			x := MustFromDecimal(tc.x)
			y := MustFromDecimal(tc.y)
			want := MustFromDecimal(tc.want)

			got := Zero()
			got.Or(x, y)

			if got.Neq(want) {
				t.Errorf("Or(%s, %s) = %s, want %s", tc.x, tc.y, got.ToString(), tc.want)
			}
		})
	}
}

func TestAnd(t *testing.T) {
	tests := []struct {
		name       string
		x, y, want string
	}{
		{"all zeroes", "0", "0", "0"},
		{"all ones", "-1", "-1", "-1"},
		{"mixed", "0", "-1", "0"},
		{"mixed 2", "-1", "0", "0"},
	}

	for _, tc := range tests {
		t.Run(tc.name, func(t *testing.T) {
			x := MustFromDecimal(tc.x)
			y := MustFromDecimal(tc.y)
			want := MustFromDecimal(tc.want)

			got := Zero()
			got.And(x, y)

			if got.Neq(want) {
				t.Errorf("And(%s, %s) = %s, want %s", tc.x, tc.y, got.ToString(), tc.want)
			}
		})
	}
}

func TestLsh(t *testing.T) {
	tests := []struct {
		name     string
		x        string
		n        uint
		expected string
	}{
		{
			name:     "n is equal 0",
			x:        "100",
			n:        0,
			expected: "100",
		},
		{
			name:     "n is greater than or equal 256",
			x:        "-4125871947195612497219427349",
			n:        256,
			expected: "0",
		},
		{
			name:     "x is non-neg & n is smaller than 256 and greater than or equal 192",
			x:        "57896044618658097711785492504343953926634992332820282019728792003956564819967",
			n:        200,
			expected: "-1606938044258990275541962092341162602522202993782792835301376",
		},
		{
			name:     "x is non-neg & n is smaller than 192 and greater than or equal 128",
			x:        "57896044618658097711785492504343953926634992332820282019728792003956564819967",
			n:        150,
			expected: "-1427247692705959881058285969449495136382746624",
		},
		{
			name:     "x is non-neg & n is smaller than 128 and greater than or equal 64",
			x:        "57896044618658097711785492504343953926634992332820282019728792003956564819967",
			n:        100,
			expected: "-1267650600228229401496703205376",
		},
		{
			name:     "x is non-neg & n is smaller than 64",
			x:        "57896044618658097711785492504343953926634992332820282019728792003956564819967",
			n:        32,
			expected: "-4294967296",
		},
		{
			name:     "x is neg & n is smaller than 256 and greater than or equal 192",
			x:        "-11111",
			n:        200,
			expected: "-17854688609761640951546740808002657676624197463920611193033588736",
		},
		{
			name:     "x is neg & n is smaller than 192 and greater than or equal 128",
			x:        "-11111",
			n:        150,
			expected: "-15858149113655920238438615406553340460348697739264",
		},
		{
			name:     "x is neg & n is smaller than 128 and greater than or equal 64",
			x:        "-11111",
			n:        100,
			expected: "-14084865819135856880029869314932736",
		},
		{
			name:     "x is neg & n is smaller than 64",
			x:        "-11111",
			n:        32,
			expected: "-47721381625856",
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			x := MustFromDecimal(tt.x)
			z := new(Int).Lsh(x, tt.n)
			uassert.Equal(t, tt.expected, z.ToString())
		})
	}
}

func TestRsh(t *testing.T) {
	tests := []struct {
		name     string
		x        string
		n        uint
		expected string
	}{
		{
			name:     "n is equal 0",
			x:        "100",
			n:        0,
			expected: "100",
		},
		{
			name:     "x is non-neg & n is greater than or equal 255",
			x:        "431247391574329147932",
			n:        255,
			expected: "0",
		},
		{
			name:     "x is non-neg & n is smaller than 256 and greater than or equal 192",
			x:        "57896044618658097711785492504343953926634992332820282019728792003956564819967",
			n:        200,
			expected: "36028797018963967",
		},
		{
			name:     "x is non-neg & n is smaller than 192 and greater than or equal 128",
			x:        "57896044618658097711785492504343953926634992332820282019728792003956564819967",
			n:        150,
			expected: "40564819207303340847894502572031",
		},
		{
			name:     "x is non-neg & n is smaller than 128 and greater than or equal 64",
			x:        "57896044618658097711785492504343953926634992332820282019728792003956564819967",
			n:        100,
			expected: "45671926166590716193865151022383844364247891967",
		},
		{
			name:     "x is non-neg & n is smaller than 64",
			x:        "57896044618658097711785492504343953926634992332820282019728792003956564819967",
			n:        32,
			expected: "13479973333575319897333507543509815336818572211270286240551805124607",
		},
		{
			name:     "x is neg & n is smaller than 256 and greater than or equal 192",
			x:        "-11111",
			n:        200,
			expected: "-1",
		},
		{
			name:     "x is neg & n is smaller than 192 and greater than or equal 128",
			x:        "-11111",
			n:        150,
			expected: "-1",
		},
		{
			name:     "x is neg & n is smaller than 128 and greater than or equal 64",
			x:        "-11111",
			n:        100,
			expected: "-1",
		},
		{
			name:     "x is neg & n is smaller than 64",
			x:        "-11111",
			n:        2,
			expected: "-2778",
		},
		{
			name:     "x is neg & n is greater than or equal 255",
			x:        "-11111",
			n:        255,
			expected: "-1",
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			x := MustFromDecimal(tt.x)
			z := new(Int).Rsh(x, tt.n)
			uassert.Equal(t, tt.expected, z.ToString())
		})
	}
}

func TestLsh_NoPanic(t *testing.T) {
	x := MustFromDecimal("-12345678901234567890")

	for n := uint(0); n < 300; n++ {
		uassert.NotPanics(t, func() {
			_ = new(Int).Lsh(x, n)
		})
	}
}

func TestRsh_NoPanic(t *testing.T) {
	x := MustFromDecimal("-12345678901234567890")

	for n := uint(0); n < 300; n++ {
		uassert.NotPanics(t, func() {
			_ = new(Int).Rsh(x, n)
		})
	}
}

func TestRsh_SignExtendProperty(t *testing.T) {
	// For all negative integers, Rsh should satisfy:
	//  - Rsh(x, n) <= 0
	//  - Rsh(x, n+1) == Rsh(Rsh(x,n), 1)
	x := MustFromDecimal("-11111")

	for n := uint(0); n < 255; n++ {
		z := new(Int).Rsh(x, n)
		zz := new(Int).Rsh(z, 1)
		z2 := new(Int).Rsh(x, n+1)

		uassert.Equal(t, z2.ToString(), zz.ToString())
	}
}
