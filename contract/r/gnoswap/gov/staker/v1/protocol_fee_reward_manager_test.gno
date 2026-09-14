package staker

import (
	"math"
	"testing"

	uassert "gno.land/p/nt/uassert/v0"

	u256 "gno.land/p/gnoswap/uint256"

	"gno.land/r/gnoswap/gov/staker"
)

const (
	pfTestBar = "gno.land/r/onbloc/bar.BAR"
	pfTestQux = "gno.land/r/onbloc/qux.QUX"
)

func newPfTestManager() *ProtocolFeeRewardManagerResolver {
	return NewProtocolFeeRewardManagerResolver(staker.NewProtocolFeeRewardManager())
}

// foldAll folds the given buckets as an exhaustive consume at the manager's epoch.
func foldAll(t *testing.T, resolver *ProtocolFeeRewardManagerResolver, tokenPath string, epochs, amounts []int64, timestamp int64) {
	t.Helper()
	uassert.NoError(t, resolver.applyAccrualBuckets(tokenPath, epochs, amounts, true, timestamp))
}

func TestProtocolFeeRewardManager_addStake(cur realm, t *testing.T) {
	t.Run("records epoch, total and staker event", func(cur realm, t *testing.T) {
		resolver := newPfTestManager()

		uassert.NoError(t, resolver.addStake("alice", 100, 1))
		uassert.NoError(t, resolver.addStake("bob", 300, 2))
		uassert.NoError(t, resolver.addStake("alice", 50, 3))

		uassert.Equal(t, resolver.GetCurrentEpoch(), int64(3))
		uassert.Equal(t, resolver.GetTotalStakedAmount(), int64(450))
		uassert.Equal(t, resolver.GetTotalStakedAmountAt(0), int64(0))
		uassert.Equal(t, resolver.GetTotalStakedAmountAt(1), int64(100))
		uassert.Equal(t, resolver.GetTotalStakedAmountAt(2), int64(400))
		uassert.Equal(t, resolver.GetTotalStakedAmountAt(3), int64(450))

		alice, ok, err := resolver.GetRewardState("alice")
		uassert.NoError(t, err)
		uassert.True(t, ok)
		uassert.Equal(t, alice.GetStakedAmount(), int64(150))
		uassert.Equal(t, alice.GetStakeEventCount(), int64(2))
		event, ok := alice.GetStakeEvent(1)
		uassert.True(t, ok)
		uassert.Equal(t, event.GetEpoch(), int64(3))
		uassert.Equal(t, event.GetStakedAmount(), int64(150))

		// No accumulator was touched.
		uassert.Equal(t, len(resolver.GetTokenPaths()), 0)
	})

	t.Run("rejects non-positive amount", func(cur realm, t *testing.T) {
		resolver := newPfTestManager()
		uassert.ErrorContains(t, resolver.addStake("alice", 0, 1), errAmountMustBePositive)
		uassert.ErrorContains(t, resolver.addStake("alice", -1, 1), errAmountMustBePositive)
	})

	t.Run("rejects an epoch older than the one in force", func(cur realm, t *testing.T) {
		resolver := newPfTestManager()
		uassert.NoError(t, resolver.addStake("alice", 100, 5))
		uassert.ErrorContains(t, resolver.addStake("alice", 100, 4), errInvalidAccrualEpoch)
	})

	t.Run("rejects total overflow", func(cur realm, t *testing.T) {
		resolver := newPfTestManager()
		uassert.NoError(t, resolver.addStake("alice", math.MaxInt64-10, 1))
		uassert.ErrorContains(t, resolver.addStake("bob", 11, 2), errTotalStakedAmountOverflow)
	})
}

