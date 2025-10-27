package staker

import (
	"errors"
	"strconv"

	"gno.land/p/gnoswap/store"
	"gno.land/p/nt/avl"
	"gno.land/p/nt/ufmt"
)

// Storage key constants
const (
	// Basic configuration
	StoreKeyUnDelegationLockupPeriod = "unDelegationLockupPeriod"
	StoreKeyEmissionRewardBalance    = "emissionRewardBalance"
	StoreKeyTotalDelegatedAmount     = "totalDelegatedAmount"
	StoreKeyTotalLockedAmount        = "totalLockedAmount"

	// Counters
	StoreKeyDelegationNextID = "delegationNextID"

	// Complex data structures
	StoreKeyDelegations         = "delegations"         // AVL tree of delegations
	StoreKeyDelegationHistory   = "delegationHistory"   // List of delegation records
	StoreKeyDelegationSnapshots = "delegationSnapshots" // AVL tree of snapshots by timestamp
	StoreKeyUserDelegations     = "userDelegations"     // Nested maps of user delegations
)

// govStakerStore is the concrete implementation of IGovStakerStore
type govStakerStore struct {
	kvStore store.KVStore
}

var _ IGovStakerStore = (*govStakerStore)(nil)

// NewGovStakerStore creates a new governance staker store instance
func NewGovStakerStore(kvStore store.KVStore) IGovStakerStore {
	return &govStakerStore{
		kvStore: kvStore,
	}
}

// Basic configuration methods
func (s *govStakerStore) HasUnDelegationLockupPeriodStoreKey() bool {
	_, err := s.kvStore.Get(StoreKeyUnDelegationLockupPeriod)
	return err == nil
}

func (s *govStakerStore) GetUnDelegationLockupPeriod() (int64, error) {
	result, err := s.kvStore.Get(StoreKeyUnDelegationLockupPeriod)
	if err != nil {
		// Return default value if not initialized
		return 300, nil // 5 minutes default
	}

	period, ok := result.(int64)
	if !ok {
		return 0, errors.New(ufmt.Sprintf("failed to cast result to int64: %T", result))
	}

	return period, nil
}

func (s *govStakerStore) SetUnDelegationLockupPeriod(period int64) error {
	return s.kvStore.Set(StoreKeyUnDelegationLockupPeriod, period)
}

func (s *govStakerStore) HasEmissionRewardBalanceStoreKey() bool {
	_, err := s.kvStore.Get(StoreKeyEmissionRewardBalance)
	return err == nil
}

func (s *govStakerStore) GetEmissionRewardBalance() (int64, error) {
	result, err := s.kvStore.Get(StoreKeyEmissionRewardBalance)
	if err != nil {
		// Return 0 if not initialized
		return 0, nil
	}

	balance, ok := result.(int64)
	if !ok {
		return 0, errors.New(ufmt.Sprintf("failed to cast result to int64: %T", result))
	}

	return balance, nil
}

func (s *govStakerStore) SetEmissionRewardBalance(balance int64) error {
	return s.kvStore.Set(StoreKeyEmissionRewardBalance, balance)
}

func (s *govStakerStore) HasTotalDelegatedAmountStoreKey() bool {
	_, err := s.kvStore.Get(StoreKeyTotalDelegatedAmount)
	return err == nil
}

func (s *govStakerStore) GetTotalDelegatedAmount() int64 {
	result, err := s.kvStore.Get(StoreKeyTotalDelegatedAmount)
	if err != nil {
		// Return 0 if key doesn't exist (initial state)
		return 0
	}

	amount, ok := result.(int64)
	if !ok {
		panic(ufmt.Sprintf("failed to cast result to int64: %T", result))
	}

	return amount
}

func (s *govStakerStore) SetTotalDelegatedAmount(amount int64) error {
	return s.kvStore.Set(StoreKeyTotalDelegatedAmount, amount)
}

func (s *govStakerStore) HasTotalLockedAmountStoreKey() bool {
	_, err := s.kvStore.Get(StoreKeyTotalLockedAmount)
	return err == nil
}

func (s *govStakerStore) GetTotalLockedAmount() int64 {
	result, err := s.kvStore.Get(StoreKeyTotalLockedAmount)
	if err != nil {
		// Return 0 if key doesn't exist (initial state)
		return 0
	}

	amount, ok := result.(int64)
	if !ok {
		panic(ufmt.Sprintf("failed to cast result to int64: %T", result))
	}

	return amount
}

