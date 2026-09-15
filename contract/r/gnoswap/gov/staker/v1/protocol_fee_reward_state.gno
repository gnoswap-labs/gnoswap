package staker

import (
	"errors"

	"gno.land/p/gnoswap/consts/v1"
	"gno.land/p/gnoswap/gnsmath/v1"
	u256 "gno.land/p/gnoswap/uint256/v1"

	"gno.land/r/gnoswap/gov/staker"
)

// ProtocolFeeRewardStateResolver settles one staker's protocol fee rewards.
//
// A staker's reward for a token is the sum, over the segments between their stake
// events, of the stake held during the segment times the growth of the token's
// accumulated fee per stake across it. Segments are folded in event order, so the work
// of settling a token is proportional to the staker's own stake changes since the token
// was last settled, never to the number of tokens.
type ProtocolFeeRewardStateResolver struct {
	*staker.ProtocolFeeRewardState
}

// NewProtocolFeeRewardStateResolver wraps one staker's protocol fee reward state
// with settlement operations.
//
// Parameters:
//   - protocolFeeRewardState: staker reward state to resolve and mutate.
//
// Returns:
//   - *ProtocolFeeRewardStateResolver: resolver backed by protocolFeeRewardState.
func NewProtocolFeeRewardStateResolver(protocolFeeRewardState *staker.ProtocolFeeRewardState) *ProtocolFeeRewardStateResolver {
	return &ProtocolFeeRewardStateResolver{
		ProtocolFeeRewardState: protocolFeeRewardState,
	}
}

// protocolFeeAccumulatorView reads a token accumulator as it stands, optionally
// extended in memory with buckets that are still pending on the protocol fee realm.
// The extension lets a query report what a collect would pay without folding anything.
type protocolFeeAccumulatorView struct {
	accumulator *staker.ProtocolFeeTokenAccumulator // nil when the token was never folded
	// extraEpochs and extraValues hold projected history entries, in ascending epoch order
	extraEpochs []int64
	extraValues []*u256.Uint
	// current is the latest accumulated value, projection included
	current *u256.Uint
	// firstEpoch is the first epoch a fee was folded for, projection included, or -1
	firstEpoch int64
	// foldedEpoch is the last epoch whose fees are known to be fully folded, or -1
	foldedEpoch int64
	// currentEpoch is the accrual epoch in force on the manager
	currentEpoch int64
}

// at returns the accumulated value after the fees of the latest known epoch at or
// before epoch.
func (v *protocolFeeAccumulatorView) at(epoch int64) *u256.Uint {
	for i := len(v.extraEpochs) - 1; i >= 0; i-- {
		if v.extraEpochs[i] <= epoch {
			return v.extraValues[i]
		}
	}

	if v.accumulator == nil {
		return u256.Zero()
	}

	return v.accumulator.GetAccumulatedX128PerStakeAt(epoch)
}

// protocolFeeTokenSettlement is the in-memory working copy of a token's settlement
// state. It is written back only on a collect, so queries never touch storage.
type protocolFeeTokenSettlement struct {
	eventCursor         int64
	segmentStakedAmount int64
	segmentStartX128    *u256.Uint
	earnedX128          *u256.Uint
}