func TestProtocolFeeRewardManager_removeStake(cur realm, t *testing.T) {
	t.Run("records the decrease", func(cur realm, t *testing.T) {
		resolver := newPfTestManager()
		uassert.NoError(t, resolver.addStake("alice", 100, 1))
		uassert.NoError(t, resolver.removeStake("alice", 40, 2))

		uassert.Equal(t, resolver.GetTotalStakedAmount(), int64(60))
		uassert.Equal(t, resolver.GetTotalStakedAmountAt(1), int64(100))
		uassert.Equal(t, resolver.GetTotalStakedAmountAt(2), int64(60))

		alice, _, _ := resolver.GetRewardState("alice")
		uassert.Equal(t, alice.GetStakedAmount(), int64(60))
		uassert.Equal(t, alice.GetStakeEventCount(), int64(2))
	})

	t.Run("rejects negative amount", func(cur realm, t *testing.T) {
		resolver := newPfTestManager()
		uassert.ErrorContains(t, resolver.removeStake("alice", -1, 1), errAmountMustBeNonNegative)
	})

	t.Run("rejects total underflow", func(cur realm, t *testing.T) {
		resolver := newPfTestManager()
		uassert.ErrorContains(t, resolver.removeStake("alice", 1, 1), errRemoveAmountExceedsTotalStaked)
	})

	t.Run("rejects over-removal for the staker and leaves totals untouched", func(cur realm, t *testing.T) {
		resolver := newPfTestManager()
		uassert.NoError(t, resolver.addStake("alice", 100, 1))
		uassert.NoError(t, resolver.addStake("bob", 100, 2))

		uassert.ErrorContains(t, resolver.removeStake("alice", 150, 3), errRemoveAmountExceedsStaked)
		uassert.Equal(t, resolver.GetTotalStakedAmount(), int64(200))
		uassert.Equal(t, resolver.GetCurrentEpoch(), int64(2))
	})

	t.Run("rejects an epoch older than the one in force", func(cur realm, t *testing.T) {
		resolver := newPfTestManager()
		uassert.NoError(t, resolver.addStake("alice", 100, 5))
		uassert.ErrorContains(t, resolver.removeStake("alice", 10, 4), errInvalidAccrualEpoch)
	})
}

func TestProtocolFeeRewardManager_applyAccrualBuckets(cur realm, t *testing.T) {
	t.Run("divides each bucket by the total stake in force during its epoch", func(cur realm, t *testing.T) {
		resolver := newPfTestManager()
		uassert.NoError(t, resolver.addStake("alice", 100, 1))
		uassert.NoError(t, resolver.addStake("bob", 300, 2))

		foldAll(t, resolver, pfTestBar, []int64{1, 2}, []int64{1000, 800}, 50)

		accumulator, ok := resolver.GetTokenAccumulator(pfTestBar)
		uassert.True(t, ok)
		// 1000/100 = 10 per stake, then 800/400 = 2 per stake.
		uassert.Equal(t, accumulator.GetAccumulatedX128PerStakeAt(1).ToString(), x128(10))
		uassert.Equal(t, accumulator.GetAccumulatedX128PerStakeAt(2).ToString(), x128(12))
		uassert.Equal(t, accumulator.GetAccumulatedX128PerStake().ToString(), x128(12))
		uassert.Equal(t, accumulator.GetFirstEpoch(), int64(1))
		uassert.Equal(t, accumulator.GetProtocolFeeAmount(), int64(1800))
		uassert.Equal(t, resolver.GetAccumulatedTimestamp(), int64(50))
		// The epoch in force stays open, every earlier one is folded.
		uassert.Equal(t, accumulator.GetFoldedEpoch(), int64(1))
	})

	t.Run("drops a bucket with nothing staked but still counts it", func(cur realm, t *testing.T) {
		resolver := newPfTestManager()

		foldAll(t, resolver, pfTestBar, []int64{0}, []int64{5000}, 10)

		accumulator, ok := resolver.GetTokenAccumulator(pfTestBar)
		uassert.True(t, ok)
		uassert.Equal(t, accumulator.GetAccumulatedX128PerStake().ToString(), "0")
		uassert.Equal(t, accumulator.GetFirstEpoch(), int64(-1))
		uassert.Equal(t, accumulator.GetProtocolFeeAmount(), int64(5000))
	})

	t.Run("a partial consume folds only up to the last bucket", func(cur realm, t *testing.T) {
		resolver := newPfTestManager()
		uassert.NoError(t, resolver.addStake("alice", 100, 1))
		uassert.NoError(t, resolver.removeStake("alice", 0, 2))
		uassert.NoError(t, resolver.removeStake("alice", 0, 3))

		uassert.NoError(t, resolver.applyAccrualBuckets(pfTestBar, []int64{1}, []int64{100}, false, 10))
		accumulator, _ := resolver.GetTokenAccumulator(pfTestBar)
		uassert.Equal(t, accumulator.GetFoldedEpoch(), int64(1))

		// Exhausting the buckets marks every closed epoch as folded.
		uassert.NoError(t, resolver.applyAccrualBuckets(pfTestBar, []int64{}, []int64{}, true, 11))
		uassert.Equal(t, accumulator.GetFoldedEpoch(), int64(2))
	})

	t.Run("an empty exhaustive fold of an unknown token creates nothing", func(cur realm, t *testing.T) {
		resolver := newPfTestManager()
		foldAll(t, resolver, pfTestBar, []int64{}, []int64{}, 10)
		uassert.Equal(t, len(resolver.GetTokenPaths()), 0)
	})

	t.Run("rejects malformed buckets", func(cur realm, t *testing.T) {
		resolver := newPfTestManager()
		uassert.NoError(t, resolver.addStake("alice", 100, 1))

		uassert.ErrorContains(t, resolver.applyAccrualBuckets(pfTestBar, []int64{1}, []int64{}, true, 1), errInvalidAccrualBuckets)
		uassert.ErrorContains(t, resolver.applyAccrualBuckets(pfTestBar, []int64{2}, []int64{1}, true, 1), errInvalidAccrualBuckets)
		uassert.ErrorContains(t, resolver.applyAccrualBuckets(pfTestBar, []int64{1, 0}, []int64{1, 1}, true, 1), errInvalidAccrualBuckets)
		uassert.ErrorContains(t, resolver.applyAccrualBuckets(pfTestBar, []int64{1}, []int64{-1}, true, 1), errInvalidAccrualBuckets)
	})
}

