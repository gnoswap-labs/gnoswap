package staker

import (
	"errors"

	"gno.land/p/gnoswap/consts"
	gnsmath "gno.land/p/gnoswap/gnsmath"
	u256 "gno.land/p/gnoswap/uint256"
	"gno.land/r/gnoswap/gov/staker"
)

type EmissionRewardStateResolver struct {
	*staker.EmissionRewardState
}

// NewEmissionRewardStateResolver wraps an on-chain emission reward state for
// reward calculation and stake/claim updates.
//
// Parameters:
//   - emissionRewardState: persisted reward state to expose through the resolver
//
// Returns:
//   - *EmissionRewardStateResolver: resolver backed by emissionRewardState
func NewEmissionRewardStateResolver(emissionRewardState *staker.EmissionRewardState) *EmissionRewardStateResolver {
	return &EmissionRewardStateResolver{emissionRewardState}
}

// IsClaimable checks if rewards can be claimed at the given timestamp.
// Rewards are claimable only when currentTimestamp is later than the stored
// claimed timestamp.
//
// Parameters:
//   - currentTimestamp: timestamp at which claimability is evaluated
//
// Returns:
//   - bool: true when currentTimestamp is greater than the last claimed timestamp
func (self *EmissionRewardStateResolver) IsClaimable(currentTimestamp int64) bool {
	return self.GetClaimedTimestamp() < currentTimestamp
}

// GetClaimableRewardAmount calculates the total amount of rewards that can be claimed.
// It combines newly earned rewards with accumulated rewards not yet claimed.
//
// Parameters:
//   - accumulatedRewardX128PerStake: system-wide accumulated reward per stake, scaled by 2^128
//   - currentTimestamp: timestamp through which newly earned rewards are calculated
//
// Returns:
//   - int64: total claimable amount, including accumulated-but-unclaimed and newly earned rewards
//   - error: nil on success; an error propagated from reward calculation otherwise
func (self *EmissionRewardStateResolver) GetClaimableRewardAmount(
	accumulatedRewardX128PerStake *u256.Uint,
	currentTimestamp int64,
) (int64, error) {
	rewardAmount, err := self.calculateClaimableRewards(accumulatedRewardX128PerStake, currentTimestamp)
	if err != nil {
		return 0, err
	}

	accumulatedUnclaimedReward := gnsmath.SafeSubInt64(
		self.GetAccumulatedRewardAmount(),
		self.GetClaimedRewardAmount(),
	)

	return gnsmath.SafeAddInt64(accumulatedUnclaimedReward, rewardAmount), nil
}

// calculateClaimableRewards calculates newly earned rewards since the last update.
// It uses the accumulator difference and this address's stake, returning zero
// before the stored timestamp or when no stake is held.
//
// Parameters:
//   - accumulatedRewardX128PerStake: current system-wide accumulated reward per stake, scaled by 2^128
//   - currentTimestamp: timestamp through which newly earned rewards are calculated
//
// Returns:
//   - int64: newly earned reward amount since the stored reward-debt timestamp
//   - error: nil in the current implementation; arithmetic or int64-conversion failures panic
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
		consts.Q128(),
	)
	return gnsmath.SafeConvertToInt64(rewardAmount), nil
}

// addStake increases the staked amount for this address.
// Negative amounts are rejected.
//
// Parameters:
//   - amount: nonnegative amount of stake to add
//
// Returns:
//   - error: nil when the stake is updated; an error when amount is negative
func (self *EmissionRewardStateResolver) addStake(amount int64) error {
	if amount < 0 {
		return errors.New(errAmountMustBeNonNegative)
	}
	self.SetStakedAmount(gnsmath.SafeAddInt64(self.GetStakedAmount(), amount))
	return nil
}

// removeStake decreases the staked amount for this address.
// Negative amounts and amounts greater than the current stake are rejected.
//
// Parameters:
//   - amount: nonnegative amount of stake to remove
//
// Returns:
//   - error: nil when the stake is updated; an error when amount is negative or exceeds the current stake
func (self *EmissionRewardStateResolver) removeStake(amount int64) error {
	if amount < 0 {
		return errors.New(errAmountMustBeNonNegative)
	}
	if amount > self.GetStakedAmount() {
		return errors.New(errRemoveAmountExceedsStaked)
	}
	self.SetStakedAmount(gnsmath.SafeSubInt64(self.GetStakedAmount(), amount))
	return nil
}

