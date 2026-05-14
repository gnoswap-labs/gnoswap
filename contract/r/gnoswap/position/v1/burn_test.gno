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
			name:                            "Wrapped underflow computes modular delta",
			feeGrowthInsideLastX128:         q128.Clone(),
			positionFeeGrowthInsideLastX128: u256.MustFromDecimal(MAX_UINT256),
			positionLiquidity:               u256.One(),
			expected:                        u256.One(),
			shouldPanic:                     false,
		},
		{
			name:                            "Wrapped underflow computes upstream overflow-boundary value 16",
			feeGrowthInsideLastX128:         u256.MustFromDecimal("15"),
			positionFeeGrowthInsideLastX128: u256.MustFromDecimal(MAX_UINT256),
			positionLiquidity:               q128.Clone(),
			expected:                        u256.MustFromDecimal("16"),
			shouldPanic:                     false,
		},
		{
			name:                            "Wrapped underflow computes upstream overflow-boundary value 13",
			feeGrowthInsideLastX128:         u256.Zero(),
			positionFeeGrowthInsideLastX128: u256.MustFromDecimal(maxUint256Minus12),
			positionLiquidity:               q128.Clone(),
			expected:                        u256.MustFromDecimal("13"),
			shouldPanic:                     false,
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
			name:                            "Wrapped underflow with zero current",
			feeGrowthInsideLastX128:         u256.Zero(),
			positionFeeGrowthInsideLastX128: u256.MustFromDecimal(MAX_UINT256),
			positionLiquidity:               u256.MustFromDecimal("1000000"),
			expected:                        u256.Zero(),
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
		expectedTokensOwed0  int64
		expectedTokensOwed1  int64
		expectedPanicMessage string
		shouldPanic          bool
	}{
		{
			name: "Normal case - fees accrued on both tokens",
			setupPosition: func() *position.Position {
				pos := position.NewPosition(
					"pool:key",     // poolKey
					int32(-887220), // tickLower
					int32(887220),  // tickUpper
					"1000000",      // liquidity
					"100",          // feeGrowthInside0LastX128
					"200",          // feeGrowthInside1LastX128
					10,             // tokensOwed0
					20,             // tokensOwed1
					false,          // burned
					"",             // operator
				)
				return pos
			},
			feeGrowthInside: FeeGrowthInside{
				feeGrowthInside0LastX128: u256.MustFromDecimal("340282366920938463463374607431768211556"),
				feeGrowthInside1LastX128: u256.MustFromDecimal("340282366920938463463374607431768211656"),
			},
			expectedTokensOwed0: 1000010,
			expectedTokensOwed1: 1000020,
			shouldPanic:         false,
		},
		{
			name: "No new fees - growth unchanged",
			setupPosition: func() *position.Position {
				pos := position.NewPosition(
					"pool:key",
					int32(-887220),
					int32(887220),
					"1000000",
					"100",
					"200",
					50,
					75,
					false, // burned
					"",    // operator
				)
				return pos
			},
			feeGrowthInside: FeeGrowthInside{
				feeGrowthInside0LastX128: u256.MustFromDecimal("100"),
				feeGrowthInside1LastX128: u256.MustFromDecimal("200"),
			},
			expectedTokensOwed0: 50,
			expectedTokensOwed1: 75,
			shouldPanic:         false,
		},
		{
			name: "Zero liquidity position",
			setupPosition: func() *position.Position {
				pos := position.NewPosition(
					"pool:key",
					int32(-887220),
					int32(887220),
					"0",
					"100",
					"200",
					0,
					0,
					false, // burned
					"",    // operator
				)
				return pos
			},
			feeGrowthInside: FeeGrowthInside{
				feeGrowthInside0LastX128: u256.MustFromDecimal("1000"),
				feeGrowthInside1LastX128: u256.MustFromDecimal("2000"),
			},
			expectedTokensOwed0: 0,
			expectedTokensOwed1: 0,
			shouldPanic:         false,
		},
		{
			name: "Wrapped fee growth adds one token owed",
			setupPosition: func() *position.Position {
				pos := position.NewPosition(
					"pool:key",
					int32(-887220),
					int32(887220),
					"1",
					u256.MustFromDecimal(MAX_UINT256).ToString(),
					u256.MustFromDecimal(MAX_UINT256).ToString(),
					7,
					9,
					false,
					"",
				)
				return pos
			},
			feeGrowthInside: FeeGrowthInside{
				feeGrowthInside0LastX128: q128.Clone(),
				feeGrowthInside1LastX128: q128.Clone(),
			},
			expectedTokensOwed0: 8,
			expectedTokensOwed1: 10,
			shouldPanic:         false,
		},
		{
			name: "Wrapped fee growth mirrors upstream overflow boundary values",
			setupPosition: func() *position.Position {
				pos := position.NewPosition(
					"pool:key",
					int32(-887220),
					int32(887220),
					q128.ToString(),
					u256.MustFromDecimal(MAX_UINT256).ToString(),
					u256.MustFromDecimal(maxUint256Minus12).ToString(),
					0,
					0,
					false,
					"",
				)
				return pos
			},
			feeGrowthInside: FeeGrowthInside{
				feeGrowthInside0LastX128: u256.MustFromDecimal("15"),
				feeGrowthInside1LastX128: u256.Zero(),
			},
			expectedTokensOwed0: 16,
			expectedTokensOwed1: 13,
			shouldPanic:         false,
		},
		{
			name: "Wrapped fee growth adds overflow-boundary deltas on top of existing tokens owed",
			setupPosition: func() *position.Position {
				pos := position.NewPosition(
					"pool:key",
					int32(-887220),
					int32(887220),
					q128.ToString(),
					u256.MustFromDecimal(MAX_UINT256).ToString(),
					u256.MustFromDecimal(maxUint256Minus12).ToString(),
					7,
					9,
					false,
					"",
				)
				return pos
			},
			feeGrowthInside: FeeGrowthInside{
				feeGrowthInside0LastX128: u256.MustFromDecimal("15"),
				feeGrowthInside1LastX128: u256.Zero(),
			},
			expectedTokensOwed0: 23,
			expectedTokensOwed1: 22,
			shouldPanic:         false,
		},
		{
			name: "Overflow on token0",
			setupPosition: func() *position.Position {
				pos := position.NewPosition(
					"pool:key",
					int32(-887220),
					int32(887220),
					q128.ToString(),
					"0",
					"0",
					9223372036854775807, // Already max tokens owed
					0,
					false, // burned
					"",    // operator
				)
				return pos
			},
			feeGrowthInside: FeeGrowthInside{
				feeGrowthInside0LastX128: u256.MustFromDecimal("1"),
				feeGrowthInside1LastX128: u256.Zero(),
			},
			expectedPanicMessage: "int64 addition overflow",
			shouldPanic:          true,
		},
		{
			name: "Allow overflow on token1",
			setupPosition: func() *position.Position {
				pos := position.NewPosition(
					"pool:key",
					int32(-887220),
					int32(887220),
					q128.ToString(),
					"0",
					"0",
					0,
					9223372036854775807, // Already max tokens owed
					false, // burned
					"",    // operator
				)
				return pos
			},
			feeGrowthInside: FeeGrowthInside{
				feeGrowthInside0LastX128: u256.Zero(),
				feeGrowthInside1LastX128: u256.MustFromDecimal("1"),
			},
			expectedPanicMessage: "int64 addition overflow",
			shouldPanic:          true,
		},
		{
			name: "Large fees calculation",
			setupPosition: func() *position.Position {
				pos := position.NewPosition(
					"pool:key",
					int32(-887220),
					int32(887220),
					"100000000000000000",
					"0",
					"0",
					1000,
					2000,
					false, // burned
					"",    // operator
				)
				return pos
			},
			feeGrowthInside: FeeGrowthInside{
				feeGrowthInside0LastX128: u256.MustFromDecimal("340282366920938463463374607431768211456"),
				feeGrowthInside1LastX128: u256.MustFromDecimal("680564733841876926926749214863536422912"),
			},
			expectedTokensOwed0: 100000000000001000,
			expectedTokensOwed1: 200000000000002000,
			shouldPanic:         false,
		},
		{
			name: "Existing tokens owed with new fees",
			setupPosition: func() *position.Position {
				pos := position.NewPosition(
					"pool:key",
					int32(-887220),
					int32(887220),
					"1000000",
					"100",
					"200",
					999999,
					888888,
					false, // burned
					"",    // operator
				)
				return pos
			},
			feeGrowthInside: FeeGrowthInside{
				feeGrowthInside0LastX128: u256.MustFromDecimal("340282366920938463463374607431768211556"),
				feeGrowthInside1LastX128: u256.MustFromDecimal("340282366920938463463374607431768211656"),
			},
			expectedTokensOwed0: 1999999,
			expectedTokensOwed1: 1888888,
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
				uassert.Equal(t, tt.expectedTokensOwed0, tokensOwed0, "tokensOwed0 mismatch")
				uassert.Equal(t, tt.expectedTokensOwed1, tokensOwed1, "tokensOwed1 mismatch")
			}
		})
	}
}

