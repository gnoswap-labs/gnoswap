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
		{"-57896044618658097711785492504343953926634992332820282019728792003956564819968", -1},
		{"57896044618658097711785492504343953926634992332820282019728792003956564819967", 1},
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
		x, want             string
		expectedHasOverflow bool
	}{
		{"0", "0", false},
		{"1", "1", false},
		{"-1", "1", false},
		{"-2", "2", false},
		{"57896044618658097711785492504343953926634992332820282019728792003956564819967", "57896044618658097711785492504343953926634992332820282019728792003956564819967", false},
		{"-57896044618658097711785492504343953926634992332820282019728792003956564819967", "57896044618658097711785492504343953926634992332820282019728792003956564819967", false},
		// MinInt256 overflows when taking Abs
		{"-57896044618658097711785492504343953926634992332820282019728792003956564819968", "", true},
	}

	for _, tc := range tests {
		x, err := FromDecimal(tc.x)
		if err != nil {
			t.Error(err)
			continue
		}

		if tc.expectedHasOverflow {
			uassert.PanicsContains(t, "int256: overflow", func() {
				x.Abs()
			})
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
		{"-57896044618658097711785492504343953926634992332820282019728792003956564819967", "57896044618658097711785492504343953926634992332820282019728792003956564819967", false, false},
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
	tests := []struct {
		name     string
		x        string
		y        string
		expected string
	}{
		{
			name:     "large negative + small negative overflow",
			x:        "-57896044618658097711785492504343953926634992332820282019728792003956564606844",
			y:        "-431294739547329532759",
			expected: "57896044618658097711785492504343953926634992332820282019297497264409235500333",
		},
		{
			name:     "min negative + min negative overflow",
			x:        "-57896044618658097711785492504343953926634992332820282019728792003956564819968",
			y:        "-57896044618658097711785492504343953926634992332820282019728792003956564819968",
			expected: "0",
		},
		{
			name:     "max positive + min negative",
			x:        "57896044618658097711785492504343953926634992332820282019728792003956564819967",
			y:        "-57896044618658097711785492504343953926634992332820282019728792003956564819968",
			expected: "-1",
		},
		{
			name:     "small positive + large negative",
			x:        "10000",
			y:        "-2000000",
			expected: "-1990000",
		},
		{
			name:     "max positive + max positive overflow",
			x:        "57896044618658097711785492504343953926634992332820282019728792003956564819967",
			y:        "57896044618658097711785492504343953926634992332820282019728792003956564819967",
			expected: "-2",
		},
		{
			name:     "large positive + large positive overflow",
			x:        "57896044618658097711785492504343953926634992332820282019728792003956564819961",
			y:        "431405283104328105143242031570231414",
			expected: "-57896044618658097711785492504343953926634560927537177691623648761924994588561",
		},
		{
			name:     "large positive + one overflow",
			x:        "57896044618658097711785492504343953926634992332820282019728792003956564819967",
			y:        "1",
			expected: "-57896044618658097711785492504343953926634992332820282019728792003956564819968",
		},
		{
			name:     "min negative + negative one overflow",
			x:        "-57896044618658097711785492504343953926634992332820282019728792003956564819968",
			y:        "-1",
			expected: "57896044618658097711785492504343953926634992332820282019728792003956564819967",
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			x := MustFromDecimal(tt.x)
			y := MustFromDecimal(tt.y)
			z := new(Int).Add(x, y)
			uassert.Equal(t, tt.expected, z.ToString())
		})
	}
}

func TestAddOverflow(t *testing.T) {
	tests := []struct {
		name             string
		x                string
		y                string
		expected         string
		expectedOverflow bool
	}{
		{
			name:             "large negative + small negative overflow",
			x:                "-57896044618658097711785492504343953926634992332820282019728792003956564606844",
			y:                "-431294739547329532759",
			expected:         "57896044618658097711785492504343953926634992332820282019297497264409235500333",
			expectedOverflow: true,
		},
		{
			name:             "min negative + min negative overflow",
			x:                "-57896044618658097711785492504343953926634992332820282019728792003956564819968",
			y:                "-57896044618658097711785492504343953926634992332820282019728792003956564819968",
			expected:         "0",
			expectedOverflow: true,
		},
		{
			name:             "max positive + min negative",
			x:                "57896044618658097711785492504343953926634992332820282019728792003956564819967",
			y:                "-57896044618658097711785492504343953926634992332820282019728792003956564819968",
			expected:         "-1",
			expectedOverflow: false,
		},
		{
			name:             "small positive + large negative",
			x:                "10000",
			y:                "-2000000",
			expected:         "-1990000",
			expectedOverflow: false,
		},
		{
			name:             "max positive + max positive overflow",
			x:                "57896044618658097711785492504343953926634992332820282019728792003956564819967",
			y:                "57896044618658097711785492504343953926634992332820282019728792003956564819967",
			expected:         "-2",
			expectedOverflow: true,
		},
		{
			name:             "max positive + one overflow",
			x:                "57896044618658097711785492504343953926634992332820282019728792003956564819967",
			y:                "1",
			expected:         "-57896044618658097711785492504343953926634992332820282019728792003956564819968",
			expectedOverflow: true,
		},
		{
			name:             "min negative + negative one overflow",
			x:                "-57896044618658097711785492504343953926634992332820282019728792003956564819968",
			y:                "-1",
			expected:         "57896044618658097711785492504343953926634992332820282019728792003956564819967",
			expectedOverflow: true,
		},
		{
			name:             "large positive + large positive overflow",
			x:                "57896044618658097711785492504343953926634992332820282019728792003956564819961",
			y:                "431405283104328105143242031570231414",
			expected:         "-57896044618658097711785492504343953926634560927537177691623648761924994588561",
			expectedOverflow: true,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			x := MustFromDecimal(tt.x)
			y := MustFromDecimal(tt.y)
			z, overflow := new(Int).AddOverflow(x, y)
			uassert.Equal(t, tt.expected, z.ToString())
			uassert.Equal(t, tt.expectedOverflow, overflow)
		})
	}
}

