package staker

import (
	"std"
)

type Incentive struct {
	numberOfStakes bigint
}

type Stake struct {
	secondsPerLiquidityInsideInitialX128 bigint
	liquidityNoOverflow                  bigint
	liquidityIfOverflow                  bigint
}

type Deposit struct {
	owner          std.Address
	numberOfStakes bigint
	tickLower      bigint
	tickUpper      bigint
	lockDuration   bigint
	timeToWithdraw bigint
}

type IncentiveKey struct {
	// rewardToken std.Address
	// pool std.Address
	startTime bigint
	endTime   bigint
	refundee  std.Address
}

type StakingRewards struct {
	Reward7  bigint
	Reward14 bigint
	Reward21 bigint
}