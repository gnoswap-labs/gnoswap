package staker

import (
	"std"

	ufmt "gno.land/p/demo/ufmt"

	u256 "gno.land/p/gnoswap/uint256"
)

//! TODO: Change function names to follow a naming convention

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
	pool, ok := pools.Get(poolPath)
	if !ok {
		panic(ufmt.Sprintf("poolPath(%s) pool does not exist", poolPath))
	}

	ids := []string{}
	pool.incentives.byTime.Iterate("", "", func(key string, value interface{}) bool {
		ids = append(ids, key)
		return true
	})

	return ids
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
func StakerIncentiveTargetPoolPath(incentiveId string, poolPath string) string {
	pool, ok := pools.Get(poolPath)
	if !ok {
		panic(ufmt.Sprintf("poolPath(%s) pool does not exist", poolPath))
	}

	incentive, exist := pool.incentives.byTime.Get(incentiveId)
	if !exist {
		panic(ufmt.Sprintf("incentiveId(%s) incentive does not exist", incentiveId))
	}

	return incentive.(*ExternalIncentive).targetPoolPath
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
func StakerIncentiveRewardToken(incentiveId string, poolPath string) string {
	pool, ok := pools.Get(poolPath)
	if !ok {
		panic(ufmt.Sprintf("poolPath(%s) pool does not exist", poolPath))
	}

	incentive, exist := pool.incentives.byTime.Get(incentiveId)
	if !exist {
		panic(ufmt.Sprintf("incentiveId(%s) incentive does not exist", incentiveId))
	}

	return incentive.(*ExternalIncentive).rewardToken
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
func StakerIncentiveRewardAmount(incentiveId string, poolPath string) *u256.Uint {
	pool, ok := pools.Get(poolPath)
	if !ok {
		panic(ufmt.Sprintf("poolPath(%s) pool does not exist", poolPath))
	}

	incentive, exist := pool.incentives.byTime.Get(incentiveId)
	if !exist {
		panic(ufmt.Sprintf("incentiveId(%s) incentive does not exist", incentiveId))
	}

	return u256.NewUint(incentive.(*ExternalIncentive).rewardAmount)
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
func StakerIncentiveRewardAmountStr(incentiveId string, poolPath string) string {
	pool, ok := pools.Get(poolPath)
	if !ok {
		panic(ufmt.Sprintf("poolPath(%s) pool does not exist", poolPath))
	}

	incentive, exist := pool.incentives.byTime.Get(incentiveId)
	if !exist {
		panic(ufmt.Sprintf("incentiveId(%s) incentive does not exist", incentiveId))
	}

	return u256.NewUint(incentive.(*ExternalIncentive).rewardAmount).ToString()
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
func StakerIncentiveStartTimestamp(incentiveId string, poolPath string) int64 {
	pool, ok := pools.Get(poolPath)
	if !ok {
		panic(ufmt.Sprintf("poolPath(%s) pool does not exist", poolPath))
	}

	incentive, exist := pool.incentives.byTime.Get(incentiveId)
	if !exist {
		panic(ufmt.Sprintf("incentiveId(%s) incentive does not exist", incentiveId))
	}

	return incentive.(*ExternalIncentive).startTimestamp
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
func StakerIncentiveEndTimestamp(incentiveId string, poolPath string) int64 {
	pool, ok := pools.Get(poolPath)
	if !ok {
		panic(ufmt.Sprintf("poolPath(%s) pool does not exist", poolPath))
	}

	incentive, exist := pool.incentives.byTime.Get(incentiveId)
	if !exist {
		panic(ufmt.Sprintf("incentiveId(%s) incentive does not exist", incentiveId))
	}

	return incentive.(*ExternalIncentive).endTimestamp
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
func StakerIncentiveRefundee(incentiveId string, poolPath string) std.Address {
	pool, ok := pools.Get(poolPath)
	if !ok {
		panic(ufmt.Sprintf("poolPath(%s) pool does not exist", poolPath))
	}

	incentive, exist := pool.incentives.byTime.Get(incentiveId)
	if !exist {
		panic(ufmt.Sprintf("incentiveId(%s) incentive does not exist", incentiveId))
	}

	return incentive.(*ExternalIncentive).refundee
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
	deposit := deposits.Get(lpTokenId)
	if deposit == nil {
		panic(ufmt.Sprintf("lpTokenId(%d) deposit does not exist", lpTokenId))
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
/*
func StakerDepositNumberOfStakes(lpTokenId uint64) uint64 {
	en.MintAndDistributeGns()
	if consts.EMISSION_REFACTORED {
		CalcPoolPositionRefactor()
	} else {
		CalcPoolPosition()
	}

	deposit, exist := deposits.Get(lpTokenId)
	if !exist {
		panic(addDetailToError(
			errDataNotFound,
			ufmt.Sprintf("tokenId(%d) deposit does not exist", lpTokenId),
		))
	}

	return deposit.numberOfStakes
}
*/

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
	deposit := deposits.Get(lpTokenId)
	if deposit == nil {
		panic(ufmt.Sprintf("lpTokenId(%d) deposit does not exist", lpTokenId))
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
	deposit := deposits.Get(lpTokenId)
	if deposit == nil {
		panic(ufmt.Sprintf("lpTokenId(%d) deposit does not exist", lpTokenId))
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
	return poolTier.CurrentTier(poolPath, uint64(std.GetHeight()))
}
