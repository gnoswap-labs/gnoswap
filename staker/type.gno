package staker

import (
	"std"

	u256 "gno.land/p/gnoswap/uint256"
)

type InternalTier struct {
	tier           uint64 // internal reward tier
	startTimestamp int64  // start time for internal reward
}

type ExternalIncentive struct {
	targetPoolPath    string      // external reward target pool path
	rewardToken       string      // external reward token path
	rewardAmount      *u256.Uint  // total reward amount
	rewardLeft        *u256.Uint  // remaining reward amount
	startTimestamp    int64       // start time for external reward
	endTimestamp      int64       // end time for external reward
	rewardPerBlockX96 *u256.Uint  // reward per block in Q96 notation
	refundee          std.Address // refundee address
	createdHeight     int64       // block height when the incentive was created
	depositGnsAmount  uint64      // deposited gns amount
}

type Deposit struct {
	owner          std.Address // owner address
	stakeTimestamp int64       // staked time
	stakeHeight    int64       // staked block height

	targetPoolPath string      // staked position's pool path
	tickLower      int32       // tick lower
	tickUpper      int32       // tick upper
	liquidity      *u256.Uint  // liquidity
	
	warmups        []Warmup    // warmup information

	lastCollectHeight uint64 // last collect block height
}