package launchpad

import (
	"errors"

	"gno.land/r/gnoswap/launchpad"

	gnsmath "gno.land/p/gnoswap/gnsmath"
	u256 "gno.land/p/gnoswap/uint256"
)

// Helper functions for RewardState

func isRewardStateClaimable(r *launchpad.RewardState, currentTime int64) bool {
	return currentTime >= r.ClaimableTime()
}

// calculateReward computes total accrued reward from the Q128 accumulator and price debt.
//
// Parameters:
//   - r: reward state containing deposit amount and Q128 price debt.
//   - accumRewardPerDepositX128: current accumulated reward per deposit scaled by 2^128.
//
// Returns:
//   - amount: accrued reward-token amount after Q128 conversion, or zero when inputs are nil or no reward accrued.
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
		panic(errors.New(errOverflow))
	}
	reward = reward.Rsh(reward, 128)
	return gnsmath.SafeConvertToInt64(reward)
}

// calculateClaimableReward computes accrued reward not already marked as claimed.
//
// Parameters:
//   - r: reward state containing deposit amount and claimed amount.
//   - accumRewardPerDepositX128: current accumulated reward per deposit scaled by 2^128.
//
// Returns:
//   - amount: accrued amount minus claimed amount, or zero when nothing remains claimable.
func calculateClaimableReward(r *launchpad.RewardState, accumRewardPerDepositX128 *u256.Uint) int64 {
	if accumRewardPerDepositX128 == nil {
		return 0
	}

	reward := calculateReward(r, accumRewardPerDepositX128)
	claimedAmount := r.ClaimedAmount()

	if reward <= claimedAmount {
		return 0
	}

	return reward - claimedAmount
}
