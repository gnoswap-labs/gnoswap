package pool

import (
	"testing"

	uassert "gno.land/p/nt/uassert/v0"
	pl "gno.land/r/gnoswap/pool"

	u256 "gno.land/p/gnoswap/uint256"
)

// create mock data for getters
func testInitData(cur realm, t *testing.T) {
	t.Helper()
	resetObject(cur, t)

	params := createMockPoolParams{
		token0Path: "token0",
		token1Path: "token1",
		balances: mockBalances{
			token0: 1000,
			token1: 2000,
		},
		fee:         3000,
		tickSpacing: 10,
		slot0: mockSlot0{
			sqrtPriceX96: u256.NewUint(1000000000000000000),
			tick:         5,
			feeProtocol:  6,
			unlocked:     false,
		},
		feeGrowthGlobal0X128: u256.NewUint(1000000000000000000),
		feeGrowthGlobal1X128: u256.NewUint(2000000000000000000),
		protocolFees: mockBalances{
			token0: 1000,
			token1: 2000,
		},
		liquidity: u256.NewUint(1000000),
	}
	mockPool := makeMockPool(params)

	mockTicks := pl.NewPoolTicksTree()

	tickInfo := pl.NewTickInfo()
	tickInfo.SetLiquidityGross("1000000")
	tickInfo.SetLiquidityNet("2000000")
	tickInfo.SetFeeGrowthOutside0X128("3000000")
	tickInfo.SetFeeGrowthOutside1X128("4000000")
	tickInfo.SetTickCumulativeOutside(5)
	tickInfo.SetSecondsPerLiquidityOutsideX128("6000000")
	tickInfo.SetSecondsOutside(7)
	tickInfo.SetInitialized(true)

	mockTicks.Set(pl.EncodeTickKey(0), tickInfo)
	mockPool.SetTicks(mockTicks)

	mockPositions := pl.NewPoolPositionsTree()

	positionInfo := pl.NewPositionInfo()
	positionInfo.SetLiquidity("1000000")
	positionInfo.SetFeeGrowthInside0LastX128("2000000")
	positionInfo.SetFeeGrowthInside1LastX128("3000000")
	positionInfo.SetTokensOwed0(4000000)
	positionInfo.SetTokensOwed1(5000000)

	mockPositions.Set("test_position", positionInfo)
	mockPool.SetPositions(mockPositions)

	pools := getMockInstance().store.GetPools()
	pools.Set("token0:token1:3000", mockPool)
	err := getMockInstance().store.SetPools(0, cur, pools)
	if err != nil {
		panic(err)
	}
}

