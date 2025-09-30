package staker

import (
	"gno.land/p/nt/avl"
	"gno.land/p/nt/ufmt"

	u256 "gno.land/p/gnoswap/uint256"
)

// ProtocolFeeRewardManager manages the distribution of protocol fee rewards to stakers.
// Unlike emission rewards, protocol fees can come from multiple tokens, requiring
// separate tracking and distribution mechanisms for each token type.
type ProtocolFeeRewardManager struct {
	// rewardStates maps address to ProtocolFeeRewardState for tracking individual staker rewards
	rewardStates *avl.Tree // address -> ProtocolFeeRewardState

	// accumulatedProtocolFeeX128PerStake maps token path to accumulated fee per stake with 128-bit precision
	accumulatedProtocolFeeX128PerStake map[string]*u256.Uint
	// protocolFeeAmounts maps token path to total distributed protocol fee amounts
	protocolFeeAmounts map[string]int64
	// accumulatedTimestamp tracks the last timestamp when fees were accumulated
	accumulatedTimestamp int64
	// totalStakedAmount tracks the total amount of tokens staked in the system
	totalStakedAmount int64
}

// GetAccumulatedProtocolFeeX128PerStake returns the accumulated protocol fee per stake for a specific token.
//
// Parameters:
//   - token: token path to get accumulated fee for
//
// Returns:
//   - *u256.Uint: accumulated protocol fee per stake for the token (scaled by 2^128)
func (p *ProtocolFeeRewardManager) GetAccumulatedProtocolFeeX128PerStake(token string) *u256.Uint {
	return p.accumulatedProtocolFeeX128PerStake[token]
}

// GetAccumulatedTimestamp returns the last timestamp when protocol fees were accumulated.
//
// Returns:
//   - int64: last accumulated timestamp
func (p *ProtocolFeeRewardManager) GetAccumulatedTimestamp() int64 {
	return p.accumulatedTimestamp
}

// GetClaimableRewardAmounts calculates the claimable reward amounts for all tokens for a specific address.
// This method computes rewards based on current protocol fee distribution state and staking history.
//
// Parameters:
//   - protocolFeeAmounts: current protocol fee amounts for all tokens
//   - address: staker's address to calculate rewards for
//   - currentTimestamp: current timestamp
//
// Returns:
//   - map[string]int64: map of token path to claimable reward amount
func (p *ProtocolFeeRewardManager) GetClaimableRewardAmounts(
	protocolFeeAmounts map[string]int64,
	address string,
	currentTimestamp int64,
) (map[string]int64, error) {
	rewardStateI, ok := p.rewardStates.Get(address)
	if !ok {
		return make(map[string]int64), nil
	}

	rewardState, ok := rewardStateI.(*ProtocolFeeRewardState)
	if !ok {
		return nil, ufmt.Errorf(
			"failed to cast rewardStates's element to *ProtocolFeeRewardState: %T",
			rewardStateI,
		)
	}

	accumulatedRewardX128PerStake, _, err := p.calculateAccumulatedRewardX128PerStake(
		protocolFeeAmounts,
		currentTimestamp,
	)
	if err != nil {
		return nil, err
	}

	return rewardState.GetClaimableRewardAmounts(accumulatedRewardX128PerStake, currentTimestamp)
}

