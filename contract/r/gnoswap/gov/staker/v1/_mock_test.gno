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
	delegationNextID int64
	delegationHistory []*staker.DelegationRecord
	userDelegations   map[string]map[string][]int64
	
	// Snapshots
	delegationSnapshots *avl.Tree // map[int64]staker.DelegationSnapshot
}

func newMockGovStakerStore() staker.IGovStakerStore {
	return &mockGovStakerStore{
		delegations:         avl.NewTree(),
		delegationSnapshots: avl.NewTree(),
		userDelegations:     make(map[string]map[string][]int64),
		delegationHistory:   make([]*staker.DelegationRecord, 0),
		delegationNextID:    1,
	}
}

// Basic configuration methods
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

func (m *mockGovStakerStore) GetEmissionRewardBalance() (int64, error) {
	return m.emissionRewardBalance, nil
}

func (m *mockGovStakerStore) SetEmissionRewardBalance(balance int64) error {
	m.emissionRewardBalance = balance
	return nil
}

func (m *mockGovStakerStore) GetTotalDelegatedAmount() int64 {
	return m.totalDelegatedAmount
}

func (m *mockGovStakerStore) SetTotalDelegatedAmount(amount int64) error {
	m.totalDelegatedAmount = amount
	return nil
}

func (m *mockGovStakerStore) GetTotalLockedAmount() int64 {
	return m.totalLockedAmount
}

func (m *mockGovStakerStore) SetTotalLockedAmount(amount int64) error {
	m.totalLockedAmount = amount
	return nil
}

// Delegation management methods
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

func (m *mockGovStakerStore) GetDelegationNextID() (int64, error) {
	return m.delegationNextID, nil
}

func (m *mockGovStakerStore) SetDelegationNextID(nextID int64) error {
	m.delegationNextID = nextID
	return nil
}

func (m *mockGovStakerStore) IncrementDelegationNextID() (int64, error) {
	m.delegationNextID++
	return m.delegationNextID, nil
}

// Delegation history methods
func (m *mockGovStakerStore) AddDelegationRecord(record *staker.DelegationRecord) error {
	m.delegationHistory = append(m.delegationHistory, record)
	return nil
}

func (m *mockGovStakerStore) GetDelegationHistory() ([]*staker.DelegationRecord, error) {
	return m.delegationHistory, nil
}

// User delegation mapping methods
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

func (m *mockGovStakerStore) GetAllDelegationSnapshots() (*avl.Tree, error) {
	return m.delegationSnapshots, nil
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
