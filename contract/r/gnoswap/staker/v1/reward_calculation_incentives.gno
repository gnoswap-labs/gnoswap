package staker

import (
	"gno.land/p/gnoswap/gnsmath"
	u256 "gno.land/p/gnoswap/uint256"
	bptree "gno.land/p/nt/bptree/v0"

	sr "gno.land/r/gnoswap/staker"
)

type IncentivesResolver struct {
	*sr.Incentives
}

func NewIncentivesResolver(incentives *sr.Incentives) *IncentivesResolver {
	return &IncentivesResolver{
		Incentives: incentives,
	}
}

// Get incentive by incentiveId
func (self *IncentivesResolver) Get(incentiveId string) (*sr.ExternalIncentive, bool) {
	return retrieveIncentive(self.IncentiveTrees(), incentiveId)
}

func (self *IncentivesResolver) GetIncentiveResolver(incentiveId string) (*ExternalIncentiveResolver, bool) {
	if incentive, ok := self.Get(incentiveId); ok {
		return NewExternalIncentiveResolver(incentive), true
	}
	return nil, false
}

func retrieveIncentive(tree *bptree.BPTree, id string) (*sr.ExternalIncentive, bool) {
	value := tree.Get(id)
	if value == nil {
		return nil, false
	}
	v, ok := value.(*sr.ExternalIncentive)
	if !ok {
		panic("failed to cast value to *sr.ExternalIncentive")
	}
	return v, true
}

// Create a new external incentive
// Panics if the incentive already exists.
func (self *IncentivesResolver) create(incentive *sr.ExternalIncentive) {
	self.Incentives.SetIncentive(incentive.IncentiveId(), incentive)
	self.Incentives.AddIncentiveByStartTime(incentive.StartTimestamp(), incentive.IncentiveId())
}

// update updates an existing incentive with new information
func (self *IncentivesResolver) update(incentive *sr.ExternalIncentive) {
	self.Incentives.SetIncentive(incentive.IncentiveId(), incentive)
}

// remove drops an incentive from both the incentive tree and the start-time
// discovery index. It is only valid for an incentive that has not started: no
// deposit can reference it yet, so nothing is left pointing at a missing record.
func (self *IncentivesResolver) remove(incentive *sr.ExternalIncentive) {
	self.Incentives.RemoveIncentive(incentive.IncentiveId())
	self.Incentives.RemoveIncentiveByStartTime(incentive.StartTimestamp(), incentive.IncentiveId())
}

// starts incentive unclaimable period for this pool
func (self *IncentivesResolver) startUnclaimablePeriod(startTimestamp int64) {
	self.Incentives.SetUnclaimablePeriod(startTimestamp, int64(0))
}

// ends incentive unclaimable period for this pool
// ignores if currently not in unclaimable period
func (self *IncentivesResolver) endUnclaimablePeriod(endTimestamp int64) {
	startTimestamp := int64(0)
	self.UnclaimablePeriods().ReverseIterate(0, endTimestamp, func(key int64, value any) bool {
		v, ok := value.(int64)
		if !ok {
			panic("failed to cast value to int64")
		}
		if v != 0 {
			// Already ended, no need to update
			// keeping startTimestamp as 0 to indicate this
			return true
		}
		startTimestamp = key
		return true
	})

	if startTimestamp == 0 {
		// No ongoing unclaimable period found
		return
	}

	if startTimestamp == endTimestamp {
		self.Incentives.RemoveUnclaimablePeriod(startTimestamp)
	} else {
		self.Incentives.SetUnclaimablePeriod(startTimestamp, endTimestamp)
	}

	// Accumulate the just-closed period into every active incentive
	self.accumulateUnclaimableSeconds(startTimestamp, endTimestamp)
}

// accumulateUnclaimableSeconds adds the unclaimable duration between
// startTimestamp and endTimestamp to every non-refunded incentive whose window
// overlaps the period. The accumulator is updated in place on the stored
// incentive pointers, so no tree write is required here.
func (self *IncentivesResolver) accumulateUnclaimableSeconds(startTimestamp, endTimestamp int64) {
	self.Incentives.IterateIncentives(func(_ string, incentive *sr.ExternalIncentive) bool {
		if incentive.Refunded() {
			return false
		}

		duration := calculateUnClaimableDuration(
			startTimestamp,
			endTimestamp,
			incentive.StartTimestamp(),
			incentive.EndTimestamp(),
		)
		if duration > 0 {
			incentive.SetUnclaimableSeconds(gnsmath.SafeAddInt64(incentive.UnclaimableSeconds(), duration))
		}
		return false
	})
}

