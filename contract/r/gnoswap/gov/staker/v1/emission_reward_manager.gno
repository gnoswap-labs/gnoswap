package staker

import (
	"errors"
	"math"

	gnsmath "gno.land/p/gnoswap/gnsmath"
	u256 "gno.land/p/gnoswap/uint256"
	"gno.land/r/gnoswap/gov/staker"
)

type EmissionRewardManagerResolver struct {
	*staker.EmissionRewardManager
}

// NewEmissionRewardManagerResolver wraps an emission reward manager with reward
// calculation and stake-accounting helpers.
//
// Parameters:
//   - emissionRewardManager: manager state to resolve and mutate.
//
// Returns:
//   - *EmissionRewardManagerResolver: resolver backed by emissionRewardManager.
func NewEmissionRewardManagerResolver(emissionRewardManager *staker.EmissionRewardManager) *EmissionRewardManagerResolver {
	return &EmissionRewardManagerResolver{emissionRewardManager}
}

// GetClaimableRewardAmount calculates the claimable reward amount for a specific address.
//
// Parameters:
//   - currentDistributedAmount: total emission amount distributed to the staker
//     manager at the current observation point.
//   - address: reward-state identifier whose claimable amount is requested.
//   - currentTimestamp: Unix timestamp used to settle the address's reward state.
//
// Returns:
//   - int64: emission reward currently claimable by address, or zero when no
//     reward state exists.
//   - error: nil on success; an error from accumulated-reward or reward-state
//     resolution when calculation fails.
func (self *EmissionRewardManagerResolver) GetClaimableRewardAmount(
	currentDistributedAmount int64,
	address string,
	currentTimestamp int64,
) (int64, error) {
	rewardState, ok, err := self.GetRewardState(address)
	if !ok {
		return 0, nil
	}

	accumulatedRewardX128PerStake, err := self.calculateAccumulatedRewardX128PerStake(
		currentDistributedAmount,
		currentTimestamp,
	)
	if err != nil {
		return 0, err
	}

	resolvedState := NewEmissionRewardStateResolver(rewardState)
	return resolvedState.GetClaimableRewardAmount(accumulatedRewardX128PerStake, currentTimestamp)
}

// calculateAccumulatedRewardX128PerStake calculates the updated accumulated reward per stake.
//
// Parameters:
//   - currentDistributedAmount: total emission amount distributed at the current
//     observation point.
//   - currentTimestamp: Unix timestamp at which the accumulator is evaluated.
//
// Returns:
//   - *u256.Uint: accumulated emission reward per stake scaled by 2^128.
//   - error: nil; this calculation currently has no explicit error path.
func (self *EmissionRewardManagerResolver) calculateAccumulatedRewardX128PerStake(
	currentDistributedAmount int64,
	currentTimestamp int64,
) (*u256.Uint, error) {
	// If we're looking at a past timestamp, return current state
	if currentTimestamp < self.GetAccumulatedTimestamp() {
		return self.GetAccumulatedRewardX128PerStake(), nil
	}

	// With no stake there is nobody to credit, so the delta accrued over that window is
	// dropped and the caller advances the cursor past it. The protocol fee accumulator
	// applies the same policy, see ProtocolFeeRewardManagerResolver.
	totalStakedAmount := self.GetTotalStakedAmount()
	if totalStakedAmount == 0 {
		return self.GetAccumulatedRewardX128PerStake(), nil
	}

	// Newly distributed rewards since last update
	distributedAmountDelta := gnsmath.SafeSubInt64(currentDistributedAmount, self.GetDistributedAmount())
	if distributedAmountDelta <= 0 {
		// Non-positive delta. nothing to do more.
		return self.GetAccumulatedRewardX128PerStake(), nil
	}

	// Reward per stake for the new distribution
	distributedAmountDeltaX128PerStake := u256.Zero().Div(
		u256.Zero().Lsh(u256.NewUintFromInt64(distributedAmountDelta), 128),
		u256.NewUintFromInt64(totalStakedAmount),
	)

	// Add to accumulated reward per stake
	accumulatedReward := u256.Zero().Add(self.GetAccumulatedRewardX128PerStake(), distributedAmountDeltaX128PerStake)
	return accumulatedReward, nil
}

// updateAccumulatedRewardX128PerStake updates the internal accumulated reward state.
// This method should be called before any stake changes to ensure accurate reward calculations.
//
// Parameters:
//   - currentDistributedAmount: total emission amount distributed at the current
//     observation point.
//   - currentTimestamp: Unix timestamp used as the manager's accumulation cursor.
//
// Returns:
//   - error: nil when the state is updated or the timestamp is older than the
//     current cursor; otherwise the calculation error.
func (self *EmissionRewardManagerResolver) updateAccumulatedRewardX128PerStake(
	currentDistributedAmount int64,
	currentTimestamp int64,
) error {
	// DO NOT apply out-of-order timestamps
	if currentTimestamp < self.GetAccumulatedTimestamp() {
		return nil
	}

	// Update accumulated reward state
	accumulatedRewardX128PerStake, err := self.calculateAccumulatedRewardX128PerStake(
		currentDistributedAmount,
		currentTimestamp,
	)
	if err != nil {
		return err
	}

	self.setAccumulatedRewardX128PerStake(accumulatedRewardX128PerStake.Clone())
	self.setDistributedAmount(currentDistributedAmount)
	self.setAccumulatedTimestamp(currentTimestamp)

	return nil
}