func (s *govStakerStore) SetTotalLockedAmount(amount int64) error {
	return s.kvStore.Set(StoreKeyTotalLockedAmount, amount)
}

// Delegation management methods
func (s *govStakerStore) HasDelegationsStoreKey() bool {
	_, err := s.kvStore.Get(StoreKeyDelegations)
	return err == nil
}

func (s *govStakerStore) HasDelegation(id int64) bool {
	delegations, err := s.getAllDelegations()
	if err != nil {
		return false
	}
	_, exists := delegations.Get(int64ToString(id))
	return exists
}

func (s *govStakerStore) GetDelegation(id int64) (*Delegation, bool) {
	delegations, err := s.getAllDelegations()
	if err != nil {
		return nil, false
	}

	result, exists := delegations.Get(int64ToString(id))
	if !exists {
		return nil, false
	}

	delegation, ok := result.(*Delegation)
	if !ok {
		panic(ufmt.Sprintf("failed to cast result to *Delegation: %T", result))
	}

	return delegation, true
}

func (s *govStakerStore) SetDelegation(id int64, delegation *Delegation) error {
	delegations, err := s.getAllDelegations()
	if err != nil {
		return err
	}

	delegations.Set(int64ToString(id), delegation)
	return s.kvStore.Set(StoreKeyDelegations, delegations)
}

func (s *govStakerStore) RemoveDelegation(id int64) error {
	delegations, err := s.getAllDelegations()
	if err != nil {
		return err
	}

	delegations.Remove(int64ToString(id))
	return s.kvStore.Set(StoreKeyDelegations, delegations)
}

func (s *govStakerStore) GetAllDelegations() (*avl.Tree, error) {
	return s.getAllDelegations()
}

func (s *govStakerStore) getAllDelegations() (*avl.Tree, error) {
	result, err := s.kvStore.Get(StoreKeyDelegations)
	if err != nil {
		// If key doesn't exist, return empty tree
		return avl.NewTree(), nil
	}

	delegations, ok := result.(*avl.Tree)
	if !ok {
		return nil, errors.New(ufmt.Sprintf("failed to cast result to *avl.Tree: %T", result))
	}

	return delegations, nil
}

func (s *govStakerStore) HasDelegationNextIDStoreKey() bool {
	_, err := s.kvStore.Get(StoreKeyDelegationNextID)
	return err == nil
}

func (s *govStakerStore) GetDelegationNextID() (int64, error) {
	result, err := s.kvStore.Get(StoreKeyDelegationNextID)
	if err != nil {
		// Return 1 if not initialized (starting ID)
		return 1, nil
	}

	nextID, ok := result.(int64)
	if !ok {
		return 0, errors.New(ufmt.Sprintf("failed to cast result to int64: %T", result))
	}

	return nextID, nil
}

func (s *govStakerStore) SetDelegationNextID(nextID int64) error {
	return s.kvStore.Set(StoreKeyDelegationNextID, nextID)
}

func (s *govStakerStore) IncrementDelegationNextID() (int64, error) {
	nextID, err := s.GetDelegationNextID()
	if err != nil {
		return 0, err
	}

	nextID++
	err = s.SetDelegationNextID(nextID)
	if err != nil {
		return 0, err
	}

	return nextID, nil
}

// Delegation history methods
func (s *govStakerStore) HasDelegationHistoryStoreKey() bool {
	_, err := s.kvStore.Get(StoreKeyDelegationHistory)
	return err == nil
}

func (s *govStakerStore) AddDelegationRecord(record *DelegationRecord) error {
	history, err := s.GetDelegationHistory()
	if err != nil {
		return err
	}

	history = append(history, record)
	return s.kvStore.Set(StoreKeyDelegationHistory, history)
}

func (s *govStakerStore) GetDelegationHistory() ([]*DelegationRecord, error) {
	result, err := s.kvStore.Get(StoreKeyDelegationHistory)
	if err != nil {
		// If key doesn't exist, return empty slice
		return make([]*DelegationRecord, 0), nil
	}

	history, ok := result.([]*DelegationRecord)
	if !ok {
		return nil, errors.New(ufmt.Sprintf("failed to cast result to []*DelegationRecord: %T", result))
	}

	return history, nil
}

