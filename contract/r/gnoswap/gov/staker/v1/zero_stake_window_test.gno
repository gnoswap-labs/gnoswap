package staker

import (
	"math"
	"testing"

	uassert "gno.land/p/nt/uassert/v0"

	"gno.land/r/gnoswap/gov/staker"
)

const (
	zeroStakeTestToken      = "gno.land/r/onbloc/bar.BAR"
	zeroStakeTestOtherToken = "gno.land/r/onbloc/qux.QUX"
)

// TestEmissionRewardManager_ZeroStakeWindow_DiscardsDelta pins the discard policy:
// a window with no stake has nobody to credit, so its delta is dropped and the cursor
// advances past it instead of being handed to whoever stakes next.
func TestEmissionRewardManager_ZeroStakeWindow_DiscardsDelta(cur realm, t *testing.T) {
	// Given: a fresh manager with nothing staked
	manager := staker.NewEmissionRewardManager()
	resolver := NewEmissionRewardManagerResolver(manager)

	// When: 1000 is distributed while totalStakedAmount is 0
	err := resolver.updateAccumulatedRewardX128PerStake(1000, 10)
	uassert.NoError(t, err)

	// Then: the cursor moved past the window and no reward per stake was recorded
	uassert.Equal(t, resolver.GetDistributedAmount(), int64(1000))
	uassert.Equal(t, resolver.GetAccumulatedTimestamp(), int64(10))
	uassert.Equal(t, resolver.GetAccumulatedRewardX128PerStake().ToString(), "0")

	// When: the first staker arrives and another 500 is distributed
	uassert.NoError(t, resolver.addStake("alice", 100, 10))
	uassert.NoError(t, resolver.updateAccumulatedRewardX128PerStake(1500, 20))

	// Then: alice only earns the post-stake delta, not the discarded window
	claimable, err := resolver.GetClaimableRewardAmount(1500, "alice", 20)
	uassert.NoError(t, err)
	uassert.Equal(t, claimable, int64(500))
}

// TestEmissionRewardManager_ZeroStakeWindow_AfterFullUnstake covers the window that opens
// when every staker leaves and later stakers arrive.
func TestEmissionRewardManager_ZeroStakeWindow_AfterFullUnstake(cur realm, t *testing.T) {
	// Given: alice is the only staker and earns 1000
	manager := staker.NewEmissionRewardManager()
	resolver := NewEmissionRewardManagerResolver(manager)

	uassert.NoError(t, resolver.addStake("alice", 100, 0))
	uassert.NoError(t, resolver.updateAccumulatedRewardX128PerStake(1000, 10))

	// When: alice unstakes completely and 4000 accrues with nothing staked
	uassert.NoError(t, resolver.removeStake("alice", 100, 10))
	uassert.Equal(t, resolver.GetTotalStakedAmount(), int64(0))

	uassert.NoError(t, resolver.updateAccumulatedRewardX128PerStake(5000, 20))

	// Then: the 4000 is discarded, cursor advanced, accumulator untouched
	uassert.Equal(t, resolver.GetDistributedAmount(), int64(5000))
	accumulatedAfterWindow := resolver.GetAccumulatedRewardX128PerStake().ToString()

	// When: bob stakes and another 1000 is distributed
	uassert.NoError(t, resolver.addStake("bob", 100, 20))
	uassert.NoError(t, resolver.updateAccumulatedRewardX128PerStake(6000, 30))

	// Then: bob earns only the post-stake delta
	bobClaimable, err := resolver.GetClaimableRewardAmount(6000, "bob", 30)
	uassert.NoError(t, err)
	uassert.Equal(t, bobClaimable, int64(1000))

	// And: alice keeps the entitlement she accrued before the window
	aliceClaimable, err := resolver.GetClaimableRewardAmount(6000, "alice", 30)
	uassert.NoError(t, err)
	uassert.Equal(t, aliceClaimable, int64(1000))

	// And: the discarded window never reappeared in the accumulator
	uassert.NotEqual(t, resolver.GetAccumulatedRewardX128PerStake().ToString(), accumulatedAfterWindow)
	claimed, err := resolver.claimRewards("alice", 40)
	uassert.NoError(t, err)
	uassert.Equal(t, claimed, int64(1000))
}

