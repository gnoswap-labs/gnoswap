package staker

// Pins two properties of the reward accumulators: boundary ticks created by a
// stake are seeded, and raw rewards are subtracted modulo 2^256 so that a
// wrapped base cannot make a deposit permanently un-collectable.

import (
	"chain/runtime"
	"math"
	"testing"

	uassert "gno.land/p/nt/uassert/v0"
	ufmt "gno.land/p/nt/ufmt/v0"

	u256 "gno.land/p/gnoswap/uint256"
	sr "gno.land/r/gnoswap/staker"
)

// Shared by every deposit so the global accumulator advances predictably.
var stakeLiquidity = u256.NewUint(1000000000000000000)

const stakeOwner = address("gno1qyqszqgpqyqszqgpqyqszqgpqyqszqgp")

const (
	externalIncentiveAmount   = int64(100000000000)
	externalIncentiveDuration = int64(100000)
)

// Seeding rules: a new tick at or below the price takes the global
// accumulation, a new tick above it keeps zero, an existing tick is left alone.
func TestStakeSeedsNewBoundaryTickAtOrBelowCurrentTick(cur realm, t *testing.T) {
	canonical := Setup(cur, t)
	poolPath := test_gnousdc
	canonical.CreatePool(poolPath, 1, 0)

	// In range at tick 0, so the pool accumulates. Creates tick 0 and tick 10.
	mustStake(cur, t, canonical, 0, poolPath, 0, 10)
	canonical.NextBlock()
	canonical.NextBlock()

	pool := mustGetPool(t, poolPath)
	resolver := NewPoolResolver(pool)
	globalAcc, _ := resolver.globalRewardRatioAccumulationAt(canonical.CurrentTime())
	uassert.True(t, globalAcc.Gt(u256.Zero()), "global accumulation must have advanced")

	// Price is still tick 0: deposit 1 creates tick -5 below and tick 5 above,
	// deposit 2 reuses tick 0.
	mustStake(cur, t, canonical, 1, poolPath, -5, 5)
	mustStake(cur, t, canonical, 2, poolPath, 0, 20)

	now := canonical.CurrentTime()

	// At or below the current tick: seeded.
	seeded := NewTickResolver(resolver.GetOrNewTick(int32(-5))).CurrentOutsideAccumulation(now)
	uassert.Equal(t, globalAcc.ToString(), seeded.ToString(),
		"a boundary tick created at or below the current tick is seeded with the global accumulation")

	// Above the current tick: zero base, so below(tick) == global holds there too.
	above := pool.Ticks().Get(int32(5))
	uassert.NotEqual(t, nil, above, "upper boundary tick must exist")
	uassert.Equal(t, 0, above.OutsideAccumulation().Size(),
		"a boundary tick created above the current tick keeps the zero base")

	// Re-seeding a tick that already backs deposits would shift their raw reward.
	reused := pool.Ticks().Get(int32(0))
	uassert.Equal(t, 1, reused.OutsideAccumulation().Size(),
		"an existing boundary tick is never re-seeded")
}

// The reported orientation: staked above [0, 5) with a crossed tick 0 and a
// freshly created tick 5. The seed keeps the "above upper" base non-wrapped.
func TestOutOfRangeStakeAboveItsRangeHasGenuineRawBase(cur realm, t *testing.T) {
	canonical, victimId := buildOutOfRangeStakeState(cur, t)
	canonical.NextBlock()
	poolPath := test_gnousdc

	pool := mustGetPool(t, poolPath)
	resolver := NewPoolResolver(pool)
	now := canonical.CurrentTime()

	lowerOutside := NewTickResolver(resolver.GetOrNewTick(int32(0))).CurrentOutsideAccumulation(now)
	upperOutside := NewTickResolver(resolver.GetOrNewTick(int32(5))).CurrentOutsideAccumulation(now)

	uassert.True(t, lowerOutside.Gt(u256.Zero()), "lower boundary must have been crossed at least once")
	uassert.True(t, upperOutside.Gt(u256.Zero()), "upper boundary must have been seeded at stake time")
	uassert.True(t, upperOutside.Gt(lowerOutside),
		"the seeded upper base must dominate the crossed lower base, so raw does not wrap")

	deposit := getMockInstance().getDeposits().get(victimId)
	startRaw := resolver.CalculateRawRewardForPosition(now, resolver.CurrentTick(now), deposit)

	expected := u256.Zero().Sub(upperOutside, lowerOutside)
	uassert.Equal(t, expected.ToString(), startRaw.ToString(), "raw = out(upper) - out(lower)")
	uassert.True(t, startRaw.Lt(upperOutside), "raw base stays in the same order of magnitude as the accumulator")
}

