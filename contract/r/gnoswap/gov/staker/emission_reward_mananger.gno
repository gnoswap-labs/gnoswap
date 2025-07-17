package staker

import (
	"gno.land/p/demo/avl"
	u256 "gno.land/p/gnoswap/uint256"
)

// EmissionRewardManager manages the distribution of emission rewards to stakers.
// It tracks accumulated rewards per stake and handles reward calculations,
// distribution, and claiming operations for emission-based incentives.
type EmissionRewardManager struct {
	// rewardStates maps address to EmissionRewardState for tracking individual staker rewards
	rewardStates *avl.Tree // address -> EmissionRewardState

	// accumulatedRewardX128PerStake tracks the cumulative reward per unit of stake with 128-bit precision
	accumulatedRewardX128PerStake *u256.Uint
	// distributedAmount tracks the total amount of rewards distributed
	distributedAmount             int64
	// accumulatedHeight tracks the last block height when rewards were accumulated
	accumulatedHeight             int64
	// totalStakedAmount tracks the total amount of tokens staked in the system
	totalStakedAmount             int64
}

// GetAccumulatedRewardX128PerStake returns the accumulated reward per stake with 128-bit precision.
//
// Returns:
//   - *u256.Uint: accumulated reward per stake (scaled by 2^128)
func (e *EmissionRewardManager) GetAccumulatedRewardX128PerStake() *u256.Uint {
	return e.accumulatedRewardX128PerStake
}

// GetAccumulatedHeight returns the last block height when rewards were accumulated.
//
// Returns:
//   - int64: last accumulated block height
func (e *EmissionRewardManager) GetAccumulatedHeight() int64 {
	return e.accumulatedHeight
}

// GetTotalStakedAmount returns the total amount of tokens staked in the system.
//
// Returns:
//   - int64: total staked amount
func (e *EmissionRewardManager) GetTotalStakedAmount() int64 {
	return e.totalStakedAmount
}

// GetDistributedAmount returns the total amount of rewards distributed.
//
// Returns:
//   - int64: total distributed reward amount
func (e *EmissionRewardManager) GetDistributedAmount() int64 {
	return e.distributedAmount
}

// GetClaimableRewardAmount calculates the claimable reward amount for a specific address.
// This method computes rewards based on current distribution state and staking history.
//
// Parameters:
//   - currentDistributedAmount: current total distributed amount from emission contract
//   - address: staker's address to calculate rewards for
//   - currentHeight: current block height
//
// Returns:
//   - int64: amount of rewards that can be claimed
func (e *EmissionRewardManager) GetClaimableRewardAmount(
	currentDistributedAmount int64,
	address string,
	currentHeight int64,
) int64 {
	rewardStateI, ok := e.rewardStates.Get(address)
	if !ok {
		return 0
	}

	rewardState := rewardStateI.(*EmissionRewardState)
	accumulatedRewardX128PerStake := e.calculateAccumulatedRewardX128PerStake(currentDistributedAmount, currentHeight)

	return rewardState.GetClaimableRewardAmount(accumulatedRewardX128PerStake, currentHeight)
}

// calculateAccumulatedRewardX128PerStake calculates the updated accumulated reward per stake.
// This method computes the new accumulated reward rate based on newly distributed rewards.
//
// Parameters:
//   - currentDistributedAmount: current total distributed amount
//   - currentHeight: current block height
//
// Returns:
//   - *u256.Uint: updated accumulated reward per stake
func (e *EmissionRewardManager) calculateAccumulatedRewardX128PerStake(
	currentDistributedAmount int64,
	currentHeight int64,
) *u256.Uint {
	// If we're looking at a past height, return current state
	if e.accumulatedHeight > currentHeight {
		return e.accumulatedRewardX128PerStake
	}

	// If no tokens are staked, no rewards to distribute
	if e.totalStakedAmount == 0 {
		return e.accumulatedRewardX128PerStake
	}

	// Calculate the newly distributed rewards since last update
	distributedAmountDelta := currentDistributedAmount - e.distributedAmount
	distributedAmountDeltaX128 := u256.NewUintFromInt64(distributedAmountDelta)
	distributedAmountDeltaX128 = distributedAmountDeltaX128.Lsh(distributedAmountDeltaX128, 128)

	// Calculate reward per stake for the new distribution
	distributedAmountDeltaX128PerStake := u256.Zero().Div(
		distributedAmountDeltaX128,
		u256.NewUintFromInt64(e.totalStakedAmount),
	)

	// Add to accumulated reward per stake
	accumulatedRewardX128PerStake := u256.Zero().Add(
		e.accumulatedRewardX128PerStake,
		distributedAmountDeltaX128PerStake,
	)

	return accumulatedRewardX128PerStake
}