func TestSub(t *testing.T) {
	tests := []struct {
		name     string
		x        string
		y        string
		expected string
	}{
		{
			name:     "min negative - positive underflow",
			x:        "-57896044618658097711785492504343953926634992332820282019728792003956564819968",
			y:        "100",
			expected: "57896044618658097711785492504343953926634992332820282019728792003956564819868",
		},
		{
			name:     "zero - positive",
			x:        "0",
			y:        "9999",
			expected: "-9999",
		},
		{
			name:     "max positive - min negative overflow",
			x:        "57896044618658097711785492504343953926634992332820282019728792003956564819967",
			y:        "-57896044618658097711785492504343953926634992332820282019728792003956564819968",
			expected: "-1",
		},
		{
			name:     "min negative - max positive underflow",
			x:        "-57896044618658097711785492504343953926634992332820282019728792003956564819968",
			y:        "57896044618658097711785492504343953926634992332820282019728792003956564819967",
			expected: "1",
		},
		{
			name:     "large positive - one overflow",
			x:        "57896044618658097711785492504343953926634992332820282019728792003956564819967",
			y:        "-1",
			expected: "-57896044618658097711785492504343953926634992332820282019728792003956564819968",
		},
		{
			name:     "min negative - negative one overflow",
			x:        "-57896044618658097711785492504343953926634992332820282019728792003956564819968",
			y:        "1",
			expected: "57896044618658097711785492504343953926634992332820282019728792003956564819967",
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			x := MustFromDecimal(tt.x)
			y := MustFromDecimal(tt.y)
			z := new(Int).Sub(x, y)
			uassert.Equal(t, tt.expected, z.ToString())
		})
	}
}

func TestSubOverflow(t *testing.T) {
	tests := []struct {
		name             string
		x                string
		y                string
		expected         string
		expectedOverflow bool
	}{
		{
			name:             "min negative - positive underflow",
			x:                "-57896044618658097711785492504343953926634992332820282019728792003956564819968",
			y:                "100",
			expected:         "57896044618658097711785492504343953926634992332820282019728792003956564819868",
			expectedOverflow: true,
		},
		{
			name:             "zero - positive",
			x:                "0",
			y:                "9999",
			expected:         "-9999",
			expectedOverflow: false,
		},
		{
			name:             "max positive - min negative overflow",
			x:                "57896044618658097711785492504343953926634992332820282019728792003956564819967",
			y:                "-57896044618658097711785492504343953926634992332820282019728792003956564819968",
			expected:         "-1",
			expectedOverflow: true,
		},
		{
			name:             "min negative - max positive underflow",
			x:                "-57896044618658097711785492504343953926634992332820282019728792003956564819968",
			y:                "57896044618658097711785492504343953926634992332820282019728792003956564819967",
			expected:         "1",
			expectedOverflow: true,
		},
		{
			name:             "min int256 - 1 underflow",
			x:                "-57896044618658097711785492504343953926634992332820282019728792003956564819968",
			y:                "1",
			expected:         "57896044618658097711785492504343953926634992332820282019728792003956564819967",
			expectedOverflow: true,
		},
		{
			name:             "zero - min int256 overflow",
			x:                "0",
			y:                "-57896044618658097711785492504343953926634992332820282019728792003956564819968",
			expected:         "-57896044618658097711785492504343953926634992332820282019728792003956564819968",
			expectedOverflow: true,
		},
		{
			name:             "max int256 - (-1) overflow",
			x:                "57896044618658097711785492504343953926634992332820282019728792003956564819967",
			y:                "-1",
			expected:         "-57896044618658097711785492504343953926634992332820282019728792003956564819968",
			expectedOverflow: true,
		},
		{
			name:             "negative two - max int256 overflow",
			x:                "-2",
			y:                "57896044618658097711785492504343953926634992332820282019728792003956564819967",
			expected:         "57896044618658097711785492504343953926634992332820282019728792003956564819967",
			expectedOverflow: true,
		},
		{
			name:             "one - min int256 overflow",
			x:                "1",
			y:                "-57896044618658097711785492504343953926634992332820282019728792003956564819968",
			expected:         "-57896044618658097711785492504343953926634992332820282019728792003956564819967",
			expectedOverflow: true,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			x := MustFromDecimal(tt.x)
			y := MustFromDecimal(tt.y)
			z, overflow := new(Int).SubOverflow(x, y)
			uassert.Equal(t, tt.expected, z.ToString())
			uassert.Equal(t, tt.expectedOverflow, overflow)
		})
	}
}

