package staker

import (
	bptree "gno.land/p/nt/bptree/v0"
	ufmt "gno.land/p/nt/ufmt/v0"

	u256 "gno.land/p/gnoswap/uint256"
)

// ProtocolFeeRewardState tracks the protocol fee rewards of one staker.
//
// Ordinary stake changes append one ProtocolFeeStakeEvent; Redelegate performs
// a remove plus an add and appends two events. Each token is settled on its own
// from those events, so the state keeps a per-token cursor into the event
// history rather than a reward debt for every token at once.
type ProtocolFeeRewardState struct {
	// stakedAmount is the current amount staked
	stakedAmount int64
	// stakeEvents records the staked amount in force from each stake change, by index
	stakeEvents *UintTree // index -> *ProtocolFeeStakeEvent
	// stakeEventCount is the number of recorded stake events
	stakeEventCount int64
	// tokenStates maps a token path to the settlement state of that token
	tokenStates *bptree.BPTree // tokenPath -> *ProtocolFeeTokenRewardState
	// claimedTimestamp is the last timestamp at which every token was collected
	claimedTimestamp int64
}

// ProtocolFeeStakeEvent is one stake change: from epoch on, stakedAmount was staked.
type ProtocolFeeStakeEvent struct {
	epoch        int64
	stakedAmount int64
}

// GetEpoch returns the accrual epoch from which this stake event applies.
//
// Returns:
//   - int64: epoch at which the stake amount became effective
func (e *ProtocolFeeStakeEvent) GetEpoch() int64 { return e.epoch }

// GetStakedAmount returns the stake amount in force for this event.
//
// Returns:
//   - int64: staked amount associated with the event
func (e *ProtocolFeeStakeEvent) GetStakedAmount() int64 { return e.stakedAmount }

// ProtocolFeeTokenRewardState is the settlement state of one token for one staker.
//
// Stake events up to eventCursor are folded into earnedX128. The open segment starts
// where the last folded event left the accumulator (segmentStartX128) with
// segmentStakedAmount staked.
type ProtocolFeeTokenRewardState struct {
	// eventCursor is the number of stake events already folded in
	eventCursor int64
	// segmentStakedAmount is the amount staked during the open segment
	segmentStakedAmount int64
	// segmentStartX128 is the accumulated fee per stake at the start of the open segment
	segmentStartX128 *u256.Uint
	// earnedX128 is the reward earned by closed segments and not yet collected, scaled by 2^128
	earnedX128 *u256.Uint
	// claimedReward is the total reward collected so far
	claimedReward int64
}

// NewProtocolFeeRewardState creates an empty state for a staker with no stake.
//
// Returns:
//   - *ProtocolFeeRewardState: initialized reward state with empty event and token trees
func NewProtocolFeeRewardState() *ProtocolFeeRewardState {
	return &ProtocolFeeRewardState{
		stakedAmount:     0,
		stakeEvents:      NewUintTree(),
		stakeEventCount:  0,
		tokenStates:      bptree.NewBPTreeN(16),
		claimedTimestamp: 0,
	}
}

// NewProtocolFeeTokenRewardState creates the settlement state of a token whose open
// segment starts at the given cursor, stake and accumulator value.
//
// Parameters:
//   - eventCursor: number of stake events already folded into this token state
//   - segmentStakedAmount: stake amount in force during the open segment
//   - segmentStartX128: accumulated fee-per-stake value at the open segment start, scaled by 2^128
//
// Returns:
//   - *ProtocolFeeTokenRewardState: token settlement state with zero closed-segment earnings and claimed reward
func NewProtocolFeeTokenRewardState(eventCursor int64, segmentStakedAmount int64, segmentStartX128 *u256.Uint) *ProtocolFeeTokenRewardState {
	return &ProtocolFeeTokenRewardState{
		eventCursor:         eventCursor,
		segmentStakedAmount: segmentStakedAmount,
		segmentStartX128:    u256.Zero().Set(segmentStartX128),
		earnedX128:          u256.Zero(),
		claimedReward:       0,
	}
}

