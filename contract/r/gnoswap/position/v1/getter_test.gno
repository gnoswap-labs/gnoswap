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

func setupMultiplePositions(t *testing.T) {
	t.Helper()
	initPositionTest(t)

	createPoolWithoutFee(barPath, fooPath, fee500, 0)

	// Create 3 positions with different tick ranges
	mockInstanceMint(barPath, fooPath, fee500, -10000, 10000, "1000000", "1000000", "0", "0", 9999999999, adminAddr, adminAddr, "")
	mockInstanceMint(barPath, fooPath, fee500, -5000, 5000, "500000", "500000", "0", "0", 9999999999, adminAddr, adminAddr, "")
	mockInstanceMint(barPath, fooPath, fee500, -2000, 2000, "200000", "200000", "0", "0", 9999999999, adminAddr, adminAddr, "")
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

func TestGetPositionCount(t *testing.T) {
	testCases := []struct {
		name     string
		setup    func(t *testing.T)
		expected int
	}{
		{
			name: "empty store returns zero",
			setup: func(t *testing.T) {
				initPositionTest(t)
			},
			expected: 0,
		},
		{
			name: "returns correct count after minting 3 positions",
			setup: func(t *testing.T) {
				setupMultiplePositions(t)
			},
			expected: 3,
		},
		{
			name: "returns correct count after single mint",
			setup: func(t *testing.T) {
				setupPositionGetter(t)
			},
			expected: 1,
		},
	}

	for _, tc := range testCases {
		t.Run(tc.name, func(t *testing.T) {
			tc.setup(t)
			count := mockInstance.GetPositionCount()
			uassert.Equal(t, tc.expected, count)
		})
	}
}

func TestGetPositionIDs(t *testing.T) {
	testCases := []struct {
		name           string
		setup          func(t *testing.T)
		offset         int
		count          int
		expectedLength int
	}{
		{
			name: "empty store returns empty slice",
			setup: func(t *testing.T) {
				initPositionTest(t)
			},
			offset:         0,
			count:          10,
			expectedLength: 0,
		},
		{
			name: "returns all position IDs",
			setup: func(t *testing.T) {
				setupMultiplePositions(t)
			},
			offset:         0,
			count:          10,
			expectedLength: 3,
		},
		{
			name: "pagination with offset 0 and count 2",
			setup: func(t *testing.T) {
				setupMultiplePositions(t)
			},
			offset:         0,
			count:          2,
			expectedLength: 2,
		},
		{
			name: "pagination with offset 2 returns remaining",
			setup: func(t *testing.T) {
				setupMultiplePositions(t)
			},
			offset:         2,
			count:          10,
			expectedLength: 1,
		},
		{
			name: "offset beyond range returns empty",
			setup: func(t *testing.T) {
				setupMultiplePositions(t)
			},
			offset:         100,
			count:          10,
			expectedLength: 0,
		},
	}

	for _, tc := range testCases {
		t.Run(tc.name, func(t *testing.T) {
			tc.setup(t)
			ids := mockInstance.GetPositionIDs(tc.offset, tc.count)
			uassert.Equal(t, tc.expectedLength, len(ids))
		})
	}
}

func TestGetPositionTokenBalances(t *testing.T) {
	setupPositionGetter(t)
	positionId := uint64(1)

	testCases := []struct {
		name     string
		testFunc func() bool
	}{
		{
			name: "token0 balance is not nil after mint",
			testFunc: func() bool {
				position := mockInstance.mustGetPosition(positionId)
				return position.Token0Balance() != nil
			},
		},
		{
			name: "token1 balance is not nil after mint",
			testFunc: func() bool {
				position := mockInstance.mustGetPosition(positionId)
				return position.Token1Balance() != nil
			},
		},
	}

	for _, tc := range testCases {
		t.Run(tc.name, func(t *testing.T) {
			uassert.True(t, tc.testFunc())
		})
	}
}

func TestGetPositionExistence(t *testing.T) {
	testCases := []struct {
		name       string
		setup      func(t *testing.T)
		positionId uint64
		expected   bool
	}{
		{
			name: "non-existent position returns false",
			setup: func(t *testing.T) {
				initPositionTest(t)
			},
			positionId: 9999,
			expected:   false,
		},
		{
			name: "existing position returns true",
			setup: func(t *testing.T) {
				setupPositionGetter(t)
			},
			positionId: 1,
			expected:   true,
		},
	}

	for _, tc := range testCases {
		t.Run(tc.name, func(t *testing.T) {
			tc.setup(t)
			_, exists := mockInstance.GetPosition(tc.positionId)
			uassert.Equal(t, tc.expected, exists)
		})
	}
}

func TestGetterExistPosition(t *testing.T) {
	testCases := []struct {
		name       string
		setup      func(t *testing.T)
		positionId uint64
		expected   bool
	}{
		{
			name: "returns false for non-existent position",
			setup: func(t *testing.T) {
				initPositionTest(t)
			},
			positionId: 9999,
			expected:   false,
		},
		{
			name: "returns true for existing position",
			setup: func(t *testing.T) {
				setupPositionGetter(t)
			},
			positionId: 1,
			expected:   true,
		},
	}

	for _, tc := range testCases {
		t.Run(tc.name, func(t *testing.T) {
			tc.setup(t)
			exists := mockInstance.ExistPosition(tc.positionId)
			uassert.Equal(t, tc.expected, exists)
		})
	}
}

func TestGetPositionDetailsGetter(t *testing.T) {
	setupPositionGetter(t)
	positionId := uint64(1)

	testCases := []struct {
		name     string
		testFunc func() any
		expected any
	}{
		{
			name: "GetPositionOwner returns correct owner",
			testFunc: func() any {
				return mockInstance.GetPositionOwner(positionId)
			},
			expected: adminAddr,
		},
		{
			name: "GetPositionPoolKey returns correct pool key",
			testFunc: func() any {
				return mockInstance.GetPositionPoolKey(positionId)
			},
			expected: "gno.land/r/onbloc/bar:gno.land/r/onbloc/foo:500",
		},
		{
			name: "GetPositionTickLower returns correct tick lower",
			testFunc: func() any {
				return mockInstance.GetPositionTickLower(positionId)
			},
			expected: int32(-10000),
		},
		{
			name: "GetPositionTickUpper returns correct tick upper",
			testFunc: func() any {
				return mockInstance.GetPositionTickUpper(positionId)
			},
			expected: int32(10000),
		},
		{
			name: "GetPositionLiquidity returns non-zero liquidity",
			testFunc: func() any {
				return mockInstance.GetPositionLiquidity(positionId).ToString()
			},
			expected: "2541592",
		},
		{
			name: "GetPositionFeeGrowthInside0LastX128 returns zero initially",
			testFunc: func() any {
				return mockInstance.GetPositionFeeGrowthInside0LastX128(positionId).ToString()
			},
			expected: "0",
		},
		{
			name: "GetPositionFeeGrowthInside1LastX128 returns zero initially",
			testFunc: func() any {
				return mockInstance.GetPositionFeeGrowthInside1LastX128(positionId).ToString()
			},
			expected: "0",
		},
		{
			name: "GetPositionTokensOwed0 returns zero initially",
			testFunc: func() any {
				return mockInstance.GetPositionTokensOwed0(positionId).ToString()
			},
			expected: "0",
		},
		{
			name: "GetPositionTokensOwed1 returns zero initially",
			testFunc: func() any {
				return mockInstance.GetPositionTokensOwed1(positionId).ToString()
			},
			expected: "0",
		},
	}

	for _, tc := range testCases {
		t.Run(tc.name, func(t *testing.T) {
			result := tc.testFunc()
			uassert.Equal(t, tc.expected, result)
		})
	}
}

func TestIsBurned(t *testing.T) {
	testCases := []struct {
		name       string
		setup      func(t *testing.T)
		positionId uint64
		expected   bool
	}{
		{
			name: "newly minted position is not burned",
			setup: func(t *testing.T) {
				setupPositionGetter(t)
			},
			positionId: 1,
			expected:   false,
		},
	}

	for _, tc := range testCases {
		t.Run(tc.name, func(t *testing.T) {
			tc.setup(t)
			result := mockInstance.IsBurned(tc.positionId)
			uassert.Equal(t, tc.expected, result)
		})
	}
}

func TestIsInRange(t *testing.T) {
	testCases := []struct {
		name       string
		setup      func(t *testing.T)
		positionId uint64
		expected   bool
	}{
		{
			name: "position with tick range including current tick is in range",
			setup: func(t *testing.T) {
				setupPositionGetter(t)
			},
			positionId: 1,
			expected:   true,
		},
	}

	for _, tc := range testCases {
		t.Run(tc.name, func(t *testing.T) {
			tc.setup(t)
			result := mockInstance.IsInRange(tc.positionId)
			uassert.Equal(t, tc.expected, result)
		})
	}
}

func TestGetPositionOperator(t *testing.T) {
	testCases := []struct {
		name       string
		setup      func(t *testing.T)
		positionId uint64
		expected   address
	}{
		{
			name: "returns correct operator for position",
			setup: func(t *testing.T) {
				setupPositionGetter(t)
			},
			positionId: 1,
			expected:   address(""),
		},
	}

	for _, tc := range testCases {
		t.Run(tc.name, func(t *testing.T) {
			tc.setup(t)
			result := mockInstance.GetPositionOperator(tc.positionId)
			uassert.Equal(t, tc.expected, result)
		})
	}
}

func TestGetUnclaimedFee(t *testing.T) {
	testCases := []struct {
		name          string
		setup         func(t *testing.T)
		positionId    uint64
		expectedFee0  string
		expectedFee1  string
	}{
		{
			name: "newly minted position has zero unclaimed fees",
			setup: func(t *testing.T) {
				setupPositionGetter(t)
			},
			positionId:   1,
			expectedFee0: "0",
			expectedFee1: "0",
		},
	}

	for _, tc := range testCases {
		t.Run(tc.name, func(t *testing.T) {
			tc.setup(t)
			fee0, fee1 := mockInstance.GetUnclaimedFee(tc.positionId)
			uassert.Equal(t, tc.expectedFee0, fee0.ToString())
			uassert.Equal(t, tc.expectedFee1, fee1.ToString())
		})
	}
}

func TestMustGetPositionPanic(t *testing.T) {
	testCases := []struct {
		name        string
		setup       func(t *testing.T)
		positionId  uint64
		shouldPanic bool
	}{
		{
			name: "panics for non-existent position",
			setup: func(t *testing.T) {
				initPositionTest(t)
			},
			positionId:  9999,
			shouldPanic: true,
		},
		{
			name: "does not panic for existing position",
			setup: func(t *testing.T) {
				setupPositionGetter(t)
			},
			positionId:  1,
			shouldPanic: false,
		},
	}

	for _, tc := range testCases {
		t.Run(tc.name, func(t *testing.T) {
			tc.setup(t)
			if tc.shouldPanic {
				uassert.PanicsWithMessage(t, "[GNOSWAP-POSITION-012] position does not exist || position with position ID(9999) doesn't exist", func() {
					mockInstance.mustGetPosition(tc.positionId)
				})
			} else {
				// Should not panic
				pos := mockInstance.mustGetPosition(tc.positionId)
				uassert.True(t, pos != nil)
			}
		})
	}
}

func TestGetPositionIDsOrder(t *testing.T) {
	testCases := []struct {
		name     string
		setup    func(t *testing.T)
		offset   int
		count    int
		expected []uint64
	}{
		{
			name: "returns position IDs in correct order",
			setup: func(t *testing.T) {
				setupMultiplePositions(t)
			},
			offset:   0,
			count:    10,
			expected: []uint64{1, 2, 3},
		},
		{
			name: "returns first position ID only",
			setup: func(t *testing.T) {
				setupMultiplePositions(t)
			},
			offset:   0,
			count:    1,
			expected: []uint64{1},
		},
		{
			name: "returns second and third position IDs with offset",
			setup: func(t *testing.T) {
				setupMultiplePositions(t)
			},
			offset:   1,
			count:    2,
			expected: []uint64{2, 3},
		},
	}

	for _, tc := range testCases {
		t.Run(tc.name, func(t *testing.T) {
			tc.setup(t)
			ids := mockInstance.GetPositionIDs(tc.offset, tc.count)
			uassert.Equal(t, len(tc.expected), len(ids))
			for i, expectedId := range tc.expected {
				uassert.Equal(t, expectedId, ids[i])
			}
		})
	}
}

func TestGetPositionWithMultiplePositions(t *testing.T) {
	setupMultiplePositions(t)

	testCases := []struct {
		name              string
		positionId        uint64
		expectedTickLower int32
		expectedTickUpper int32
		expectedExists    bool
	}{
		{
			name:              "first position has correct tick range",
			positionId:        1,
			expectedTickLower: -10000,
			expectedTickUpper: 10000,
			expectedExists:    true,
		},
		{
			name:              "second position has correct tick range",
			positionId:        2,
			expectedTickLower: -5000,
			expectedTickUpper: 5000,
			expectedExists:    true,
		},
		{
			name:              "third position has correct tick range",
			positionId:        3,
			expectedTickLower: -2000,
			expectedTickUpper: 2000,
			expectedExists:    true,
		},
		{
			name:              "non-existent position returns false",
			positionId:        999,
			expectedTickLower: 0,
			expectedTickUpper: 0,
			expectedExists:    false,
		},
	}

	for _, tc := range testCases {
		t.Run(tc.name, func(t *testing.T) {
			pos, exists := mockInstance.GetPosition(tc.positionId)
			uassert.Equal(t, tc.expectedExists, exists)
			if exists {
				uassert.Equal(t, tc.expectedTickLower, pos.TickLower())
				uassert.Equal(t, tc.expectedTickUpper, pos.TickUpper())
			}
		})
	}
}
