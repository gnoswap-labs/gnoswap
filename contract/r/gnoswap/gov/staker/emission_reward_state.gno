package staker

import (
	u256 "gno.land/p/gnoswap/uint256/v1"
)

// EmissionRewardState tracks emission reward information for an individual staker.
// This struct maintains reward debt, accumulated rewards, and claiming history
// to ensure accurate reward calculations and prevent double-claiming.
type EmissionRewardState struct {
	// rewardDebtX128 represents the reward debt with 128-bit precision scaling
	// Used to calculate rewards earned since the last update
	rewardDebtX128 *u256.Uint
	// accumulatedRewardAmount is the total rewards accumulated but not yet claimed
	accumulatedRewardAmount int64
	// accumulatedTimestamp is the last timestamp when rewards were accumulated
	accumulatedTimestamp int64
	// claimedRewardAmount is the total amount of rewards that have been claimed
	claimedRewardAmount int64
	// claimedTimestamp is the last timestamp when rewards were claimed
	claimedTimestamp int64
	// stakedAmount is the current amount of tokens staked by this address
	stakedAmount int64
}

// NewEmissionRewardState creates a new emission reward state for a staker.
// This factory function initializes the state with the current system reward debt.
//
// Parameters:
//   - accumulatedRewardX128PerStake: current system-wide accumulated reward per stake
//
// Returns:
//   - *EmissionRewardState: new emission reward state instance
func NewEmissionRewardState(accumulatedRewardX128PerStake *u256.Uint) *EmissionRewardState {
	return &EmissionRewardState{
		// Deep copy the input to snapshot the current accumulator value.
		rewardDebtX128:          accumulatedRewardX128PerStake.Clone(),
		accumulatedRewardAmount: 0,
		accumulatedTimestamp:    0,
		claimedRewardAmount:     0,
		claimedTimestamp:        0,
		stakedAmount:            0,
	}
}

/* Getters */

// GetRewardDebtX128 returns the scaled reward debt used for accrual calculations.
//
// Returns:
//   - *u256.Uint: current reward debt in the protocol's 128-bit fixed-point scale.
func (e *EmissionRewardState) GetRewardDebtX128() *u256.Uint { return e.rewardDebtX128 }

// GetAccumulatedRewardAmount returns rewards accrued but not yet claimed.
//
// Returns:
//   - int64: accumulated reward amount in the smallest token unit.
func (e *EmissionRewardState) GetAccumulatedRewardAmount() int64 { return e.accumulatedRewardAmount }

// GetAccumulatedTimestamp returns when accumulated rewards were last updated.
//
// Returns:
//   - int64: Unix timestamp in seconds of the last accumulation update.
func (e *EmissionRewardState) GetAccumulatedTimestamp() int64 { return e.accumulatedTimestamp }

// GetClaimedRewardAmount returns the total rewards already claimed.
//
// Returns:
//   - int64: claimed reward amount in the smallest token unit.
func (e *EmissionRewardState) GetClaimedRewardAmount() int64 { return e.claimedRewardAmount }

// GetClaimedTimestamp returns when rewards were last claimed.
//
// Returns:
//   - int64: Unix timestamp in seconds of the last claim.
func (e *EmissionRewardState) GetClaimedTimestamp() int64 { return e.claimedTimestamp }

// GetStakedAmount returns the amount currently staked for this state.
//
// Returns:
//   - int64: staked token amount in the smallest token unit.
func (e *EmissionRewardState) GetStakedAmount() int64 { return e.stakedAmount }

/* Setters */
// SetRewardDebtX128 replaces the reward debt with a copied fixed-point value.
//
// Parameters:
//   - rewardDebtX128: reward debt in the protocol's 128-bit fixed-point scale.
func (e *EmissionRewardState) SetRewardDebtX128(rewardDebtX128 *u256.Uint) {
	e.rewardDebtX128 = u256.Zero().Set(rewardDebtX128)
}

// SetAccumulatedRewardAmount replaces the unclaimed accumulated reward amount.
//
// Parameters:
//   - accumulatedRewardAmount: accumulated reward in the smallest token unit.
func (e *EmissionRewardState) SetAccumulatedRewardAmount(accumulatedRewardAmount int64) {
	e.accumulatedRewardAmount = accumulatedRewardAmount
}

// SetAccumulatedTimestamp records the latest reward accumulation timestamp.
//
// Parameters:
//   - accumulatedTimestamp: Unix timestamp in seconds for the accumulation update.
func (e *EmissionRewardState) SetAccumulatedTimestamp(accumulatedTimestamp int64) {
	e.accumulatedTimestamp = accumulatedTimestamp
}

// SetClaimedRewardAmount replaces the total claimed reward amount.
//
// Parameters:
//   - claimedRewardAmount: claimed reward in the smallest token unit.
func (e *EmissionRewardState) SetClaimedRewardAmount(claimedRewardAmount int64) {
	e.claimedRewardAmount = claimedRewardAmount
}

// SetClaimedTimestamp records the latest reward claim timestamp.
//
// Parameters:
//   - claimedTimestamp: Unix timestamp in seconds for the claim.
func (e *EmissionRewardState) SetClaimedTimestamp(claimedTimestamp int64) {
	e.claimedTimestamp = claimedTimestamp
}

// SetStakedAmount replaces the current staked amount.
// Parameters:
//   - stakedAmount: staked token amount in the smallest token unit.
func (e *EmissionRewardState) SetStakedAmount(stakedAmount int64) {
	e.stakedAmount = stakedAmount
}