// loadTokenSettlement returns the settlement state of tokenPath, initialising it when
// the token was never settled for this staker.
//
// A fresh state skips every stake event at or before the accumulator's first epoch:
// the accumulator was zero throughout, so those segments earned nothing and the open
// segment can start at the last of them. When no fee was folded at all, the skip
// covers every event, but only once every closed epoch is known to be folded: a
// bucket still pending from a closed epoch could later credit one of those events,
// so until then they are settled one by one through settleEvents, which is gated by
// foldedEpoch and yields nothing while the accumulator stays at zero.
func (p *ProtocolFeeRewardStateResolver) loadTokenSettlement(tokenPath string, view *protocolFeeAccumulatorView) *protocolFeeTokenSettlement {
	if tokenState, ok := p.GetTokenState(tokenPath); ok {
		return &protocolFeeTokenSettlement{
			eventCursor:         tokenState.GetEventCursor(),
			segmentStakedAmount: tokenState.GetSegmentStakedAmount(),
			segmentStartX128:    tokenState.GetSegmentStartX128().Clone(),
			earnedX128:          tokenState.GetEarnedX128().Clone(),
		}
	}

	settlement := &protocolFeeTokenSettlement{
		eventCursor:         0,
		segmentStakedAmount: 0,
		segmentStartX128:    u256.Zero(),
		earnedX128:          u256.Zero(),
	}

	eventCount := p.GetStakeEventCount()
	if view.firstEpoch < 0 {
		if view.foldedEpoch >= view.currentEpoch-1 {
			// No fee was ever folded and nothing from a closed epoch is pending, so
			// every recorded event earned nothing.
			settlement.eventCursor = eventCount
			settlement.segmentStakedAmount = p.GetStakedAmount()
		}
		return settlement
	}

	// Stake events are appended in epoch order, so the last event at or before
	// firstEpoch is found by binary search: the lookup costs O(log n) reads no matter
	// how many stake changes the staker made since the token's first fee.
	lo, hi := int64(0), eventCount
	for lo < hi {
		mid := lo + (hi-lo)/2
		event, ok := p.GetStakeEvent(mid)
		if !ok {
			break
		}
		if event.GetEpoch() <= view.firstEpoch {
			lo = mid + 1
		} else {
			hi = mid
		}
	}

	if lo > 0 {
		if event, ok := p.GetStakeEvent(lo - 1); ok {
			settlement.eventCursor = lo
			settlement.segmentStakedAmount = event.GetStakedAmount()
		}
	}

	return settlement
}

// settleEvents folds up to maxEvents pending stake events into the settlement. An
// event can only be folded once the epoch before it is fully folded on the
// accumulator, because the segment it closes ends at that epoch's value. A maxEvents
// of zero or less folds every event it can. Returns true when no event is left pending.
func (p *ProtocolFeeRewardStateResolver) settleEvents(settlement *protocolFeeTokenSettlement, view *protocolFeeAccumulatorView, maxEvents int64) bool {
	eventCount := p.GetStakeEventCount()
	processed := int64(0)

	for settlement.eventCursor < eventCount {
		if maxEvents > 0 && processed >= maxEvents {
			return false
		}

		event, ok := p.GetStakeEvent(settlement.eventCursor)
		if !ok {
			return false
		}
		if event.GetEpoch()-1 > view.foldedEpoch {
			return false
		}

		segmentEndX128 := view.at(event.GetEpoch() - 1)
		settlement.earnedX128 = u256.Zero().Add(
			settlement.earnedX128,
			segmentRewardX128(settlement.segmentStakedAmount, settlement.segmentStartX128, segmentEndX128),
		)
		settlement.segmentStartX128 = segmentEndX128.Clone()
		settlement.segmentStakedAmount = event.GetStakedAmount()
		settlement.eventCursor++
		processed++
	}

	return true
}

// closeOpenSegment folds the open segment up to the accumulator's latest value. It may
// only be called once every stake event is settled, so that the open segment really
// ends at the present.
func closeOpenSegment(settlement *protocolFeeTokenSettlement, view *protocolFeeAccumulatorView) {
	settlement.earnedX128 = u256.Zero().Add(
		settlement.earnedX128,
		segmentRewardX128(settlement.segmentStakedAmount, settlement.segmentStartX128, view.current),
	)
	settlement.segmentStartX128 = view.current.Clone()
}

// takeReward removes the whole-unit part of the earned reward from the settlement and
// returns it. The sub-unit remainder stays earned so that no fee share is lost.
func takeReward(settlement *protocolFeeTokenSettlement) int64 {
	rewardX128 := u256.Zero().Rsh(settlement.earnedX128, 128)
	reward := gnsmath.SafeConvertToInt64(rewardX128)
	settlement.earnedX128 = u256.Zero().Sub(settlement.earnedX128, u256.Zero().Lsh(rewardX128, 128))

	return reward
}

// segmentRewardX128 returns stakedAmount times the accumulator growth across a segment.
func segmentRewardX128(stakedAmount int64, startX128, endX128 *u256.Uint) *u256.Uint {
	if stakedAmount <= 0 || !endX128.Gt(startX128) {
		return u256.Zero()
	}

	growthX128 := u256.Zero().Sub(endX128, startX128)

	return u256.Zero().Mul(growthX128, u256.NewUintFromInt64(stakedAmount))
}

