package staker

import (
	"testing"

	i256 "gno.land/p/gnoswap/int256"
	uassert "gno.land/p/nt/uassert/v0"
	sr "gno.land/r/gnoswap/staker"
)

// TestFormalUnclaimableReplayAfterHalving fixes the ordering used by tick
// crossing: cache elapsed halving boundaries before changing staked liquidity.
func TestFormalUnclaimableReplayAfterHalving(cur realm, t *testing.T) {
	const (
		start      int64 = 1
		halving    int64 = 5
		tickCross  int64 = 10
		collect    int64 = 20
		beforeRate int64 = 100
		afterRate  int64 = 50
	)

	pool := sr.NewPool("formal-unclaimable-replay", start)
	resolver := NewPoolResolver(pool)
	resolver.cacheReward(start, beforeRate)

	// Equivalent to cacheRewardForPool's historical-boundary replay before
	// processTickCrossImmediate/processBatchedTickCrosses calls modifyDeposit.
	resolver.cacheReward(halving, afterRate)
	resolver.cacheReward(tickCross, afterRate)
	resolver.modifyDeposit(i256.NewInt(1), tickCross, 0)
	resolver.cacheReward(collect, afterRate)

	want := (halving-start)*beforeRate + (tickCross-halving)*afterRate
	uassert.Equal(t, want, resolver.processUnclaimableReward(collect))
}
