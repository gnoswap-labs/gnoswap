package staker

import (
	"errors"

	u256 "gno.land/p/gnoswap/uint256"
)

// ProtocolFeeRewardState tracks protocol fee reward information for an individual staker across multiple tokens.
// Unlike emission rewards which are single-token, protocol fees can come from various trading pairs,
// requiring separate tracking and calculation for each token type.
type ProtocolFeeRewardState struct {
	// rewardDebtX128 maps token path to reward debt with 128-bit precision scaling
	// Used to calculate rewards earned since the last update for each token
	rewardDebtX128 map[string]*u256.Uint
	// accumulatedRewards maps token path to total rewards accumulated but not yet claimed
	accumulatedRewards map[string]int64
	// claimedRewards maps token path to total amount of rewards that have been claimed
	claimedRewards map[string]int64
	// accumulatedTimestamp is the last timestamp when rewards were accumulated
	accumulatedTimestamp int64
	// claimedTimestamp is the last timestamp when rewards were claimed
	claimedTimestamp int64
	// stakedAmount is the current amount of tokens staked by this address
	stakedAmount int64
}

// IsClaimable checks if rewards can be claimed at the given timestamp.
// Rewards are claimable if the current timestamp is greater than the last claimed timestamp.
//
// Parameters:
//   - currentTimestamp: current timestamp to check against
//
// Returns:
//   - bool: true if rewards can be claimed, false otherwise
func (p *ProtocolFeeRewardState) IsClaimable(currentTimestamp int64) bool {
	return p.claimedTimestamp < currentTimestamp
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
func (p *ProtocolFeeRewardState) GetClaimableRewardAmounts(
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
func (p *ProtocolFeeRewardState) calculateClaimableRewards(
	accumulatedRewardsX128PerStake map[string]*u256.Uint,
	currentTimestamp int64,
) (map[string]int64, error) {
	// Don't calculate rewards for past timestamps
	if p.accumulatedTimestamp >= currentTimestamp {
		return p.accumulatedRewards, nil
	}

	rewardAmounts := make(map[string]int64)

	// Calculate rewards for each token type
	for token, accumulatedRewardX128PerStake := range accumulatedRewardsX128PerStake {
		// Initialize reward debt if it doesn't exist for this token
		if p.rewardDebtX128[token] == nil {
			p.rewardDebtX128[token] = u256.Zero()
		}

		// Calculate the difference in accumulated rewards per stake since last update
		// Using modular arithmetic for accumulator values - underflow is allowed and handled correctly
		rewardDebtDeltaX128 := u256.Zero().Sub(
			accumulatedRewardX128PerStake,
			p.rewardDebtX128[token],
		)

		// Multiply by staked amount to get total reward for this staker and token
		rewardAmount := u256.MulDiv(
			rewardDebtDeltaX128,
			u256.NewUintFromInt64(p.stakedAmount),
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
func (p *ProtocolFeeRewardState) addStake(amount int64) {
	p.stakedAmount = p.stakedAmount + amount
}

// removeStake decreases the staked amount for this address.
// This method should be called when a user decreases their stake.
//
// Parameters:
//   - amount: amount of stake to remove
func (p *ProtocolFeeRewardState) removeStake(amount int64) {
	p.stakedAmount = p.stakedAmount - amount
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
func (p *ProtocolFeeRewardState) claimRewards(currentTimestamp int64) (map[string]int64, error) {
	if !p.IsClaimable(currentTimestamp) {
		return nil, errors.New("not claimable")
	}

	if p.accumulatedTimestamp < currentTimestamp {
		return nil, errors.New("must update reward debt before claiming rewards")
	}

	currentClaimedRewards := make(map[string]int64)

	// Calculate and update claimed amounts for each token
	for token, rewardAmount := range p.accumulatedRewards {
		currentClaimedRewards[token] = rewardAmount - p.claimedRewards[token]
		p.claimedRewards[token] = rewardAmount
	}

	p.claimedTimestamp = currentTimestamp

	return currentClaimedRewards, nil
}

// updateRewardDebtX128 updates the reward debt and accumulates new rewards for all tokens.
// This method should be called before any stake changes to ensure accurate reward tracking.
//
// Parameters:
//   - accumulatedProtocolFeeX128PerStake: current system-wide accumulated protocol fees per stake for all tokens
//   - currentTimestamp: current timestamp
func (p *ProtocolFeeRewardState) updateRewardDebtX128(
	accumulatedProtocolFeeX128PerStake map[string]*u256.Uint,
	currentTimestamp int64,
) error {
	// Don't update if we're looking at a past timestamp
	if p.accumulatedTimestamp >= currentTimestamp {
		return nil
	}

	// Calculate and accumulate new rewards for all tokens
	rewardAmounts, err := p.calculateClaimableRewards(accumulatedProtocolFeeX128PerStake, currentTimestamp)
	if err != nil {
		return err
	}

	p.rewardDebtX128 = cloneAccumulatedProtocolFeeX128PerStake(accumulatedProtocolFeeX128PerStake)

	// Add newly calculated rewards to accumulated amounts
	for token, rewardAmount := range rewardAmounts {
		p.accumulatedRewards[token] = p.accumulatedRewards[token] + rewardAmount
	}

	p.accumulatedTimestamp = currentTimestamp

	return nil
}

// addStakeWithUpdateRewardDebtX128 adds stake and updates reward debt in one operation.
// This ensures rewards are properly calculated before the stake change takes effect.
//
// Parameters:
//   - amount: amount of stake to add
//   - accumulatedProtocolFeeX128PerStake: current system-wide accumulated protocol fees per stake
//   - currentTimestamp: current timestamp
func (p *ProtocolFeeRewardState) addStakeWithUpdateRewardDebtX128(
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
func (p *ProtocolFeeRewardState) removeStakeWithUpdateRewardDebtX128(
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
func (p *ProtocolFeeRewardState) claimRewardsWithUpdateRewardDebtX128(
	accumulatedProtocolFeeX128PerStake map[string]*u256.Uint,
	currentTimestamp int64,
) (map[string]int64, error) {
	p.updateRewardDebtX128(accumulatedProtocolFeeX128PerStake, currentTimestamp)

	return p.claimRewards(currentTimestamp)
}

// NewProtocolFeeRewardState creates a new protocol fee reward state for a staker.
// This factory function initializes the state with the current system reward debt for all tokens.
//
// Parameters:
//   - accumulatedProtocolFeeX128PerStake: current system-wide accumulated protocol fees per stake for all tokens
//
// Returns:
//   - *ProtocolFeeRewardState: new protocol fee reward state instance
func NewProtocolFeeRewardState(
	accumulatedProtocolFeeX128PerStake map[string]*u256.Uint,
) *ProtocolFeeRewardState {
	rewardDebtX128 := make(map[string]*u256.Uint)

	// Clone reward debt for each token to avoid reference issues
	for token, accumulatedProtocolFeeX128PerStake := range accumulatedProtocolFeeX128PerStake {
		rewardDebtX128[token] = accumulatedProtocolFeeX128PerStake.Clone()
	}

	return &ProtocolFeeRewardState{
		rewardDebtX128:       rewardDebtX128,
		claimedRewards:       map[string]int64{},
		accumulatedRewards:   map[string]int64{},
		stakedAmount:         0,
		accumulatedTimestamp: 0,
		claimedTimestamp:     0,
	}
}

// cloneAccumulatedProtocolFeeX128PerStake creates a deep copy of the accumulated protocol fee map.
// This utility function prevents reference sharing between different reward states.
//
// Parameters:
//   - accumulatedProtocolFeeX128PerStake: map to clone
//
// Returns:
//   - map[string]*u256.Uint: deep copy of the input map
func cloneAccumulatedProtocolFeeX128PerStake(accumulatedProtocolFeeX128PerStake map[string]*u256.Uint) map[string]*u256.Uint {
	clone := make(map[string]*u256.Uint)

	for token, item := range accumulatedProtocolFeeX128PerStake {
		clone[token] = item.Clone()
	}

	return clone
}
