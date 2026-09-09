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
	// If we're looking at a past timestamp, return current state.
	if currentTimestamp < self.GetAccumulatedTimestamp() {
		return self.GetAccumulatedRewardX128PerStake(), nil
	}

	// Decode the persisted accumulator once for this calculation. The value is
	// passed through every branch below instead of re-decoding it on each return.
	accumulatedReward := self.GetAccumulatedRewardX128PerStake()
	totalStakedAmount := self.GetTotalStakedAmount()
	if totalStakedAmount == 0 {
		// With no stake there is nobody to credit, so the delta accrued over
		// that window is dropped and the cursor advances past it.
		return accumulatedReward, nil
	}

	distributedAmountDelta := gnsmath.SafeSubInt64(currentDistributedAmount, self.GetDistributedAmount())
	if distributedAmountDelta <= 0 {
		return accumulatedReward, nil
	}

	distributedAmountDeltaX128PerStake := u256.Zero().Div(
		u256.Zero().Lsh(u256.NewUintFromInt64(distributedAmountDelta), 128),
		u256.NewUintFromInt64(totalStakedAmount),
	)

	return u256.Zero().Add(accumulatedReward, distributedAmountDeltaX128PerStake), nil
}

// updateAccumulatedRewardX128PerStake updates the internal accumulated reward state.
// This method should be called before any stake changes to ensure accurate reward calculations.
// Updates accumulated reward per stake with current distribution data.
// updateAccumulatedRewardX128PerStakeWithValue updates the persisted accumulator
// and returns the numeric value prepared for the next operation in this
// transaction. The returned value is calculation-local and is never stored.
func (self *EmissionRewardManagerResolver) updateAccumulatedRewardX128PerStakeWithValue(
	currentDistributedAmount int64,
	currentTimestamp int64,
) (*u256.Uint, error) {
	if currentTimestamp < self.GetAccumulatedTimestamp() {
		return self.GetAccumulatedRewardX128PerStake(), nil
	}

	accumulatedRewardX128PerStake, err := self.calculateAccumulatedRewardX128PerStake(
		currentDistributedAmount,
		currentTimestamp,
	)
	if err != nil {
		return nil, err
	}

	self.setAccumulatedRewardX128PerStake(accumulatedRewardX128PerStake)
	self.setDistributedAmount(currentDistributedAmount)
	self.setAccumulatedTimestamp(currentTimestamp)

	return accumulatedRewardX128PerStake, nil
}

// updateAccumulatedRewardX128PerStake updates the internal accumulated reward state.
func (self *EmissionRewardManagerResolver) updateAccumulatedRewardX128PerStake(
	currentDistributedAmount int64,
	currentTimestamp int64,
) error {
	if currentTimestamp < self.GetAccumulatedTimestamp() {
		return nil
	}
	_, err := self.updateAccumulatedRewardX128PerStakeWithValue(
		currentDistributedAmount,
		currentTimestamp,
	)
	return err
}

// addStake adds a stake for an address and updates their reward state.
// This method ensures rewards are properly calculated before the stake change.
// Adds stake for specified address and updates reward calculations.
// addStake adds a stake for an address and updates their reward state.
func (self *EmissionRewardManagerResolver) addStake(address string, amount int64, currentTimestamp int64) error {
	if amount < 0 {
		return errors.New(errAmountMustBeNonNegative)
	}
	return self.addStakeWithAccumulatedReward(
		address,
		amount,
		currentTimestamp,
		self.GetAccumulatedRewardX128PerStake(),
	)
}

// addStakeWithAccumulatedReward uses an accumulator prepared earlier in the
// same transaction, avoiding a second persisted-value decode.
func (self *EmissionRewardManagerResolver) addStakeWithAccumulatedReward(
	address string,
	amount int64,
	currentTimestamp int64,
	accumulatedReward *u256.Uint,
) error {
	if amount < 0 {
		return errors.New(errAmountMustBeNonNegative)
	}

	rewardState, ok, err := self.GetRewardState(address)
	if err != nil {
		return err
	}
	if !ok {
		rewardState = staker.NewEmissionRewardState(accumulatedReward)
	}

	resolvedState := NewEmissionRewardStateResolver(rewardState)
	if err = resolvedState.addStakeWithUpdateRewardDebtX128(amount, accumulatedReward, currentTimestamp); err != nil {
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
// Removes stake for specified address and updates reward calculations.
// removeStake removes a stake for an address and updates their reward state.
func (self *EmissionRewardManagerResolver) removeStake(address string, amount int64, currentTimestamp int64) error {
	if amount < 0 {
		return errors.New(errAmountMustBeNonNegative)
	}
	return self.removeStakeWithAccumulatedReward(
		address,
		amount,
		currentTimestamp,
		self.GetAccumulatedRewardX128PerStake(),
	)
}

// removeStakeWithAccumulatedReward uses an accumulator prepared earlier in the
// same transaction, avoiding a second persisted-value decode.
func (self *EmissionRewardManagerResolver) removeStakeWithAccumulatedReward(
	address string,
	amount int64,
	currentTimestamp int64,
	accumulatedReward *u256.Uint,
) error {
	if amount < 0 {
		return errors.New(errAmountMustBeNonNegative)
	}

	updatedTotalStakedAmount := gnsmath.SafeSubInt64(self.GetTotalStakedAmount(), amount)
	if updatedTotalStakedAmount < 0 {
		return errors.New(errRemoveAmountExceedsTotalStaked)
	}

	rewardState, ok, err := self.GetRewardState(address)
	if err != nil {
		return err
	}
	if !ok {
		rewardState = staker.NewEmissionRewardState(accumulatedReward)
	}

	resolvedState := NewEmissionRewardStateResolver(rewardState)
	if err = resolvedState.removeStakeWithUpdateRewardDebtX128(amount, accumulatedReward, currentTimestamp); err != nil {
		return err
	}

	self.setRewardStates(address, rewardState)
	self.SetTotalStakedAmount(updatedTotalStakedAmount)
	return nil
}

// claimRewards processes reward claiming for an address.
// This method calculates and returns the amount of rewards claimed.
// Claims available rewards for specified address.
// claimRewards processes reward claiming for an address.
func (self *EmissionRewardManagerResolver) claimRewards(address string, currentTimestamp int64) (int64, error) {
	return self.claimRewardsWithAccumulatedReward(
		address,
		currentTimestamp,
		self.GetAccumulatedRewardX128PerStake(),
	)
}

// claimRewardsWithAccumulatedReward uses an accumulator prepared earlier in
// the same transaction, avoiding a second persisted-value decode.
func (self *EmissionRewardManagerResolver) claimRewardsWithAccumulatedReward(
	address string,
	currentTimestamp int64,
	accumulatedReward *u256.Uint,
) (claimedRewardAmount int64, err error) {
	rewardState, ok, err := self.GetRewardState(address)
	if err != nil || !ok {
		return 0, err
	}

	resolvedState := NewEmissionRewardStateResolver(rewardState)
	claimedRewardAmount, err = resolvedState.claimRewardsWithUpdateRewardDebtX128(accumulatedReward, currentTimestamp)
	if err != nil {
		return 0, err
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
