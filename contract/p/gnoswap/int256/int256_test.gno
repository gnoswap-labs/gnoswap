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

func TestAbs(t *testing.T) {
	tests := []struct {
		x, want string
	}{
		{"0", "0"},
		{"1", "1"},
		{"-1", "1"},
		{"-2", "2"},
		{"57896044618658097711785492504343953926634992332820282019728792003956564819967", "57896044618658097711785492504343953926634992332820282019728792003956564819967"},
		{"-57896044618658097711785492504343953926634992332820282019728792003956564819967", "57896044618658097711785492504343953926634992332820282019728792003956564819967"},
	}

	for _, tc := range tests {
		x, err := FromDecimal(tc.x)
		if err != nil {
			t.Error(err)
			continue
		}

		got := x.Abs()

		if got.ToString() != tc.want {
			t.Errorf("Abs(%s) = %v, want %v", tc.x, got.ToString(), tc.want)
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

func TestAdd(t *testing.T) {
	maxIntStr := MaxInt256().ToString()

	tests := []struct {
		x, y, want string
	}{
		{"0", "1", "1"},
		{"1", "0", "1"},
		{"1", "1", "2"},
		{"1", "2", "3"},
		// NEGATIVE
		{"-1", "1", "0"},
		{"1", "-1", "0"},
		{"3", "-3", "0"},
		{"-1", "-1", "-2"},
		{"-1", "-2", "-3"},
		{"-1", "3", "2"},
		{"3", "-1", "2"},
		// BOUNDARY
		{maxIntStr, "0", maxIntStr},
	}

	for _, tc := range tests {
		x, err := FromDecimal(tc.x)
		if err != nil {
			t.Error(err)
			continue
		}

		y, err := FromDecimal(tc.y)
		if err != nil {
			t.Error(err)
			continue
		}

		want, err := FromDecimal(tc.want)
		if err != nil {
			t.Error(err)
			continue
		}

		got := Zero()
		got.Add(x, y)

		if got.Neq(want) {
			t.Errorf("Add(%s, %s) = %v, want %v", tc.x, tc.y, got.ToString(), want.ToString())
		}
	}
}

func TestAddOverflow(t *testing.T) {
	maxInt256 := MaxInt256()
	minInt256 := MinInt256()

	tests := []struct {
		name         string
		x            *Int
		y            *Int
		wantResult   string
		wantOverflow bool
	}{
		// Basic cases (no overflow)
		{
			name:         "positive + positive (no overflow)",
			x:            NewInt(100),
			y:            NewInt(200),
			wantResult:   "300",
			wantOverflow: false,
		},
		{
			name:         "negative + negative (no overflow)",
			x:            NewInt(-100),
			y:            NewInt(-200),
			wantResult:   "-300",
			wantOverflow: false,
		},
		// Boundary cases - near maximum value
		{
			name:         "max_int256 + 0",
			x:            maxInt256,
			y:            Zero(),
			wantResult:   maxInt256.ToString(),
			wantOverflow: false,
		},
		{
			name:         "max_int256 - 1 + 1",
			x:            new(Int).Sub(maxInt256, One()),
			y:            One(),
			wantResult:   maxInt256.ToString(),
			wantOverflow: false,
		},
		{
			name:         "max_int256 + 1",
			x:            maxInt256,
			y:            One(),
			wantResult:   "", // overflow
			wantOverflow: true,
		},

		// Boundary cases - near minimum value
		{
			name:         "min_int256 + 0",
			x:            minInt256,
			y:            Zero(),
			wantResult:   minInt256.ToString(),
			wantOverflow: false,
		},
		{
			name:         "min_int256 + 1 - 1",
			x:            new(Int).Add(minInt256, One()),
			y:            NewInt(-1),
			wantResult:   minInt256.ToString(),
			wantOverflow: false,
		},
		{
			name:         "min_int256 + (-1)",
			x:            minInt256,
			y:            NewInt(-1),
			wantResult:   "", // overflow
			wantOverflow: true,
		},

		// Special cases
		{
			name:         "max_int256 + min_int256",
			x:            maxInt256,
			y:            minInt256,
			wantResult:   "-1",
			wantOverflow: false,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			z := new(Int)
			gotResult, gotOverflow := z.AddOverflow(tt.x, tt.y)

			if gotOverflow != tt.wantOverflow {
				t.Errorf("overflow = %v, want %v", gotOverflow, tt.wantOverflow)
				return
			}

			if !gotOverflow {
				if gotResult == nil {
					t.Error("unexpected nil result for non-overflow case")
					return
				}
				if gotResult.ToString() != tt.wantResult {
					t.Errorf("result = %v, want %v", gotResult.ToString(), tt.wantResult)
				}
			}

			// Commutativity test only for non-overflow cases
			if !tt.wantOverflow {
				reverseResult, reverseOverflow := z.AddOverflow(tt.y, tt.x)
				if reverseOverflow != gotOverflow {
					t.Error("addition is not commutative for overflow")
				}
				if reverseResult.ToString() != gotResult.ToString() {
					t.Error("addition is not commutative for result")
				}
			}
		})
	}
}

func TestSub(t *testing.T) {
	maxInt := MaxInt256()
	maxIntStr := maxInt.ToString()
	maxIntMinusOneStr := new(Int).Sub(maxInt, One()).ToString()
	minIntStr := MinInt256().ToString()

	tests := []struct {
		x, y, want string
	}{
		{"1", "0", "1"},
		{"1", "1", "0"},
		{"-1", "1", "-2"},
		{"1", "-1", "2"},
		{"-1", "-1", "0"},
		{minIntStr, minIntStr, "0"},
		{minIntStr, "0", minIntStr},
		{maxIntStr, maxIntStr, "0"},
		{maxIntMinusOneStr, "-1", maxIntStr},
	}

	for _, tc := range tests {
		x, err := FromDecimal(tc.x)
		if err != nil {
			t.Error(err)
			continue
		}

		y, err := FromDecimal(tc.y)
		if err != nil {
			t.Error(err)
			continue
		}

		want, err := FromDecimal(tc.want)
		if err != nil {
			t.Error(err)
			continue
		}

		got := Zero()
		got.Sub(x, y)

		if got.Neq(want) {
			t.Errorf("Sub(%s, %s) = %v, want %v", tc.x, tc.y, got.ToString(), want.ToString())
		}
	}
}

func TestInt_SubOverflow(t *testing.T) {
	maxInt256 := MaxInt256()
	minInt256 := MinInt256()

	tests := []struct {
		name         string
		x            *Int
		y            *Int
		wantResult   string
		wantOverflow bool
	}{
		{
			name:         "positive - positive (no overflow)",
			x:            NewInt(200),
			y:            NewInt(100),
			wantResult:   "100",
			wantOverflow: false,
		},
		{
			name:         "negative - negative (no overflow)",
			x:            NewInt(-200),
			y:            NewInt(-300),
			wantResult:   "100",
			wantOverflow: false,
		},
		{
			name:         "positive - negative (no overflow)",
			x:            NewInt(200),
			y:            NewInt(-100),
			wantResult:   "300",
			wantOverflow: false,
		},
		{
			name:         "max_int256 - 0",
			x:            maxInt256,
			y:            Zero(),
			wantResult:   maxInt256.ToString(),
			wantOverflow: false,
		},
		{
			name:         "min_int256 - 0",
			x:            minInt256,
			y:            Zero(),
			wantResult:   minInt256.ToString(),
			wantOverflow: false,
		},
		{
			name:         "max_int256 - (-1)", // max_int256 + 1 -> overflow
			x:            maxInt256,
			y:            NewInt(-1),
			wantResult:   "",
			wantOverflow: true,
		},
		{
			name:         "min_int256 - 1", // min_int256 - 1 -> overflow
			x:            minInt256,
			y:            One(),
			wantResult:   "",
			wantOverflow: true,
		},
		{
			name:         "0 - 0",
			x:            Zero(),
			y:            Zero(),
			wantResult:   "0",
			wantOverflow: false,
		},
		{
			name:         "min_int256 - min_int256",
			x:            minInt256,
			y:            minInt256,
			wantResult:   "0",
			wantOverflow: false,
		},
		{
			name:         "max_int256 - max_int256",
			x:            maxInt256,
			y:            maxInt256,
			wantResult:   "0",
			wantOverflow: false,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			z := Zero()
			gotResult, gotOverflow := z.SubOverflow(tt.x, tt.y)

			if gotOverflow != tt.wantOverflow {
				t.Errorf("overflow = %v, want %v", gotOverflow, tt.wantOverflow)
				return
			}

			if !gotOverflow {
				if gotResult == nil {
					t.Error("unexpected nil result for non-overflow case")
					return
				}
				if gotResult.ToString() != tt.wantResult {
					t.Errorf("result = %v, want %v", gotResult.ToString(), tt.wantResult)
				}
			}
		})
	}
}

func TestMul(t *testing.T) {
	tests := []struct {
		x, y, want string
	}{
		{"5", "3", "15"},
		{"-5", "3", "-15"},
		{"5", "-3", "-15"},
		{"0", "3", "0"},
		{"3", "0", "0"},
	}

	for _, tc := range tests {
		x, err := FromDecimal(tc.x)
		if err != nil {
			t.Error(err)
			continue
		}

		y, err := FromDecimal(tc.y)
		if err != nil {
			t.Error(err)
			continue
		}

		want, err := FromDecimal(tc.want)
		if err != nil {
			t.Error(err)
			continue
		}

		got := Zero()
		got.Mul(x, y)

		if got.Neq(want) {
			t.Errorf("Mul(%s, %s) = %v, want %v", tc.x, tc.y, got.ToString(), want.ToString())
		}
	}
}

func TestInt_MulOverflow(t *testing.T) {
	maxInt256 := MaxInt256()
	minInt256 := MinInt256()

	tests := []struct {
		name         string
		x            *Int
		y            *Int
		wantResult   string
		wantOverflow bool
	}{
		{
			name:         "positive * positive (no overflow)",
			x:            NewInt(100),
			y:            NewInt(100),
			wantResult:   "10000",
			wantOverflow: false,
		},
		{
			name:         "negative * negative (no overflow)",
			x:            NewInt(-100),
			y:            NewInt(-100),
			wantResult:   "10000",
			wantOverflow: false,
		},
		{
			name:         "positive * negative (no overflow)",
			x:            NewInt(100),
			y:            NewInt(-100),
			wantResult:   "-10000",
			wantOverflow: false,
		},
		{
			name:         "0 * positive",
			x:            Zero(),
			y:            NewInt(100),
			wantResult:   "0",
			wantOverflow: false,
		},
		{
			name:         "positive * 0",
			x:            NewInt(100),
			y:            Zero(),
			wantResult:   "0",
			wantOverflow: false,
		},
		{
			name:         "0 * 0",
			x:            Zero(),
			y:            Zero(),
			wantResult:   "0",
			wantOverflow: false,
		},
		{
			name:         "max_int256 * 1",
			x:            maxInt256,
			y:            One(),
			wantResult:   maxInt256.ToString(),
			wantOverflow: false,
		},
		{
			name:         "min_int256 * 1",
			x:            minInt256,
			y:            One(),
			wantResult:   minInt256.ToString(),
			wantOverflow: false,
		},
		{
			name:         "min_int256 * -1",
			x:            minInt256,
			y:            NewInt(-1),
			wantResult:   "", // overflow because abs(min_int256) > max_int256
			wantOverflow: true,
		},
		{
			name:         "max_int256 * 2",
			x:            maxInt256,
			y:            NewInt(2),
			wantResult:   "",
			wantOverflow: true,
		},
		{
			name:         "min_int256 * 2",
			x:            minInt256,
			y:            NewInt(2),
			wantResult:   "",
			wantOverflow: true,
		},
		{
			name:         "half_max * 2",
			x:            MustFromDecimal("28948022309329048855892746252171976963317496332820282019728792003956564819983"), // (2^255-1)/2
			y:            NewInt(2),
			wantResult:   "",
			wantOverflow: true,
		},
		{
			name:         "(half_max + 1) * 2",
			x:            new(Int).Add(new(Int).Div(maxInt256, NewInt(2)), One()),
			y:            NewInt(2),
			wantResult:   "",
			wantOverflow: true,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			z := new(Int)
			gotResult, gotOverflow := z.MulOverflow(tt.x, tt.y)

			if gotOverflow != tt.wantOverflow {
				t.Errorf("overflow = %v, want %v", gotOverflow, tt.wantOverflow)
				return
			}

			if !gotOverflow {
				if gotResult == nil {
					t.Error("unexpected nil result for non-overflow case")
					return
				}
				if gotResult.ToString() != tt.wantResult {
					t.Errorf("result = %v, want %v", gotResult.ToString(), tt.wantResult)
				}
			}

			if !tt.wantOverflow {
				reverseResult, reverseOverflow := z.MulOverflow(tt.y, tt.x)
				if reverseOverflow != gotOverflow {
					t.Error("multiplication is not commutative for overflow")
				}
				if reverseResult.ToString() != gotResult.ToString() {
					t.Error("multiplication is not commutative for result")
				}
			}
		})
	}
}

