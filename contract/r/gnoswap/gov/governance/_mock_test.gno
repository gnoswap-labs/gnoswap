package governance

import (
	rotree "gno.land/p/nt/bptree/v0/rotree"
)

// MockResponse is a simple mock response helper
type MockResponse struct {
	data      map[string][]any
	callCount map[string]int
}

func NewMockResponse() *MockResponse {
	return &MockResponse{
		data:      make(map[string][]any),
		callCount: make(map[string]int),
	}
}

func (m *MockResponse) Set(key string, values ...any) {
	m.data[key] = values
}

func (m *MockResponse) Get(key string) ([]any, bool) {
	if m.callCount == nil {
		m.callCount = make(map[string]int)
	}
	m.callCount[key]++

	val, ok := m.data[key]
	return val, ok
}

func (m *MockResponse) CallCount(key string) int {
	if m.callCount == nil {
		return 0
	}
	return m.callCount[key]
}

type MockGovernance struct {
	Version  string
	Response *MockResponse
}

func (m *MockGovernance) ProposeText(_ int, rlm realm, title string, description string) int64 {
	res, ok := m.Response.Get("ProposeText")
	if !ok {
		return 0
	}
	return res[0].(int64)
}

func (m *MockGovernance) ProposeCommunityPoolSpend(
	_ int, rlm realm,
	title string,
	description string,
	to address,
	tokenPath string,
	amount int64,
) int64 {
	res, ok := m.Response.Get("ProposeCommunityPoolSpend")
	if !ok {
		return 0
	}
	return res[0].(int64)
}

func (m *MockGovernance) ProposeParameterChange(
	_ int, rlm realm,
	title string,
	description string,
	numToExecute int64,
	executions string,
) int64 {
	res, ok := m.Response.Get("ProposeParameterChange")
	if !ok {
		return 0
	}
	return res[0].(int64)
}

func (m *MockGovernance) Vote(_ int, rlm realm, proposalId int64, yes bool) string {
	res, ok := m.Response.Get("Vote")
	if !ok {
		return ""
	}
	return res[0].(string)
}

func (m *MockGovernance) Execute(_ int, rlm realm, proposalId int64) int64 {
	res, ok := m.Response.Get("Execute")
	if !ok {
		return 0
	}
	return res[0].(int64)
}

func (m *MockGovernance) Cancel(_ int, rlm realm, proposalId int64) int64 {
	res, ok := m.Response.Get("Cancel")
	if !ok {
		return 0
	}
	return res[0].(int64)
}

func (m *MockGovernance) PruneInactiveProposals(_ int, rlm realm) {
	m.Response.Get("PruneInactiveProposals")
}

func (m *MockGovernance) Reconfigure(
	_ int, rlm realm,
	votingStartDelay int64,
	votingPeriod int64,
	votingWeightSmoothingDuration int64,
	quorum int64,
	proposalCreationThreshold int64,
	executionDelay int64,
	executionWindow int64,
) int64 {
	res, ok := m.Response.Get("Reconfigure")
	if !ok {
		return 0
	}
	return res[0].(int64)
}

// Store data getters
func (m *MockGovernance) GetLatestConfigVersion() int64 {
	res, ok := m.Response.Get("GetLatestConfigVersion")
	if !ok {
		return 0
	}
	return res[0].(int64)
}

func (m *MockGovernance) GetCurrentProposalID() int64 {
	res, ok := m.Response.Get("GetCurrentProposalID")
	if !ok {
		return 0
	}
	return res[0].(int64)
}

func (m *MockGovernance) GetMaxSmoothingPeriod() int64 {
	res, ok := m.Response.Get("GetMaxSmoothingPeriod")
	if !ok {
		return 30 * 24 * 60 * 60 // default 30 days
	}
	return res[0].(int64)
}

// Config getters
func (m *MockGovernance) GetLatestConfig() (Config, error) {
	res, ok := m.Response.Get("GetLatestConfig")
	if !ok {
		return Config{}, nil
	}
	return res[0].(Config), nil
}

func (m *MockGovernance) GetConfig(configVersion int64) (Config, error) {
	res, ok := m.Response.Get("GetConfig")
	if !ok {
		return Config{}, nil
	}
	if res[1] != nil {
		return Config{}, res[1].(error)
	}
	return res[0].(Config), nil
}

