package launchpad

import (
	u256 "gno.land/p/gnoswap/uint256"
)

// RewardState represents the state of a reward for a deposit.
// It contains the necessary data to manage and distribute rewards for a specific deposit.
type RewardState struct {
	priceDebtX128    u256.Uint // price debt per GNS stake, Q128
	priceDebtX128Set bool      // preserves legacy nil vs present-zero state
	claimableTime    int64     // time when reward can be claimed

	depositAmount           int64 // amount of GNS staked
	distributeStartTime     int64 // time when launchpad started staking
	distributeEndTime       int64 // end time of reward calculation
	accumulatedRewardAmount int64 // calculated, not collected
	accumulatedTime         int64 // last time when reward was calculated
	claimedAmount           int64 // amount of reward claimed so far
}

// NewRewardState returns a pointer to a new RewardState with the given values.
func NewRewardState(
	accumulatedRewardPerDepositX128 *u256.Uint,
	depositAmount,
	distributeStartTime,
	distributeEndTime int64,
	claimableTime int64,
) *RewardState {
	priceDebtX128 := u256.Uint{}
	priceDebtX128Set := accumulatedRewardPerDepositX128 != nil
	if priceDebtX128Set {
		priceDebtX128.Set(accumulatedRewardPerDepositX128)
	}
	return &RewardState{
		priceDebtX128:           priceDebtX128,
		priceDebtX128Set:        priceDebtX128Set,
		depositAmount:           depositAmount,
		distributeStartTime:     distributeStartTime,
		distributeEndTime:       distributeEndTime,
		claimableTime:           claimableTime,
		accumulatedRewardAmount: 0,
		claimedAmount:           0,
	}
}

// PriceDebtX128 returns a detached price debt (Q128) copy of the reward state.
func (rs *RewardState) PriceDebtX128() *u256.Uint {
	if !rs.priceDebtX128Set {
		return nil
	}
	return rs.priceDebtX128.Clone()
}

// SetPriceDebtX128 sets the price debt (Q128) of the reward state.
func (rs *RewardState) SetPriceDebtX128(debt *u256.Uint) {
	rs.priceDebtX128.Set(debt)
	rs.priceDebtX128Set = true
}

// ClaimableTime returns the claimable time of the reward state.
func (rs *RewardState) ClaimableTime() int64 {
	return rs.claimableTime
}

// SetClaimableTime sets the claimable time of the reward state.
func (rs *RewardState) SetClaimableTime(time int64) {
	rs.claimableTime = time
}

// DepositAmount returns the deposit amount of the reward state.
func (rs *RewardState) DepositAmount() int64 {
	return rs.depositAmount
}

// SetDepositAmount sets the deposit amount of the reward state.
func (rs *RewardState) SetDepositAmount(amount int64) {
	rs.depositAmount = amount
}

// DistributeStartTime returns the distribute start time of the reward state.
func (rs *RewardState) DistributeStartTime() int64 {
	return rs.distributeStartTime
}

// SetDistributeStartTime sets the distribute start time of the reward state.
func (rs *RewardState) SetDistributeStartTime(time int64) {
	rs.distributeStartTime = time
}

// DistributeEndTime returns the distribute end time of the reward state.
func (rs *RewardState) DistributeEndTime() int64 {
	return rs.distributeEndTime
}

// SetDistributeEndTime sets the distribute end time of the reward state.
func (rs *RewardState) SetDistributeEndTime(time int64) {
	rs.distributeEndTime = time
}

// AccumulatedRewardAmount returns the accumulated reward amount of the reward state.
func (rs *RewardState) AccumulatedRewardAmount() int64 {
	return rs.accumulatedRewardAmount
}

// SetAccumulatedRewardAmount sets the accumulated reward amount of the reward state.
func (rs *RewardState) SetAccumulatedRewardAmount(amount int64) {
	rs.accumulatedRewardAmount = amount
}

// AccumulatedTime returns the accumulated time of the reward state.
func (rs *RewardState) AccumulatedTime() int64 {
	return rs.accumulatedTime
}

// SetAccumulatedTime sets the accumulated time of the reward state.
func (rs *RewardState) SetAccumulatedTime(time int64) {
	rs.accumulatedTime = time
}

// ClaimedAmount returns the claimed amount of the reward state.
func (rs *RewardState) ClaimedAmount() int64 {
	return rs.claimedAmount
}

// SetClaimedAmount sets the claimed amount of the reward state.
func (rs *RewardState) SetClaimedAmount(amount int64) {
	rs.claimedAmount = amount
}

func (rs RewardState) Clone() *RewardState {
	if !rs.priceDebtX128Set {
		panic("cannot clone absent reward state price debt")
	}
	return &RewardState{
		priceDebtX128:           rs.priceDebtX128,
		priceDebtX128Set:        rs.priceDebtX128Set,
		depositAmount:           rs.depositAmount,
		distributeStartTime:     rs.distributeStartTime,
		distributeEndTime:       rs.distributeEndTime,
		accumulatedRewardAmount: rs.accumulatedRewardAmount,
		accumulatedTime:         rs.accumulatedTime,
		claimedAmount:           rs.claimedAmount,
	}
}