// calculateAccumulatedRewardX128PerStake calculates the updated accumulated reward per stake for all tokens.
// This method computes new accumulated reward rates based on newly distributed protocol fees.
//
// Parameters:
//   - protocolFeeAmounts: current protocol fee amounts for all tokens
//   - currentTimestamp: current timestamp
//
// Returns:
//   - map[string]*u256.Uint: updated accumulated reward per stake for each token
//   - map[string]int64: updated protocol fee amounts for each token
func (p *ProtocolFeeRewardManager) calculateAccumulatedRewardX128PerStake(
	protocolFeeAmounts map[string]int64,
	currentTimestamp int64,
) (map[string]*u256.Uint, map[string]int64, error) {
	// If we're looking at a past timestamp, return current state
	if p.accumulatedTimestamp > currentTimestamp {
		return p.accumulatedProtocolFeeX128PerStake, p.protocolFeeAmounts, nil
	}

	accumulatedProtocolFeesX128PerStake := make(map[string]*u256.Uint)
	changedProtocolFeeAmounts := make(map[string]int64)

	// Process each token's protocol fees
	for token, protocolFeeAmount := range protocolFeeAmounts {
		previousProtocolFeeAmount, ok := p.protocolFeeAmounts[token]
		if !ok {
			previousProtocolFeeAmount = 0
		}

		protocolFeeDelta := protocolFeeAmount - previousProtocolFeeAmount

		// If no new fees for this token, keep existing rate
		if protocolFeeDelta <= 0 {
			accumulatedProtocolFeesX128PerStake[token] = p.accumulatedProtocolFeeX128PerStake[token]
			if accumulatedProtocolFeesX128PerStake[token] == nil {
				accumulatedProtocolFeesX128PerStake[token] = u256.NewUint(0)
			}
		}

		// Scale the fee delta by 2^128 for precision
		protocolFeeDeltaX128 := u256.NewUintFromInt64(protocolFeeDelta)
		protocolFeeDeltaX128 = u256.Zero().Lsh(protocolFeeDeltaX128, 128)

		protocolFeeDeltaX128PerStake := u256.Zero()

		// Calculate fee per stake if there are staked tokens
		if p.totalStakedAmount > 0 {
			feePerStake := u256.Zero().Div(protocolFeeDeltaX128, u256.NewUintFromInt64(p.totalStakedAmount))
			protocolFeeDeltaX128PerStake = feePerStake
		}

		// Get current accumulated fee per stake for this token
		accumulatedProtocolFeeX128PerStake := u256.Zero()
		if p.accumulatedProtocolFeeX128PerStake[token] != nil {
			accumulatedProtocolFeeX128PerStake = p.accumulatedProtocolFeeX128PerStake[token]
		}

		// Add the new fee per stake to the accumulated amount
		accumulatedProtocolFeeX128PerStake = u256.Zero().Add(accumulatedProtocolFeeX128PerStake, protocolFeeDeltaX128PerStake)
		accumulatedProtocolFeesX128PerStake[token] = accumulatedProtocolFeeX128PerStake.Clone()

		changedProtocolFeeAmounts[token] = protocolFeeAmount
	}

	return accumulatedProtocolFeesX128PerStake, changedProtocolFeeAmounts, nil
}

// updateAccumulatedProtocolFeeX128PerStake updates the internal accumulated protocol fee state.
// This method should be called before any stake changes to ensure accurate reward calculations.
//
// Parameters:
//   - protocolFeeAmounts: current protocol fee amounts for all tokens
//   - currentTimestamp: current timestamp
func (p *ProtocolFeeRewardManager) updateAccumulatedProtocolFeeX128PerStake(
	protocolFeeAmounts map[string]int64,
	currentTimestamp int64,
) error {
	// Don't update if we're looking at a past timestamp
	if p.accumulatedTimestamp > currentTimestamp {
		return nil
	}

	accumulatedProtocolFeeX128PerStake, changedProtocolFeeAmounts, err := p.calculateAccumulatedRewardX128PerStake(
		protocolFeeAmounts,
		currentTimestamp,
	)
	if err != nil {
		return err
	}

	p.accumulatedProtocolFeeX128PerStake = accumulatedProtocolFeeX128PerStake
	p.protocolFeeAmounts = changedProtocolFeeAmounts
	p.accumulatedTimestamp = currentTimestamp

	return nil
}

