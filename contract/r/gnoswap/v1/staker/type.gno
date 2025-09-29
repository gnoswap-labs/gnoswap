package staker

import (
	"std"

	u256 "gno.land/p/gnoswap/uint256"
)

// ExternalIncentive is a struct for storing external incentive information.
type ExternalIncentive struct {
	incentiveId      string      // incentive id
	startTimestamp   int64       // start time for external reward
	endTimestamp     int64       // end time for external reward
	createdHeight    int64       // block height when the incentive was created
	depositGnsAmount int64       // deposited gns amount
	targetPoolPath   string      // external reward target pool path
	rewardToken      string      // external reward token path
	rewardAmount     int64       // total reward amount
	rewardPerSecond  int64       // reward per second
	rewardDust       int64       // dust amount from precision loss (rewardAmount % duration)
	refundee         std.Address // refundee address

	refunded        bool // whether incentive has been refunded (includes GNS deposit and unclaimed rewards)
	isRequestUnwrap bool // whether the original deposit was native GNOT (needs unwrap on refund)
}

// NewExternalIncentive creates a new external incentive
func NewExternalIncentive(
	incentiveId string,
	targetPoolPath string,
	rewardToken string,
	rewardAmount int64,
	startTimestamp int64, // timestamp is in unix time(seconds)
	endTimestamp int64,
	refundee std.Address,
	createdHeight int64,
	depositGnsAmount int64,
	currentTime int64, // current time in unix time(seconds)
	isRequestUnwrap bool, // whether original deposit was native GNOT
) *ExternalIncentive {
	incentiveDuration := endTimestamp - startTimestamp
	rewardPerSecond := rewardAmount / incentiveDuration
	// Calculate dust from integer division precision loss
	rewardDust := rewardAmount - (rewardPerSecond * incentiveDuration)

	return &ExternalIncentive{
		incentiveId:      incentiveId,
		targetPoolPath:   targetPoolPath,
		rewardToken:      rewardToken,
		rewardAmount:     rewardAmount,
		startTimestamp:   startTimestamp,
		endTimestamp:     endTimestamp,
		rewardPerSecond:  rewardPerSecond,
		rewardDust:       rewardDust,
		refundee:         refundee,
		createdHeight:    createdHeight,
		depositGnsAmount: depositGnsAmount,
		refunded:         false,
		isRequestUnwrap:  isRequestUnwrap,
	}
}

// isActive checks if the incentive is currently active at the given timestamp
func (e ExternalIncentive) isActive(currentTimestamp int64) bool {
	return currentTimestamp < e.endTimestamp
}

func (e ExternalIncentive) IsStarted(currentTimestamp int64) bool {
	return currentTimestamp >= e.startTimestamp
}

func (self *ExternalIncentive) setRefunded(refunded bool) {
	self.refunded = refunded
}

func (e ExternalIncentive) StartTimestamp() int64 { return e.startTimestamp }
func (e ExternalIncentive) EndTimestamp() int64   { return e.endTimestamp }
func (e ExternalIncentive) RewardToken() string   { return e.rewardToken }
func (e ExternalIncentive) RewardAmount() int64   { return e.rewardAmount }
func (e ExternalIncentive) RewardDust() int64     { return e.rewardDust }

func (self *ExternalIncentive) RewardSpent(currentTimestamp int64) int64 {
	if currentTimestamp < self.startTimestamp {
		return 0
	}

	if currentTimestamp > self.endTimestamp {
		return self.rewardAmount
	}

	timeDuration := currentTimestamp - self.startTimestamp
	rewardSpent := safeMulInt64(timeDuration, self.rewardPerSecond)
	return rewardSpent
}


func (self *ExternalIncentive) Clone() *ExternalIncentive {
	return &ExternalIncentive{
		incentiveId:      self.incentiveId,
		startTimestamp:   self.startTimestamp,
		endTimestamp:     self.endTimestamp,
		createdHeight:    self.createdHeight,
		depositGnsAmount: self.depositGnsAmount,
		targetPoolPath:   self.targetPoolPath,
		rewardToken:      self.rewardToken,
		rewardAmount:     self.rewardAmount,
		rewardPerSecond:  self.rewardPerSecond,
		rewardDust:       self.rewardDust,
		refundee:         self.refundee,
		refunded:         self.refunded,
	}
}

func (self *ExternalIncentive) setRefunded(refunded bool) {
	self.refunded = refunded
}

