package v1

import (
	"gno.land/p/nt/avl"
	"gno.land/r/gnoswap/gov/governance"
)

type mockGovernanceStore struct {
	governanceState governance.GovernanceState
	proposals       *avl.Tree
	nextID          uint64
}

func (m *mockGovernanceStore) HasGovernanceStateStoreKey() bool {
	return m.governanceState != nil
}

func (m *mockGovernanceStore) GetGovernanceState() governance.GovernanceState {
	if m.governanceState == nil {
		m.governanceState = NewGovernanceState()
	}
	return m.governanceState
}

func (m *mockGovernanceStore) SetGovernanceState(governanceState governance.GovernanceState) error {
	m.governanceState = governanceState
	return nil
}

func (m *mockGovernanceStore) HasProposalNextIDStoreKey() bool {
	return true
}

func (m *mockGovernanceStore) GetProposalNextID() uint64 {
	return m.nextID
}

func (m *mockGovernanceStore) SetProposalNextID(nextID uint64) error {
	m.nextID = nextID
	return nil
}

func newMockGovernance() *governanceV1 {
	store := &mockGovernanceStore{
		proposals: avl.NewTree(),
		nextID:    1,
	}
	store.governanceState = NewGovernanceState()
	
	return &governanceV1{
		store: store,
	}
}

func newMockGovernanceStore() *mockGovernanceStore {
	store := &mockGovernanceStore{
		proposals: avl.NewTree(),
		nextID:    1,
	}
	store.governanceState = NewGovernanceState()
	return store
}
