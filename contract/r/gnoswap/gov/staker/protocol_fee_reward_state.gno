package staker

import (
	u256 "gno.land/p/gnoswap/uint256"
)

// ProtocolFeeRewardState tracks protocol fee reward information for an individual staker across multiple tokens.
// Unlike emission rewards which are single-token, protocol fees can come from various trading pairs,
// requiring separate tracking and calculation for each token type.
type ProtocolFeeRewardState struct {
	// rewardDebtX128 maps token path to reward debt with 128-bit precision scaling
	// Used to calculate rewards earned since the last update for each token
	rewardDebtX128 map[string]*u256.Uint
	// accumulatedRewards maps token path to total rewards accumulated but not yet claimed
	accumulatedRewards map[string]int64
	// claimedRewards maps token path to total amount of rewards that have been claimed
	claimedRewards map[string]int64
	// accumulatedTimestamp is the last timestamp when rewards were accumulated
	accumulatedTimestamp int64
	// claimedTimestamp is the last timestamp when rewards were claimed
	claimedTimestamp int64
	// stakedAmount is the current amount of tokens staked by this address
	stakedAmount int64
}

func (p *ProtocolFeeRewardState) GetRewardDebtX128() map[string]*u256.Uint {
	return p.rewardDebtX128
}

func (p *ProtocolFeeRewardState) GetAccumulatedRewards() map[string]int64 {
	return p.accumulatedRewards
}

func (p *ProtocolFeeRewardState) GetClaimedRewards() map[string]int64 {
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

func (p *ProtocolFeeRewardState) SetRewardDebtX128(rewardDebtX128 map[string]*u256.Uint) {
	p.rewardDebtX128 = rewardDebtX128
}

func (p *ProtocolFeeRewardState) SetAccumulatedRewards(accumulatedRewards map[string]int64) {
	p.accumulatedRewards = accumulatedRewards
}

func (p *ProtocolFeeRewardState) SetClaimedRewards(claimedRewards map[string]int64) {
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
	return p.rewardDebtX128[token]
}

func (p *ProtocolFeeRewardState) GetAccumulatedRewardForToken(token string) int64 {
	if p.accumulatedRewards == nil {
		return 0
	}
	return p.accumulatedRewards[token]
}

func (p *ProtocolFeeRewardState) GetClaimedRewardForToken(token string) int64 {
	if p.claimedRewards == nil {
		return 0
	}
	return p.claimedRewards[token]
}

// Additional setters for individual token rewards

func (p *ProtocolFeeRewardState) SetRewardDebtX128ForToken(token string, value *u256.Uint) {
	if p.rewardDebtX128 == nil {
		p.rewardDebtX128 = make(map[string]*u256.Uint)
	}
	p.rewardDebtX128[token] = value
}

func (p *ProtocolFeeRewardState) SetAccumulatedRewardForToken(token string, value int64) {
	if p.accumulatedRewards == nil {
		p.accumulatedRewards = make(map[string]int64)
	}
	p.accumulatedRewards[token] = value
}

func (p *ProtocolFeeRewardState) SetClaimedRewardForToken(token string, value int64) {
	if p.claimedRewards == nil {
		p.claimedRewards = make(map[string]int64)
	}
	p.claimedRewards[token] = value
}

// NewProtocolFeeRewardState creates a new protocol fee reward state for a staker.
// This factory function initializes the state with the current system reward debt for all tokens.
func NewProtocolFeeRewardState(accumulatedProtocolFeeX128PerStake map[string]*u256.Uint) *ProtocolFeeRewardState {
	rewardDebtX128 := make(map[string]*u256.Uint)

	// Clone reward debt for each token to avoid reference issues
	for token, accumulatedFee := range accumulatedProtocolFeeX128PerStake {
		rewardDebtX128[token] = accumulatedFee.Clone()
	}

	return &ProtocolFeeRewardState{
		rewardDebtX128:       rewardDebtX128,
		claimedRewards:       make(map[string]int64),
		accumulatedRewards:   make(map[string]int64),
		stakedAmount:         0,
		accumulatedTimestamp: 0,
		claimedTimestamp:     0,
	}
}
