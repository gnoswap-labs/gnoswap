package staker

import (
	"gno.land/p/gnoswap/gnsmath/v1"
	sr "gno.land/r/gnoswap/staker"
)

type ExternalIncentiveResolver struct {
	*sr.ExternalIncentive
}

// isActive checks if the incentive is currently active at the given timestamp
func (self *ExternalIncentiveResolver) isActive(currentTimestamp int64) bool {
	return currentTimestamp >= self.StartTimestamp() && currentTimestamp <= self.EndTimestamp()
}

// IsEnded reports whether an external incentive's distribution window has ended.
//
// Parameters:
//   - currentTimestamp: Timestamp in Unix seconds to compare with the incentive end time.
//
// Returns:
//   - ended: True when currentTimestamp is after the inclusive end timestamp; false otherwise.
func (self *ExternalIncentiveResolver) IsEnded(currentTimestamp int64) bool {
	return currentTimestamp > self.EndTimestamp()
}

// IsStarted reports whether an external incentive's distribution window has opened.
//
// Parameters:
//   - currentTimestamp: Timestamp in Unix seconds to compare with the incentive start time.
//
// Returns:
//   - started: True when currentTimestamp is at or after the incentive start timestamp; false otherwise.
func (self *ExternalIncentiveResolver) IsStarted(currentTimestamp int64) bool {
	return currentTimestamp >= self.StartTimestamp()
}

// addDistributedRewardAmount adds the given amount to the distributed reward amount.
// This function is used to add the distributed reward amount when the incentive is un-staked and refunded.
func (self *ExternalIncentiveResolver) addDistributedRewardAmount(amount int64) {
	distributedRewardAmount := gnsmath.SafeAddInt64(self.DistributedRewardAmount(), amount)
	self.SetDistributedRewardAmount(distributedRewardAmount)
}

// addAccumulatedPenaltyAmount adds the given amount to the accumulated penalty amount.
// Called during CollectReward to track warmup penalties for later collection.
func (self *ExternalIncentiveResolver) addAccumulatedPenaltyAmount(amount int64) {
	accumulatedPenaltyAmount := gnsmath.SafeAddInt64(self.AccumulatedPenaltyAmount(), amount)
	self.SetAccumulatedPenaltyAmount(accumulatedPenaltyAmount)
}

// NewExternalIncentiveResolver wraps an external incentive with resolver operations.
//
// Parameters:
//   - externalIncentive: External incentive whose timestamps and accounting state the resolver exposes.
//
// Returns:
//   - resolver: Resolver backed by externalIncentive.
func NewExternalIncentiveResolver(
	externalIncentive *sr.ExternalIncentive,
) *ExternalIncentiveResolver {
	return &ExternalIncentiveResolver{
		ExternalIncentive: externalIncentive,
	}
}

type DepositResolver struct {
	*sr.Deposit
}

// InternalRewardLastCollectTime returns the last collect time for the internal reward.
// If the last collect time is 0, it returns the staked time.
//
// Returns:
//   - lastCollectTime: Last internal reward collection time in Unix seconds, falling back to StakeTime when the stored cursor is zero.
func (self *DepositResolver) InternalRewardLastCollectTime() int64 {
	if self.Deposit.InternalRewardLastCollectTime() == 0 {
		return self.Deposit.StakeTime()
	}

	return self.Deposit.InternalRewardLastCollectTime()
}

// ExternalRewardLastCollectTime returns the last collect time for the external reward for the given incentive ID.
// If the last collect time is 0, it returns the staked time.
//
// Parameters:
//   - incentiveID: External incentive ID whose collection cursor should be resolved.
//
// Returns:
//   - lastCollectTime: Last collection time in Unix seconds, falling back to StakeTime when no nonzero cursor is stored.
func (self *DepositResolver) ExternalRewardLastCollectTime(incentiveID string) int64 {
	lastCollectTime, exists := self.Deposit.GetExternalRewardLastCollectTime(incentiveID)
	if !exists || lastCollectTime == 0 {
		return self.Deposit.StakeTime()
	}

	return lastCollectTime
}

// CollectedExternalReward returns the amount already collected for one external incentive.
//
// Parameters:
//   - incentiveID: External incentive ID whose collected amount should be resolved.
//
// Returns:
//   - collectedReward: Cumulative amount collected for incentiveID, or 0 when no amount is stored.
func (self *DepositResolver) CollectedExternalReward(incentiveID string) int64 {
	collectedExternalReward, exists := self.Deposit.GetCollectedExternalReward(incentiveID)
	if !exists {
		return 0
	}

	return collectedExternalReward
}

func (self *DepositResolver) addCollectedInternalReward(reward int64) {
	self.SetCollectedInternalReward(gnsmath.SafeAddInt64(self.CollectedInternalReward(), reward))
}

func (self *DepositResolver) addCollectedExternalReward(incentiveID string, reward int64) {
	collectedExternalReward := gnsmath.SafeAddInt64(self.CollectedExternalReward(incentiveID), reward)
	self.SetCollectedExternalReward(incentiveID, collectedExternalReward)
}

// updateInternalRewardLastCollectTime updates the last collect time for the internal reward.
// It returns an error if the current time is less than the last collect time for the internal reward.
func (self *DepositResolver) updateInternalRewardLastCollectTime(currentTime int64) error {
	if self.InternalRewardLastCollectTime() > currentTime {
		return makeErrorWithDetails(errNotAvailableUpdateCollectTime, "currentTime must be greater than internal reward last collect time")
	}

	self.SetInternalRewardLastCollectTime(currentTime)

	return nil
}

// updateExternalRewardLastCollectTime lazily updates the last collect time for the external reward for the given incentive ID.
// It returns an error if the current time is less than the last collect time for the external reward for the given incentive ID.
func (self *DepositResolver) updateExternalRewardLastCollectTime(incentiveID string, currentTime int64) error {
	if self.ExternalRewardLastCollectTimes() == nil {
		self.SetExternalRewardLastCollectTimes(make(map[string]int64))
	}

	externalLastCollectTime, exists := self.Deposit.GetExternalRewardLastCollectTime(incentiveID)
	if exists && externalLastCollectTime > currentTime {
		return makeErrorWithDetails(errNotAvailableUpdateCollectTime, "currentTime must be greater than external reward last collect time")
	}

	self.Deposit.SetExternalRewardLastCollectTime(incentiveID, currentTime)

	return nil
}

// FindWarmup returns the first warmup tier whose end time is after currentTime.
//
// Parameters:
//   - currentTime: Timestamp in Unix seconds used to select the active warmup tier.
//
// Returns:
//   - index: Index of the first tier with a later NextWarmupTime, or the final tier's index when all tiers have ended.
func (self *DepositResolver) FindWarmup(currentTime int64) int {
	for i, warmup := range self.Warmups() {
		if currentTime < warmup.NextWarmupTime {
			return i
		}
	}
	return len(self.Warmups()) - 1
}

// GetWarmup returns the warmup tier at index.
//
// Parameters:
//   - index: Zero-based warmup-tier index; an out-of-range index panics through slice indexing.
//
// Returns:
//   - warmup: Warmup tier stored at index.
func (self *DepositResolver) GetWarmup(index int) sr.Warmup {
	return self.Warmups()[index]
}

// NewDepositResolver wraps a deposit with reward-cursor and warmup resolution helpers.
//
// Parameters:
//   - deposit: Deposit whose persisted reward state should be resolved.
//
// Returns:
//   - resolver: Resolver backed by deposit.
func NewDepositResolver(
	deposit *sr.Deposit,
) *DepositResolver {
	return &DepositResolver{
		Deposit: deposit,
	}
}