// storeTokenSettlement writes the settlement back to the staker's state.
func (p *ProtocolFeeRewardStateResolver) storeTokenSettlement(tokenPath string, settlement *protocolFeeTokenSettlement) {
	tokenState, ok := p.GetTokenState(tokenPath)
	if !ok {
		tokenState = staker.NewProtocolFeeTokenRewardState(settlement.eventCursor, settlement.segmentStakedAmount, settlement.segmentStartX128)
		tokenState.SetEarnedX128(settlement.earnedX128)
		p.SetTokenState(tokenPath, tokenState)
		return
	}

	tokenState.SetSegment(settlement.eventCursor, settlement.segmentStakedAmount, settlement.segmentStartX128)
	tokenState.SetEarnedX128(settlement.earnedX128)
}

// claimTokenReward settles tokenPath and returns the reward collected.
//
// Up to maxEvents stake events are folded; whatever is settled by then is paid, and
// the rest stays pending for a later collect. A maxEvents of zero or less folds
// everything.
func (p *ProtocolFeeRewardStateResolver) claimTokenReward(tokenPath string, view *protocolFeeAccumulatorView, maxEvents int64) (int64, error) {
	// A token that never collected a fee has nothing to settle; skipping it keeps the
	// staker's state free of an entry per token merely queried.
	if _, ok := p.GetTokenState(tokenPath); !ok && view.firstEpoch < 0 {
		return 0, nil
	}

	settlement := p.loadTokenSettlement(tokenPath, view)

	if p.settleEvents(settlement, view, maxEvents) {
		closeOpenSegment(settlement, view)
	}

	reward := takeReward(settlement)
	p.storeTokenSettlement(tokenPath, settlement)

	if reward > 0 {
		if tokenState, ok := p.GetTokenState(tokenPath); ok {
			tokenState.SetClaimedReward(gnsmath.SafeAddInt64(tokenState.GetClaimedReward(), reward))
		}
	}

	return reward, nil
}

// getClaimableReward returns what a collect of tokenPath would pay right now, without
// changing any state.
func (p *ProtocolFeeRewardStateResolver) getClaimableReward(tokenPath string, view *protocolFeeAccumulatorView) int64 {
	settlement := p.loadTokenSettlement(tokenPath, view)

	if p.settleEvents(settlement, view, 0) {
		closeOpenSegment(settlement, view)
	}

	return gnsmath.SafeConvertToInt64(u256.Zero().Div(settlement.earnedX128, consts.Q128()))
}

// addStake increases the staked amount and records the change from epoch on.
func (p *ProtocolFeeRewardStateResolver) addStake(amount int64, epoch int64) error {
	if amount <= 0 {
		return errors.New(errAmountMustBePositive)
	}

	stakedAmount := gnsmath.SafeAddInt64(p.GetStakedAmount(), amount)
	p.SetStakedAmount(stakedAmount)
	p.AppendStakeEvent(epoch, stakedAmount)

	return nil
}

// removeStake decreases the staked amount and records the change from epoch on.
func (p *ProtocolFeeRewardStateResolver) removeStake(amount int64, epoch int64) error {
	if amount < 0 {
		return errors.New(errAmountMustBeNonNegative)
	}
	if amount > p.GetStakedAmount() {
		return errors.New(errRemoveAmountExceedsStaked)
	}

	stakedAmount := gnsmath.SafeSubInt64(p.GetStakedAmount(), amount)
	p.SetStakedAmount(stakedAmount)
	p.AppendStakeEvent(epoch, stakedAmount)

	return nil
}

// IsClaimable reports whether every token may be collected at once at currentTimestamp.
//
// Parameters:
//   - currentTimestamp: current Unix timestamp used to compare the last collection.
//
// Returns:
//   - bool: true when currentTimestamp is later than the state's claimed timestamp.
func (p *ProtocolFeeRewardStateResolver) IsClaimable(currentTimestamp int64) bool {
	return p.GetClaimedTimestamp() < currentTimestamp
}
