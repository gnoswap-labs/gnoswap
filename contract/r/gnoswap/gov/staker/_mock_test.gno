package staker

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

type MockGovStaker struct {
	Version  string
	Response *MockResponse
}

func (m *MockGovStaker) Delegate(to address, amount int64, referrer string) int64 {
	res, ok := m.Response.Get("Delegate")
	if !ok {
		return 0
	}
	return res[0].(int64)
}

func (m *MockGovStaker) Undelegate(from address, amount int64) int64 {
	res, ok := m.Response.Get("Undelegate")
	if !ok {
		return 0
	}
	return res[0].(int64)
}

func (m *MockGovStaker) Redelegate(delegatee, newDelegatee address, amount int64) int64 {
	res, ok := m.Response.Get("Redelegate")
	if !ok {
		return 0
	}
	return res[0].(int64)
}

func (m *MockGovStaker) CollectUndelegatedGns() int64 {
	res, ok := m.Response.Get("CollectUndelegatedGns")
	if !ok {
		return 0
	}
	return res[0].(int64)
}

func (m *MockGovStaker) CollectReward() {
	m.Response.Get("CollectReward")
}

func (m *MockGovStaker) CollectRewardFromLaunchPad(to address) {
	m.Response.Get("CollectRewardFromLaunchPad")
}

func (m *MockGovStaker) SetAmountByProjectWallet(addr address, amount int64, add bool) {
	m.Response.Get("SetAmountByProjectWallet")
}

func (m *MockGovStaker) GetUnDelegationLockupPeriod() int64 {
	res, ok := m.Response.Get("GetUnDelegationLockupPeriod")
	if !ok {
		return 0
	}
	return res[0].(int64)
}

func (m *MockGovStaker) GetEmissionRewardBalance() int64 {
	res, ok := m.Response.Get("GetEmissionRewardBalance")
	if !ok {
		return 0
	}
	return res[0].(int64)
}

func (m *MockGovStaker) GetTotalxGnsSupply() int64 {
	res, ok := m.Response.Get("GetTotalxGnsSupply")
	if !ok {
		return 0
	}
	return res[0].(int64)
}

func (m *MockGovStaker) GetTotalVoteWeight() int64 {
	res, ok := m.Response.Get("GetTotalVoteWeight")
	if !ok {
		return 0
	}
	return res[0].(int64)
}

func (m *MockGovStaker) GetTotalDelegated() int64 {
	res, ok := m.Response.Get("GetTotalDelegated")
	if !ok {
		return 0
	}
	return res[0].(int64)
}

func (m *MockGovStaker) GetTotalLockedAmount() int64 {
	res, ok := m.Response.Get("GetTotalLockedAmount")
	if !ok {
		return 0
	}
	return res[0].(int64)
}

func (m *MockGovStaker) GetLockedAmount() int64 {
	res, ok := m.Response.Get("GetLockedAmount")
	if !ok {
		return 0
	}
	return res[0].(int64)
}

func (m *MockGovStaker) GetDelegationCount() int {
	res, ok := m.Response.Get("GetDelegationCount")
	if !ok {
		return 0
	}
	return res[0].(int)
}

func (m *MockGovStaker) GetDelegationIDs(offset, count int) []int64 {
	res, ok := m.Response.Get("GetDelegationIDs")
	if !ok {
		return []int64{}
	}
	return res[0].([]int64)
}

func (m *MockGovStaker) ExistsDelegation(delegationID int64) bool {
	res, ok := m.Response.Get("ExistsDelegation")
	if !ok {
		return false
	}
	return res[0].(bool)
}

func (m *MockGovStaker) GetDelegation(delegationID int64) (*Delegation, error) {
	res, ok := m.Response.Get("GetDelegation")
	if !ok {
		return nil, nil
	}
	if res[1] != nil {
		return nil, res[1].(error)
	}
	return res[0].(*Delegation), nil
}

func (m *MockGovStaker) GetDelegatorDelegationCount(delegator address) int {
	res, ok := m.Response.Get("GetDelegatorDelegationCount")
	if !ok {
		return 0
	}
	return res[0].(int)
}

func (m *MockGovStaker) GetDelegatorDelegationIDs(delegator address, offset, count int) []int64 {
	res, ok := m.Response.Get("GetDelegatorDelegationIDs")
	if !ok {
		return []int64{}
	}
	return res[0].([]int64)
}

func (m *MockGovStaker) HasDelegationSnapshotsKey() bool {
	res, ok := m.Response.Get("HasDelegationSnapshotsKey")
	if !ok {
		return false
	}
	return res[0].(bool)
}

func (m *MockGovStaker) GetTotalDelegationAmountAtSnapshot(snapshotTime int64) (int64, bool) {
	res, ok := m.Response.Get("GetTotalDelegationAmountAtSnapshot")
	if !ok {
		return 0, false
	}
	return res[0].(int64), res[1].(bool)
}

func (m *MockGovStaker) GetUserDelegationAmountAtSnapshot(userAddr address, snapshotTime int64) (int64, bool) {
	res, ok := m.Response.Get("GetUserDelegationAmountAtSnapshot")
	if !ok {
		return 0, false
	}
	return res[0].(int64), res[1].(bool)
}

func (m *MockGovStaker) GetClaimableRewardByAddress(addr address) (int64, map[string]int64) {
	res, ok := m.Response.Get("GetClaimableRewardByAddress")
	if !ok {
		return 0, nil
	}
	return res[0].(int64), res[1].(map[string]int64)
}

func (m *MockGovStaker) GetClaimableRewardByLaunchpad(addr address) (int64, map[string]int64) {
	res, ok := m.Response.Get("GetClaimableRewardByLaunchpad")
	if !ok {
		return 0, nil
	}
	return res[0].(int64), res[1].(map[string]int64)
}

func (m *MockGovStaker) GetClaimableRewardByRewardID(rewardID string) (int64, map[string]int64) {
	res, ok := m.Response.Get("GetClaimableRewardByRewardID")
	if !ok {
		return 0, nil
	}
	return res[0].(int64), res[1].(map[string]int64)
}

func (m *MockGovStaker) GetLaunchpadProjectDeposit(projectAddr string) (int64, bool) {
	res, ok := m.Response.Get("GetLaunchpadProjectDeposit")
	if !ok {
		return 0, false
	}
	return res[0].(int64), res[1].(bool)
}

func (m *MockGovStaker) CleanStakerDelegationSnapshotByAdmin(snapshotTime int64) {
	m.Response.Get("CleanStakerDelegationSnapshotByAdmin")
}

func (m *MockGovStaker) SetUnDelegationLockupPeriodByAdmin(period int64) {
	m.Response.Get("SetUnDelegationLockupPeriodByAdmin")
}

func newMockGovStaker(version string) *MockGovStaker {
	return &MockGovStaker{
		Version:  version,
		Response: NewMockResponse(),
	}
}
