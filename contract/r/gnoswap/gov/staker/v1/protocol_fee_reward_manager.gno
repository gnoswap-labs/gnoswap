package staker

import (
	"errors"
	"math"

	"gno.land/p/gnoswap/gnsmath"
	u256 "gno.land/p/gnoswap/uint256"

	"gno.land/r/gnoswap/gov/staker"
)

// ProtocolFeeRewardManagerResolver drives the ProtocolFeeRewardManager.
//
// Stake changes only move the epoch, the total stake history and the staker's own
// event list. Fees are folded into a token's accumulator when that token is collected,
// each accrual bucket against the total stake in force during its epoch.
type ProtocolFeeRewardManagerResolver struct {
	*staker.ProtocolFeeRewardManager
}

func NewProtocolFeeRewardManagerResolver(manager *staker.ProtocolFeeRewardManager) *ProtocolFeeRewardManagerResolver {
	return &ProtocolFeeRewardManagerResolver{
		ProtocolFeeRewardManager: manager,
	}
}

// addStake records that rewardID staked amount more from epoch on.
//
// epoch is the accrual epoch protocol_fee just opened for this change, so it must not
// be older than the epoch in force.
func (self *ProtocolFeeRewardManagerResolver) addStake(rewardID string, amount int64, epoch int64) error {
	if amount <= 0 {
		return errors.New(errAmountMustBePositive)
	}
	if epoch < self.GetCurrentEpoch() {
		return errors.New(errInvalidAccrualEpoch)
	}

	currentTotal := self.GetTotalStakedAmount()
	if currentTotal > math.MaxInt64-amount {
		return errors.New(errTotalStakedAmountOverflow)
	}

	rewardState, ok, err := self.GetRewardState(rewardID)
	if err != nil {
		return err
	}
	if !ok {
		rewardState = staker.NewProtocolFeeRewardState()
	}

	resolvedState := NewProtocolFeeRewardStateResolver(rewardState)
	if err := resolvedState.addStake(amount, epoch); err != nil {
		return err
	}

	self.recordTotalStakedAmount(epoch, gnsmath.SafeAddInt64(currentTotal, amount))
	self.SetRewardState(rewardID, rewardState)

	return nil
}

// removeStake records that rewardID staked amount less from epoch on.
func (self *ProtocolFeeRewardManagerResolver) removeStake(rewardID string, amount int64, epoch int64) error {
	if amount < 0 {
		return errors.New(errAmountMustBeNonNegative)
	}
	if epoch < self.GetCurrentEpoch() {
		return errors.New(errInvalidAccrualEpoch)
	}

	updatedTotal := gnsmath.SafeSubInt64(self.GetTotalStakedAmount(), amount)
	if updatedTotal < 0 {
		return errors.New(errRemoveAmountExceedsTotalStaked)
	}

	rewardState, ok, err := self.GetRewardState(rewardID)
	if err != nil {
		return err
	}
	if !ok {
		rewardState = staker.NewProtocolFeeRewardState()
	}

	resolvedState := NewProtocolFeeRewardStateResolver(rewardState)
	if err := resolvedState.removeStake(amount, epoch); err != nil {
		return err
	}

	self.recordTotalStakedAmount(epoch, updatedTotal)
	self.SetRewardState(rewardID, rewardState)

	return nil
}

func (self *ProtocolFeeRewardManagerResolver) recordTotalStakedAmount(epoch int64, totalStakedAmount int64) {
	self.SetCurrentEpoch(epoch)
	self.SetTotalStakedAmount(totalStakedAmount)
	self.SetTotalStakedAmountAt(epoch, totalStakedAmount)
}

// applyAccrualBuckets folds consumed accrual buckets of tokenPath into its accumulator.
//
// epochs and amounts are parallel and in ascending epoch order. Each amount is divided
// by the total stake in force during its epoch; with nothing staked the amount is
// dropped, the same policy the emission accumulator applies. exhausted reports that
// no bucket is left pending, which lets the accumulator mark every closed epoch as
// fully folded.
func (self *ProtocolFeeRewardManagerResolver) applyAccrualBuckets(
	tokenPath string,
	epochs []int64,
	amounts []int64,
	exhausted bool,
	currentTimestamp int64,
) error {
	if len(epochs) != len(amounts) {
		return errors.New(errInvalidAccrualBuckets)
	}

	accumulator, ok := self.GetTokenAccumulator(tokenPath)
	if !ok {
		if len(epochs) == 0 {
			return nil
		}
		accumulator = staker.NewProtocolFeeTokenAccumulator()
		self.SetTokenAccumulator(tokenPath, accumulator)
	}

	currentX128 := accumulator.GetAccumulatedX128PerStake().Clone()
	feeAmount := accumulator.GetProtocolFeeAmount()
	lastEpoch := int64(-1)

	for i, epoch := range epochs {
		if epoch < lastEpoch || epoch > self.GetCurrentEpoch() {
			return errors.New(errInvalidAccrualBuckets)
		}
		lastEpoch = epoch

		amount := amounts[i]
		if amount < 0 {
			return errors.New(errInvalidAccrualBuckets)
		}
		feeAmount = gnsmath.SafeAddInt64(feeAmount, amount)

		totalStakedAmount := self.GetTotalStakedAmountAt(epoch)
		if totalStakedAmount <= 0 || amount == 0 {
			continue
		}

		// Scale the amount by 2^128 before dividing by the total stake. The amount
		// fits in 63 bits, so the product fits in 191 bits and cannot overflow.
		amountX128 := u256.Zero().Lsh(u256.NewUintFromInt64(amount), 128)
		perStakeX128 := u256.Zero().Div(amountX128, u256.NewUintFromInt64(totalStakedAmount))
		currentX128 = u256.Zero().Add(currentX128, perStakeX128)

		accumulator.SetAccumulatedX128PerStakeAt(epoch, currentX128)
	}

	accumulator.SetProtocolFeeAmount(feeAmount)

	// Every epoch before the one in force is closed, so it is fully folded once no bucket
	// is left. Otherwise only the epochs up to the last consumed bucket are complete.
	foldedEpoch := accumulator.GetFoldedEpoch()
	if exhausted {
		foldedEpoch = maxInt64(foldedEpoch, self.GetCurrentEpoch()-1)
	} else if lastEpoch >= 0 {
		foldedEpoch = maxInt64(foldedEpoch, minInt64(lastEpoch, self.GetCurrentEpoch()-1))
	}
	accumulator.SetFoldedEpoch(foldedEpoch)

	self.SetAccumulatedTimestamp(currentTimestamp)

	return nil
}

