package pool

import (
	"testing"

	"gno.land/p/gnoswap/consts"
	u256 "gno.land/p/gnoswap/uint256"
	uassert "gno.land/p/nt/uassert/v0"
	pl "gno.land/r/gnoswap/pool"
)

type snapshotCumulativesInsideCase struct {
	name                 string
	currentTick          int32
	lower                pl.TickInfo
	upper                pl.TickInfo
	observationTick      int64
	observationLiquidity string
	wantTick             int64
	wantLiquidity        string
	wantSeconds          uint32
}

func TestSnapshotCumulativesInside_RangePosition(cur realm, t *testing.T) {
	tests := []snapshotCumulativesInsideCase{
		{
			name:                 "below range subtracts upper outside accumulators",
			currentTick:          -20,
			lower:                newSnapshotTickInfo(100, "900", 50, true),
			upper:                newSnapshotTickInfo(40, "300", 20, true),
			observationTick:      0,
			observationLiquidity: "0",
			wantTick:             60,
			wantLiquidity:        "600",
			wantSeconds:          30,
		},
		{
			name:                 "inside range subtracts both outside accumulators from current",
			currentTick:          0,
			lower:                newSnapshotTickInfo(100, "1000", 10, true),
			upper:                newSnapshotTickInfo(200, "2000", 20, true),
			observationTick:      1000,
			observationLiquidity: "5000",
			wantTick:             700,
			wantLiquidity:        "2000",
			wantSeconds:          70,
		},
		{
			name:                 "above range subtracts lower outside accumulators",
			currentTick:          20,
			lower:                newSnapshotTickInfo(40, "300", 20, true),
			upper:                newSnapshotTickInfo(100, "900", 50, true),
			observationTick:      0,
			observationLiquidity: "0",
			wantTick:             60,
			wantLiquidity:        "600",
			wantSeconds:          30,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(cur realm, t *testing.T) {
			restoreContext := setOracleTestContext(100)
			defer restoreContext()

			pool := newSnapshotCumulativesInsidePool(
				tt.currentTick,
				-10,
				10,
				100,
				tt.observationTick,
				tt.observationLiquidity,
				tt.lower,
				tt.upper,
			)

			tickCumulativeInside, secondsPerLiquidityInsideX128, secondsInside, err := snapshotCumulativesInside(pool, observationsForTest(pool), -10, 10)
			uassert.NoError(t, err)
			uassert.Equal(t, tt.wantTick, tickCumulativeInside)
			uassert.Equal(t, tt.wantLiquidity, secondsPerLiquidityInsideX128.ToString())
			uassert.Equal(t, tt.wantSeconds, secondsInside)
		})
	}
}

func TestSnapshotCumulativesInside_UsesCounterfactualCurrentObservation(cur realm, t *testing.T) {
	restoreContext := setOracleTestContext(100)
	defer restoreContext()

	pool := newSnapshotCumulativesInsidePool(
		10,
		-10,
		20,
		90,
		900,
		"0",
		newSnapshotTickInfo(100, "0", 10, true),
		newSnapshotTickInfo(200, "0", 20, true),
	)
	pool.SetLiquidity(u256.One())

	observationBefore, ok := observationsForTest(pool).Get(0)
	uassert.True(t, ok)
	beforeTimestamp := observationBefore.BlockTimestamp()
	beforeTickCumulative := observationBefore.TickCumulative()
	beforeSecondsPerLiquidity := observationBefore.SecondsPerLiquidityCumulativeX128()
	slot0Before := pool.Slot0()

	tickCumulativeInside, secondsPerLiquidityInsideX128, secondsInside, err := snapshotCumulativesInside(pool, observationsForTest(pool), -10, 20)
	uassert.NoError(t, err)
	uassert.Equal(t, int64(700), tickCumulativeInside)
	uassert.Equal(t, u256.Zero().Mul(u256.NewUint(10), consts.Q128()).ToString(), secondsPerLiquidityInsideX128.ToString())
	uassert.Equal(t, uint32(70), secondsInside)

	observationAfter, ok := observationsForTest(pool).Get(0)
	uassert.True(t, ok)
	uassert.Equal(t, beforeTimestamp, observationAfter.BlockTimestamp())
	uassert.Equal(t, beforeTickCumulative, observationAfter.TickCumulative())
	uassert.Equal(t, beforeSecondsPerLiquidity, observationAfter.SecondsPerLiquidityCumulativeX128())

	slot0After := pool.Slot0()
	uassert.Equal(t, slot0Before.ObservationIndex(), slot0After.ObservationIndex())
	uassert.Equal(t, slot0Before.ObservationCardinality(), slot0After.ObservationCardinality())
}

func TestSnapshotCumulativesInside_ValidatesRangeAndTicks(cur realm, t *testing.T) {
	pool := createTestPool()

	tests := []struct {
		name      string
		tickLower int32
		tickUpper int32
		wantErr   string
	}{
		{
			name:      "rejects an empty range",
			tickLower: 0,
			tickUpper: 0,
			wantErr:   errInvalidTickRange,
		},
		{
			name:      "rejects a lower tick below the minimum",
			tickLower: MIN_TICK - 1,
			tickUpper: 0,
			wantErr:   errTickLowerInvalid,
		},
		{
			name:      "rejects an upper tick above the maximum",
			tickLower: 0,
			tickUpper: MAX_TICK + 1,
			wantErr:   errTickUpperInvalid,
		},
		{
			name:      "requires initialized lower and upper ticks",
			tickLower: -10,
			tickUpper: 10,
			wantErr:   errDataNotFound,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(cur realm, t *testing.T) {
			_, _, _, err := snapshotCumulativesInside(pool, observationsForTest(pool), tt.tickLower, tt.tickUpper)
			uassert.ErrorContains(t, err, tt.wantErr)
		})
	}
}

func newSnapshotCumulativesInsidePool(
	currentTick int32,
	tickLower int32,
	tickUpper int32,
	observationTimestamp int64,
	observationTickCumulative int64,
	observationSecondsPerLiquidityX128 string,
	lower pl.TickInfo,
	upper pl.TickInfo,
) *pl.Pool {
	pool := createTestPool()
	slot0 := pool.Slot0()
	slot0.SetTick(currentTick)
	slot0.SetObservationIndex(0)
	slot0.SetObservationCardinality(1)
	slot0.SetObservationCardinalityNext(1)
	pool.SetSlot0(slot0)
	pool.SetLiquidity(u256.One())

	observations := pl.NewPoolObservationsTree(observationTimestamp)
	observations.Set(0, pl.NewObservation(
		observationTimestamp,
		observationTickCumulative,
		observationSecondsPerLiquidityX128,
		true,
	))
	setObservationsForTest(pool, observations)

	ticks := pl.NewPoolTicksTree()
	ticks.Set(pl.EncodeTickKey(tickLower), lower)
	ticks.Set(pl.EncodeTickKey(tickUpper), upper)
	pool.SetTicks(ticks)

	return pool
}

func newSnapshotTickInfo(
	tickCumulativeOutside int64,
	secondsPerLiquidityOutsideX128 string,
	secondsOutside uint32,
	initialized bool,
) pl.TickInfo {
	tickInfo := pl.NewTickInfo()
	tickInfo.SetTickCumulativeOutside(tickCumulativeOutside)
	tickInfo.SetSecondsPerLiquidityOutsideX128(secondsPerLiquidityOutsideX128)
	tickInfo.SetSecondsOutside(secondsOutside)
	tickInfo.SetInitialized(initialized)
	return tickInfo
}
