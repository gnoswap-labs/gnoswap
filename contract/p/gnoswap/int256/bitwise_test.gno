package int256

import (
	"testing"

	"gno.land/p/gnoswap/uint256"
)

func TestOr(t *testing.T) {
	tests := []struct {
		name       string
		x, y, want Int
	}{
		{
			name: "all zeroes",
			x:    Int{abs: uint256.Zero(), neg: false},
			y:    Int{abs: uint256.Zero(), neg: false},
			want: Int{abs: uint256.Zero(), neg: false},
		},
		{
			name: "all ones",
			x:    Int{abs: uint256.NewUint(0).SetAllOne(), neg: false},
			y:    Int{abs: uint256.NewUint(0).SetAllOne(), neg: false},
			want: Int{abs: uint256.NewUint(0).SetAllOne(), neg: false},
		},
		{
			name: "mixed",
			x:    Int{abs: uint256.NewUint(0).SetAllOne(), neg: false},
			y:    Int{abs: uint256.NewUint(0), neg: false},
			want: Int{abs: uint256.NewUint(0).SetAllOne(), neg: false},
		},
	}

	for _, tc := range tests {
		t.Run(tc.name, func(t *testing.T) {
			got := New()
			got.Or(&tc.x, &tc.y)

			if got.Neq(&tc.want) {
				t.Errorf("Or(%v, %v) = %v, want %v", tc.x, tc.y, got, tc.want)
			}
		})
	}
}

func TestAnd(t *testing.T) {
	tests := []struct {
		name       string
		x, y, want Int
	}{
		{
			name: "all zeroes",
			x:    Int{abs: uint256.Zero(), neg: false},
			y:    Int{abs: uint256.Zero(), neg: false},
			want: Int{abs: uint256.Zero(), neg: false},
		},
		{
			name: "all ones",
			x:    Int{abs: uint256.NewUint(0).SetAllOne(), neg: false},
			y:    Int{abs: uint256.NewUint(0).SetAllOne(), neg: false},
			want: Int{abs: uint256.NewUint(0).SetAllOne(), neg: false},
		},
		{
			name: "mixed",
			x:    Int{abs: uint256.Zero(), neg: false},
			y:    Int{abs: uint256.NewUint(0).SetAllOne(), neg: false},
			want: Int{abs: uint256.Zero(), neg: false},
		},
		{
			name: "mixed 2",
			x:    Int{abs: uint256.NewUint(0).SetAllOne(), neg: false},
			y:    Int{abs: uint256.Zero(), neg: false},
			want: Int{abs: uint256.Zero(), neg: false},
		},
		{
			name: "mixed 3",
			x:    Int{abs: uint256.NewUint(0).SetAllOne(), neg: false},
			y:    Int{abs: uint256.Zero(), neg: false},
			want: Int{abs: uint256.Zero(), neg: false},
		},
		{
			name: "one operand zero",
			x:    Int{abs: uint256.Zero(), neg: false},
			y:    Int{abs: uint256.NewUint(0).SetAllOne(), neg: false},
			want: Int{abs: uint256.Zero(), neg: false},
		},
		{
			name: "one operand all ones",
			x:    Int{abs: uint256.NewUint(0).SetAllOne(), neg: false},
			y:    Int{abs: uint256.NewUint(0).SetAllOne(), neg: false},
			want: Int{abs: uint256.NewUint(0).SetAllOne(), neg: false},
		},
	}

	for _, tc := range tests {
		t.Run(tc.name, func(t *testing.T) {
			got := New()
			got.And(&tc.x, &tc.y)

			if got.Neq(&tc.want) {
				t.Errorf("And(%v, %v) = %v, want %v", tc.x, tc.y, got, tc.want)
			}
		})
	}
}

