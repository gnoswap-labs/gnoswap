package staker

import (
	u256 "gno.land/p/gnoswap/uint256"
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

func (e *EmissionRewardState) GetRewardDebtX128() *u256.Uint     { return e.rewardDebtX128 }
func (e *EmissionRewardState) GetAccumulatedRewardAmount() int64 { return e.accumulatedRewardAmount }
func (e *EmissionRewardState) GetAccumulatedTimestamp() int64    { return e.accumulatedTimestamp }
func (e *EmissionRewardState) GetClaimedRewardAmount() int64     { return e.claimedRewardAmount }
func (e *EmissionRewardState) GetClaimedTimestamp() int64        { return e.claimedTimestamp }
func (e *EmissionRewardState) GetStakedAmount() int64            { return e.stakedAmount }

/* Setters */
func (e *EmissionRewardState) SetRewardDebtX128(rewardDebtX128 *u256.Uint) {
	e.rewardDebtX128 = rewardDebtX128
}

func (e *EmissionRewardState) SetAccumulatedRewardAmount(accumulatedRewardAmount int64) {
	e.accumulatedRewardAmount = accumulatedRewardAmount
}

func (e *EmissionRewardState) SetAccumulatedTimestamp(accumulatedTimestamp int64) {
	e.accumulatedTimestamp = accumulatedTimestamp
}

func (e *EmissionRewardState) SetClaimedRewardAmount(claimedRewardAmount int64) {
	e.claimedRewardAmount = claimedRewardAmount
}

func (e *EmissionRewardState) SetClaimedTimestamp(claimedTimestamp int64) {
	e.claimedTimestamp = claimedTimestamp
}

func (e *EmissionRewardState) SetStakedAmount(stakedAmount int64) {
	e.stakedAmount = stakedAmount
}