// TestProtocolFeeRewardManager_claimRewards_ExactAcrossStakeChanges is the core
// correctness check: fees folded long after the stake changes they span are still
// attributed to the stake distribution in force when they arrived.
func TestProtocolFeeRewardManager_claimRewards_ExactAcrossStakeChanges(cur realm, t *testing.T) {
	resolver := newPfTestManager()

	// epoch 1: alice 100 (total 100), fee 1000 -> alice 1000
	// epoch 2: bob 300 (total 400), fee 800 -> alice 200, bob 600
	// epoch 3: alice out (total 300), fee 300 -> bob 300
	uassert.NoError(t, resolver.addStake("alice", 100, 1))
	uassert.NoError(t, resolver.addStake("bob", 300, 2))
	uassert.NoError(t, resolver.removeStake("alice", 100, 3))

	foldAll(t, resolver, pfTestBar, []int64{1, 2, 3}, []int64{1000, 800, 300}, 100)

	aliceRewards, err := resolver.claimRewards("alice", 100)
	uassert.NoError(t, err)
	uassert.Equal(t, aliceRewards[pfTestBar], int64(1200))

	bobRewards, err := resolver.claimRewards("bob", 100)
	uassert.NoError(t, err)
	uassert.Equal(t, bobRewards[pfTestBar], int64(900))

	// Nothing is left once collected.
	aliceRewards, err = resolver.claimRewards("alice", 101)
	uassert.NoError(t, err)
	uassert.Equal(t, aliceRewards[pfTestBar], int64(0))

	alice, _, _ := resolver.GetRewardState("alice")
	uassert.Equal(t, alice.GetClaimedReward(pfTestBar), int64(1200))
	bob, _, _ := resolver.GetRewardState("bob")
	uassert.Equal(t, bob.GetClaimedReward(pfTestBar), int64(900))
}

func TestProtocolFeeRewardManager_claimRewards_SameSecondIsIdempotent(cur realm, t *testing.T) {
	resolver := newPfTestManager()
	uassert.NoError(t, resolver.addStake("alice", 100, 1))
	foldAll(t, resolver, pfTestBar, []int64{1}, []int64{1000}, 100)

	rewards, err := resolver.claimRewards("alice", 100)
	uassert.NoError(t, err)
	uassert.Equal(t, rewards[pfTestBar], int64(1000))

	// A second all-token claim in the same second pays nothing and touches nothing.
	rewards, err = resolver.claimRewards("alice", 100)
	uassert.NoError(t, err)
	uassert.Equal(t, len(rewards), 0)

	// An unknown staker gets an empty map.
	rewards, err = resolver.claimRewards("nobody", 100)
	uassert.NoError(t, err)
	uassert.Equal(t, len(rewards), 0)
}

