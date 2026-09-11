package staker

import (
	"testing"

	u256 "gno.land/p/gnoswap/uint256"
	uassert "gno.land/p/nt/uassert/v0"

	sr "gno.land/r/gnoswap/staker"
)

// An incentive's reward amount only ever decreases, so a checkpoint owed more than the
// incentive holds can never be paid. It must be forfeited instead of pending forever, which
// would lock the position's re-staking and the incentive's refund with no way out.
func TestMarkIncentiveCollectedForfeitsUncoverableIncentive(cur realm, t *testing.T) {
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

	// A skip the incentive could still cover stays pending.
	instance.markIncentiveCollected(0, cur, target, incentiveId, 3, 0, "")
	uassert.True(t, position.HasPendingIncentiveId(incentiveId))
	uassert.Equal(t, int64(1), instance.uncollectedIncentiveCountOf(incentiveId))

	// A skip it can no longer cover is forfeited, releasing the checkpoint and the refund hold.
	instance.markIncentiveCollected(0, cur, target, incentiveId, 8, 3, "")
	uassert.False(t, position.HasPendingIncentiveId(incentiveId))
	uassert.Equal(t, int64(0), instance.uncollectedIncentiveCountOf(incentiveId))
	uassert.False(t, instance.HasUnstakedPosition(1))
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

	instance.markIncentiveCollected(0, cur, target, incentiveId, 10, 0, gnsPath)
	uassert.False(t, position.HasPendingIncentiveId(incentiveId))
	uassert.Equal(t, int64(0), instance.uncollectedIncentiveCountOf(incentiveId))

	// Not fully collected yet: the emission source is still owed.
	uassert.True(t, instance.HasUnstakedPosition(2))
}
