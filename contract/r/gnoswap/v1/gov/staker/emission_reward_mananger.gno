package staker

import (
	"gno.land/p/demo/avl"
	"gno.land/p/demo/ufmt"

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
	distributedAmount int64
	// accumulatedTimestamp tracks the last timestamp when rewards were accumulated
	accumulatedTimestamp int64
	// totalStakedAmount tracks the total amount of tokens staked in the system
	totalStakedAmount int64
}

// GetAccumulatedRewardX128PerStake returns the accumulated reward per stake with 128-bit precision.
//
// Returns:
//   - *u256.Uint: accumulated reward per stake (scaled by 2^128)
func (e *EmissionRewardManager) GetAccumulatedRewardX128PerStake() *u256.Uint {
	return e.accumulatedRewardX128PerStake
}

// GetAccumulatedTimestamp returns the last timestamp when rewards were accumulated.
//
// Returns:
//   - int64: last accumulated timestamp
func (e *EmissionRewardManager) GetAccumulatedTimestamp() int64 {
	return e.accumulatedTimestamp
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
//   - currentTimestamp: current timestamp
//
// Returns:
//   - int64: amount of rewards that can be claimed
func (e *EmissionRewardManager) GetClaimableRewardAmount(
	currentDistributedAmount int64,
	address string,
	currentTimestamp int64,
) int64 {
	rewardStateI, ok := e.rewardStates.Get(address)
	if !ok {
		return 0
	}

	rewardState, ok := rewardStateI.(*EmissionRewardState)
	if !ok {
		panic(ufmt.Sprintf(
			"failed to cast rewardStates's element to *EmissionRewardState: %T",
			rewardStateI,
		))
	}
	accumulatedRewardX128PerStake := e.calculateAccumulatedRewardX128PerStake(currentDistributedAmount, currentTimestamp)

	return rewardState.GetClaimableRewardAmount(accumulatedRewardX128PerStake, currentTimestamp)
}

// calculateAccumulatedRewardX128PerStake calculates the updated accumulated reward per stake.
// This method computes the new accumulated reward rate based on newly distributed rewards.
//
// Parameters:
//   - currentDistributedAmount: current total distributed amount
//   - currentTimestamp: current timestamp
//
// Returns:
//   - *u256.Uint: updated accumulated reward per stake
func (e *EmissionRewardManager) calculateAccumulatedRewardX128PerStake(
	currentDistributedAmount int64,
	currentTimestamp int64,
) *u256.Uint {
	// If we're looking at a past timestamp, return current state
	if e.accumulatedTimestamp > currentTimestamp {
		return e.accumulatedRewardX128PerStake
	}

	// If no tokens are staked, no rewards to distribute
	if e.totalStakedAmount == 0 {
		return e.accumulatedRewardX128PerStake
	}

	// Calculate the newly distributed rewards since last update
	distributedAmountDelta := currentDistributedAmount - e.distributedAmount
	distributedAmountDeltaX128 := u256.NewUintFromInt64(distributedAmountDelta)
	distributedAmountDeltaX128 = u256.Zero().Lsh(distributedAmountDeltaX128, 128)

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
//   - currentTimestamp: current timestamp
func (e *EmissionRewardManager) updateAccumulatedRewardX128PerStake(
	currentDistributedAmount int64,
	currentTimestamp int64,
) {
	// Don't update if we're looking at a past timestamp
	if e.accumulatedTimestamp > currentTimestamp {
		return
	}

	// Don't update if no tokens are staked
	if e.totalStakedAmount == 0 {
		return
	}

	// Update accumulated reward state
	e.accumulatedRewardX128PerStake = e.calculateAccumulatedRewardX128PerStake(
		currentDistributedAmount,
		currentTimestamp,
	)
	e.distributedAmount = currentDistributedAmount
	e.accumulatedTimestamp = currentTimestamp
}

// addStake adds a stake for an address and updates their reward state.
// This method ensures rewards are properly calculated before the stake change.
//
// Parameters:
//   - address: staker's address
//   - amount: amount of stake to add
//   - currentTimestamp: current timestamp
func (e *EmissionRewardManager) addStake(address string, amount int64, currentTimestamp int64) {
	rewardStateI, ok := e.rewardStates.Get(address)
	if !ok {
		rewardStateI = NewEmissionRewardState(e.accumulatedRewardX128PerStake)
	}

	rewardState, ok := rewardStateI.(*EmissionRewardState)
	if !ok {
		panic(ufmt.Sprintf(
			"failed to cast rewardStates's element to *EmissionRewardState: %T",
			rewardStateI,
		))
	}
	rewardState.addStakeWithUpdateRewardDebtX128(amount, e.accumulatedRewardX128PerStake, currentTimestamp)

	e.rewardStates.Set(address, rewardState)

	e.totalStakedAmount = e.totalStakedAmount + amount
}

// removeStake removes a stake for an address and updates their reward state.
// This method ensures rewards are properly calculated before the stake change.
//
// Parameters:
//   - address: staker's address
//   - amount: amount of stake to remove
//   - currentTimestamp: current timestamp
func (e *EmissionRewardManager) removeStake(address string, amount int64, currentTimestamp int64) {
	rewardStateI, ok := e.rewardStates.Get(address)
	if !ok {
		rewardStateI = NewEmissionRewardState(e.accumulatedRewardX128PerStake.Clone())
	}

	if rewardState, ok := rewardStateI.(*EmissionRewardState); !ok {
		panic(ufmt.Sprintf("failed to cast rewardStates's element to *EmissionRewardState: %T", rewardStateI))
	} else {
		rewardState.removeStakeWithUpdateRewardDebtX128(amount, e.accumulatedRewardX128PerStake, currentTimestamp)
		e.rewardStates.Set(address, rewardState)
	}

	e.totalStakedAmount = e.totalStakedAmount - amount
}

// claimRewards processes reward claiming for an address.
// This method calculates and returns the amount of rewards claimed.
//
// Parameters:
//   - address: staker's address claiming rewards
//   - currentTimestamp: current timestamp
//
// Returns:
//   - int64: amount of rewards claimed
//   - error: nil on success, error if claiming fails
func (e *EmissionRewardManager) claimRewards(address string, currentTimestamp int64) (claimedRewardAmount int64, err error) {
	rewardStateI, ok := e.rewardStates.Get(address)
	if !ok {
		return 0, nil
	}

	rewardState, ok := rewardStateI.(*EmissionRewardState)
	if !ok {
		return 0, ufmt.Errorf(
			"failed to cast rewardStates's element to *EmissionRewardState: %T",
			rewardStateI)
	}

	claimedRewardAmount, err = rewardState.claimRewardsWithUpdateRewardDebtX128(e.accumulatedRewardX128PerStake, currentTimestamp)
	if err != nil {
		return 0, err
	}

	e.rewardStates.Set(address, rewardState)

	return
}

// NewEmissionRewardManager creates a new instance of EmissionRewardManager.
// This factory function initializes all tracking structures for emission reward management.
//
// Returns:
//   - *EmissionRewardManager: new emission reward manager instance
func NewEmissionRewardManager() *EmissionRewardManager {
	return &EmissionRewardManager{
		accumulatedRewardX128PerStake: u256.NewUint(0),
		accumulatedTimestamp:          0,
		totalStakedAmount:             0,
		distributedAmount:             0,
		rewardStates:                  avl.NewTree(),
	}
}
