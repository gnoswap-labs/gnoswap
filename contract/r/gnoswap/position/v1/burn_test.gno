package v1

import (
	"testing"
	"time"

	u256 "gno.land/p/gnoswap/uint256"
	uassert "gno.land/p/nt/uassert/v0"

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
			expectedPanicMessage:            "[GNOSWAP-POSITION-013] underflow || feeGrowthInsideLastX128 - positionFeeGrowthInsideLastX128 underflow",
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
			name:                            "Underflow with zero current",
			feeGrowthInsideLastX128:         u256.Zero(),
			positionFeeGrowthInsideLastX128: u256.MustFromDecimal("1"),
			positionLiquidity:               u256.MustFromDecimal("1000000"),
			expectedPanicMessage:            "[GNOSWAP-POSITION-013] underflow || feeGrowthInsideLastX128 - positionFeeGrowthInsideLastX128 underflow",
			shouldPanic:                     true,
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
			name: "Overflow on token0",
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
					false, // burned
					"",    // operator
				)
				return pos
			},
			feeGrowthInside: FeeGrowthInside{
				feeGrowthInside0LastX128: u256.MustFromDecimal("1"),
				feeGrowthInside1LastX128: u256.Zero(),
			},
			expectedPanicMessage: "[GNOSWAP-POSITION-014] overflow || tokensOwed0 + fee0 overflow",
			shouldPanic:          true,
		},
		{
			name: "Allow overflow on token1",
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
					false, // burned
					"",    // operator
				)
				return pos
			},
			feeGrowthInside: FeeGrowthInside{
				feeGrowthInside0LastX128: u256.Zero(),
				feeGrowthInside1LastX128: u256.MustFromDecimal("1"),
			},
			expectedPanicMessage: "[GNOSWAP-POSITION-014] overflow || tokensOwed1 + fee1 overflow",
			shouldPanic:          true,
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

func TestDecreaseLiquidity_TokensOwedOverflow(t *testing.T) {
	tests := []struct {
		name             string
		tokensOwed0      *u256.Uint
		tokensOwed1      *u256.Uint
		expectedPanicMsg string
	}{
		{
			name:             "overflow on tokensOwed0 + burnedAmount0",
			tokensOwed0:      u256.MustFromDecimal(MAX_UINT256),
			tokensOwed1:      u256.Zero(),
			expectedPanicMsg: "[GNOSWAP-POSITION-014] overflow || tokensOwed0(",
		},
		{
			name:             "overflow on tokensOwed1 + burnedAmount1",
			tokensOwed0:      u256.Zero(),
			tokensOwed1:      u256.MustFromDecimal(MAX_UINT256),
			expectedPanicMsg: "[GNOSWAP-POSITION-014] overflow || tokensOwed1(",
		},
		{
			name:             "overflow on both tokensOwed0 and tokensOwed1",
			tokensOwed0:      u256.MustFromDecimal(MAX_UINT256),
			tokensOwed1:      u256.MustFromDecimal(MAX_UINT256),
			expectedPanicMsg: "[GNOSWAP-POSITION-014] overflow || tokensOwed0(",
		},
	}

	for _, tc := range tests {
		t.Run(tc.name, func(t *testing.T) {
			initPositionTest(t)
			createPoolWithoutFee(barPath, fooPath, fee500, 0)

			testing.SetRealm(adminRealm)
			mockInstanceMint(
				barPath, fooPath, fee500,
				-10000, 10000,
				"1000000", "1000000",
				"0", "0",
				time.Now().Add(time.Hour).Unix(),
				adminAddr, adminAddr, "",
			)

			pos := mockInstance.mustGetPosition(1)
			pos.SetTokensOwed0(u256.Zero().Set(tc.tokensOwed0))
			pos.SetTokensOwed1(u256.Zero().Set(tc.tokensOwed1))
			mockInstance.mustUpdatePosition(1, *pos)

			testing.SetRealm(testing.NewUserRealm(adminAddr))
			uassert.AbortsContains(t, tc.expectedPanicMsg, func() {
				mockInstanceDecreaseLiquidity(
					1,
					"100",
					"0", "0",
					time.Now().Add(time.Hour).Unix(),
				)
			})
		})
	}
}
