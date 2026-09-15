package uint256

import (
	"testing"
)

const (
	maxUint256MinusOne  = "115792089237316195423570985008687907853269984665640564039457584007913129639934"
	maxUint256MinusTwo  = "115792089237316195423570985008687907853269984665640564039457584007913129639933"
	twoPow255           = "57896044618658097711785492504343953926634992332820282019728792003956564819968"
	twoPow255MinusOne   = "57896044618658097711785492504343953926634992332820282019728792003956564819967"
	twoPow128           = "340282366920938463463374607431768211456"
)

func TestCmp(t *testing.T) {
	tests := []struct {
		x, y string
		want int
	}{
		{"0", "0", 0},
		{"0", "1", -1},
		{"1", "0", 1},
		{"1", "1", 0},
		{"10", "10", 0},
		{"10", "11", -1},
		{"11", "10", 1},
		{MAX_UINT256, maxUint256MinusOne, 1},
		{maxUint256MinusOne, MAX_UINT256, -1},
		{twoPow255MinusOne, twoPow255, -1},
		{twoPow255, twoPow255MinusOne, 1},
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

func TestLt(t *testing.T) {
	tests := []struct {
		x, y string
		want bool
	}{
		// basic cases
		{"0", "0", false},
		{"0", "1", true},
		{"1", "0", false},
		{"1", "1", false},

		// boundary values around 2^255 (sign bit)
		{twoPow255MinusOne, twoPow255, true},
		{twoPow255, twoPow255MinusOne, false},
		{twoPow255MinusOne, twoPow255MinusOne, false},
		{twoPow255, twoPow255, false},

		// MAX boundary
		{maxUint256MinusOne, MAX_UINT256, true},
		{MAX_UINT256, maxUint256MinusOne, false},
		{MAX_UINT256, MAX_UINT256, false},

		// cross-range comparisons
		{"0", MAX_UINT256, true},
		{MAX_UINT256, "0", false},
		{"0", twoPow255, true},
		{twoPow255, "0", false},
	}

	for _, tc := range tests {
		x := MustFromDecimal(tc.x)
		y := MustFromDecimal(tc.y)

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
		// basic cases
		{"0", "0", false},
		{"0", "1", false},
		{"1", "0", true},
		{"1", "1", false},

		// boundary values around 2^255 (sign bit)
		{twoPow255MinusOne, twoPow255, false},
		{twoPow255, twoPow255MinusOne, true},
		{twoPow255MinusOne, twoPow255MinusOne, false},
		{twoPow255, twoPow255, false},

		// MAX boundary
		{maxUint256MinusOne, MAX_UINT256, false},
		{MAX_UINT256, maxUint256MinusOne, true},
		{MAX_UINT256, MAX_UINT256, false},

		// cross-range comparisons
		{"0", MAX_UINT256, false},
		{MAX_UINT256, "0", true},
		{"0", twoPow255, false},
		{twoPow255, "0", true},
	}

	for _, tc := range tests {
		x := MustFromDecimal(tc.x)
		y := MustFromDecimal(tc.y)

		got := x.Gt(y)
		if got != tc.want {
			t.Errorf("Gt(%s, %s) = %v, want %v", tc.x, tc.y, got, tc.want)
		}
	}
}

func TestIsZero(t *testing.T) {
	tests := []struct {
		x    string
		want bool
	}{
		{"0", true},
		{"1", false},
		{"10", false},
		// high-word cases: low word is 0 but high words are set
		{twoPow128, false}, // 2^128: arr[2] has value, arr[0] is 0
		{twoPow255, false}, // 2^255: arr[3] has value, lower words are 0
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

func TestLte(t *testing.T) {
	tests := []struct {
		x, y string
		want bool
	}{
		{"0", "0", true},    // equal
		{"0", "1", true},    // less than
		{"1", "0", false},   // greater than
		{"10", "10", true},  // equal
		{"10", "11", true},  // less than
		{"11", "10", false}, // greater than
		{maxUint256MinusOne, MAX_UINT256, true},
		{MAX_UINT256, maxUint256MinusOne, false},
		{twoPow255MinusOne, twoPow255, true},
		{twoPow255, twoPow255MinusOne, false},
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
		{"0", "0", true},    // equal
		{"0", "1", false},   // less than
		{"1", "0", true},    // greater than
		{"10", "10", true},  // equal
		{"10", "11", false}, // less than
		{"11", "10", true},  // greater than
		{MAX_UINT256, maxUint256MinusOne, true},
		{maxUint256MinusOne, MAX_UINT256, false},
		{twoPow255, twoPow255MinusOne, true},
		{twoPow255MinusOne, twoPow255, false},
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

func TestEq(t *testing.T) {
	tests := []struct {
		x    string
		y    string
		want bool
	}{
		{"18446744073709551615", "18446744073709551615", true},
		{"18446744073709551615", "18446744073709551616", false},
		{"0", "0", true},
		{"115792089237316195423570985008687907853269984665640564039457584007913129639935", "115792089237316195423570985008687907853269984665640564039457584007913129639935", true},
		{maxUint256MinusOne, maxUint256MinusOne, true},
		{maxUint256MinusTwo, maxUint256MinusOne, false},
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
		x    string
		y    string
		want bool
	}{
		{"0", "0", false},
		{"0", "1", true},
		{"1", "0", true},
		{"10", "10", false},
		{"10", "11", true},
		{maxUint256MinusOne, maxUint256MinusOne, false},
		{maxUint256MinusTwo, maxUint256MinusOne, true},
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

func TestSign(t *testing.T) {
	tests := []struct {
		x    string
		want int
	}{
		{"0", 0},
		{"1", 1},
		{"18446744073709551615", 1},                                                            // max uint64, below 2^255
		{twoPow255MinusOne, 1},                                                                 // 2^255-1: largest positive (sign bit not set)
		{"57896044618658097711785492504343953926634992332820282019728792003956564819968", -1}, // 2^255: sign bit set
		{maxUint256MinusOne, -1},                                                               // MAX-1
		{MAX_UINT256, -1},
	}

	for _, tc := range tests {
		x := MustFromDecimal(tc.x)
		if got := x.Sign(); got != tc.want {
			t.Errorf("Sign(%s) = %d, want %d", tc.x, got, tc.want)
		}
	}
}