func TestDecreaseLiquidity_TokensOwedOverflow(t *testing.T) {
	MAX_INT64 := int64(9223372036854775807)

	tests := []struct {
		name             string
		tokensOwed0      int64
		tokensOwed1      int64
		expectedPanicMsg string
	}{
		{
			name:             "overflow on tokensOwed0 + burnedAmount0",
			tokensOwed0:      MAX_INT64,
			tokensOwed1:      0,
			expectedPanicMsg: "int64 addition overflow",
		},
		{
			name:             "overflow on tokensOwed1 + burnedAmount1",
			tokensOwed0:      0,
			tokensOwed1:      MAX_INT64,
			expectedPanicMsg: "int64 addition overflow",
		},
		{
			name:             "overflow on both tokensOwed0 and tokensOwed1",
			tokensOwed0:      MAX_INT64,
			tokensOwed1:      MAX_INT64,
			expectedPanicMsg: "int64 addition overflow",
		},
	}

	for _, tc := range tests {
		t.Run(tc.name, func(t *testing.T) {
			initPositionTest(t)
			createPoolWithoutFee(atomPath, btcPath, fee500, 0)

			testing.SetRealm(adminRealm)
			mockInstanceMint(
				atomPath, btcPath, fee500,
				-10000, 10000,
				"1000000", "1000000",
				"0", "0",
				time.Now().Add(time.Hour).Unix(),
				adminAddr, adminAddr, "",
			)

			pos := mockInstance.mustGetPosition(1)
			pos.SetTokensOwed0(tc.tokensOwed0)
			pos.SetTokensOwed1(tc.tokensOwed1)
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