// TestEmissionRewardManager_ZeroStakeWindow_EdgeCases covers the boundaries around the
// discard policy: the timestamp guard still wins, and degenerate deltas are safe.
func TestEmissionRewardManager_ZeroStakeWindow_EdgeCases(cur realm, t *testing.T) {
	t.Run("out-of-order timestamp does not advance the cursor", func(cur realm, t *testing.T) {
		manager := staker.NewEmissionRewardManager()
		resolver := NewEmissionRewardManagerResolver(manager)
		resolver.SetAccumulatedTimestamp(100)
		resolver.SetDistributedAmount(500)

		uassert.NoError(t, resolver.updateAccumulatedRewardX128PerStake(1000, 50))

		uassert.Equal(t, resolver.GetDistributedAmount(), int64(500))
		uassert.Equal(t, resolver.GetAccumulatedTimestamp(), int64(100))
	})

	t.Run("same timestamp still advances the cursor", func(cur realm, t *testing.T) {
		manager := staker.NewEmissionRewardManager()
		resolver := NewEmissionRewardManagerResolver(manager)
		resolver.SetAccumulatedTimestamp(100)
		resolver.SetDistributedAmount(500)

		uassert.NoError(t, resolver.updateAccumulatedRewardX128PerStake(1000, 100))

		uassert.Equal(t, resolver.GetDistributedAmount(), int64(1000))
		uassert.Equal(t, resolver.GetAccumulatedRewardX128PerStake().ToString(), "0")
	})

	t.Run("zero delta over a zero stake window is a safe no-op", func(cur realm, t *testing.T) {
		manager := staker.NewEmissionRewardManager()
		resolver := NewEmissionRewardManagerResolver(manager)
		resolver.SetDistributedAmount(700)

		uassert.NoError(t, resolver.updateAccumulatedRewardX128PerStake(700, 10))

		uassert.Equal(t, resolver.GetDistributedAmount(), int64(700))
		uassert.Equal(t, resolver.GetAccumulatedTimestamp(), int64(10))
		uassert.Equal(t, resolver.GetAccumulatedRewardX128PerStake().ToString(), "0")
	})

	t.Run("max int64 delta over a zero stake window does not overflow", func(cur realm, t *testing.T) {
		manager := staker.NewEmissionRewardManager()
		resolver := NewEmissionRewardManagerResolver(manager)

		uassert.NoError(t, resolver.updateAccumulatedRewardX128PerStake(math.MaxInt64, 10))

		uassert.Equal(t, resolver.GetDistributedAmount(), int64(math.MaxInt64))
		uassert.Equal(t, resolver.GetAccumulatedRewardX128PerStake().ToString(), "0")

		// The next staker inherits nothing from that window.
		uassert.NoError(t, resolver.addStake("alice", 100, 10))
		claimable, err := resolver.GetClaimableRewardAmount(math.MaxInt64, "alice", 20)
		uassert.NoError(t, err)
		uassert.Equal(t, claimable, int64(0))
	})

	t.Run("stake added and removed within one timestamp leaves no residue", func(cur realm, t *testing.T) {
		manager := staker.NewEmissionRewardManager()
		resolver := NewEmissionRewardManagerResolver(manager)

		uassert.NoError(t, resolver.addStake("alice", 100, 10))
		uassert.NoError(t, resolver.removeStake("alice", 100, 10))
		uassert.Equal(t, resolver.GetTotalStakedAmount(), int64(0))

		uassert.NoError(t, resolver.updateAccumulatedRewardX128PerStake(1000, 20))

		claimable, err := resolver.GetClaimableRewardAmount(1000, "alice", 20)
		uassert.NoError(t, err)
		uassert.Equal(t, claimable, int64(0))
	})
}

