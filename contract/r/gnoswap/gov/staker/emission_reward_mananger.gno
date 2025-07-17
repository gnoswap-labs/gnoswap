package staker

import (
	"gno.land/p/demo/avl"
	u256 "gno.land/p/gnoswap/uint256"
)

type EmissionRewardManager struct {
	rewardStates *avl.Tree // address -> EmissionRewardState

	accumulatedRewardX128PerStake *u256.Uint
	distributedAmount             int64
	accumulatedHeight             int64
	totalStakedAmount             int64
}

func (e *EmissionRewardManager) GetAccumulatedRewardX128PerStake() *u256.Uint {
	return e.accumulatedRewardX128PerStake
}

func (e *EmissionRewardManager) GetAccumulatedHeight() int64 {
	return e.accumulatedHeight
}

func (e *EmissionRewardManager) GetTotalStakedAmount() int64 {
	return e.totalStakedAmount
}

func (e *EmissionRewardManager) GetDistributedAmount() int64 {
	return e.distributedAmount
}

func (e *EmissionRewardManager) GetClaimableRewardAmount(
	currentDistributedAmount int64,
	address string,
	currentHeight int64,
) int64 {
	rewardStateI, ok := e.rewardStates.Get(address)
	if !ok {
		return 0
	}

	rewardState := rewardStateI.(*EmissionRewardState)
	accumulatedRewardX128PerStake := e.calculateAccumulatedRewardX128PerStake(currentDistributedAmount, currentHeight)

	return rewardState.GetClaimableRewardAmount(accumulatedRewardX128PerStake, currentHeight)
}

func (e *EmissionRewardManager) calculateAccumulatedRewardX128PerStake(
	currentDistributedAmount int64,
	currentHeight int64,
) *u256.Uint {
	if e.accumulatedHeight > currentHeight {
		return e.accumulatedRewardX128PerStake
	}

	if e.totalStakedAmount == 0 {
		return e.accumulatedRewardX128PerStake
	}

	distributedAmountDelta := currentDistributedAmount - e.distributedAmount
	distributedAmountDeltaX128 := u256.NewUintFromInt64(distributedAmountDelta)
	distributedAmountDeltaX128 = distributedAmountDeltaX128.Lsh(distributedAmountDeltaX128, 128)

	distributedAmountDeltaX128PerStake := u256.Zero().Div(
		distributedAmountDeltaX128,
		u256.NewUintFromInt64(e.totalStakedAmount),
	)

	accumulatedRewardX128PerStake := u256.Zero().Add(
		e.accumulatedRewardX128PerStake,
		distributedAmountDeltaX128PerStake,
	)

	return accumulatedRewardX128PerStake
}

func (e *EmissionRewardManager) updateAccumulatedRewardX128PerStake(
	currentDistributedAmount int64,
	currentHeight int64,
) {
	if e.accumulatedHeight > currentHeight {
		return
	}

	if e.totalStakedAmount == 0 {
		return
	}

	e.accumulatedRewardX128PerStake = e.calculateAccumulatedRewardX128PerStake(
		currentDistributedAmount, 
		currentHeight,
	)
	e.distributedAmount = currentDistributedAmount
	e.accumulatedHeight = currentHeight
}

func (e *EmissionRewardManager) addStake(address string, amount int64, currentHeight int64) {
	rewardStateI, ok := e.rewardStates.Get(address)
	if !ok {
		rewardStateI = NewEmissionRewardState(e.accumulatedRewardX128PerStake)
	}

	rewardState := rewardStateI.(*EmissionRewardState)
	rewardState.addStakeWithUpdateRewardDebtX128(amount, e.accumulatedRewardX128PerStake, currentHeight)

	e.rewardStates.Set(address, rewardState)

	e.totalStakedAmount = e.totalStakedAmount + amount
}

func (e *EmissionRewardManager) removeStake(address string, amount int64, currentHeight int64) {
	rewardStateI, ok := e.rewardStates.Get(address)
	if !ok {
		rewardStateI = NewEmissionRewardState(e.accumulatedRewardX128PerStake.Clone())
	}

	rewardState := rewardStateI.(*EmissionRewardState)
	rewardState.removeStakeWithUpdateRewardDebtX128(amount, e.accumulatedRewardX128PerStake, currentHeight)

	e.rewardStates.Set(address, rewardState)

	e.totalStakedAmount = e.totalStakedAmount - amount
}

func (e *EmissionRewardManager) claimRewards(address string, currentHeight int64) (int64, error) {
	rewardStateI, ok := e.rewardStates.Get(address)
	if !ok {
		return 0, nil
	}

	rewardState := rewardStateI.(*EmissionRewardState)
	
	claimedRewardAmount, err := rewardState.claimRewardsWithUpdateRewardDebtX128(e.accumulatedRewardX128PerStake, currentHeight)
	if err != nil {
		return 0, err
	}

	e.rewardStates.Set(address, rewardState)

	return claimedRewardAmount, nil
}

func NewEmissionRewardManager() *EmissionRewardManager {
	return &EmissionRewardManager{
		accumulatedRewardX128PerStake: u256.NewUint(0),
		accumulatedHeight:             0,
		totalStakedAmount:             0,
		distributedAmount:             0,
		rewardStates:                  avl.NewTree(),
	}
}
