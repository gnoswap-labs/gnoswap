package int256

import (
	"testing"
)

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
		{"115792089237316195423570985008687907853269984665640564039457584007913129639935", "-115792089237316195423570985008687907853269984665640564039457584007913129639935", false},
		{"-115792089237316195423570985008687907853269984665640564039457584007913129639935", "-115792089237316195423570985008687907853269984665640564039457584007913129639935", true},
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
		{"115792089237316195423570985008687907853269984665640564039457584007913129639935", "-115792089237316195423570985008687907853269984665640564039457584007913129639935", true},
		{"-115792089237316195423570985008687907853269984665640564039457584007913129639935", "-115792089237316195423570985008687907853269984665640564039457584007913129639935", false},
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
		{"115792089237316195423570985008687907853269984665640564039457584007913129639935", "-115792089237316195423570985008687907853269984665640564039457584007913129639935", 1},
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
		{"-0", true}, // TODO: should this be false?
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
		{"115792089237316195423570985008687907853269984665640564039457584007913129639935", "-115792089237316195423570985008687907853269984665640564039457584007913129639935", false},
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
		{"115792089237316195423570985008687907853269984665640564039457584007913129639935", "-115792089237316195423570985008687907853269984665640564039457584007913129639935", true},
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

func TestLte(t *testing.T) {
	tests := []struct {
		x, y string
		want bool
	}{
		{"0", "0", true},
		{"0", "1", true},
		{"1", "0", false},
		{"-1", "0", true},
		{"0", "-1", false},
		{"1", "1", true},
		{"-1", "-1", true},

		{"10", "20", true},
		{"20", "10", false},
		{"100", "100", true},

		{"-10", "-20", false},
		{"-20", "-10", true},
		{"-100", "-100", true},

		{"100", "-100", false},
		{"-100", "100", true},

		{"57896044618658097711785492504343953926634992332820282019728792003956564819967", "57896044618658097711785492504343953926634992332820282019728792003956564819967", true},
		{"-57896044618658097711785492504343953926634992332820282019728792003956564819968", "-57896044618658097711785492504343953926634992332820282019728792003956564819968", true},
		{"57896044618658097711785492504343953926634992332820282019728792003956564819967", "-57896044618658097711785492504343953926634992332820282019728792003956564819968", false},
		{"-57896044618658097711785492504343953926634992332820282019728792003956564819968", "57896044618658097711785492504343953926634992332820282019728792003956564819967", true},
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

		got := x.Lte(y)
		if got != tc.want {
			t.Errorf("Lte(%s, %s) = %v, want %v", tc.x, tc.y, got, tc.want)
		}
	}
}

func TestGte(t *testing.T) {
	tests := []struct {
		x, y string
		want bool
	}{
		{"0", "0", true},
		{"0", "1", false},
		{"1", "0", true},
		{"-1", "0", false},
		{"0", "-1", true},
		{"1", "1", true},
		{"-1", "-1", true},

		{"10", "20", false},
		{"20", "10", true},
		{"100", "100", true},

		{"-10", "-20", true},
		{"-20", "-10", false},
		{"-100", "-100", true},

		{"100", "-100", true},
		{"-100", "100", false},

		{"57896044618658097711785492504343953926634992332820282019728792003956564819967", "57896044618658097711785492504343953926634992332820282019728792003956564819967", true},
		{"-57896044618658097711785492504343953926634992332820282019728792003956564819968", "-57896044618658097711785492504343953926634992332820282019728792003956564819968", true},
		{"57896044618658097711785492504343953926634992332820282019728792003956564819967", "-57896044618658097711785492504343953926634992332820282019728792003956564819968", true},
		{"-57896044618658097711785492504343953926634992332820282019728792003956564819968", "57896044618658097711785492504343953926634992332820282019728792003956564819967", false},
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

		got := x.Gte(y)
		if got != tc.want {
			t.Errorf("Gte(%s, %s) = %v, want %v", tc.x, tc.y, got, tc.want)
		}
	}
}

func TestLteGteNilChecks(t *testing.T) {
	validInt := NewInt(123)

	tests := []struct {
		name      string
		fn        func()
		wantPanic string
	}{
		{
			name:      "Lte with nil x",
			fn:        func() { validInt.Lte(nil) },
			wantPanic: "int256: comparing with nil",
		},
		{
			name:      "Gte with nil x",
			fn:        func() { validInt.Gte(nil) },
			wantPanic: "int256: comparing with nil",
		},
		{
			name: "Lte with nil receiver",
			fn: func() {
				var z *Int
				z.Lte(validInt)
			},
			wantPanic: "int256: comparing with nil",
		},
		{
			name: "Gte with nil receiver",
			fn: func() {
				var z *Int
				z.Gte(validInt)
			},
			wantPanic: "int256: comparing with nil",
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			defer func() {
				r := recover()
				if r == nil {
					t.Errorf("%s: expected panic but got none", tt.name)
					return
				}
				if r.(string) != tt.wantPanic {
					t.Errorf("%s: got panic %v, want %v", tt.name, r, tt.wantPanic)
				}
			}()

			tt.fn()
		})
	}
}

func TestLteGteConsistencyWithCmp(t *testing.T) {
	values := []string{
		"-57896044618658097711785492504343953926634992332820282019728792003956564819968", // min
		"-1000",
		"-1",
		"0",
		"1",
		"1000",
		"57896044618658097711785492504343953926634992332820282019728792003956564819967", // max
	}

	for _, xStr := range values {
		for _, yStr := range values {
			x := MustFromDecimal(xStr)
			y := MustFromDecimal(yStr)

			cmp := x.Cmp(y)
			lte := x.Lte(y)
			gte := x.Gte(y)

			if (cmp <= 0) != lte {
				t.Errorf("Lte inconsistent: x=%s, y=%s, cmp=%d, lte=%v", xStr, yStr, cmp, lte)
			}

			if (cmp >= 0) != gte {
				t.Errorf("Gte inconsistent: x=%s, y=%s, cmp=%d, gte=%v", xStr, yStr, cmp, gte)
			}

			if lte && gte && cmp != 0 {
				t.Errorf("Both lte and gte but not equal: x=%s, y=%s", xStr, yStr)
			}
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
		{"115792089237316195423570985008687907853269984665640564039457584007913129639935"},
		{"-115792089237316195423570985008687907853269984665640564039457584007913129639935"},
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
		name      string
		fn        func()
		wantPanic string
	}{
		{
			name:      "Eq with nil",
			fn:        func() { validInt.Eq(nil) },
			wantPanic: "int256: comparing with nil",
		},
		{
			name:      "Neq with nil",
			fn:        func() { validInt.Neq(nil) },
			wantPanic: "int256: comparing with nil",
		},
		{
			name:      "Cmp with nil",
			fn:        func() { validInt.Cmp(nil) },
			wantPanic: "int256: comparing with nil",
		},
		{
			name:      "Lt with nil",
			fn:        func() { validInt.Lt(nil) },
			wantPanic: "int256: comparing with nil",
		},
		{
			name:      "Gt with nil",
			fn:        func() { validInt.Gt(nil) },
			wantPanic: "int256: comparing with nil",
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			defer func() {
				r := recover()
				if r == nil {
					t.Errorf("%s: expected panic but got none", tt.name)
					return
				}
				if r.(string) != tt.wantPanic {
					t.Errorf("%s: got panic %v, want %v", tt.name, r, tt.wantPanic)
				}
			}()

			tt.fn()
		})
	}
}