func TestProtocolFeeRewardManager_claimTokenReward(cur realm, t *testing.T) {
	t.Run("settles one token and leaves the others untouched", func(cur realm, t *testing.T) {
		resolver := newPfTestManager()
		uassert.NoError(t, resolver.addStake("alice", 100, 1))
		foldAll(t, resolver, pfTestBar, []int64{1}, []int64{1000}, 100)
		foldAll(t, resolver, pfTestQux, []int64{1}, []int64{500}, 100)

		reward, err := resolver.claimTokenReward("alice", pfTestBar, 0)
		uassert.NoError(t, err)
		uassert.Equal(t, reward, int64(1000))

		reward, err = resolver.claimTokenReward("alice", pfTestBar, 0)
		uassert.NoError(t, err)
		uassert.Equal(t, reward, int64(0))

		rewards, err := resolver.claimRewards("alice", 100)
		uassert.NoError(t, err)
		uassert.Equal(t, rewards[pfTestBar], int64(0))
		uassert.Equal(t, rewards[pfTestQux], int64(500))
	})

	t.Run("a bounded settle pays what it settled and the rest later", func(cur realm, t *testing.T) {
		resolver := newPfTestManager()
		// alice alone: 100 (e1), 200 (e2), 300 (e3); fees 100, 200, 300 -> 1 per stake each epoch.
		uassert.NoError(t, resolver.addStake("alice", 100, 1))
		uassert.NoError(t, resolver.addStake("alice", 100, 2))
		uassert.NoError(t, resolver.addStake("alice", 100, 3))
		foldAll(t, resolver, pfTestBar, []int64{1, 2, 3}, []int64{100, 200, 300}, 100)

		// One event per call: the first call closes the epoch 1 segment only, since the
		// open segment is left alone until every event is settled.
		first, err := resolver.claimTokenReward("alice", pfTestBar, 1)
		uassert.NoError(t, err)
		uassert.Equal(t, first, int64(100))

		second, err := resolver.claimTokenReward("alice", pfTestBar, 1)
		uassert.NoError(t, err)
		uassert.Equal(t, second, int64(500))

		third, err := resolver.claimTokenReward("alice", pfTestBar, 1)
		uassert.NoError(t, err)
		uassert.Equal(t, third, int64(0))
	})

	t.Run("an event past the folded epoch waits for the fold", func(cur realm, t *testing.T) {
		resolver := newPfTestManager()
		uassert.NoError(t, resolver.addStake("alice", 100, 1))
		uassert.NoError(t, resolver.addStake("bob", 300, 2))
		uassert.NoError(t, resolver.removeStake("alice", 100, 3))

		// Only epoch 1 is folded, so alice's exit at epoch 3 cannot be settled yet and
		// nothing is paid for the still open window.
		uassert.NoError(t, resolver.applyAccrualBuckets(pfTestBar, []int64{1}, []int64{1000}, false, 100))
		reward, err := resolver.claimTokenReward("alice", pfTestBar, 0)
		uassert.NoError(t, err)
		uassert.Equal(t, reward, int64(0))

		foldAll(t, resolver, pfTestBar, []int64{2, 3}, []int64{800, 300}, 101)
		reward, err = resolver.claimTokenReward("alice", pfTestBar, 0)
		uassert.NoError(t, err)
		uassert.Equal(t, reward, int64(1200))
	})

	t.Run("a token that never collected a fee leaves no state behind", func(cur realm, t *testing.T) {
		resolver := newPfTestManager()
		uassert.NoError(t, resolver.addStake("alice", 100, 1))

		reward, err := resolver.claimTokenReward("alice", pfTestBar, 0)
		uassert.NoError(t, err)
		uassert.Equal(t, reward, int64(0))

		alice, _, _ := resolver.GetRewardState("alice")
		uassert.Equal(t, len(alice.GetTokenPaths()), 0)
	})

	t.Run("an unknown staker gets nothing", func(cur realm, t *testing.T) {
		resolver := newPfTestManager()
		reward, err := resolver.claimTokenReward("nobody", pfTestBar, 0)
		uassert.NoError(t, err)
		uassert.Equal(t, reward, int64(0))
	})
}

func TestProtocolFeeRewardManager_LateJoinerEarnsNothingBeforeJoining(cur realm, t *testing.T) {
	resolver := newPfTestManager()
	uassert.NoError(t, resolver.addStake("alice", 100, 1))
	foldAll(t, resolver, pfTestBar, []int64{1}, []int64{1000}, 10)

	uassert.NoError(t, resolver.addStake("bob", 100, 2))
	foldAll(t, resolver, pfTestBar, []int64{2}, []int64{1000}, 20)

	bobRewards, err := resolver.claimRewards("bob", 20)
	uassert.NoError(t, err)
	uassert.Equal(t, bobRewards[pfTestBar], int64(500))

	aliceRewards, err := resolver.claimRewards("alice", 20)
	uassert.NoError(t, err)
	uassert.Equal(t, aliceRewards[pfTestBar], int64(1500))
}