// User delegation mapping methods
func (s *govStakerStore) HasUserDelegationsStoreKey() bool {
	_, err := s.kvStore.Get(StoreKeyUserDelegations)
	return err == nil
}

func (s *govStakerStore) HasUserDelegations(user string) bool {
	allUserDelegations, err := s.getAllUserDelegations()
	if err != nil {
		return false
	}
	_, exists := allUserDelegations[user]
	return exists
}

func (s *govStakerStore) GetUserDelegations(user string) (map[string][]int64, error) {
	allUserDelegations, err := s.getAllUserDelegations()
	if err != nil {
		return nil, err
	}

	if delegations, exists := allUserDelegations[user]; exists {
		return delegations, nil
	}

	return make(map[string][]int64), nil
}

func (s *govStakerStore) AddUserDelegation(from, to string, delegationID int64) error {
	allUserDelegations, err := s.getAllUserDelegations()
	if err != nil {
		return err
	}

	if _, exists := allUserDelegations[from]; !exists {
		allUserDelegations[from] = make(map[string][]int64)
	}

	allUserDelegations[from][to] = append(allUserDelegations[from][to], delegationID)

	return s.kvStore.Set(StoreKeyUserDelegations, allUserDelegations)
}

func (s *govStakerStore) RemoveUserDelegation(from, to string, delegationID int64) error {
	allUserDelegations, err := s.getAllUserDelegations()
	if err != nil {
		return err
	}

	if delegations, exists := allUserDelegations[from]; exists {
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

	return s.kvStore.Set(StoreKeyUserDelegations, allUserDelegations)
}

func (s *govStakerStore) getAllUserDelegations() (map[string]map[string][]int64, error) {
	result, err := s.kvStore.Get(StoreKeyUserDelegations)
	if err != nil {
		// If key doesn't exist, return empty map
		return make(map[string]map[string][]int64), nil
	}

	userDelegations, ok := result.(map[string]map[string][]int64)
	if !ok {
		return nil, errors.New(ufmt.Sprintf("failed to cast result to map[string]map[string][]int64: %T", result))
	}

	return userDelegations, nil
}

// Delegation snapshot methods
func (s *govStakerStore) HasDelegationSnapshotsStoreKey() bool {
	_, err := s.kvStore.Get(StoreKeyDelegationSnapshots)
	return err == nil
}

func (s *govStakerStore) HasDelegationSnapshot(timestamp int64) bool {
	snapshots, err := s.getAllDelegationSnapshots()
	if err != nil {
		return false
	}
	_, exists := snapshots.Get(int64ToString(timestamp))
	return exists
}

func (s *govStakerStore) SetDelegationSnapshot(timestamp int64, snapshot DelegationSnapshot) error {
	snapshots, err := s.getAllDelegationSnapshots()
	if err != nil {
		return err
	}

	snapshots.Set(int64ToString(timestamp), snapshot)
	return s.kvStore.Set(StoreKeyDelegationSnapshots, snapshots)
}

func (s *govStakerStore) GetDelegationSnapshot(timestamp int64) (DelegationSnapshot, bool) {
	snapshots, err := s.getAllDelegationSnapshots()
	if err != nil {
		return nil, false
	}

	result, exists := snapshots.Get(int64ToString(timestamp))
	if !exists {
		return nil, false
	}

	snapshot, ok := result.(DelegationSnapshot)
	if !ok {
		panic(ufmt.Sprintf("failed to cast result to DelegationSnapshot: %T", result))
	}

	return snapshot, true
}

func (s *govStakerStore) GetAllDelegationSnapshots() (*avl.Tree, error) {
	return s.getAllDelegationSnapshots()
}

func (s *govStakerStore) getAllDelegationSnapshots() (*avl.Tree, error) {
	result, err := s.kvStore.Get(StoreKeyDelegationSnapshots)
	if err != nil {
		// If key doesn't exist, return empty tree
		return avl.NewTree(), nil
	}

	snapshots, ok := result.(*avl.Tree)
	if !ok {
		return nil, errors.New(ufmt.Sprintf("failed to cast result to *avl.Tree: %T", result))
	}

	return snapshots, nil
}

// Helper functions
func int64ToString(n int64) string {
	return strconv.FormatInt(n, 10)
}
