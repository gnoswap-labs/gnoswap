package int256

import "testing"

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
			// z := new(Int)
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