func TestProtocolFeeRewardManager_GetClaimableRewardAmount(cur realm, t *testing.T) {
	t.Run("projects pending buckets without folding them", func(cur realm, t *testing.T) {
		resolver := newPfTestManager()
		uassert.NoError(t, resolver.addStake("alice", 100, 1))
		uassert.NoError(t, resolver.addStake("bob", 300, 2))
		uassert.NoError(t, resolver.removeStake("alice", 100, 3))

		claimable, err := resolver.GetClaimableRewardAmount("alice", pfTestBar, []int64{1, 2, 3}, []int64{1000, 800, 300})
		uassert.NoError(t, err)
		uassert.Equal(t, claimable, int64(1200))
		uassert.Equal(t, len(resolver.GetTokenPaths()), 0)

		// Folding then claiming pays exactly what was projected.
		foldAll(t, resolver, pfTestBar, []int64{1, 2, 3}, []int64{1000, 800, 300}, 100)
		reward, err := resolver.claimTokenReward("alice", pfTestBar, 0)
		uassert.NoError(t, err)
		uassert.Equal(t, reward, claimable)
	})

	t.Run("combines folded history with pending buckets", func(cur realm, t *testing.T) {
		resolver := newPfTestManager()
		uassert.NoError(t, resolver.addStake("alice", 100, 1))
		foldAll(t, resolver, pfTestBar, []int64{1}, []int64{1000}, 10)
		uassert.NoError(t, resolver.addStake("bob", 100, 2))

		claimable, err := resolver.GetClaimableRewardAmount("alice", pfTestBar, []int64{2}, []int64{1000})
		uassert.NoError(t, err)
		uassert.Equal(t, claimable, int64(1500))

		claimable, err = resolver.GetClaimableRewardAmount("bob", pfTestBar, []int64{2}, []int64{1000})
		uassert.NoError(t, err)
		uassert.Equal(t, claimable, int64(500))
	})

	t.Run("unknown staker or token yields zero", func(cur realm, t *testing.T) {
		resolver := newPfTestManager()
		claimable, err := resolver.GetClaimableRewardAmount("nobody", pfTestBar, nil, nil)
		uassert.NoError(t, err)
		uassert.Equal(t, claimable, int64(0))

		uassert.NoError(t, resolver.addStake("alice", 100, 1))
		claimable, err = resolver.GetClaimableRewardAmount("alice", pfTestBar, nil, nil)
		uassert.NoError(t, err)
		uassert.Equal(t, claimable, int64(0))
	})
}

func TestProtocolFeeRewardManager_RemainderIsCarried(cur realm, t *testing.T) {
	resolver := newPfTestManager()
	uassert.NoError(t, resolver.addStake("alice", 3, 1))
	uassert.NoError(t, resolver.addStake("bob", 3, 2))

	// 10 over a stake of 6 is 5/3 per stake, which the X128 accumulator floors by a
	// hair. alice's share comes out just under 5, so 4 is paid and the fraction is
	// carried instead of being dropped.
	foldAll(t, resolver, pfTestBar, []int64{2}, []int64{10}, 10)
	first, err := resolver.claimTokenReward("alice", pfTestBar, 0)
	uassert.NoError(t, err)
	uassert.Equal(t, first, int64(4))

	alice, _, _ := resolver.GetRewardState("alice")
	tokenState, ok := alice.GetTokenState(pfTestBar)
	uassert.True(t, ok)
	carried := tokenState.GetEarnedX128()
	uassert.True(t, carried.Gt(u256.Zero().Sub(u256Lsh128(1), u256.NewUint(3))))
	uassert.True(t, carried.Lt(u256Lsh128(1)))

	// The carried fraction tops up the next payout.
	foldAll(t, resolver, pfTestBar, []int64{2}, []int64{10}, 11)
	second, err := resolver.claimTokenReward("alice", pfTestBar, 0)
	uassert.NoError(t, err)
	uassert.Equal(t, second, int64(5))
}

func TestProtocolFeeRewardManager_LargeAmountsDoNotOverflow(cur realm, t *testing.T) {
	resolver := newPfTestManager()
	uassert.NoError(t, resolver.addStake("alice", math.MaxInt64, 1))

	foldAll(t, resolver, pfTestBar, []int64{1}, []int64{math.MaxInt64}, 10)

	reward, err := resolver.claimTokenReward("alice", pfTestBar, 0)
	uassert.NoError(t, err)
	uassert.Equal(t, reward, int64(math.MaxInt64))
}

// x128 renders amount << 128 as a decimal string.
func x128(amount int64) string {
	return u256Lsh128(amount).ToString()
}