func TestGetters(cur realm, t *testing.T) {
	testInitData(cur, t)

	t.Run("valid pool path", func(cur realm, t *testing.T) {
		validPoolPath := "token0:token1:3000"

		t.Run("get token0 path", func(cur realm, t *testing.T) {
			token0Path, err := getMockInstance().GetToken0Path(validPoolPath)
			uassert.True(t, err == nil)
			if token0Path != "token0" {
				t.Errorf("Expected token0 path [%s], got %s", "token0", token0Path)
			}
		})

		t.Run("get token1 path", func(cur realm, t *testing.T) {
			token1Path, err := getMockInstance().GetToken1Path(validPoolPath)
			uassert.True(t, err == nil)
			if token1Path != "token1" {
				t.Errorf("Expected token1 path [%s], got %s", "token1", token1Path)
			}
		})

		t.Run("get fee", func(cur realm, t *testing.T) {
			fee, err := getMockInstance().GetFee(validPoolPath)
			uassert.True(t, err == nil)
			if fee != 3000 {
				t.Errorf("Expected fee [%d], got %d", 3000, fee)
			}
		})

		t.Run("get balance token0", func(cur realm, t *testing.T) {
			balanceToken0, err := getMockInstance().GetBalanceToken0(validPoolPath)
			uassert.True(t, err == nil)
			if balanceToken0 != 1000 {
				t.Errorf("Expected balance token0 [%d], got %d", 1000, balanceToken0)
			}
		})

		t.Run("get balance token1", func(cur realm, t *testing.T) {
			balanceToken1, err := getMockInstance().GetBalanceToken1(validPoolPath)
			uassert.True(t, err == nil)
			if balanceToken1 != 2000 {
				t.Errorf("Expected balance token1 [%d], got %d", 2000, balanceToken1)
			}
		})

		t.Run("get tick spacing", func(cur realm, t *testing.T) {
			tickSpacing, err := getMockInstance().GetTickSpacing(validPoolPath)
			uassert.True(t, err == nil)
			if tickSpacing != 10 {
				t.Errorf("Expected tick spacing [%d], got %d", 10, tickSpacing)
			}
		})

		t.Run("get max liquidity per tick", func(cur realm, t *testing.T) {
			maxLiquidityPerTick, err := getMockInstance().GetMaxLiquidityPerTick(validPoolPath)
			uassert.True(t, err == nil)
			if maxLiquidityPerTick != "1917569901783203986719870431555990" {
				t.Errorf("Expected max liquidity per tick [%s], got %s", "1917569901783203986719870431555990", maxLiquidityPerTick)
			}
		})

		t.Run("get slot0 sqrt price x96", func(cur realm, t *testing.T) {
			sqrtPriceX96, err := getMockInstance().GetSlot0SqrtPriceX96(validPoolPath)
			uassert.True(t, err == nil)
			if sqrtPriceX96.ToString() != "1000000000000000000" {
				t.Errorf("Expected sqrt price x96 [%s], got %s", "1000000000000000000", sqrtPriceX96.ToString())
			}
		})

		t.Run("get slot0 tick", func(cur realm, t *testing.T) {
			tick, err := getMockInstance().GetSlot0Tick(validPoolPath)
			uassert.True(t, err == nil)
			if tick != 5 {
				t.Errorf("Expected tick [%d], got %d", 5, tick)
			}
		})

		t.Run("get slot0 fee protocol", func(cur realm, t *testing.T) {
			feeProtocol, err := getMockInstance().GetSlot0FeeProtocol(validPoolPath)
			uassert.True(t, err == nil)
			if feeProtocol != 6 {
				t.Errorf("Expected fee protocol [%d], got %d", 6, feeProtocol)
			}
		})

		t.Run("get slot0 unlocked", func(cur realm, t *testing.T) {
			unlocked, err := getMockInstance().GetSlot0Unlocked(validPoolPath)
			uassert.True(t, err == nil)
			if unlocked != false {
				t.Errorf("Expected unlocked [%t], got %t", false, unlocked)
			}
		})

		t.Run("get fee growth global0x128", func(cur realm, t *testing.T) {
			feeGrowthGlobal0X128, err := getMockInstance().GetFeeGrowthGlobal0X128(validPoolPath)
			uassert.True(t, err == nil)
			if feeGrowthGlobal0X128.ToString() != "1000000000000000000" {
				t.Errorf("Expected fee growth global 0 x128 [%s], got %s", "1000000000000000000", feeGrowthGlobal0X128.ToString())
			}
		})

		t.Run("get fee growth global1x128", func(cur realm, t *testing.T) {
			feeGrowthGlobal1X128, err := getMockInstance().GetFeeGrowthGlobal1X128(validPoolPath)
			uassert.True(t, err == nil)
			if feeGrowthGlobal1X128.ToString() != "2000000000000000000" {
				t.Errorf("Expected fee growth global 1 x128 [%s], got %s", "2000000000000000000", feeGrowthGlobal1X128.ToString())
			}
		})

		t.Run("get protocol fees token0", func(cur realm, t *testing.T) {
			protocolFeesToken0, err := getMockInstance().GetProtocolFeesToken0(validPoolPath)
			uassert.True(t, err == nil)
			if protocolFeesToken0 != 1000 {
				t.Errorf("Expected protocol fees token0 [%d], got %d", 1000, protocolFeesToken0)
			}
		})

		t.Run("get protocol fees token1", func(cur realm, t *testing.T) {
			protocolFeesToken1, err := getMockInstance().GetProtocolFeesToken1(validPoolPath)
			uassert.True(t, err == nil)
			if protocolFeesToken1 != 2000 {
				t.Errorf("Expected protocol fees token1 [%d], got %d", 2000, protocolFeesToken1)
			}
		})

		t.Run("get liquidity", func(cur realm, t *testing.T) {
			liquidity, err := getMockInstance().GetLiquidity(validPoolPath)
			uassert.True(t, err == nil)
			if liquidity.ToString() != "1000000" {
				t.Errorf("Expected liquidity [%s], got %s", "1000000", liquidity.ToString())
			}
		})
	})

	t.Run("invalid pool path returns error", func(cur realm, t *testing.T) {
		invalidPoolPath := "invalid/pool/path"

		t.Run("get token0 path", func(cur realm, t *testing.T) { _, err := getMockInstance().GetToken0Path(invalidPoolPath); uassert.True(t, err != nil) })

		t.Run("get token1 path", func(cur realm, t *testing.T) { _, err := getMockInstance().GetToken1Path(invalidPoolPath); uassert.True(t, err != nil) })

		t.Run("get fee", func(cur realm, t *testing.T) { _, err := getMockInstance().GetFee(invalidPoolPath); uassert.True(t, err != nil) })

		t.Run("get balance token0", func(cur realm, t *testing.T) { _, err := getMockInstance().GetBalanceToken0(invalidPoolPath); uassert.True(t, err != nil) })

		t.Run("get balance token1", func(cur realm, t *testing.T) { _, err := getMockInstance().GetBalanceToken1(invalidPoolPath); uassert.True(t, err != nil) })

		t.Run("get tick spacing", func(cur realm, t *testing.T) { _, err := getMockInstance().GetTickSpacing(invalidPoolPath); uassert.True(t, err != nil) })

		t.Run("get liquidity", func(cur realm, t *testing.T) { _, err := getMockInstance().GetLiquidity(invalidPoolPath); uassert.True(t, err != nil) })

		t.Run("get max liquidity per tick", func(cur realm, t *testing.T) { _, err := getMockInstance().GetMaxLiquidityPerTick(invalidPoolPath); uassert.True(t, err != nil) })

		t.Run("get slot0 sqrt price x96", func(cur realm, t *testing.T) { _, err := getMockInstance().GetSlot0SqrtPriceX96(invalidPoolPath); uassert.True(t, err != nil) })

		t.Run("get slot0 tick", func(cur realm, t *testing.T) { _, err := getMockInstance().GetSlot0Tick(invalidPoolPath); uassert.True(t, err != nil) })

		t.Run("get slot0 fee protocol", func(cur realm, t *testing.T) { _, err := getMockInstance().GetSlot0FeeProtocol(invalidPoolPath); uassert.True(t, err != nil) })

		t.Run("get slot0 unlocked", func(cur realm, t *testing.T) { _, err := getMockInstance().GetSlot0Unlocked(invalidPoolPath); uassert.True(t, err != nil) })

		t.Run("get fee growth global0x128", func(cur realm, t *testing.T) { _, err := getMockInstance().GetFeeGrowthGlobal0X128(invalidPoolPath); uassert.True(t, err != nil) })

		t.Run("get fee growth global1x128", func(cur realm, t *testing.T) { _, err := getMockInstance().GetFeeGrowthGlobal1X128(invalidPoolPath); uassert.True(t, err != nil) })

		t.Run("get protocol fees token0", func(cur realm, t *testing.T) { _, err := getMockInstance().GetProtocolFeesToken0(invalidPoolPath); uassert.True(t, err != nil) })

		t.Run("get protocol fees token1", func(cur realm, t *testing.T) { _, err := getMockInstance().GetProtocolFeesToken1(invalidPoolPath); uassert.True(t, err != nil) })

		t.Run("get liquidity", func(cur realm, t *testing.T) { _, err := getMockInstance().GetLiquidity(invalidPoolPath); uassert.True(t, err != nil) })
	})
}

