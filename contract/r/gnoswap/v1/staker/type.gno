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
	rewardLeft       int64       // remaining reward amount
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

func (self *ExternalIncentive) RewardLeft(currentTimestamp int64) int64 {
	// Still check timestamps for state validation
	if currentTimestamp <= self.startTimestamp {
		// Subtract dust since it won't be distributed
		return self.rewardLeft
	}

	if currentTimestamp > self.endTimestamp {
		return 0
	}

	timeDuration := self.endTimestamp - currentTimestamp
	rewardLeft := safeMulInt64(timeDuration, self.rewardPerSecond)
	return rewardLeft
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
		rewardLeft:       self.rewardLeft,
		rewardPerSecond:  self.rewardPerSecond,
		rewardDust:       self.rewardDust,
		refundee:         self.refundee,
		refunded:         self.refunded,
	}
}

type Deposit struct {
	owner           std.Address // owner address
	stakeTime       int64       // staked time
	targetPoolPath  string      // staked position's pool path
	tickLower       int32       // tick lower
	tickUpper       int32       // tick upper
	liquidity       *u256.Uint  // liquidity
	lastCollectTime int64       // last collect time
	warmups         []Warmup    // warmup information
}
