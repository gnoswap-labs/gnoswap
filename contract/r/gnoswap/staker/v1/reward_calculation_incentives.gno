package v1

import (
	"gno.land/p/nt/avl"

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

// Get incentive by incentiveId (checks both active and archived)
func (self *IncentivesResolver) Get(incentiveId string) (*sr.ExternalIncentive, bool) {
	// First check active incentives
	if incentive, ok := retrieveIncentive(self.IncentiveTrees(), incentiveId); ok {
		return incentive, true
	}
	return retrieveIncentive(self.ArchivedIncentives(), incentiveId)
}

func (self *IncentivesResolver) GetIncentiveResolver(incentiveId string) (*ExternalIncentiveResolver, bool) {
	if incentive, ok := self.Get(incentiveId); ok {
		return NewExternalIncentiveResolver(incentive), true
	}
	return nil, false
}

func (self *IncentivesResolver) IsArchived(incentiveId string) bool {
	_, exists := self.ArchivedIncentives().Get(incentiveId)
	return exists
}

func retrieveIncentive(tree *avl.Tree, id string) (*sr.ExternalIncentive, bool) {
	value, ok := tree.Get(id)
	if !ok {
		return nil, false
	}
	v, ok := value.(*sr.ExternalIncentive)
	if !ok {
		panic("failed to cast value to *sr.ExternalIncentive")
	}
	return v, true
}

// Get all incentives that is active in given [startTimestamp, endTimestamp)
func (self *IncentivesResolver) GetAllInTimestamps(startTimestamp, endTimestamp int64) map[string]*sr.ExternalIncentive {
	incentives := make(map[string]*sr.ExternalIncentive)

	// Only iterate active incentives (not archived)
	self.IncentiveTrees().Iterate("", "", func(_ string, value any) bool {
		incentive, ok := value.(*sr.ExternalIncentive)
		if !ok {
			return false
		}

		// incentive is not active
		if incentive.StartTimestamp() > endTimestamp || incentive.EndTimestamp() < startTimestamp {
			return false
		}

		incentives[incentive.IncentiveId()] = incentive

		return false
	})

	return incentives
}

// Create a new external incentive
// Panics if the incentive already exists.
func (self *IncentivesResolver) create(
	creator address,
	incentive *sr.ExternalIncentive,
) {
	self.IncentiveTrees().Set(incentive.IncentiveId(), incentive)
}

// update updates an existing incentive with new information
func (self *IncentivesResolver) update(
	creator address,
	incentive *sr.ExternalIncentive,
) {
	self.IncentiveTrees().Set(incentive.IncentiveId(), incentive)
}

// starts incentive unclaimable period for this pool
func (self *IncentivesResolver) startUnclaimablePeriod(startTimestamp int64) {
	self.UnclaimablePeriods().Set(startTimestamp, int64(0))
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
		self.UnclaimablePeriods().Remove(startTimestamp)
	} else {
		self.UnclaimablePeriods().Set(startTimestamp, endTimestamp)
	}
}

// archiveIncentive moves an ended incentive from active to archived storage
func (self *IncentivesResolver) archiveIncentive(incentiveId string) {
	if incentive, exists := self.IncentiveTrees().Get(incentiveId); exists {
		self.ArchivedIncentives().Set(incentiveId, incentive)
		self.IncentiveTrees().Remove(incentiveId)
	}
}

// calculate unclaimable reward by checking unclaimable periods
func (self *IncentivesResolver) calculateUnclaimableReward(incentiveId string) int64 {
	incentive, ok := self.Get(incentiveId)
	if !ok {
		return 0
	}

	timeDiff := int64(0)

	// Find unclaimable periods that end before or at incentive start
	self.UnclaimablePeriods().ReverseIterate(0, incentive.StartTimestamp(), func(startTimestamp int64, value any) bool {
		endTimestamp, ok := value.(int64)
		if !ok {
			panic("failed to cast value to int64")
		}

		if endTimestamp == 0 {
			endTimestamp = incentive.EndTimestamp()
		}

		if endTimestamp <= incentive.StartTimestamp() {
			return true
		}

		// Calculate duration of unclaimable period that overlaps with incentive period
		duration := calculateUnClaimableDuration(
			startTimestamp,
			endTimestamp,
			incentive.StartTimestamp(),
			incentive.EndTimestamp(),
		)

		timeDiff = safeAddInt64(timeDiff, duration)

		return true
	})

	// Find unclaimable periods that start within incentive period
	self.UnclaimablePeriods().Iterate(incentive.StartTimestamp(), incentive.EndTimestamp(), func(startTimestamp int64, value any) bool {
		endTimestamp, ok := value.(int64)
		if !ok {
			panic("failed to cast value to int64")
		}

		if endTimestamp == 0 {
			endTimestamp = incentive.EndTimestamp()
		}

		// Calculate duration of unclaimable period that overlaps with incentive period
		duration := calculateUnClaimableDuration(
			startTimestamp,
			endTimestamp,
			incentive.StartTimestamp(),
			incentive.EndTimestamp(),
		)
		timeDiff = safeAddInt64(timeDiff, duration)

		// ensures continue iterating through all unclaimable periods
		return false
	})

	return safeMulInt64(timeDiff, incentive.RewardPerSecond())
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
	return safeSubInt64(endTime, startTime)
}