// addStake adds a stake for an address and updates their reward state.
// This method ensures rewards are properly calculated before the stake change.
//
// Parameters:
//   - address: reward-state identifier receiving the stake.
//   - amount: non-negative stake amount to add.
//   - currentTimestamp: Unix timestamp at which the stake is added.
//
// Returns:
//   - error: nil on success; an error when amount is negative, reward state
//     resolution fails, or total stake would overflow.
func (self *EmissionRewardManagerResolver) addStake(address string, amount int64, currentTimestamp int64) error {
	if amount < 0 {
		return errors.New(errAmountMustBeNonNegative)
	}

	accumulatedReward := self.GetAccumulatedRewardX128PerStake()

	rewardState, ok, err := self.GetRewardState(address)
	if err != nil {
		return err
	}
	if !ok {
		rewardState = staker.NewEmissionRewardState(accumulatedReward)
	}

	resolvedState := NewEmissionRewardStateResolver(rewardState)
	err = resolvedState.addStakeWithUpdateRewardDebtX128(amount, accumulatedReward, currentTimestamp)
	if err != nil {
		return err
	}

	self.setRewardStates(address, rewardState)

	currentTotal := self.GetTotalStakedAmount()
	if amount > 0 && currentTotal > math.MaxInt64-amount {
		return errors.New(errTotalStakedAmountOverflow)
	}
	self.SetTotalStakedAmount(gnsmath.SafeAddInt64(currentTotal, amount))
	return nil
}

// removeStake removes a stake for an address and updates their reward state.
// This method ensures rewards are properly calculated before the stake change.
//
// Parameters:
//   - address: reward-state identifier whose stake is reduced.
//   - amount: non-negative stake amount to remove.
//   - currentTimestamp: Unix timestamp at which the stake is removed.
//
// Returns:
//   - error: nil on success; an error when amount is negative, exceeds total
//     stake, or reward-state resolution fails.
func (self *EmissionRewardManagerResolver) removeStake(address string, amount int64, currentTimestamp int64) error {
	if amount < 0 {
		return errors.New(errAmountMustBeNonNegative)
	}

	updatedTotalStakedAmount := gnsmath.SafeSubInt64(self.GetTotalStakedAmount(), amount)
	if updatedTotalStakedAmount < 0 {
		return errors.New(errRemoveAmountExceedsTotalStaked)
	}

	accumulatedReward := self.GetAccumulatedRewardX128PerStake()

	rewardState, ok, err := self.GetRewardState(address)
	if err != nil {
		return err
	}
	if !ok {
		rewardState = staker.NewEmissionRewardState(accumulatedReward)
	}

	resolvedState := NewEmissionRewardStateResolver(rewardState)

	err = resolvedState.removeStakeWithUpdateRewardDebtX128(amount, accumulatedReward, currentTimestamp)
	if err != nil {
		return err
	}

	// persist updated state
	self.setRewardStates(address, rewardState)

	self.SetTotalStakedAmount(updatedTotalStakedAmount)

	return nil
}

// claimRewards processes reward claiming for an address.
// This method calculates and returns the amount of rewards claimed.
//
// Parameters:
//   - address: reward-state identifier whose emission rewards are claimed.
//   - currentTimestamp: Unix timestamp used to settle the reward state.
//
// Returns:
//   - claimedRewardAmount: whole-unit emission reward amount claimed; zero when
//     no reward state exists or an error prevents claiming.
//   - err: nil on success; an error returned while resolving or updating the
//     address's reward state.
func (self *EmissionRewardManagerResolver) claimRewards(address string, currentTimestamp int64) (claimedRewardAmount int64, err error) {
	rewardState, ok, err := self.GetRewardState(address)
	if err != nil || !ok {
		return 0, err
	}

	resolvedState := NewEmissionRewardStateResolver(rewardState)
	claimedRewardAmount, cErr := resolvedState.claimRewardsWithUpdateRewardDebtX128(self.GetAccumulatedRewardX128PerStake(), currentTimestamp)
	if cErr != nil {
		return 0, cErr
	}

	self.setRewardStates(address, rewardState)
	return claimedRewardAmount, nil
}

// setRewardStates persists the reward state for an address in the manager.
//
// Parameters:
//   - address: reward-state identifier to update.
//   - rewardState: updated emission reward state to store.
func (self *EmissionRewardManagerResolver) setRewardStates(address string, rewardState *staker.EmissionRewardState) {
	self.SetRewardState(address, rewardState)
}

// setAccumulatedRewardX128PerStake updates the manager's accumulated emission
// reward per stake value.
//
// Parameters:
//   - accumulatedRewardX128PerStake: new Q128-scaled accumulated reward per
//     stake.
func (self *EmissionRewardManagerResolver) setAccumulatedRewardX128PerStake(accumulatedRewardX128PerStake *u256.Uint) {
	self.SetAccumulatedRewardX128PerStake(accumulatedRewardX128PerStake)
}

// setDistributedAmount updates the manager's total distributed emission cursor.
//
// Parameters:
//   - distributedAmount: total emission amount recorded as distributed.
func (self *EmissionRewardManagerResolver) setDistributedAmount(distributedAmount int64) {
	self.SetDistributedAmount(distributedAmount)
}

// setAccumulatedTimestamp updates the manager's timestamp cursor.
//
// Parameters:
//   - accumulatedTimestamp: Unix timestamp represented by the accumulated state.
func (self *EmissionRewardManagerResolver) setAccumulatedTimestamp(accumulatedTimestamp int64) {
	self.SetAccumulatedTimestamp(accumulatedTimestamp)
}