func TestDiv(t *testing.T) {
	maxInt := MaxInt256()
	maxIntStr := maxInt.ToString()
	maxIntHalfStr := new(Int).Rsh(maxInt, 1).ToString()

	tests := []struct {
		x, y, expected string
	}{
		{"1", "1", "1"},
		{"0", "1", "0"},
		{"-1", "1", "-1"},
		{"1", "-1", "-1"},
		{"-1", "-1", "1"},
		{"-6", "3", "-2"},
		{"10", "-2", "-5"},
		{"-10", "3", "-3"},
		{"7", "3", "2"},
		{"-7", "3", "-2"},
		{maxIntStr, "2", maxIntHalfStr}, // Max int256 / 2
	}

	for _, tt := range tests {
		t.Run(tt.x+"/"+tt.y, func(t *testing.T) {
			x := MustFromDecimal(tt.x)
			y := MustFromDecimal(tt.y)
			result := Zero().Div(x, y)
			if result.ToString() != tt.expected {
				t.Errorf("Div(%s, %s) = %s, want %s", tt.x, tt.y, result.ToString(), tt.expected)
			}
			if result.IsZero() && result.IsNeg() {
				t.Errorf("Div(%s, %s) resulted in negative zero", tt.x, tt.y)
			}
		})
	}

	t.Run("Division by zero", func(t *testing.T) {
		defer func() {
			if r := recover(); r == nil {
				t.Errorf("Div(1, 0) did not panic")
			}
		}()
		x := MustFromDecimal("1")
		y := MustFromDecimal("0")
		Zero().Div(x, y)
	})
}

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