// addStake adds a stake for an address and updates their protocol fee reward state.
// This method ensures rewards are properly calculated before the stake change.
//
// Parameters:
//   - address: staker's address
//   - amount: amount of stake to add
//   - currentTimestamp: current timestamp
func (p *ProtocolFeeRewardManager) addStake(address string, amount int64, currentTimestamp int64) error {
	rewardStateI, ok := p.rewardStates.Get(address)
	if !ok {
		rewardStateI = NewProtocolFeeRewardState(p.accumulatedProtocolFeeX128PerStake)
	}

	rewardState, ok := rewardStateI.(*ProtocolFeeRewardState)
	if !ok {
		return ufmt.Errorf(
			"failed to cast rewardStates's element to *ProtocolFeeRewardState: %T",
			rewardStateI,
		)
	}

	err := rewardState.addStakeWithUpdateRewardDebtX128(amount, p.accumulatedProtocolFeeX128PerStake, currentTimestamp)
	if err != nil {
		return err
	}

	p.rewardStates.Set(address, rewardState)

	p.totalStakedAmount = p.totalStakedAmount + amount

	return nil
}

// removeStake removes a stake for an address and updates their protocol fee reward state.
// This method ensures rewards are properly calculated before the stake change.
//
// Parameters:
//   - address: staker's address
//   - amount: amount of stake to remove
//   - currentTimestamp: current timestamp
func (p *ProtocolFeeRewardManager) removeStake(address string, amount int64, currentTimestamp int64) error {
	rewardStateI, ok := p.rewardStates.Get(address)
	if !ok {
		rewardStateI = NewProtocolFeeRewardState(p.accumulatedProtocolFeeX128PerStake)
	}

	rewardState, ok := rewardStateI.(*ProtocolFeeRewardState)
	if !ok {
		return ufmt.Errorf(
			"failed to cast rewardStates's element to *ProtocolFeeRewardState: %T",
			rewardStateI,
		)
	}

	err := rewardState.removeStakeWithUpdateRewardDebtX128(amount, p.accumulatedProtocolFeeX128PerStake, currentTimestamp)
	if err != nil {
		return err
	}

	p.rewardStates.Set(address, rewardState)

	p.totalStakedAmount = p.totalStakedAmount - amount

	return nil
}

// claimRewards processes protocol fee reward claiming for an address.
// This method calculates and returns the amounts of rewards claimed for each token.
//
// Parameters:
//   - address: staker's address claiming rewards
//   - currentTimestamp: current timestamp
//
// Returns:
//   - map[string]int64: map of token path to claimed reward amount
//   - error: nil on success, error if claiming fails
func (p *ProtocolFeeRewardManager) claimRewards(address string, currentTimestamp int64) (map[string]int64, error) {
	rewardStateI, ok := p.rewardStates.Get(address)
	if !ok {
		return make(map[string]int64), nil
	}

	rewardState, ok := rewardStateI.(*ProtocolFeeRewardState)
	if !ok {
		return nil, ufmt.Errorf(
			"failed to cast rewardStates's element to *ProtocolFeeRewardState: %T",
			rewardStateI,
		)
	}

	claimedRewards, err := rewardState.claimRewardsWithUpdateRewardDebtX128(
		p.accumulatedProtocolFeeX128PerStake,
		currentTimestamp,
	)
	if err != nil {
		return nil, err
	}

	p.rewardStates.Set(address, rewardState)

	return claimedRewards, nil
}

// NewProtocolFeeRewardManager creates a new instance of ProtocolFeeRewardManager.
// This factory function initializes all tracking structures for multi-token protocol fee reward management.
//
// Returns:
//   - *ProtocolFeeRewardManager: new protocol fee reward manager instance
func NewProtocolFeeRewardManager() *ProtocolFeeRewardManager {
	return &ProtocolFeeRewardManager{
		rewardStates:                       avl.NewTree(),
		protocolFeeAmounts:                 make(map[string]int64),
		accumulatedProtocolFeeX128PerStake: make(map[string]*u256.Uint),
		accumulatedTimestamp:               0,
		totalStakedAmount:                  0,
	}
}