func TestRsh(t *testing.T) {
	tests := []struct {
		x    string
		n    uint
		want string
	}{
		{"1024", 0, "1024"},
		{"1024", 1, "512"},
		{"1024", 2, "256"},
		{"1024", 10, "1"},
		{"1024", 11, "0"},
		{"18446744073709551615", 0, "18446744073709551615"},
		{"18446744073709551615", 1, "9223372036854775807"},
		{"18446744073709551615", 62, "3"},
		{"18446744073709551615", 63, "1"},
		{"18446744073709551615", 64, "0"},
		{"115792089237316195423570985008687907853269984665640564039457584007913129639935", 0, "115792089237316195423570985008687907853269984665640564039457584007913129639935"},
		{"115792089237316195423570985008687907853269984665640564039457584007913129639935", 1, "57896044618658097711785492504343953926634992332820282019728792003956564819967"},
		{"115792089237316195423570985008687907853269984665640564039457584007913129639935", 128, "340282366920938463463374607431768211455"},
		{"115792089237316195423570985008687907853269984665640564039457584007913129639935", 255, "1"},
		{"115792089237316195423570985008687907853269984665640564039457584007913129639935", 256, "0"},
		{"-1024", 0, "-1024"},
		{"-1024", 1, "-512"},
		{"-1024", 2, "-256"},
		{"-1024", 10, "-1"},
		{"-1024", 10, "-1"},
		{"-9223372036854775808", 0, "-9223372036854775808"},
		{"-9223372036854775808", 1, "-4611686018427387904"},
		{"-9223372036854775808", 62, "-2"},
		{"-9223372036854775808", 63, "-1"},
		{"-9223372036854775808", 64, "-1"},
		{"-57896044618658097711785492504343953926634992332820282019728792003956564819968", 0, "-57896044618658097711785492504343953926634992332820282019728792003956564819968"},
		{"-57896044618658097711785492504343953926634992332820282019728792003956564819968", 1, "-28948022309329048855892746252171976963317496166410141009864396001978282409984"},
		{"-57896044618658097711785492504343953926634992332820282019728792003956564819968", 253, "-4"},
		{"-57896044618658097711785492504343953926634992332820282019728792003956564819968", 254, "-2"},
		{"-57896044618658097711785492504343953926634992332820282019728792003956564819968", 255, "-1"},
		{"-57896044618658097711785492504343953926634992332820282019728792003956564819968", 256, "-1"},
	}

	for _, tc := range tests {
		x, err := FromDecimal(tc.x)
		if err != nil {
			t.Error(err)
			continue
		}

		got := New()
		got.Rsh(x, tc.n)

		if got.ToString() != tc.want {
			t.Errorf("Rsh(%s, %d) = %v, want %v", tc.x, tc.n, got.ToString(), tc.want)
		}
	}
}

