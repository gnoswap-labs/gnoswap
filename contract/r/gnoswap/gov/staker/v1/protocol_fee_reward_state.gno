package v1

import (
	"errors"

	"gno.land/p/nt/avl"
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
	accumulatedRewardsX128PerStake *avl.Tree,
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
	accumulatedRewardsX128PerStake *avl.Tree,
	currentTimestamp int64,
) (map[string]int64, error) {
	// Don't calculate rewards for past timestamps
	if p.GetAccumulatedTimestamp() >= currentTimestamp {
		// Convert AVL tree to map for return
		result := make(map[string]int64)
		accumulatedRewards := p.GetAccumulatedRewards()
		if accumulatedRewards != nil {
			accumulatedRewards.Iterate("", "", func(key string, value interface{}) bool {
				if amount, ok := value.(int64); ok {
					result[key] = amount
				}
				return false
			})
		}
		return result, nil
	}

	rewardAmounts := make(map[string]int64)
	stakedAmount := p.GetStakedAmount()

	// Calculate rewards for each token type by iterating AVL tree
	if accumulatedRewardsX128PerStake != nil {
		accumulatedRewardsX128PerStake.Iterate("", "", func(token string, value interface{}) bool {
			accumulatedRewardX128PerStake, ok := value.(*u256.Uint)
			if !ok {
				return false
			}

			// Get reward debt for this token
			rewardDebtX128 := p.GetRewardDebtX128ForToken(token)
			if rewardDebtX128 == nil {
				rewardDebtX128 = u256.Zero()
				p.SetRewardDebtX128ForToken(token, u256.Zero())
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
			return false
		})
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
	newAmount := safeSubInt64(p.GetStakedAmount(), amount)
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

	// Calculate and update claimed amounts for each token by iterating AVL trees
	if accumulatedRewards != nil {
		accumulatedRewards.Iterate("", "", func(token string, value interface{}) bool {
			rewardAmount, ok := value.(int64)
			if !ok {
				return false
			}

			claimedAmount := p.GetClaimedRewardForToken(token)
			currentClaimedRewards[token] = safeSubInt64(rewardAmount, claimedAmount)
			p.SetClaimedRewardForToken(token, rewardAmount)
			return false
		})
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
	accumulatedProtocolFeeX128PerStake *avl.Tree,
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
	newRewardDebtX128 := cloneAccumulatedProtocolFeeX128PerStake(accumulatedProtocolFeeX128PerStake)
	p.SetRewardDebtX128(newRewardDebtX128)

	// Add newly calculated rewards to accumulated amounts
	for token, rewardAmount := range rewardAmounts {
		currentAccumulated := p.GetAccumulatedRewardForToken(token)
		p.SetAccumulatedRewardForToken(token, safeAddInt64(currentAccumulated, rewardAmount))
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
	accumulatedProtocolFeeX128PerStake *avl.Tree,
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
	accumulatedProtocolFeeX128PerStake *avl.Tree,
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
	accumulatedProtocolFeeX128PerStake *avl.Tree,
	currentTimestamp int64,
) (map[string]int64, error) {
	p.updateRewardDebtX128(accumulatedProtocolFeeX128PerStake, currentTimestamp)

	return p.claimRewards(currentTimestamp)
}

// cloneAccumulatedProtocolFeeX128PerStake creates a deep copy of the accumulated protocol fee tree.
// This utility function prevents reference sharing between different reward states.
//
// Parameters:
//   - accumulatedProtocolFeeX128PerStake: tree to clone
//
// Returns:
//   - *avl.Tree: deep copy of the input tree
func cloneAccumulatedProtocolFeeX128PerStake(accumulatedProtocolFeeX128PerStake *avl.Tree) *avl.Tree {
	clone := avl.NewTree()

	if accumulatedProtocolFeeX128PerStake != nil {
		accumulatedProtocolFeeX128PerStake.Iterate("", "", func(token string, value interface{}) bool {
			if item, ok := value.(*u256.Uint); ok {
				clone.Set(token, item.Clone())
			}
			return false
		})
	}

	return clone
}