func TestMulOverFlow(t *testing.T) {
	tests := []struct {
		name             string
		x                string
		y                string
		expected         string
		expectedOverflow bool
	}{
		{
			name:             "positive * negative",
			x:                "100",
			y:                "-2",
			expected:         "-200",
			expectedOverflow: false,
		},
		{
			name:             "max positive * min negative overflow",
			x:                "57896044618658097711785492504343953926634992332820282019728792003956564819967",
			y:                "-57896044618658097711785492504343953926634992332820282019728792003956564819968",
			expected:         "-57896044618658097711785492504343953926634992332820282019728792003956564819968",
			expectedOverflow: true,
		},
		{
			name:             "max positive * max positive overflow",
			x:                "57896044618658097711785492504343953926634992332820282019728792003956564819967",
			y:                "57896044618658097711785492504343953926634992332820282019728792003956564819967",
			expected:         "1",
			expectedOverflow: true,
		},
		{
			name:             "min negative * min negative overflow",
			x:                "-57896044618658097711785492504343953926634992332820282019728792003956564819968",
			y:                "-57896044618658097711785492504343953926634992332820282019728792003956564819968",
			expected:         "0",
			expectedOverflow: true,
		},
		{
			name:             "zero * min negative",
			x:                "0",
			y:                "-57896044618658097711785492504343953926634992332820282019728792003956564819968",
			expected:         "0",
			expectedOverflow: false,
		},
		{
			name:             "large positive * large positive",
			x:                "412421424314214830214",
			y:                "491735014023482390148157914",
			expected:         "202802054868735010725494286098171881252370413596",
			expectedOverflow: false,
		},
		{
			name:             "small positive * small positive",
			x:                "12",
			y:                "12",
			expected:         "144",
			expectedOverflow: false,
		},
		{
			name:             "negative * positive",
			x:                "-500000000000000",
			y:                "5000000000000",
			expected:         "-2500000000000000000000000000",
			expectedOverflow: false,
		},
		{
			name:             "large negative * large positive",
			x:                "-412421424314214830214",
			y:                "491735014023482390148157914",
			expected:         "-202802054868735010725494286098171881252370413596",
			expectedOverflow: false,
		},
		{
			name:             "large positive * large negative overflow",
			x:                "202802054868735010725494286098171881252370413596",
			y:                "-202802054868735010725494286098171881252370413596",
			expected:         "17633904406147578101277522337283808353988667996273383726665993364273483857136",
			expectedOverflow: true,
		},
		{
			name:             "min negative * 1",
			x:                "-57896044618658097711785492504343953926634992332820282019728792003956564819968",
			y:                "1",
			expected:         "-57896044618658097711785492504343953926634992332820282019728792003956564819968",
			expectedOverflow: false,
		},
		{
			name:             "min negative * -1 overflow",
			x:                "-57896044618658097711785492504343953926634992332820282019728792003956564819968",
			y:                "-1",
			expected:         "-57896044618658097711785492504343953926634992332820282019728792003956564819968",
			expectedOverflow: true,
		},
		{
			name:             "min negative/2 * 2",
			x:                "-28948022309329048855892746252171976963317496166410141009864396001978282409984",
			y:                "2",
			expected:         "-57896044618658097711785492504343953926634992332820282019728792003956564819968",
			expectedOverflow: false,
		},
		{
			name:             "positive boundary * 2 overflows to min",
			x:                "28948022309329048855892746252171976963317496166410141009864396001978282409984", // 2^254
			y:                "2",
			expected:         "-57896044618658097711785492504343953926634992332820282019728792003956564819968", // -2^255
			expectedOverflow: true,
		},
		{
			name:             "min negative * 2 overflow",
			x:                "-57896044618658097711785492504343953926634992332820282019728792003956564819968",
			y:                "2",
			expected:         "0",
			expectedOverflow: true,
		},
		{
			name:             "max positive * 2 overflow",
			x:                "57896044618658097711785492504343953926634992332820282019728792003956564819967",
			y:                "2",
			expected:         "-2",
			expectedOverflow: true,
		},
		{
			name:             "min negative * -2 overflow",
			x:                "-57896044618658097711785492504343953926634992332820282019728792003956564819968",
			y:                "-2",
			expected:         "0",
			expectedOverflow: true,
		},
		{
			name:             "min negative plus one * -1 stays in range",
			x:                "-57896044618658097711785492504343953926634992332820282019728792003956564819967",
			y:                "-1",
			expected:         "57896044618658097711785492504343953926634992332820282019728792003956564819967",
			expectedOverflow: false,
		},
		{
			name:             "max positive * -2 underflows",
			x:                "57896044618658097711785492504343953926634992332820282019728792003956564819967",
			y:                "-2",
			expected:         "2",
			expectedOverflow: true,
		},
		{
			name:             "min negative * 0 short-circuits",
			x:                "-57896044618658097711785492504343953926634992332820282019728792003956564819968",
			y:                "0",
			expected:         "0",
			expectedOverflow: false,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			x := MustFromDecimal(tt.x)
			y := MustFromDecimal(tt.y)
			z, overflow := new(Int).MulOverflow(x, y)
			uassert.Equal(t, tt.expected, z.ToString())
			uassert.Equal(t, tt.expectedOverflow, overflow)
		})
	}
}