// updateAccumulatedRewardX128PerStake updates the internal accumulated reward state.
// This method should be called before any stake changes to ensure accurate reward calculations.
//
// Parameters:
//   - currentDistributedAmount: current total distributed amount
//   - currentHeight: current block height
func (e *EmissionRewardManager) updateAccumulatedRewardX128PerStake(
	currentDistributedAmount int64,
	currentHeight int64,
) {
	// Don't update if we're looking at a past height
	if e.accumulatedHeight > currentHeight {
		return
	}

	// Don't update if no tokens are staked
	if e.totalStakedAmount == 0 {
		return
	}

	// Update accumulated reward state
	e.accumulatedRewardX128PerStake = e.calculateAccumulatedRewardX128PerStake(
		currentDistributedAmount, 
		currentHeight,
	)
	e.distributedAmount = currentDistributedAmount
	e.accumulatedHeight = currentHeight
}

// addStake adds a stake for an address and updates their reward state.
// This method ensures rewards are properly calculated before the stake change.
//
// Parameters:
//   - address: staker's address
//   - amount: amount of stake to add
//   - currentHeight: current block height
func (e *EmissionRewardManager) addStake(address string, amount int64, currentHeight int64) {
	rewardStateI, ok := e.rewardStates.Get(address)
	if !ok {
		rewardStateI = NewEmissionRewardState(e.accumulatedRewardX128PerStake)
	}

	rewardState := rewardStateI.(*EmissionRewardState)
	rewardState.addStakeWithUpdateRewardDebtX128(amount, e.accumulatedRewardX128PerStake, currentHeight)

	e.rewardStates.Set(address, rewardState)

	e.totalStakedAmount = e.totalStakedAmount + amount
}

// removeStake removes a stake for an address and updates their reward state.
// This method ensures rewards are properly calculated before the stake change.
//
// Parameters:
//   - address: staker's address
//   - amount: amount of stake to remove
//   - currentHeight: current block height
func (e *EmissionRewardManager) removeStake(address string, amount int64, currentHeight int64) {
	rewardStateI, ok := e.rewardStates.Get(address)
	if !ok {
		rewardStateI = NewEmissionRewardState(e.accumulatedRewardX128PerStake.Clone())
	}

	rewardState := rewardStateI.(*EmissionRewardState)
	rewardState.removeStakeWithUpdateRewardDebtX128(amount, e.accumulatedRewardX128PerStake, currentHeight)

	e.rewardStates.Set(address, rewardState)

	e.totalStakedAmount = e.totalStakedAmount - amount
}

// claimRewards processes reward claiming for an address.
// This method calculates and returns the amount of rewards claimed.
//
// Parameters:
//   - address: staker's address claiming rewards
//   - currentHeight: current block height
//
// Returns:
//   - int64: amount of rewards claimed
//   - error: nil on success, error if claiming fails
func (e *EmissionRewardManager) claimRewards(address string, currentHeight int64) (int64, error) {
	rewardStateI, ok := e.rewardStates.Get(address)
	if !ok {
		return 0, nil
	}

	rewardState := rewardStateI.(*EmissionRewardState)
	
	claimedRewardAmount, err := rewardState.claimRewardsWithUpdateRewardDebtX128(e.accumulatedRewardX128PerStake, currentHeight)
	if err != nil {
		return 0, err
	}

	e.rewardStates.Set(address, rewardState)

	return claimedRewardAmount, nil
}

// NewEmissionRewardManager creates a new instance of EmissionRewardManager.
// This factory function initializes all tracking structures for emission reward management.
//
// Returns:
//   - *EmissionRewardManager: new emission reward manager instance
func NewEmissionRewardManager() *EmissionRewardManager {
	return &EmissionRewardManager{
		accumulatedRewardX128PerStake: u256.NewUint(0),
		accumulatedHeight:             0,
		totalStakedAmount:             0,
		distributedAmount:             0,
		rewardStates:                  avl.NewTree(),
	}
}
