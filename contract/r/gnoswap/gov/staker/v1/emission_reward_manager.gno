package v1

import (
    "math"
    "errors"

	u256 "gno.land/p/gnoswap/uint256"
	"gno.land/r/gnoswap/gov/staker"
)

type EmissionRewardManagerResolver struct {
	*staker.EmissionRewardManager
}

func NewEmissionRewardManagerResolver(emissionRewardManager *staker.EmissionRewardManager) *EmissionRewardManagerResolver {
	return &EmissionRewardManagerResolver{emissionRewardManager}
}

// GetClaimableRewardAmount calculates the claimable reward amount for a specific address.
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
func (self *EmissionRewardManagerResolver) calculateAccumulatedRewardX128PerStake(
	currentDistributedAmount int64,
	currentTimestamp int64,
) (*u256.Uint, error) {
	// If we're looking at a past timestamp, return current state
	if currentTimestamp < self.GetAccumulatedTimestamp() {
		return self.GetAccumulatedRewardX128PerStake(), nil
	}

	// If no tokens are staked, no rewards to distribute
	totalStakedAmount := self.GetTotalStakedAmount()
	if totalStakedAmount == 0 {
		return self.GetAccumulatedRewardX128PerStake(), nil
	}

	// Newly distributed rewards since last update
	distributedAmountDelta := currentDistributedAmount - self.GetDistributedAmount()
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
// Updates accumulated reward per stake with current distribution data.
func (self *EmissionRewardManagerResolver) updateAccumulatedRewardX128PerStake(
	currentDistributedAmount int64,
	currentTimestamp int64,
) error {
	// DO NOT apply out-of-order timestamps
	if currentTimestamp < self.GetAccumulatedTimestamp() {
		return nil
	}

	// to avoid accumulating a large delta later.
	if self.GetTotalStakedAmount() == 0 {
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
// Adds stake for specified address and updates reward calculations.
func (self *EmissionRewardManagerResolver) addStake(address string, amount int64, currentTimestamp int64) error {
    if amount < 0 {
        return errors.New("amount must be non-negative")
    }

	rewardState, ok, err := self.GetRewardState(address)
	if err != nil {
		return err
	}
	if !ok {
		// if the address is unseen, initialize a snapshot to avoid nil deref
		rewardState = staker.NewEmissionRewardState(self.GetAccumulatedRewardX128PerStake().Clone())
	}

	resolvedState := NewEmissionRewardStateResolver(rewardState)
	err = resolvedState.addStakeWithUpdateRewardDebtX128(amount, self.GetAccumulatedRewardX128PerStake(), currentTimestamp)
	if err != nil {
		return err
	}

	self.setRewardStates(address, rewardState)

	currentTotal := self.GetTotalStakedAmount()
	if amount > 0 && currentTotal > math.MaxInt64-amount {
		return errors.New("total staked amount would overflow")
	}
	self.SetTotalStakedAmount(currentTotal + amount)
	return nil
}

// removeStake removes a stake for an address and updates their reward state.
// This method ensures rewards are properly calculated before the stake change.
// Removes stake for specified address and updates reward calculations.
func (self *EmissionRewardManagerResolver) removeStake(address string, amount int64, currentTimestamp int64) error {
	if amount < 0 {
        return errors.New("amount must be non-negative")
    }

	rewardState, ok, err := self.GetRewardState(address)
	if err != nil {
		return err
	}
	if !ok {
		// if the address is unseen, initialize a snapshot to avoid nil deref
		rewardState = staker.NewEmissionRewardState(self.GetAccumulatedRewardX128PerStake().Clone())
	}

	resolvedState := NewEmissionRewardStateResolver(rewardState)
	err = resolvedState.removeStakeWithUpdateRewardDebtX128(amount, self.GetAccumulatedRewardX128PerStake(), currentTimestamp)
	if err != nil {
		return err
	}

	// persist updated state
	self.setRewardStates(address, rewardState)

	updatedTotalStakedAmount := self.GetTotalStakedAmount() - amount
	if updatedTotalStakedAmount < 0 {
		updatedTotalStakedAmount = 0
	}
	self.SetTotalStakedAmount(updatedTotalStakedAmount)

	return nil
}

// claimRewards processes reward claiming for an address.
// This method calculates and returns the amount of rewards claimed.
// Claims available rewards for specified address.
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

func (self *EmissionRewardManagerResolver) setRewardStates(address string, rewardState *staker.EmissionRewardState) {
	self.SetRewardState(address, rewardState)
}

func (self *EmissionRewardManagerResolver) setAccumulatedRewardX128PerStake(accumulatedRewardX128PerStake *u256.Uint) {
	self.SetAccumulatedRewardX128PerStake(accumulatedRewardX128PerStake)
}

func (self *EmissionRewardManagerResolver) setDistributedAmount(distributedAmount int64) {
	self.SetDistributedAmount(distributedAmount)
}

func (self *EmissionRewardManagerResolver) setAccumulatedTimestamp(accumulatedTimestamp int64) {
	self.SetAccumulatedTimestamp(accumulatedTimestamp)
}
