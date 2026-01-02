package v1

import (
	"gno.land/p/nt/avl"
	"gno.land/r/gnoswap/gov/governance"
)

type mockGovernanceStore struct {
	configCounter             *governance.Counter
	proposalCounter           *governance.Counter
	config                    governance.Config
	configs                   *avl.Tree
	proposals                 *avl.Tree
	proposalUserVotingInfos   *avl.Tree
	userProposals             *avl.Tree
	setProposalVotingInfoErr error
}

// Counter methods
func (m *mockGovernanceStore) HasConfigCounterStoreKey() bool {
	return m.configCounter != nil
}

func (m *mockGovernanceStore) GetConfigCounter() *governance.Counter {
	return m.configCounter
}

func (m *mockGovernanceStore) SetConfigCounter(counter *governance.Counter) error {
	m.configCounter = counter
	return nil
}

func (m *mockGovernanceStore) HasProposalCounterStoreKey() bool {
	return m.proposalCounter != nil
}

func (m *mockGovernanceStore) GetProposalCounter() *governance.Counter {
	return m.proposalCounter
}

func (m *mockGovernanceStore) SetProposalCounter(counter *governance.Counter) error {
	m.proposalCounter = counter
	return nil
}

// Config methods
func (m *mockGovernanceStore) HasConfigsStoreKey() bool {
	return m.configs != nil
}

func (m *mockGovernanceStore) SetConfigs(configs *avl.Tree) error {
	m.configs = configs
	return nil
}

func (m *mockGovernanceStore) GetConfig(version int64) (governance.Config, bool) {
	if m.configs == nil {
		return governance.Config{}, false
	}
	result, exists := m.configs.Get(governance.FormatInt64Key(version))
	if !exists {
		return governance.Config{}, false
	}
	return result.(governance.Config), true
}

func (m *mockGovernanceStore) SetConfig(version int64, config governance.Config) error {
	if m.configs == nil {
		m.configs = avl.NewTree()
	}
	m.configs.Set(governance.FormatInt64Key(version), config)
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
	proposal, exists := m.proposals.Get(governance.FormatInt64Key(proposalID))
	if !exists {
		return nil, false
	}
	return proposal.(*governance.Proposal), true
}

func (m *mockGovernanceStore) SetProposal(proposalID int64, proposal *governance.Proposal) error {
	if m.proposals == nil {
		m.proposals = avl.NewTree()
	}
	m.proposals.Set(governance.FormatInt64Key(proposalID), proposal)
	return nil
}

func (m *mockGovernanceStore) SetProposals(proposals *avl.Tree) error {
	m.proposals = proposals
	return nil
}

// Proposal voting info methods
func (m *mockGovernanceStore) GetProposalUserVotingInfos() *avl.Tree {
	return m.proposalUserVotingInfos
}

func (m *mockGovernanceStore) GetProposalVotingInfo(proposalID int64, voter string) (*governance.VotingInfo, bool) {
	if m.proposalUserVotingInfos == nil {
		return nil, false
	}
	result, exists := m.proposalUserVotingInfos.Get(governance.FormatProposalVotingInfoKey(proposalID, voter))
	if !exists {
		return nil, false
	}

	votingInfo, ok := result.(*governance.VotingInfo)
	if !ok {
		return nil, false
	}

	return votingInfo, true
}

func (m *mockGovernanceStore) SetProposalVotingInfo(proposalID int64, voter string, votingInfo *governance.VotingInfo) error {
	if m.setProposalVotingInfoErr != nil {
		return m.setProposalVotingInfoErr
	}
	if m.proposalUserVotingInfos == nil {
		m.proposalUserVotingInfos = avl.NewTree()
	}
	m.proposalUserVotingInfos.Set(governance.FormatProposalVotingInfoKey(proposalID, voter), votingInfo)
	return nil
}

func (m *mockGovernanceStore) HasProposalUserVotingInfosStoreKey() bool {
	return m.proposalUserVotingInfos != nil
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

func (m *mockGovernanceStore) RemoveUserProposal(user string, proposalID int64) error {
	if m.userProposals == nil {
		return nil
	}

	proposalIDsRaw, ok := m.userProposals.Get(user)
	if !ok {
		return nil
	}

	proposalIDs, ok := proposalIDsRaw.([]int64)
	newProposalIDs := make([]int64, 0)

	for _, id := range proposalIDs {
		if id == proposalID {
			continue
		}

		newProposalIDs = append(newProposalIDs, id)
	}

	if len(newProposalIDs) == 0 {
		m.userProposals.Remove(user)
	} else {
		m.userProposals.Set(user, newProposalIDs)
	}

	return nil
}

func (m *mockGovernanceStore) SetUserProposals(userProposals *avl.Tree) error {
	m.userProposals = userProposals
	return nil
}

func newMockGovernance() *governanceV1 {
	store := newMockGovernanceStore()
	return &governanceV1{
		store:          store,
		stakerAccessor: newMockGovStakerAccessor(),
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

// mockGovStakerAccessor provides a mock implementation of GovStakerAccessor for testing.
type mockGovStakerAccessor struct {
	totalDelegation int64
	userDelegations map[string]int64
}

func (m *mockGovStakerAccessor) GetTotalDelegationAmountAtSnapshot(snapshotTime int64) (int64, bool) {
	if m.totalDelegation <= 0 {
		return 0, false
	}
	return m.totalDelegation, true
}

func (m *mockGovStakerAccessor) GetUserDelegationAmountAtSnapshot(userAddr address, snapshotTime int64) (int64, bool) {
	if m.userDelegations == nil {
		return 0, false
	}
	amount, exists := m.userDelegations[userAddr.String()]
	if !exists || amount <= 0 {
		return 0, false
	}
	return amount, true
}

// SetTotalDelegation sets the total delegation amount for the mock
func (m *mockGovStakerAccessor) SetTotalDelegation(amount int64) {
	m.totalDelegation = amount
}

// SetUserDelegation sets the delegation amount for a specific user
func (m *mockGovStakerAccessor) SetUserDelegation(userAddr address, amount int64) {
	if m.userDelegations == nil {
		m.userDelegations = make(map[string]int64)
	}
	m.userDelegations[userAddr.String()] = amount
}

func newMockGovStakerAccessor() *mockGovStakerAccessor {
	return &mockGovStakerAccessor{
		totalDelegation: 0,
		userDelegations: make(map[string]int64),
	}
}