func TestPositionGetters(cur realm, t *testing.T) {
	tests := []struct {
		name                             string
		poolPath                         string
		positionKey                      string
		expectedLiquidity                string
		expectedFeeGrowthInside0LastX128 string
		expectedFeeGrowthInside1LastX128 string
		expectedTokensOwed0              int64
		expectedTokensOwed1              int64
		expectedHasPanic                 bool
		expectedPanicMessage             string
	}{
		{
			name:                             "position getters is success by valid position",
			poolPath:                         "token0:token1:3000",
			positionKey:                      "test_position",
			expectedLiquidity:                "1000000",
			expectedFeeGrowthInside0LastX128: "2000000",
			expectedFeeGrowthInside1LastX128: "3000000",
			expectedTokensOwed0:              4000000,
			expectedTokensOwed1:              5000000,
			expectedHasPanic:                 false,
		},
		{
			name:                             "position getters is failed by invalid position",
			poolPath:                         "token0:token1:3000",
			positionKey:                      "invalid_position",
			expectedLiquidity:                "0",
			expectedFeeGrowthInside0LastX128: "0",
			expectedFeeGrowthInside1LastX128: "0",
			expectedTokensOwed0:              0,
			expectedTokensOwed1:              0,
			expectedHasPanic:                 true,
			expectedPanicMessage:             "[GNOSWAP-POOL-005] requested data not found",
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(cur realm, t *testing.T) {
			testInitData(cur, t)

			var liquidity string
			var feeGrowthInside0LastX128 string
			var feeGrowthInside1LastX128 string
			var tokensOwed0 int64
			var tokensOwed1 int64

			liquidity, err := getMockInstance().GetPositionLiquidity(tt.poolPath, tt.positionKey)
			if tt.expectedHasPanic {
				uassert.True(t, err != nil)
				_, err = getMockInstance().GetPositionFeeGrowthInside0LastX128(tt.poolPath, tt.positionKey)
				uassert.True(t, err != nil)
				_, err = getMockInstance().GetPositionFeeGrowthInside1LastX128(tt.poolPath, tt.positionKey)
				uassert.True(t, err != nil)
				_, err = getMockInstance().GetPositionTokensOwed0(tt.poolPath, tt.positionKey)
				uassert.True(t, err != nil)
				_, err = getMockInstance().GetPositionTokensOwed1(tt.poolPath, tt.positionKey)
				uassert.True(t, err != nil)
				return
			}
			uassert.True(t, err == nil)
			feeGrowthInside0LastX128, err = getMockInstance().GetPositionFeeGrowthInside0LastX128(tt.poolPath, tt.positionKey)
			uassert.True(t, err == nil)
			feeGrowthInside1LastX128, err = getMockInstance().GetPositionFeeGrowthInside1LastX128(tt.poolPath, tt.positionKey)
			uassert.True(t, err == nil)
			tokensOwed0, err = getMockInstance().GetPositionTokensOwed0(tt.poolPath, tt.positionKey)
			uassert.True(t, err == nil)
			tokensOwed1, err = getMockInstance().GetPositionTokensOwed1(tt.poolPath, tt.positionKey)
			uassert.True(t, err == nil)

			uassert.Equal(t, tt.expectedLiquidity, liquidity)
			uassert.Equal(t, tt.expectedFeeGrowthInside0LastX128, feeGrowthInside0LastX128)
			uassert.Equal(t, tt.expectedFeeGrowthInside1LastX128, feeGrowthInside1LastX128)
			uassert.Equal(t, tt.expectedTokensOwed0, tokensOwed0)
			uassert.Equal(t, tt.expectedTokensOwed1, tokensOwed1)
		})
	}

	t.Run("invalid position", func(cur realm, t *testing.T) {
		validPoolPath := "token0:token1:3000"        // pool must valid
		invalidPositionKey := "invalid/position/key" // but position must not

		t.Run("get position liquidity", func(cur realm, t *testing.T) {
			_, err := getMockInstance().GetPositionLiquidity(validPoolPath, invalidPositionKey)
			uassert.True(t, err != nil)
		})

		t.Run("get position fee growth inside0 last x128", func(cur realm, t *testing.T) {
			_, err := getMockInstance().GetPositionFeeGrowthInside0LastX128(validPoolPath, invalidPositionKey)
			uassert.True(t, err != nil)
		})

		t.Run("get position fee growth inside1 last x128", func(cur realm, t *testing.T) {
			_, err := getMockInstance().GetPositionFeeGrowthInside1LastX128(validPoolPath, invalidPositionKey)
			uassert.True(t, err != nil)
		})

		t.Run("get position tokens owed0", func(cur realm, t *testing.T) {
			_, err := getMockInstance().GetPositionTokensOwed0(validPoolPath, invalidPositionKey)
			uassert.True(t, err != nil)
		})

		t.Run("get position tokens owed1", func(cur realm, t *testing.T) {
			_, err := getMockInstance().GetPositionTokensOwed1(validPoolPath, invalidPositionKey)
			uassert.True(t, err != nil)
		})
	})
}

