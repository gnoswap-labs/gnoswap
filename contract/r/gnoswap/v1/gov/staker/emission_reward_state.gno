package staker

import (
	"errors"

	u256 "gno.land/p/gnoswap/uint256"
)

var errNotClaimable = errors.New("not claimable")

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

// IsClaimable checks if rewards can be claimed at the given timestamp.
// Rewards are claimable if the current timestamp is greater than the last claimed timestamp.
//
// Parameters:
//   - currentTimestamp: current timestamp to check against
//
// Returns:
//   - bool: true if rewards can be claimed, false otherwise
func (e *EmissionRewardState) IsClaimable(currentTimestamp int64) bool {
	return e.claimedTimestamp < currentTimestamp
}

// GetClaimableRewardAmount calculates the total amount of rewards that can be claimed.
// This includes both accumulated rewards and newly earned rewards based on current state.
//
// Parameters:
//   - accumulatedRewardX128PerStake: current system-wide accumulated reward per stake
//   - currentTimestamp: current timestamp
//
// Returns:
//   - int64: total claimable reward amount
func (e *EmissionRewardState) GetClaimableRewardAmount(
	accumulatedRewardX128PerStake *u256.Uint,
	currentTimestamp int64,
) (int64, error) {
	rewardAmount, err := e.calculateClaimableRewards(accumulatedRewardX128PerStake, currentTimestamp)
	if err != nil {
		return 0, err
	}
	return e.accumulatedRewardAmount + rewardAmount, nil
}

// calculateClaimableRewards calculates newly earned rewards since the last update.
// Uses the difference between current and stored reward debt to calculate earnings.
//
// Parameters:
//   - accumulatedRewardX128PerStake: current system-wide accumulated reward per stake
//   - currentTimestamp: current timestamp
//
// Returns:
//   - int64: newly earned reward amount since last update
//   - error: nil on success, error if calculation fails
func (e *EmissionRewardState) calculateClaimableRewards(
	accumulatedRewardX128PerStake *u256.Uint,
	currentTimestamp int64,
) (int64, error) {
	// Don't calculate rewards for past timestamps or when nothing is staked
	if currentTimestamp < e.accumulatedTimestamp || e.stakedAmount == 0 {
		return 0, nil
	}

	// Calculate the difference in accumulated rewards per stake since last update
	// Using modular arithmetic for accumulator values - underflow is allowed and handled correctly
	rewardDebtDeltaX128 := u256.Zero().Sub(
		accumulatedRewardX128PerStake,
		e.rewardDebtX128,
	)

	// Calculate reward amount by multiplying reward debt delta by staked amount and dividing by Q128
	// rewardAmount = (rewardDebtDeltaX128 * stakedAmount) / Q128
	rewardAmount := u256.MulDiv(
		rewardDebtDeltaX128,
		u256.NewUintFromInt64(e.stakedAmount),
		q128,
	)
	return safeConvertToInt64(rewardAmount), nil
}

// addStake increases the staked amount for this address.
// This method should be called when a user increases their stake.
//
// Parameters:
//   - amount: amount of stake to add
func (e *EmissionRewardState) addStake(amount int64) {
	e.adjustStake(amount)
}

// removeStake decreases the staked amount for this address.
// This method should be called when a user decreases their stake.
//
// Parameters:
//   - amount: amount of stake to remove
func (e *EmissionRewardState) removeStake(amount int64) {
	e.adjustStake(-amount)
}

// adjustStake is a small internal helper to centralize bound checks and math.
func (e *EmissionRewardState) adjustStake(delta int64) {
	if delta == 0 {
		return
	}
	// clamp at zero on underflow
	newAmt := e.stakedAmount + delta
	if newAmt < 0 {
		newAmt = 0
	}
	e.stakedAmount = newAmt
}

// claimRewards processes reward claiming and updates the claim state.
// This method validates claimability and transfers accumulated rewards to claimed status.
//
// Parameters:
//   - currentTimestamp: current timestamp
//
// Returns:
//   - int64: amount of rewards claimed
//   - error: nil on success, error if claiming is not allowed
func (e *EmissionRewardState) claimRewards(currentTimestamp int64) (int64, error) {
	if !e.IsClaimable(currentTimestamp) {
		return 0, errNotClaimable
	}
	claimedRewardAmount := e.accumulatedRewardAmount - e.claimedRewardAmount
	e.claimedRewardAmount = e.accumulatedRewardAmount
	e.claimedTimestamp = currentTimestamp
	return claimedRewardAmount, nil
}

// updateRewardDebtX128 updates the reward debt and accumulates new rewards.
// This method should be called before any stake changes to ensure accurate reward tracking.
//
// Parameters:
//   - accumulatedRewardX128PerStake: current system-wide accumulated reward per stake
//   - currentTimestamp: current timestamp
func (e *EmissionRewardState) updateRewardDebtX128(
	accumulatedRewardX128PerStake *u256.Uint,
	currentTimestamp int64,
) error {
	rewardAmount, err := e.calculateClaimableRewards(accumulatedRewardX128PerStake, currentTimestamp)
	if err != nil {
		return err
	}

	// Accumulate newly earned rewards
	if rewardAmount != 0 {
		e.accumulatedRewardAmount += rewardAmount
	}

	// Deep copy to avoid aliasing with external state
	e.rewardDebtX128 = accumulatedRewardX128PerStake.Clone()
	e.accumulatedTimestamp = currentTimestamp
	return nil
}

// addStakeWithUpdateRewardDebtX128 adds stake and updates reward debt in one operation.
// This ensures rewards are properly calculated before the stake change takes effect.
//
// Parameters:
//   - amount: amount of stake to add
//   - accumulatedRewardX128PerStake: current system-wide accumulated reward per stake
//   - currentTimestamp: current timestamp
func (e *EmissionRewardState) addStakeWithUpdateRewardDebtX128(
	amount int64,
	accumulatedRewardX128PerStake *u256.Uint,
	currentTimestamp int64,
) error {
	if err := e.updateRewardDebtX128(accumulatedRewardX128PerStake, currentTimestamp); err != nil {
		return err
	}
	e.addStake(amount)
	return nil
}

// removeStakeWithUpdateRewardDebtX128 removes stake and updates reward debt in one operation.
// This ensures rewards are properly calculated before the stake change takes effect.
//
// Parameters:
//   - amount: amount of stake to remove
//   - accumulatedRewardX128PerStake: current system-wide accumulated reward per stake
//   - currentTimestamp: current timestamp
func (e *EmissionRewardState) removeStakeWithUpdateRewardDebtX128(
	amount int64,
	accumulatedRewardX128PerStake *u256.Uint,
	currentTimestamp int64,
) error {
	if err := e.updateRewardDebtX128(accumulatedRewardX128PerStake, currentTimestamp); err != nil {
		return err
	}
	e.removeStake(amount)
	return nil
}

// claimRewardsWithUpdateRewardDebtX128 claims rewards and updates reward debt in one operation.
// This ensures all rewards are properly calculated before claiming.
//
// Parameters:
//   - accumulatedRewardX128PerStake: current system-wide accumulated reward per stake
//   - currentTimestamp: current timestamp
//
// Returns:
//   - int64: amount of rewards claimed
//   - error: nil on success, error if claiming fails
func (e *EmissionRewardState) claimRewardsWithUpdateRewardDebtX128(
	accumulatedRewardX128PerStake *u256.Uint,
	currentTimestamp int64,
) (int64, error) {
	if err := e.updateRewardDebtX128(accumulatedRewardX128PerStake, currentTimestamp); err != nil {
		return 0, err
	}
	return e.claimRewards(currentTimestamp)
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
