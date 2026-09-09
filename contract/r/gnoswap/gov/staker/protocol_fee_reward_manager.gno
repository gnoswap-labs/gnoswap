package staker

import (
	bptree "gno.land/p/nt/bptree/v0"
	ufmt "gno.land/p/nt/ufmt/v0"

	u256 "gno.land/p/gnoswap/uint256"
)

// ProtocolFeeRewardManager manages the distribution of protocol fee rewards to stakers.
// Unlike emission rewards, protocol fees can come from multiple tokens, requiring
// separate tracking and distribution mechanisms for each token type.
type ProtocolFeeRewardManager struct {
	// rewardStates maps address to ProtocolFeeRewardState for tracking individual staker rewards
	rewardStates *bptree.BPTree // address -> ProtocolFeeRewardState

	// accumulatedProtocolFeeX128PerStake maps token path to accumulated fee per stake
	// with 128-bit precision. Values are inline to avoid pointer-valued map entries.
	accumulatedProtocolFeeX128PerStake map[string]u256.Uint
	// protocolFeeAmounts maps token path to total distributed protocol fee amounts
	protocolFeeAmounts map[string]int64
	// accumulatedTimestamp tracks the last timestamp when fees were accumulated
	accumulatedTimestamp int64
	// totalStakedAmount tracks the total amount of tokens staked in the system
	totalStakedAmount int64
}

// NewProtocolFeeRewardManager creates a new instance of ProtocolFeeRewardManager.
// This factory function initializes all tracking structures for multi-token protocol fee reward management.
//
// Returns:
//   - *ProtocolFeeRewardManager: new protocol fee reward manager instance
func NewProtocolFeeRewardManager() *ProtocolFeeRewardManager {
	return &ProtocolFeeRewardManager{
		rewardStates:                       bptree.NewBPTreeN(16),
		protocolFeeAmounts:                 make(map[string]int64),
		accumulatedProtocolFeeX128PerStake: make(map[string]u256.Uint),
		accumulatedTimestamp:               0,
		totalStakedAmount:                  0,
	}
}

/* Getters */

func (p *ProtocolFeeRewardManager) GetRewardState(addr string) (*ProtocolFeeRewardState, bool, error) {
	ri := p.rewardStates.Get(addr)
	if ri == nil {
		return nil, false, nil
	}
	rs, castOk := ri.(*ProtocolFeeRewardState)
	if !castOk {
		return nil, false, ufmt.Errorf(errFailedToCastRewardState, ri)
	}
	return rs, true, nil
}

// GetAccumulatedProtocolFeeX128PerStake returns a detached accumulated protocol fee
// per stake value for a specific token.
//
// A missing token returns nil, while a registered token with a zero value returns
// a non-nil zero Uint. Keeping those states distinct is required by accrual cursors.
func (p *ProtocolFeeRewardManager) GetAccumulatedProtocolFeeX128PerStake(token string) *u256.Uint {
	value, ok := p.accumulatedProtocolFeeX128PerStake[token]
	if !ok {
		return nil
	}
	return value.Clone()
}

func (p *ProtocolFeeRewardManager) GetProtocolFeeAmounts() map[string]int64 {
	return p.protocolFeeAmounts
}

// GetAccumulatedTimestamp returns the last timestamp when protocol fees were accumulated.
//
// Returns:
//   - int64: last accumulated timestamp
func (p *ProtocolFeeRewardManager) GetAccumulatedTimestamp() int64 {
	return p.accumulatedTimestamp
}

func (p *ProtocolFeeRewardManager) GetTotalStakedAmount() int64 {
	return p.totalStakedAmount
}

/* Setters */

func (p *ProtocolFeeRewardManager) SetRewardStates(rewardStates *bptree.BPTree) {
	p.rewardStates = rewardStates
}

func (p *ProtocolFeeRewardManager) SetAccumulatedProtocolFeeX128PerStake(accumulatedProtocolFeeX128PerStake map[string]*u256.Uint) {
	copied := make(map[string]u256.Uint, len(accumulatedProtocolFeeX128PerStake))
	for token, value := range accumulatedProtocolFeeX128PerStake {
		if value == nil {
			continue
		}
		copied[token] = *value
	}
	p.accumulatedProtocolFeeX128PerStake = copied
}

func (p *ProtocolFeeRewardManager) SetProtocolFeeAmounts(protocolFeeAmounts map[string]int64) {
	copied := make(map[string]int64, len(protocolFeeAmounts))
	for token, amount := range protocolFeeAmounts {
		copied[token] = amount
	}
	p.protocolFeeAmounts = copied
}

func (p *ProtocolFeeRewardManager) SetAccumulatedProtocolFeeX128PerStakeForToken(token string, value *u256.Uint) {
	if p.accumulatedProtocolFeeX128PerStake == nil {
		p.accumulatedProtocolFeeX128PerStake = make(map[string]u256.Uint)
	}
	if value == nil {
		delete(p.accumulatedProtocolFeeX128PerStake, token)
		return
	}
	p.accumulatedProtocolFeeX128PerStake[token] = *value
}

func (p *ProtocolFeeRewardManager) SetProtocolFeeAmountForToken(token string, amount int64) {
	if p.protocolFeeAmounts == nil {
		p.protocolFeeAmounts = make(map[string]int64)
	}
	p.protocolFeeAmounts[token] = amount
}

func (p *ProtocolFeeRewardManager) SetAccumulatedTimestamp(accumulatedTimestamp int64) {
	p.accumulatedTimestamp = accumulatedTimestamp
}

func (p *ProtocolFeeRewardManager) SetTotalStakedAmount(totalStakedAmount int64) {
	p.totalStakedAmount = totalStakedAmount
}

// GetAllAccumulatedProtocolFeeX128PerStake returns all accumulated protocol fees per stake
// as detached pointers for compatibility with reward-state APIs.
func (p *ProtocolFeeRewardManager) GetAllAccumulatedProtocolFeeX128PerStake() map[string]*u256.Uint {
	if p.accumulatedProtocolFeeX128PerStake == nil {
		return nil
	}
	copied := make(map[string]*u256.Uint, len(p.accumulatedProtocolFeeX128PerStake))
	for token, value := range p.accumulatedProtocolFeeX128PerStake {
		copied[token] = value.Clone()
	}
	return copied
}

// GetProtocolFeeAmount returns the protocol fee amount for a specific token
func (p *ProtocolFeeRewardManager) GetProtocolFeeAmount(token string) int64 {
	return p.protocolFeeAmounts[token]
}

// SetRewardState sets the reward state for a specific address
func (p *ProtocolFeeRewardManager) SetRewardState(address string, rewardState *ProtocolFeeRewardState) {
	p.rewardStates.Set(address, rewardState)
}