func TestTickGetters(cur realm, t *testing.T) {
	testInitData(cur, t)
	t.Run("valid tick", func(cur realm, t *testing.T) {
		validPoolPath := "token0:token1:3000"
		validTick := int32(0)

		t.Run("get tick liquidity gross", func(cur realm, t *testing.T) {
			liquidityGross, err := getMockInstance().GetTickLiquidityGross(validPoolPath, validTick)
			uassert.True(t, err == nil)
			if liquidityGross != "1000000" {
				t.Errorf("Expected liquidity gross [%s], got %s", "1000000", liquidityGross)
			}
		})

		t.Run("get tick liquidity net", func(cur realm, t *testing.T) {
			liquidityNet, err := getMockInstance().GetTickLiquidityNet(validPoolPath, validTick)
			uassert.True(t, err == nil)
			if liquidityNet != "2000000" {
				t.Errorf("Expected liquidity net [%s], got %s", "2000000", liquidityNet)
			}
		})

		t.Run("get tick fee growth outside0 x128", func(cur realm, t *testing.T) {
			feeGrowthOutside0X128, err := getMockInstance().GetTickFeeGrowthOutside0X128(validPoolPath, validTick)
			uassert.True(t, err == nil)
			if feeGrowthOutside0X128 != "3000000" {
				t.Errorf("Expected fee growth outside0 x128 [%s], got %s", "3000000", feeGrowthOutside0X128)
			}
		})

		t.Run("get tick fee growth outside1 x128", func(cur realm, t *testing.T) {
			feeGrowthOutside1X128, err := getMockInstance().GetTickFeeGrowthOutside1X128(validPoolPath, validTick)
			uassert.True(t, err == nil)
			if feeGrowthOutside1X128 != "4000000" {
				t.Errorf("Expected fee growth outside1 x128 [%s], got %s", "4000000", feeGrowthOutside1X128)
			}
		})

		t.Run("get tick cumulative outside", func(cur realm, t *testing.T) {
			tickCumulativeOutside, err := getMockInstance().GetTickCumulativeOutside(validPoolPath, validTick)
			uassert.True(t, err == nil)
			if tickCumulativeOutside != 5 {
				t.Errorf("Expected tick cumulative outside [%d], got %d", 5, tickCumulativeOutside)
			}
		})

		t.Run("get tick seconds per liquidity outside x128", func(cur realm, t *testing.T) {
			secondsPerLiquidityOutsideX128, err := getMockInstance().GetTickSecondsPerLiquidityOutsideX128(validPoolPath, validTick)
			uassert.True(t, err == nil)
			if secondsPerLiquidityOutsideX128 != "6000000" {
				t.Errorf("Expected seconds per liquidity outside x128 [%s], got %s", "6000000", secondsPerLiquidityOutsideX128)
			}
		})

		t.Run("get tick seconds outside", func(cur realm, t *testing.T) {
			secondsOutside, err := getMockInstance().GetTickSecondsOutside(validPoolPath, validTick)
			uassert.True(t, err == nil)
			if secondsOutside != 7 {
				t.Errorf("Expected seconds outside [%d], got %d", 7, secondsOutside)
			}
		})

		t.Run("get tick initialized", func(cur realm, t *testing.T) {
			initialized, err := getMockInstance().GetTickInitialized(validPoolPath, validTick)
			uassert.True(t, err == nil)
			if initialized != true {
				t.Errorf("Expected initialized [%t], got %t", true, initialized)
			}
		})
	})

	t.Run("uninitialized tick", func(cur realm, t *testing.T) {
		validPoolPath := "token0:token1:3000"
		uninitializedTick := int32(-1)

		liquidityGross, err := getMockInstance().GetTickLiquidityGross(validPoolPath, uninitializedTick)
		uassert.True(t, err == nil)
		uassert.Equal(t, "0", liquidityGross)

		liquidityNet, err := getMockInstance().GetTickLiquidityNet(validPoolPath, uninitializedTick)
		uassert.True(t, err == nil)
		uassert.Equal(t, "0", liquidityNet)

		feeGrowthOutside0X128, err := getMockInstance().GetTickFeeGrowthOutside0X128(validPoolPath, uninitializedTick)
		uassert.True(t, err == nil)
		uassert.Equal(t, "0", feeGrowthOutside0X128)

		feeGrowthOutside1X128, err := getMockInstance().GetTickFeeGrowthOutside1X128(validPoolPath, uninitializedTick)
		uassert.True(t, err == nil)
		uassert.Equal(t, "0", feeGrowthOutside1X128)

		tickCumulativeOutside, err := getMockInstance().GetTickCumulativeOutside(validPoolPath, uninitializedTick)
		uassert.True(t, err == nil)
		uassert.Equal(t, int64(0), tickCumulativeOutside)

		secondsPerLiquidityOutsideX128, err := getMockInstance().GetTickSecondsPerLiquidityOutsideX128(validPoolPath, uninitializedTick)
		uassert.True(t, err == nil)
		uassert.Equal(t, "0", secondsPerLiquidityOutsideX128)

		secondsOutside, err := getMockInstance().GetTickSecondsOutside(validPoolPath, uninitializedTick)
		uassert.True(t, err == nil)
		uassert.Equal(t, uint32(0), secondsOutside)

		initialized, err := getMockInstance().GetTickInitialized(validPoolPath, uninitializedTick)
		uassert.True(t, err == nil)
		uassert.False(t, initialized)
	})
}