func TestMul(t *testing.T) {
	tests := []struct {
		name     string
		x        string
		y        string
		expected string
	}{
		{
			name:     "positive * negative",
			x:        "100",
			y:        "-2",
			expected: "-200",
		},
		{
			name:     "max positive * min negative",
			x:        "57896044618658097711785492504343953926634992332820282019728792003956564819967",
			y:        "-57896044618658097711785492504343953926634992332820282019728792003956564819968",
			expected: "-57896044618658097711785492504343953926634992332820282019728792003956564819968",
		},
		{
			name:     "max positive * max positive",
			x:        "57896044618658097711785492504343953926634992332820282019728792003956564819967",
			y:        "57896044618658097711785492504343953926634992332820282019728792003956564819967",
			expected: "1",
		},
		{
			name:     "min negative * min negative",
			x:        "-57896044618658097711785492504343953926634992332820282019728792003956564819968",
			y:        "-57896044618658097711785492504343953926634992332820282019728792003956564819968",
			expected: "0",
		},
		{
			name:     "zero * min negative",
			x:        "0",
			y:        "-57896044618658097711785492504343953926634992332820282019728792003956564819968",
			expected: "0",
		},
		{
			name:     "large positive * large positive",
			x:        "412421424314214830214",
			y:        "491735014023482390148157914",
			expected: "202802054868735010725494286098171881252370413596",
		},
		{
			name:     "small positive * small positive",
			x:        "12",
			y:        "12",
			expected: "144",
		},
		{
			name:     "negative * positive",
			x:        "-500000000000000",
			y:        "5000000000000",
			expected: "-2500000000000000000000000000",
		},
		{
			name:     "large negative * large positive",
			x:        "-412421424314214830214",
			y:        "491735014023482390148157914",
			expected: "-202802054868735010725494286098171881252370413596",
		},
		{
			name:     "large positive * large negative overflow",
			x:        "202802054868735010725494286098171881252370413596",
			y:        "-202802054868735010725494286098171881252370413596",
			expected: "17633904406147578101277522337283808353988667996273383726665993364273483857136",
		},
		{
			name:     "min negative * 1",
			x:        "-57896044618658097711785492504343953926634992332820282019728792003956564819968",
			y:        "1",
			expected: "-57896044618658097711785492504343953926634992332820282019728792003956564819968",
		},
		{
			name:     "min negative * -1 overflow",
			x:        "-57896044618658097711785492504343953926634992332820282019728792003956564819968",
			y:        "-1",
			expected: "-57896044618658097711785492504343953926634992332820282019728792003956564819968",
		},
		{
			name:     "min negative/2 * 2",
			x:        "-28948022309329048855892746252171976963317496166410141009864396001978282409984",
			y:        "2",
			expected: "-57896044618658097711785492504343953926634992332820282019728792003956564819968",
		},
		{
			name:     "positive boundary * 2 overflows to min",
			x:        "28948022309329048855892746252171976963317496166410141009864396001978282409984", // 2^254
			y:        "2",
			expected: "-57896044618658097711785492504343953926634992332820282019728792003956564819968", // -2^255
		},
		{
			name:     "min negative * 2 overflow",
			x:        "-57896044618658097711785492504343953926634992332820282019728792003956564819968",
			y:        "2",
			expected: "0",
		},
		{
			name:     "min negative plus one * -1 stays in range",
			x:        "-57896044618658097711785492504343953926634992332820282019728792003956564819967",
			y:        "-1",
			expected: "57896044618658097711785492504343953926634992332820282019728792003956564819967",
		},
		{
			name:     "max positive * -2 underflows",
			x:        "57896044618658097711785492504343953926634992332820282019728792003956564819967",
			y:        "-2",
			expected: "2",
		},
		{
			name:     "min negative * 0 short-circuits",
			x:        "-57896044618658097711785492504343953926634992332820282019728792003956564819968",
			y:        "0",
			expected: "0",
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			x := MustFromDecimal(tt.x)
			y := MustFromDecimal(tt.y)
			z := new(Int).Mul(x, y)
			uassert.Equal(t, tt.expected, z.ToString())
		})
	}
}

func TestDiv(t *testing.T) {
	tests := []struct {
		name       string
		x          string
		y          string
		expected   string
		shoudPanic bool
	}{
		{
			name:     "positive / negative",
			x:        "100",
			y:        "-2",
			expected: "-50",
		},
		{
			name:     "min negative / positive",
			x:        "-57896044618658097711785492504343953926634992332820282019728792003956564819968",
			y:        "3194721952341",
			expected: "-18122404854742851078740194629148605029554483750497671811411863963",
		},
		{
			name:     "large positive / negative",
			x:        "57896044618658097711785492504343953926634992332820282019728792003956564819961",
			y:        "-4134320184329015710493829104",
			expected: "-14003764110508630918697735423914335136046266814161",
		},
		{
			name:     "large negative / large negative",
			x:        "-57896044618658097711785492504343953926634992332820282019728792003956564819961",
			y:        "-4134320184329015710493829104",
			expected: "14003764110508630918697735423914335136046266814161",
		},
		{
			name:     "small negative / large negative",
			x:        "-578960446186580977117854925043439539266349923328202564819961",
			y:        "-57896044618658097711785492504343953926634992332820282019728792003956564819968",
			expected: "0",
		},
		{
			name:     "large / small",
			x:        "3214732915732914729142135321421",
			y:        "510482085320157124",
			expected: "6297445117426",
		},
		{
			name:     "same values",
			x:        "510482085320157124",
			y:        "510482085320157124",
			expected: "1",
		},
		{
			name:     "zero dividend",
			x:        "0",
			y:        "510482085320157124",
			expected: "0",
		},
		{
			name:       "division by zero",
			x:          "1",
			y:          "0",
			expected:   "",
			shoudPanic: true,
		},
		{
			name:     "min int256 / -1",
			x:        MinInt256().ToString(),
			y:        "-1",
			expected: MinInt256().ToString(),
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			if tt.shoudPanic {
				defer func() {
					if r := recover(); r == nil {
						t.Error("Div should panic on division by zero")
					}
				}()
			}

			x := MustFromDecimal(tt.x)
			y := MustFromDecimal(tt.y)
			z := new(Int).Div(x, y)
			if !tt.shoudPanic {
				uassert.Equal(t, tt.expected, z.ToString())
			}
		})
	}
}

func TestOr(t *testing.T) {
	tests := []struct {
		name     string
		x        string
		y        string
		expected string
	}{
		{
			name:     "min negative | negative",
			x:        "-57896044618658097711785492504343953926634992332820282019728792003956564819968",
			y:        "-100",
			expected: "-100",
		},
		{
			name:     "max positive | positive",
			x:        "57896044618658097711785492504343953926634992332820282019728792003956564819967",
			y:        "41457129491534261876432718654783265437285638275",
			expected: "57896044618658097711785492504343953926634992332820282019728792003956564819967",
		},
		{
			name:     "min negative | max positive",
			x:        "-57896044618658097711785492504343953926634992332820282019728792003956564819968",
			y:        "57896044618658097711785492504343953926634992332820282019728792003956564819967",
			expected: "-1",
		},
		{
			name:     "min negative | zero",
			x:        "-57896044618658097711785492504343953926634992332820282019728792003956564819968",
			y:        "0",
			expected: "-57896044618658097711785492504343953926634992332820282019728792003956564819968",
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			x := MustFromDecimal(tt.x)
			y := MustFromDecimal(tt.y)
			z := new(Int).Or(x, y)
			uassert.Equal(t, tt.expected, z.ToString())
		})
	}
}

