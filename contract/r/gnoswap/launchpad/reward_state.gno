package launchpad

import (
	u256 "gno.land/p/gnoswap/uint256"
	"gno.land/p/gnoswap/utils"
)

// RewardState represents the state of a reward for a deposit.
// It contains the necessary data to manage and distribute rewards for a specific deposit.
//
// priceDebtX128 is persisted as one fixed-width 32-byte big-endian string.
// The public API remains *uint256.Uint so callers do not depend on storage layout.
type RewardState struct {
	priceDebtX128 string // 32-byte big-endian Q128 price debt
	claimableTime int64  // time when reward can be claimed

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
	return &RewardState{
		priceDebtX128:           utils.EncodeUint256(accumulatedRewardPerDepositX128),
		depositAmount:           depositAmount,
		distributeStartTime:     distributeStartTime,
		distributeEndTime:       distributeEndTime,
		claimableTime:           claimableTime,
		accumulatedRewardAmount: 0,
		claimedAmount:           0,
	}
}

// PriceDebtX128 returns a fresh public value decoded from the persisted debt.
func (rs *RewardState) PriceDebtX128() *u256.Uint {
	return utils.DecodeUint256(rs.priceDebtX128)
}

// SetPriceDebtX128 stores the debt in its fixed-width binary representation.
func (rs *RewardState) SetPriceDebtX128(debt *u256.Uint) {
	rs.priceDebtX128 = utils.EncodeUint256(debt)
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
	return &RewardState{
		priceDebtX128:           rs.priceDebtX128,
		claimableTime:           rs.claimableTime,
		depositAmount:           rs.depositAmount,
		distributeStartTime:     rs.distributeStartTime,
		distributeEndTime:       rs.distributeEndTime,
		accumulatedRewardAmount: rs.accumulatedRewardAmount,
		accumulatedTime:         rs.accumulatedTime,
		claimedAmount:           rs.claimedAmount,
	}
}
