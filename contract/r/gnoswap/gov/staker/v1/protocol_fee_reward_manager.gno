package v1

import (
	"errors"
	"math"

	u256 "gno.land/p/gnoswap/uint256"
	"gno.land/r/gnoswap/gov/staker"
)

type ProtocolFeeRewardManagerResolver struct {
	*staker.ProtocolFeeRewardManager
}

func NewProtocolFeeRewardManagerResolver(manager *staker.ProtocolFeeRewardManager) *ProtocolFeeRewardManagerResolver {
	return &ProtocolFeeRewardManagerResolver{manager}
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
func (self *ProtocolFeeRewardManagerResolver) GetClaimableRewardAmounts(
	protocolFeeAmounts map[string]int64,
	address string,
	currentTimestamp int64,
) (map[string]int64, error) {
	rewardState, ok, err := self.GetRewardState(address)
	if err != nil {
		return nil, err
	}
	if !ok {
		return make(map[string]int64), nil
	}

	accumulatedRewardX128PerStake, _, err := self.calculateAccumulatedRewardX128PerStake(
		protocolFeeAmounts,
		currentTimestamp,
	)
	if err != nil {
		return nil, err
	}

	resolvedState := NewProtocolFeeRewardStateResolver(rewardState)
	return resolvedState.GetClaimableRewardAmounts(accumulatedRewardX128PerStake, currentTimestamp)
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
func (self *ProtocolFeeRewardManagerResolver) calculateAccumulatedRewardX128PerStake(
	protocolFeeAmounts map[string]int64,
	currentTimestamp int64,
) (map[string]*u256.Uint, map[string]int64, error) {
	// If we're looking at a past timestamp, return current state
	if self.GetAccumulatedTimestamp() > currentTimestamp {
		return self.GetAllAccumulatedProtocolFeeX128PerStake(), self.GetProtocolFeeAmounts(), nil
	}

	accumulatedProtocolFeesX128PerStake := make(map[string]*u256.Uint)
	changedProtocolFeeAmounts := make(map[string]int64)

	// Process each token's protocol fees
	for token, protocolFeeAmount := range protocolFeeAmounts {
		previousProtocolFeeAmount := self.GetProtocolFeeAmount(token)

		protocolFeeDelta := safeSubInt64(protocolFeeAmount, previousProtocolFeeAmount)

		// If no new fees for this token, keep existing rate
		if protocolFeeDelta <= 0 {
			accumulatedProtocolFeesX128PerStake[token] = self.GetAccumulatedProtocolFeeX128PerStake(token)
			if accumulatedProtocolFeesX128PerStake[token] == nil {
				accumulatedProtocolFeesX128PerStake[token] = u256.NewUint(0)
			}
		}

		// Scale the fee delta by 2^128 for precision
		protocolFeeDeltaX128 := u256.NewUintFromInt64(protocolFeeDelta)
		protocolFeeDeltaX128 = u256.Zero().Lsh(protocolFeeDeltaX128, 128)

		protocolFeeDeltaX128PerStake := u256.Zero()

		// Calculate fee per stake if there are staked tokens
		if self.GetTotalStakedAmount() > 0 {
			feePerStake := u256.Zero().Div(protocolFeeDeltaX128, u256.NewUintFromInt64(self.GetTotalStakedAmount()))
			protocolFeeDeltaX128PerStake = feePerStake
		}

		// Get current accumulated fee per stake for this token
		accumulatedProtocolFeeX128PerStake := u256.Zero()
		existingAccumulatedFee := self.GetAccumulatedProtocolFeeX128PerStake(token)
		if existingAccumulatedFee != nil {
			accumulatedProtocolFeeX128PerStake = existingAccumulatedFee
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
func (self *ProtocolFeeRewardManagerResolver) updateAccumulatedProtocolFeeX128PerStake(
	protocolFeeAmounts map[string]int64,
	currentTimestamp int64,
) error {
	// Don't update if we're looking at a past timestamp
	if self.GetAccumulatedTimestamp() > currentTimestamp {
		return nil
	}

	accumulatedProtocolFeeX128PerStake, changedProtocolFeeAmounts, err := self.calculateAccumulatedRewardX128PerStake(
		protocolFeeAmounts,
		currentTimestamp,
	)
	if err != nil {
		return err
	}

	self.SetAccumulatedProtocolFeeX128PerStake(accumulatedProtocolFeeX128PerStake)
	self.SetProtocolFeeAmounts(changedProtocolFeeAmounts)
	self.SetAccumulatedTimestamp(currentTimestamp)

	return nil
}

// addStake adds a stake for an address and updates their protocol fee reward state.
// This method ensures rewards are properly calculated before the stake change.
//
// Parameters:
//   - address: staker's address
//   - amount: amount of stake to add
//   - currentTimestamp: current timestamp
func (self *ProtocolFeeRewardManagerResolver) addStake(address string, amount int64, currentTimestamp int64) error {
	if amount < 0 {
		return errors.New("amount must be non-negative")
	}

	rewardState, ok, err := self.GetRewardState(address)
	if err != nil {
		return err
	}
	if !ok {
		rewardState = staker.NewProtocolFeeRewardState(self.GetAllAccumulatedProtocolFeeX128PerStake())
	}

	resolvedState := NewProtocolFeeRewardStateResolver(rewardState)
	err = resolvedState.addStakeWithUpdateRewardDebtX128(amount, self.GetAllAccumulatedProtocolFeeX128PerStake(), currentTimestamp)
	if err != nil {
		return err
	}

	self.setRewardState(address, rewardState)

	currentTotal := self.GetTotalStakedAmount()
	if amount > 0 && currentTotal > math.MaxInt64-amount {
		return errors.New("total staked amount would overflow")
	}
	self.SetTotalStakedAmount(safeAddInt64(currentTotal, amount))

	return nil
}

// removeStake removes a stake for an address and updates their protocol fee reward state.
// This method ensures rewards are properly calculated before the stake change.
//
// Parameters:
//   - address: staker's address
//   - amount: amount of stake to remove
//   - currentTimestamp: current timestamp
func (self *ProtocolFeeRewardManagerResolver) removeStake(address string, amount int64, currentTimestamp int64) error {
	if amount < 0 {
		return errors.New("amount must be non-negative")
	}

	rewardState, ok, err := self.GetRewardState(address)
	if err != nil {
		return err
	}
	if !ok {
		rewardState = staker.NewProtocolFeeRewardState(self.GetAllAccumulatedProtocolFeeX128PerStake())
	}

	resolvedState := NewProtocolFeeRewardStateResolver(rewardState)
	err = resolvedState.removeStakeWithUpdateRewardDebtX128(amount, self.GetAllAccumulatedProtocolFeeX128PerStake(), currentTimestamp)
	if err != nil {
		return err
	}

	self.setRewardState(address, rewardState)

	updatedTotalStakedAmount := safeSubInt64(self.GetTotalStakedAmount(), amount)
	if updatedTotalStakedAmount < 0 {
		updatedTotalStakedAmount = 0
	}
	self.SetTotalStakedAmount(updatedTotalStakedAmount)

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
func (self *ProtocolFeeRewardManagerResolver) claimRewards(address string, currentTimestamp int64) (map[string]int64, error) {
	rewardState, ok, err := self.GetRewardState(address)
	if err != nil {
		return nil, err
	}
	if !ok {
		return make(map[string]int64), nil
	}

	resolvedState := NewProtocolFeeRewardStateResolver(rewardState)
	claimedRewards, err := resolvedState.claimRewardsWithUpdateRewardDebtX128(
		self.GetAllAccumulatedProtocolFeeX128PerStake(),
		currentTimestamp,
	)
	if err != nil {
		return nil, err
	}

	self.setRewardState(address, rewardState)

	return claimedRewards, nil
}

func (self *ProtocolFeeRewardManagerResolver) setRewardState(address string, rewardState *staker.ProtocolFeeRewardState) {
	self.SetRewardState(address, rewardState)
}
