package pool

import (
	"testing"

	"gno.land/p/gnoswap/gnsmath/v1"
	uassert "gno.land/p/nt/uassert/v0"
	pl "gno.land/r/gnoswap/pool"
)

// snapshotDrySwapState captures accounting before a quote and returns its check.
func snapshotDrySwapState(t *testing.T, pool *pl.Pool) func() {
	t.Helper()
	beforePool := pool.Clone()
	beforeTicks := make(map[int32]pl.TickInfo)
	pool.IterateTicks(MIN_TICK, MAX_TICK, func(tick int32, info pl.TickInfo) bool {
		beforeTicks[tick] = info
		return false
	})
	beforeBitmaps := make(map[int16]string)
	for word, bitmap := range pool.TickBitmaps() {
		beforeBitmaps[word] = bitmap
	}
	beforePositions := pool.Positions().Size()
	slot0 := pool.Slot0()
	beforeObservations := make([]pl.Observation, slot0.ObservationCardinalityNext())
	for index := range beforeObservations {
		observation, err := getMockInstance().GetObservationAt(pool.PoolPath(), uint16(index))
		uassert.NoError(t, err)
		beforeObservations[index] = observation
	}
	return func() {
		t.Helper()
		uassert.True(t, beforePool.Balances() == pool.Balances(), "quote changed balances")
		uassert.True(t, beforePool.ProtocolFees() == pool.ProtocolFees(), "quote changed protocol fees")
		uassert.True(t, beforePool.Liquidity().Eq(pool.Liquidity()), "quote changed liquidity")
		uassert.True(t, beforePool.FeeGrowthGlobal0X128().Eq(pool.FeeGrowthGlobal0X128()), "quote changed token0 fee growth")
		uassert.True(t, beforePool.FeeGrowthGlobal1X128().Eq(pool.FeeGrowthGlobal1X128()), "quote changed token1 fee growth")
		uassert.True(t, beforePool.Slot0SqrtPriceX96().Eq(pool.Slot0SqrtPriceX96()), "quote changed price")
		uassert.Equal(t, beforePool.Slot0Tick(), pool.Slot0Tick(), "quote changed tick")
		uassert.Equal(t, beforePool.Slot0FeeProtocol(), pool.Slot0FeeProtocol())
		uassert.Equal(t, beforePool.Slot0Unlocked(), pool.Slot0Unlocked())
		afterSlot0 := pool.Slot0()
		uassert.Equal(t, slot0.ObservationIndex(), afterSlot0.ObservationIndex())
		uassert.Equal(t, slot0.ObservationCardinality(), afterSlot0.ObservationCardinality())
		uassert.Equal(t, slot0.ObservationCardinalityNext(), afterSlot0.ObservationCardinalityNext())
		uassert.Equal(t, len(beforeBitmaps), len(pool.TickBitmaps()))
		for word, before := range beforeBitmaps {
			uassert.Equal(t, before, pool.TickBitmaps()[word], "quote changed tick bitmap")
		}
		uassert.Equal(t, len(beforeTicks), pool.Ticks().Size())
		for tick, before := range beforeTicks {
			after, err := pool.GetTick(tick)
			uassert.NoError(t, err)
			uassert.True(t, before == after, "quote changed tick accounting")
		}
		uassert.Equal(t, beforePositions, pool.Positions().Size())
		for index, before := range beforeObservations {
			after, err := getMockInstance().GetObservationAt(pool.PoolPath(), uint16(index))
			uassert.NoError(t, err)
			uassert.True(t, before == after, "quote changed oracle history")
		}
	}
}

