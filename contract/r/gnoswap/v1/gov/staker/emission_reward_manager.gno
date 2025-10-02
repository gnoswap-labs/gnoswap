package staker

import (
	"gno.land/p/nt/avl"
	"gno.land/p/nt/ufmt"

	u256 "gno.land/p/gnoswap/uint256"
)

var errFailedToCastRewardState = "failed to cast rewardStates's element to *EmissionRewardState: %T"

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
	if currentTimestamp < e.accumulatedTimestamp {
		return e.accumulatedRewardX128PerStake, nil
	}

	// If no tokens are staked, no rewards to distribute
	if e.totalStakedAmount == 0 {
		return e.accumulatedRewardX128PerStake, nil
	}

	// Newly distributed rewards since last update
	distributedAmountDelta := currentDistributedAmount - e.distributedAmount
	if distributedAmountDelta <= 0 {
		// Non-positive delta. nothing to do more.
		return e.accumulatedRewardX128PerStake, nil
	}

	// Reward per stake for the new distribution
	distributedAmountDeltaX128PerStake := u256.Zero().Div(
		u256.Zero().Lsh(u256.NewUintFromInt64(distributedAmountDelta), 128),
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
	// DO NOT apply out-of-order timestamps
	if currentTimestamp < e.accumulatedTimestamp {
		return nil
	}

	// to avoid accumulating a large delta later.
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

	e.accumulatedRewardX128PerStake = accumulatedRewardX128PerStake.Clone()
	e.distributedAmount = currentDistributedAmount
	e.accumulatedTimestamp = currentTimestamp

	return nil
}

// addStake adds a stake for an address and updates their reward state.
// This method ensures rewards are properly calculated before the stake change.
// Adds stake for specified address and updates reward calculations.
func (e *EmissionRewardManager) addStake(address string, amount int64, currentTimestamp int64) error {
	rewardState, ok, err := e.getRewardState(address)
	if err != nil {
		return err
	}
	if !ok {
		// if the address is unseen, initialize a snapshot to avoid nil deref
		rewardState = NewEmissionRewardState(e.accumulatedRewardX128PerStake.Clone())
	}

	err = rewardState.addStakeWithUpdateRewardDebtX128(amount, e.accumulatedRewardX128PerStake, currentTimestamp)
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
	rewardState, ok, err := e.getRewardState(address)
	if err != nil {
		return err
	}
	if !ok {
		// if the address is unseen, initialize a snapshot to avoid nil deref
		rewardState = NewEmissionRewardState(e.accumulatedRewardX128PerStake.Clone())
	}

	err = rewardState.removeStakeWithUpdateRewardDebtX128(amount, e.accumulatedRewardX128PerStake, currentTimestamp)
	if err != nil {
		return err
	}

	// persist updated state
	e.rewardStates.Set(address, rewardState)
	e.totalStakedAmount -= amount
	if e.totalStakedAmount < 0 {
		e.totalStakedAmount = 0 // defensive clamp
	}

	return nil
}

// claimRewards processes reward claiming for an address.
// This method calculates and returns the amount of rewards claimed.
// Claims available rewards for specified address.
func (e *EmissionRewardManager) claimRewards(address string, currentTimestamp int64) (claimedRewardAmount int64, err error) {
	rewardState, ok, err := e.getRewardState(address)
	if err != nil || !ok {
		return 0, err
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

func (e *EmissionRewardManager) getRewardState(addr string) (*EmissionRewardState, bool, error) {
	ri, ok := e.rewardStates.Get(addr)
	if !ok {
		return nil, false, nil
	}
	rs, castOk := ri.(*EmissionRewardState)
	if !castOk {
		return nil, false, ufmt.Errorf(errFailedToCastRewardState, ri)
	}
	return rs, true, nil
}