func TestGetPoolCount(cur realm, t *testing.T) {
	testCases := []struct {
		name     string
		setup    func(cur realm, t *testing.T)
		expected int
	}{
		{
			name: "empty store returns zero",
			setup: func(cur realm, t *testing.T) {
				resetObject(cur, t)
			},
			expected: 0,
		},
		{
			name: "returns correct count after adding pool",
			setup: func(cur realm, t *testing.T) {
				testInitData(cur, t)
			},
			expected: 1,
		},
	}

	for _, tc := range testCases {
		t.Run(tc.name, func(cur realm, t *testing.T) {
			tc.setup(cur, t)
			count := getMockInstance().GetPoolCount()
			uassert.Equal(t, tc.expected, count)
		})
	}
}

func TestGetPoolPaths(cur realm, t *testing.T) {
	testCases := []struct {
		name           string
		setup          func(cur realm, t *testing.T)
		offset         int
		count          int
		expectedLength int
	}{
		{
			name: "empty store returns empty slice",
			setup: func(cur realm, t *testing.T) {
				resetObject(cur, t)
			},
			offset:         0,
			count:          10,
			expectedLength: 0,
		},
		{
			name: "returns pool paths",
			setup: func(cur realm, t *testing.T) {
				testInitData(cur, t)
			},
			offset:         0,
			count:          10,
			expectedLength: 1,
		},
		{
			name: "offset beyond range returns empty",
			setup: func(cur realm, t *testing.T) {
				testInitData(cur, t)
			},
			offset:         100,
			count:          10,
			expectedLength: 0,
		},
	}

	for _, tc := range testCases {
		t.Run(tc.name, func(cur realm, t *testing.T) {
			tc.setup(cur, t)
			paths := getMockInstance().GetPoolPaths(tc.offset, tc.count)
			uassert.Equal(t, tc.expectedLength, len(paths))
		})
	}
}