func (m *MockGovernance) GetProposals() *rotree.ReadOnlyTree {
	res, ok := m.Response.Get("GetProposals")
	if !ok {
		return nil
	}
	return res[0].(*rotree.ReadOnlyTree)
}

func (m *MockGovernance) ExistsProposal(proposalID int64) bool {
	res, ok := m.Response.Get("ExistsProposal")
	if !ok {
		return false
	}
	return res[0].(bool)
}

func (m *MockGovernance) GetProposerByProposalId(id int64) (address, error) {
	res, ok := m.Response.Get("GetProposerByProposalId")
	if !ok {
		return "", nil
	}
	if res[1] != nil {
		return "", res[1].(error)
	}
	return res[0].(address), nil
}

func (m *MockGovernance) GetProposalCreatedAt(proposalId int64) (int64, error) {
	res, ok := m.Response.Get("GetProposalCreatedAt")
	if !ok {
		return 0, nil
	}
	if res[1] != nil {
		return 0, res[1].(error)
	}
	return res[0].(int64), nil
}

func (m *MockGovernance) GetProposalCreatedHeight(proposalId int64) (int64, error) {
	res, ok := m.Response.Get("GetProposalCreatedHeight")
	if !ok {
		return 0, nil
	}
	if res[1] != nil {
		return 0, res[1].(error)
	}
	return res[0].(int64), nil
}

func (m *MockGovernance) GetProposalCommunityPoolSpendInfo(proposalID int64) (*CommunityPoolSpendInfo, error) {
	res, ok := m.Response.Get("GetProposalCommunityPoolSpendInfo")
	if !ok {
		return nil, nil
	}
	if res[1] != nil {
		return nil, res[1].(error)
	}
	return res[0].(*CommunityPoolSpendInfo), nil
}

func (m *MockGovernance) GetProposalExecutionInfo(proposalID int64) (*ExecutionInfo, error) {
	res, ok := m.Response.Get("GetProposalExecutionInfo")
	if !ok {
		return nil, nil
	}
	if res[1] != nil {
		return nil, res[1].(error)
	}
	return res[0].(*ExecutionInfo), nil
}

func (m *MockGovernance) GetProposalTypeByProposalId(id int64) (ProposalType, error) {
	res, ok := m.Response.Get("GetProposalTypeByProposalId")
	if !ok {
		return ProposalType(0), nil
	}
	if res[1] != nil {
		return ProposalType(0), res[1].(error)
	}
	return res[0].(ProposalType), nil
}

func (m *MockGovernance) GetYeaByProposalId(id int64) (int64, error) {
	res, ok := m.Response.Get("GetYeaByProposalId")
	if !ok {
		return 0, nil
	}
	if res[1] != nil {
		return 0, res[1].(error)
	}
	return res[0].(int64), nil
}

func (m *MockGovernance) GetNayByProposalId(id int64) (int64, error) {
	res, ok := m.Response.Get("GetNayByProposalId")
	if !ok {
		return 0, nil
	}
	if res[1] != nil {
		return 0, res[1].(error)
	}
	return res[0].(int64), nil
}

func (m *MockGovernance) GetConfigVersionByProposalId(id int64) (int64, error) {
	res, ok := m.Response.Get("GetConfigVersionByProposalId")
	if !ok {
		return 0, nil
	}
	if res[1] != nil {
		return 0, res[1].(error)
	}
	return res[0].(int64), nil
}

func (m *MockGovernance) GetQuorumAmountByProposalId(id int64) (int64, error) {
	res, ok := m.Response.Get("GetQuorumAmountByProposalId")
	if !ok {
		return 0, nil
	}
	if res[1] != nil {
		return 0, res[1].(error)
	}
	return res[0].(int64), nil
}

func (m *MockGovernance) GetTitleByProposalId(id int64) (string, error) {
	res, ok := m.Response.Get("GetTitleByProposalId")
	if !ok {
		return "", nil
	}
	if res[1] != nil {
		return "", res[1].(error)
	}
	return res[0].(string), nil
}

func (m *MockGovernance) GetDescriptionByProposalId(id int64) (string, error) {
	res, ok := m.Response.Get("GetDescriptionByProposalId")
	if !ok {
		return "", nil
	}
	if res[1] != nil {
		return "", res[1].(error)
	}
	return res[0].(string), nil
}

