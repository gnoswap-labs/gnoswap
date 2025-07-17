package staker

import (
	"errors"

	u256 "gno.land/p/gnoswap/uint256"
)

// EmissionRewardState tracks emission reward information for an individual staker.
// This struct maintains reward debt, accumulated rewards, and claiming history
// to ensure accurate reward calculations and prevent double-claiming.
type EmissionRewardState struct {
	// rewardDebtX128 represents the reward debt with 128-bit precision scaling
	// Used to calculate rewards earned since the last update
	rewardDebtX128          *u256.Uint
	// accumulatedRewardAmount is the total rewards accumulated but not yet claimed
	accumulatedRewardAmount int64
	// accumulatedHeight is the last block height when rewards were accumulated
	accumulatedHeight       int64
	// claimedRewardAmount is the total amount of rewards that have been claimed
	claimedRewardAmount     int64
	// claimedHeight is the last block height when rewards were claimed
	claimedHeight           int64
	// stakedAmount is the current amount of tokens staked by this address
	stakedAmount            int64
}

// IsClaimable checks if rewards can be claimed at the given height.
// Rewards are claimable if the current height is greater than the last claimed height.
//
// Parameters:
//   - currentHeight: current block height to check against
//
// Returns:
//   - bool: true if rewards can be claimed, false otherwise
func (e *EmissionRewardState) IsClaimable(currentHeight int64) bool {
	return e.claimedHeight < currentHeight
}

// GetClaimableRewardAmount calculates the total amount of rewards that can be claimed.
// This includes both accumulated rewards and newly earned rewards based on current state.
//
// Parameters:
//   - accumulatedRewardX128PerStake: current system-wide accumulated reward per stake
//   - currentHeight: current block height
//
// Returns:
//   - int64: total claimable reward amount
func (e *EmissionRewardState) GetClaimableRewardAmount(
	accumulatedRewardX128PerStake *u256.Uint,
	currentHeight int64,
) int64 {
	rewardAmount := e.calculateClaimableRewards(accumulatedRewardX128PerStake, currentHeight)

	return e.accumulatedRewardAmount + rewardAmount
}

// calculateClaimableRewards calculates newly earned rewards since the last update.
// This method uses the difference between current and stored reward debt to calculate earnings.
//
// Parameters:
//   - accumulatedRewardX128PerStake: current system-wide accumulated reward per stake
//   - currentHeight: current block height
//
// Returns:
//   - int64: newly earned reward amount since last update
func (e *EmissionRewardState) calculateClaimableRewards(
	accumulatedRewardX128PerStake *u256.Uint,
	currentHeight int64,
) int64 {
	// Don't calculate rewards for past heights
	if e.accumulatedHeight > currentHeight {
		return 0
	}

	// Calculate the difference in accumulated rewards per stake since last update
	rewardDebtDeltaX128 := u256.Zero().Sub(
		accumulatedRewardX128PerStake,
		e.rewardDebtX128,
	)
	
	// Multiply by staked amount to get total reward for this staker
	rewardAmountX128 := u256.Zero().Mul(
		rewardDebtDeltaX128,
		u256.NewUintFromInt64(e.stakedAmount),
	)

	// Scale down by 2^128 to get the actual reward amount
	return u256.Zero().Rsh(rewardAmountX128, 128).Int64()
}

// addStake increases the staked amount for this address.
// This method should be called when a user increases their stake.
//
// Parameters:
//   - amount: amount of stake to add
func (e *EmissionRewardState) addStake(amount int64) {
	e.stakedAmount = e.stakedAmount + amount
}

// removeStake decreases the staked amount for this address.
// This method should be called when a user decreases their stake.
//
// Parameters:
//   - amount: amount of stake to remove
func (e *EmissionRewardState) removeStake(amount int64) {
	e.stakedAmount = e.stakedAmount - amount
}

// claimRewards processes reward claiming and updates the claim state.
// This method validates claimability and transfers accumulated rewards to claimed status.
//
// Parameters:
//   - currentHeight: current block height
//
// Returns:
//   - int64: amount of rewards claimed
//   - error: nil on success, error if claiming is not allowed
func (e *EmissionRewardState) claimRewards(currentHeight int64) (int64, error) {
	if !e.IsClaimable(currentHeight) {
		return 0, errors.New("not claimable")
	}

	// Calculate the amount to claim (accumulated but not yet claimed)
	claimedRewardAmount := e.accumulatedRewardAmount - e.claimedRewardAmount
	e.claimedRewardAmount = e.accumulatedRewardAmount
	e.claimedHeight = currentHeight

	return claimedRewardAmount, nil
}

// updateRewardDebtX128 updates the reward debt and accumulates new rewards.
// This method should be called before any stake changes to ensure accurate reward tracking.
//
// Parameters:
//   - accumulatedRewardX128PerStake: current system-wide accumulated reward per stake
//   - currentHeight: current block height
func (e *EmissionRewardState) updateRewardDebtX128(
	accumulatedRewardX128PerStake *u256.Uint,
	currentHeight int64,
) {
	// Calculate and accumulate new rewards since last update
	rewardAmount := e.calculateClaimableRewards(accumulatedRewardX128PerStake, currentHeight)

	e.accumulatedRewardAmount = e.accumulatedRewardAmount + rewardAmount
	e.rewardDebtX128 = accumulatedRewardX128PerStake
	e.accumulatedHeight = currentHeight
}

// addStakeWithUpdateRewardDebtX128 adds stake and updates reward debt in one operation.
// This ensures rewards are properly calculated before the stake change takes effect.
//
// Parameters:
//   - amount: amount of stake to add
//   - accumulatedRewardX128PerStake: current system-wide accumulated reward per stake
//   - currentHeight: current block height
func (e *EmissionRewardState) addStakeWithUpdateRewardDebtX128(
	amount int64,
	accumulatedRewardX128PerStake *u256.Uint,
	currentHeight int64,
) {
	e.updateRewardDebtX128(accumulatedRewardX128PerStake, currentHeight)
	e.addStake(amount)
}

// removeStakeWithUpdateRewardDebtX128 removes stake and updates reward debt in one operation.
// This ensures rewards are properly calculated before the stake change takes effect.
//
// Parameters:
//   - amount: amount of stake to remove
//   - accumulatedRewardX128PerStake: current system-wide accumulated reward per stake
//   - currentHeight: current block height
func (e *EmissionRewardState) removeStakeWithUpdateRewardDebtX128(
	amount int64,
	accumulatedRewardX128PerStake *u256.Uint,
	currentHeight int64,
) {
	e.updateRewardDebtX128(accumulatedRewardX128PerStake, currentHeight)
	e.removeStake(amount)
}

// claimRewardsWithUpdateRewardDebtX128 claims rewards and updates reward debt in one operation.
// This ensures all rewards are properly calculated before claiming.
//
// Parameters:
//   - accumulatedRewardX128PerStake: current system-wide accumulated reward per stake
//   - currentHeight: current block height
//
// Returns:
//   - int64: amount of rewards claimed
//   - error: nil on success, error if claiming fails
func (e *EmissionRewardState) claimRewardsWithUpdateRewardDebtX128(
	accumulatedRewardX128PerStake *u256.Uint,
	currentHeight int64,
) (int64, error) {
	e.updateRewardDebtX128(accumulatedRewardX128PerStake, currentHeight)
	return e.claimRewards(currentHeight)
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
		rewardDebtX128:          accumulatedRewardX128PerStake,
		accumulatedRewardAmount: 0,
		accumulatedHeight:       0,
		claimedRewardAmount:     0,
		claimedHeight:           0,
		stakedAmount:            0,
	}
}
