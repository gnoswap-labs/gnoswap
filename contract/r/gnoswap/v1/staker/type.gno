package staker

import (
	"math"
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
	refundee         std.Address // refundee address

	refunded        bool // whether incentive has been refunded (includes GNS deposit and unclaimed rewards)
	isRequestUnwrap bool // whether the original deposit was native GNOT (needs unwrap on refund)
}

func (e ExternalIncentive) IsStarted(currentTimestamp int64) bool {
	return currentTimestamp >= e.startTimestamp
}

// isActive checks if the incentive is currently active at the given timestamp
func (e ExternalIncentive) isActive(currentTimestamp int64) bool {
	return currentTimestamp < e.endTimestamp
}

// safeMulInt64 performs safe multiplication of int64 values, panicking on overflow or underflow
func safeMulInt64(a, b int64) int64 {
	if a == 0 || b == 0 {
		return 0
	}
	if a > 0 && b > 0 {
		if a > math.MaxInt64/b {
			panic("int64 multiplication overflow")
		}
	} else if a < 0 && b < 0 {
		if a < math.MaxInt64/b {
			panic("int64 multiplication overflow")
		}
	} else if a > 0 && b < 0 {
		if b < math.MinInt64/a {
			panic("int64 multiplication underflow")
		}
	} else { // a < 0 && b > 0
		if a < math.MinInt64/b {
			panic("int64 multiplication underflow")
		}
	}
	return a * b
}

// safeAddInt64 performs safe addition of int64 values, panicking on overflow or underflow
func safeAddInt64(a, b int64) int64 {
	if a > 0 && b > math.MaxInt64-a {
		panic("int64 addition overflow")
	}
	if a < 0 && b < math.MinInt64-a {
		panic("int64 addition underflow")
	}
	return a + b
}

// safeSubInt64 performs safe subtraction of int64 values, panicking on overflow or underflow
func safeSubInt64(a, b int64) int64 {
	if b > 0 && a < math.MinInt64+b {
		panic("int64 subtraction underflow")
	}
	if b < 0 && a > math.MaxInt64+b {
		panic("int64 subtraction overflow")
	}
	return a - b
}

func (e ExternalIncentive) StartTimestamp() int64 { return e.startTimestamp }
func (e ExternalIncentive) EndTimestamp() int64   { return e.endTimestamp }
func (e ExternalIncentive) RewardToken() string   { return e.rewardToken }
func (e ExternalIncentive) RewardAmount() int64   { return e.rewardAmount }

func (self *ExternalIncentive) setRefunded(refunded bool) { self.refunded = refunded }

// RewardSpent calculates the actual reward spent using pool's accumulation data
// This method now returns a more accurate value by considering actual distribution
func (self *ExternalIncentive) RewardSpent(pool *Pool, currentTimestamp int64) int64 {
	if currentTimestamp < self.startTimestamp {
		return 0
	}

	if currentTimestamp > self.endTimestamp {
		return self.rewardAmount
	}

	// Calculate actual distributed amount using accumulation difference
	actualDistributed := pool.CalculateActualDistributedReward(
		self,
		self.startTimestamp,
		currentTimestamp,
	)

	return actualDistributed
}

// RewardLeft calculates the remaining reward using actual distribution data
func (self *ExternalIncentive) RewardLeft(pool *Pool, currentTimestamp int64) int64 {
	if currentTimestamp <= self.startTimestamp {
		return self.rewardAmount
	}

	if currentTimestamp > self.endTimestamp {
		return 0
	}

	// Calculate actual distributed amount
	actualDistributed := pool.CalculateActualDistributedReward(
		self,
		self.startTimestamp,
		currentTimestamp,
	)

	// Return the difference between total and distributed
	return self.rewardAmount - actualDistributed
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
		refundee:         self.refundee,
		refunded:         self.refunded,
		isRequestUnwrap:  self.isRequestUnwrap,
	}
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
	return &ExternalIncentive{
		incentiveId:      incentiveId,
		targetPoolPath:   targetPoolPath,
		rewardToken:      rewardToken,
		rewardAmount:     rewardAmount,
		startTimestamp:   startTimestamp,
		endTimestamp:     endTimestamp,
		refundee:         refundee,
		createdHeight:    createdHeight,
		depositGnsAmount: depositGnsAmount,
		refunded:         false,
		isRequestUnwrap:  isRequestUnwrap,
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
