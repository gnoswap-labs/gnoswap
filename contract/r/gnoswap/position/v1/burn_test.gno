package v1

import (
	"testing"

	u256 "gno.land/p/gnoswap/uint256"
	"gno.land/p/nt/uassert"

	"gno.land/r/gnoswap/position"
)

func TestBurn_CalculateTokensOwed(t *testing.T) {
	tests := []struct {
		name                            string
		feeGrowthInsideLastX128         *u256.Uint
		positionFeeGrowthInsideLastX128 *u256.Uint
		positionLiquidity               *u256.Uint
		expected                        *u256.Uint
		expectedPanicMessage            string
		shouldPanic                     bool
	}{
		{
			name:                            "Normal case - fees accrued",
			feeGrowthInsideLastX128:         u256.MustFromDecimal("1000000000000000000000000000000000000"),
			positionFeeGrowthInsideLastX128: u256.MustFromDecimal("500000000000000000000000000000000000"),
			positionLiquidity:               u256.MustFromDecimal("1000000"),
			expected:                        u256.MustFromDecimal("1469"),
			shouldPanic:                     false,
		},
		{
			name:                            "No fees accrued - equal growth",
			feeGrowthInsideLastX128:         u256.MustFromDecimal("1000000000000000000000000000000000000"),
			positionFeeGrowthInsideLastX128: u256.MustFromDecimal("1000000000000000000000000000000000000"),
			positionLiquidity:               u256.MustFromDecimal("1000000"),
			expected:                        u256.Zero(),
			shouldPanic:                     false,
		},
		{
			name:                            "Zero liquidity",
			feeGrowthInsideLastX128:         u256.MustFromDecimal("1000000000000000000000000000000000000"),
			positionFeeGrowthInsideLastX128: u256.MustFromDecimal("500000000000000000000000000000000000"),
			positionLiquidity:               u256.Zero(),
			expected:                        u256.Zero(),
			shouldPanic:                     false,
		},
		{
			name:                            "Underflow - current less than last",
			feeGrowthInsideLastX128:         u256.MustFromDecimal("500000000000000000000000000000000000"),
			positionFeeGrowthInsideLastX128: u256.MustFromDecimal("1000000000000000000000000000000000000"),
			positionLiquidity:               u256.MustFromDecimal("1000000"),
			expectedPanicMessage:            "[GNOSWAP-POSITION-016] underflow || feeGrowthInsideLastX128 - positionFeeGrowthInsideLastX128 underflow",
			shouldPanic:                     true,
		},
		{
			name:                            "Large numbers",
			feeGrowthInsideLastX128:         u256.MustFromDecimal("99999999999999999999999999999999999999999999999999"),
			positionFeeGrowthInsideLastX128: u256.MustFromDecimal("1"),
			positionLiquidity:               u256.MustFromDecimal("999999999999999999"),
			expected:                        u256.MustFromDecimal("293873587705571876698310546599"),
			shouldPanic:                     false,
		},
		{
			name:                            "Minimal difference",
			feeGrowthInsideLastX128:         u256.MustFromDecimal("1000000000000000000000000000000000001"),
			positionFeeGrowthInsideLastX128: u256.MustFromDecimal("1000000000000000000000000000000000000"),
			positionLiquidity:               u256.MustFromDecimal("1000000"),
			expected:                        u256.Zero(),
			shouldPanic:                     false,
		},
		{
			name:                            "Zero current growth",
			feeGrowthInsideLastX128:         u256.Zero(),
			positionFeeGrowthInsideLastX128: u256.Zero(),
			positionLiquidity:               u256.MustFromDecimal("1000000"),
			expected:                        u256.Zero(),
			shouldPanic:                     false,
		},
		{
			name:                            "Fee growth wraparound - zero minus one",
			feeGrowthInsideLastX128:         u256.Zero(),
			positionFeeGrowthInsideLastX128: u256.MustFromDecimal("1"),
			positionLiquidity:               u256.MustFromDecimal("1000000"),
			expected:                        u256.MustFromDecimal("340282366920938463463374607431768211455"),
			shouldPanic:                     false,
		},
		{
			name:                            "Fee growth wraparound - small overflow",
			feeGrowthInsideLastX128:         u256.MustFromDecimal("100"),
			positionFeeGrowthInsideLastX128: u256.Zero().Sub(u256.MustFromDecimal(MAX_UINT256), u256.MustFromDecimal("50")),
			positionLiquidity:               u256.MustFromDecimal("340282366920938463463374607431768211456"),
			expected:                        u256.MustFromDecimal("151"),
			shouldPanic:                     false,
		},
		{
			name:                            "Fee growth wraparound - at boundary",
			feeGrowthInsideLastX128:         u256.Zero(),
			positionFeeGrowthInsideLastX128: u256.MustFromDecimal(MAX_UINT256),
			positionLiquidity:               u256.MustFromDecimal("340282366920938463463374607431768211456"),
			expected:                        u256.MustFromDecimal("1"),
			shouldPanic:                     false,
		},
		{
			name:                            "Fee growth wraparound - large liquidity",
			feeGrowthInsideLastX128:         u256.MustFromDecimal("1000000000000000000000000000000000000"),
			positionFeeGrowthInsideLastX128: u256.Zero().Sub(u256.MustFromDecimal(MAX_UINT256), u256.MustFromDecimal("1000000000000000000000000000000000000")),
			positionLiquidity:               u256.MustFromDecimal("1000000000000000000"),
			expected:                        u256.MustFromDecimal("5875397450499325094"),
			shouldPanic:                     false,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			initPositionTest(t)

			if tt.shouldPanic {
				uassert.PanicsWithMessage(t, tt.expectedPanicMessage, func() {
					calculateTokensOwed(tt.feeGrowthInsideLastX128, tt.positionFeeGrowthInsideLastX128, tt.positionLiquidity)
				})
			} else {
				result := calculateTokensOwed(tt.feeGrowthInsideLastX128, tt.positionFeeGrowthInsideLastX128, tt.positionLiquidity)
				uassert.Equal(t, tt.expected.ToString(), result.ToString())
			}
		})
	}
}