func TestEq(t *testing.T) {
	tests := []struct {
		x, y string
		want bool
	}{
		{"0", "0", true},
		{"0", "1", false},
		{"1", "0", false},
		{"-1", "0", false},
		{"0", "-1", false},
		{"1", "1", true},
		{"-1", "-1", true},
		{"57896044618658097711785492504343953926634992332820282019728792003956564819967", "-57896044618658097711785492504343953926634992332820282019728792003956564819967", false},
		{"-57896044618658097711785492504343953926634992332820282019728792003956564819967", "-57896044618658097711785492504343953926634992332820282019728792003956564819967", true},
	}

	for _, tc := range tests {
		x, err := FromDecimal(tc.x)
		if err != nil {
			t.Error(err)
			continue
		}

		y, err := FromDecimal(tc.y)
		if err != nil {
			t.Error(err)
			continue
		}

		got := x.Eq(y)
		if got != tc.want {
			t.Errorf("Eq(%s, %s) = %v, want %v", tc.x, tc.y, got, tc.want)
		}
	}
}

func TestNeq(t *testing.T) {
	tests := []struct {
		x, y string
		want bool
	}{
		{"0", "0", false},
		{"0", "1", true},
		{"1", "0", true},
		{"-1", "0", true},
		{"0", "-1", true},
		{"1", "1", false},
		{"-1", "-1", false},
		{"57896044618658097711785492504343953926634992332820282019728792003956564819967", "-57896044618658097711785492504343953926634992332820282019728792003956564819967", true},
		{"-57896044618658097711785492504343953926634992332820282019728792003956564819967", "-57896044618658097711785492504343953926634992332820282019728792003956564819967", false},
	}

	for _, tc := range tests {
		x, err := FromDecimal(tc.x)
		if err != nil {
			t.Error(err)
			continue
		}

		y, err := FromDecimal(tc.y)
		if err != nil {
			t.Error(err)
			continue
		}

		got := x.Neq(y)
		if got != tc.want {
			t.Errorf("Neq(%s, %s) = %v, want %v", tc.x, tc.y, got, tc.want)
		}
	}
}

