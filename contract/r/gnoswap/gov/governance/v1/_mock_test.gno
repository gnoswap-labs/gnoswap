package v1

// import (
// 	"gno.land/p/nt/avl"
// )

// type mockGovernanceStore struct {
// 	proposals *avl.Tree
// 	nextID uint64
// }

// func (m *mockGovernanceStore) HasProposalsStoreKey() bool {
// 	return false
// }

// func (m *mockGovernance)

// func (m *mockGovernanceStore) GetProposals() *avl.Tree {
// 	return m.proposals
// }

// func (m *mockGovernanceStore) SetProposals(proposals *avl.Tree) error {
// 	m.proposals = proposals
// 	return nil
// }

// func (m *mockGovernanceStore) HasProposalNextIDStoreKey() bool {
// 	return false
// }

// func (m *mockGovernanceStore) GetProposalNextID() uint64 {
// 	return m.nextID
// }

// func (m *mockGovernanceStore) SetProposalNextID(nextID uint64) error {
// 	m.nextID = nextID
// 	return nil
// }

// func newMockGovernance() *governanceV1 {
// 	return &governanceV1{
// 		store: &mockGovernanceStore{proposals: avl.NewTree(), nextID: 1},
// 	}
// }

// func newMockGovernanceStore() *mockGovernanceStore {
// 	return &mockGovernanceStore{proposals: avl.NewTree(), nextID: 1}
// }
