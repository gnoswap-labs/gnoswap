package staker

import (
	"gno.land/p/demo/avl"
	"gno.land/p/demo/ufmt"

	u256 "gno.land/p/gnoswap/uint256"
)

// EmissionRewardManager manages the distribution of emission rewards to stakers.
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
func (e *EmissionRewardManager) GetAccumulatedRewardX128PerStake() *u256.Uint {
	return e.accumulatedRewardX128PerStake
}

// GetAccumulatedTimestamp returns the last timestamp when rewards were accumulated.
func (e *EmissionRewardManager) GetAccumulatedTimestamp() int64 {
	return e.accumulatedTimestamp
}

// GetTotalStakedAmount returns the total amount of tokens staked in the system.
func (e *EmissionRewardManager) GetTotalStakedAmount() int64 {
	return e.totalStakedAmount
}

// GetDistributedAmount returns the total amount of rewards distributed.
func (e *EmissionRewardManager) GetDistributedAmount() int64 {
	return e.distributedAmount
}

// GetClaimableRewardAmount calculates the claimable reward amount for a specific address.
func (e *EmissionRewardManager) GetClaimableRewardAmount(
	currentDistributedAmount int64,
	address string,
	currentTimestamp int64,
) (int64, error) {
	rewardStateI, ok := e.rewardStates.Get(address)
	if !ok {
		return 0, nil
	}

	rewardState, ok := rewardStateI.(*EmissionRewardState)
	if !ok {
		return 0, ufmt.Errorf(
			"failed to cast rewardStates's element to *EmissionRewardState: %T",
			rewardStateI,
		)
	}

	accumulatedRewardX128PerStake, err := e.calculateAccumulatedRewardX128PerStake(
		currentDistributedAmount,
		currentTimestamp,
	)
	if err != nil {
		return 0, err
	}

	return rewardState.GetClaimableRewardAmount(accumulatedRewardX128PerStake, currentTimestamp)
}

// calculateAccumulatedRewardX128PerStake calculates the updated accumulated reward per stake.
func (e *EmissionRewardManager) calculateAccumulatedRewardX128PerStake(
	currentDistributedAmount int64,
	currentTimestamp int64,
) (*u256.Uint, error) {
	// If we're looking at a past timestamp, return current state
	if e.accumulatedTimestamp > currentTimestamp {
		return e.accumulatedRewardX128PerStake, nil
	}

	// If no tokens are staked, no rewards to distribute
	if e.totalStakedAmount == 0 {
		return e.accumulatedRewardX128PerStake, nil
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
	accumulatedReward := u256.Zero().Add(e.accumulatedRewardX128PerStake, distributedAmountDeltaX128PerStake)
	return accumulatedReward, nil
}

// updateAccumulatedRewardX128PerStake updates the internal accumulated reward state.
// This method should be called before any stake changes to ensure accurate reward calculations.
// Updates accumulated reward per stake with current distribution data.
func (e *EmissionRewardManager) updateAccumulatedRewardX128PerStake(
	currentDistributedAmount int64,
	currentTimestamp int64,
) error {
	// Don't update if we're looking at a past timestamp
	if e.accumulatedTimestamp > currentTimestamp {
		return nil
	}

	// Don't update if no tokens are staked
	if e.totalStakedAmount == 0 {
		return nil
	}

	// Update accumulated reward state
	accumulatedRewardX128PerStake, err := e.calculateAccumulatedRewardX128PerStake(
		currentDistributedAmount,
		currentTimestamp,
	)
	if err != nil {
		return err
	}

	e.accumulatedRewardX128PerStake = accumulatedRewardX128PerStake
	e.distributedAmount = currentDistributedAmount
	e.accumulatedTimestamp = currentTimestamp

	return nil
}

// addStake adds a stake for an address and updates their reward state.
// This method ensures rewards are properly calculated before the stake change.
// Adds stake for specified address and updates reward calculations.
func (e *EmissionRewardManager) addStake(address string, amount int64, currentTimestamp int64) error {
	rewardStateI, ok := e.rewardStates.Get(address)
	if !ok {
		rewardStateI = NewEmissionRewardState(e.accumulatedRewardX128PerStake)
	}

	rewardState, ok := rewardStateI.(*EmissionRewardState)
	if !ok {
		return ufmt.Errorf(
			"failed to cast rewardStates's element to *EmissionRewardState: %T",
			rewardStateI,
		)
	}

	err := rewardState.addStakeWithUpdateRewardDebtX128(amount, e.accumulatedRewardX128PerStake, currentTimestamp)
	if err != nil {
		return err
	}

	e.rewardStates.Set(address, rewardState)
	e.totalStakedAmount = e.totalStakedAmount + amount

	return nil
}

// removeStake removes a stake for an address and updates their reward state.
// This method ensures rewards are properly calculated before the stake change.
// Removes stake for specified address and updates reward calculations.
func (e *EmissionRewardManager) removeStake(address string, amount int64, currentTimestamp int64) error {
	rewardStateI, ok := e.rewardStates.Get(address)
	if !ok {
		rewardStateI = NewEmissionRewardState(e.accumulatedRewardX128PerStake.Clone())
	}

	rewardState, ok := rewardStateI.(*EmissionRewardState)
	if !ok {
		return ufmt.Errorf(
			"failed to cast rewardStates's element to *EmissionRewardState: %T",
			rewardStateI,
		)
	}

	err := rewardState.removeStakeWithUpdateRewardDebtX128(amount, e.accumulatedRewardX128PerStake, currentTimestamp)
	if err != nil {
		return err
	}

	e.totalStakedAmount = e.totalStakedAmount - amount

	return nil
}

// claimRewards processes reward claiming for an address.
// This method calculates and returns the amount of rewards claimed.
// Claims available rewards for specified address.
func (e *EmissionRewardManager) claimRewards(address string, currentTimestamp int64) (claimedRewardAmount int64, err error) {
	rewardStateI, ok := e.rewardStates.Get(address)
	if !ok {
		return 0, nil
	}

	rewardState, ok := rewardStateI.(*EmissionRewardState)
	if !ok {
		return 0, ufmt.Errorf(
			"failed to cast rewardStates's element to *EmissionRewardState: %T",
			rewardStateI,
		)
	}

	claimedRewardAmount, cErr := rewardState.claimRewardsWithUpdateRewardDebtX128(e.accumulatedRewardX128PerStake, currentTimestamp)
	if cErr != nil {
		return 0, cErr
	}

	e.rewardStates.Set(address, rewardState)

	return claimedRewardAmount, nil
}

// NewEmissionRewardManager creates a new instance of EmissionRewardManager.
// This factory function initializes all tracking structures for emission reward management.
// NewEmissionRewardManager creates new emission reward manager instance.
func NewEmissionRewardManager() *EmissionRewardManager {
	return &EmissionRewardManager{
		accumulatedRewardX128PerStake: u256.NewUint(0),
		accumulatedTimestamp:          0,
		totalStakedAmount:             0,
		distributedAmount:             0,
		rewardStates:                  avl.NewTree(),
	}
}