// Direct regression for the reported denial of service: the deposit stays
// collectable once the price re-enters its range, and on every later attempt.
func TestCollectRewardSucceedsForOutOfRangeStakeThatReentersRange(cur realm, t *testing.T) {
	canonical, victimId := buildOutOfRangeStakeState(cur, t)
	canonical.NextBlock()
	poolPath := test_gnousdc

	pool := mustGetPool(t, poolPath)
	resolver := NewPoolResolver(pool)
	deposit := getMockInstance().getDeposits().get(victimId)

	startTime := canonical.CurrentTime()
	startRaw := resolver.CalculateRawRewardForPosition(startTime, resolver.CurrentTick(startTime), deposit)

	canonical.MoveTick(cur, t, poolPath, 2)
	for i := 0; i < 12; i++ {
		canonical.NextBlock()
	}

	endTime := canonical.CurrentTime()
	endRaw := resolver.CalculateRawRewardForPosition(endTime, resolver.CurrentTick(endTime), deposit)
	uassert.True(t, endRaw.Gt(startRaw), "raw reward increases while the deposit is in range")

	panicked, msg := collectPanics(victimId, canonical.CurrentTime())
	uassert.False(t, panicked, "reward calculation must not abort, got: "+msg)
	uassert.True(t, rewardOf(victimId, canonical.CurrentTime()) > 0, "the deposit must accrue a reward")

	for i := 0; i < 5; i++ {
		canonical.NextBlock()
	}
	panicked, msg = collectPanics(victimId, canonical.CurrentTime())
	uassert.False(t, panicked, "later attempts must keep working, got: "+msg)
}