func TestBurn_CalculateFees(t *testing.T) {
	tests := []struct {
		name                 string
		setupPosition        func() *position.Position
		feeGrowthInside      FeeGrowthInside
		expectedTokensOwed0  *u256.Uint
		expectedTokensOwed1  *u256.Uint
		expectedPanicMessage string
		shouldPanic          bool
	}{
		{
			name: "Normal case - fees accrued on both tokens",
			setupPosition: func() *position.Position {
				pos := position.NewPosition(
					"pool:key",                      // poolKey
					int32(-887220),                  // tickLower
					int32(887220),                   // tickUpper
					u256.MustFromDecimal("1000000"), // liquidity
					u256.MustFromDecimal("100"),     // feeGrowthInside0LastX128
					u256.MustFromDecimal("200"),     // feeGrowthInside1LastX128
					u256.MustFromDecimal("10"),      // tokensOwed0
					u256.MustFromDecimal("20"),      // tokensOwed1
					u256.MustFromDecimal("500"),     // token0Balance
					u256.MustFromDecimal("600"),     // token1Balance
					false,                           // burned
					"",                              // operator
				)
				return pos
			},
			feeGrowthInside: FeeGrowthInside{
				feeGrowthInside0LastX128: u256.MustFromDecimal("340282366920938463463374607431768211556"),
				feeGrowthInside1LastX128: u256.MustFromDecimal("340282366920938463463374607431768211656"),
			},
			expectedTokensOwed0: u256.MustFromDecimal("1000010"),
			expectedTokensOwed1: u256.MustFromDecimal("1000020"),
			shouldPanic:         false,
		},
		{
			name: "No new fees - growth unchanged",
			setupPosition: func() *position.Position {
				pos := position.NewPosition(
					"pool:key",
					int32(-887220),
					int32(887220),
					u256.MustFromDecimal("1000000"),
					u256.MustFromDecimal("100"),
					u256.MustFromDecimal("200"),
					u256.MustFromDecimal("50"),
					u256.MustFromDecimal("75"),
					u256.MustFromDecimal("500"),
					u256.MustFromDecimal("600"),
					false, // burned
					"",    // operator
				)
				return pos
			},
			feeGrowthInside: FeeGrowthInside{
				feeGrowthInside0LastX128: u256.MustFromDecimal("100"),
				feeGrowthInside1LastX128: u256.MustFromDecimal("200"),
			},
			expectedTokensOwed0: u256.MustFromDecimal("50"),
			expectedTokensOwed1: u256.MustFromDecimal("75"),
			shouldPanic:         false,
		},
		{
			name: "Zero liquidity position",
			setupPosition: func() *position.Position {
				pos := position.NewPosition(
					"pool:key",
					int32(-887220),
					int32(887220),
					u256.Zero(),
					u256.MustFromDecimal("100"),
					u256.MustFromDecimal("200"),
					u256.MustFromDecimal("0"),
					u256.MustFromDecimal("0"),
					u256.Zero(),
					u256.Zero(),
					false, // burned
					"",    // operator
				)
				return pos
			},
			feeGrowthInside: FeeGrowthInside{
				feeGrowthInside0LastX128: u256.MustFromDecimal("1000"),
				feeGrowthInside1LastX128: u256.MustFromDecimal("2000"),
			},
			expectedTokensOwed0: u256.Zero(),
			expectedTokensOwed1: u256.Zero(),
			shouldPanic:         false,
		},
		{
			name: "Overflow on token0 - wraps around (Uniswap V3 behavior)",
			setupPosition: func() *position.Position {
				pos := position.NewPosition(
					"pool:key",
					int32(-887220),
					int32(887220),
					q128,
					u256.Zero(),
					u256.Zero(),
					u256.MustFromDecimal(MAX_UINT256), // Already max tokens owed
					u256.Zero(),
					u256.Zero(),
					u256.Zero(),
					false, // burned
					"",    // operator
				)
				return pos
			},
			feeGrowthInside: FeeGrowthInside{
				feeGrowthInside0LastX128: u256.MustFromDecimal("1"),
				feeGrowthInside1LastX128: u256.Zero(),
			},
			// Uniswap V3 allows overflow: MAX_UINT256 + 1 = 0
			expectedTokensOwed0: u256.Zero(),
			expectedTokensOwed1: u256.Zero(),
			shouldPanic:         false,
		},
		{
			name: "Overflow on token1 - wraps around (Uniswap V3 behavior)",
			setupPosition: func() *position.Position {
				pos := position.NewPosition(
					"pool:key",
					int32(-887220),
					int32(887220),
					q128,
					u256.Zero(),
					u256.Zero(),
					u256.Zero(),
					u256.MustFromDecimal(MAX_UINT256), // Already max tokens owed
					u256.Zero(),
					u256.Zero(),
					false, // burned
					"",    // operator
				)
				return pos
			},
			feeGrowthInside: FeeGrowthInside{
				feeGrowthInside0LastX128: u256.Zero(),
				feeGrowthInside1LastX128: u256.MustFromDecimal("1"),
			},
			// Uniswap V3 allows overflow: MAX_UINT256 + 1 = 0
			expectedTokensOwed0: u256.Zero(),
			expectedTokensOwed1: u256.Zero(),
			shouldPanic:         false,
		},
		{
			name: "Large fees calculation",
			setupPosition: func() *position.Position {
				pos := position.NewPosition(
					"pool:key",
					int32(-887220),
					int32(887220),
					u256.MustFromDecimal("100000000000000000"),
					u256.Zero(),
					u256.Zero(),
					u256.MustFromDecimal("1000"),
					u256.MustFromDecimal("2000"),
					u256.MustFromDecimal("50000000"),
					u256.MustFromDecimal("60000000"),
					false, // burned
					"",    // operator
				)
				return pos
			},
			feeGrowthInside: FeeGrowthInside{
				feeGrowthInside0LastX128: u256.MustFromDecimal("340282366920938463463374607431768211456"),
				feeGrowthInside1LastX128: u256.MustFromDecimal("680564733841876926926749214863536422912"),
			},
			expectedTokensOwed0: u256.MustFromDecimal("100000000000001000"),
			expectedTokensOwed1: u256.MustFromDecimal("200000000000002000"),
			shouldPanic:         false,
		},
		{
			name: "Existing tokens owed with new fees",
			setupPosition: func() *position.Position {
				pos := position.NewPosition(
					"pool:key",
					int32(-887220),
					int32(887220),
					u256.MustFromDecimal("1000000"),
					u256.MustFromDecimal("100"),
					u256.MustFromDecimal("200"),
					u256.MustFromDecimal("999999"),
					u256.MustFromDecimal("888888"),
					u256.MustFromDecimal("5000"),
					u256.MustFromDecimal("6000"),
					false, // burned
					"",    // operator
				)
				return pos
			},
			feeGrowthInside: FeeGrowthInside{
				feeGrowthInside0LastX128: u256.MustFromDecimal("340282366920938463463374607431768211556"),
				feeGrowthInside1LastX128: u256.MustFromDecimal("340282366920938463463374607431768211656"),
			},
			expectedTokensOwed0: u256.MustFromDecimal("1999999"),
			expectedTokensOwed1: u256.MustFromDecimal("1888888"),
			shouldPanic:         false,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			initPositionTest(t)

			position := tt.setupPosition()

			if tt.shouldPanic {
				uassert.PanicsWithMessage(t, tt.expectedPanicMessage, func() {
					mockInstance.calculateFees(position, tt.feeGrowthInside)
				})
			} else {
				tokensOwed0, tokensOwed1 := mockInstance.calculateFees(position, tt.feeGrowthInside)
				uassert.Equal(t, tt.expectedTokensOwed0.ToString(), tokensOwed0.ToString(), "tokensOwed0 mismatch")
				uassert.Equal(t, tt.expectedTokensOwed1.ToString(), tokensOwed1.ToString(), "tokensOwed1 mismatch")
			}
		})
	}
}