// NewExternalIncentive creates a new external incentive
func NewExternalIncentive(
	incentiveId string,
	targetPoolPath string,
	rewardToken string,
	rewardAmount int64,
	startTimestamp int64, // timestamp is in unix time(seconds)
	endTimestamp int64,
	refundee std.Address,
	createdHeight int64,
	depositGnsAmount int64,
	currentTime int64, // current time in unix time(seconds)
	isRequestUnwrap bool, // whether original deposit was native GNOT
) *ExternalIncentive {
	incentiveDuration := endTimestamp - startTimestamp
	rewardPerSecond := rewardAmount / incentiveDuration

	return &ExternalIncentive{
		incentiveId:      incentiveId,
		targetPoolPath:   targetPoolPath,
		rewardToken:      rewardToken,
		rewardAmount:     rewardAmount,
		startTimestamp:   startTimestamp,
		endTimestamp:     endTimestamp,
		rewardPerSecond:  rewardPerSecond,
		refundee:         refundee,
		createdHeight:    createdHeight,
		depositGnsAmount: depositGnsAmount,
		refunded:         false,
		isRequestUnwrap:  isRequestUnwrap,
	}
}

type Deposit struct {
	warmups                        []Warmup         // warmup information
	liquidity                      *u256.Uint       // liquidity
	targetPoolPath                 string           // staked position's pool path
	owner                          std.Address      // owner address
	stakeTime                      int64            // staked time
	internalRewardLastCollectTime  int64            // last collect time for internal reward
	externalRewardLastCollectTimes map[string]int64 // last collect time for external rewards by incentive id
	tickLower                      int32            // tick lower
	tickUpper                      int32            // tick upper
}

// InternalRewardLastCollectTime returns the last collect time for the internal reward.
// If the last collect time is 0, it returns the staked time.
func (self *Deposit) InternalRewardLastCollectTime() int64 {
	if self.internalRewardLastCollectTime == 0 {
		return self.stakeTime
	}

	return self.internalRewardLastCollectTime
}

// ExternalRewardLastCollectTime returns the last collect time for the external reward for the given incentive ID.
// If the last collect time is 0, it returns the staked time.
func (self *Deposit) ExternalRewardLastCollectTime(incentiveID string) int64 {
	lastCollectTime, exists := self.externalRewardLastCollectTimes[incentiveID]
	if !exists || lastCollectTime == 0 {
		return self.stakeTime
	}

	return lastCollectTime
}

// updateInternalRewardLastCollectTime updates the last collect time for the internal reward.
// It returns an error if the current time is less than the last collect time for the internal reward.
func (self *Deposit) updateInternalRewardLastCollectTime(currentTime int64) error {
	if self.internalRewardLastCollectTime > currentTime {
		return makeErrorWithDetails(errNotAvailableUpdateCollectTime, "currentTime must be greater than internal reward last collect time")
	}

	self.internalRewardLastCollectTime = currentTime

	return nil
}

// updateExternalRewardLastCollectTime lazily updates the last collect time for the external reward for the given incentive ID.
// It returns an error if the current time is less than the last collect time for the external reward for the given incentive ID.
func (self *Deposit) updateExternalRewardLastCollectTime(incentiveID string, currentTime int64) error {
	if self.externalRewardLastCollectTimes == nil {
		self.externalRewardLastCollectTimes = make(map[string]int64)
	}

	externalLastCollectTime, exists := self.externalRewardLastCollectTimes[incentiveID]
	if exists && externalLastCollectTime > currentTime {
		return makeErrorWithDetails(errNotAvailableUpdateCollectTime, "currentTime must be greater than external reward last collect time")
	}

	self.externalRewardLastCollectTimes[incentiveID] = currentTime

	return nil
}

func NewDeposit(
	owner std.Address,
	targetPoolPath string,
	liquidity *u256.Uint,
	currentTime int64,
	tickLower, tickUpper int32,
) *Deposit {
	return &Deposit{
		owner:                          owner,
		targetPoolPath:                 targetPoolPath,
		liquidity:                      liquidity,
		warmups:                        instantiateWarmup(currentTime),
		stakeTime:                      currentTime,
		tickLower:                      tickLower,
		tickUpper:                      tickUpper,
		internalRewardLastCollectTime:  currentTime,
		externalRewardLastCollectTimes: make(map[string]int64),
	}
}