func TestCmp(t *testing.T) {
	tests := []struct {
		x, y string
		want int
	}{
		{"0", "0", 0},
		{"0", "1", -1},
		{"1", "0", 1},
		{"-1", "0", -1},
		{"0", "-1", 1},
		{"1", "1", 0},
		{"57896044618658097711785492504343953926634992332820282019728792003956564819967", "-57896044618658097711785492504343953926634992332820282019728792003956564819967", 1},
	}

	for _, tc := range tests {
		x, err := FromDecimal(tc.x)
		if err != nil {
			t.Error(err)
			continue
		}

		y, err := FromDecimal(tc.y)
		if err != nil {
			t.Error(err)
			continue
		}

		got := x.Cmp(y)
		if got != tc.want {
			t.Errorf("Cmp(%s, %s) = %v, want %v", tc.x, tc.y, got, tc.want)
		}
	}
}

func TestIsZero(t *testing.T) {
	tests := []struct {
		x    string
		want bool
	}{
		{"0", true},
		{"-0", true},
		{"1", false},
		{"-1", false},
		{"10", false},
	}

	for _, tc := range tests {
		x, err := FromDecimal(tc.x)
		if err != nil {
			t.Error(err)
			continue
		}

		got := x.IsZero()
		if got != tc.want {
			t.Errorf("IsZero(%s) = %v, want %v", tc.x, got, tc.want)
		}
	}
}

