package v1

import (
	"errors"
	"strconv"

	"gno.land/p/nt/avl"

	"gno.land/r/gnoswap/gov/staker"
)

// mockGovStakerStore is a mock implementation of IGovStakerStore for testing
type mockGovStakerStore struct {
	// Basic configuration
	unDelegationLockupPeriod int64
	emissionRewardBalance    int64
	totalDelegatedAmount     int64
	totalLockedAmount        int64
	
	// Delegation data
	delegations      *avl.Tree // map[int64]*staker.Delegation
	delegationNextID *staker.Counter
	delegationHistory []*staker.DelegationRecord
	userDelegations   map[string]map[string][]int64
	
	// Snapshots
	delegationSnapshots *avl.Tree // map[int64]staker.DelegationSnapshot

	// Manager states
	emissionRewardManager *staker.EmissionRewardManager
	protocolFeeRewardManager *staker.ProtocolFeeRewardManager
	delegationManager *staker.DelegationManager
	launchpadProjectDeposits *staker.LaunchpadProjectDeposits
}

var _ staker.IGovStakerStore = (*mockGovStakerStore)(nil)

func newMockGovStakerStore() staker.IGovStakerStore {
	return &mockGovStakerStore{
		delegations:         avl.NewTree(),
		delegationSnapshots: avl.NewTree(),
		userDelegations:     make(map[string]map[string][]int64),
		delegationHistory:   make([]*staker.DelegationRecord, 0),
		delegationNextID:    staker.NewCounter(),
	}
}

// Basic configuration methods
func (m *mockGovStakerStore) HasUnDelegationLockupPeriodStoreKey() bool {
	return m.unDelegationLockupPeriod != 0
}

func (m *mockGovStakerStore) GetUnDelegationLockupPeriod() (int64, error) {
	if m.unDelegationLockupPeriod == 0 {
		return 0, errNotInitialized
	}
	return m.unDelegationLockupPeriod, nil
}

func (m *mockGovStakerStore) SetUnDelegationLockupPeriod(period int64) error {
	m.unDelegationLockupPeriod = period
	return nil
}

func (m *mockGovStakerStore) HasEmissionRewardBalanceStoreKey() bool {
	return true // Always available in mock
}

func (m *mockGovStakerStore) GetEmissionRewardBalance() (int64, error) {
	return m.emissionRewardBalance, nil
}

func (m *mockGovStakerStore) SetEmissionRewardBalance(balance int64) error {
	m.emissionRewardBalance = balance
	return nil
}

func (m *mockGovStakerStore) HasTotalDelegatedAmountStoreKey() bool {
	return true // Always available in mock
}

func (m *mockGovStakerStore) GetTotalDelegatedAmount() int64 {
	return m.totalDelegatedAmount
}

func (m *mockGovStakerStore) SetTotalDelegatedAmount(amount int64) error {
	m.totalDelegatedAmount = amount
	return nil
}

func (m *mockGovStakerStore) HasTotalLockedAmountStoreKey() bool {
	return true // Always available in mock
}

func (m *mockGovStakerStore) GetTotalLockedAmount() int64 {
	return m.totalLockedAmount
}

func (m *mockGovStakerStore) SetTotalLockedAmount(amount int64) error {
	m.totalLockedAmount = amount
	return nil
}

// Delegation management methods
func (m *mockGovStakerStore) HasDelegationsStoreKey() bool {
	return true // Always available in mock
}

func (m *mockGovStakerStore) SetDelegations(delegations *avl.Tree) error {
	m.delegations = delegations
	return nil
}

func (m *mockGovStakerStore) HasDelegation(id int64) bool {
	_, exists := m.delegations.Get(uint64ToString(uint64(id)))
	return exists
}

func (m *mockGovStakerStore) GetDelegation(id int64) (*staker.Delegation, bool) {
	value, exists := m.delegations.Get(uint64ToString(uint64(id)))
	if !exists {
		return nil, false
	}
	return value.(*staker.Delegation), true
}

func (m *mockGovStakerStore) SetDelegation(id int64, delegation *staker.Delegation) error {
	m.delegations.Set(uint64ToString(uint64(id)), delegation)
	return nil
}

func (m *mockGovStakerStore) RemoveDelegation(id int64) error {
	_, _ = m.delegations.Remove(uint64ToString(uint64(id)))
	return nil
}

func (m *mockGovStakerStore) GetAllDelegations() (*avl.Tree, error) {
	return m.delegations, nil
}

func (m *mockGovStakerStore) HasDelegationCounterStoreKey() bool {
	return true // Always available in mock
}

func (m *mockGovStakerStore) GetDelegationCounter() *staker.Counter {
	return m.delegationNextID
}

func (m *mockGovStakerStore) SetDelegationCounter(counter *staker.Counter) error {
	m.delegationNextID = counter
	return nil
}

// Delegation history methods
func (m *mockGovStakerStore) HasDelegationHistoryStoreKey() bool {
	return true // Always available in mock
}

func (m *mockGovStakerStore) AddDelegationRecord(record *staker.DelegationRecord) error {
	m.delegationHistory = append(m.delegationHistory, record)
	return nil
}

func (m *mockGovStakerStore) GetDelegationHistory() ([]*staker.DelegationRecord, error) {
	return m.delegationHistory, nil
}

func (m *mockGovStakerStore) SetDelegationHistory(history []*staker.DelegationRecord) error {
	m.delegationHistory = history
	return nil
}

