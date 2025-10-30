package governance

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

func (m *MockGovernance) ProposeText(title string, description string) int64 {
	res, ok := m.Response.Get("ProposeText")
	if !ok {
		return 0
	}
	return res[0].(int64)
}

func (m *MockGovernance) ProposeCommunityPoolSpend(
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

func (m *MockGovernance) Vote(proposalId int64, yes bool) string {
	res, ok := m.Response.Get("Vote")
	if !ok {
		return ""
	}
	return res[0].(string)
}

func (m *MockGovernance) Execute(proposalId int64) int64 {
	res, ok := m.Response.Get("Execute")
	if !ok {
		return 0
	}
	return res[0].(int64)
}

func (m *MockGovernance) Cancel(proposalId int64) int64 {
	res, ok := m.Response.Get("Cancel")
	if !ok {
		return 0
	}
	return res[0].(int64)
}

func (m *MockGovernance) Reconfigure(
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

// Getter methods
func (m *MockGovernance) GetProposerByProposalId(id int64) string {
	res, ok := m.Response.Get("GetProposerByProposalId")
	if !ok {
		return ""
	}
	return res[0].(string)
}

func (m *MockGovernance) GetProposalTypeByProposalId(id int64) string {
	res, ok := m.Response.Get("GetProposalTypeByProposalId")
	if !ok {
		return ""
	}
	return res[0].(string)
}

func (m *MockGovernance) GetYeaByProposalId(id int64) int64 {
	res, ok := m.Response.Get("GetYeaByProposalId")
	if !ok {
		return 0
	}
	return res[0].(int64)
}

func (m *MockGovernance) GetNayByProposalId(id int64) int64 {
	res, ok := m.Response.Get("GetNayByProposalId")
	if !ok {
		return 0
	}
	return res[0].(int64)
}

func (m *MockGovernance) GetProposalById(id int64) string {
	res, ok := m.Response.Get("GetProposalById")
	if !ok {
		return ""
	}
	return res[0].(string)
}

func (m *MockGovernance) GetVoteStatusFromProposalById(id int64) string {
	res, ok := m.Response.Get("GetVoteStatusFromProposalById")
	if !ok {
		return ""
	}
	return res[0].(string)
}

func (m *MockGovernance) GetVoteByAddressFromProposalById(addr address, id int64) string {
	res, ok := m.Response.Get("GetVoteByAddressFromProposalById")
	if !ok {
		return ""
	}
	return res[0].(string)
}

func (m *MockGovernance) GetConfigVersionByProposalId(id int64) int64 {
	res, ok := m.Response.Get("GetConfigVersionByProposalId")
	if !ok {
		return 0
	}
	return res[0].(int64)
}

func (m *MockGovernance) GetQuorumAmountByProposalId(id int64) int64 {
	res, ok := m.Response.Get("GetQuorumAmountByProposalId")
	if !ok {
		return 0
	}
	return res[0].(int64)
}

func (m *MockGovernance) GetTitleByProposalId(id int64) string {
	res, ok := m.Response.Get("GetTitleByProposalId")
	if !ok {
		return ""
	}
	return res[0].(string)
}

func (m *MockGovernance) GetDescriptionByProposalId(id int64) string {
	res, ok := m.Response.Get("GetDescriptionByProposalId")
	if !ok {
		return ""
	}
	return res[0].(string)
}

func (m *MockGovernance) GetExecutionStateByProposalId(id int64) string {
	res, ok := m.Response.Get("GetExecutionStateByProposalId")
	if !ok {
		return ""
	}
	return res[0].(string)
}

func (m *MockGovernance) GetLatestConfig() Config {
	res, ok := m.Response.Get("GetLatestConfig")
	if !ok {
		return Config{}
	}
	return res[0].(Config)
}

func (m *MockGovernance) GetConfig(configVersion int64) Config {
	res, ok := m.Response.Get("GetConfig")
	if !ok {
		return Config{}
	}
	return res[0].(Config)
}

func (m *MockGovernance) GetVoteWeight(proposalID int64, address address) int64 {
	res, ok := m.Response.Get("GetVoteWeight")
	if !ok {
		return 0
	}
	return res[0].(int64)
}

func (m *MockGovernance) GetVotedHeight(proposalID int64, address address) int64 {
	res, ok := m.Response.Get("GetVotedHeight")
	if !ok {
		return 0
	}
	return res[0].(int64)
}

func (m *MockGovernance) GetVotedAt(proposalID int64, address address) int64 {
	res, ok := m.Response.Get("GetVotedAt")
	if !ok {
		return 0
	}
	return res[0].(int64)
}

func newMockGovernance(version string) *MockGovernance {
	return &MockGovernance{
		Version:  version,
		Response: NewMockResponse(),
	}
}