func setupDrySwapReadOnlyPool(cur realm, t *testing.T) *pl.Pool {
	t.Helper()
	resetObject(cur, t)
	burnTokens(cur, t)
	testing.SetOriginCaller(adminAddr)
	testing.SetRealm(adminRealm)
	mockInstanceSetPoolCreationFee(0, cur, 0)
	TokenApprove(cur, t, barPath, adminAddr, poolAddr, maxApprove)
	TokenApprove(cur, t, bazPath, adminAddr, poolAddr, maxApprove)
	mockInstanceCreatePool(0, cur, barPath, bazPath, FeeTier100, EQUAL_PRICE_RATIO)

	testing.SetRealm(posRealm)
	mockInstanceMint(0, cur, barPath, bazPath, FeeTier100, -300, -200, "100000", adminAddr)
	mockInstanceMint(0, cur, barPath, bazPath, FeeTier100, -200, -100, "200000", adminAddr)
	mockInstanceMint(0, cur, barPath, bazPath, FeeTier100, -100, 0, "300000", adminAddr)
	mockInstanceMint(0, cur, barPath, bazPath, FeeTier100, 0, 100, "400000", adminAddr)
	mockInstanceMint(0, cur, barPath, bazPath, FeeTier100, 100, 200, "500000", adminAddr)
	mockInstanceMint(0, cur, barPath, bazPath, FeeTier100, 200, 300, "600000", adminAddr)
	for _, tickId := range []int32{-200, -100, 0, 100, 200} {
		tick, err := getMockInstance().mustGetPoolBy(barPath, bazPath, FeeTier100).GetTick(tickId)
		uassert.NoError(t, err)
		uassert.True(t, tick.LiquidityNet() != "0", "fixture must change liquidity at every crossed tick")
	}
	testing.SetRealm(adminRealm)
	mockInstanceSetFeeProtocol(0, cur, 4, 5)
	return getMockInstance().mustGetPoolBy(barPath, bazPath, FeeTier100)
}

func TestDrySwapMatchesSwapAcrossMultipleTicks(cur realm, t *testing.T) {
	tests := []struct {
		name            string
		zeroForOne      bool
		amountSpecified string
		limitTick       int32
	}{
		{"zero_for_one_exact_in", true, "12000", -300},
		{"zero_for_one_exact_out", true, "-10000", -300},
		{"one_for_zero_exact_in", false, "12000", 300},
		{"one_for_zero_exact_out", false, "-10000", 300},
	}
	for _, tt := range tests {
		t.Run(tt.name, func(cur realm, t *testing.T) {
			pool := setupDrySwapReadOnlyPool(cur, t)
			defer resetObject(cur, t)
			assertUnchanged := snapshotDrySwapState(t, pool)
			limit := gnsmath.TickMathGetSqrtRatioAtTick(tt.limitTick).ToString()
			dryAmount0, dryAmount1, err := pl.DrySwap(barPath, bazPath, FeeTier100, tt.zeroForOne, tt.amountSpecified, limit)
			uassert.NoError(t, err)
			assertUnchanged()

			testing.SetRealm(rouRealm)
			actualAmount0, actualAmount1 := mockInstanceSwap(0, cur, barPath, bazPath, FeeTier100, routerAddr, tt.zeroForOne, tt.amountSpecified, limit,
				func(cur realm, amount0Delta int64, amount1Delta int64, _ *pl.CallbackMarker) error {
					return mockSwapCallback(cur, barPath, bazPath, amount0Delta, amount1Delta)
				})
			uassert.Equal(t, dryAmount0, actualAmount0)
			uassert.Equal(t, dryAmount1, actualAmount1)
			if tt.zeroForOne {
				uassert.True(t, pool.Slot0Tick() <= -200, "swap did not cross multiple ticks")
			} else {
				uassert.True(t, pool.Slot0Tick() >= 200, "swap did not cross multiple ticks")
			}
		})
	}
}

func TestDrySwapRejectsLockedPool(cur realm, t *testing.T) {
	pool := setupDrySwapReadOnlyPool(cur, t)
	defer resetObject(cur, t)
	assertUnchanged := snapshotDrySwapState(t, pool)
	getMockInstance().lockPool(0, cur)
	defer getMockInstance().unlockPool(0, cur)

	amount0, amount1, err := pl.DrySwap(barPath, bazPath, FeeTier100, true, "100", gnsmath.TickMathGetSqrtRatioAtTick(-1).ToString())
	uassert.ErrorContains(t, err, errLockedPool)
	uassert.Equal(t, "0", amount0)
	uassert.Equal(t, "0", amount1)
	assertUnchanged()
}
