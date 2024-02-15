package common

import (
	"testing"
)

func TestFindMSB(t *testing.T) {
	tests := []struct {
		name          string
		ratio         bigint
		expectedMSB   bigint
		expectedRatio bigint
	}{
		{
			name:          "very low ratio",
			ratio:         bigint(1 << 10),
			expectedMSB:   10,
			expectedRatio: 1,
		},
		{
			name:          "low ratio",
			ratio:         bigint(1 << 30),
			expectedMSB:   30,
			expectedRatio: 1,
		},
		{
			name:          "medium ratio",
			ratio:         bigint(1 << 50),
			expectedMSB:   50,
			expectedRatio: 1,
		},
		{
			name:          "high ratio",
			ratio:         1 << 100,
			expectedMSB:   100,
			expectedRatio: 1,
		},
		{
			name:          "very high ratio",
			ratio:         1 << 110,
			expectedMSB:   110,
			expectedRatio: 1,
		},
		{
			name:          "extreme ratio",
			ratio:         1 << 200,
			expectedMSB:   200,
			expectedRatio: 1,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			msb, ratio := findMSB(tt.ratio)

			if msb != tt.expectedMSB {
				t.Errorf("expected MSB to be %d, got %d", tt.expectedMSB, msb)
			}

			if ratio != tt.expectedRatio {
				t.Errorf("expected ratio to be %d, got %d", tt.expectedRatio, ratio)
			}
		})
	}
}