func TestIsNeg(t *testing.T) {
	tests := []struct {
		x    string
		want bool
	}{
		{"0", false},
		{"-0", false}, // In two's complement, -0 is same as 0
		{"1", false},
		{"-1", true},
		{"10", false},
		{"-10", true},
	}

	for _, tc := range tests {
		x, err := FromDecimal(tc.x)
		if err != nil {
			t.Error(err)
			continue
		}

		got := x.IsNeg()
		if got != tc.want {
			t.Errorf("IsNeg(%s) = %v, want %v", tc.x, got, tc.want)
		}
	}
}

func TestLt(t *testing.T) {
	tests := []struct {
		x, y string
		want bool
	}{
		{"0", "0", false},
		{"0", "1", true},
		{"1", "0", false},
		{"-1", "0", true},
		{"0", "-1", false},
		{"1", "1", false},
		{"-1", "-1", false},
		{"57896044618658097711785492504343953926634992332820282019728792003956564819967", "-57896044618658097711785492504343953926634992332820282019728792003956564819967", false},
	}

	for _, tc := range tests {
		x, err := FromDecimal(tc.x)
		if err != nil {
			t.Error(err)
			continue
		}

		y, err := FromDecimal(tc.y)
		if err != nil {
			t.Error(err)
			continue
		}

		got := x.Lt(y)
		if got != tc.want {
			t.Errorf("Lt(%s, %s) = %v, want %v", tc.x, tc.y, got, tc.want)
		}
	}
}

