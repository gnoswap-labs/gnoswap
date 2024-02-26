package staker

import (
	"std"

	"gno.land/p/demo/ufmt"
)

// Incentive
func StakerPoolIncentives(poolPath string) []string {
	incentives, exist := poolIncentives[poolPath]
	requireExist(exist, ufmt.Sprintf("[STAKER] _GET_staker.gno__StakerPoolIncentives() || poolPath(%s) incentives does not exist", poolPath))

	return incentives
}

func StakerIncentiveTargetPoolPath(incentiveId string) string {
	incentive, exist := incentives[incentiveId]
	requireExist(exist, ufmt.Sprintf("[STAKER] _GET_staker.gno__StakerIncentiveTargetPoolPath() || incentiveId(%s) incentive does not exist", incentiveId))

	return incentive.targetPoolPath
}

func StakerIncentiveRewardToken(incentiveId string) string {
	incentive, exist := incentives[incentiveId]
	requireExist(exist, ufmt.Sprintf("[STAKER] _GET_staker.gno__StakerIncentiveRewardToken() || incentiveId(%s) incentive does not exist", incentiveId))

	return incentive.rewardToken
}

func StakerIncentiveRewardAmount(incentiveId string) bigint {
	incentive, exist := incentives[incentiveId]
	requireExist(exist, ufmt.Sprintf("[STAKER] _GET_staker.gno__StakerIncentiveRewardAmount() || incentiveId(%s) incentive does not exist", incentiveId))

	return incentive.rewardAmount
}

func StakerIncentiveStartTimestamp(incentiveId string) int64 {
	incentive, exist := incentives[incentiveId]
	requireExist(exist, ufmt.Sprintf("[STAKER] _GET_staker.gno__StakerIncentiveStartTimestamp() || incentiveId(%s) incentive does not exist", incentiveId))

	return incentive.startTimestamp
}

func StakerIncentiveEndTimestamp(incentiveId string) int64 {
	incentive, exist := incentives[incentiveId]
	requireExist(exist, ufmt.Sprintf("[STAKER] _GET_staker.gno__StakerIncentiveEndTimestamp() || incentiveId(%s) incentive does not exist", incentiveId))

	return incentive.endTimestamp
}

func StakerIncentiveRefundee(incentiveId string) std.Address {
	incentive, exist := incentives[incentiveId]
	requireExist(exist, ufmt.Sprintf("[STAKER] _GET_staker.gno__StakerIncentiveRefundee() || incentiveId(%s) incentive does not exist", incentiveId))

	return incentive.refundee
}

// Deposit
func StakerDepositOwner(lpTokenId uint64) std.Address {
	deposit, exist := deposits[lpTokenId]
	requireExist(exist, ufmt.Sprintf("[STAKER] _GET_staker.gno__StakerDepositOwner() || tokenId(%d) deposit does not exist", lpTokenId))

	return deposit.owner
}

func StakerDepositNumberOfStakes(lpTokenId uint64) uint64 {
	deposit, exist := deposits[lpTokenId]
	requireExist(exist, ufmt.Sprintf("[STAKER] _GET_staker.gno__StakerDepositNumberOfStakes() || tokenId(%d) deposit does not exist", lpTokenId))

	return deposit.numberOfStakes
}

func StakerDepositStakeTimestamp(lpTokenId uint64) int64 {
	deposit, exist := deposits[lpTokenId]
	requireExist(exist, ufmt.Sprintf("[STAKER] _GET_staker.gno__StakerDepositStakeTimestamp() || tokenId(%d) deposit does not exist", lpTokenId))

	return deposit.stakeTimestamp
}

func StakerDepositTargetPoolPath(lpTokenId uint64) string {
	deposit, exist := deposits[lpTokenId]
	requireExist(exist, ufmt.Sprintf("[STAKER] _GET_staker.gno__StakerDepositTargetPoolPath() || tokenId(%d) deposit does not exist", lpTokenId))

	return deposit.targetPoolPath
}

// PoolTier
func StakerPoolTier(poolPath string) uint8 {
	tier, exist := poolTiers[poolPath]
	requireExist(exist, ufmt.Sprintf("[STAKER] _GET_staker.gno__StakerPoolTier() || poolPath(%s) poolTier does not exist", poolPath))

	return tier
}
