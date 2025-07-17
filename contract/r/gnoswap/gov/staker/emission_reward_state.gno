package staker

import (
	"errors"

	u256 "gno.land/p/gnoswap/uint256"
)

type EmissionRewardState struct {
	rewardDebtX128          *u256.Uint
	accumulatedRewardAmount int64
	accumulatedHeight       int64
	claimedRewardAmount     int64
	claimedHeight           int64
	stakedAmount            int64
}

func (e *EmissionRewardState) IsClaimable(currentHeight int64) bool {
	return e.claimedHeight < currentHeight
}

func (e *EmissionRewardState) GetClaimableRewardAmount(
	accumulatedRewardX128PerStake *u256.Uint,
	currentHeight int64,
) int64 {
	rewardAmount := e.calculateClaimableRewards(accumulatedRewardX128PerStake, currentHeight)

	return e.accumulatedRewardAmount + rewardAmount
}

func (e *EmissionRewardState) calculateClaimableRewards(
	accumulatedRewardX128PerStake *u256.Uint,
	currentHeight int64,
) int64 {
	if e.accumulatedHeight > currentHeight {
		return 0
	}

	rewardDebtDeltaX128 := u256.Zero().Sub(
		accumulatedRewardX128PerStake,
		e.rewardDebtX128,
	)
	rewardAmountX128 := u256.Zero().Mul(
		rewardDebtDeltaX128,
		u256.NewUintFromInt64(e.stakedAmount),
	)

	return u256.Zero().Rsh(rewardAmountX128, 128).Int64()
}

func (e *EmissionRewardState) addStake(amount int64) {
	e.stakedAmount = e.stakedAmount + amount
}

func (e *EmissionRewardState) removeStake(amount int64) {
	e.stakedAmount = e.stakedAmount - amount
}

func (e *EmissionRewardState) claimRewards(currentHeight int64) (int64, error) {
	if !e.IsClaimable(currentHeight) {
		return 0, errors.New("not claimable")
	}

	claimedRewardAmount := e.accumulatedRewardAmount - e.claimedRewardAmount
	e.claimedRewardAmount = e.accumulatedRewardAmount
	e.claimedHeight = currentHeight

	return claimedRewardAmount, nil
}

func (e *EmissionRewardState) updateRewardDebtX128(
	accumulatedRewardX128PerStake *u256.Uint,
	currentHeight int64,
) {
	rewardAmount := e.calculateClaimableRewards(accumulatedRewardX128PerStake, currentHeight)

	e.accumulatedRewardAmount = e.accumulatedRewardAmount + rewardAmount
	e.rewardDebtX128 = accumulatedRewardX128PerStake
	e.accumulatedHeight = currentHeight
}

func (e *EmissionRewardState) addStakeWithUpdateRewardDebtX128(
	amount int64,
	accumulatedRewardX128PerStake *u256.Uint,
	currentHeight int64,
) {
	e.updateRewardDebtX128(accumulatedRewardX128PerStake, currentHeight)
	e.addStake(amount)
}

func (e *EmissionRewardState) removeStakeWithUpdateRewardDebtX128(
	amount int64,
	accumulatedRewardX128PerStake *u256.Uint,
	currentHeight int64,
) {
	e.updateRewardDebtX128(accumulatedRewardX128PerStake, currentHeight)
	e.removeStake(amount)
}

func (e *EmissionRewardState) claimRewardsWithUpdateRewardDebtX128(
	accumulatedRewardX128PerStake *u256.Uint,
	currentHeight int64,
) (int64, error) {
	e.updateRewardDebtX128(accumulatedRewardX128PerStake, currentHeight)
	return e.claimRewards(currentHeight)
}

func NewEmissionRewardState(accumulatedRewardX128PerStake *u256.Uint) *EmissionRewardState {
	return &EmissionRewardState{
		rewardDebtX128:          accumulatedRewardX128PerStake,
		accumulatedRewardAmount: 0,
		accumulatedHeight:       0,
		claimedRewardAmount:     0,
		claimedHeight:           0,
		stakedAmount:            0,
	}
}