// Mirror orientation: the lower boundary is created after the upper one, so the
// base is negative and wraps - as in Uniswap V3. The modular subtraction in
// rewardPerWarmup is what keeps that harmless.
func TestWrappedRawBaseIsHarmlessUnderModularSubtraction(cur realm, t *testing.T) {
	canonical := Setup(cur, t)
	poolPath := test_gnousdc
	canonical.CreatePool(poolPath, 1, 0)

	// Deposit 0 registers tick 0; deposit 1 keeps the accumulator moving.
	mustStake(cur, t, canonical, 0, poolPath, -10, 0)
	canonical.NextBlock()
	canonical.NextBlock()

	canonical.MoveTick(cur, t, poolPath, 5)
	canonical.NextBlock()
	mustStake(cur, t, canonical, 1, poolPath, -20, 20)
	canonical.NextBlock()
	canonical.NextBlock()

	// Drive the price below everything, crossing tick 0 downward on the way.
	canonical.MoveTick(cur, t, poolPath, -30)
	canonical.NextBlock()

	// Range [-5, 0): tick 0 has crossing history, tick -5 is created above the
	// price and keeps the zero base.
	const victimId = uint64(2)
	mustStake(cur, t, canonical, victimId, poolPath, -5, 0)
	canonical.NextBlock()

	pool := mustGetPool(t, poolPath)
	resolver := NewPoolResolver(pool)
	now := canonical.CurrentTime()

	lowerOutside := NewTickResolver(resolver.GetOrNewTick(int32(-5))).CurrentOutsideAccumulation(now)
	upperOutside := NewTickResolver(resolver.GetOrNewTick(int32(0))).CurrentOutsideAccumulation(now)
	uassert.True(t, lowerOutside.IsZero(), "a boundary created above the price keeps the zero base")
	uassert.True(t, upperOutside.Gt(u256.Zero()), "upper boundary must carry crossing history")

	deposit := getMockInstance().getDeposits().get(victimId)
	startRaw := resolver.CalculateRawRewardForPosition(now, resolver.CurrentTick(now), deposit)

	// 0 - upperOutside: negative, hence wrapped. Expected, not a defect.
	expected := u256.Zero().Sub(u256.Zero(), upperOutside)
	uassert.Equal(t, expected.ToString(), startRaw.ToString(), "the raw base legitimately wraps here")

	// Accrue past the wrap offset so endRaw < startRaw as plain integers.
	canonical.MoveTick(cur, t, poolPath, -3)
	for i := 0; i < 400; i++ {
		canonical.NextBlock()
	}

	endTime := canonical.CurrentTime()
	endRaw := resolver.CalculateRawRewardForPosition(endTime, resolver.CurrentTick(endTime), deposit)
	uassert.True(t, endRaw.Lt(startRaw), "the raw value has rolled over 2^256, which the borrow check used to reject")

	panicked, msg := collectPanics(victimId, canonical.CurrentTime())
	uassert.False(t, panicked, "a wrapped base must not abort the calculation, got: "+msg)
	uassert.True(t, rewardOf(victimId, canonical.CurrentTime()) > 0, "the deposit must still accrue a reward")
}

// Safety net: no deposit in a pool with out-of-range stakes and repeated tick
// crossings may end up un-collectable.
func TestEveryDepositInThePoolStaysCollectable(cur realm, t *testing.T) {
	canonical, victimId := buildOutOfRangeStakeState(cur, t)
	canonical.NextBlock()
	poolPath := test_gnousdc

	canonical.MoveTick(cur, t, poolPath, 2)
	for i := 0; i < 12; i++ {
		canonical.NextBlock()
	}

	for _, depositId := range []uint64{0, 1, victimId} {
		panicked, msg := collectPanics(depositId, canonical.CurrentTime())
		uassert.False(t, panicked, "deposit must stay collectable, got: "+msg)
	}
}

// The external-incentive path uses rewardPerWarmupX128, a second copy of the
// same raw-reward subtraction. A wrapped base must be equally harmless there,
// and must neither create nor destroy incentive tokens.
func TestWrappedRawBaseIsHarmlessOnTheExternalIncentivePath(cur realm, t *testing.T) {
	canonical := Setup(cur, t)
	poolPath := test_gnousdc
	canonical.CreatePool(poolPath, 1, 0)

	incentiveStart := canonical.CurrentTime()
	incentiveId := canonical.CreateExternalIncentive(
		poolPath,
		gnsPath,
		externalIncentiveAmount,
		incentiveStart,
		incentiveStart+externalIncentiveDuration,
		stakeOwner,
		runtime.ChainHeight(),
	)

	wrappedId, controlId := buildWrappedAndControlDeposits(cur, t, canonical, poolPath)

	pool := mustGetPool(t, poolPath)
	resolver := NewPoolResolver(pool)
	stakeTime := canonical.CurrentTime()
	wrapped := getMockInstance().getDeposits().get(wrappedId)
	control := getMockInstance().getDeposits().get(controlId)

	wrappedBase := resolver.CalculateRawRewardForPosition(stakeTime, resolver.CurrentTick(stakeTime), wrapped)
	controlBase := resolver.CalculateRawRewardForPosition(stakeTime, resolver.CurrentTick(stakeTime), control)
	uassert.True(t, controlBase.IsZero(), "the control deposit's boundaries are both fresh, so its base is zero")
	uassert.True(t, wrappedBase.Gt(controlBase),
		"the wrapped deposit must start from a rolled-over base, the control from a genuine one")

	// Both deposits enter range together and stay there for the same window.
	canonical.NextBlock()
	canonical.MoveTick(cur, t, poolPath, -3)
	for i := 0; i < 20; i++ {
		canonical.NextBlock()
	}

	panicked, msg := collectPanics(wrappedId, canonical.CurrentTime())
	uassert.False(t, panicked, "the external path must not abort on a wrapped base, got: "+msg)

	now := canonical.CurrentTime()
	wrappedExternal := externalRewardOf(wrappedId, incentiveId, now)
	controlExternal := externalRewardOf(controlId, incentiveId, now)
	uassert.True(t, wrappedExternal > 0, "the wrapped deposit must accrue an external reward")

	// Conservation, per deposit: identical liquidity, identical stake time and
	// identical in-range window must yield an identical share of the incentive.
	// Anything the wrap lost or invented would show up as a difference here.
	uassert.Equal(t, controlExternal, wrappedExternal,
		"a wrapped base must not change the deposit's share of the incentive")

	// Conservation, per pool: the incentive cannot owe more than it emitted.
	distributed := totalExternalDistributed(incentiveId, now)
	emitted := externalEmittedBetween(t, poolPath, incentiveId, incentiveStart, now)
	uassert.True(t, distributed > 0, "the incentive must have paid out something")
	uassert.True(t, distributed <= emitted,
		ufmt.Sprintf("distributed %d must not exceed emitted %d", distributed, emitted))
}

