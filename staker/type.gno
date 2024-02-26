package staker

import (
	"std"
)

type Incentive struct { // r3v4_xxx: private?
	targetPoolPath string
	rewardToken    string
	rewardAmount   bigint
	startTimestamp int64
	endTimestamp   int64
	refundee       std.Address
}

type Deposit struct { // r3v4_xxx: private?
	owner          std.Address
	numberOfStakes uint64
	stakeTimestamp int64
	targetPoolPath string
}

type StakingRewards struct { // r3v4_xxx: private? or is it for gov?
	Tier1 uint8
	Tier2 uint8
	Tier3 uint8
	Tier4 uint8
}
