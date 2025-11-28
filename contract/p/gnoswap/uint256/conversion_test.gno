package uint256

import (
	"testing"
)

func TestDec(t *testing.T) {
	testCases := []struct {
		name string
		z    Uint
		want string
	}{
		{
			name: "zero",
			z:    Uint{0, 0, 0, 0},
			want: "0",
		},
		{
			name: "less than 20 digits",
			z:    Uint{1234567890, 0, 0, 0},
			want: "1234567890",
		},
		{
			name: "max possible value",
			z:    Uint{^uint64(0), ^uint64(0), ^uint64(0), ^uint64(0)},
			want: "115792089237316195423570985008687907853269984665640564039457584007913129639935",
		},
	}

	for _, tc := range testCases {
		t.Run(tc.name, func(t *testing.T) {
			result := tc.z.Dec()
			if result != tc.want {
				t.Errorf("Dec(%v) = %s, want %s", tc.z, result, tc.want)
			}
		})
	}
}