/* ProtocolFeeRewardState getters */

// GetStakedAmount returns the current stake amount tracked for the staker.
//
// Returns:
//   - int64: current staked amount
func (p *ProtocolFeeRewardState) GetStakedAmount() int64 {
	return p.stakedAmount
}

// GetStakeEventCount returns the number of stake-change events recorded.
//
// Returns:
//   - int64: count of indexed stake events
func (p *ProtocolFeeRewardState) GetStakeEventCount() int64 {
	return p.stakeEventCount
}

// GetStakeEvent returns the indexed stake event.
//
// Parameters:
//   - index: zero-based stake-event index
//
// Returns:
//   - *ProtocolFeeStakeEvent: event at index, or nil when no event is stored there
//   - bool: true when an event exists at index; false when the index is absent
func (p *ProtocolFeeRewardState) GetStakeEvent(index int64) (*ProtocolFeeStakeEvent, bool) {
	ei, ok := p.stakeEvents.Get(index)
	if !ok {
		return nil, false
	}
	event, castOk := ei.(*ProtocolFeeStakeEvent)
	if !castOk {
		panic(ufmt.Sprintf("failed to cast stake event: %T", ei))
	}
	return event, true
}

// GetTokenState returns the settlement state of tokenPath, or false when the token was
// never settled for this staker.
//
// Parameters:
//   - tokenPath: registered token path whose per-staker settlement state is requested
//
// Returns:
//   - *ProtocolFeeTokenRewardState: token settlement state, or nil when it has not been initialized
//   - bool: true when tokenPath has a stored settlement state, otherwise false
func (p *ProtocolFeeRewardState) GetTokenState(tokenPath string) (*ProtocolFeeTokenRewardState, bool) {
	ti := p.tokenStates.Get(tokenPath)
	if ti == nil {
		return nil, false
	}
	tokenState, castOk := ti.(*ProtocolFeeTokenRewardState)
	if !castOk {
		panic(ufmt.Sprintf("failed to cast token reward state: %T", ti))
	}
	return tokenState, true
}

// GetTokenPaths returns every token path settled for this staker, in key order.
//
// Returns:
//   - []string: token paths with stored settlement state, ordered by the underlying tree keys
func (p *ProtocolFeeRewardState) GetTokenPaths() []string {
	tokenPaths := make([]string, 0, p.tokenStates.Size())
	p.tokenStates.Iterate("", "", func(key string, _ any) bool {
		tokenPaths = append(tokenPaths, key)
		return false
	})
	return tokenPaths
}

// GetClaimedReward returns the total reward of tokenPath collected so far.
//
// Parameters:
//   - tokenPath: token path whose accumulated claimed reward is requested
//
// Returns:
//   - int64: total reward collected for tokenPath, or zero when no token state exists
func (p *ProtocolFeeRewardState) GetClaimedReward(tokenPath string) int64 {
	tokenState, ok := p.GetTokenState(tokenPath)
	if !ok {
		return 0
	}
	return tokenState.GetClaimedReward()
}

// GetClaimedTimestamp returns the last timestamp at which all token rewards were collected.
//
// Returns:
//   - int64: Unix timestamp recorded for the most recent all-token collection
func (p *ProtocolFeeRewardState) GetClaimedTimestamp() int64 {
	return p.claimedTimestamp
}

/* ProtocolFeeRewardState setters */

// SetStakedAmount updates the current stake amount tracked for the staker.
//
// Parameters:
//   - stakedAmount: new current staked amount
func (p *ProtocolFeeRewardState) SetStakedAmount(stakedAmount int64) {
	p.stakedAmount = stakedAmount
}