func TestRshOptimized(t *testing.T) {
	tests := []struct {
		name string
		x    string
		n    uint
		want string
	}{
		{
			name: "positive_no_shift",
			x:    "1024",
			n:    0,
			want: "1024",
		},
		{
			name: "positive_basic_shift",
			x:    "1024",
			n:    1,
			want: "512",
		},
		{
			name: "positive_complete_shift",
			x:    "1024",
			n:    10,
			want: "1",
		},
		{
			name: "positive_overflow_shift",
			x:    "1024",
			n:    11,
			want: "0",
		},
		{
			name: "negative_no_shift",
			x:    "-1024",
			n:    0,
			want: "-1024",
		},
		{
			name: "negative_basic_shift",
			x:    "-1024",
			n:    1,
			want: "-512",
		},
		{
			name: "negative_preserve_sign",
			x:    "-1024",
			n:    10,
			want: "-1",
		},
		{
			name: "negative_one_shift",
			x:    "-1",
			n:    1,
			want: "-1",
		},
		{
			name: "negative_one_large_shift",
			x:    "-1",
			n:    100,
			want: "-1",
		},
		{
			name: "negative_one_max_shift",
			x:    "-1",
			n:    255,
			want: "-1",
		},
		{
			name: "int64_max",
			x:    "9223372036854775807",
			n:    1,
			want: "4611686018427387903",
		},
		{
			name: "int64_min",
			x:    "-9223372036854775808",
			n:    1,
			want: "-4611686018427387904",
		},
		{
			name: "int64_min_63_shift",
			x:    "-9223372036854775808",
			n:    63,
			want: "-1",
		},
		{
			name: "max_int256",
			x:    "57896044618658097711785492504343953926634992332820282019728792003956564819967",
			n:    1,
			want: "28948022309329048855892746252171976963317496166410141009864396001978282409983",
		},
		{
			name: "min_int256",
			x:    "-57896044618658097711785492504343953926634992332820282019728792003956564819968",
			n:    1,
			want: "-28948022309329048855892746252171976963317496166410141009864396001978282409984",
		},
		{
			name: "min_int256_254_shift",
			x:    "-57896044618658097711785492504343953926634992332820282019728792003956564819968",
			n:    254,
			want: "-2",
		},
		{
			name: "min_int256_255_shift",
			x:    "-57896044618658097711785492504343953926634992332820282019728792003956564819968",
			n:    255,
			want: "-1",
		},
		{
			name: "positive_256_shift",
			x:    "115792089237316195423570985008687907853269984665640564039457584007913129639935",
			n:    256,
			want: "0",
		},
		{
			name: "negative_256_shift",
			x:    "-57896044618658097711785492504343953926634992332820282019728792003956564819968",
			n:    256,
			want: "-1",
		},
		{
			name: "negative_power_of_two",
			x:    "-256", // -2^8
			n:    7,
			want: "-2",
		},
		{
			name: "negative_power_of_two_exact",
			x:    "-256",
			n:    8,
			want: "-1",
		},
		{
			name: "verify_arithmetic_shift_1",
			x:    "-5",
			n:    1,
			want: "-3", // -5 >> 1 = -3 (not -2)
		},
		{
			name: "verify_arithmetic_shift_2",
			x:    "-6",
			n:    1,
			want: "-3",
		},
		{
			name: "verify_arithmetic_shift_3",
			x:    "-7",
			n:    1,
			want: "-4", // -7 >> 1 = -4 (not -3)
		},
		{
			name: "verify_arithmetic_shift_4",
			x:    "-8",
			n:    1,
			want: "-4",
		},
	}

	for _, tc := range tests {
		t.Run(tc.name, func(t *testing.T) {
			x, err := FromDecimal(tc.x)
			if err != nil {
				t.Fatal(err)
			}

			got := new(Int).Rsh(x, tc.n)

			if got.ToString() != tc.want {
				t.Errorf("Rsh(%s, %d) = %s, want %s", tc.x, tc.n, got.ToString(), tc.want)
			}

			if tc.n < 10 {
				var nilZ *Int
				result := nilZ.Rsh(x, tc.n)
				if result == nil {
					t.Error("Rsh with nil receiver returned nil")
				}
			}
		})
	}
}

func TestRshPerformance(t *testing.T) {
	x := MustFromDecimal("-57896044618658097711785492504343953926634992332820282019728792003956564819968")

	shifts := []uint{1, 10, 63, 64, 127, 128, 255}

	for _, n := range shifts {
		result := new(Int).Rsh(x, n)
		if result.abs == nil {
			t.Errorf("Rsh returned invalid result for shift %d", n)
		}
	}
}

func TestRshTwosComplement(t *testing.T) {
	testCases := []struct {
		x    int64
		n    uint
		want int64
	}{
		{-1, 1, -1},
		{-2, 1, -1},
		{-3, 1, -2},
		{-4, 1, -2},
		{-5, 1, -3},
		{-128, 1, -64},
		{-256, 1, -128},
	}

	for _, tc := range testCases {
		x := NewInt(tc.x)
		got := new(Int).Rsh(x, tc.n)
		gotInt64 := got.Int64()

		if gotInt64 != tc.want {
			t.Errorf("Rsh(%d, %d) = %d, want %d", tc.x, tc.n, gotInt64, tc.want)
		}
	}
}

func TestLsh(t *testing.T) {
	tests := []struct {
		x    string
		n    uint
		want string
	}{
		{"1", 0, "1"},
		{"1", 1, "2"},
		{"1", 2, "4"},
		{"2", 0, "2"},
		{"2", 1, "4"},
		{"2", 2, "8"},
		{"-2", 0, "-2"},
		{"-4", 0, "-4"},
		{"-8", 0, "-8"},
		{"-1", 255, "-57896044618658097711785492504343953926634992332820282019728792003956564819968"},
		{"-1", 256, "0"},
		{"-2", 255, "0"},
		{"-4", 254, "0"},
		{"-8", 253, "0"},
	}

	for _, tc := range tests {
		x, err := FromDecimal(tc.x)
		if err != nil {
			t.Error(err)
			continue
		}

		got := New()
		got.Lsh(x, tc.n)

		if got.ToString() != tc.want {
			t.Errorf("Lsh(%s, %d) = %v, want %v", tc.x, tc.n, got.ToString(), tc.want)
		}
	}
}
