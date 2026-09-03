package staker

import (
	"testing"

	i256 "gno.land/p/gnoswap/int256"
	uassert "gno.land/p/nt/uassert/v0"
	sr "gno.land/r/gnoswap/staker"
)

const (
	immediateTickCrossStart      int64 = 1
	immediateTickCrossHalving    int64 = 5
	immediateTickCrossTime       int64 = 10
	immediateTickCrossBeforeRate int64 = 100
	immediateTickCrossAfterRate  int64 = 50
	immediateTickCrossPoolPath         = "gno.land/r/onbloc/bar.BAR:gno.land/r/onbloc/baz.BAZ:3000"
)

// newImmediateTickCrossState creates a zero-liquidity tiered pool whose rate
// halves before a tick cross adds the first unit of staked liquidity.
func newImmediateTickCrossState() (*stakerV1, *PoolResolver, *sr.Pool, *sr.Tick) {
	pool := sr.NewPool(immediateTickCrossPoolPath, immediateTickCrossStart)
	resolver := NewPoolResolver(pool)
	resolver.cacheReward(immediateTickCrossStart, immediateTickCrossBeforeRate)

	tick := sr.NewTick(0)
	NewTickResolver(tick).modifyDepositLower(immediateTickCrossStart, i256.NewInt(1))
	pool.Ticks().SetTick(0, tick)

	pools := NewPools()
	pools.set(immediateTickCrossPoolPath, pool)
	poolTier := newTestPoolTier(
		immediateTickCrossPoolPath,
		Tier1,
		[AllTierCount]uint64{0, 1, 0, 0},
		[]halvingPoint{{at: immediateTickCrossHalving, emission: immediateTickCrossAfterRate}},
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

// TestProcessTickCrossImmediate_ReplaysHalvingBeforeDeposit verifies the
// unbatched fallback closes and restarts the zero-liquidity window at the
// elapsed halving boundary before modifyDeposit changes staked liquidity.
func TestProcessTickCrossImmediate_ReplaysHalvingBeforeDeposit(t *testing.T) {
	instance, resolver, pool, tick := newImmediateTickCrossState()
	want := (immediateTickCrossHalving-immediateTickCrossStart)*immediateTickCrossBeforeRate +
		(immediateTickCrossTime-immediateTickCrossHalving)*immediateTickCrossAfterRate

	instance.processTickCrossImmediate(pool, tick, tick.Id(), false, immediateTickCrossTime)

	uassert.Equal(t, want, resolver.processUnclaimableReward(immediateTickCrossTime))
}
