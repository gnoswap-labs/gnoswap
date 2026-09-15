package staker

import (
	bptree "gno.land/p/nt/bptree/v0"
	ufmt "gno.land/p/nt/ufmt/v0"

	u256 "gno.land/p/gnoswap/uint256"
)

// ProtocolFeeRewardManager distributes protocol fees to stakers.
//
// Protocol fees arrive in many tokens, so the manager keeps one accumulator per token
// instead of a single one. A stake change never touches those accumulators: it advances
// the accrual epoch, records the total stake in force from that epoch, and appends one
// event for an ordinary add/remove. Redelegate performs a remove plus an add and
// therefore appends two events. The per-token work happens when a token is collected,
// so stake-change cost does not depend on how many tokens ever collected a fee.
type ProtocolFeeRewardManager struct {
	// rewardStates maps a reward ID to the ProtocolFeeRewardState tracking that staker
	rewardStates *bptree.BPTree // rewardID -> *ProtocolFeeRewardState
	// tokenAccumulators maps a token path to its ProtocolFeeTokenAccumulator
	tokenAccumulators *bptree.BPTree // tokenPath -> *ProtocolFeeTokenAccumulator
	// currentEpoch is the accrual epoch in force, mirrored from protocol_fee
	currentEpoch int64
	// totalStakedAmount is the total amount currently staked
	totalStakedAmount int64
	// totalStakedHistory records the total staked amount in force from each epoch
	totalStakedHistory *UintTree // epoch -> int64
	// accumulatedTimestamp is the last timestamp at which the accrual state moved: a fold or a stake change
	accumulatedTimestamp int64
}

// NewProtocolFeeRewardManager creates a new instance of ProtocolFeeRewardManager.
//
// Returns:
//   - *ProtocolFeeRewardManager: new protocol fee reward manager instance
func NewProtocolFeeRewardManager() *ProtocolFeeRewardManager {
	totalStakedHistory := NewUintTree()
	totalStakedHistory.Set(0, int64(0))

	return &ProtocolFeeRewardManager{
		rewardStates:         bptree.NewBPTreeN(16),
		tokenAccumulators:    bptree.NewBPTreeN(16),
		currentEpoch:         0,
		totalStakedAmount:    0,
		totalStakedHistory:   totalStakedHistory,
		accumulatedTimestamp: 0,
	}
}

/* Getters */

// GetRewardState retrieves the reward state identified by rewardID.
// Missing IDs return nil and false; a stored value of the wrong type returns
// an error.
//
// Parameters:
//   - rewardID: identifier of the staker reward state to retrieve
//
// Returns:
//   - *ProtocolFeeRewardState: stored reward state, or nil when rewardID is absent or invalid
//   - bool: true when a correctly typed reward state was found
//   - error: nil when absent or found; a cast error when the stored value has the wrong type
func (p *ProtocolFeeRewardManager) GetRewardState(rewardID string) (*ProtocolFeeRewardState, bool, error) {
	ri := p.rewardStates.Get(rewardID)
	if ri == nil {
		return nil, false, nil
	}
	rs, castOk := ri.(*ProtocolFeeRewardState)
	if !castOk {
		return nil, false, ufmt.Errorf(errFailedToCastRewardState, ri)
	}
	return rs, true, nil
}

// GetTokenAccumulator returns the accumulator of tokenPath, or false when the token
// never had a fee folded in.
//
// Parameters:
//   - tokenPath: token package path whose protocol-fee accumulator is requested
//
// Returns:
//   - *ProtocolFeeTokenAccumulator: accumulator for tokenPath, or nil when none exists
//   - bool: true when tokenPath has a folded-fee accumulator
func (p *ProtocolFeeRewardManager) GetTokenAccumulator(tokenPath string) (*ProtocolFeeTokenAccumulator, bool) {
	ai := p.tokenAccumulators.Get(tokenPath)
	if ai == nil {
		return nil, false
	}
	accumulator, castOk := ai.(*ProtocolFeeTokenAccumulator)
	if !castOk {
		panic(ufmt.Sprintf("failed to cast token accumulator: %T", ai))
	}
	return accumulator, true
}

// GetTokenPaths returns every token path that had a fee folded in, in key order.
//
// Returns:
//   - []string: token paths present in the accumulator tree, ordered by tree key
func (p *ProtocolFeeRewardManager) GetTokenPaths() []string {
	tokenPaths := make([]string, 0, p.tokenAccumulators.Size())
	p.tokenAccumulators.Iterate("", "", func(key string, _ any) bool {
		tokenPaths = append(tokenPaths, key)
		return false
	})
	return tokenPaths
}

