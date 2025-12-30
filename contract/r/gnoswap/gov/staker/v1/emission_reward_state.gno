package v1

import (
	"errors"

	u256 "gno.land/p/gnoswap/uint256"
	"gno.land/r/gnoswap/gov/staker"
)

var errNotClaimable = errors.New("not claimable")

type EmissionRewardStateResolver struct {
	*staker.EmissionRewardState
}

func NewEmissionRewardStateResolver(emissionRewardState *staker.EmissionRewardState) *EmissionRewardStateResolver {
	return &EmissionRewardStateResolver{emissionRewardState}
}

// IsClaimable checks if rewards can be claimed at the given timestamp.
// Rewards are claimable if the current timestamp is greater than the last claimed timestamp.
//
// Parameters:
//   - currentTimestamp: current timestamp to check against
//
// Returns:
//   - bool: true if rewards can be claimed, false otherwise
func (self *EmissionRewardStateResolver) IsClaimable(currentTimestamp int64) bool {
	return self.GetClaimedTimestamp() < currentTimestamp
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
func (self *EmissionRewardStateResolver) GetClaimableRewardAmount(
	accumulatedRewardX128PerStake *u256.Uint,
	currentTimestamp int64,
) (int64, error) {
	rewardAmount, err := self.calculateClaimableRewards(accumulatedRewardX128PerStake, currentTimestamp)
	if err != nil {
		return 0, err
	}
	return safeAddInt64(self.GetAccumulatedRewardAmount(), rewardAmount), nil
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
func (self *EmissionRewardStateResolver) calculateClaimableRewards(
	accumulatedRewardX128PerStake *u256.Uint,
	currentTimestamp int64,
) (int64, error) {
	stakedAmount := self.GetStakedAmount()

	// Don't calculate rewards for past timestamps or when nothing is staked
	if currentTimestamp < self.GetAccumulatedTimestamp() || stakedAmount == 0 {
		return 0, nil
	}

	// Calculate the difference in accumulated rewards per stake since last update
	// Using modular arithmetic for accumulator values - underflow is allowed and handled correctly
	rewardDebtDeltaX128 := u256.Zero().Sub(
		accumulatedRewardX128PerStake,
		self.GetRewardDebtX128(),
	)

	// Calculate reward amount by multiplying reward debt delta by staked amount and dividing by Q128
	// rewardAmount = (rewardDebtDeltaX128 * stakedAmount) / Q128
	rewardAmount := u256.MulDiv(
		rewardDebtDeltaX128,
		u256.NewUintFromInt64(stakedAmount),
		q128,
	)
	return safeConvertToInt64(rewardAmount), nil
}

// addStake increases the staked amount for this address.
// This method should be called when a user increases their stake.
//
// Parameters:
//   - amount: amount of stake to add
func (self *EmissionRewardStateResolver) addStake(amount int64) {
	self.adjustStake(amount)
}

// removeStake decreases the staked amount for this address.
// This method should be called when a user decreases their stake.
//
// Parameters:
//   - amount: amount of stake to remove
func (self *EmissionRewardStateResolver) removeStake(amount int64) {
	self.adjustStake(-amount)
}

// adjustStake is a small internal helper to centralize bound checks and math.
func (self *EmissionRewardStateResolver) adjustStake(delta int64) {
	if delta == 0 {
		return
	}
	// clamp at zero on underflow
	newAmt := safeAddInt64(self.GetStakedAmount(), delta)
	if newAmt < 0 {
		newAmt = 0
	}
	self.SetStakedAmount(newAmt)
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
func (self *EmissionRewardStateResolver) claimRewards(currentTimestamp int64) (int64, error) {
	if !self.IsClaimable(currentTimestamp) {
		return 0, errNotClaimable
	}

	accumulatedRewardAmount := self.GetAccumulatedRewardAmount()
	previousClaimedAmount := self.GetClaimedRewardAmount()
	claimableAmount := safeSubInt64(accumulatedRewardAmount, previousClaimedAmount)

	self.SetClaimedRewardAmount(accumulatedRewardAmount)
	self.SetClaimedTimestamp(currentTimestamp)

	return claimableAmount, nil
}

// updateRewardDebtX128 updates the reward debt and accumulates new rewards.
// This method should be called before any stake changes to ensure accurate reward tracking.
//
// Parameters:
//   - accumulatedRewardX128PerStake: current system-wide accumulated reward per stake
//   - currentTimestamp: current timestamp
func (self *EmissionRewardStateResolver) updateRewardDebtX128(
	accumulatedRewardX128PerStake *u256.Uint,
	currentTimestamp int64,
) error {
	rewardAmount, err := self.calculateClaimableRewards(accumulatedRewardX128PerStake, currentTimestamp)
	if err != nil {
		return err
	}

	// Accumulate newly earned rewards
	if rewardAmount != 0 {
		self.SetAccumulatedRewardAmount(safeAddInt64(self.GetAccumulatedRewardAmount(), rewardAmount))
	}

	// Deep copy to avoid aliasing with external state
	self.SetRewardDebtX128(accumulatedRewardX128PerStake.Clone())
	self.SetAccumulatedTimestamp(currentTimestamp)
	return nil
}

// addStakeWithUpdateRewardDebtX128 adds stake and updates reward debt in one operation.
// This ensures rewards are properly calculated before the stake change takes effect.
//
// Parameters:
//   - amount: amount of stake to add
//   - accumulatedRewardX128PerStake: current system-wide accumulated reward per stake
//   - currentTimestamp: current timestamp
func (self *EmissionRewardStateResolver) addStakeWithUpdateRewardDebtX128(
	amount int64,
	accumulatedRewardX128PerStake *u256.Uint,
	currentTimestamp int64,
) error {
	if err := self.updateRewardDebtX128(accumulatedRewardX128PerStake, currentTimestamp); err != nil {
		return err
	}
	self.addStake(amount)
	return nil
}

// removeStakeWithUpdateRewardDebtX128 removes stake and updates reward debt in one operation.
// This ensures rewards are properly calculated before the stake change takes effect.
//
// Parameters:
//   - amount: amount of stake to remove
//   - accumulatedRewardX128PerStake: current system-wide accumulated reward per stake
//   - currentTimestamp: current timestamp
func (self *EmissionRewardStateResolver) removeStakeWithUpdateRewardDebtX128(
	amount int64,
	accumulatedRewardX128PerStake *u256.Uint,
	currentTimestamp int64,
) error {
	if err := self.updateRewardDebtX128(accumulatedRewardX128PerStake, currentTimestamp); err != nil {
		return err
	}
	self.removeStake(amount)
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
func (self *EmissionRewardStateResolver) claimRewardsWithUpdateRewardDebtX128(
	accumulatedRewardX128PerStake *u256.Uint,
	currentTimestamp int64,
) (int64, error) {
	if err := self.updateRewardDebtX128(accumulatedRewardX128PerStake, currentTimestamp); err != nil {
		return 0, err
	}
	return self.claimRewards(currentTimestamp)
}