func TestExistsPoolPath(cur realm, t *testing.T) {
	testCases := []struct {
		name     string
		setup    func(cur realm, t *testing.T)
		poolPath string
		expected bool
	}{
		{
			name: "existing pool returns true",
			setup: func(cur realm, t *testing.T) {
				testInitData(cur, t)
			},
			poolPath: "token0:token1:3000",
			expected: true,
		},
		{
			name: "non-existent pool returns false",
			setup: func(cur realm, t *testing.T) {
				testInitData(cur, t)
			},
			poolPath: "nonexistent:pool:path",
			expected: false,
		},
	}

	for _, tc := range testCases {
		t.Run(tc.name, func(cur realm, t *testing.T) {
			tc.setup(cur, t)
			exists := getMockInstance().ExistsPoolPath(tc.poolPath)
			uassert.Equal(t, tc.expected, exists)
		})
	}
}

func TestGetFeeAmountTickSpacings(cur realm, t *testing.T) {
	testInitData(cur, t)

	t.Run("returns all fee tier mappings", func(cur realm, t *testing.T) {
		mappings := getMockInstance().GetFeeAmountTickSpacings()
		uassert.True(t, len(mappings) > 0)
	})
}

func TestGetFeeAmountTickSpacing(cur realm, t *testing.T) {
	testCases := []struct {
		name        string
		setup       func(cur realm, t *testing.T)
		fee         uint32
		expected    int32
		shouldPanic bool
	}{
		{
			name: "valid fee tier 500 returns tick spacing 10",
			setup: func(cur realm, t *testing.T) {
				testInitData(cur, t)
			},
			fee:         500,
			expected:    10,
			shouldPanic: false,
		},
		{
			name: "valid fee tier 3000 returns tick spacing 60",
			setup: func(cur realm, t *testing.T) {
				testInitData(cur, t)
			},
			fee:         3000,
			expected:    60,
			shouldPanic: false,
		},
		{
			name: "invalid fee tier panics",
			setup: func(cur realm, t *testing.T) {
				testInitData(cur, t)
			},
			fee:         9999,
			expected:    0,
			shouldPanic: true,
		},
	}

	for _, tc := range testCases {
		t.Run(tc.name, func(cur realm, t *testing.T) {
			tc.setup(cur, t)
			if tc.shouldPanic {
				_, err := getMockInstance().GetFeeAmountTickSpacing(tc.fee)
				uassert.True(t, err != nil)
			} else {
				spacing, err := getMockInstance().GetFeeAmountTickSpacing(tc.fee)
				uassert.True(t, err == nil)
				uassert.Equal(t, tc.expected, spacing)
			}
		})
	}
}

func TestGetPoolPositionCount(cur realm, t *testing.T) {
	testCases := []struct {
		name     string
		setup    func(cur realm, t *testing.T)
		poolPath string
		expected int
	}{
		{
			name: "valid pool with positions",
			setup: func(cur realm, t *testing.T) {
				testInitData(cur, t)
			},
			poolPath: "token0:token1:3000",
			expected: 1,
		},
		{
			name: "non-existent pool returns zero",
			setup: func(cur realm, t *testing.T) {
				testInitData(cur, t)
			},
			poolPath: "nonexistent:pool:path",
			expected: 0,
		},
	}

	for _, tc := range testCases {
		t.Run(tc.name, func(cur realm, t *testing.T) {
			tc.setup(cur, t)
			count, err := getMockInstance().GetPoolPositionCount(tc.poolPath)
			if tc.expected == 0 && tc.poolPath == "nonexistent:pool:path" {
				uassert.True(t, err != nil)
			} else {
				uassert.True(t, err == nil)
				uassert.Equal(t, tc.expected, count)
			}
		})
	}
}