// Boundary ticks are removed once the last deposit referencing them unstakes,
// taking their OutsideAccumulation history with them. A stake that re-creates
// such a tick has to re-seed it, otherwise it inherits a stale zero base.
func TestBoundaryTickRemovedOnFinalUnstakeIsReseededOnReCreation(cur realm, t *testing.T) {
	canonical := Setup(cur, t)
	poolPath := test_gnousdc
	canonical.CreatePool(poolPath, 1, 0)

	// Deposit 0 keeps the accumulator moving and never touches ticks 0 or 10.
	mustStake(cur, t, canonical, 0, poolPath, -50, 50)

	// Deposit 1 owns ticks 0 and 10 exclusively.
	const boundaryOwnerId = uint64(1)
	mustStake(cur, t, canonical, boundaryOwnerId, poolPath, 0, 10)
	canonical.NextBlock()
	canonical.NextBlock()

	// Give tick 0 a crossing history in both directions.
	canonical.MoveTick(cur, t, poolPath, -5)
	canonical.NextBlock()
	canonical.MoveTick(cur, t, poolPath, 20)
	canonical.NextBlock()

	pool := mustGetPool(t, poolPath)
	resolver := NewPoolResolver(pool)
	crossed := NewTickResolver(resolver.GetOrNewTick(int32(0))).CurrentOutsideAccumulation(canonical.CurrentTime())
	uassert.True(t, crossed.Gt(u256.Zero()), "tick 0 must carry crossing history before the unstake")

	// The last deposit on ticks 0 and 10 leaves, so Ticks.SetTick prunes them.
	canonical.UnstakeToken(boundaryOwnerId)
	uassert.Equal(t, nil, pool.Ticks().Get(int32(0)), "tick 0 must be pruned once its gross liquidity reaches zero")
	uassert.Equal(t, nil, pool.Ticks().Get(int32(10)), "tick 10 must be pruned as well")

	// Let the global accumulation move on before the tick comes back.
	for i := 0; i < 5; i++ {
		canonical.NextBlock()
	}

	// Deposit 2 re-creates tick 0, now well below the current tick 20.
	const reCreatorId = uint64(2)
	mustStake(cur, t, canonical, reCreatorId, poolPath, 0, 30)

	now := canonical.CurrentTime()
	globalAcc, _ := resolver.globalRewardRatioAccumulationAt(now)
	reCreated := pool.Ticks().Get(int32(0))
	uassert.NotEqual(t, nil, reCreated, "tick 0 must exist again")
	uassert.Equal(t, 1, reCreated.OutsideAccumulation().Size(),
		"the re-created tick carries exactly the seed written by this stake, not the pruned history")
	uassert.Equal(t, globalAcc.ToString(),
		NewTickResolver(reCreated).CurrentOutsideAccumulation(now).ToString(),
		"the re-created tick is seeded with the accumulation current at re-creation")

	// [0, 30) contains tick 20, so the fresh in-range stake starts from exactly
	// zero: raw = global - out(0) - out(30) = global - global - 0.
	deposit := getMockInstance().getDeposits().get(reCreatorId)
	startRaw := resolver.CalculateRawRewardForPosition(now, resolver.CurrentTick(now), deposit)
	uassert.Equal(t, "0", startRaw.ToString(), "a fresh in-range stake starts from a zero raw base")

	for i := 0; i < 10; i++ {
		canonical.NextBlock()
	}

	for _, depositId := range []uint64{0, reCreatorId} {
		panicked, msg := collectPanics(depositId, canonical.CurrentTime())
		uassert.False(t, panicked, "deposit must stay collectable after the prune/re-create cycle, got: "+msg)
	}
	uassert.True(t, rewardOf(reCreatorId, canonical.CurrentTime()) > 0,
		"the deposit on the re-created boundary must accrue a reward")
}

