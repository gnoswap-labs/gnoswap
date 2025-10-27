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
	delegationCounter    *Counter
	delegations          *avl.Tree
	delegationManager    *DelegationManager
	delegationHistory    DelegationHistory
	delegationSnapshots  DelegationSnapshot

	// Reward managers
	emissionRewardManager    *EmissionRewardManager
	protocolFeeRewardManager *ProtocolFeeRewardManager

	// Launchpad integration
	launchpadProjectDeposits *avl.Tree

	// Reward balances (previously global variables)
	emissionRewardBalance int64
	protocolFeeBalances   map[string]int64

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

// SetUnDelegationLockupPeriod updates the undelegation lockup period
func (s *govStakerStateV1) SetUnDelegationLockupPeriod(period int64) {
	s.unDelegationLockupPeriod = period
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
	// Convert DelegationHistory to *avl.Tree for interface compatibility
	// This is a temporary workaround until we update the interface
	tree := avl.NewTree()
	for i, record := range s.delegationHistory {
		tree.Set(formatInt(int64(i)), record)
	}
	return tree
}

// DelegationSnapshots returns the delegation snapshots tree
func (s *govStakerStateV1) DelegationSnapshots() *avl.Tree {
	// Convert DelegationSnapshot to *avl.Tree for interface compatibility
	// This is a temporary workaround until we update the interface
	tree := avl.NewTree()
	for k, v := range s.delegationSnapshots {
		tree.Set(k, v)
	}
	return tree
}

// SetDelegationHistory sets the delegation history
func (s *govStakerStateV1) SetDelegationHistory(history DelegationHistory) {
	s.delegationHistory = history
}

// SetDelegationSnapshots sets the delegation snapshots
func (s *govStakerStateV1) SetDelegationSnapshots(snapshots DelegationSnapshot) {
	s.delegationSnapshots = snapshots
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

// SetTotalDelegatedAmount sets the total delegated amount
func (s *govStakerStateV1) SetTotalDelegatedAmount(amount int64) {
	s.totalDelegatedAmount = amount
}

// SetTotalLockedAmount sets the total locked amount
func (s *govStakerStateV1) SetTotalLockedAmount(amount int64) {
	s.totalLockedAmount = amount
}

// EmissionRewardBalance returns the emission reward balance
func (s *govStakerStateV1) EmissionRewardBalance() int64 {
	return s.emissionRewardBalance
}

// SetEmissionRewardBalance sets the emission reward balance
func (s *govStakerStateV1) SetEmissionRewardBalance(balance int64) {
	s.emissionRewardBalance = balance
}

// ProtocolFeeBalances returns the protocol fee balances
func (s *govStakerStateV1) ProtocolFeeBalances() map[string]int64 {
	return s.protocolFeeBalances
}

// SetProtocolFeeBalances sets the protocol fee balances
func (s *govStakerStateV1) SetProtocolFeeBalances(balances map[string]int64) {
	s.protocolFeeBalances = balances
}

// GetDelegationHistoryDirect returns the delegation history directly
func (s *govStakerStateV1) GetDelegationHistoryDirect() DelegationHistory {
	return s.delegationHistory
}

// GetDelegationSnapshotsDirect returns the delegation snapshots directly
func (s *govStakerStateV1) GetDelegationSnapshotsDirect() DelegationSnapshot {
	return s.delegationSnapshots
}

// NewGovStakerStateV1 creates a new govStakerStateV1 instance
func NewGovStakerStateV1() staker.GovStakerState {
	return &govStakerStateV1{
		unDelegationLockupPeriod: 60 * 60 * 24 * 7, // 7 days
		delegationCounter:        NewCounter(),
		delegations:              avl.NewTree(),
		delegationManager:        NewDelegationManager(),
		delegationHistory:        make(DelegationHistory, 0),
		delegationSnapshots:      make(DelegationSnapshot),
		emissionRewardManager:    NewEmissionRewardManager(),
		protocolFeeRewardManager: NewProtocolFeeRewardManager(),
		launchpadProjectDeposits: avl.NewTree(),
		emissionRewardBalance:    0,
		protocolFeeBalances:      make(map[string]int64),
		totalDelegatedAmount:     0,
		totalLockedAmount:        0,
	}
}