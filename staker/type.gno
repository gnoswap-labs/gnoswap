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
	targetPoolPath    string // 줘야 하는 곳
	rewardToken       string // 실제로 주는 리워드
	rewardAmount      *u256.Uint
	rewardLeft        *u256.Uint
	startTimestamp    int64
	endTimestamp      int64
	// startHeight       int64 => Diff를 구해서 1 block 당 얼만큼 줘야 하는지 계산
	// endHeight         int64
	rewardPerBlockX96 *u256.Uint
	refundee          std.Address
	createdHeight     int64
	depositGnsAmount  uint64
}

type Deposit struct {
	owner          std.Address
	numberOfStakes uint64
	stakeTimestamp int64
	stakeHeight    int64
	targetPoolPath string
}