// accumulatorView returns a read view of tokenPath's accumulator. When pending buckets
// are given they are projected on top, as applyAccrualBuckets would fold them, so a
// query reports what a collect would pay.
func (self *ProtocolFeeRewardManagerResolver) accumulatorView(tokenPath string, pendingEpochs []int64, pendingAmounts []int64) *protocolFeeAccumulatorView {
	view := &protocolFeeAccumulatorView{
		extraEpochs: []int64{},
		extraValues: []*u256.Uint{},
		current:     u256.Zero(),
		firstEpoch:  -1,
		foldedEpoch: -1,
	}

	if accumulator, ok := self.GetTokenAccumulator(tokenPath); ok {
		view.accumulator = accumulator
		view.current = accumulator.GetAccumulatedX128PerStake().Clone()
		view.firstEpoch = accumulator.GetFirstEpoch()
		view.foldedEpoch = accumulator.GetFoldedEpoch()
	}

	if len(pendingEpochs) == 0 {
		return view
	}

	for i, epoch := range pendingEpochs {
		totalStakedAmount := self.GetTotalStakedAmountAt(epoch)
		if totalStakedAmount <= 0 || pendingAmounts[i] <= 0 {
			continue
		}

		amountX128 := u256.Zero().Lsh(u256.NewUintFromInt64(pendingAmounts[i]), 128)
		perStakeX128 := u256.Zero().Div(amountX128, u256.NewUintFromInt64(totalStakedAmount))
		view.current = u256.Zero().Add(view.current, perStakeX128)
		view.extraEpochs = append(view.extraEpochs, epoch)
		view.extraValues = append(view.extraValues, view.current.Clone())
		if view.firstEpoch < 0 {
			view.firstEpoch = epoch
		}
	}

	// Projecting every pending bucket folds all closed epochs.
	view.foldedEpoch = maxInt64(view.foldedEpoch, self.GetCurrentEpoch()-1)

	return view
}

// claimTokenReward settles tokenPath for rewardID and returns the reward collected.
// See ProtocolFeeRewardStateResolver.claimTokenReward for the maxEvents bound.
func (self *ProtocolFeeRewardManagerResolver) claimTokenReward(rewardID string, tokenPath string, maxEvents int64) (int64, error) {
	rewardState, ok, err := self.GetRewardState(rewardID)
	if err != nil {
		return 0, err
	}
	if !ok {
		return 0, nil
	}

	resolvedState := NewProtocolFeeRewardStateResolver(rewardState)
	reward, err := resolvedState.claimTokenReward(tokenPath, self.accumulatorView(tokenPath, nil, nil), maxEvents)
	if err != nil {
		return 0, err
	}

	self.SetRewardState(rewardID, rewardState)

	return reward, nil
}

// claimRewards settles every folded token for rewardID and returns the reward
// collected per token. Its cost grows with the number of tokens that ever collected a
// fee; claimTokenReward is the bounded alternative.
func (self *ProtocolFeeRewardManagerResolver) claimRewards(rewardID string, currentTimestamp int64) (map[string]int64, error) {
	rewards := make(map[string]int64)

	rewardState, ok, err := self.GetRewardState(rewardID)
	if err != nil {
		return nil, err
	}
	if !ok {
		return rewards, nil
	}

	resolvedState := NewProtocolFeeRewardStateResolver(rewardState)
	if !resolvedState.IsClaimable(currentTimestamp) {
		return rewards, nil
	}

	for _, tokenPath := range self.GetTokenPaths() {
		reward, err := resolvedState.claimTokenReward(tokenPath, self.accumulatorView(tokenPath, nil, nil), 0)
		if err != nil {
			return nil, err
		}
		rewards[tokenPath] = reward
	}

	resolvedState.SetClaimedTimestamp(currentTimestamp)
	self.SetRewardState(rewardID, rewardState)

	return rewards, nil
}

// GetClaimableRewardAmount returns what collecting tokenPath for rewardID would pay,
// with the given pending buckets projected on top of the accumulator.
func (self *ProtocolFeeRewardManagerResolver) GetClaimableRewardAmount(rewardID string, tokenPath string, pendingEpochs []int64, pendingAmounts []int64) (int64, error) {
	rewardState, ok, err := self.GetRewardState(rewardID)
	if err != nil {
		return 0, err
	}
	if !ok {
		return 0, nil
	}

	resolvedState := NewProtocolFeeRewardStateResolver(rewardState)

	return resolvedState.getClaimableReward(tokenPath, self.accumulatorView(tokenPath, pendingEpochs, pendingAmounts)), nil
}

func maxInt64(a, b int64) int64 {
	if a > b {
		return a
	}
	return b
}

func minInt64(a, b int64) int64 {
	if a < b {
		return a
	}
	return b
}