func TestGt(t *testing.T) {
	tests := []struct {
		x, y string
		want bool
	}{
		{"0", "0", false},
		{"0", "1", false},
		{"1", "0", true},
		{"-1", "0", false},
		{"0", "-1", true},
		{"1", "1", false},
		{"-1", "-1", false},
		{"57896044618658097711785492504343953926634992332820282019728792003956564819967", "-57896044618658097711785492504343953926634992332820282019728792003956564819967", true},
	}

	for _, tc := range tests {
		x, err := FromDecimal(tc.x)
		if err != nil {
			t.Error(err)
			continue
		}

		y, err := FromDecimal(tc.y)
		if err != nil {
			t.Error(err)
			continue
		}

		got := x.Gt(y)
		if got != tc.want {
			t.Errorf("Gt(%s, %s) = %v, want %v", tc.x, tc.y, got, tc.want)
		}
	}
}

func TestClone(t *testing.T) {
	tests := []struct {
		x string
	}{
		{"0"},
		{"-0"},
		{"1"},
		{"-1"},
		{"10"},
		{"-10"},
		{"57896044618658097711785492504343953926634992332820282019728792003956564819967"},
		{"-57896044618658097711785492504343953926634992332820282019728792003956564819967"},
	}

	for _, tc := range tests {
		x, err := FromDecimal(tc.x)
		if err != nil {
			t.Error(err)
			continue
		}

		y := x.Clone()

		if x.Cmp(y) != 0 {
			t.Errorf("Clone(%s) = %v, want %v", tc.x, y, x)
		}
	}
}

func TestNilChecks(t *testing.T) {
	validInt := NewInt(123)

	tests := []struct {
		name string
		fn   func()
	}{
		{
			name: "Eq with nil",
			fn:   func() { validInt.Eq(nil) },
		},
		{
			name: "Neq with nil",
			fn:   func() { validInt.Neq(nil) },
		},
		{
			name: "Cmp with nil",
			fn:   func() { validInt.Cmp(nil) },
		},
		{
			name: "Lt with nil",
			fn:   func() { validInt.Lt(nil) },
		},
		{
			name: "Gt with nil",
			fn:   func() { validInt.Gt(nil) },
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			defer func() {
				r := recover()
				if r == nil {
					t.Errorf("%s: expected panic but got none", tt.name)
				}
				// Any panic (nil pointer or custom message) is acceptable
			}()

			tt.fn()
		})
	}
}

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
				if !z.IsNeg() {
					t.Errorf("SetInt64(%d): expected IsNegative()=true, got false", tc.x)
				}
			} else if tc.x > 0 {
				if z.IsNeg() {
					t.Errorf("SetInt64(%d): expected IsNegative()=false, got true", tc.x)
				}
			} else { // tc.x == 0
				if z.IsNeg() {
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
		// In two's complement, -1 = 0xFFFF...FFFF, so z[0] = max uint64
		{"-1", 18446744073709551615},
		{"-18446744073709551615", 1},
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
			name: "Zero",
			setupInt: func() *Int {
				return Zero()
			},
			want:        0,
			description: "Zero should return 0",
		},
		{
			name: "Large positive int256",
			setupInt: func() *Int {
				// Value larger than int64 max
				return MustFromDecimal("18446744073709551615")
			},
			want:        -1, // Truncated to int64
			description: "Large positive wraps in int64",
		},
		{
			name: "Large negative int256",
			setupInt: func() *Int {
				return MustFromDecimal("-18446744073709551615")
			},
			want:        1, // Truncated to int64
			description: "Large negative wraps in int64",
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
