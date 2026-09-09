package staker

import (
	"errors"
	"math"

	gnsmath "gno.land/p/gnoswap/gnsmath"
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

	// The domain-owned map is readonly-tainted here; copy its entries into this realm.
	stored := self.GetAllAccumulatedProtocolFeeX128PerStake()
	accumulatedRewardX128PerStake := make(map[string]*u256.Uint, len(stored))
	for token, rate := range stored {
		accumulatedRewardX128PerStake[token] = rate
	}
	recalculatedRewardX128PerStake, _, _, err := self.calculateAccumulatedRewardX128PerStakeWithBase(
		protocolFeeAmounts,
		currentTimestamp,
		accumulatedRewardX128PerStake,
	)
	if err != nil {
		return nil, err
	}

	// Layer newly accrued tokens onto an isolated copy of the stored accumulator map.
	for token, rate := range recalculatedRewardX128PerStake {
		accumulatedRewardX128PerStake[token] = rate
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
func (self *ProtocolFeeRewardManagerResolver) calculateAccumulatedRewardX128PerStakeWithBase(
	protocolFeeAmounts map[string]int64,
	currentTimestamp int64,
	baseAccumulatedFees map[string]*u256.Uint,
) (map[string]*u256.Uint, map[string]int64, map[string]*u256.Uint, error) {
	if self.GetAccumulatedTimestamp() > currentTimestamp {
		if baseAccumulatedFees != nil {
			return baseAccumulatedFees, self.GetProtocolFeeAmounts(), make(map[string]*u256.Uint), nil
		}
		return self.GetAllAccumulatedProtocolFeeX128PerStake(), self.GetProtocolFeeAmounts(), make(map[string]*u256.Uint), nil
	}

	accumulatedProtocolFeesX128PerStake := make(map[string]*u256.Uint)
	changedProtocolFeeAmounts := make(map[string]int64)
	previousAccumulatedFees := make(map[string]*u256.Uint)
	totalStakedAmount := self.GetTotalStakedAmount()

	for token, protocolFeeAmount := range protocolFeeAmounts {
		previousProtocolFeeAmount := self.GetProtocolFeeAmount(token)
		protocolFeeDelta := gnsmath.SafeSubInt64(protocolFeeAmount, previousProtocolFeeAmount)

		var existingAccumulatedFee *u256.Uint
		if baseAccumulatedFees != nil {
			existingAccumulatedFee = baseAccumulatedFees[token]
		} else {
			existingAccumulatedFee = self.GetAccumulatedProtocolFeeX128PerStake(token)
		}
		previousAccumulatedFees[token] = existingAccumulatedFee

		if protocolFeeDelta <= 0 {
			if existingAccumulatedFee == nil {
				existingAccumulatedFee = u256.NewUint(0)
			}
			accumulatedProtocolFeesX128PerStake[token] = existingAccumulatedFee
			changedProtocolFeeAmounts[token] = protocolFeeAmount
			continue
		}

		protocolFeeDeltaX128 := u256.NewUintFromInt64(protocolFeeDelta)
		protocolFeeDeltaX128 = u256.Zero().Lsh(protocolFeeDeltaX128, 128)

		protocolFeeDeltaX128PerStake := u256.Zero()
		if totalStakedAmount > 0 {
			protocolFeeDeltaX128PerStake = u256.Zero().Div(
				protocolFeeDeltaX128,
				u256.NewUintFromInt64(totalStakedAmount),
			)
		}

		if existingAccumulatedFee == nil {
			existingAccumulatedFee = u256.Zero()
		}
		accumulatedProtocolFeeX128PerStake := u256.Zero().Add(existingAccumulatedFee, protocolFeeDeltaX128PerStake)
		accumulatedProtocolFeesX128PerStake[token] = accumulatedProtocolFeeX128PerStake.Clone()
		changedProtocolFeeAmounts[token] = protocolFeeAmount
	}

	return accumulatedProtocolFeesX128PerStake, changedProtocolFeeAmounts, previousAccumulatedFees, nil
}

func (self *ProtocolFeeRewardManagerResolver) calculateAccumulatedRewardX128PerStake(
	protocolFeeAmounts map[string]int64,
	currentTimestamp int64,
) (map[string]*u256.Uint, map[string]int64, error) {
	accumulated, changed, _, err := self.calculateAccumulatedRewardX128PerStakeWithBase(
		protocolFeeAmounts,
		currentTimestamp,
		nil,
	)
	return accumulated, changed, err
}

// calculateAccumulatedRewardX128PerStakeForToken calculates accumulated reward per stake for exactly one token.
func (self *ProtocolFeeRewardManagerResolver) calculateAccumulatedRewardX128PerStakeForTokenWithPrevious(
	tokenPath string,
	protocolFeeAmount int64,
) (*u256.Uint, int64, *u256.Uint, error) {
	previousProtocolFeeAmount := self.GetProtocolFeeAmount(tokenPath)
	protocolFeeDelta := gnsmath.SafeSubInt64(protocolFeeAmount, previousProtocolFeeAmount)

	existingAccumulatedFee := self.GetAccumulatedProtocolFeeX128PerStake(tokenPath)
	previousAccumulatedFee := existingAccumulatedFee
	if existingAccumulatedFee == nil {
		existingAccumulatedFee = u256.Zero()
	}

	if protocolFeeDelta <= 0 {
		return existingAccumulatedFee.Clone(), protocolFeeAmount, previousAccumulatedFee, nil
	}

	protocolFeeDeltaX128 := u256.NewUintFromInt64(protocolFeeDelta)
	protocolFeeDeltaX128 = u256.Zero().Lsh(protocolFeeDeltaX128, 128)

	protocolFeeDeltaX128PerStake := u256.Zero()
	totalStakedAmount := self.GetTotalStakedAmount()
	if totalStakedAmount > 0 {
		protocolFeeDeltaX128PerStake = u256.Zero().Div(
			protocolFeeDeltaX128,
			u256.NewUintFromInt64(totalStakedAmount),
		)
	}

	accumulatedProtocolFeeX128PerStake := u256.Zero().Add(existingAccumulatedFee, protocolFeeDeltaX128PerStake)
	return accumulatedProtocolFeeX128PerStake.Clone(), protocolFeeAmount, previousAccumulatedFee, nil
}

func (self *ProtocolFeeRewardManagerResolver) calculateAccumulatedRewardX128PerStakeForToken(
	tokenPath string,
	protocolFeeAmount int64,
) (*u256.Uint, int64, error) {
	accumulated, changed, _, err := self.calculateAccumulatedRewardX128PerStakeForTokenWithPrevious(
		tokenPath,
		protocolFeeAmount,
	)
	return accumulated, changed, err
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
	if self.GetAccumulatedTimestamp() > currentTimestamp {
		return nil
	}

	accumulatedProtocolFeeX128PerStake, changedProtocolFeeAmounts, previousAccumulatedFees, err := self.calculateAccumulatedRewardX128PerStakeWithBase(
		protocolFeeAmounts,
		currentTimestamp,
		nil,
	)
	if err != nil {
		return err
	}

	for token, newAcc := range accumulatedProtocolFeeX128PerStake {
		existing := previousAccumulatedFees[token]
		if existing == nil || !existing.Eq(newAcc) {
			self.SetAccumulatedProtocolFeeX128PerStakeForToken(token, newAcc)
		}
	}
	for token, amount := range changedProtocolFeeAmounts {
		if self.GetProtocolFeeAmount(token) != amount {
			self.SetProtocolFeeAmountForToken(token, amount)
		}
	}

	self.SetAccumulatedTimestamp(currentTimestamp)
	return nil
}

func (self *ProtocolFeeRewardManagerResolver) updateAccumulatedProtocolFeeX128PerStakeWithValues(
	protocolFeeAmounts map[string]int64,
	currentTimestamp int64,
) (map[string]*u256.Uint, error) {
	stored := self.GetAllAccumulatedProtocolFeeX128PerStake()
	base := make(map[string]*u256.Uint, len(stored))
	for token, value := range stored {
		base[token] = value
	}
	if self.GetAccumulatedTimestamp() > currentTimestamp {
		return base, nil
	}
	updated, changed, _, err := self.calculateAccumulatedRewardX128PerStakeWithBase(protocolFeeAmounts, currentTimestamp, base)
	if err != nil {
		return nil, err
	}
	for token, value := range updated {
		previous := base[token]
		if previous == nil || !previous.Eq(value) {
			self.SetAccumulatedProtocolFeeX128PerStakeForToken(token, value)
		}
		base[token] = value
	}
	for token, amount := range changed {
		if self.GetProtocolFeeAmount(token) != amount {
			self.SetProtocolFeeAmountForToken(token, amount)
		}
	}
	self.SetAccumulatedTimestamp(currentTimestamp)
	return base, nil
}

// updateAccumulatedProtocolFeeX128PerStakeForToken updates manager accumulators for exactly one token.
func (self *ProtocolFeeRewardManagerResolver) updateAccumulatedProtocolFeeX128PerStakeForTokenWithValue(
	tokenPath string,
	protocolFeeAmount int64,
) (*u256.Uint, error) {
	accumulatedProtocolFeeX128PerStake, changedProtocolFeeAmount, previousAccumulatedFee, err := self.calculateAccumulatedRewardX128PerStakeForTokenWithPrevious(
		tokenPath,
		protocolFeeAmount,
	)
	if err != nil {
		return nil, err
	}

	if previousAccumulatedFee == nil || !previousAccumulatedFee.Eq(accumulatedProtocolFeeX128PerStake) {
		self.SetAccumulatedProtocolFeeX128PerStakeForToken(tokenPath, accumulatedProtocolFeeX128PerStake)
	}
	if self.GetProtocolFeeAmount(tokenPath) != changedProtocolFeeAmount {
		self.SetProtocolFeeAmountForToken(tokenPath, changedProtocolFeeAmount)
	}
	return accumulatedProtocolFeeX128PerStake, nil
}

func (self *ProtocolFeeRewardManagerResolver) updateAccumulatedProtocolFeeX128PerStakeForToken(
	tokenPath string,
	protocolFeeAmount int64,
	currentTimestamp int64,
) error {
	_, err := self.updateAccumulatedProtocolFeeX128PerStakeForTokenWithValue(tokenPath, protocolFeeAmount)
	return err
}

// addStake adds a stake for an address and updates their protocol fee reward state.
func (self *ProtocolFeeRewardManagerResolver) addStake(address string, amount int64, currentTimestamp int64) error {
	return self.addStakeWithAccumulatedRewards(
		address,
		amount,
		currentTimestamp,
		self.GetAllAccumulatedProtocolFeeX128PerStake(),
	)
}

func (self *ProtocolFeeRewardManagerResolver) addStakeWithAccumulatedRewards(
	address string,
	amount int64,
	currentTimestamp int64,
	accumulatedProtocolFeeX128PerStake map[string]*u256.Uint,
) error {
	if amount <= 0 {
		return errors.New(errAmountMustBePositive)
	}

	rewardState, ok, err := self.GetRewardState(address)
	if err != nil {
		return err
	}
	if !ok {
		rewardState = staker.NewProtocolFeeRewardState(accumulatedProtocolFeeX128PerStake)
	}

	resolvedState := NewProtocolFeeRewardStateResolver(rewardState)
	currentTotal := self.GetTotalStakedAmount()
	if currentTotal > math.MaxInt64-amount {
		return errors.New(errTotalStakedAmountOverflow)
	}
	updatedTotalStakedAmount := gnsmath.SafeAddInt64(currentTotal, amount)

	err = resolvedState.addStakeWithUpdateRewardDebtX128(
		amount,
		accumulatedProtocolFeeX128PerStake,
		currentTimestamp,
	)
	if err != nil {
		return err
	}

	self.setRewardState(address, rewardState)
	self.SetTotalStakedAmount(updatedTotalStakedAmount)
	return nil
}

// removeStake removes a stake for an address and updates their protocol fee reward state.
func (self *ProtocolFeeRewardManagerResolver) removeStake(address string, amount int64, currentTimestamp int64) error {
	return self.removeStakeWithAccumulatedRewards(
		address,
		amount,
		currentTimestamp,
		self.GetAllAccumulatedProtocolFeeX128PerStake(),
	)
}

func (self *ProtocolFeeRewardManagerResolver) removeStakeWithAccumulatedRewards(
	address string,
	amount int64,
	currentTimestamp int64,
	accumulatedProtocolFeeX128PerStake map[string]*u256.Uint,
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
		rewardState = staker.NewProtocolFeeRewardState(accumulatedProtocolFeeX128PerStake)
	}

	resolvedState := NewProtocolFeeRewardStateResolver(rewardState)
	err = resolvedState.removeStakeWithUpdateRewardDebtX128(
		amount,
		accumulatedProtocolFeeX128PerStake,
		currentTimestamp,
	)
	if err != nil {
		return err
	}

	self.setRewardState(address, rewardState)
	self.SetTotalStakedAmount(updatedTotalStakedAmount)
	return nil
}

// claimRewards processes protocol fee reward claiming for an address.
func (self *ProtocolFeeRewardManagerResolver) claimRewards(address string, currentTimestamp int64) (map[string]int64, error) {
	return self.claimRewardsWithAccumulatedRewards(
		address,
		currentTimestamp,
		self.GetAllAccumulatedProtocolFeeX128PerStake(),
	)
}

func (self *ProtocolFeeRewardManagerResolver) claimRewardsWithAccumulatedRewards(
	address string,
	currentTimestamp int64,
	accumulatedProtocolFeeX128PerStake map[string]*u256.Uint,
) (map[string]int64, error) {
	rewardState, ok, err := self.GetRewardState(address)
	if err != nil {
		return nil, err
	}
	if !ok {
		return make(map[string]int64), nil
	}

	resolvedState := NewProtocolFeeRewardStateResolver(rewardState)
	claimedRewards, err := resolvedState.claimRewardsWithUpdateRewardDebtX128(
		accumulatedProtocolFeeX128PerStake,
		currentTimestamp,
	)
	if err != nil {
		return nil, err
	}

	self.setRewardState(address, rewardState)
	return claimedRewards, nil
}

// claimRewardForToken processes protocol fee reward claiming for exactly one token.
func (self *ProtocolFeeRewardManagerResolver) claimRewardForToken(
	address string,
	tokenPath string,
	currentTimestamp int64,
) (int64, error) {
	return self.claimRewardForTokenWithAccumulatedReward(
		address,
		tokenPath,
		currentTimestamp,
		self.GetAccumulatedProtocolFeeX128PerStake(tokenPath),
	)
}

func (self *ProtocolFeeRewardManagerResolver) claimRewardForTokenWithAccumulatedReward(
	address string,
	tokenPath string,
	currentTimestamp int64,
	accumulatedProtocolFeeX128PerStake *u256.Uint,
) (int64, error) {
	rewardState, ok, err := self.GetRewardState(address)
	if err != nil {
		return 0, err
	}
	if !ok {
		return 0, nil
	}

	resolvedState := NewProtocolFeeRewardStateResolver(rewardState)
	claimedReward, err := resolvedState.claimRewardForTokenWithUpdateRewardDebtX128(
		tokenPath,
		accumulatedProtocolFeeX128PerStake,
		currentTimestamp,
	)
	if err != nil {
		return 0, err
	}

	self.setRewardState(address, rewardState)
	return claimedReward, nil
}

func (self *ProtocolFeeRewardManagerResolver) setRewardState(address string, rewardState *staker.ProtocolFeeRewardState) {
	self.SetRewardState(address, rewardState)
}
