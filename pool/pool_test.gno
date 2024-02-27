package pool

import (
	"testing"

	"gno.land/r/demo/consts"
	"gno.land/p/demo/common"
	"gno.land/p/demo/ufmt"
)

type IPool interface {
    GetSlot0() Slot0
    GetBalances() Balances
    GetFee() uint16
    GetTickSpacing() int32
    GetMaxLiquidityPerTick() bigint
    GetFeeGrowthGlobal0X128() bigint
    GetFeeGrowthGlobal1X128() bigint
    GetProtocolFees() ProtocolFees
    GetLiquidity() bigint
    GetTicks() Ticks
    GetTickBitmaps() TickBitmaps
    GetPositions() Positions
}

type MockPool struct {
	slot0                Slot0
    balances             Balances
    fee                  uint16
    tickSpacing          int32
    maxLiquidityPerTick  bigint
    feeGrowthGlobal0X128 bigint
    feeGrowthGlobal1X128 bigint
    protocolFees         ProtocolFees
    liquidity            bigint
    ticks                Ticks
    tickBitmaps          TickBitmaps
    positions            Positions
}

func (m *MockPool) GetSlot0() Slot0 {
    return m.slot0
}

func (m *MockPool) GetBalances() Balances {
    return m.balances
}

func (m *MockPool) GetFee() uint16 {
    return m.fee
}

func (m *MockPool) GetTickSpacing() int32 {
    return m.tickSpacing
}

func (m *MockPool) GetMaxLiquidityPerTick() bigint {
    return m.maxLiquidityPerTick
}

func (m *MockPool) GetFeeGrowthGlobal0X128() bigint {
    return m.feeGrowthGlobal0X128
}

func (m *MockPool) GetFeeGrowthGlobal1X128() bigint {
    return m.feeGrowthGlobal1X128
}

func (m *MockPool) GetProtocolFees() ProtocolFees {
    return m.protocolFees
}

func (m *MockPool) GetLiquidity() bigint {
    return m.liquidity
}

func (m *MockPool) GetTicks() Ticks {
    return m.ticks
}

func (m *MockPool) GetTickBitmaps() TickBitmaps {
    return m.tickBitmaps
}

func (m *MockPool) GetPositions() Positions {
    return m.positions
}

func (pool *MockPool) tickBitmapNextInitializedTickWithInOneWord(
	tick int32,
	tickSpacing int32,
	lte bool,
) (int32, bool) {
	compress := tick / tickSpacing
	if tick < 0 && tick%tickSpacing != 0 {
		compress--
	}

	if lte {
		wordPos, bitPos := tickBitmapPosition(compress)

		mask := (bigint(1) << uint64(bitPos)) - bigint(1) + (bigint(1) << uint64(bitPos))
		requireUnsigned(mask, ufmt.Sprintf("[POOL] tick_bitmap.gno__tickBitmapNextInitializedTickWithInOneWord #1 || mask(%d) >= 0", mask))

		masked := pool.tickBitmaps[wordPos] & mask
		requireUnsigned(masked, ufmt.Sprintf("[POOL] tick_bitmap.gno__tickBitmapNextInitializedTickWithInOneWord #1 || masked(%d) >= 0", masked))

		initialized := masked != 0

		if initialized {
			next := (compress - int32(bitPos-bitMathMostSignificantBit(masked))) * tickSpacing
			return next, initialized
		}

		next := (compress - int32(bitPos)) * tickSpacing
		return next, initialized
	}

	wordPos, bitPos := tickBitmapPosition(compress + 1)

	_mask := bigint(1) << uint64(bitPos)
	_mask -= bigint(1)
	mask := bigintBitwiseNotForUint256BitmapIndexing(_mask)
	requireUnsigned(mask, ufmt.Sprintf("[POOL] tick_bitmap.gno__tickBitmapNextInitializedTickWithInOneWord #2 || mask(%d) >= 0", mask))

	masked := pool.tickBitmaps[wordPos] & mask
	requireUnsigned(masked, ufmt.Sprintf("[POOL] tick_bitmap.gno__tickBitmapNextInitializedTickWithInOneWord #2 || masked(%d) >= 0", masked))

	initialized := masked != 0
	if initialized {
		next := (compress + 1 + int32(bitMathLeastSignificantBit(masked)-bitPos)) * tickSpacing
		return next, initialized
	} else {
		next := (compress + 1 + int32(int64(consts.MAX_UINT8-bigint(uint64(bitPos))))) * tickSpacing
		return next, initialized
	}
}

