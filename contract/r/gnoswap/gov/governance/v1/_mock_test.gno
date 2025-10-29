package v1

import (
	"gno.land/p/nt/avl"
	"gno.land/r/gnoswap/gov/governance"
)

type mockGovernanceStore struct {
	configCounter           *governance.Counter
	proposalCounter         *governance.Counter
	configs                 *avl.Tree
	proposals               *avl.Tree
	proposalUserVotingInfos *avl.Tree
	userProposals           *avl.Tree
}

// Counter methods
func (m *mockGovernanceStore) HasConfigCounterStoreKey() bool {
	return true
}

func (m *mockGovernanceStore) GetConfigCounter() *governance.Counter {
	return m.configCounter
}

func (m *mockGovernanceStore) SetConfigCounter(counter *governance.Counter) error {
	m.configCounter = counter
	return nil
}

func (m *mockGovernanceStore) IncrementConfigCounter() (int64, error) {
	m.configCounter.Next()
	return m.configCounter.Get(), nil
}

func (m *mockGovernanceStore) HasProposalCounterStoreKey() bool {
	return true
}

func (m *mockGovernanceStore) GetProposalCounter() *governance.Counter {
	return m.proposalCounter
}

func (m *mockGovernanceStore) SetProposalCounter(counter *governance.Counter) error {
	m.proposalCounter = counter
	return nil
}

func (m *mockGovernanceStore) IncrementProposalCounter() (int64, error) {
	m.proposalCounter.Next()
	return m.proposalCounter.Get(), nil
}

// Config methods
func (m *mockGovernanceStore) HasConfigsStoreKey() bool {
	return m.configs != nil
}

func (m *mockGovernanceStore) GetConfig(version int64) (governance.Config, bool) {
	if m.configs == nil {
		return governance.Config{}, false
	}
	result, exists := m.configs.Get(formatInt(version))
	if !exists {
		return governance.Config{}, false
	}
	return result.(governance.Config), true
}

func (m *mockGovernanceStore) SetConfig(version int64, config governance.Config) error {
	if m.configs == nil {
		m.configs = avl.NewTree()
	}
	m.configs.Set(formatInt(version), config)
	return nil
}

func (m *mockGovernanceStore) SetConfigs(configs *avl.Tree) error {
	m.configs = configs
	return nil
}

// Proposal methods
func (m *mockGovernanceStore) HasProposalsStoreKey() bool {
	return m.proposals != nil
}

func (m *mockGovernanceStore) GetProposal(proposalID int64) (*governance.Proposal, bool) {
	if m.proposals == nil {
		return nil, false
	}
	// return m.proposals.Get(formatInt(proposalID))
	proposal, exists := m.proposals.Get(formatInt(proposalID))
	if !exists {
		return nil, false
	}
	return proposal.(*governance.Proposal), true
}

func (m *mockGovernanceStore) SetProposal(proposalID int64, proposal *governance.Proposal) error {
	if m.proposals == nil {
		m.proposals = avl.NewTree()
	}
	m.proposals.Set(formatInt(proposalID), proposal)
	return nil
}

func (m *mockGovernanceStore) SetProposals(proposals *avl.Tree) error {
	m.proposals = proposals
	return nil
}

// Proposal voting info methods
func (m *mockGovernanceStore) HasProposalUserVotingInfosStoreKey() bool {
	return m.proposalUserVotingInfos != nil
}

func (m *mockGovernanceStore) GetProposalVotingInfos(proposalID int64) (interface{}, bool) {
	if m.proposalUserVotingInfos == nil {
		return nil, false
	}
	return m.proposalUserVotingInfos.Get(formatInt(proposalID))
}

func (m *mockGovernanceStore) SetProposalVotingInfos(proposalID int64, votingInfos interface{}) error {
	if m.proposalUserVotingInfos == nil {
		m.proposalUserVotingInfos = avl.NewTree()
	}
	m.proposalUserVotingInfos.Set(formatInt(proposalID), votingInfos)
	return nil
}

func (m *mockGovernanceStore) SetProposalUserVotingInfos(votingInfos *avl.Tree) error {
	m.proposalUserVotingInfos = votingInfos
	return nil
}

// User proposals methods
func (m *mockGovernanceStore) HasUserProposalsStoreKey() bool {
	return m.userProposals != nil
}

func (m *mockGovernanceStore) GetUserProposalIDs(user string) ([]int64, bool) {
	if m.userProposals == nil {
		return nil, false
	}
	result, exists := m.userProposals.Get(user)
	if !exists {
		return nil, false
	}
	return result.([]int64), true
}

func (m *mockGovernanceStore) AddUserProposal(user string, proposalID int64) error {
	if m.userProposals == nil {
		m.userProposals = avl.NewTree()
	}

	var proposalIDs []int64
	if existing, ok := m.userProposals.Get(user); ok {
		proposalIDs = existing.([]int64)
	}
	proposalIDs = append(proposalIDs, proposalID)
	m.userProposals.Set(user, proposalIDs)
	return nil
}

func (m *mockGovernanceStore) SetUserProposals(userProposals *avl.Tree) error {
	m.userProposals = userProposals
	return nil
}

func newMockGovernance() *governanceV1 {
	store := newMockGovernanceStore()
	return &governanceV1{
		store: store,
	}
}

func newMockGovernanceStore() *mockGovernanceStore {
	return &mockGovernanceStore{
		configCounter:           governance.NewCounter(),
		proposalCounter:         governance.NewCounter(),
		configs:                 avl.NewTree(),
		proposals:               avl.NewTree(),
		proposalUserVotingInfos: avl.NewTree(),
		userProposals:           avl.NewTree(),
	}
}
