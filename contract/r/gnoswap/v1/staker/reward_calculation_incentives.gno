package staker

import (
	"std"
	"time"

	"gno.land/p/nt/avl"
)

// Incentives represents a collection of external incentives for a specific pool.
//
// Fields:
//
//   - incentives: AVL tree storing ExternalIncentive objects indexed by incentiveId
//     The incentiveId serves as the key to efficiently lookup incentive details
//
//   - targetPoolPath: String identifier for the pool this incentive collection belongs to
//     Used to associate incentives with their corresponding liquidity pool
//
//   - unclaimablePeriods: Tree storing periods when rewards cannot be claimed
//     Maps start timestamp (key) to end timestamp (value)
//     An end timestamp of 0 indicates an ongoing unclaimable period
//     Used to track intervals when staking rewards are not claimable
type Incentives struct {
	incentives         *avl.Tree // (incentiveId) => ExternalIncentive
	archivedIncentives *avl.Tree // (incentiveId) => ExternalIncentive (ended incentives)

	targetPoolPath string // The target pool path for this incentive collection

	unclaimablePeriods *UintTree // startTimestamp => endTimestamp
}

// NewIncentives creates a new Incentives instance.
func NewIncentives(targetPoolPath string) Incentives {
	result := Incentives{
		targetPoolPath:     targetPoolPath,
		unclaimablePeriods: NewUintTree(),
		incentives:         avl.NewTree(),
		archivedIncentives: avl.NewTree(),
	}

	// initial unclaimable period starts, as there cannot be any staked positions yet.
	currentTimestamp := time.Now().Unix()
	result.unclaimablePeriods.set(currentTimestamp, int64(0))
	return result
}

// Get incentive by incentiveId (checks both active and archived)
func (self *Incentives) Get(incentiveId string) (*ExternalIncentive, bool) {
	// First check active incentives
	if incentive, ok := retrieveIncentive(self.incentives, incentiveId); ok {
		return incentive, true
	}
	return retrieveIncentive(self.archivedIncentives, incentiveId)
}

func retrieveIncentive(tree *avl.Tree, id string) (*ExternalIncentive, bool) {
	value, ok := tree.Get(id)
	if !ok {
		return nil, false
	}
	v, ok := value.(*ExternalIncentive)
	if !ok {
		panic("failed to cast value to *ExternalIncentive")
	}
	return v, true
}

// Get all incentives that is active in given [startTimestamp, endTimestamp)
func (self *Incentives) GetAllInTimestamps(startTimestamp, endTimestamp int64) map[string]*ExternalIncentive {
	incentives := make(map[string]*ExternalIncentive)

	// Only iterate active incentives (not archived)
	self.incentives.Iterate("", "", func(key string, value any) bool {
		incentive, ok := value.(*ExternalIncentive)
		if !ok {
			return false
		}

		// incentive is not active
		if incentive.startTimestamp > endTimestamp || incentive.endTimestamp < startTimestamp {
			return false
		}

		incentives[incentive.incentiveId] = incentive

		return false
	})

	return incentives
}

// Create a new external incentive
// Panics if the incentive already exists.
func (self *Incentives) create(
	creator std.Address,
	incentive *ExternalIncentive,
) {
	self.incentives.Set(incentive.incentiveId, incentive)
}

// starts incentive unclaimable period for this pool
func (self *Incentives) update(
	creator std.Address,
	incentive *ExternalIncentive,
) {
	self.incentives.Set(incentive.incentiveId, incentive)
}

// starts incentive unclaimable period for this pool
func (self *Incentives) startUnclaimablePeriod(startTimestamp int64) {
	self.unclaimablePeriods.set(startTimestamp, int64(0))
}

// ends incentive unclaimable period for this pool
// ignores if currently not in unclaimable period
func (self *Incentives) endUnclaimablePeriod(endTimestamp int64) {
	startTimestamp := int64(0)
	self.unclaimablePeriods.ReverseIterate(0, endTimestamp, func(key int64, value any) bool {
		if value.(int64) != 0 {
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
		self.unclaimablePeriods.remove(startTimestamp)
	} else {
		self.unclaimablePeriods.set(startTimestamp, endTimestamp)
	}
}

// archiveIncentive moves an ended incentive from active to archived storage
func (self *Incentives) archiveIncentive(incentiveId string) {
	if incentive, exists := self.incentives.Get(incentiveId); exists {
		self.archivedIncentives.Set(incentiveId, incentive)
		self.incentives.Remove(incentiveId)
	}
}

// calculate unclaimable reward by checking unclaimable periods
func (self *Incentives) calculateUnclaimableReward(incentiveId string) int64 {
	incentive, ok := self.Get(incentiveId)
	if !ok {
		return 0
	}

	timeDiff := int64(0)

	// Find unclaimable periods that end before or at incentive start
	self.unclaimablePeriods.ReverseIterate(0, incentive.startTimestamp, func(key int64, value any) bool {
		startTimestamp := key
		endTimestamp := value.(int64)
		if endTimestamp == 0 {
			endTimestamp = incentive.endTimestamp
		}

		if endTimestamp <= incentive.startTimestamp {
			return true
		}

		// Calculate duration of unclaimable period that overlaps with incentive period
		duration := calculateUnClaimableDuration(
			startTimestamp,
			endTimestamp,
			incentive.startTimestamp,
			incentive.endTimestamp,
		)

		timeDiff += duration

		return true
	})

	// Find unclaimable periods that start within incentive period
	self.unclaimablePeriods.Iterate(incentive.startTimestamp, incentive.endTimestamp, func(key int64, value any) bool {
		startTimestamp := key
		endTimestamp, ok := value.(int64)
		if !ok {
			panic("failed to cast value to int64")
		}

		if endTimestamp == 0 {
			endTimestamp = incentive.endTimestamp
		}

		// Calculate duration of unclaimable period that overlaps with incentive period
		duration := calculateUnClaimableDuration(
			startTimestamp,
			endTimestamp,
			incentive.startTimestamp,
			incentive.endTimestamp,
		)

		timeDiff += duration

		return false
	})

	return timeDiff * incentive.rewardPerSecond
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
	return endTime - startTime
}