// --- helpers -----------------------------------------------------------------

// buildWrappedAndControlDeposits stakes two deposits side by side, at the same
// timestamp and with the same liquidity, one starting from a wrapped raw base
// and one from a genuine zero base, and stops at the stake timestamp.
//
//	stake 3 [-10, 0]  registers tick 0
//	price   0  ->  5  keeps the accumulator moving
//	stake 4 [-20, 20] in range at tick 5
//	price   5  -> -30 crosses tick 0 downward, so out(0) > 0
//	stake 5 [-5, 0]   below its range; tick -5 is created above the price and
//	                  keeps the zero base, so raw = 0 - out(0) wraps
//	stake 6 [-8, -1]  below its range; both boundaries are created above the
//	                  price, so raw = 0 - 0 = 0
//
// Both enter range together at tick -3, so their rewards must match exactly.
func buildWrappedAndControlDeposits(
	cur realm,
	t *testing.T,
	canonical *canonicalRewardState,
	poolPath string,
) (wrappedId, controlId uint64) {
	t.Helper()

	mustStake(cur, t, canonical, 3, poolPath, -10, 0)
	canonical.NextBlock()
	canonical.NextBlock()

	canonical.MoveTick(cur, t, poolPath, 5)
	canonical.NextBlock()

	mustStake(cur, t, canonical, 4, poolPath, -20, 20)
	canonical.NextBlock()
	canonical.NextBlock()

	canonical.MoveTick(cur, t, poolPath, -30)
	canonical.NextBlock()

	wrappedId, controlId = uint64(5), uint64(6)
	mustStake(cur, t, canonical, wrappedId, poolPath, -5, 0)
	mustStake(cur, t, canonical, controlId, poolPath, -8, -1)

	return wrappedId, controlId
}

// buildOutOfRangeStakeState drives the pool into the state from the original
// report and returns the canonical harness plus the out-of-range deposit id.
//
// Timeline:
//
//	stake 0 [0, 10]  in range at tick 0
//	price   0  -> -1 : tick 0 crosses down, out(0) becomes positive
//	stake 1 [-5, 15] in range at tick -1, keeps the accumulator moving
//	price  -1  -> 20 : ticks 0, 10 and 15 cross up; tick 5 still does not exist
//	stake 2 [0, 5]   above its range, upper boundary created and seeded here
//
// It deliberately stops at the stake timestamp, because the seed is written in
// the same call as the stake and CalculateRawRewardForPosition resolves a
// deposit's base at its last collect time.
func buildOutOfRangeStakeState(cur realm, t *testing.T) (*canonicalRewardState, uint64) {
	t.Helper()

	canonical := Setup(cur, t)
	poolPath := test_gnousdc
	canonical.CreatePool(poolPath, 1, 0)

	mustStake(cur, t, canonical, 0, poolPath, 0, 10)
	canonical.NextBlock()
	canonical.NextBlock()

	canonical.MoveTick(cur, t, poolPath, -1)
	canonical.NextBlock()

	mustStake(cur, t, canonical, 1, poolPath, -5, 15)
	canonical.NextBlock()
	canonical.NextBlock()

	canonical.MoveTick(cur, t, poolPath, 20)
	canonical.NextBlock()

	const victimId = uint64(2)
	mustStake(cur, t, canonical, victimId, poolPath, 0, 5)

	return canonical, victimId
}

