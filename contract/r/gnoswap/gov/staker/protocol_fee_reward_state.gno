package staker

import (
	bptree "gno.land/p/nt/bptree/v0"
	ufmt "gno.land/p/nt/ufmt/v0"

	u256 "gno.land/p/gnoswap/uint256"
)

// ProtocolFeeRewardState tracks the protocol fee rewards of one staker.
//
// A stake change appends one ProtocolFeeStakeEvent and nothing else. Each token is
// settled on its own from those events, so the state keeps a per-token cursor into
// the event history rather than a reward debt for every token at once.
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

func (e *ProtocolFeeStakeEvent) GetEpoch() int64        { return e.epoch }
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

func (p *ProtocolFeeRewardState) GetStakedAmount() int64 {
	return p.stakedAmount
}

func (p *ProtocolFeeRewardState) GetStakeEventCount() int64 {
	return p.stakeEventCount
}

// GetStakeEvent returns the index-th stake event.
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
func (p *ProtocolFeeRewardState) GetTokenPaths() []string {
	tokenPaths := make([]string, 0, p.tokenStates.Size())
	p.tokenStates.Iterate("", "", func(key string, _ any) bool {
		tokenPaths = append(tokenPaths, key)
		return false
	})
	return tokenPaths
}

// GetClaimedReward returns the total reward of tokenPath collected so far.
func (p *ProtocolFeeRewardState) GetClaimedReward(tokenPath string) int64 {
	tokenState, ok := p.GetTokenState(tokenPath)
	if !ok {
		return 0
	}
	return tokenState.GetClaimedReward()
}

func (p *ProtocolFeeRewardState) GetClaimedTimestamp() int64 {
	return p.claimedTimestamp
}

/* ProtocolFeeRewardState setters */

func (p *ProtocolFeeRewardState) SetStakedAmount(stakedAmount int64) {
	p.stakedAmount = stakedAmount
}

// AppendStakeEvent records that stakedAmount is staked from epoch on.
func (p *ProtocolFeeRewardState) AppendStakeEvent(epoch int64, stakedAmount int64) {
	p.stakeEvents.Set(p.stakeEventCount, &ProtocolFeeStakeEvent{
		epoch:        epoch,
		stakedAmount: stakedAmount,
	})
	p.stakeEventCount++
}

func (p *ProtocolFeeRewardState) SetTokenState(tokenPath string, tokenState *ProtocolFeeTokenRewardState) {
	p.tokenStates.Set(tokenPath, tokenState)
}

func (p *ProtocolFeeRewardState) SetClaimedTimestamp(claimedTimestamp int64) {
	p.claimedTimestamp = claimedTimestamp
}

/* ProtocolFeeTokenRewardState getters and setters */

func (t *ProtocolFeeTokenRewardState) GetEventCursor() int64 {
	return t.eventCursor
}

func (t *ProtocolFeeTokenRewardState) GetSegmentStakedAmount() int64 {
	return t.segmentStakedAmount
}

func (t *ProtocolFeeTokenRewardState) GetSegmentStartX128() *u256.Uint {
	return t.segmentStartX128
}

func (t *ProtocolFeeTokenRewardState) GetEarnedX128() *u256.Uint {
	return t.earnedX128
}

func (t *ProtocolFeeTokenRewardState) GetClaimedReward() int64 {
	return t.claimedReward
}

// SetSegment moves the open segment: events up to eventCursor are folded, and the
// segment starts at segmentStartX128 with segmentStakedAmount staked.
func (t *ProtocolFeeTokenRewardState) SetSegment(eventCursor int64, segmentStakedAmount int64, segmentStartX128 *u256.Uint) {
	t.eventCursor = eventCursor
	t.segmentStakedAmount = segmentStakedAmount
	t.segmentStartX128 = u256.Zero().Set(segmentStartX128)
}

func (t *ProtocolFeeTokenRewardState) SetEarnedX128(earnedX128 *u256.Uint) {
	t.earnedX128 = u256.Zero().Set(earnedX128)
}

func (t *ProtocolFeeTokenRewardState) SetClaimedReward(claimedReward int64) {
	t.claimedReward = claimedReward
}
