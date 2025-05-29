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
	startHeight      int64       // start height for external reward
	endHeight        int64       // end height for external reward
	rewardPerBlock   int64       // reward per block
	refundee         std.Address // refundee address

	unclaimableRefunded bool // whether unclaimable reward is refunded
}

func (e ExternalIncentive) StartTimestamp() int64 { return e.startTimestamp }
func (e ExternalIncentive) EndTimestamp() int64   { return e.endTimestamp }
func (e ExternalIncentive) RewardToken() string   { return e.rewardToken }
func (e ExternalIncentive) RewardAmount() int64   { return e.rewardAmount }

func (self *ExternalIncentive) RewardSpent(currentHeight int64) int64 {
	if currentHeight < self.startHeight {
		return 0
	}

	if currentHeight > self.endHeight {
		return self.rewardAmount
	}

	blocks := currentHeight - self.startHeight
	rewardSpent := blocks * self.rewardPerBlock
	return rewardSpent
}

func (self *ExternalIncentive) RewardLeft(currentHeight int64) int64 {
	if currentHeight <= self.startHeight {
		return self.rewardAmount
	}

	if currentHeight > self.endHeight {
		return 0
	}

	if currentHeight == self.endHeight {
		return self.rewardPerBlock
	}

	blocks := self.endHeight - currentHeight
	rewardLeft := blocks * self.rewardPerBlock
	return rewardLeft
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
	msPerBlock int64, // msPerBlock is in milliseconds
) *ExternalIncentive {
	if msPerBlock <= 0 {
		panic("msPerBlock must be greater than 0")
	}

	incentiveDuration := endTimestamp - startTimestamp
	incentiveBlock := incentiveDuration * 1000 / msPerBlock
	rewardPerBlock := rewardAmount / incentiveBlock

	blocksLeftUntilStartHeight := (startTimestamp - currentTime) * 1000 / msPerBlock
	blocksLeftUntilEndHeight := (endTimestamp - currentTime) * 1000 / msPerBlock

	startHeight := std.ChainHeight() + blocksLeftUntilStartHeight
	endHeight := std.ChainHeight() + blocksLeftUntilEndHeight

	return &ExternalIncentive{
		incentiveId:         incentiveId,
		targetPoolPath:      targetPoolPath,
		rewardToken:         rewardToken,
		rewardAmount:        rewardAmount,
		startTimestamp:      startTimestamp,
		endTimestamp:        endTimestamp,
		startHeight:         startHeight,
		endHeight:           endHeight,
		rewardPerBlock:      rewardPerBlock,
		refundee:            refundee,
		createdHeight:       createdHeight,
		depositGnsAmount:    depositGnsAmount,
		unclaimableRefunded: false,
	}
}

type Deposit struct {
	owner             std.Address // owner address
	stakeTimestamp    int64       // staked time
	stakeHeight       int64       // staked block height
	targetPoolPath    string      // staked position's pool path
	tickLower         int32       // tick lower
	tickUpper         int32       // tick upper
	liquidity         *u256.Uint  // liquidity
	lastCollectHeight int64       // last collect block height
	warmups           []Warmup    // warmup information
}
