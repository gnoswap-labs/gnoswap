package staker

import (
	"std"

	"gno.land/p/demo/ufmt"

	u256 "gno.land/p/gnoswap/uint256"

	en "gno.land/r/gnoswap/v1/emission"

	"gno.land/r/gnoswap/v1/consts"
)

// StakerPoolIncentives returns the list of incentive IDs for a given pool
//
// Parameters:
//   - poolPath (string): The path of the pool to get incentives for
//
// Returns:
//   - A slice og incentive IDs associated with the pool
//
// Panics:
//   - If the pool incentives do not exist for the given pool path
func StakerPoolIncentives(poolPath string) []string {
	en.MintAndDistributeGns()
	if consts.EMISSION_REFACTORED {
		CalcPoolPositionRefactor()
	} else {
		CalcPoolPosition()
	}

	incentives, exist := poolIncentives[poolPath]
	if !exist {
		panic(addDetailToError(
			errDataNotFound,
			ufmt.Sprintf("_GET_no_receiver.gno__StakerPoolIncentives() || poolPath(%s) incentives does not exist", poolPath),
		))
	}

	return incentives
}

// StakerIncentiveTargetPoolPath returns the target pool path for a given incentive
//
// Parameters:
//   - incentiveId (string): The ID of the incentive
//
// Returns:
//   - The target pool path (string) associated with the incentive
//
// Panics:
//   - If the incentive does nor exist for the given incentive ID
func StakerIncentiveTargetPoolPath(incentiveId string) string {
	en.MintAndDistributeGns()
	if consts.EMISSION_REFACTORED {
		CalcPoolPositionRefactor()
	} else {
		CalcPoolPosition()
	}

	incentive, exist := incentives[incentiveId]
	if !exist {
		panic(addDetailToError(
			errDataNotFound,
			ufmt.Sprintf("_GET_no_receiver.gno__StakerIncentiveTargetPoolPath() || incentiveId(%s) incentive does not exist", incentiveId),
		))
	}

	return incentive.targetPoolPath
}

// StakerIncentiveRewardToken returns the reward token for a given incentive
//
// Parameters:
//   - incentiveId (string): The ID of the incentive
//
// Returns:
//   - The reward token (string) associated with the incentive
//
// Panics:
//   - If the incentive does not exist for the given incentiveId
func StakerIncentiveRewardToken(incentiveId string) string {
	en.MintAndDistributeGns()
	if consts.EMISSION_REFACTORED {
		CalcPoolPositionRefactor()
	} else {
		CalcPoolPosition()
	}

	incentive, exist := incentives[incentiveId]
	if !exist {
		panic(addDetailToError(
			errDataNotFound,
			ufmt.Sprintf("_GET_no_receiver.gno__StakerIncentiveRewardToken() || incentiveId(%s) incentive does not exist", incentiveId),
		))
	}

	return incentive.rewardToken
}

// StakerIncentiveRewardAmount returns the reward amount for a given incentive as a Uint256
//
// Parameters:
//   - incentiveId (string): The ID of the incentive
//
// Returns:
//   - *u256.Uint: The reward amount associated with the incentive
//
// Panics:
//   - If the incentive does not exist for the given incentiveId
func StakerIncentiveRewardAmount(incentiveId string) *u256.Uint {
	en.MintAndDistributeGns()
	if consts.EMISSION_REFACTORED {
		CalcPoolPositionRefactor()
	} else {
		CalcPoolPosition()
	}

	incentive, exist := incentives[incentiveId]
	if !exist {
		panic(addDetailToError(
			errDataNotFound,
			ufmt.Sprintf("_GET_no_receiver.gno__StakerIncentiveRewardAmount() || incentiveId(%s) incentive does not exist", incentiveId),
		))
	}

	return incentive.rewardAmount
}

// StakerIncentiveRewardAmountStr returns the reward amount for a given incentive as a string
//
// Parameters:
//   - incentiveId (string): The ID of the incentive
//
// Returns:
//   - string: The reward amount associated with the incentive as a string
//
// Panics:
//   - If the incentive does not exist for the given incentiveId
func StakerIncentiveRewardAmountStr(incentiveId string) string {
	en.MintAndDistributeGns()
	if consts.EMISSION_REFACTORED {
		CalcPoolPositionRefactor()
	} else {
		CalcPoolPosition()
	}

	incentive, exist := incentives[incentiveId]
	if !exist {
		panic(addDetailToError(
			errDataNotFound,
			ufmt.Sprintf("_GET_no_receiver.gno__StakerIncentiveRewardAmount() || incentiveId(%s) incentive does not exist", incentiveId),
		))
	}

	return incentive.rewardAmount.ToString()
}

// StakerIncentiveStartTimestamp returns the start timestamp for a given incentive
//
// Parameters:
//   - incentiveId (string): The ID of the incentive
//
// Returns:
//   - int64: The start timestamp of the incentive
//
// Panics:
//   - If the incentive does not exist for the given incentiveId
func StakerIncentiveStartTimestamp(incentiveId string) int64 {
	en.MintAndDistributeGns()
	if consts.EMISSION_REFACTORED {
		CalcPoolPositionRefactor()
	} else {
		CalcPoolPosition()
	}

	incentive, exist := incentives[incentiveId]
	if !exist {
		panic(addDetailToError(
			errDataNotFound,
			ufmt.Sprintf("_GET_no_receiver.gno__StakerIncentiveStartTimestamp() || incentiveId(%s) incentive does not exist", incentiveId),
		))
	}

	return incentive.startTimestamp
}

