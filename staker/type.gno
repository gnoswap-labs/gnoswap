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
	startTimestamp    int64       // start time for external reward
	endTimestamp      int64       // end time for external reward
	createdHeight     int64       // block height when the incentive was created
	depositGnsAmount  uint64      // deposited gns amount
	targetPoolPath    string      // external reward target pool path
	rewardToken       string      // external reward token path
	rewardAmount      *u256.Uint  // total reward amount
	rewardLeft        *u256.Uint  // remaining reward amount
	rewardPerBlockX96 *u256.Uint  // reward per block in Q96 notation
	refundee          std.Address // refundee address
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
	rewardAmount *u256.Uint,
	rewardLeft *u256.Uint,
	rewardPerBlockX96 *u256.Uint,
	refundee std.Address,
) ExternalIncentive {
	return ExternalIncentive{
		startTimestamp:    startTimestamp,
		endTimestamp:      endTimestamp,
		createdHeight:     createdHeight,
		depositGnsAmount:  depositGnsAmount,
		targetPoolPath:    targetPoolPath,
		rewardToken:       rewardToken,
		rewardAmount:      rewardAmount,
		rewardLeft:        rewardLeft,
		rewardPerBlockX96: rewardPerBlockX96,
		refundee:          refundee,
	}
}

type Deposit struct {
	owner          std.Address // owner address
	numberOfStakes uint64      // number of stakes
	stakeTimestamp int64       // staked time
	stakeHeight    int64       // staked block height
	targetPoolPath string      // staked position's pool path
}

func (d Deposit) NumberOfStakes() uint64 {
	return d.numberOfStakes
}

func (d Deposit) StakeTimestamp() int64 {
	return d.stakeTimestamp
}

func (d Deposit) TargetPoolPath() string {
	return d.targetPoolPath
}

func (d Deposit) SetOwner(owner std.Address) {
	d.owner = owner
}

func (d Deposit) SetNumberOfStakes(numberOfStakes uint64) {
	d.numberOfStakes = numberOfStakes
}

func (d Deposit) SetStakeTimestamp(stakeTimestamp int64) {
	d.stakeTimestamp = stakeTimestamp
}

func (d Deposit) SetStakeHeight(stakeHeight int64) {
	d.stakeHeight = stakeHeight
}

func (d Deposit) SetTargetPoolPath(targetPoolPath string) {
	d.targetPoolPath = targetPoolPath
}
