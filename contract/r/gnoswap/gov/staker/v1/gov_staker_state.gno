package v1

import (
	"gno.land/p/nt/avl"
	"gno.land/r/gnoswap/gov/staker"
)

// GovStakerState implements staker.GovStakerState interface
type GovStakerState struct {
	unDelegationLockupPeriod   int64
	delegationCounter          *Counter
	delegations                *avl.Tree
	delegationManager          *DelegationManager
	delegationHistory          *avl.Tree
	delegationSnapshots        *avl.Tree
	emissionRewardManager      *EmissionRewardManager
	protocolFeeRewardManager   *ProtocolFeeRewardManager
	launchpadProjectDeposits   *avl.Tree
	totalDelegatedAmount       int64
	totalLockedAmount          int64
}

// UnDelegationLockupPeriod returns the lockup period
func (s *GovStakerState) UnDelegationLockupPeriod() int64 {
	return s.unDelegationLockupPeriod
}

// DelegationCounter returns the delegation counter
func (s *GovStakerState) DelegationCounter() interface{} {
	return s.delegationCounter
}

// Delegations returns the delegations tree
func (s *GovStakerState) Delegations() *avl.Tree {
	return s.delegations
}

// DelegationManager returns the delegation manager
func (s *GovStakerState) DelegationManager() interface{} {
	return s.delegationManager
}

// DelegationHistory returns the delegation history
func (s *GovStakerState) DelegationHistory() *avl.Tree {
	return s.delegationHistory
}

// DelegationSnapshots returns the delegation snapshots
func (s *GovStakerState) DelegationSnapshots() *avl.Tree {
	return s.delegationSnapshots
}

// EmissionRewardManager returns the emission reward manager
func (s *GovStakerState) EmissionRewardManager() interface{} {
	return s.emissionRewardManager
}

// ProtocolFeeRewardManager returns the protocol fee reward manager
func (s *GovStakerState) ProtocolFeeRewardManager() interface{} {
	return s.protocolFeeRewardManager
}

// LaunchpadProjectDeposits returns the launchpad project deposits
func (s *GovStakerState) LaunchpadProjectDeposits() *avl.Tree {
	return s.launchpadProjectDeposits
}

// TotalDelegatedAmount returns the total delegated amount
func (s *GovStakerState) TotalDelegatedAmount() int64 {
	return s.totalDelegatedAmount
}

// TotalLockedAmount returns the total locked amount
func (s *GovStakerState) TotalLockedAmount() int64 {
	return s.totalLockedAmount
}

// Global state instance (temporary until full migration)
var globalState *GovStakerState

func init() {
	globalState = &GovStakerState{
		unDelegationLockupPeriod:   60 * 60 * 24 * 7, // 7 days
		delegationCounter:          NewCounter(),
		delegations:                avl.NewTree(),
		delegationManager:          NewDelegationManager(),
		delegationHistory:          avl.NewTree(),
		delegationSnapshots:        avl.NewTree(),
		emissionRewardManager:      NewEmissionRewardManager(),
		protocolFeeRewardManager:   NewProtocolFeeRewardManager(),
		launchpadProjectDeposits:   avl.NewTree(),
		totalDelegatedAmount:       0,
		totalLockedAmount:          0,
	}
}

// getGlobalState returns the global state instance
func getGlobalState() *GovStakerState {
	return globalState
}