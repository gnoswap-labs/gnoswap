package pool

import (
	"testing"
	"time"

	u256 "gno.land/p/gnoswap/uint256"
	uassert "gno.land/p/nt/uassert/v0"
	pl "gno.land/r/gnoswap/pool"
)

func TestTickTransitionSeedsOracleFromSwapStartTick(cur realm, t *testing.T) {
	const (
		swapStartTick = int32(0)
		midSwapTick   = int32(255)
		crossedTick   = int32(500)
		timeDelta     = int64(100)
	)

	currentTime := time.Now().Unix()
	pool := makeMockPool(createMockPoolParams{
		slot0:            mockSlot0{tick: swapStartTick},
		liquidity:        u256.One(),
		observationState: pl.NewObservationState(currentTime - timeDelta),
	})
	pool.SetTick(crossedTick, pl.NewTickInfo())

	state := SwapState{
		tick:                midSwapTick,
		liquidity:           u256.One(),
		feeGrowthGlobalX128: u256.Zero(),
	}
	cache := newSwapCache(0, u256.One(), currentTime, pool.Slot0())
	step := StepComputations{tickNext: crossedTick, initialized: true}

	getMockInstance().tickTransition(step, false, state, pool, cache, nil)

	tick, err := pool.GetTick(crossedTick)
	uassert.NoError(t, err)
	uassert.Equal(t, int64(swapStartTick)*timeDelta, tick.TickCumulativeOutside())
}