func mustStake(
	cur realm,
	t *testing.T,
	canonical *canonicalRewardState,
	positionId uint64,
	poolPath string,
	tickLower, tickUpper int32,
) {
	t.Helper()

	err := canonical.StakeToken(cur, positionId, poolPath, stakeOwner, tickLower, tickUpper, stakeLiquidity)
	if err != nil {
		t.Fatalf("stake %d failed: %s", positionId, err.Error())
	}
}

func mustGetPool(t *testing.T, poolPath string) *sr.Pool {
	t.Helper()

	pool, ok := getMockInstance().getPools().Get(poolPath)
	if !ok {
		t.Fatalf("pool not found: %s", poolPath)
	}
	return pool
}

// rewardOf returns the deposit's collectable internal reward.
func rewardOf(positionId uint64, currentTime int64) int64 {
	reward, err := getMockInstance().calculateCollectablePositionReward(currentTime, currentTime, positionId)
	if err != nil {
		panic(err)
	}
	return reward.Internal
}

// collectPanics runs the shared read-only reward calculation - the same code
// path CollectReward, UnStakeToken and the Collectable* getters use - and
// reports whether it aborted.
func collectPanics(positionId uint64, currentTime int64) (panicked bool, message string) {
	defer func() {
		r := recover()
		if r == nil {
			return
		}
		panicked = true
		if err, ok := r.(error); ok {
			message = err.Error()
			return
		}
		if str, ok := r.(string); ok {
			message = str
			return
		}
		message = "unknown panic"
	}()

	_, err := getMockInstance().calculateCollectablePositionReward(currentTime, currentTime, positionId)
	if err != nil {
		return true, err.Error()
	}
	return false, ""
}

// externalRewardOf returns the deposit's collectable reward for one incentive.
func externalRewardOf(positionId uint64, incentiveId string, currentTime int64) int64 {
	reward, err := getMockInstance().calculateCollectablePositionReward(currentTime, currentTime, positionId)
	if err != nil {
		panic(err)
	}
	return reward.External[incentiveId]
}

// totalExternalDistributed sums what the incentive currently owes every staked
// deposit, rewards and warmup penalties alike.
func totalExternalDistributed(incentiveId string, currentTime int64) int64 {
	total := int64(0)
	getMockInstance().getDeposits().Iterate(0, math.MaxUint64, func(positionId uint64, _ *sr.Deposit) bool {
		reward, err := getMockInstance().calculateCollectablePositionReward(currentTime, currentTime, positionId)
		if err != nil {
			panic(err)
		}
		total += reward.External[incentiveId] + reward.ExternalPenalty[incentiveId]
		return false
	})
	return total
}

// externalEmittedBetween returns the incentive's total emission over the window,
// which is the ceiling for everything the pool can hand out.
func externalEmittedBetween(t *testing.T, poolPath, incentiveId string, from, to int64) int64 {
	t.Helper()

	pool := mustGetPool(t, poolPath)
	incentive, ok := NewPoolResolver(pool).IncentivesResolver().Get(incentiveId)
	if !ok {
		t.Fatalf("incentive not found: %s", incentiveId)
	}
	return rewardPerSecondFromX128(incentive) * (to - from)
}
