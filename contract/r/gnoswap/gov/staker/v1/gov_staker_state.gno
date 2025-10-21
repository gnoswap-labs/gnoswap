package v1

import (
	"gno.land/p/nt/avl"
	"gno.land/r/gnoswap/gov/staker"
)

// govStakerStateV1 implements the GovStakerState interface
type govStakerStateV1 struct {
	// Lockup configuration
	unDelegationLockupPeriod int64

	// Delegation management
	delegationCounter    interface{} // *counter.Counter
	delegations          *avl.Tree
	delegationManager    interface{} // *DelegationManager
	delegationHistory    *avl.Tree
	delegationSnapshots  *avl.Tree

	// Reward managers
	emissionRewardManager    interface{} // *EmissionRewardManager
	protocolFeeRewardManager interface{} // *ProtocolFeeRewardManager

	// Launchpad integration
	launchpadProjectDeposits *avl.Tree

	// Aggregate metrics
	totalDelegatedAmount int64
	totalLockedAmount    int64
}

// Ensure govStakerStateV1 implements GovStakerState interface
var _ staker.GovStakerState = (*govStakerStateV1)(nil)

// UnDelegationLockupPeriod returns the lockup period for undelegation
func (s *govStakerStateV1) UnDelegationLockupPeriod() int64 {
	return s.unDelegationLockupPeriod
}

// DelegationCounter returns the delegation counter
func (s *govStakerStateV1) DelegationCounter() interface{} {
	return s.delegationCounter
}

// Delegations returns the delegations tree
func (s *govStakerStateV1) Delegations() *avl.Tree {
	return s.delegations
}

// DelegationManager returns the delegation manager
func (s *govStakerStateV1) DelegationManager() interface{} {
	return s.delegationManager
}

// DelegationHistory returns the delegation history tree
func (s *govStakerStateV1) DelegationHistory() *avl.Tree {
	return s.delegationHistory
}

// DelegationSnapshots returns the delegation snapshots tree
func (s *govStakerStateV1) DelegationSnapshots() *avl.Tree {
	return s.delegationSnapshots
}

// EmissionRewardManager returns the emission reward manager
func (s *govStakerStateV1) EmissionRewardManager() interface{} {
	return s.emissionRewardManager
}

// ProtocolFeeRewardManager returns the protocol fee reward manager
func (s *govStakerStateV1) ProtocolFeeRewardManager() interface{} {
	return s.protocolFeeRewardManager
}

// LaunchpadProjectDeposits returns the launchpad project deposits tree
func (s *govStakerStateV1) LaunchpadProjectDeposits() *avl.Tree {
	return s.launchpadProjectDeposits
}

// TotalDelegatedAmount returns the total delegated amount
func (s *govStakerStateV1) TotalDelegatedAmount() int64 {
	return s.totalDelegatedAmount
}

// TotalLockedAmount returns the total locked amount
func (s *govStakerStateV1) TotalLockedAmount() int64 {
	return s.totalLockedAmount
}

// NewGovStakerStateV1 creates a new govStakerStateV1 instance
func NewGovStakerStateV1() staker.GovStakerState {
	return &govStakerStateV1{
		unDelegationLockupPeriod: 60 * 60 * 24 * 7, // 7 days
		delegations:              avl.NewTree(),
		delegationHistory:        avl.NewTree(),
		delegationSnapshots:      avl.NewTree(),
		launchpadProjectDeposits: avl.NewTree(),
		totalDelegatedAmount:     0,
		totalLockedAmount:        0,
	}
}