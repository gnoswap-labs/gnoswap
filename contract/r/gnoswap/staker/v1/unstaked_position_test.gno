package staker

import (
	"testing"

	u256 "gno.land/p/gnoswap/uint256/v1"
	uassert "gno.land/p/nt/uassert/v0"

	sr "gno.land/r/gnoswap/staker"
)

// An incentive's reward amount only ever decreases, so a checkpoint owed more than the
// incentive holds can never be paid. It must be forfeited instead of pending forever, which
// would lock the position's re-staking and the incentive's refund with no way out.
func TestMarkIncentiveCollectedFollowsDeliveryOutcome(cur realm, t *testing.T) {
	initStakerTest(cur, t)
	instance := getMockInstance()

	const incentiveId = "creator:1:1"

	deposit := sr.NewDeposit(addr01, "pool", u256.Zero(), 0, 0, 0, nil)
	position := sr.NewUnstakedPosition(deposit, 100, 0, nil, nil, "0", "0", 0, 0, 0, 0, []string{incentiveId})
	position.MarkEmissionCollected()

	instance.getUnstakedPositions().set(1, position)
	instance.addUncollectedIncentiveCount(incentiveId, 1)

	incentive := sr.NewExternalIncentive(incentiveId, "pool", gnsPath, 5, 0, 1000, addr01, 0, 0, 0)
	instance.getExternalIncentives().set(incentiveId, incentive)

	target := &collectTarget{positionId: 1, deposit: deposit, currentTime: 100, checkpoint: position}

	testing.SetRealm(testing.NewCodeRealm("gno.land/r/gnoswap/staker"))

	// A deferral stays pending.
	instance.markIncentiveCollected(0, cur, target, incentiveId, 3, 0, externalDeliveryDeferred)
	uassert.True(t, position.HasPendingIncentiveId(incentiveId))
	uassert.Equal(t, int64(1), instance.uncollectedIncentiveCountOf(incentiveId))

	// A debt that can never be paid is forfeited, releasing the checkpoint and the refund hold.
	instance.markIncentiveCollected(0, cur, target, incentiveId, 8, 3, externalDeliveryUnpayable)
	uassert.False(t, position.HasPendingIncentiveId(incentiveId))
	uassert.Equal(t, int64(0), instance.uncollectedIncentiveCountOf(incentiveId))
	uassert.False(t, instance.HasUnstakedPosition(1))
}

// A source whose cursor already sits at the window's close is settled, whichever call moved it.
func TestMarkIncentiveCollectedSettlesAlreadyDelivered(cur realm, t *testing.T) {
	initStakerTest(cur, t)
	instance := getMockInstance()

	const incentiveId = "creator:1:3"

	deposit := sr.NewDeposit(addr01, "pool", u256.Zero(), 0, 0, 0, nil)
	position := sr.NewUnstakedPosition(deposit, 100, 0, nil, nil, "0", "0", 0, 0, 0, 0, []string{incentiveId})
	position.MarkEmissionCollected()

	instance.getUnstakedPositions().set(3, position)
	instance.addUncollectedIncentiveCount(incentiveId, 1)

	target := &collectTarget{positionId: 3, deposit: deposit, currentTime: 100, checkpoint: position}

	testing.SetRealm(testing.NewCodeRealm("gno.land/r/gnoswap/staker"))
	instance.markIncentiveCollected(0, cur, target, incentiveId, 3, 0, externalDeliveryAlreadyDelivered)
	uassert.False(t, position.HasPendingIncentiveId(incentiveId))
	uassert.Equal(t, int64(0), instance.uncollectedIncentiveCountOf(incentiveId))
	uassert.False(t, instance.HasUnstakedPosition(3))

	// Marking again is a no-op: the count must not go negative and the emission mark is idempotent.
	instance.markIncentiveCollected(0, cur, target, incentiveId, 3, 0, externalDeliveryPaid)
	instance.markEmissionCollected(0, cur, target)
	uassert.Equal(t, int64(0), instance.uncollectedIncentiveCountOf(incentiveId))
}

// A delivered incentive clears its pending entry and count.
func TestMarkIncentiveCollectedOnDelivery(cur realm, t *testing.T) {
	initStakerTest(cur, t)
	instance := getMockInstance()

	const incentiveId = "creator:1:2"

	deposit := sr.NewDeposit(addr01, "pool", u256.Zero(), 0, 0, 0, nil)
	position := sr.NewUnstakedPosition(deposit, 100, 0, nil, nil, "0", "0", 0, 0, 0, 0, []string{incentiveId})

	instance.getUnstakedPositions().set(2, position)
	instance.addUncollectedIncentiveCount(incentiveId, 1)

	target := &collectTarget{positionId: 2, deposit: deposit, currentTime: 100, checkpoint: position}

	testing.SetRealm(testing.NewCodeRealm("gno.land/r/gnoswap/staker"))
	instance.markIncentiveCollected(0, cur, target, incentiveId, 10, 0, externalDeliveryPaid)
	uassert.False(t, position.HasPendingIncentiveId(incentiveId))
	uassert.Equal(t, int64(0), instance.uncollectedIncentiveCountOf(incentiveId))

	// Not fully collected yet: the emission source is still owed.
	uassert.True(t, instance.HasUnstakedPosition(2))
}