// it takes the MockPool as a type which cannot convert to Pool. So I have to copy the function from the original code
func mockExecuteSwapStep(
	pool *MockPool,
	state *SwapState,
	sqrtPriceLimitX96 bigint,
	zeroForOne bool,
) StepComputations {
	var step StepComputations

	step.sqrtPriceStartX96 = state.sqrtPriceX96
	step.tickNext, step.initialized = pool.tickBitmapNextInitializedTickWithInOneWord(
		state.tick,
		pool.tickSpacing,
		zeroForOne,
	)

	// adjust next tick according to price limits
	if step.tickNext < consts.MIN_TICK {
		step.tickNext = consts.MIN_TICK
	} else if step.tickNext > consts.MAX_TICK {
		step.tickNext = consts.MAX_TICK
	}

	step.sqrtPriceNextX96 = common.TickMathGetSqrtRatioAtTick(step.tickNext)

	isLower := step.sqrtPriceNextX96 < sqrtPriceLimitX96
	isHigher := step.sqrtPriceNextX96 > sqrtPriceLimitX96

	var sqrtRatioTargetX96 bigint
	if (zeroForOne && isLower) || (!zeroForOne && isHigher) {
		sqrtRatioTargetX96 = sqrtPriceLimitX96
	} else {
		sqrtRatioTargetX96 = step.sqrtPriceNextX96
	}

	state.sqrtPriceX96, step.amountIn, step.amountOut, step.feeAmount = swapMathComputeSwapStep(
		state.sqrtPriceX96,
		sqrtRatioTargetX96,
		state.liquidity,
		state.amountSpecifiedRemaining,
		uint32(pool.fee),
	)

	return step
}

func TestExecuteSwapStep(t *testing.T) {
	tests := []struct {
		name string
		pool MockPool
		state SwapState
		sqrtPriceLimitX96 bigint
		zeroForOne bool
		expectedState SwapState
	}{
		{
			name: "normal swap, zeroForOne = true",
			pool: MockPool{
				slot0: Slot0{
					sqrtPriceX96: 1000000,
					tick: 1,
					feeProtocol: 10,
					unlocked: true,
				},
				fee: 30,
				tickSpacing: 10,
				tickBitmaps: TickBitmaps{
					0: 1,
				},
			},
			state: SwapState{
				amountSpecifiedRemaining: 1000,
				amountCalculated: 10,
				sqrtPriceX96: 1000000,
				tick: 1,
				feeGrowthGlobalX128: 10,
				protocolFee: 10,
				liquidity: 10000,
			},
			sqrtPriceLimitX96: 9000,
			zeroForOne: true,
			expectedState: SwapState{
				amountSpecifiedRemaining: 1000,
				amountCalculated: 10,
				sqrtPriceX96: 7914_8934_3517_5007_3255_9604_0638,
				tick: 1,
				feeGrowthGlobalX128: 10,
				protocolFee: 10,
				liquidity: 10000,
			},
		},
		{
			name: "normal swap, zeroForOne = false",
			pool: MockPool{
				slot0: Slot0{
					sqrtPriceX96: 1000000,
					tick:         -1,
					feeProtocol:  10,
					unlocked:     true,
				},
				fee:         30,
				tickSpacing: 10,
				tickBitmaps: TickBitmaps{
					-1: 1,
				},
			},
			state: SwapState{
				amountSpecifiedRemaining: 1000,
				amountCalculated:         10,
				sqrtPriceX96:             1000000,
				tick:                     -1,
				feeGrowthGlobalX128:      10,
				protocolFee:              10,
				liquidity:                10000,
			},
			sqrtPriceLimitX96: 1100000,
			zeroForOne:        false,
			expectedState: SwapState{
				amountSpecifiedRemaining: 1000,
				amountCalculated:         10,
				sqrtPriceX96:             1100000,
				tick:                     -1,
				feeGrowthGlobalX128:      10,
				protocolFee:              10,
				liquidity:                10000,
			},
		},
	}

	for _, tc := range tests {
		t.Run(tc.name, func(t *testing.T) {
			step := mockExecuteSwapStep(&tc.pool, &tc.state, tc.sqrtPriceLimitX96, tc.zeroForOne)

			if tc.expectedState.amountSpecifiedRemaining != tc.state.amountSpecifiedRemaining {
				t.Errorf("`%s` expected amountSpecifiedRemaining to be %d, got %d", tc.name, tc.expectedState.amountSpecifiedRemaining, tc.state.amountSpecifiedRemaining)
			}

			if tc.expectedState.amountCalculated != tc.state.amountCalculated {
				t.Errorf("`%s` expected amountCalculated to be %d, got %d", tc.name, tc.expectedState.amountCalculated, tc.state.amountCalculated)
			}

			if tc.expectedState.tick != tc.state.tick {
				t.Errorf("`%s` expected tick to be %d, got %d", tc.name, tc.expectedState.tick, tc.state.tick)
			}

			if tc.expectedState.sqrtPriceX96 != tc.state.sqrtPriceX96 {
				t.Errorf("`%s` expected sqrtPriceX96 to be %d, got %d", tc.name, tc.expectedState.sqrtPriceX96, tc.state.sqrtPriceX96)
			}

			if tc.expectedState.liquidity != tc.state.liquidity {
				t.Errorf("`%s` expected liquidity to be %d, got %d", tc.name, tc.expectedState.liquidity, tc.state.liquidity)
			}

			if tc.expectedState.feeGrowthGlobalX128 != tc.state.feeGrowthGlobalX128 {
				t.Errorf("`%s` expected feeGrowthGlobalX128 to be %d, got %d", tc.name, tc.expectedState.feeGrowthGlobalX128, tc.state.feeGrowthGlobalX128)
			}

			if tc.expectedState.protocolFee != tc.state.protocolFee {
				t.Errorf("`%s` expected protocolFee to be %d, got %d", tc.name, tc.expectedState.protocolFee, tc.state.protocolFee)
			}
		})
	}
}

