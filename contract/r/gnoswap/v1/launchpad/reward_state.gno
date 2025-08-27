package launchpad

import (
	u256 "gno.land/p/gnoswap/uint256"
)

// RewardState represents the state of a reward for a deposit.
// It contains the necessary data to manage and distribute rewards for a specific deposit.
type RewardState struct {
	priceDebtX128 *u256.Uint // price debt per GNS stake, Q128
	claimableTime int64      // time when reward can be claimed

	depositAmount           int64 // amount of GNS staked
	distributeStartTime     int64 // time when launchpad started staking
	distributeEndTime       int64 // end time of reward calculation
	accumulatedRewardAmount int64 // calculated, not collected
	accumulatedHeight       int64 // last height when reward was calculated
	accumulatedTime         int64 // last time when reward was calculated
	claimedAmount           int64 // amount of reward claimed so far
}

func (r *RewardState) PriceDebtX128() *u256.Uint {
	return r.priceDebtX128
}

func (r *RewardState) setPriceDebtX128(v *u256.Uint) {
	r.priceDebtX128 = v
}

func (r *RewardState) DepositAmount() int64 {
	return r.depositAmount
}

func (r *RewardState) setDepositAmount(v int64) {
	r.depositAmount = v
}

func (r *RewardState) AccumulatedRewardAmount() int64 {
	return r.accumulatedRewardAmount
}

func (r *RewardState) setAccumulatedRewardAmount(v int64) {
	r.accumulatedRewardAmount = v
}

func (r *RewardState) ClaimedAmount() int64 {
	return r.claimedAmount
}

func (r *RewardState) setClaimedAmount(v int64) {
	r.claimedAmount = v
}

func (r *RewardState) DistributeStartTime() int64 {
	return r.distributeStartTime
}

func (r *RewardState) setDistributeStartTime(v int64) {
	r.distributeStartTime = v
}

func (r *RewardState) DistributeEndTime() int64 {
	return r.distributeEndTime
}

func (r *RewardState) setDistributeEndTime(v int64) {
	r.distributeEndTime = v
}

func (r *RewardState) AccumulatedHeight() int64 {
	return r.accumulatedHeight
}

func (r *RewardState) setAccumulatedHeight(v int64) {
	r.accumulatedHeight = v
}

func (r *RewardState) AccumulatedTime() int64 {
	return r.accumulatedTime
}

func (r *RewardState) setAccumulatedTime(v int64) {
	r.accumulatedTime = v
}

func (r *RewardState) IsClaimable(currentTime int64) bool {
	return currentTime >= r.claimableTime
}

func (r *RewardState) ClaimableTime() int64 {
	return r.claimableTime
}

func (r *RewardState) setClaimableTime(v int64) {
	r.claimableTime = v
}

// calculateReward calculates the total reward amount based on
// the accumulated reward per deposit.
// Returns the total reward amount.
func (r *RewardState) calculateReward(accumRewardPerDepositX128 *u256.Uint) int64 {
	if accumRewardPerDepositX128 == nil || r.PriceDebtX128() == nil {
		return 0
	}

	actualRewardPerDepositX128 := u256.Zero().Sub(accumRewardPerDepositX128, r.PriceDebtX128())
	if actualRewardPerDepositX128.IsZero() {
		return 0
	}

	reward := u256.Zero().Mul(actualRewardPerDepositX128, u256.NewUintFromInt64(r.DepositAmount()))
	reward = u256.Zero().Rsh(reward, 128)

	return safeConvertToInt64(reward)
}

// calculateClaimableReward calculates the amount of reward that can be claimed
// based on the current accumulated reward per deposit.
// Returns the amount of reward that can be claimed.
func (r *RewardState) calculateClaimableReward(accumRewardPerDepositX128 *u256.Uint) int64 {
	if accumRewardPerDepositX128 == nil {
		return 0
	}

	// Return 0 if accumulated reward is less than price debt
	if accumRewardPerDepositX128.Lt(r.priceDebtX128) {
		return 0
	}

	reward := r.calculateReward(accumRewardPerDepositX128)
	claimedAmount := r.ClaimedAmount()

	if reward <= claimedAmount {
		return 0
	}

	return reward - claimedAmount
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
		priceDebtX128:           accumulatedRewardPerDepositX128,
		depositAmount:           depositAmount,
		distributeStartTime:     distributeStartTime,
		distributeEndTime:       distributeEndTime,
		claimableTime:           claimableTime,
		accumulatedRewardAmount: 0,
		claimedAmount:           0,
		accumulatedHeight:       0,
	}
}