func TestAnd(t *testing.T) {
	tests := []struct {
		name     string
		x        string
		y        string
		expected string
	}{
		{
			name:     "min negative & negative",
			x:        "-57896044618658097711785492504343953926634992332820282019728792003956564819968",
			y:        "-100",
			expected: "-57896044618658097711785492504343953926634992332820282019728792003956564819968",
		},
		{
			name:     "max positive & positive",
			x:        "57896044618658097711785492504343953926634992332820282019728792003956564819967",
			y:        "41457129491534261876432718654783265437285638275",
			expected: "41457129491534261876432718654783265437285638275",
		},
		{
			name:     "negative & small positive",
			x:        "-57896044618658097711785492504343953926634992332820282019728792003956564819967",
			y:        "7",
			expected: "1",
		},
		{
			name:     "min negative & zero",
			x:        "-57896044618658097711785492504343953926634992332820282019728792003956564819968",
			y:        "0",
			expected: "0",
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			x := MustFromDecimal(tt.x)
			y := MustFromDecimal(tt.y)
			z := new(Int).And(x, y)
			uassert.Equal(t, tt.expected, z.ToString())
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
			name:     "x is non-neg & n is 64",
			x:        "1",
			n:        64,
			expected: "18446744073709551616",
		},
		{
			name:     "x is non-neg & n is 128",
			x:        "1",
			n:        128,
			expected: "340282366920938463463374607431768211456",
		},
		{
			name:     "x is non-neg & n is 192",
			x:        "1",
			n:        192,
			expected: "6277101735386680763835789423207666416102355444464034512896",
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
			name:     "x is non-neg & n is 64",
			x:        "18446744073709551616",
			n:        64,
			expected: "1",
		},
		{
			name:     "x is non-neg & n is 128",
			x:        "340282366920938463463374607431768211456",
			n:        128,
			expected: "1",
		},
		{
			name:     "x is non-neg & n is 192",
			x:        "6277101735386680763835789423207666416102355444464034512896",
			n:        192,
			expected: "1",
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
		{
			name:     "x is neg & n is greater than or equal 256",
			x:        "-11111",
			n:        256,
			expected: "-1",
		},
		{
			name:     "x is non-neg & n much larger than 256",
			x:        "11111",
			n:        300,
			expected: "0",
		},
		{
			name:     "one rsh 0 is one",
			x:        "1",
			n:        0,
			expected: "1",
		},
		{
			name:     "negative one rsh 0 is negative one",
			x:        "-1",
			n:        0,
			expected: "-1",
		},
		{
			name:     "one rsh 1 is zero",
			x:        "1",
			n:        1,
			expected: "0",
		},
		{
			name:     "negative one rsh 1 is negative one",
			x:        "-1",
			n:        1,
			expected: "-1",
		},
		{
			name:     "max int256 rsh 254 is one",
			x:        "57896044618658097711785492504343953926634992332820282019728792003956564819967",
			n:        254,
			expected: "1",
		},
		{
			name:     "max int256 rsh 255 is zero",
			x:        "57896044618658097711785492504343953926634992332820282019728792003956564819967",
			n:        255,
			expected: "0",
		},
		{
			name:     "min int256 rsh 254 is one",
			x:        "-57896044618658097711785492504343953926634992332820282019728792003956564819968",
			n:        254,
			expected: "-2",
		},
		{
			name:     "min int256 rsh 255 is negative one",
			x:        "-57896044618658097711785492504343953926634992332820282019728792003956564819968",
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

func TestClearAndSetAllBitsOne(t *testing.T) {
	t.Run("Clear resets to zero", func(t *testing.T) {
		x := MustFromDecimal("123456789")
		uassert.Equal(t, "0", x.Clear().ToString())
	})

	t.Run("SetAllBitsOne sets -1", func(t *testing.T) {
		x := new(Int).SetAllBitsOne()
		uassert.Equal(t, "-1", x.ToString())
	})
}

func TestBitLen(t *testing.T) {
	type tc struct {
		name     string
		val      *Int
		expected int
	}

	one := One()
	tests := []tc{
		{name: "zero", val: Zero(), expected: 0},
		{name: "one", val: one, expected: 1},
		{name: "two", val: new(Int).SetInt64(2), expected: 2},
		{name: "three", val: new(Int).SetInt64(3), expected: 2},
		{name: "seven", val: new(Int).SetInt64(7), expected: 3},
		{
			name:     "two_to_64",
			val:      new(Int).Lsh(one.Clone(), 64),
			expected: 65,
		},
		{
			name:     "two_to_64_minus_one",
			val:      new(Int).Sub(new(Int).Lsh(one.Clone(), 64), one),
			expected: 64,
		},
		{
			name:     "max_int256_boundary",
			val:      MaxInt256(),
			expected: 255,
		},
		{
			name:     "min_int256_two_complement_bits",
			val:      MinInt256(),
			expected: 256,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			uassert.Equal(t, tt.expected, tt.val.BitLen())
		})
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
		name     string
		x        string
		y        string
		expected int
	}{
		{
			name:     "min negative < max positive",
			x:        "-57896044618658097711785492504343953926634992332820282019728792003956564819968",
			y:        "57896044618658097711785492504343953926634992332820282019728792003956564819967",
			expected: -1,
		},
		{
			name:     "min negative == min negative",
			x:        "-57896044618658097711785492504343953926634992332820282019728792003956564819968",
			y:        "-57896044618658097711785492504343953926634992332820282019728792003956564819968",
			expected: 0,
		},
		{
			name:     "max positive > min negative",
			x:        "57896044618658097711785492504343953926634992332820282019728792003956564819967",
			y:        "-57896044618658097711785492504343953926634992332820282019728792003956564819968",
			expected: 1,
		},
		{
			name:     "max positive == max positive",
			x:        "57896044618658097711785492504343953926634992332820282019728792003956564819967",
			y:        "57896044618658097711785492504343953926634992332820282019728792003956564819967",
			expected: 0,
		},
		{
			name:     "zero == zero",
			x:        "0",
			y:        "0",
			expected: 0,
		},
		{
			name:     "zero > negative",
			x:        "0",
			y:        "-10",
			expected: 1,
		},
		{
			name:     "smaller positive < larger positive",
			x:        "57896044618658097711785492504343953926634992332820282019728792003956564",
			y:        "57896044618658097711785492504343953926634992332820282019728792003956564819967",
			expected: -1,
		},
		{
			name:     "larger negative > smaller negative",
			x:        "-578960446186580977117854925043439539266349923328202820197287920039565648",
			y:        "-57896044618658097711785492504343953926634992332820282019728792003956564819967",
			expected: 1,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			x := MustFromDecimal(tt.x)
			y := MustFromDecimal(tt.y)
			uassert.Equal(t, tt.expected, x.Cmp(y))
		})
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
		{"57896044618658097711785492504343953926634992332820282019728792003956564819967", false},
		{"-57896044618658097711785492504343953926634992332820282019728792003956564819968", false},
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

func TestIsOne(t *testing.T) {
	tests := []struct {
		x    string
		want bool
	}{
		{"0", false},
		{"1", true},
		{"-1", false},
		{"2", false},
		{MaxInt256().ToString(), false},
	}

	for _, tc := range tests {
		x := MustFromDecimal(tc.x)
		got := x.IsOne()
		if got != tc.want {
			t.Errorf("IsOne(%s) = %v, want %v", tc.x, got, tc.want)
		}
	}
}

func TestLt(t *testing.T) {
	tests := []struct {
		x, y string
		want bool
	}{
		{"-57896044618658097711785492504343953926634992332820282019728792003956564819968", "57896044618658097711785492504343953926634992332820282019728792003956564819967", true},
		{"0", "0", false},
		{"0", "1", true},
		{"1", "0", false},
		{"-1", "0", true},
		{"0", "-1", false},
		{"1", "1", false},
		{"-1", "-1", false},
		{"57896044618658097711785492504343953926634992332820282019728792003956564819967", "57896044618658097711785492504343953926634992332820282019728792003956564819967", false},
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

func TestLteAndGte(t *testing.T) {
	tests := []struct {
		name      string
		x         string
		y         string
		expectLte bool
		expectGte bool
	}{
		{name: "equal values", x: "42", y: "42", expectLte: true, expectGte: true},
		{name: "less than", x: "-1", y: "0", expectLte: true, expectGte: false},
		{name: "greater than", x: "1", y: "0", expectLte: false, expectGte: true},
		{name: "both negative with ordering", x: "-5", y: "-1", expectLte: true, expectGte: false},
		{name: "negative vs positive", x: "-100", y: "100", expectLte: true, expectGte: false},
		{name: "zero vs negative", x: "0", y: "-10", expectLte: false, expectGte: true},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			x := MustFromDecimal(tt.x)
			y := MustFromDecimal(tt.y)
			uassert.Equal(t, tt.expectLte, x.Lte(y))
			uassert.Equal(t, tt.expectGte, x.Gte(y))
		})
	}
}

func TestClone(t *testing.T) {
	tests := []string{
		"0",
		"-0",
		"1",
		"-1",
		"10",
		"-10",
		"57896044618658097711785492504343953926634992332820282019728792003956564819967",
		"-57896044618658097711785492504343953926634992332820282019728792003956564819967",
		"-57896044618658097711785492504343953926634992332820282019728792003956564819968",
	}

	for _, tt := range tests {
		x, err := FromDecimal(tt)
		if err != nil {
			t.Error(err)
			continue
		}

		y := x.Clone()

		if x.Cmp(y) != 0 {
			t.Errorf("Clone(%s) = %v, want %v", tt, y, x)
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
		{
			name: "Lte with nil",
			fn:   func() { validInt.Lte(nil) },
		},
		{
			name: "Gte with nil",
			fn:   func() { validInt.Gte(nil) },
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

func TestSetBytes32(t *testing.T) {
	tests := []struct {
		name     string
		input    []byte
		expected string
	}{
		{
			name:     "all zeros",
			input:    make([]byte, 32),
			expected: "0",
		},
		{
			name: "min int256",
			input: func() []byte {
				b := make([]byte, 32)
				b[0] = 0x80
				return b
			}(),
			expected: MinInt256().ToString(),
		},
		{
			name: "all ones is -1",
			input: func() []byte {
				b := make([]byte, 32)
				for i := range b {
					b[i] = 0xff
				}
				return b
			}(),
			expected: "-1",
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			z := new(Int).SetBytes32(tt.input)
			if got := z.ToString(); got != tt.expected {
				t.Errorf("SetBytes32(%s) = %s, want %s", tt.name, got, tt.expected)
			}
		})
	}
}

func TestSetBytes32PanicsOnShortInput(t *testing.T) {
	shortInput := make([]byte, 31)
	defer func() {
		if r := recover(); r == nil {
			t.Error("expected panic for short input")
		}
	}()
	new(Int).SetBytes32(shortInput)
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
		name         string
		x            uint64
		want         string
		prevValue    string // if non-empty, set this value first to test overwrite
		testChaining bool   // test method chaining
	}{
		// Basic values
		{name: "zero", x: 0, want: "0"},
		{name: "one", x: 1, want: "1"},

		// Boundary values
		{name: "max uint64", x: 18446744073709551615, want: "18446744073709551615"},
		{name: "max int64 as uint64", x: 9223372036854775807, want: "9223372036854775807"},
		{name: "max int64 + 1", x: 9223372036854775808, want: "9223372036854775808"},
		{name: "max uint32", x: 4294967295, want: "4294967295"},
		{name: "max uint32 + 1", x: 4294967296, want: "4294967296"},

		// Power of 2 boundaries
		{name: "2^32", x: 1 << 32, want: "4294967296"},
		{name: "2^63", x: 1 << 63, want: "9223372036854775808"},

		// Overwrite previous value (including negative)
		{name: "overwrite negative value", x: 99999, want: "99999", prevValue: "-12345"},
		{name: "overwrite large positive", x: 1, want: "1", prevValue: "57896044618658097711785492504343953926634992332820282019728792003956564819967"},

		// Method chaining test
		{name: "chaining", x: 42, want: "42", testChaining: true},
	}

	for _, tc := range tests {
		t.Run(tc.name, func(t *testing.T) {
			var z *Int
			if tc.prevValue != "" {
				z = MustFromDecimal(tc.prevValue)
			} else {
				z = new(Int)
			}

			result := z.SetUint64(tc.x)

			// Verify value
			got := z.ToString()
			if got != tc.want {
				t.Errorf("SetUint64(%d) = %s, want %s", tc.x, got, tc.want)
			}

			// SetUint64 should always produce non-negative values
			if z.IsNeg() {
				t.Errorf("SetUint64(%d) produced negative value", tc.x)
			}

			// Method chaining: SetUint64 should return receiver
			if tc.testChaining && result != z {
				t.Error("SetUint64 should return the receiver for chaining")
			}

			// Round-trip verification
			roundTrip := z.Uint64()
			if roundTrip != tc.x {
				t.Errorf("Round trip failed: SetUint64(%d).Uint64() = %d", tc.x, roundTrip)
			}
		})
	}
}

func TestUint64(t *testing.T) {
	tests := []struct {
		x      string
		want   uint64
		panics bool
	}{
		{"0", 0, false},
		{"1", 1, false},
		{"9223372036854775807", 9223372036854775807, false},
		{"9223372036854775808", 9223372036854775808, false},
		{"18446744073709551615", 18446744073709551615, false},
		{"18446744073709551616", 0, true}, // out of range
		{"18446744073709551617", 0, true}, // out of range
		{"-1", 0, true},                   // negative -> panic
		{"-18446744073709551615", 0, true},
		{"-18446744073709551616", 0, true},
		{"-18446744073709551617", 0, true},
		{"-57896044618658097711785492504343953926634992332820282019728792003956564819968", 0, true},
		{"-57896044618658097711785492504343953926634992332820282019728792003956564819967", 0, true},
		{"-57896044618658097711785492504343953926634992332820282019728792003956564819966", 0, true},
		{"57896044618658097711785492504343953926634992332820282019728792003956564819967", 0, true},
		{"57896044618658097711785492504343953926634992332820282019728792003956564819966", 0, true},
	}

	for _, tc := range tests {
		z := MustFromDecimal(tc.x)

		if tc.panics {
			uassert.PanicsContains(t, "uint64 overflow", func() {
				z.Uint64()
			})
			continue
		}

		got := z.Uint64()
		if got != tc.want {
			t.Errorf("Uint64(%s) = %d, want %d", tc.x, got, tc.want)
		}
	}
}

func TestInt64(t *testing.T) {
	tests := []struct {
		name          string
		x             string
		want          int64
		panics        bool
		testRoundTrip bool // test SetInt64 -> Int64 round-trip
	}{
		// Basic values
		{name: "zero", x: "0", want: 0},
		{name: "one", x: "1", want: 1},
		{name: "negative one", x: "-1", want: -1},

		// int8 boundaries
		{name: "max int8", x: "127", want: 127},
		{name: "min int8", x: "-128", want: -128},

		// int16 boundaries
		{name: "max int16", x: "32767", want: 32767},
		{name: "min int16", x: "-32768", want: -32768},

		// int32 boundaries
		{name: "max int32", x: "2147483647", want: 2147483647},
		{name: "min int32", x: "-2147483648", want: -2147483648},

		// int64 boundaries
		{name: "max int64", x: "9223372036854775807", want: 9223372036854775807},
		{name: "min int64", x: "-9223372036854775808", want: -9223372036854775808},

		// Round-trip tests (SetInt64 -> Int64)
		{name: "round-trip max int64", x: "9223372036854775807", want: 9223372036854775807, testRoundTrip: true},
		{name: "round-trip min int64", x: "-9223372036854775808", want: -9223372036854775808, testRoundTrip: true},
		{name: "round-trip zero", x: "0", want: 0, testRoundTrip: true},

		// Overflow cases (positive)
		{name: "max int64 + 1", x: "9223372036854775808", panics: true},
		{name: "max uint64", x: "18446744073709551615", panics: true},
		{name: "max uint64 + 1", x: "18446744073709551616", panics: true},
		{name: "max uint64 + 2", x: "18446744073709551617", panics: true},
		{name: "max int256", x: "57896044618658097711785492504343953926634992332820282019728792003956564819967", panics: true},
		{name: "max int256 - 1", x: "57896044618658097711785492504343953926634992332820282019728792003956564819966", panics: true},

		// Overflow cases (negative)
		{name: "min int64 - 1", x: "-9223372036854775809", panics: true},
		{name: "negative max uint64", x: "-18446744073709551615", panics: true},
		{name: "min int256", x: "-57896044618658097711785492504343953926634992332820282019728792003956564819968", panics: true},
		{name: "min int256 + 1", x: "-57896044618658097711785492504343953926634992332820282019728792003956564819967", panics: true},
		{name: "min int256 + 2", x: "-57896044618658097711785492504343953926634992332820282019728792003956564819966", panics: true},
	}

	for _, tc := range tests {
		t.Run(tc.name, func(t *testing.T) {
			z := MustFromDecimal(tc.x)

			if tc.panics {
				uassert.PanicsContains(t, "int64 overflow", func() {
					z.Int64()
				})
				return
			}

			got := z.Int64()
			if got != tc.want {
				t.Errorf("Int64(%s) = %d, want %d", tc.x, got, tc.want)
			}

			// Round-trip verification: SetInt64 -> Int64
			if tc.testRoundTrip {
				z2 := new(Int)
				z2.SetInt64(tc.want)
				got2 := z2.Int64()
				if got2 != tc.want {
					t.Errorf("Round-trip failed: SetInt64(%d).Int64() = %d", tc.want, got2)
				}
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
		// MinInt256 negation overflows; expect no-op result (still MinInt256)
		{"-57896044618658097711785492504343953926634992332820282019728792003956564819968", "-57896044618658097711785492504343953926634992332820282019728792003956564819968"},
		{"-57896044618658097711785492504343953926634992332820282019728792003956564819967", "57896044618658097711785492504343953926634992332820282019728792003956564819967"},
		{"57896044618658097711785492504343953926634992332820282019728792003956564819967", "-57896044618658097711785492504343953926634992332820282019728792003956564819967"},
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

func TestNegOverflow(t *testing.T) {
	tests := []struct {
		x           string
		want        string
		shouldPanic bool
	}{
		{"0", "0", false},
		{"1", "-1", false},
		{"-1", "1", false},
		{"9223372036854775807", "-9223372036854775807", false},
		{"-18446744073709551615", "18446744073709551615", false},
		// MinInt256 negation overflows; expect no-op result (still MinInt256)
		{"-57896044618658097711785492504343953926634992332820282019728792003956564819968", "-57896044618658097711785492504343953926634992332820282019728792003956564819968", true},
		{"-57896044618658097711785492504343953926634992332820282019728792003956564819967", "57896044618658097711785492504343953926634992332820282019728792003956564819967", false},
		{"57896044618658097711785492504343953926634992332820282019728792003956564819967", "-57896044618658097711785492504343953926634992332820282019728792003956564819967", false},
	}

	for _, tc := range tests {
		z := MustFromDecimal(tc.x)

		if tc.shouldPanic {
			uassert.PanicsContains(t, "int256: overflow", func() {
				z.NegOverflow(z)
			})
			continue
		}

		z.NegOverflow(z)

		got := z.ToString()
		if got != tc.want {
			t.Errorf("Neg(%s) = %s, want %s", tc.x, got, tc.want)
		}
	}
}

func TestSet(t *testing.T) {
	tests := []struct {
		name           string
		src            string
		dst            string // initial value of destination (empty means new(Int))
		want           string
		selfAssignment bool // test z.Set(z)
		testChaining   bool
		testIndepence  bool // verify src and dst are independent after Set
	}{
		// Basic values
		{name: "zero to new", src: "0", want: "0"},
		{name: "one to new", src: "1", want: "1"},
		{name: "negative one to new", src: "-1", want: "-1"},

		// Boundary values
		{name: "max int256", src: "57896044618658097711785492504343953926634992332820282019728792003956564819967", want: "57896044618658097711785492504343953926634992332820282019728792003956564819967"},
		{name: "min int256", src: "-57896044618658097711785492504343953926634992332820282019728792003956564819968", want: "-57896044618658097711785492504343953926634992332820282019728792003956564819968"},
		{name: "max int64", src: "9223372036854775807", want: "9223372036854775807"},
		{name: "min int64", src: "-9223372036854775808", want: "-9223372036854775808"},

		// Overwrite existing value
		{name: "positive to negative", src: "12345", dst: "-99999", want: "12345"},
		{name: "negative to positive", src: "-12345", dst: "99999", want: "-12345"},
		{name: "large to small", src: "1", dst: "57896044618658097711785492504343953926634992332820282019728792003956564819967", want: "1"},
		{name: "small to large", src: "57896044618658097711785492504343953926634992332820282019728792003956564819967", dst: "1", want: "57896044618658097711785492504343953926634992332820282019728792003956564819967"},

		// Self-assignment
		{name: "self assignment zero", src: "0", selfAssignment: true, want: "0"},
		{name: "self assignment positive", src: "12345", selfAssignment: true, want: "12345"},
		{name: "self assignment negative", src: "-12345", selfAssignment: true, want: "-12345"},
		{name: "self assignment max", src: "57896044618658097711785492504343953926634992332820282019728792003956564819967", selfAssignment: true, want: "57896044618658097711785492504343953926634992332820282019728792003956564819967"},
		{name: "self assignment min", src: "-57896044618658097711785492504343953926634992332820282019728792003956564819968", selfAssignment: true, want: "-57896044618658097711785492504343953926634992332820282019728792003956564819968"},

		// Method chaining
		{name: "chaining", src: "42", testChaining: true, want: "42"},

		// Independence test
		{name: "independence after set", src: "100", testIndepence: true, want: "100"},
	}

	for _, tc := range tests {
		t.Run(tc.name, func(t *testing.T) {
			src := MustFromDecimal(tc.src)

			var dst *Int
			if tc.selfAssignment {
				dst = src
			} else if tc.dst != "" {
				dst = MustFromDecimal(tc.dst)
			} else {
				dst = new(Int)
			}

			result := dst.Set(src)

			// Verify value
			got := dst.ToString()
			if got != tc.want {
				t.Errorf("Set(%s) = %s, want %s", tc.src, got, tc.want)
			}

			// Method chaining: Set should return receiver
			if tc.testChaining && result != dst {
				t.Error("Set should return the receiver for chaining")
			}

			// Independence: modifying src should not affect dst
			if tc.testIndepence {
				originalDst := dst.ToString()
				src.SetInt64(999)
				if dst.ToString() != originalDst {
					t.Errorf("dst changed after modifying src: got %s, want %s", dst.ToString(), originalDst)
				}
			}
		})
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
		{"123-", true, "", false},
		{"123+", true, "", false},

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