// User delegation mapping methods
func (m *mockGovStakerStore) HasUserDelegationsStoreKey() bool {
	return true // Always available in mock
}

func (m *mockGovStakerStore) HasUserDelegations(user string) bool {
	_, exists := m.userDelegations[user]
	return exists
}

func (m *mockGovStakerStore) SetUserDelegations(user string, delegations map[string][]int64) error {
	m.userDelegations[user] = delegations
	return nil
}

func (m *mockGovStakerStore) GetUserDelegations(user string) (map[string][]int64, error) {
	if delegations, exists := m.userDelegations[user]; exists {
		return delegations, nil
	}
	return make(map[string][]int64), nil
}

func (m *mockGovStakerStore) AddUserDelegation(from, to string, delegationID int64) error {
	if _, exists := m.userDelegations[from]; !exists {
		m.userDelegations[from] = make(map[string][]int64)
	}
	m.userDelegations[from][to] = append(m.userDelegations[from][to], delegationID)
	return nil
}

func (m *mockGovStakerStore) RemoveUserDelegation(from, to string, delegationID int64) error {
	if delegations, exists := m.userDelegations[from]; exists {
		if ids, exists := delegations[to]; exists {
			// Remove the delegationID from the slice
			for i, id := range ids {
				if id == delegationID {
					delegations[to] = append(ids[:i], ids[i+1:]...)
					break
				}
			}
		}
	}
	return nil
}

// Delegation snapshot methods
func (m *mockGovStakerStore) HasDelegationSnapshotsStoreKey() bool {
	return true // Always available in mock
}

func (m *mockGovStakerStore) HasDelegationSnapshot(timestamp int64) bool {
	_, exists := m.delegationSnapshots.Get(uint64ToString(uint64(timestamp)))
	return exists
}

func (m *mockGovStakerStore) SetDelegationSnapshot(timestamp int64, snapshot staker.DelegationSnapshot) error {
	m.delegationSnapshots.Set(uint64ToString(uint64(timestamp)), snapshot)
	return nil
}

func (m *mockGovStakerStore) GetDelegationSnapshot(timestamp int64) (staker.DelegationSnapshot, bool) {
	value, exists := m.delegationSnapshots.Get(uint64ToString(uint64(timestamp)))
	if !exists {
		return nil, false
	}
	return value.(staker.DelegationSnapshot), true
}

func (m *mockGovStakerStore) SetAllDelegationSnapshots(snapshots *avl.Tree) error {
	m.delegationSnapshots = snapshots
	return nil
}

func (m *mockGovStakerStore) GetAllDelegationSnapshots() (*avl.Tree, error) {
	return m.delegationSnapshots, nil
}

func (m *mockGovStakerStore) HasEmissionRewardManagerStoreKey() bool {
	return true // Always available in mock
}

func (m *mockGovStakerStore) GetEmissionRewardManager() (*staker.EmissionRewardManager, error) {
	if m.emissionRewardManager == nil {
		m.emissionRewardManager = staker.NewEmissionRewardManager()
	}
	return m.emissionRewardManager, nil
}

func (m *mockGovStakerStore) SetEmissionRewardManager(manager *staker.EmissionRewardManager) error {
	m.emissionRewardManager = manager
	return nil
}

func (m *mockGovStakerStore) HasProtocolFeeRewardManagerStoreKey() bool {
	return true // Always available in mock
}

func (m *mockGovStakerStore) GetProtocolFeeRewardManager() (*staker.ProtocolFeeRewardManager, error) {
	if m.protocolFeeRewardManager == nil {
		m.protocolFeeRewardManager = staker.NewProtocolFeeRewardManager()
	}
	return m.protocolFeeRewardManager, nil
}

func (m *mockGovStakerStore) SetProtocolFeeRewardManager(manager *staker.ProtocolFeeRewardManager) error {
	m.protocolFeeRewardManager = manager
	return nil
}

func (m *mockGovStakerStore) HasDelegationManagerStoreKey() bool {
	return true // Always available in mock
}

func (m *mockGovStakerStore) GetDelegationManager() (*staker.DelegationManager, error) {
	if m.delegationManager == nil {
		m.delegationManager = staker.NewDelegationManager()
	}
	return m.delegationManager, nil
}

func (m *mockGovStakerStore) SetDelegationManager(manager *staker.DelegationManager) error {
	m.delegationManager = manager
	return nil
}

func (m *mockGovStakerStore) HasLaunchpadProjectDepositsStoreKey() bool {
	return true // Always available in mock
}

func (m *mockGovStakerStore) GetLaunchpadProjectDeposits() (*staker.LaunchpadProjectDeposits, error) {
	if m.launchpadProjectDeposits == nil {
		m.launchpadProjectDeposits = staker.NewLaunchpadProjectDeposits()
	}
	return m.launchpadProjectDeposits, nil
}

func (m *mockGovStakerStore) SetLaunchpadProjectDeposits(deposits *staker.LaunchpadProjectDeposits) error {
	m.launchpadProjectDeposits = deposits
	return nil
}

var errNotInitialized = errors.New("not initialized")

// uint64ToString converts uint64 to string
func uint64ToString(n uint64) string {
	return strconv.FormatUint(n, 10)
}

// createTestGovStaker creates a govStakerV1 instance for testing
func createTestGovStaker() *govStakerV1 {
	store := newMockGovStakerStore()
	// Initialize required values
	store.(*mockGovStakerStore).unDelegationLockupPeriod = 86400 // 1 day default
	gs := NewGovStakerV1(store).(*govStakerV1)
	return gs
}