// func TestApplySwapStep(t *testing.T) {
// 	tests := []struct {
// 		name string
// 		state       SwapState
// 		cache       SwapCache
// 		step        StepComputations
// 		exactInput  bool
// 		expected    SwapState
// 	}{
// 		{
// 			name: "Exact input, fee protocol > 0",
// 			state: SwapState{
// 				amountSpecifiedRemaining: bigint(1000),
// 				amountCalculated:         bigint(0),
// 				protocolFee:              bigint(0),
// 				feeGrowthGlobalX128:      bigint(0),
// 				liquidity:                bigint(10000),
// 			},
// 			cache: SwapCache{
// 				feeProtocol:    10,
// 				liquidityStart: bigint(10000),
// 			},
// 			step: StepComputations{
// 				amountIn:         bigint(100),
// 				amountOut:        bigint(50),
// 				feeAmount:        bigint(5),
// 				sqrtPriceNextX96: bigint(1000000),
// 			},
// 			exactInput: true,
// 			expected: SwapState{
// 				amountSpecifiedRemaining: bigint(895), // 1000 - (100 + 5)
// 				amountCalculated:         bigint(-50),
// 				protocolFee:              bigint(1), // 5 / 10
// 				feeGrowthGlobalX128:      bigint(0),   // Updated based on feeAmount and liquidity
// 				liquidity:                bigint(10000),
// 			},
// 		},
// 		{
// 			name: "Not exact input, fee protocol = 0",
// 			state: SwapState{
// 				amountSpecifiedRemaining: bigint(1000),
// 				amountCalculated:         bigint(0),
// 				protocolFee:              bigint(0),
// 				feeGrowthGlobalX128:      bigint(0),
// 				liquidity:                bigint(10000),
// 			},
// 			cache: SwapCache{
// 				feeProtocol:    0,
// 				liquidityStart: bigint(10000),
// 			},
// 			step: StepComputations{
// 				amountIn:         bigint(100),
// 				amountOut:        bigint(50),
// 				feeAmount:        bigint(5),
// 				sqrtPriceNextX96: bigint(1000000),
// 			},
// 			exactInput: false,
// 			expected: SwapState{
// 				amountSpecifiedRemaining: bigint(1050), // 1000 + 50
// 				amountCalculated:         bigint(105),  // 100 + 5
// 				protocolFee:              bigint(0),
// 				feeGrowthGlobalX128:      bigint(0),    // Updated based on feeAmount and liquidity
// 				liquidity:                bigint(10000),
// 			},
// 		},
// 	}

// 	for _, tc := range tests {
// 		t.Run(tc.name, func(t *testing.T) {
// 			applySwapStep(&tc.state, &tc.cache, &tc.step, tc.exactInput)
// 		})

// 		if tc.expected.amountSpecifiedRemaining != tc.state.amountSpecifiedRemaining {
// 			t.Errorf("`%s` expected amountSpecifiedRemaining to be %d, got %d", tc.name, tc.expected.amountSpecifiedRemaining, tc.state.amountSpecifiedRemaining)
// 		}
// 	}
// }