// AppendStakeEvent records that stakedAmount is staked from epoch on.
//
// Parameters:
//   - epoch: accrual epoch at which this stake amount becomes effective
//   - stakedAmount: stake amount in force from epoch onward
func (p *ProtocolFeeRewardState) AppendStakeEvent(epoch int64, stakedAmount int64) {
	p.stakeEvents.Set(p.stakeEventCount, &ProtocolFeeStakeEvent{
		epoch:        epoch,
		stakedAmount: stakedAmount,
	})
	p.stakeEventCount++
}

// SetTokenState stores the settlement state for a token path.
//
// Parameters:
//   - tokenPath: token path used as the settlement-state key
//   - tokenState: per-token settlement state to store
func (p *ProtocolFeeRewardState) SetTokenState(tokenPath string, tokenState *ProtocolFeeTokenRewardState) {
	p.tokenStates.Set(tokenPath, tokenState)
}

// SetClaimedTimestamp records the timestamp at which all token rewards were collected.
//
// Parameters:
//   - claimedTimestamp: Unix timestamp of the all-token collection
func (p *ProtocolFeeRewardState) SetClaimedTimestamp(claimedTimestamp int64) {
	p.claimedTimestamp = claimedTimestamp
}

/* ProtocolFeeTokenRewardState getters and setters */

// GetEventCursor returns the number of stake events already folded for this token.
//
// Returns:
//   - int64: count of folded stake events
func (t *ProtocolFeeTokenRewardState) GetEventCursor() int64 {
	return t.eventCursor
}

// GetSegmentStakedAmount returns the stake amount in the open segment.
//
// Returns:
//   - int64: stake amount used while settling the open segment
func (t *ProtocolFeeTokenRewardState) GetSegmentStakedAmount() int64 {
	return t.segmentStakedAmount
}

// GetSegmentStartX128 returns the accumulator value at the open segment start.
//
// Returns:
//   - *u256.Uint: fee-per-stake accumulator at segment start, scaled by 2^128
func (t *ProtocolFeeTokenRewardState) GetSegmentStartX128() *u256.Uint {
	return t.segmentStartX128
}

// GetEarnedX128 returns closed-segment earnings awaiting collection.
//
// Returns:
//   - *u256.Uint: unclaimed reward accumulator scaled by 2^128
func (t *ProtocolFeeTokenRewardState) GetEarnedX128() *u256.Uint {
	return t.earnedX128
}

// GetClaimedReward returns the total reward collected for this token state.
//
// Returns:
//   - int64: cumulative collected reward amount
func (t *ProtocolFeeTokenRewardState) GetClaimedReward() int64 {
	return t.claimedReward
}

// SetSegment moves the open segment: events up to eventCursor are folded, and the
// segment starts at segmentStartX128 with segmentStakedAmount staked.
//
// Parameters:
//   - eventCursor: number of stake events folded into the new segment
//   - segmentStakedAmount: stake amount in force for the new open segment
//   - segmentStartX128: fee-per-stake accumulator at the new segment start, scaled by 2^128
func (t *ProtocolFeeTokenRewardState) SetSegment(eventCursor int64, segmentStakedAmount int64, segmentStartX128 *u256.Uint) {
	t.eventCursor = eventCursor
	t.segmentStakedAmount = segmentStakedAmount
	t.segmentStartX128 = u256.Zero().Set(segmentStartX128)
}

// SetEarnedX128 replaces the closed-segment earnings accumulator.
//
// Parameters:
//   - earnedX128: unclaimed earnings accumulator scaled by 2^128
func (t *ProtocolFeeTokenRewardState) SetEarnedX128(earnedX128 *u256.Uint) {
	t.earnedX128 = u256.Zero().Set(earnedX128)
}

// SetClaimedReward replaces the cumulative collected reward amount.
//
// Parameters:
//   - claimedReward: total reward collected for this token state
func (t *ProtocolFeeTokenRewardState) SetClaimedReward(claimedReward int64) {
	t.claimedReward = claimedReward
}
