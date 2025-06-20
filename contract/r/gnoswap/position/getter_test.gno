package position

import (
	"std"
	"testing"

	"gno.land/p/demo/uassert"
	u256 "gno.land/p/gnoswap/uint256"
)

func setupPositionGetter(t *testing.T) {
	t.Helper()

	CreatePoolWithoutFee(t)
	testing.SetRealm(std.NewUserRealm(adminAddr))
	position := Position{
		nonce:                    u256.Zero(),
		operator:                 positionAddr,
		poolKey:                  "gno.land/r/onbloc/bar:gno.land/r/onbloc/foo:500",
		tickLower:                -10000,
		tickUpper:                10000,
		liquidity:                u256.NewUint(1000000),
		feeGrowthInside0LastX128: u256.Zero(),
		feeGrowthInside1LastX128: u256.Zero(),
		tokensOwed0:              u256.Zero(),
		tokensOwed1:              u256.Zero(),
		burned:                   false,
	}
	positionId := GetNextId()
	createNewPosition(positionId, position)
}

func TestPositionGetter(t *testing.T) {
	positionId := uint64(1)
	setupPositionGetter(t)

	testCases := []struct {
		name     string
		testFunc func() any
		expected any
	}{
		{
			name: "GetPosition - poolKey",
			testFunc: func() any {
				position := PositionGetPosition(positionId)
				return position.poolKey
			},
			expected: "gno.land/r/onbloc/bar:gno.land/r/onbloc/foo:500",
		},
		{
			name: "GetPosition - tickLower",
			testFunc: func() any {
				position := PositionGetPosition(positionId)
				return position.tickLower
			},
			expected: int32(-10000),
		},
		{
			name: "GetPosition - tickUpper",
			testFunc: func() any {
				position := PositionGetPosition(positionId)
				return position.tickUpper
			},
			expected: int32(10000),
		},
		{
			name: "GetPosition - liquidity",
			testFunc: func() any {
				position := PositionGetPosition(positionId)
				return position.liquidity.ToString()
			},
			expected: "1000000",
		},
		{
			name: "GetPosition - feeGrowthInside0LastX128",
			testFunc: func() any {
				position := PositionGetPosition(positionId)
				return position.feeGrowthInside0LastX128.ToString()
			},
			expected: "0",
		},
		{
			name: "GetPosition - feeGrowthInside1LastX128",
			testFunc: func() any {
				position := PositionGetPosition(positionId)
				return position.feeGrowthInside1LastX128.ToString()
			},
			expected: "0",
		},
		{
			name: "GetPosition - tokensOwed0",
			testFunc: func() any {
				position := PositionGetPosition(positionId)
				return position.tokensOwed0.ToString()
			},
			expected: "0",
		},
		{
			name: "GetPosition - tokensOwed1",
			testFunc: func() any {
				position := PositionGetPosition(positionId)
				return position.tokensOwed1.ToString()
			},
			expected: "0",
		},
		{
			name: "GetPosition - burned",
			testFunc: func() any {
				position := PositionGetPosition(positionId)
				return position.burned
			},
			expected: false,
		},
		{
			name: "GetPositionNonce",
			testFunc: func() any {
				return PositionGetPositionNonce(positionId).ToString()
			},
			expected: "0",
		},
		{
			name: "GetPositionOperator",
			testFunc: func() any {
				return PositionGetPositionOperator(positionId)
			},
			expected: positionAddr,
		},
		{
			name: "GetPositionPoolKey",
			testFunc: func() any {
				return PositionGetPositionPoolKey(positionId)
			},
			expected: "gno.land/r/onbloc/bar:gno.land/r/onbloc/foo:500",
		},
		{
			name: "GetPositionTickLower",
			testFunc: func() any {
				return PositionGetPositionTickLower(positionId)
			},
			expected: int32(-10000),
		},
		{
			name: "GetPositionTickUpper",
			testFunc: func() any {
				return PositionGetPositionTickUpper(positionId)
			},
			expected: int32(10000),
		},
		{
			name: "GetPositionLiquidity",
			testFunc: func() any {
				return PositionGetPositionLiquidity(positionId).ToString()
			},
			expected: "1000000",
		},
		{
			name: "GetPositionFeeGrowthInside0LastX128",
			testFunc: func() any {
				return PositionGetPositionFeeGrowthInside0LastX128(positionId).ToString()
			},
			expected: "0",
		},
		{
			name: "GetPositionFeeGrowthInside1LastX128",
			testFunc: func() any {
				return PositionGetPositionFeeGrowthInside1LastX128(positionId).ToString()
			},
			expected: "0",
		},
		{
			name: "GetPositionTokensOwed0",
			testFunc: func() any {
				return PositionGetPositionTokensOwed0(positionId).ToString()
			},
			expected: "0",
		},
		{
			name: "GetPositionTokensOwed1",
			testFunc: func() any {
				return PositionGetPositionTokensOwed1(positionId).ToString()
			},
			expected: "0",
		},
		{
			name: "GetPositionIsBurned",
			testFunc: func() any {
				return PositionGetPositionIsBurned(positionId)
			},
			expected: false,
		},
		{
			name: "IsInRange",
			testFunc: func() any {
				return PositionIsInRange(positionId)
			},
			expected: true,
		},
		{
			name: "GetPositionNonceStr",
			testFunc: func() any {
				return PositionGetPositionNonceStr(positionId)
			},
			expected: "0",
		},
		{
			name: "GetPositionOperatorStr",
			testFunc: func() any {
				return PositionGetPositionOperatorStr(positionId)
			},
			expected: string(positionAddr),
		},
		{
			name: "GetPositionLiquidityStr",
			testFunc: func() any {
				return PositionGetPositionLiquidityStr(positionId)
			},
			expected: "1000000",
		},
		{
			name: "GetPositionFeeGrowthInside0LastX128Str",
			testFunc: func() any {
				return PositionGetPositionFeeGrowthInside0LastX128Str(positionId)
			},
			expected: "0",
		},
		{
			name: "GetPositionFeeGrowthInside1LastX128Str",
			testFunc: func() any {
				return PositionGetPositionFeeGrowthInside1LastX128Str(positionId)
			},
			expected: "0",
		},
		{
			name: "GetPositionTokensOwed0Str",
			testFunc: func() any {
				return PositionGetPositionTokensOwed0Str(positionId)
			},
			expected: "0",
		},
		{
			name: "GetPositionTokensOwed1Str",
			testFunc: func() any {
				return PositionGetPositionTokensOwed1Str(positionId)
			},
			expected: "0",
		},
	}

	for _, tt := range testCases {
		t.Run(tt.name, func(t *testing.T) {
			result := tt.testFunc()
			uassert.Equal(t, tt.expected, result)
		})
	}
}
