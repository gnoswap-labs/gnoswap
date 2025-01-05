package staker

import (
	"std"

	u256 "gno.land/p/gnoswap/uint256"
)

type InternalTier struct {
	tier           uint64 // internal reward tier
	startTimestamp int64  // start time for internal reward
}

func (i InternalTier) Tier() uint64 {
	return i.tier
}

func (i InternalTier) StartTimestamp() int64 {
	return i.startTimestamp
}

// newInternalTier creates a new internal tier
func newInternalTier(tier uint64, startTimestamp int64) InternalTier {
	return InternalTier{
		tier:           tier,
		startTimestamp: startTimestamp,
	}
}

type ExternalIncentive struct {
	incentiveId      string      // incentive id
	startTimestamp   int64       // start time for external reward
	endTimestamp     int64       // end time for external reward
	createdHeight    int64       // block height when the incentive was created
	depositGnsAmount uint64      // deposited gns amount
	targetPoolPath   string      // external reward target pool path
	rewardToken      string      // external reward token path
	rewardAmount     uint64      // total reward amount
	rewardLeft       uint64      // remaining reward amount
	startHeight      int64       // start height for external reward
	endHeight        int64       // end height for external reward
	rewardPerBlock   uint64      // reward per block
	refundee         std.Address // refundee address
}

func (e ExternalIncentive) StartTimestamp() int64 {
	return e.startTimestamp
}

func (e ExternalIncentive) EndTimestamp() int64 {
	return e.endTimestamp
}

func (e ExternalIncentive) RewardToken() string {
	return e.rewardToken
}

// newExternalIncentive creates a new external incentive
func newExternalIncentive(
	startTimestamp int64,
	endTimestamp int64,
	createdHeight int64,
	depositGnsAmount uint64,
	targetPoolPath string,
	rewardToken string,
	rewardAmount uint64,
	rewardLeft uint64,
	rewardPerBlock uint64,
	refundee std.Address,
) ExternalIncentive {
	return ExternalIncentive{
		startTimestamp:   startTimestamp,
		endTimestamp:     endTimestamp,
		createdHeight:    createdHeight,
		depositGnsAmount: depositGnsAmount,
		targetPoolPath:   targetPoolPath,
		rewardToken:      rewardToken,
		rewardAmount:     rewardAmount,
		rewardLeft:       rewardLeft,
		rewardPerBlock:   rewardPerBlock,
		refundee:         refundee,
	}
}

func NewExternalIncentive(
	incentiveId string,
	targetPoolPath string,
	rewardToken string,
	rewardAmount uint64,
	startTimestamp int64, // timestamp is in unix time(seconds)
	endTimestamp int64,
	refundee std.Address,
	createdHeight int64,
	depositGnsAmount uint64,

	currentTime int64, // current time in unix time(seconds)
	msPerBlock int64, // msPerBlock is in milliseconds
) *ExternalIncentive {
	incentiveDuration := endTimestamp - startTimestamp
	incentiveBlock := incentiveDuration * 1000 / msPerBlock
	rewardPerBlock := rewardAmount / uint64(incentiveBlock)

	blocksLeftUntilStartHeight := (startTimestamp - currentTime) * 1000 / msPerBlock
	blocksLeftUntilEndHeight := (endTimestamp - currentTime) * 1000 / msPerBlock

	startHeight := std.GetHeight() + blocksLeftUntilStartHeight
	endHeight := std.GetHeight() + blocksLeftUntilEndHeight

	return &ExternalIncentive{
		incentiveId:      incentiveId,
		targetPoolPath:   targetPoolPath,
		rewardToken:      rewardToken,
		rewardAmount:     rewardAmount,
		startTimestamp:   startTimestamp,
		endTimestamp:     endTimestamp,
		startHeight:      startHeight,
		endHeight:        endHeight,
		rewardPerBlock:   rewardPerBlock,
		refundee:         refundee,
		createdHeight:    createdHeight,
		depositGnsAmount: depositGnsAmount,
	}
}

func (self *ExternalIncentive) RewardSpent(currentHeight uint64) uint64 {
	if currentHeight < uint64(self.startHeight) {
		return 0
	}

	if currentHeight > uint64(self.endHeight) {
		return self.rewardAmount
	}

	blocks := currentHeight - uint64(self.startHeight)
	rewardSpent := blocks * self.rewardPerBlock
	return rewardSpent
}

func (self *ExternalIncentive) RewardLeft(currentHeight uint64) uint64 {
	if currentHeight < uint64(self.startHeight) {
		return self.rewardAmount
	}

	if currentHeight > uint64(self.endHeight) {
		return 0
	}

	blocks := uint64(self.endHeight) - currentHeight
	rewardLeft := blocks * self.rewardPerBlock
	return rewardLeft
}

type Deposit struct {
	owner             std.Address // owner address
	stakeTimestamp    int64       // staked time
	stakeHeight       int64       // staked block height
	targetPoolPath    string      // staked position's pool path
	tickLower         int32       // tick lower
	tickUpper         int32       // tick upper
	liquidity         *u256.Uint  // liquidity
	lastCollectHeight uint64      // last collect block height
	warmups           []Warmup    // warmup information
}
