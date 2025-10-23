package v1

import (
	"testing"

	"gno.land/p/nt/uassert"
)

var poolKey = "gno.land/r/onbloc/bar:gno.land/r/onbloc/foo:500"

func setupPositionGetter(t *testing.T) {
	t.Helper()
	initPositionTest(t)

	createPoolWithoutFee(barPath, fooPath, fee500, 0)

	mockInstanceMint(barPath, fooPath, fee500, -10000, 10000, "1000000", "1000000", "0", "0", 9999999999, adminAddr, adminAddr, "")
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
			name: "get position is success by poolKey",
			testFunc: func() any {
				position := mockInstance.mustGetPosition(positionId)
				return position.PoolKey()
			},
			expected: poolKey,
		},
		{
			name: "get position is success by tickLower",
			testFunc: func() any {
				position := mockInstance.mustGetPosition(positionId)
				return position.TickLower()
			},
			expected: int32(-10000),
		},
		{
			name: "get position is success by tickUpper",
			testFunc: func() any {
				position := mockInstance.mustGetPosition(positionId)
				return position.TickUpper()
			},
			expected: int32(10000),
		},
		{
			name: "get position is success by liquidity",
			testFunc: func() any {
				position := mockInstance.mustGetPosition(positionId)
				return position.Liquidity().ToString()
			},
			expected: "2541592",
		},
		{
			name: "get position is success by feeGrowthInside0LastX128",
			testFunc: func() any {
				position := mockInstance.mustGetPosition(positionId)
				return position.FeeGrowthInside0LastX128().ToString()
			},
			expected: "0",
		},
		{
			name: "get position is success by feeGrowthInside1LastX128",
			testFunc: func() any {
				position := mockInstance.mustGetPosition(positionId)
				return position.FeeGrowthInside1LastX128().ToString()
			},
			expected: "0",
		},
		{
			name: "get position is success by tokensOwed0",
			testFunc: func() any {
				position := mockInstance.mustGetPosition(positionId)
				return position.TokensOwed0().ToString()
			},
			expected: "0",
		},
		{
			name: "get position is success by tokensOwed1",
			testFunc: func() any {
				position := mockInstance.mustGetPosition(positionId)
				return position.TokensOwed1().ToString()
			},
			expected: "0",
		},
		{
			name: "get position is success by burned",
			testFunc: func() any {
				position := mockInstance.mustGetPosition(positionId)
				return position.Burned()
			},
			expected: false,
		},
		{
			name: "get position is success by liquidity",
			testFunc: func() any {
				return mockInstance.mustGetPosition(positionId).Liquidity().ToString()
			},
			expected: "2541592",
		},
		{
			name: "get position is success by feeGrowthInside0LastX128",
			testFunc: func() any {
				return mockInstance.mustGetPosition(positionId).FeeGrowthInside0LastX128().ToString()
			},
			expected: "0",
		},
		{
			name: "get position is success by feeGrowthInside1LastX128",
			testFunc: func() any {
				return mockInstance.mustGetPosition(positionId).FeeGrowthInside1LastX128().ToString()
			},
			expected: "0",
		},
		{
			name: "get position is success by tokensOwed0",
			testFunc: func() any {
				return mockInstance.mustGetPosition(positionId).TokensOwed0().ToString()
			},
			expected: "0",
		},
		{
			name: "get position is success by tokensOwed1",
			testFunc: func() any {
				return mockInstance.mustGetPosition(positionId).TokensOwed1().ToString()
			},
			expected: "0",
		},
		{
			name: "get position is success by isBurned",
			testFunc: func() any {
				return mockInstance.IsBurned(positionId)
			},
			expected: false,
		},
		{
			name: "get position is success by isInRange",
			testFunc: func() any {
				return mockInstance.IsInRange(positionId)
			},
			expected: true,
		},
	}

	for _, tt := range testCases {
		t.Run(tt.name, func(t *testing.T) {
			result := tt.testFunc()
			uassert.Equal(t, tt.expected, result)
		})
	}
}
