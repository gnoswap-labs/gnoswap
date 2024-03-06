package common

import (
	"testing"

	"gno.land/r/demo/consts"
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

func TestTickMathGetSqrtRatioAtTick(t *testing.T) {
	testCases := []struct {
		name     string
		tick     int32
		expected bigint
		isErr    bool
	}{
		{
			name:     "positive 1",
			tick:     1,
			expected: 79232123823359799118286999568,
			isErr:    false,
		},
		{
			name:     "Test Case 1",
			tick:     int32(10),
			expected: 79267784519130042428790663799,
			isErr:    false,
		},
		{
			name:     "Test Case 2",
			tick:     int32(20),
			expected: 79307426338960776842885539845,
			isErr:    false,
		},
		{
			name:     "Test Case 3",
			tick:     int32(30),
			expected: 79347087983666005045280518415,
			isErr:    false,
		},
		{
			name:     "negative tick",
			tick:     -1,
			expected: 79224201403219477170569942574,
			isErr:    false,
		},
		{
			name:     "zero tick",
			tick:     0,
			expected: 79228162514264337593543950337,
			isErr:    false,
		},
		{
			name:     "maximum tick",
			tick:     887272,
			expected: 1461446703485210103287273052203988822378723970342,
			isErr:    false,
		},
		{
			name:     "minimum tick",
			tick:     -887272,
			expected: 4295128739,
			isErr:    false,
		},
	}

	for _, tc := range testCases {
		t.Run(tc.name, func(t *testing.T) {
			result := TickMathGetSqrtRatioAtTick(tc.tick)
			if tc.isErr && result != 0 {
				t.Errorf("(%s) expected error, got %d", tc.name, result)
			}

			if result != tc.expected {
				t.Errorf("(%s) expected %d, got %d", tc.name, tc.expected, result)
			}
		})
	}
}

func TestTickMathGetTickAtSqrtRatio(t *testing.T) {
	testCases := []struct {
		name           string
		sqrtPriceX96   bigint
		expectedResult int32
		isErr          bool
	}{
		{
			name:           "Test Case 1",
			sqrtPriceX96:   130621891405341611593710811006,
			expectedResult: int32(10000),
			isErr:          false,
		},
		{
			name:           "max uint64",
			sqrtPriceX96:   consts.MAX_UINT64,
			expectedResult: -443637,
			isErr:          false,
		},
		{
			name:           "max uint128",
			sqrtPriceX96:   consts.MAX_UINT128,
			expectedResult: 443636,
			isErr:          false,
		},
		{
			name:           "min sqrt ratio",
			sqrtPriceX96:   consts.MIN_SQRT_RATIO,
			expectedResult: -887272,
			isErr:          false,
		},
		{
			name:           "q96",
			sqrtPriceX96:   consts.Q96,
			expectedResult: -1,
			isErr:          false,
		},
		{
			name:           "q128",
			sqrtPriceX96:   consts.Q128,
			expectedResult: 443636,
			isErr:          false,
		},
		{
			name:           "Test Case for typical sqrtPriceX96",
			sqrtPriceX96:   79228162514264337593543950336,
			expectedResult: -1,
			isErr:          false,
		},
	}

	for _, tc := range testCases {
		t.Run(tc.name, func(t *testing.T) {
			result := TickMathGetTickAtSqrtRatio(tc.sqrtPriceX96)

			if tc.isErr && result != 0 {
				t.Errorf("(%s) expected error, got %d", tc.name, result)
			}
		})
	}
}

func TestCalculateLog2(t *testing.T) {
	testCases := []struct {
		name     string
		msb      bigint
		ratio    bigint
		expected bigint
	}{
		{
			name:     "100",
			msb:      100,
			ratio:    1000,
			expected: -516508834063867445248,
		},
		{
			name:     "msb at higher bound with ratio 1",
			msb:      256,
			ratio:    1,
			expected: 2361183241434822606848,
		},
		{
			name:     "higher msb with higher ratio",
			msb:      256,
			ratio:    2,
			expected: 2361183241434822606848,
		},
		{
			name:     "lower bound",
			msb:      128,
			ratio:    1 << 127,
			expected: 0,
		},
		{
			name:     "high msb with exact square",
			msb:      256,
			ratio:    1 << 128,
			expected: 2379629985508532158464,
		},
		{
			name:     "double value",
			msb:      129,
			ratio:    1 << 128,
			expected: 1 << 64,
		},
	}

	for _, tc := range testCases {
		t.Run(tc.name, func(t *testing.T) {
			result := calculateLog2(tc.msb, tc.ratio)

			if result != tc.expected {
				t.Errorf("(%s) expected %d, got %d", tc.name, tc.expected, result)
			}
		})
	}
}
