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
	// Using AVL tree to handle unbounded growth of token types efficiently
	accumulatedProtocolFeeX128PerStake *avl.Tree // token path -> *u256.Uint
	// protocolFeeAmounts maps token path to total distributed protocol fee amounts
	// Using AVL tree to handle unbounded growth of token types efficiently
	protocolFeeAmounts *avl.Tree // token path -> int64
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
		rewardStates:                       avl.NewTree(),
		protocolFeeAmounts:                 avl.NewTree(),
		accumulatedProtocolFeeX128PerStake: avl.NewTree(),
		accumulatedTimestamp:               0,
		totalStakedAmount:                  0,
	}
}

/* Getters */

func (p *ProtocolFeeRewardManager) GetRewardState(addr string) (*ProtocolFeeRewardState, bool, error) {
	ri, ok := p.rewardStates.Get(addr)
	if !ok {
		return nil, false, nil
	}
	rs, castOk := ri.(*ProtocolFeeRewardState)
	if !castOk {
		return nil, false, ufmt.Errorf(errFailedToCastRewardState, ri)
	}
	return rs, true, nil
}

// GetAccumulatedProtocolFeeX128PerStake returns the accumulated protocol fee per stake for a specific token.
//
// Parameters:
//   - token: token path to get accumulated fee for
//
// Returns:
//   - *u256.Uint: accumulated protocol fee per stake for the token (scaled by 2^128)
func (p *ProtocolFeeRewardManager) GetAccumulatedProtocolFeeX128PerStake(token string) *u256.Uint {
	value, exists := p.accumulatedProtocolFeeX128PerStake.Get(token)
	if !exists {
		return nil
	}
	fee, ok := value.(*u256.Uint)
	if !ok {
		return nil
	}
	return fee
}

func (p *ProtocolFeeRewardManager) GetProtocolFeeAmounts() *avl.Tree {
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

func (p *ProtocolFeeRewardManager) SetRewardStates(rewardStates *avl.Tree) {
	p.rewardStates = rewardStates
}

func (p *ProtocolFeeRewardManager) SetAccumulatedProtocolFeeX128PerStake(accumulatedProtocolFeeX128PerStake *avl.Tree) {
	p.accumulatedProtocolFeeX128PerStake = accumulatedProtocolFeeX128PerStake
}

func (p *ProtocolFeeRewardManager) SetProtocolFeeAmounts(protocolFeeAmounts *avl.Tree) {
	p.protocolFeeAmounts = protocolFeeAmounts
}

func (p *ProtocolFeeRewardManager) SetAccumulatedTimestamp(accumulatedTimestamp int64) {
	p.accumulatedTimestamp = accumulatedTimestamp
}

func (p *ProtocolFeeRewardManager) SetTotalStakedAmount(totalStakedAmount int64) {
	p.totalStakedAmount = totalStakedAmount
}

// GetAllAccumulatedProtocolFeeX128PerStake returns all accumulated protocol fees per stake
func (p *ProtocolFeeRewardManager) GetAllAccumulatedProtocolFeeX128PerStake() *avl.Tree {
	return p.accumulatedProtocolFeeX128PerStake
}

// GetProtocolFeeAmount returns the protocol fee amount for a specific token
func (p *ProtocolFeeRewardManager) GetProtocolFeeAmount(token string) int64 {
	value, exists := p.protocolFeeAmounts.Get(token)
	if !exists {
		return 0
	}
	amount, ok := value.(int64)
	if !ok {
		return 0
	}
	return amount
}

// SetRewardState sets the reward state for a specific address
func (p *ProtocolFeeRewardManager) SetRewardState(address string, rewardState *ProtocolFeeRewardState) {
	p.rewardStates.Set(address, rewardState)
}