// GetAccumulatedProtocolFeeX128PerStake returns the accumulated fee per stake of tokenPath
// (scaled by 2^128), or nil when the token never had a fee folded in.
//
// Parameters:
//   - tokenPath: token package path whose accumulated per-stake fee is requested
//
// Returns:
//   - *u256.Uint: accumulated fee per stake scaled by 2^128, or nil when tokenPath has no accumulator
func (p *ProtocolFeeRewardManager) GetAccumulatedProtocolFeeX128PerStake(tokenPath string) *u256.Uint {
	accumulator, ok := p.GetTokenAccumulator(tokenPath)
	if !ok {
		return nil
	}
	return accumulator.GetAccumulatedX128PerStake()
}

// GetProtocolFeeAmount returns the total fee amount folded in for tokenPath.
//
// Parameters:
//   - tokenPath: token package path whose folded protocol-fee amount is requested
//
// Returns:
//   - int64: total fee amount folded for tokenPath, or zero when no accumulator exists
func (p *ProtocolFeeRewardManager) GetProtocolFeeAmount(tokenPath string) int64 {
	accumulator, ok := p.GetTokenAccumulator(tokenPath)
	if !ok {
		return 0
	}
	return accumulator.GetProtocolFeeAmount()
}

// GetCurrentEpoch returns the accrual epoch currently in force.
//
// Returns:
//   - int64: current protocol-fee accrual epoch
func (p *ProtocolFeeRewardManager) GetCurrentEpoch() int64 {
	return p.currentEpoch
}

// GetTotalStakedAmount returns the total amount currently staked.
//
// Returns:
//   - int64: current total staked amount
func (p *ProtocolFeeRewardManager) GetTotalStakedAmount() int64 {
	return p.totalStakedAmount
}

// GetTotalStakedAmountAt returns the total staked amount in force during epoch,
// using the latest recorded stake amount at or before that epoch.
//
// Parameters:
//   - epoch: accrual epoch whose effective total stake is requested
//
// Returns:
//   - int64: total stake recorded at or before epoch, or zero for a negative epoch
func (p *ProtocolFeeRewardManager) GetTotalStakedAmountAt(epoch int64) int64 {
	if epoch < 0 {
		return 0
	}

	totalStakedAmount := int64(0)
	p.totalStakedHistory.ReverseIterate(0, epoch, func(_ int64, value any) bool {
		amount, castOk := value.(int64)
		if !castOk {
			panic(ufmt.Sprintf("failed to cast total staked amount: %T", value))
		}
		totalStakedAmount = amount
		return true
	})

	return totalStakedAmount
}

// GetAccumulatedTimestamp returns the last timestamp at which fee accrual
// state moved through a fold or stake change.
//
// Returns:
//   - int64: last accumulated-state update timestamp
func (p *ProtocolFeeRewardManager) GetAccumulatedTimestamp() int64 {
	return p.accumulatedTimestamp
}

/* Setters */

// SetRewardState stores rewardState under rewardID.
//
// Parameters:
//   - rewardID: identifier under which the staker reward state is stored
//   - rewardState: reward state to associate with rewardID
func (p *ProtocolFeeRewardManager) SetRewardState(rewardID string, rewardState *ProtocolFeeRewardState) {
	p.rewardStates.Set(rewardID, rewardState)
}

// SetTokenAccumulator stores accumulator under tokenPath.
//
// Parameters:
//   - tokenPath: token package path used as the accumulator key
//   - accumulator: protocol-fee accumulator to store for tokenPath
func (p *ProtocolFeeRewardManager) SetTokenAccumulator(tokenPath string, accumulator *ProtocolFeeTokenAccumulator) {
	p.tokenAccumulators.Set(tokenPath, accumulator)
}

// SetCurrentEpoch records the accrual epoch currently in force.
//
// Parameters:
//   - epoch: new current protocol-fee accrual epoch
func (p *ProtocolFeeRewardManager) SetCurrentEpoch(epoch int64) {
	p.currentEpoch = epoch
}

// SetTotalStakedAmount records the total amount currently staked.
//
// Parameters:
//   - totalStakedAmount: new total staked amount
func (p *ProtocolFeeRewardManager) SetTotalStakedAmount(totalStakedAmount int64) {
	p.totalStakedAmount = totalStakedAmount
}

// SetTotalStakedAmountAt records the total staked amount in force from epoch on.
//
// Parameters:
//   - epoch: first accrual epoch at which totalStakedAmount is in force
//   - totalStakedAmount: total stake amount to record from epoch onward
func (p *ProtocolFeeRewardManager) SetTotalStakedAmountAt(epoch int64, totalStakedAmount int64) {
	p.totalStakedHistory.Set(epoch, totalStakedAmount)
}

// SetAccumulatedTimestamp records the timestamp at which accrual state last moved.
//
// Parameters:
//   - accumulatedTimestamp: timestamp to record for the latest fold or stake change
func (p *ProtocolFeeRewardManager) SetAccumulatedTimestamp(accumulatedTimestamp int64) {
	p.accumulatedTimestamp = accumulatedTimestamp
}