// calculate unclaimable reward from the per-incentive unclaimable seconds
// accumulator instead of scanning the unbounded unclaimable periods tree.
func (self *IncentivesResolver) calculateUnclaimableReward(incentiveId string) int64 {
	incentive, ok := self.Get(incentiveId)
	if !ok {
		return 0
	}

	// The accumulator holds the duration of every closed unclaimable period
	// that overlaps the incentive window.
	timeDiff := incentive.UnclaimableSeconds()

	// Ongoing unclaimable periods (end == 0) are not yet accumulated because
	// their end is unknown. They are resolved here by treating them as
	// extending to the incentive end. Unclaimable periods never overlap and
	// are recorded in ascending order, so an ongoing period is always the
	// most recently started one and therefore the highest key in the tree.
	// ReverseIterate visits the highest key first, so each scan below finds
	// the only ongoing period that can affect the reward (if any) on its
	// first visit and stops - the scan is bounded regardless of how many
	// periods exist in the tree.
	//
	// Tail 1: the ongoing period that started before the incentive window
	// (e.g. the initial pool-creation period). If the highest period starting
	// before the window is already closed, no ongoing period can overlap the
	// incentive start and there is nothing to add.
	self.UnclaimablePeriods().ReverseIterate(0, incentive.StartTimestamp()-1, func(startTimestamp int64, value any) bool {
		endTimestamp, ok := value.(int64)
		if !ok {
			panic("failed to cast value to int64")
		}
		if endTimestamp != 0 {
			// Already closed - the duration is already accumulated in
			// UnclaimableSeconds(), and being the highest key it is also the
			// latest period, so no ongoing period can exist below it.
			return true
		}

		timeDiff = gnsmath.SafeAddInt64(timeDiff, calculateUnClaimableDuration(
			startTimestamp,
			incentive.EndTimestamp(),
			incentive.StartTimestamp(),
			incentive.EndTimestamp(),
		))
		return true
	})

	// Tail 2: the ongoing period that started within the incentive window.
	// The upper bound is endTime-1 to mirror the Iterate(start, end)
	// half-open range, which excludes a period starting exactly at endTime
	// (e.g. the initial pool-creation period that coincides with endTime).
	self.UnclaimablePeriods().ReverseIterate(incentive.StartTimestamp(), incentive.EndTimestamp()-1, func(startTimestamp int64, value any) bool {
		endTimestamp, ok := value.(int64)
		if !ok {
			panic("failed to cast value to int64")
		}
		if endTimestamp != 0 {
			// Already closed - the duration is already accumulated in
			// UnclaimableSeconds(), and being the highest key it is also the
			// latest period, so no ongoing period can exist below it.
			return true
		}

		timeDiff = gnsmath.SafeAddInt64(timeDiff, calculateUnClaimableDuration(
			startTimestamp,
			incentive.EndTimestamp(),
			incentive.StartTimestamp(),
			incentive.EndTimestamp(),
		))
		return true
	})

	// rewardPerSecondX128 = rps << 128, so dividing by q128 here recovers the
	// floor of (timeDiff * rps) without the truncation that an int64 rps would
	// have introduced at incentive-creation time.
	unclaimable := u256.MulDiv(
		u256.NewUintFromInt64(timeDiff),
		incentive.RewardPerSecondX128(),
		q128,
	)
	return gnsmath.SafeConvertToInt64(unclaimable)
}

// calculateUnClaimableDuration calculates the duration of overlap between an unclaimable period and incentive period
func calculateUnClaimableDuration(unclaimableStart, unclaimableEnd, incentiveStartTimestamp, incentiveEndTimestamp int64) int64 {
	// Use later timestamp between unclaimable start and incentive start
	startTime := unclaimableStart
	if startTime < incentiveStartTimestamp {
		startTime = incentiveStartTimestamp
	}

	// Use earlier timestamp between unclaimable end and incentive end
	endTime := unclaimableEnd
	if endTime > incentiveEndTimestamp {
		endTime = incentiveEndTimestamp
	}

	// Return 0 if no overlap
	if endTime < startTime {
		return 0
	}

	// Calculate overlap duration
	return gnsmath.SafeSubInt64(endTime, startTime)
}
