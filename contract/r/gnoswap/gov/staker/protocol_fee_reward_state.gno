package staker

import (
	"gno.land/p/nt/avl"

	u256 "gno.land/p/gnoswap/uint256"
)

// ProtocolFeeRewardState tracks protocol fee reward information for an individual staker across multiple tokens.
// Unlike emission rewards which are single-token, protocol fees can come from various trading pairs,
// requiring separate tracking and calculation for each token type.
type ProtocolFeeRewardState struct {
	// rewardDebtX128 maps token path to reward debt with 128-bit precision scaling
	// Used to calculate rewards earned since the last update for each token
	// Using AVL tree to handle unbounded growth of token types efficiently
	rewardDebtX128 *avl.Tree // token path -> *u256.Uint
	// accumulatedRewards maps token path to total rewards accumulated but not yet claimed
	// Using AVL tree to handle unbounded growth of token types efficiently
	accumulatedRewards *avl.Tree // token path -> int64
	// claimedRewards maps token path to total amount of rewards that have been claimed
	// Using AVL tree to handle unbounded growth of token types efficiently
	claimedRewards *avl.Tree // token path -> int64
	// accumulatedTimestamp is the last timestamp when rewards were accumulated
	accumulatedTimestamp int64
	// claimedTimestamp is the last timestamp when rewards were claimed
	claimedTimestamp int64
	// stakedAmount is the current amount of tokens staked by this address
	stakedAmount int64
}

func (p *ProtocolFeeRewardState) GetRewardDebtX128() *avl.Tree {
	return p.rewardDebtX128
}

func (p *ProtocolFeeRewardState) GetAccumulatedRewards() *avl.Tree {
	return p.accumulatedRewards
}

func (p *ProtocolFeeRewardState) GetClaimedRewards() *avl.Tree {
	return p.claimedRewards
}

func (p *ProtocolFeeRewardState) GetAccumulatedTimestamp() int64 {
	return p.accumulatedTimestamp
}

func (p *ProtocolFeeRewardState) GetClaimedTimestamp() int64 {
	return p.claimedTimestamp
}

func (p *ProtocolFeeRewardState) GetStakedAmount() int64 {
	return p.stakedAmount
}

/* Setters */

func (p *ProtocolFeeRewardState) SetRewardDebtX128(rewardDebtX128 *avl.Tree) {
	p.rewardDebtX128 = rewardDebtX128
}

func (p *ProtocolFeeRewardState) SetAccumulatedRewards(accumulatedRewards *avl.Tree) {
	p.accumulatedRewards = accumulatedRewards
}

func (p *ProtocolFeeRewardState) SetClaimedRewards(claimedRewards *avl.Tree) {
	p.claimedRewards = claimedRewards
}

func (p *ProtocolFeeRewardState) SetAccumulatedTimestamp(accumulatedTimestamp int64) {
	p.accumulatedTimestamp = accumulatedTimestamp
}

func (p *ProtocolFeeRewardState) SetClaimedTimestamp(claimedTimestamp int64) {
	p.claimedTimestamp = claimedTimestamp
}

func (p *ProtocolFeeRewardState) SetStakedAmount(stakedAmount int64) {
	p.stakedAmount = stakedAmount
}

// Additional getters for individual token rewards

func (p *ProtocolFeeRewardState) GetRewardDebtX128ForToken(token string) *u256.Uint {
	if p.rewardDebtX128 == nil {
		return nil
	}
	value, exists := p.rewardDebtX128.Get(token)
	if !exists {
		return nil
	}
	debt, ok := value.(*u256.Uint)
	if !ok {
		return nil
	}
	return debt
}

func (p *ProtocolFeeRewardState) GetAccumulatedRewardForToken(token string) int64 {
	if p.accumulatedRewards == nil {
		return 0
	}
	value, exists := p.accumulatedRewards.Get(token)
	if !exists {
		return 0
	}
	reward, ok := value.(int64)
	if !ok {
		return 0
	}
	return reward
}

func (p *ProtocolFeeRewardState) GetClaimedRewardForToken(token string) int64 {
	if p.claimedRewards == nil {
		return 0
	}
	value, exists := p.claimedRewards.Get(token)
	if !exists {
		return 0
	}
	claimed, ok := value.(int64)
	if !ok {
		return 0
	}
	return claimed
}

// Additional setters for individual token rewards

func (p *ProtocolFeeRewardState) SetRewardDebtX128ForToken(token string, value *u256.Uint) {
	if p.rewardDebtX128 == nil {
		p.rewardDebtX128 = avl.NewTree()
	}
	p.rewardDebtX128.Set(token, value)
}

func (p *ProtocolFeeRewardState) SetAccumulatedRewardForToken(token string, value int64) {
	if p.accumulatedRewards == nil {
		p.accumulatedRewards = avl.NewTree()
	}
	p.accumulatedRewards.Set(token, value)
}

func (p *ProtocolFeeRewardState) SetClaimedRewardForToken(token string, value int64) {
	if p.claimedRewards == nil {
		p.claimedRewards = avl.NewTree()
	}
	p.claimedRewards.Set(token, value)
}

// NewProtocolFeeRewardState creates a new protocol fee reward state for a staker.
// This factory function initializes the state with the current system reward debt for all tokens.
func NewProtocolFeeRewardState(accumulatedProtocolFeeX128PerStake *avl.Tree) *ProtocolFeeRewardState {
	rewardDebtX128 := avl.NewTree()

	// Clone reward debt for each token to avoid reference issues
	if accumulatedProtocolFeeX128PerStake != nil {
		accumulatedProtocolFeeX128PerStake.Iterate("", "", func(key string, value interface{}) bool {
			if accumulatedFee, ok := value.(*u256.Uint); ok {
				rewardDebtX128.Set(key, accumulatedFee.Clone())
			}
			return false
		})
	}

	return &ProtocolFeeRewardState{
		rewardDebtX128:       rewardDebtX128,
		claimedRewards:       avl.NewTree(),
		accumulatedRewards:   avl.NewTree(),
		stakedAmount:         0,
		accumulatedTimestamp: 0,
		claimedTimestamp:     0,
	}
}