// TestProtocolFeeRewardManager_ZeroStakeWindow_DiscardsDelta pins the same policy on the
// protocol fee accumulator, for both the all-token and the single-token update paths.
func TestProtocolFeeRewardManager_ZeroStakeWindow_DiscardsDelta(cur realm, t *testing.T) {
	t.Run("all-token update discards and advances", func(cur realm, t *testing.T) {
		manager := staker.NewProtocolFeeRewardManager()
		resolver := NewProtocolFeeRewardManagerResolver(manager)

		err := resolver.updateAccumulatedProtocolFeeX128PerStake(
			map[string]int64{zeroStakeTestToken: 5000},
			10,
		)
		uassert.NoError(t, err)

		uassert.Equal(t, resolver.GetProtocolFeeAmount(zeroStakeTestToken), int64(5000))
		uassert.Equal(t, resolver.GetAccumulatedProtocolFeeX128PerStake(zeroStakeTestToken).ToString(), "0")

		// The first staker only earns fees collected after it staked.
		uassert.NoError(t, resolver.addStake("alice", 100, 10))
		err = resolver.updateAccumulatedProtocolFeeX128PerStake(
			map[string]int64{zeroStakeTestToken: 6000},
			20,
		)
		uassert.NoError(t, err)

		claimable, err := resolver.GetClaimableRewardAmounts(map[string]int64{}, "alice", 20)
		uassert.NoError(t, err)
		uassert.Equal(t, claimable[zeroStakeTestToken], int64(1000))
	})

	t.Run("single-token update discards and advances", func(cur realm, t *testing.T) {
		manager := staker.NewProtocolFeeRewardManager()
		resolver := NewProtocolFeeRewardManagerResolver(manager)

		err := resolver.updateAccumulatedProtocolFeeX128PerStakeForToken(zeroStakeTestToken, 5000, 10)
		uassert.NoError(t, err)

		uassert.Equal(t, resolver.GetProtocolFeeAmount(zeroStakeTestToken), int64(5000))
		uassert.Equal(t, resolver.GetAccumulatedProtocolFeeX128PerStake(zeroStakeTestToken).ToString(), "0")

		uassert.NoError(t, resolver.addStake("alice", 100, 10))
		uassert.NoError(t, resolver.updateAccumulatedProtocolFeeX128PerStakeForToken(zeroStakeTestToken, 6000, 20))

		claimable, err := resolver.GetClaimableRewardAmounts(map[string]int64{}, "alice", 20)
		uassert.NoError(t, err)
		uassert.Equal(t, claimable[zeroStakeTestToken], int64(1000))
	})

	t.Run("only the token that saw fees during the window is discarded", func(cur realm, t *testing.T) {
		manager := staker.NewProtocolFeeRewardManager()
		resolver := NewProtocolFeeRewardManagerResolver(manager)

		// bar collects while nothing is staked, qux only collects afterwards.
		err := resolver.updateAccumulatedProtocolFeeX128PerStake(
			map[string]int64{zeroStakeTestToken: 5000},
			10,
		)
		uassert.NoError(t, err)

		uassert.NoError(t, resolver.addStake("alice", 100, 10))
		err = resolver.updateAccumulatedProtocolFeeX128PerStake(
			map[string]int64{zeroStakeTestOtherToken: 2000},
			20,
		)
		uassert.NoError(t, err)

		claimable, err := resolver.GetClaimableRewardAmounts(map[string]int64{}, "alice", 20)
		uassert.NoError(t, err)
		uassert.Equal(t, claimable[zeroStakeTestToken], int64(0))
		uassert.Equal(t, claimable[zeroStakeTestOtherToken], int64(2000))
	})
}

// TestRewardAccumulators_ZeroStakeWindowPolicyParity is the regression guard for the
// original defect: the two accumulators must agree on what a zero stake window means.
func TestRewardAccumulators_ZeroStakeWindowPolicyParity(cur realm, t *testing.T) {
	const (
		windowAmount    = int64(5000)
		postStakeAmount = int64(1000)
		stakeAmount     = int64(100)
	)

	emissionResolver := NewEmissionRewardManagerResolver(staker.NewEmissionRewardManager())
	feeResolver := NewProtocolFeeRewardManagerResolver(staker.NewProtocolFeeRewardManager())

	// Both see the same window with nothing staked.
	uassert.NoError(t, emissionResolver.updateAccumulatedRewardX128PerStake(windowAmount, 10))
	uassert.NoError(t, feeResolver.updateAccumulatedProtocolFeeX128PerStake(
		map[string]int64{zeroStakeTestToken: windowAmount},
		10,
	))

	// Both advanced their cursor past the window without crediting anyone.
	uassert.Equal(t, emissionResolver.GetDistributedAmount(), windowAmount)
	uassert.Equal(t, feeResolver.GetProtocolFeeAmount(zeroStakeTestToken), windowAmount)
	uassert.Equal(t, emissionResolver.GetAccumulatedRewardX128PerStake().ToString(), "0")
	uassert.Equal(t, feeResolver.GetAccumulatedProtocolFeeX128PerStake(zeroStakeTestToken).ToString(), "0")

	// Both then credit the first staker with the post-stake delta only.
	uassert.NoError(t, emissionResolver.addStake("alice", stakeAmount, 10))
	uassert.NoError(t, feeResolver.addStake("alice", stakeAmount, 10))

	uassert.NoError(t, emissionResolver.updateAccumulatedRewardX128PerStake(windowAmount+postStakeAmount, 20))
	uassert.NoError(t, feeResolver.updateAccumulatedProtocolFeeX128PerStake(
		map[string]int64{zeroStakeTestToken: windowAmount + postStakeAmount},
		20,
	))

	emissionClaimable, err := emissionResolver.GetClaimableRewardAmount(windowAmount+postStakeAmount, "alice", 20)
	uassert.NoError(t, err)
	feeClaimable, err := feeResolver.GetClaimableRewardAmounts(map[string]int64{}, "alice", 20)
	uassert.NoError(t, err)

	uassert.Equal(t, emissionClaimable, postStakeAmount)
	uassert.Equal(t, feeClaimable[zeroStakeTestToken], postStakeAmount)
	uassert.Equal(t, emissionClaimable, feeClaimable[zeroStakeTestToken])
}