func TestFeeCalculation_WraparoundConsistency(t *testing.T) {
	tests := []struct {
		name                            string
		feeGrowthInsideLastX128         *u256.Uint
		positionFeeGrowthInsideLastX128 *u256.Uint
		positionLiquidity               *u256.Uint
		expectedDiff                    *u256.Uint
		description                     string
	}{
		{
			name:                            "Normal case - no wraparound",
			feeGrowthInsideLastX128:         u256.MustFromDecimal("1000"),
			positionFeeGrowthInsideLastX128: u256.MustFromDecimal("500"),
			positionLiquidity:               u256.MustFromDecimal("340282366920938463463374607431768211456"),
			expectedDiff:                    u256.MustFromDecimal("500"),
			description:                     "Standard case: current > last, diff = 500",
		},
		{
			name:                            "Wraparound case - current < last",
			feeGrowthInsideLastX128:         u256.MustFromDecimal("100"),
			positionFeeGrowthInsideLastX128: u256.Zero().Sub(u256.MustFromDecimal(MAX_UINT256), u256.MustFromDecimal("50")),
			positionLiquidity:               u256.MustFromDecimal("340282366920938463463374607431768211456"),
			expectedDiff:                    u256.MustFromDecimal("151"),
			description:                     "Wraparound: 100 - (MAX-50) = 151 via wraparound",
		},
		{
			name:                            "Exact wraparound boundary",
			feeGrowthInsideLastX128:         u256.Zero(),
			positionFeeGrowthInsideLastX128: u256.MustFromDecimal(MAX_UINT256),
			positionLiquidity:               u256.MustFromDecimal("340282366920938463463374607431768211456"),
			expectedDiff:                    u256.MustFromDecimal("1"),
			description:                     "Boundary: 0 - MAX = 1 via wraparound",
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			initPositionTest(t)

			actualDiff := subUint256(tt.feeGrowthInsideLastX128, tt.positionFeeGrowthInsideLastX128)
			uassert.Equal(t, tt.expectedDiff.ToString(), actualDiff.ToString(), tt.description)

			result := calculateTokensOwed(tt.feeGrowthInsideLastX128, tt.positionFeeGrowthInsideLastX128, tt.positionLiquidity)

			expectedFee := u256.MulDiv(tt.expectedDiff, tt.positionLiquidity, q128)
			uassert.Equal(t, expectedFee.ToString(), result.ToString(), "calculateTokensOwed result mismatch")
		})
	}
}
