package v1

import (
	"errors"

	u256 "gno.land/p/gnoswap/uint256"
	"gno.land/r/gnoswap/gov/staker"
)

type ProtocolFeeRewardStateResolver struct {
	*staker.ProtocolFeeRewardState
}

func NewProtocolFeeRewardStateResolver(protocolFeeRewardState *staker.ProtocolFeeRewardState) *ProtocolFeeRewardStateResolver {
	return &ProtocolFeeRewardStateResolver{protocolFeeRewardState}
}

// IsClaimable checks if rewards can be claimed at the given timestamp.
// Rewards are claimable if the current timestamp is greater than the last claimed timestamp.
//
// Parameters:
//   - currentTimestamp: current timestamp to check against
//
// Returns:
//   - bool: true if rewards can be claimed, false otherwise
func (p *ProtocolFeeRewardStateResolver) IsClaimable(currentTimestamp int64) bool {
	return p.GetClaimedTimestamp() < currentTimestamp
}

// GetClaimableRewardAmounts calculates the claimable reward amounts for all tokens.
// This includes both accumulated rewards and newly earned rewards based on current state.
//
// Parameters:
//   - accumulatedRewardsX128PerStake: current system-wide accumulated rewards per stake for all tokens
//   - currentTimestamp: current timestamp
//
// Returns:
//   - map[string]int64: map of token path to claimable reward amount
//   - error: nil on success, error if claiming is not allowed
func (p *ProtocolFeeRewardStateResolver) GetClaimableRewardAmounts(
	accumulatedRewardsX128PerStake map[string]*u256.Uint,
	currentTimestamp int64,
) (map[string]int64, error) {
	rewardAmounts, err := p.calculateClaimableRewards(accumulatedRewardsX128PerStake, currentTimestamp)
	if err != nil {
		return nil, err
	}

	return rewardAmounts, nil
}

// calculateClaimableRewards calculates newly earned rewards for all tokens since the last update.
// This method uses the difference between current and stored reward debt to calculate earnings.
//
// Parameters:
//   - accumulatedRewardsX128PerStake: current system-wide accumulated rewards per stake for all tokens
//   - currentTimestamp: current timestamp
//
// Returns:
//   - map[string]int64: map of token path to newly earned reward amount
func (p *ProtocolFeeRewardStateResolver) calculateClaimableRewards(
	accumulatedRewardsX128PerStake map[string]*u256.Uint,
	currentTimestamp int64,
) (map[string]int64, error) {
	// Don't calculate rewards for past timestamps
	if p.GetAccumulatedTimestamp() >= currentTimestamp {
		return p.GetAccumulatedRewards(), nil
	}

	rewardAmounts := make(map[string]int64)
	stakedAmount := p.GetStakedAmount()

	// Calculate rewards for each token type
	for token, accumulatedRewardX128PerStake := range accumulatedRewardsX128PerStake {
		// Get reward debt for this token
		rewardDebtX128 := p.GetRewardDebtX128ForToken(token)
		if rewardDebtX128 == nil {
			rewardDebtX128 = u256.Zero()
		}

		// Calculate the difference in accumulated rewards per stake since last update
		// Using modular arithmetic for accumulator values - underflow is allowed and handled correctly
		rewardDebtDeltaX128 := u256.Zero().Sub(
			accumulatedRewardX128PerStake,
			rewardDebtX128,
		)

		// Multiply by staked amount to get total reward for this staker and token
		rewardAmount := u256.MulDiv(
			rewardDebtDeltaX128,
			u256.NewUintFromInt64(stakedAmount),
			q128,
		)

		rewardAmounts[token] = safeConvertToInt64(rewardAmount)
	}

	return rewardAmounts, nil
}

// addStake increases the staked amount for this address.
// This method should be called when a user increases their stake.
//
// Parameters:
//   - amount: amount of stake to add
func (p *ProtocolFeeRewardStateResolver) addStake(amount int64) {
	p.SetStakedAmount(safeAddInt64(p.GetStakedAmount(), amount))
}

// removeStake decreases the staked amount for this address.
// This method should be called when a user decreases their stake.
//
// Parameters:
//   - amount: amount of stake to remove
func (p *ProtocolFeeRewardStateResolver) removeStake(amount int64) {
	newAmount := p.GetStakedAmount() - amount
	if newAmount < 0 {
		newAmount = 0
	}
	p.SetStakedAmount(newAmount)
}

