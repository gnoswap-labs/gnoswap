package staker

import (
	"std"

	u256 "gno.land/p/gnoswap/uint256"
)

type InternalTier struct {
	tier           uint64
	startTimestamp int64
	startHeight    int64
	updateHeight   int64
}

type ExternalIncentive struct {
	targetPoolPath    string
	rewardToken       string
	rewardAmount      *u256.Uint
	rewardLeft        *u256.Uint
	startTimestamp    int64
	endTimestamp      int64
	rewardPerBlockX96 *u256.Uint
	refundee          std.Address
	createdHeight     int64
}

type Deposit struct {
	owner          std.Address
	numberOfStakes uint64
	stakeTimestamp int64
	stakeHeight    int64
	targetPoolPath string
}