func (m *MockGovernance) GetProposalStatusByProposalId(id int64) (string, error) {
	res, ok := m.Response.Get("GetProposalStatusByProposalId")
	if !ok {
		return "", nil
	}
	if res[1] != nil {
		return "", res[1].(error)
	}
	return res[0].(string), nil
}

// Vote getters
func (m *MockGovernance) GetVoteStatus(proposalId int64) (quorum, maxVotingWeight, yesWeight, noWeight int64, err error) {
	res, ok := m.Response.Get("GetVoteStatus")
	if !ok {
		return 0, 0, 0, 0, nil
	}
	if res[4] != nil {
		return 0, 0, 0, 0, res[4].(error)
	}
	return res[0].(int64), res[1].(int64), res[2].(int64), res[3].(int64), nil
}

func (m *MockGovernance) GetVotingInfos(proposalID int64) *rotree.ReadOnlyTree {
	res, ok := m.Response.Get("GetVotingInfos")
	if !ok {
		return nil
	}
	return res[0].(*rotree.ReadOnlyTree)
}

func (m *MockGovernance) ExistsVotingInfo(proposalID int64, addr address) bool {
	res, ok := m.Response.Get("ExistsVotingInfo")
	if !ok {
		return false
	}
	return res[0].(bool)
}

func (m *MockGovernance) GetVoteWeight(proposalID int64, addr address) (int64, error) {
	res, ok := m.Response.Get("GetVoteWeight")
	if !ok {
		return 0, nil
	}
	if res[1] != nil {
		return 0, res[1].(error)
	}
	return res[0].(int64), nil
}

func (m *MockGovernance) GetVotedHeight(proposalID int64, addr address) (int64, error) {
	res, ok := m.Response.Get("GetVotedHeight")
	if !ok {
		return 0, nil
	}
	if res[1] != nil {
		return 0, res[1].(error)
	}
	return res[0].(int64), nil
}

func (m *MockGovernance) GetVotedAt(proposalID int64, addr address) (int64, error) {
	res, ok := m.Response.Get("GetVotedAt")
	if !ok {
		return 0, nil
	}
	if res[1] != nil {
		return 0, res[1].(error)
	}
	return res[0].(int64), nil
}

func (m *MockGovernance) GetUserProposals() *rotree.ReadOnlyTree {
	res, ok := m.Response.Get("GetUserProposals")
	if !ok {
		return nil
	}
	return res[0].(*rotree.ReadOnlyTree)
}

// Active proposal query
func (m *MockGovernance) GetOldestActiveProposalSnapshotTime() (int64, bool) {
	res, ok := m.Response.Get("GetOldestActiveProposalSnapshotTime")
	if !ok {
		return 0, false
	}
	return res[0].(int64), res[1].(bool)
}

// Voting weight snapshot getters
func (m *MockGovernance) GetCurrentVotingWeightSnapshot() (int64, int64, error) {
	res, ok := m.Response.Get("GetCurrentVotingWeightSnapshot")
	if !ok {
		return 0, 0, nil
	}
	return res[0].(int64), res[1].(int64), nil
}

func newMockGovernance(version string) *MockGovernance {
	return &MockGovernance{
		Version:  version,
		Response: NewMockResponse(),
	}
}

type mockGovStakerAccessor struct {
	totalDelegation int64
	totalXGnsSupply int64
	userDelegations map[string]int64
}

func (m *mockGovStakerAccessor) GetTotalDelegationAmountAtSnapshot(snapshotTime int64) (int64, bool) {
	return m.totalDelegation, true
}

func (m *mockGovStakerAccessor) GetUserDelegationAmountAtSnapshot(userAddr address, snapshotTime int64) (int64, bool) {
	return m.userDelegations[userAddr.String()], true
}

func (m *mockGovStakerAccessor) GetTotalxGnsSupply() int64 {
	return m.totalXGnsSupply
}

func newMockGovStakerAccessor() *mockGovStakerAccessor {
	return &mockGovStakerAccessor{
		totalDelegation: 0,
		totalXGnsSupply: 0,
		userDelegations: make(map[string]int64),
	}
}
