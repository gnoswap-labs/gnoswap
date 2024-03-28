package staker

import (
	"std"

	"gno.land/p/demo/ufmt"

	u256 "gno.land/p/demo/uint256"
)

// Incentive
func StakerPoolIncentives(poolPath string) []string {
	incentives, exist := poolIncentives[poolPath]
	if !exist {
		panic(ufmt.Sprintf("[STAKER] _GET_no_receiver__StakerPoolIncentives() || poolPath(%s) incentives does not exist", poolPath))
	}

	return incentives
}

func StakerIncentiveTargetPoolPath(incentiveId string) string {
	incentive, exist := incentives[incentiveId]
	if !exist {
		panic(ufmt.Sprintf("[STAKER] _GET_no_receiver__StakerIncentiveTargetPoolPath() || incentiveId(%s) incentive does not exist", incentiveId))
	}

	return incentive.targetPoolPath
}

func StakerIncentiveRewardToken(incentiveId string) string {
	incentive, exist := incentives[incentiveId]
	if !exist {
		panic(ufmt.Sprintf("[STAKER] _GET_no_receiver__StakerIncentiveRewardToken() || incentiveId(%s) incentive does not exist", incentiveId))
	}

	return incentive.rewardToken
}

// UINT
func StakerIncentiveRewardAmount(incentiveId string) *u256.Uint {
	incentive, exist := incentives[incentiveId]
	if !exist {
		panic(ufmt.Sprintf("[STAKER] _GET_no_receiver__StakerIncentiveRewardAmount() || incentiveId(%s) incentive does not exist", incentiveId))
	}

	return incentive.rewardAmount
}

// STR
func StakerIncentiveRewardAmountStr(incentiveId string) string {
	incentive, exist := incentives[incentiveId]
	if !exist {
		panic(ufmt.Sprintf("[STAKER] _GET_no_receiver__StakerIncentiveRewardAmount() || incentiveId(%s) incentive does not exist", incentiveId))
	}

	return incentive.rewardAmount.ToString()
}

func StakerIncentiveStartTimestamp(incentiveId string) int64 {
	incentive, exist := incentives[incentiveId]
	if !exist {
		panic(ufmt.Sprintf("[STAKER] _GET_no_receiver__StakerIncentiveStartTimestamp() || incentiveId(%s) incentive does not exist", incentiveId))
	}

	return incentive.startTimestamp
}

func StakerIncentiveEndTimestamp(incentiveId string) int64 {
	incentive, exist := incentives[incentiveId]
	if !exist {
		panic(ufmt.Sprintf("[STAKER] _GET_no_receiver__StakerIncentiveEndTimestamp() || incentiveId(%s) incentive does not exist", incentiveId))
	}

	return incentive.endTimestamp
}

func StakerIncentiveRefundee(incentiveId string) std.Address {
	incentive, exist := incentives[incentiveId]
	if !exist {
		panic(ufmt.Sprintf("[STAKER] _GET_no_receiver__StakerIncentiveRefundee() || incentiveId(%s) incentive does not exist", incentiveId))
	}

	return incentive.refundee
}

// Deposit
func StakerDepositOwner(lpTokenId uint64) std.Address {
	deposit, exist := deposits[lpTokenId]
	if !exist {
		panic(ufmt.Sprintf("[STAKER] _GET_no_receiver__StakerDepositOwner() || tokenId(%d) deposit does not exist", lpTokenId))
	}

	return deposit.owner
}

func StakerDepositNumberOfStakes(lpTokenId uint64) uint64 {
	deposit, exist := deposits[lpTokenId]
	if !exist {
		panic(ufmt.Sprintf("[STAKER] _GET_no_receiver__StakerDepositNumberOfStakes() || tokenId(%d) deposit does not exist", lpTokenId))
	}

	return deposit.numberOfStakes
}

func StakerDepositStakeTimestamp(lpTokenId uint64) int64 {
	deposit, exist := deposits[lpTokenId]
	if !exist {
		panic(ufmt.Sprintf("[STAKER] _GET_no_receiver__StakerDepositStakeTimestamp() || tokenId(%d) deposit does not exist", lpTokenId))
	}

	return deposit.stakeTimestamp
}

func StakerDepositTargetPoolPath(lpTokenId uint64) string {
	deposit, exist := deposits[lpTokenId]
	if !exist {
		panic(ufmt.Sprintf("[STAKER] _GET_no_receiver__StakerDepositTargetPoolPath() || tokenId(%d) deposit does not exist", lpTokenId))
	}

	return deposit.targetPoolPath
}

// PoolTier
func StakerPoolTier(poolPath string) uint64 {
	tier, exist := poolTiers[poolPath]
	if !exist {
		panic(ufmt.Sprintf("[STAKER] _GET_no_receiver__StakerPoolTier() || poolPath(%s) poolTier does not exist", poolPath))
	}

	return tier
}