// claimRewards processes reward claiming for all tokens and updates the claim state.
// This method validates claimability and transfers accumulated rewards to claimed status.
//
// Parameters:
//   - currentTimestamp: current timestamp
//
// Returns:
//   - map[string]int64: map of token path to claimed reward amount
//   - error: nil on success, error if claiming is not allowed
func (p *ProtocolFeeRewardStateResolver) claimRewards(currentTimestamp int64) (map[string]int64, error) {
	if !p.IsClaimable(currentTimestamp) {
		return nil, errors.New("not claimable")
	}

	if p.GetAccumulatedTimestamp() < currentTimestamp {
		return nil, errors.New("must update reward debt before claiming rewards")
	}

	currentClaimedRewards := make(map[string]int64)
	accumulatedRewards := p.GetAccumulatedRewards()
	claimedRewards := p.GetClaimedRewards()

	// Calculate and update claimed amounts for each token
	for token, rewardAmount := range accumulatedRewards {
		claimedAmount := claimedRewards[token]
		currentClaimedRewards[token] = rewardAmount - claimedAmount
		p.SetClaimedRewardForToken(token, rewardAmount)
	}

	p.SetClaimedTimestamp(currentTimestamp)

	return currentClaimedRewards, nil
}

// updateRewardDebtX128 updates the reward debt and accumulates new rewards for all tokens.
// This method should be called before any stake changes to ensure accurate reward tracking.
//
// Parameters:
//   - accumulatedProtocolFeeX128PerStake: current system-wide accumulated protocol fees per stake for all tokens
//   - currentTimestamp: current timestamp
func (p *ProtocolFeeRewardStateResolver) updateRewardDebtX128(
	accumulatedProtocolFeeX128PerStake map[string]*u256.Uint,
	currentTimestamp int64,
) error {
	// Don't update if we're looking at a past timestamp
	if p.GetAccumulatedTimestamp() >= currentTimestamp {
		return nil
	}

	// Calculate and accumulate new rewards for all tokens
	rewardAmounts, err := p.calculateClaimableRewards(accumulatedProtocolFeeX128PerStake, currentTimestamp)
	if err != nil {
		return err
	}

	// Update reward debt for all tokens
	p.SetRewardDebtX128(accumulatedProtocolFeeX128PerStake)

	// Add newly calculated rewards to accumulated amounts
	accumulatedRewards := p.GetAccumulatedRewards()
	for token, rewardAmount := range rewardAmounts {
		p.SetAccumulatedRewardForToken(token, safeAddInt64(accumulatedRewards[token], rewardAmount))
	}

	p.SetAccumulatedTimestamp(currentTimestamp)

	return nil
}

// addStakeWithUpdateRewardDebtX128 adds stake and updates reward debt in one operation.
// This ensures rewards are properly calculated before the stake change takes effect.
//
// Parameters:
//   - amount: amount of stake to add
//   - accumulatedProtocolFeeX128PerStake: current system-wide accumulated protocol fees per stake
//   - currentTimestamp: current timestamp
func (p *ProtocolFeeRewardStateResolver) addStakeWithUpdateRewardDebtX128(
	amount int64,
	accumulatedProtocolFeeX128PerStake map[string]*u256.Uint,
	currentTimestamp int64,
) error {
	err := p.updateRewardDebtX128(accumulatedProtocolFeeX128PerStake, currentTimestamp)
	if err != nil {
		return err
	}

	p.addStake(amount)

	return nil
}

// removeStakeWithUpdateRewardDebtX128 removes stake and updates reward debt in one operation.
// This ensures rewards are properly calculated before the stake change takes effect.
//
// Parameters:
//   - amount: amount of stake to remove
//   - accumulatedProtocolFeeX128PerStake: current system-wide accumulated protocol fees per stake
//   - currentTimestamp: current timestamp
func (p *ProtocolFeeRewardStateResolver) removeStakeWithUpdateRewardDebtX128(
	amount int64,
	accumulatedProtocolFeeX128PerStake map[string]*u256.Uint,
	currentTimestamp int64,
) error {
	err := p.updateRewardDebtX128(accumulatedProtocolFeeX128PerStake, currentTimestamp)
	if err != nil {
		return err
	}

	p.removeStake(amount)

	return nil
}

// claimRewardsWithUpdateRewardDebtX128 claims rewards and updates reward debt in one operation.
// This ensures all rewards are properly calculated before claiming.
//
// Parameters:
//   - accumulatedProtocolFeeX128PerStake: current system-wide accumulated protocol fees per stake
//   - currentTimestamp: current timestamp
//
// Returns:
//   - map[string]int64: map of token path to claimed reward amount
//   - error: nil on success, error if claiming fails
func (p *ProtocolFeeRewardStateResolver) claimRewardsWithUpdateRewardDebtX128(
	accumulatedProtocolFeeX128PerStake map[string]*u256.Uint,
	currentTimestamp int64,
) (map[string]int64, error) {
	p.updateRewardDebtX128(accumulatedProtocolFeeX128PerStake, currentTimestamp)

	return p.claimRewards(currentTimestamp)
}
