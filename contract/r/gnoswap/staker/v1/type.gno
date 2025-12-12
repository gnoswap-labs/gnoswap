package v1

import (
	"gno.land/p/nt/avl"
	sr "gno.land/r/gnoswap/staker"
)

type ExternalIncentiveResolver struct {
	*sr.ExternalIncentive
}

// isActive checks if the incentive is currently active at the given timestamp
func (self *ExternalIncentiveResolver) isActive(currentTimestamp int64) bool {
	return currentTimestamp >= self.StartTimestamp() && currentTimestamp < self.EndTimestamp()
}

func (self *ExternalIncentiveResolver) IsEnded(currentTimestamp int64) bool {
	return currentTimestamp > self.EndTimestamp()
}

func (self *ExternalIncentiveResolver) IsStarted(currentTimestamp int64) bool {
	return currentTimestamp >= self.StartTimestamp()
}

func (self *ExternalIncentiveResolver) IsFinished() bool {
	return self.Refunded() && self.DistributedRewardAmount() >= self.TotalRewardAmount()
}

func (self *ExternalIncentiveResolver) setRefunded(refunded bool) {
	self.SetRefunded(refunded)
}

func (self *ExternalIncentiveResolver) RewardSpent(currentTimestamp int64) int64 {
	// Check timestamps for state validation
	if currentTimestamp < self.StartTimestamp() {
		return 0
	}

	if currentTimestamp > self.EndTimestamp() {
		return self.RewardAmount()
	}

	timeDuration := safeSubInt64(currentTimestamp, self.StartTimestamp())
	rewardSpent := safeMulInt64(timeDuration, self.RewardPerSecond())
	return rewardSpent
}

// addDistributedRewardAmount adds the given amount to the distributed reward amount.
// This function is used to add the distributed reward amount when the incentive is un-staked and refunded.
func (self *ExternalIncentiveResolver) addDistributedRewardAmount(amount int64) {
	distributedRewardAmount := safeAddInt64(self.DistributedRewardAmount(), amount)
	self.SetDistributedRewardAmount(distributedRewardAmount)
}

func (self *ExternalIncentiveResolver) Clone() *ExternalIncentiveResolver {
	return &ExternalIncentiveResolver{
		ExternalIncentive: self.ExternalIncentive.Clone(),
	}
}

// NewExternalIncentive creates a new external incentive
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
func (self *DepositResolver) InternalRewardLastCollectTime() int64 {
	if self.Deposit.InternalRewardLastCollectTime() == 0 {
		return self.Deposit.StakeTime()
	}

	return self.Deposit.InternalRewardLastCollectTime()
}

// ExternalRewardLastCollectTime returns the last collect time for the external reward for the given incentive ID.
// If the last collect time is 0, it returns the staked time.
func (self *DepositResolver) ExternalRewardLastCollectTime(incentiveID string) int64 {
	lastCollectTime, exists := self.Deposit.GetExternalRewardLastCollectTime(incentiveID)
	if !exists || lastCollectTime == 0 {
		return self.Deposit.StakeTime()
	}

	return lastCollectTime
}

func (self *DepositResolver) CollectedExternalReward(incentiveID string) int64 {
	collectedExternalReward, exists := self.Deposit.GetCollectedExternalReward(incentiveID)
	if !exists {
		return 0
	}

	return collectedExternalReward
}

func (self *DepositResolver) addCollectedInternalReward(reward int64) {
	self.SetCollectedInternalReward(safeAddInt64(self.CollectedInternalReward(), reward))
}

func (self *DepositResolver) addCollectedExternalReward(incentiveID string, reward int64) {
	collectedExternalReward := safeAddInt64(self.CollectedExternalReward(incentiveID), reward)
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
		self.SetExternalRewardLastCollectTimes(avl.NewTree())
	}

	externalLastCollectTime, exists := self.Deposit.GetExternalRewardLastCollectTime(incentiveID)
	if exists && externalLastCollectTime > currentTime {
		return makeErrorWithDetails(errNotAvailableUpdateCollectTime, "currentTime must be greater than external reward last collect time")
	}

	self.Deposit.SetExternalRewardLastCollectTime(incentiveID, currentTime)

	return nil
}

func (self *DepositResolver) FindWarmup(currentTime int64) int {
	for i, warmup := range self.Warmups() {
		if currentTime < warmup.NextWarmupTime {
			return i
		}
	}
	return len(self.Warmups()) - 1
}

func (self *DepositResolver) GetWarmup(index int) sr.Warmup {
	return self.Warmups()[index]
}

func NewDepositResolver(
	deposit *sr.Deposit,
) *DepositResolver {
	return &DepositResolver{
		Deposit: deposit,
	}
}
