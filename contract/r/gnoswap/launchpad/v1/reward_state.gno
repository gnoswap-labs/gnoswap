package v1

import (
	"gno.land/r/gnoswap/launchpad"

	u256 "gno.land/p/gnoswap/uint256"
)

// Helper functions for RewardState

func isRewardStateClaimable(r *launchpad.RewardState, currentTime int64) bool {
	return currentTime >= r.ClaimableTime()
}

// calculateReward calculates the total reward amount based on
// the accumulated reward per deposit.
// Returns the total reward amount.
func calculateReward(r *launchpad.RewardState, accumRewardPerDepositX128 *u256.Uint) int64 {
	if accumRewardPerDepositX128 == nil || r.PriceDebtX128() == nil {
		return 0
	}

	actualRewardPerDepositX128 := u256.Zero().Sub(accumRewardPerDepositX128, r.PriceDebtX128())
	if actualRewardPerDepositX128.IsZero() {
		return 0
	}

	reward, overflow := u256.Zero().MulOverflow(actualRewardPerDepositX128, u256.NewUintFromInt64(r.DepositAmount()))
	if overflow {
		panic(errOverflow)
	}
	reward = u256.Zero().Rsh(reward, 128)

	return safeConvertToInt64(reward)
}

// calculateClaimableReward calculates the amount of reward that can be claimed
// based on the current accumulated reward per deposit.
// Returns the amount of reward that can be claimed.
func calculateClaimableReward(r *launchpad.RewardState, accumRewardPerDepositX128 *u256.Uint) int64 {
	if accumRewardPerDepositX128 == nil {
		return 0
	}

	// Return 0 if accumulated reward is less than price debt
	if accumRewardPerDepositX128.Lt(r.PriceDebtX128()) {
		return 0
	}

	reward := calculateReward(r, accumRewardPerDepositX128)
	claimedAmount := r.ClaimedAmount()

	if reward <= claimedAmount {
		return 0
	}

	return reward - claimedAmount
}

// NewRewardState returns a pointer to a new RewardState with the given values.
func newRewardState(
	accumulatedRewardPerDepositX128 *u256.Uint,
	depositAmount,
	distributeStartTime,
	distributeEndTime int64,
	claimableTime int64,
) *launchpad.RewardState {
	return launchpad.NewRewardState(
		accumulatedRewardPerDepositX128,
		depositAmount,
		distributeStartTime,
		distributeEndTime,
		claimableTime,
	)
}