// StakerIncentiveEndTimestamp returns the end timestamp for a given incentive
//
// Parameters:
//   - incentiveId (string): The ID of the incentive
//
// Returns:
//   - int64: The end timestamp of the incentive
//
// Panics:
//   - If the incentive does not exist for the given incentiveId
func StakerIncentiveEndTimestamp(incentiveId string) int64 {
	en.MintAndDistributeGns()
	if consts.EMISSION_REFACTORED {
		CalcPoolPositionRefactor()
	} else {
		CalcPoolPosition()
	}

	incentive, exist := incentives[incentiveId]
	if !exist {
		panic(addDetailToError(
			errDataNotFound,
			ufmt.Sprintf("_GET_no_receiver.gno__StakerIncentiveEndTimestamp() || incentiveId(%s) incentive does not exist", incentiveId),
		))
	}

	return incentive.endTimestamp
}

// StakerIncentiveRefundee returns the refundee address for a given incentive
//
// Parameters:
//   - incentiveId (string): The ID of the incentive
//
// Returns:
//   - std.Address: The refundee address of the incentive
//
// Panics:
//   - If the incentive does not exist for the given incentiveId
func StakerIncentiveRefundee(incentiveId string) std.Address {
	en.MintAndDistributeGns()
	if consts.EMISSION_REFACTORED {
		CalcPoolPositionRefactor()
	} else {
		CalcPoolPosition()
	}

	incentive, exist := incentives[incentiveId]
	if !exist {
		panic(addDetailToError(
			errDataNotFound,
			ufmt.Sprintf("_GET_no_receiver.gno__StakerIncentiveRefundee() || incentiveId(%s) incentive does not exist", incentiveId),
		))
	}

	return incentive.refundee
}

// StakerDepositOwner returns the owner address of a deposit for a given LP token ID
//
// Parameters:
//   - lpTokenId (uint64): The ID of the LP token
//
// Returns:
//   - std.Address: The owner address of the deposit
//
// Panics:
//   - If the deposit does not exist for the given lpTokenId
func StakerDepositOwner(lpTokenId uint64) std.Address {
	en.MintAndDistributeGns()
	if consts.EMISSION_REFACTORED {
		CalcPoolPositionRefactor()
	} else {
		CalcPoolPosition()
	}

	deposit, exist := deposits[lpTokenId]
	if !exist {
		panic(addDetailToError(
			errDataNotFound,
			ufmt.Sprintf("_GET_no_receiver.gno__StakerDepositOwner() || tokenId(%d) deposit does not exist", lpTokenId),
		))
	}

	return deposit.owner
}

// StakerDepositNumberOfStakes returns the number of stakes for a given LP token ID
//
// Parameters:
//   - lpTokenId (uint64): The ID of the LP token
//
// Returns:
//   - uint64: The number of stakes for the deposit
//
// Panics:
//   - If the deposit does not exist for the given lpTokenId
func StakerDepositNumberOfStakes(lpTokenId uint64) uint64 {
	en.MintAndDistributeGns()
	if consts.EMISSION_REFACTORED {
		CalcPoolPositionRefactor()
	} else {
		CalcPoolPosition()
	}

	deposit, exist := deposits[lpTokenId]
	if !exist {
		panic(addDetailToError(
			errDataNotFound,
			ufmt.Sprintf("_GET_no_receiver.gno__StakerDepositNumberOfStakes() || tokenId(%d) deposit does not exist", lpTokenId),
		))
	}

	return deposit.numberOfStakes
}

// StakerDepositStakeTimestamp returns the stake timestamp for a given LP token ID
//
// Parameters:
//   - lpTokenId (uint64): The ID of the LP token
//
// Returns:
//   - int64: The stake timestamp of the deposit
//
// Panics:
//   - If the deposit does not exist for the given lpTokenId
func StakerDepositStakeTimestamp(lpTokenId uint64) int64 {
	en.MintAndDistributeGns()
	if consts.EMISSION_REFACTORED {
		CalcPoolPositionRefactor()
	} else {
		CalcPoolPosition()
	}

	deposit, exist := deposits[lpTokenId]
	if !exist {
		panic(addDetailToError(
			errDataNotFound,
			ufmt.Sprintf("_GET_no_receiver.gno__StakerDepositStakeTimestamp() || tokenId(%d) deposit does not exist", lpTokenId),
		))
	}

	return deposit.stakeTimestamp
}

// StakerDepositTargetPoolPath returns the target pool path for a given LP token ID
//
// Parameters:
//   - lpTokenId (uint64): The ID of the LP token
//
// Returns:
//   - string: The target pool path of the deposit
//
// Panics:
//   - If the deposit does not exist for the given lpTokenId
func StakerDepositTargetPoolPath(lpTokenId uint64) string {
	en.MintAndDistributeGns()
	if consts.EMISSION_REFACTORED {
		CalcPoolPositionRefactor()
	} else {
		CalcPoolPosition()
	}

	deposit, exist := deposits[lpTokenId]
	if !exist {
		panic(addDetailToError(
			errDataNotFound,
			ufmt.Sprintf("_GET_no_receiver.gno__StakerDepositTargetPoolPath() || tokenId(%d) deposit does not exist", lpTokenId),
		))
	}

	return deposit.targetPoolPath
}

// StakerPoolTier returns the tier of a given pool
//
// Parameters:
//   - poolPath (string): The path of the pool
//
// Returns:
//   - uint64: The tier of the pool
//
// Panics:
//   - If the pool tier does not exist for the given poolPath
func StakerPoolTier(poolPath string) uint64 {
	internal, exist := poolTiers[poolPath]
	if !exist {
		panic(addDetailToError(
			errDataNotFound,
			ufmt.Sprintf("_GET_no_receiver.gno__StakerPoolTier() || poolPath(%s) poolTier does not exist", poolPath),
		))
	}

	return internal.tier
}
