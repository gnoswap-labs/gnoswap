package staker

import (
	"std"
)

type Incentive struct {
	targetPoolPath string
	// rewardToken std.Address
	rewardToken    string
	rewardAmount   bigint
	startTimestamp bigint
	endTimestamp   bigint
	refundee       std.Address
}

type Deposit struct {
	owner          std.Address
	numberOfStakes bigint
	stakeTimestamp bigint
	targetPoolPath string
}

type StakingRewards struct {
	Tier1 bigint
	Tier2 bigint
	Tier3 bigint
	Tier4 bigint
}
