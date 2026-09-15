package staker

import (
	bptree "gno.land/p/nt/bptree/v0"
	ufmt "gno.land/p/nt/ufmt/v0"

	u256 "gno.land/p/gnoswap/uint256/v1"
)

const errFailedToCastRewardState = "failed to cast rewardStates's element to *EmissionRewardState: %T"

// EmissionRewardManager manages the distribution of emission rewards to stakers.
type EmissionRewardManager struct {
	// rewardStates maps address to EmissionRewardState for tracking individual staker rewards
	rewardStates *bptree.BPTree // address -> EmissionRewardState

	// accumulatedRewardX128PerStake tracks the cumulative reward per unit of stake with 128-bit precision
	accumulatedRewardX128PerStake *u256.Uint
	// distributedAmount tracks the total amount of rewards distributed
	distributedAmount int64
	// accumulatedTimestamp tracks the last timestamp when rewards were accumulated
	accumulatedTimestamp int64
	// totalStakedAmount tracks the total amount of tokens staked in the system
	totalStakedAmount int64
}

// NewEmissionRewardManager creates and initializes an EmissionRewardManager with empty reward states and zero accounting totals.
// Returns:
//   - *EmissionRewardManager: initialized manager with empty reward states, zero totals, and a zero Q128 accumulator.
func NewEmissionRewardManager() *EmissionRewardManager {
	return &EmissionRewardManager{
		accumulatedRewardX128PerStake: u256.NewUint(0),
		accumulatedTimestamp:          0,
		totalStakedAmount:             0,
		distributedAmount:             0,
		rewardStates:                  bptree.NewBPTreeN(16),
	}
}

// GetAccumulatedRewardX128PerStake returns the accumulated reward per stake with 128-bit precision.
// Returns:
//   - *u256.Uint: accumulated emission reward per unit of stake in Q128 fixed-point form.
func (e *EmissionRewardManager) GetAccumulatedRewardX128PerStake() *u256.Uint {
	return e.accumulatedRewardX128PerStake
}

// GetAccumulatedTimestamp returns the last timestamp when rewards were accumulated.
// Returns:
//   - int64: Unix timestamp of the latest emission-reward accumulation.
func (e *EmissionRewardManager) GetAccumulatedTimestamp() int64 {
	return e.accumulatedTimestamp
}

// GetTotalStakedAmount returns the total amount of tokens staked in the system.
// Returns:
//   - int64: total staked token amount tracked by the manager.
func (e *EmissionRewardManager) GetTotalStakedAmount() int64 {
	return e.totalStakedAmount
}

// GetDistributedAmount returns the total amount of rewards distributed.
// Returns:
//   - int64: total emission reward amount marked as distributed.
func (e *EmissionRewardManager) GetDistributedAmount() int64 {
	return e.distributedAmount
}

// GetRewardState retrieves the reward state for addr.
//
// Parameters:
//   - addr: Address key identifying the staker's emission reward state.
//
// Returns:
//   - *EmissionRewardState: stored state, or nil when addr has no state.
//   - bool: true when a reward state exists for addr; false when absent.
//   - error: nil on success or absence; non-nil when the stored value has the wrong type.
func (e *EmissionRewardManager) GetRewardState(addr string) (*EmissionRewardState, bool, error) {
	ri := e.rewardStates.Get(addr)
	if ri == nil {
		return nil, false, nil
	}
	rs, castOk := ri.(*EmissionRewardState)
	if !castOk {
		return nil, false, ufmt.Errorf(errFailedToCastRewardState, ri)
	}
	return rs, true, nil
}

/* Setters */

// SetRewardStates replaces the tree containing per-address emission reward states.
//
// Parameters:
//   - rewardStates: BPTree mapping staker addresses to emission reward states.
func (e *EmissionRewardManager) SetRewardStates(rewardStates *bptree.BPTree) {
	e.rewardStates = rewardStates
}

// SetAccumulatedRewardX128PerStake stores the accumulated emission reward per stake.
//
// Parameters:
//   - accumulatedRewardX128PerStake: Q128 fixed-point reward-per-stake accumulator to copy into the manager.
func (e *EmissionRewardManager) SetAccumulatedRewardX128PerStake(accumulatedRewardX128PerStake *u256.Uint) {
	e.accumulatedRewardX128PerStake = u256.Zero().Set(accumulatedRewardX128PerStake)
}

// SetDistributedAmount stores the total emission amount marked as distributed.
//
// Parameters:
//   - distributedAmount: Total emission reward amount distributed so far.
func (e *EmissionRewardManager) SetDistributedAmount(distributedAmount int64) {
	e.distributedAmount = distributedAmount
}

// SetAccumulatedTimestamp stores the latest emission-reward accumulation timestamp.
//
// Parameters:
//   - accumulatedTimestamp: Unix timestamp associated with the current accumulator.
func (e *EmissionRewardManager) SetAccumulatedTimestamp(accumulatedTimestamp int64) {
	e.accumulatedTimestamp = accumulatedTimestamp
}

// SetTotalStakedAmount stores the total amount currently staked.
//
// Parameters:
//   - totalStakedAmount: Aggregate token amount participating in emission rewards.
func (e *EmissionRewardManager) SetTotalStakedAmount(totalStakedAmount int64) {
	e.totalStakedAmount = totalStakedAmount
}

// SetRewardState sets the reward state for a specific address
// SetRewardState stores one staker's emission reward state under address.
//
// Parameters:
//   - address: Address key for the staker's reward state.
//   - rewardState: Emission reward state to store for address.
func (e *EmissionRewardManager) SetRewardState(address string, rewardState *EmissionRewardState) {
	e.rewardStates.Set(address, rewardState)
}
