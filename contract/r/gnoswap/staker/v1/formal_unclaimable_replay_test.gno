package staker

import (
	"testing"

	i256 "gno.land/p/gnoswap/int256"
	uassert "gno.land/p/nt/uassert/v0"
	sr "gno.land/r/gnoswap/staker"
)

const (
	formalReplayStart      int64 = 1
	formalReplayHalving    int64 = 5
	formalReplayTickCross  int64 = 10
	formalReplayBeforeRate int64 = 100
	formalReplayAfterRate  int64 = 50
	formalReplayPoolPath         = "gno.land/r/onbloc/bar.BAR:gno.land/r/onbloc/baz.BAZ:3000"
)

// newFormalUnclaimableReplayState creates a zero-liquidity tiered pool whose
// rate halves before a tick cross adds the first unit of staked liquidity.
func newFormalUnclaimableReplayState() (*stakerV1, *PoolResolver, *sr.Pool, *sr.Tick) {

	pool := sr.NewPool(formalReplayPoolPath, formalReplayStart)
	resolver := NewPoolResolver(pool)
	resolver.cacheReward(formalReplayStart, formalReplayBeforeRate)

	tick := sr.NewTick(0)
	NewTickResolver(tick).modifyDepositLower(formalReplayStart, i256.NewInt(1))
	pool.Ticks().SetTick(0, tick)

	pools := NewPools()
	pools.set(formalReplayPoolPath, pool)
	poolTier := newTestPoolTier(
		formalReplayPoolPath,
		Tier1,
		[AllTierCount]uint64{0, 1, 0, 0},
		[]halvingPoint{{at: formalReplayHalving, emission: formalReplayAfterRate}},
	)

	store := newMockStakerStore()
	store.pools = pools.tree
	store.poolTierMemberships = poolTier.membership
	store.poolTierRatio = poolTier.tierRatio
	store.poolTierCounts = poolTier.counts
	store.poolTierLastRewardCacheTimestamp = poolTier.lastRewardCacheTimestamp
	store.poolTierCurrentEmission = poolTier.currentEmission
	store.poolTierGetEmission = poolTier.getEmission
	store.poolTierGetHalvingBlocksInRange = poolTier.getHalvingBlocksInRange

	return &stakerV1{store: store}, resolver, pool, tick
}

// TestFormalUnclaimableReplayAfterHalving verifies both tick-cross paths cache
// elapsed halving boundaries before modifyDeposit closes the zero-liquidity
// window. Removing either cacheRewardForPool call must make this test fail.
func TestFormalUnclaimableReplayAfterHalving(cur realm, t *testing.T) {
	want := (formalReplayHalving-formalReplayStart)*formalReplayBeforeRate +
		(formalReplayTickCross-formalReplayHalving)*formalReplayAfterRate

	t.Run("immediate tick cross", func(t *testing.T) {
		instance, resolver, pool, tick := newFormalUnclaimableReplayState()

		instance.processTickCrossImmediate(pool, tick, tick.Id(), false, formalReplayTickCross)

		uassert.Equal(t, want, resolver.processUnclaimableReward(formalReplayTickCross))
	})

	t.Run("batched tick crosses", func(t *testing.T) {
		instance, resolver, pool, tick := newFormalUnclaimableReplayState()
		batch := sr.NewSwapBatchProcessor(formalReplayPoolPath, pool, formalReplayTickCross)
		batch.AddCross(sr.NewSwapTickCross(tick.Id(), false, i256.NewInt(1)))
		if err := instance.store.SetCurrentSwapBatch(0, cur, batch); err != nil {
			t.Fatalf("set swap batch: %s", err.Error())
		}

		if err := instance.processBatchedTickCrosses(0, cur); err != nil {
			t.Fatalf("process batched tick crosses: %s", err.Error())
		}
		uassert.Equal(t, want, resolver.processUnclaimableReward(formalReplayTickCross))
	})
}
