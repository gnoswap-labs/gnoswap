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
	unDelegationLockupPeriod       int64
	hasUnDelegationLockupPeriodKey bool
	emissionRewardBalance          int64
	totalDelegatedAmount           int64
	totalLockedAmount              int64

	// Delegation data
	delegations      *avl.Tree // map[int64]*staker.Delegation
	delegationNextID *staker.Counter
	userDelegations  map[string]map[string][]int64

	// New delegation history structures
	totalDelegationHistory *staker.UintTree // timestamp -> int64
	userDelegationHistory  *avl.Tree        // address -> *staker.UintTree[timestamp -> int64]

	// Manager states
	emissionRewardManager    *staker.EmissionRewardManager
	protocolFeeRewardManager *staker.ProtocolFeeRewardManager
	delegationManager        *staker.DelegationManager
	launchpadProjectDeposits *staker.LaunchpadProjectDeposits
}

var _ staker.IGovStakerStore = (*mockGovStakerStore)(nil)

func newMockGovStakerStore() staker.IGovStakerStore {
	return &mockGovStakerStore{
		delegations:            avl.NewTree(),
		userDelegations:        make(map[string]map[string][]int64),
		delegationNextID:       staker.NewCounter(),
		totalDelegationHistory: staker.NewUintTree(),
		userDelegationHistory:  avl.NewTree(),
	}
}

// Basic configuration methods
func (m *mockGovStakerStore) HasUnDelegationLockupPeriodStoreKey() bool {
	return m.hasUnDelegationLockupPeriodKey
}

func (m *mockGovStakerStore) GetUnDelegationLockupPeriod() int64 {
	if !m.hasUnDelegationLockupPeriodKey {
		panic(errNotInitialized)
	}
	return m.unDelegationLockupPeriod
}

func (m *mockGovStakerStore) SetUnDelegationLockupPeriod(period int64) error {
	m.unDelegationLockupPeriod = period
	m.hasUnDelegationLockupPeriodKey = true
	return nil
}

func (m *mockGovStakerStore) HasEmissionRewardBalanceStoreKey() bool {
	return true // Always available in mock
}

func (m *mockGovStakerStore) GetEmissionRewardBalance() int64 {
	return m.emissionRewardBalance
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

func (m *mockGovStakerStore) GetAllDelegations() *avl.Tree {
	return m.delegations
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

// Total delegation history methods (timestamp -> int64)
func (m *mockGovStakerStore) HasTotalDelegationHistoryStoreKey() bool {
	return true // Always available in mock
}

func (m *mockGovStakerStore) GetTotalDelegationHistory() *staker.UintTree {
	return m.totalDelegationHistory
}

func (m *mockGovStakerStore) SetTotalDelegationHistory(history *staker.UintTree) error {
	m.totalDelegationHistory = history
	return nil
}

// User delegation history methods (address -> *UintTree[timestamp -> int64])
func (m *mockGovStakerStore) HasUserDelegationHistoryStoreKey() bool {
	return true // Always available in mock
}

func (m *mockGovStakerStore) GetUserDelegationHistory() *avl.Tree {
	return m.userDelegationHistory
}

func (m *mockGovStakerStore) SetUserDelegationHistory(history *avl.Tree) error {
	m.userDelegationHistory = history
	return nil
}

// User delegation mapping methods (legacy, kept for compatibility)
func (m *mockGovStakerStore) HasUserDelegationsStoreKey() bool {
	return true // Always available in mock
}

func (m *mockGovStakerStore) HasUserDelegations(user string) bool {
	_, exists := m.userDelegations[user]
	return exists
}

func (m *mockGovStakerStore) SetUserDelegations(delegations map[string]map[string][]int64) error {
	m.userDelegations = delegations
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

func (m *mockGovStakerStore) HasEmissionRewardManagerStoreKey() bool {
	return true // Always available in mock
}

func (m *mockGovStakerStore) GetEmissionRewardManager() *staker.EmissionRewardManager {
	if m.emissionRewardManager == nil {
		m.emissionRewardManager = staker.NewEmissionRewardManager()
	}
	return m.emissionRewardManager
}

func (m *mockGovStakerStore) SetEmissionRewardManager(manager *staker.EmissionRewardManager) error {
	m.emissionRewardManager = manager
	return nil
}

func (m *mockGovStakerStore) HasProtocolFeeRewardManagerStoreKey() bool {
	return true // Always available in mock
}

func (m *mockGovStakerStore) GetProtocolFeeRewardManager() *staker.ProtocolFeeRewardManager {
	if m.protocolFeeRewardManager == nil {
		m.protocolFeeRewardManager = staker.NewProtocolFeeRewardManager()
	}
	return m.protocolFeeRewardManager
}

func (m *mockGovStakerStore) SetProtocolFeeRewardManager(manager *staker.ProtocolFeeRewardManager) error {
	m.protocolFeeRewardManager = manager
	return nil
}

func (m *mockGovStakerStore) HasDelegationManagerStoreKey() bool {
	return true // Always available in mock
}

func (m *mockGovStakerStore) GetDelegationManager() *staker.DelegationManager {
	if m.delegationManager == nil {
		m.delegationManager = staker.NewDelegationManager()
	}
	return m.delegationManager
}

func (m *mockGovStakerStore) SetDelegationManager(manager *staker.DelegationManager) error {
	m.delegationManager = manager
	return nil
}

func (m *mockGovStakerStore) HasLaunchpadProjectDepositsStoreKey() bool {
	return true // Always available in mock
}

func (m *mockGovStakerStore) GetLaunchpadProjectDeposits() *staker.LaunchpadProjectDeposits {
	if m.launchpadProjectDeposits == nil {
		m.launchpadProjectDeposits = staker.NewLaunchpadProjectDeposits()
	}
	return m.launchpadProjectDeposits
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
	mockStore := store.(*mockGovStakerStore)
	mockStore.unDelegationLockupPeriod = 86400 // 1 day default
	mockStore.hasUnDelegationLockupPeriodKey = true
	gs := NewGovStakerV1(store).(*govStakerV1)
	return gs
}