func TestGetPoolPositionKeys(cur realm, t *testing.T) {
	testCases := []struct {
		name           string
		setup          func(cur realm, t *testing.T)
		poolPath       string
		offset         int
		count          int
		expectedLength int
	}{
		{
			name: "valid pool returns position keys",
			setup: func(cur realm, t *testing.T) {
				testInitData(cur, t)
			},
			poolPath:       "token0:token1:3000",
			offset:         0,
			count:          10,
			expectedLength: 1,
		},
		{
			name: "non-existent pool returns empty",
			setup: func(cur realm, t *testing.T) {
				testInitData(cur, t)
			},
			poolPath:       "nonexistent:pool:path",
			offset:         0,
			count:          10,
			expectedLength: 0,
		},
	}

	for _, tc := range testCases {
		t.Run(tc.name, func(cur realm, t *testing.T) {
			tc.setup(cur, t)
			keys, err := getMockInstance().GetPoolPositionKeys(tc.poolPath, tc.offset, tc.count)
			if tc.expectedLength == 0 && tc.poolPath == "nonexistent:pool:path" {
				uassert.True(t, err != nil)
			} else {
				uassert.True(t, err == nil)
				uassert.Equal(t, tc.expectedLength, len(keys))
			}
		})
	}
}

func TestGetInitializedTicksInRange(cur realm, t *testing.T) {
	testCases := []struct {
		name           string
		setup          func(cur realm, t *testing.T)
		poolPath       string
		tickLower      int32
		tickUpper      int32
		expectedLength int
	}{
		{
			name: "valid range with initialized tick",
			setup: func(cur realm, t *testing.T) {
				testInitData(cur, t)
			},
			poolPath:       "token0:token1:3000",
			tickLower:      -10,
			tickUpper:      10,
			expectedLength: 1,
		},
		{
			name: "range without initialized ticks",
			setup: func(cur realm, t *testing.T) {
				testInitData(cur, t)
			},
			poolPath:       "token0:token1:3000",
			tickLower:      100,
			tickUpper:      200,
			expectedLength: 0,
		},
		{
			name: "non-existent pool returns empty",
			setup: func(cur realm, t *testing.T) {
				testInitData(cur, t)
			},
			poolPath:       "nonexistent:pool:path",
			tickLower:      -10,
			tickUpper:      10,
			expectedLength: 0,
		},
	}

	for _, tc := range testCases {
		t.Run(tc.name, func(cur realm, t *testing.T) {
			tc.setup(cur, t)
			ticks, err := getMockInstance().GetInitializedTicksInRange(tc.poolPath, tc.tickLower, tc.tickUpper)
			if tc.expectedLength == 0 && tc.poolPath == "nonexistent:pool:path" {
				uassert.True(t, err != nil)
			} else {
				uassert.True(t, err == nil)
				uassert.Equal(t, tc.expectedLength, len(ticks))
			}
		})
	}
}

func TestGetPoolWithError(cur realm, t *testing.T) {
	testCases := []struct {
		name        string
		setup       func(cur realm, t *testing.T)
		token0Path  string
		token1Path  string
		fee         uint32
		expectError bool
	}{
		{
			name: "valid pool returns no error",
			setup: func(cur realm, t *testing.T) {
				testInitData(cur, t)
			},
			token0Path:  "token0",
			token1Path:  "token1",
			fee:         3000,
			expectError: false,
		},
		{
			name: "non-existent pool returns error",
			setup: func(cur realm, t *testing.T) {
				testInitData(cur, t)
			},
			token0Path:  "nonexistent",
			token1Path:  "pool",
			fee:         3000,
			expectError: true,
		},
	}

	for _, tc := range testCases {
		t.Run(tc.name, func(cur realm, t *testing.T) {
			tc.setup(cur, t)
			pool, err := getMockInstance().GetPool(tc.token0Path, tc.token1Path, tc.fee)
			if tc.expectError {
				uassert.True(t, err != nil)
			} else {
				uassert.True(t, err == nil)
				uassert.True(t, pool != nil)
			}
		})
	}
}

