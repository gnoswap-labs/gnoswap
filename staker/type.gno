package staker

import (
	"std"

	u256 "gno.land/p/gnoswap/uint256"
)

type InternalTier struct {
	tier           uint64
	startTimestamp int64
}

type ExternalIncentive struct {
	targetPoolPath string
	rewardToken    string
	rewardAmount   *u256.Uint
	rewardLeft     *u256.Uint
	startTimestamp int64
	endTimestamp   int64
	refundee       std.Address
}

type Deposit struct {
	owner          std.Address
	numberOfStakes uint64
	stakeTimestamp int64
	stakeHeight    int64
	targetPoolPath string
}

type StakingRewards struct {
	Tier1 uint8
	Tier2 uint8
	Tier3 uint8
	Tier4 uint8
}