// claimRewards processes reward claiming and updates the claim state.
// This method validates claimability and transfers accumulated rewards to claimed status.
//
// Parameters:
//   - currentTimestamp: current timestamp
//
// Returns:
//   - int64: amount of rewards claimed (0 if already claimed at this timestamp)
//   - error: always nil in the current implementation
func (self *EmissionRewardStateResolver) claimRewards(currentTimestamp int64) (int64, error) {
	if !self.IsClaimable(currentTimestamp) {
		return 0, nil
	}

	accumulatedRewardAmount := self.GetAccumulatedRewardAmount()
	previousClaimedAmount := self.GetClaimedRewardAmount()
	claimableAmount := gnsmath.SafeSubInt64(accumulatedRewardAmount, previousClaimedAmount)

	self.SetClaimedRewardAmount(accumulatedRewardAmount)
	self.SetClaimedTimestamp(currentTimestamp)

	return claimableAmount, nil
}

// updateRewardDebtX128 updates the reward debt and accumulates new rewards.
// It records the supplied accumulator and timestamp after calculating rewards
// through currentTimestamp.
//
// Parameters:
//   - accumulatedRewardX128PerStake: current system-wide accumulated reward per stake, scaled by 2^128
//   - currentTimestamp: timestamp at which the reward debt is refreshed
//
// Returns:
//   - error: nil when state is updated; an error propagated from reward calculation otherwise
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
		self.SetAccumulatedRewardAmount(gnsmath.SafeAddInt64(self.GetAccumulatedRewardAmount(), rewardAmount))
	}

	// Deep copy to avoid aliasing with external state
	self.SetRewardDebtX128(accumulatedRewardX128PerStake.Clone())
	self.SetAccumulatedTimestamp(currentTimestamp)
	return nil
}

// addStakeWithUpdateRewardDebtX128 refreshes reward debt before adding stake.
// This prevents the stake change from affecting rewards earned before it.
//
// Parameters:
//   - amount: nonnegative amount of stake to add
//   - accumulatedRewardX128PerStake: current system-wide accumulated reward per stake, scaled by 2^128
//   - currentTimestamp: timestamp through which rewards are settled before the stake change
//
// Returns:
//   - error: nil when debt refresh and stake addition succeed; an error from either operation otherwise
func (self *EmissionRewardStateResolver) addStakeWithUpdateRewardDebtX128(
	amount int64,
	accumulatedRewardX128PerStake *u256.Uint,
	currentTimestamp int64,
) error {
	if err := self.updateRewardDebtX128(accumulatedRewardX128PerStake, currentTimestamp); err != nil {
		return err
	}
	return self.addStake(amount)
}

// removeStakeWithUpdateRewardDebtX128 refreshes reward debt before removing stake.
// This prevents the stake change from affecting rewards earned before it.
//
// Parameters:
//   - amount: nonnegative amount of stake to remove
//   - accumulatedRewardX128PerStake: current system-wide accumulated reward per stake, scaled by 2^128
//   - currentTimestamp: timestamp through which rewards are settled before the stake change
//
// Returns:
//   - error: nil when debt refresh and stake removal succeed; an error from either operation otherwise
func (self *EmissionRewardStateResolver) removeStakeWithUpdateRewardDebtX128(
	amount int64,
	accumulatedRewardX128PerStake *u256.Uint,
	currentTimestamp int64,
) error {
	if err := self.updateRewardDebtX128(accumulatedRewardX128PerStake, currentTimestamp); err != nil {
		return err
	}
	return self.removeStake(amount)
}

// claimRewardsWithUpdateRewardDebtX128 settles newly earned rewards, refreshes
// reward debt, and then marks all accumulated rewards as claimed.
//
// Parameters:
//   - accumulatedRewardX128PerStake: current system-wide accumulated reward per stake, scaled by 2^128
//   - currentTimestamp: timestamp through which rewards are settled and claim time is recorded
//
// Returns:
//   - int64: amount of accumulated rewards marked claimed after the debt refresh
//   - error: nil when debt refresh and claim succeed; an error propagated from debt refresh otherwise
func (self *EmissionRewardStateResolver) claimRewardsWithUpdateRewardDebtX128(
	accumulatedRewardX128PerStake *u256.Uint,
	currentTimestamp int64,
) (int64, error) {
	if err := self.updateRewardDebtX128(accumulatedRewardX128PerStake, currentTimestamp); err != nil {
		return 0, err
	}
	return self.claimRewards(currentTimestamp)
}
