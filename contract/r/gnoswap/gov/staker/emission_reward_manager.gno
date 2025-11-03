package staker

import (
	"gno.land/p/nt/avl"
	"gno.land/p/nt/ufmt"

	u256 "gno.land/p/gnoswap/uint256"
)

var errFailedToCastRewardState = "failed to cast rewardStates's element to *EmissionRewardState: %T"

// EmissionRewardManager manages the distribution of emission rewards to stakers.
type EmissionRewardManager struct {
	// rewardStates maps address to EmissionRewardState for tracking individual staker rewards
	rewardStates *avl.Tree // address -> EmissionRewardState

	// accumulatedRewardX128PerStake tracks the cumulative reward per unit of stake with 128-bit precision
	accumulatedRewardX128PerStake *u256.Uint
	// distributedAmount tracks the total amount of rewards distributed
	distributedAmount int64
	// accumulatedTimestamp tracks the last timestamp when rewards were accumulated
	accumulatedTimestamp int64
	// totalStakedAmount tracks the total amount of tokens staked in the system
	totalStakedAmount int64
}

// NewEmissionRewardManager creates a new instance of EmissionRewardManager.
// This factory function initializes all tracking structures for emission reward management.
// NewEmissionRewardManager creates new emission reward manager instance.
func NewEmissionRewardManager() *EmissionRewardManager {
	return &EmissionRewardManager{
		accumulatedRewardX128PerStake: u256.NewUint(0),
		accumulatedTimestamp:          0,
		totalStakedAmount:             0,
		distributedAmount:             0,
		rewardStates:                  avl.NewTree(),
	}
}

// GetAccumulatedRewardX128PerStake returns the accumulated reward per stake with 128-bit precision.
func (e *EmissionRewardManager) GetAccumulatedRewardX128PerStake() *u256.Uint {
	return e.accumulatedRewardX128PerStake
}

// GetAccumulatedTimestamp returns the last timestamp when rewards were accumulated.
func (e *EmissionRewardManager) GetAccumulatedTimestamp() int64 {
	return e.accumulatedTimestamp
}

// GetTotalStakedAmount returns the total amount of tokens staked in the system.
func (e *EmissionRewardManager) GetTotalStakedAmount() int64 {
	return e.totalStakedAmount
}

// GetDistributedAmount returns the total amount of rewards distributed.
func (e *EmissionRewardManager) GetDistributedAmount() int64 {
	return e.distributedAmount
}

func (e *EmissionRewardManager) GetRewardState(addr string) (*EmissionRewardState, bool, error) {
	ri, ok := e.rewardStates.Get(addr)
	if !ok {
		return nil, false, nil
	}
	rs, castOk := ri.(*EmissionRewardState)
	if !castOk {
		return nil, false, ufmt.Errorf(errFailedToCastRewardState, ri)
	}
	return rs, true, nil
}

/* Setters */

func (e *EmissionRewardManager) SetRewardStates(rewardStates *avl.Tree) {
	e.rewardStates = rewardStates
}

func (e *EmissionRewardManager) SetAccumulatedRewardX128PerStake(accumulatedRewardX128PerStake *u256.Uint) {
	e.accumulatedRewardX128PerStake = accumulatedRewardX128PerStake
}

func (e *EmissionRewardManager) SetDistributedAmount(distributedAmount int64) {
	e.distributedAmount = distributedAmount
}

func (e *EmissionRewardManager) SetAccumulatedTimestamp(accumulatedTimestamp int64) {
	e.accumulatedTimestamp = accumulatedTimestamp
}

func (e *EmissionRewardManager) SetTotalStakedAmount(totalStakedAmount int64) {
	e.totalStakedAmount = totalStakedAmount
}

// SetRewardState sets the reward state for a specific address
func (e *EmissionRewardManager) SetRewardState(address string, rewardState *EmissionRewardState) {
	e.rewardStates.Set(address, rewardState)
}