func TestGetTickInfoWithError(cur realm, t *testing.T) {
	testCases := []struct {
		name        string
		setup       func(cur realm, t *testing.T)
		poolPath    string
		tick        int32
		expectError bool
	}{
		{
			name: "valid tick returns no error",
			setup: func(cur realm, t *testing.T) {
				testInitData(cur, t)
			},
			poolPath:    "token0:token1:3000",
			tick:        0,
			expectError: false,
		},
		{
			name: "non-existent tick returns error",
			setup: func(cur realm, t *testing.T) {
				testInitData(cur, t)
			},
			poolPath:    "token0:token1:3000",
			tick:        999,
			expectError: true,
		},
		{
			name: "non-existent pool returns error",
			setup: func(cur realm, t *testing.T) {
				testInitData(cur, t)
			},
			poolPath:    "nonexistent:pool:path",
			tick:        0,
			expectError: true,
		},
	}

	for _, tc := range testCases {
		t.Run(tc.name, func(cur realm, t *testing.T) {
			tc.setup(cur, t)
			tickInfo, err := getMockInstance().GetTickInfo(tc.poolPath, tc.tick)
			if tc.expectError {
				uassert.True(t, err != nil)
			} else {
				uassert.True(t, err == nil)
				uassert.Equal(t, "1000000", tickInfo.LiquidityGross())
			}
		})
	}
}

func TestGetPositionWithError(cur realm, t *testing.T) {
	testCases := []struct {
		name        string
		setup       func(cur realm, t *testing.T)
		poolPath    string
		key         string
		expectError bool
	}{
		{
			name: "valid position returns no error",
			setup: func(cur realm, t *testing.T) {
				testInitData(cur, t)
			},
			poolPath:    "token0:token1:3000",
			key:         "test_position",
			expectError: false,
		},
		{
			name: "non-existent position returns error",
			setup: func(cur realm, t *testing.T) {
				testInitData(cur, t)
			},
			poolPath:    "token0:token1:3000",
			key:         "nonexistent_position",
			expectError: true,
		},
		{
			name: "non-existent pool returns error",
			setup: func(cur realm, t *testing.T) {
				testInitData(cur, t)
			},
			poolPath:    "nonexistent:pool:path",
			key:         "test_position",
			expectError: true,
		},
	}

	for _, tc := range testCases {
		t.Run(tc.name, func(cur realm, t *testing.T) {
			tc.setup(cur, t)
			positionInfo, err := getMockInstance().GetPosition(tc.poolPath, tc.key)
			if tc.expectError {
				uassert.True(t, err != nil)
			} else {
				uassert.True(t, err == nil)
				uassert.Equal(t, "1000000", positionInfo.Liquidity())
			}
		})
	}
}

func TestGetFeeGrowthGlobalX128(cur realm, t *testing.T) {
	testInitData(cur, t)

	t.Run("returns both fee growth values", func(cur realm, t *testing.T) {
		feeGrowth0, feeGrowth1, err := getMockInstance().GetFeeGrowthGlobalX128("token0:token1:3000")
		uassert.True(t, err == nil)
		uassert.Equal(t, "1000000000000000000", feeGrowth0.ToString())
		uassert.Equal(t, "2000000000000000000", feeGrowth1.ToString())
	})
}

func TestGetTickFeeGrowthOutsideX128(cur realm, t *testing.T) {
	testInitData(cur, t)

	t.Run("returns both fee growth outside values", func(cur realm, t *testing.T) {
		feeGrowth0, feeGrowth1, err := getMockInstance().GetTickFeeGrowthOutsideX128("token0:token1:3000", 0)
		uassert.True(t, err == nil)
		uassert.Equal(t, "3000000", feeGrowth0)
		uassert.Equal(t, "4000000", feeGrowth1)
	})
}

func TestGetPositionFeeGrowthInsideLastX128(cur realm, t *testing.T) {
	testInitData(cur, t)

	t.Run("returns both fee growth inside values", func(cur realm, t *testing.T) {
		feeGrowth0, feeGrowth1, err := getMockInstance().GetPositionFeeGrowthInsideLastX128("token0:token1:3000", "test_position")
		uassert.True(t, err == nil)
		uassert.Equal(t, "2000000", feeGrowth0)
		uassert.Equal(t, "3000000", feeGrowth1)
	})
}

func TestGetPoolCreationFee(cur realm, t *testing.T) {
	testInitData(cur, t)

	t.Run("returns pool creation fee", func(cur realm, t *testing.T) {
		fee := getMockInstance().GetPoolCreationFee()
		uassert.True(t, fee >= 0)
	})
}

func TestGetWithdrawalFee(cur realm, t *testing.T) {
	testInitData(cur, t)

	t.Run("returns withdrawal fee", func(cur realm, t *testing.T) {
		fee := getMockInstance().GetWithdrawalFee()
		uassert.True(t, fee >= 0)
	})
}
