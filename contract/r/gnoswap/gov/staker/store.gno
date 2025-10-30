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

	// Manager states
	StoreKeyEmissionRewardManager    = "emissionRewardManager"
	StoreKeyProtocolFeeRewardManager = "protocolFeeRewardManager"
	StoreKeyDelegationManager        = "delegationManager"
	StoreKeyLaunchpadProjectDeposits = "launchpadProjectDeposits"
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
	return s.kvStore.Has(StoreKeyUnDelegationLockupPeriod)
}

func (s *govStakerStore) GetUnDelegationLockupPeriod() (int64, error) {
	result, err := s.kvStore.Get(StoreKeyUnDelegationLockupPeriod)
	if err != nil {
		// Return default value if not initialized
		return 0, errors.New("undelegation lockup period not initialized")
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
	return s.kvStore.Has(StoreKeyEmissionRewardBalance)
}

func (s *govStakerStore) GetEmissionRewardBalance() (int64, error) {
	result, err := s.kvStore.Get(StoreKeyEmissionRewardBalance)
	if err != nil {
		return 0, err
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
	return s.kvStore.Has(StoreKeyTotalDelegatedAmount)
}

func (s *govStakerStore) GetTotalDelegatedAmount() (int64, error) {
	result, err := s.kvStore.Get(StoreKeyTotalDelegatedAmount)
	if err != nil {
		return 0, err
	}

	amount, ok := result.(int64)
	if !ok {
		return 0, errors.New(ufmt.Sprintf("failed to cast result to int64: %T", result))
	}

	return amount, nil
}

func (s *govStakerStore) SetTotalDelegatedAmount(amount int64) error {
	return s.kvStore.Set(StoreKeyTotalDelegatedAmount, amount)
}

func (s *govStakerStore) HasTotalLockedAmountStoreKey() bool {
	return s.kvStore.Has(StoreKeyTotalLockedAmount)
}

func (s *govStakerStore) GetTotalLockedAmount() (int64, error) {
	result, err := s.kvStore.Get(StoreKeyTotalLockedAmount)
	if err != nil {
		return 0, err
	}

	amount, ok := result.(int64)
	if !ok {
		return 0, errors.New(ufmt.Sprintf("failed to cast result to int64: %T", result))
	}

	return amount, nil
}

func (s *govStakerStore) SetTotalLockedAmount(amount int64) error {
	return s.kvStore.Set(StoreKeyTotalLockedAmount, amount)
}

// Delegation management methods
func (s *govStakerStore) HasDelegationsStoreKey() bool {
	return s.kvStore.Has(StoreKeyDelegations)
}

func (s *govStakerStore) SetDelegations(delegations *avl.Tree) error {
	return s.kvStore.Set(StoreKeyDelegations, delegations)
}

func (s *govStakerStore) HasDelegation(id int64) bool {
	delegations, err := s.getAllDelegations()
	if err != nil {
		panic(err)
	}
	_, exists := delegations.Get(int64ToString(id))
	return exists
}

func (s *govStakerStore) GetDelegation(id int64) (*Delegation, bool) {
	delegations, err := s.getAllDelegations()
	if err != nil {
		panic(err)
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
		return nil, err
	}

	delegations, ok := result.(*avl.Tree)
	if !ok {
		return nil, errors.New(ufmt.Sprintf("failed to cast result to *avl.Tree: %T", result))
	}

	return delegations, nil
}

func (s *govStakerStore) HasDelegationCounterStoreKey() bool {
	return s.kvStore.Has(StoreKeyDelegationNextID)
}

func (s *govStakerStore) GetDelegationCounter() (*Counter, error) {
	result, err := s.kvStore.Get(StoreKeyDelegationNextID)
	if err != nil {
		return nil, err
	}

	counter, ok := result.(*Counter)
	if !ok {
		return nil, errors.New(ufmt.Sprintf("failed to cast result to Counter: %T", result))
	}

	return counter, nil
}

func (s *govStakerStore) SetDelegationCounter(counter *Counter) error {
	return s.kvStore.Set(StoreKeyDelegationNextID, counter)
}

// Delegation history methods
func (s *govStakerStore) HasDelegationHistoryStoreKey() bool {
	return s.kvStore.Has(StoreKeyDelegationHistory)
}

func (s *govStakerStore) AddDelegationRecord(record *DelegationRecord) error {
	history, err := s.GetDelegationHistory()
	if err != nil {
		return err
	}

	history = append(history, record)
	return s.kvStore.Set(StoreKeyDelegationHistory, history)
}

func (s *govStakerStore) GetDelegationHistory() (DelegationHistory, error) {
	result, err := s.kvStore.Get(StoreKeyDelegationHistory)
	if err != nil {
		return nil, err
	}

	history, ok := result.(DelegationHistory)
	if !ok {
		return nil, errors.New(ufmt.Sprintf("failed to cast result to []*DelegationRecord: %T", result))
	}

	return history, nil
}

func (s *govStakerStore) SetDelegationHistory(history DelegationHistory) error {
	return s.kvStore.Set(StoreKeyDelegationHistory, history)
}

// Delegation snapshot methods
func (s *govStakerStore) HasDelegationSnapshotStoreKey() bool {
	return s.kvStore.Has(StoreKeyDelegationSnapshots)
}

func (s *govStakerStore) SetDelegationSnapshot(snapshot DelegationSnapshot) error {
	return s.kvStore.Set(StoreKeyDelegationSnapshots, snapshot)
}

func (s *govStakerStore) GetDelegationSnapshot() (DelegationSnapshot, error) {
	result, err := s.kvStore.Get(StoreKeyDelegationSnapshots)
	if err != nil {
		return nil, err
	}

	snapshot, ok := result.(DelegationSnapshot)
	if !ok {
		return nil, errors.New(ufmt.Sprintf("failed to cast result to DelegationSnapshot: %T", result))
	}

	return snapshot, nil
}

func (s *govStakerStore) HasEmissionRewardManagerStoreKey() bool {
	return s.kvStore.Has(StoreKeyEmissionRewardManager)
}

func (s *govStakerStore) GetEmissionRewardManager() (*EmissionRewardManager, error) {
	result, err := s.kvStore.Get(StoreKeyEmissionRewardManager)
	if err != nil {
		return nil, err
	}

	manager, ok := result.(*EmissionRewardManager)
	if !ok {
		return nil, errors.New(ufmt.Sprintf("failed to cast result to *EmissionRewardManager: %T", result))
	}

	return manager, nil
}

func (s *govStakerStore) SetEmissionRewardManager(manager *EmissionRewardManager) error {
	return s.kvStore.Set(StoreKeyEmissionRewardManager, manager)
}

func (s *govStakerStore) HasProtocolFeeRewardManagerStoreKey() bool {
	return s.kvStore.Has(StoreKeyProtocolFeeRewardManager)
}

func (s *govStakerStore) GetProtocolFeeRewardManager() (*ProtocolFeeRewardManager, error) {
	result, err := s.kvStore.Get(StoreKeyProtocolFeeRewardManager)
	if err != nil {
		return nil, err
	}

	manager, ok := result.(*ProtocolFeeRewardManager)
	if !ok {
		return nil, errors.New(ufmt.Sprintf("failed to cast result to *ProtocolFeeRewardManager: %T", result))
	}

	return manager, nil
}

func (s *govStakerStore) SetProtocolFeeRewardManager(manager *ProtocolFeeRewardManager) error {
	return s.kvStore.Set(StoreKeyProtocolFeeRewardManager, manager)
}

func (s *govStakerStore) HasDelegationManagerStoreKey() bool {
	return s.kvStore.Has(StoreKeyDelegationManager)
}

func (s *govStakerStore) GetDelegationManager() (*DelegationManager, error) {
	result, err := s.kvStore.Get(StoreKeyDelegationManager)
	if err != nil {
		return nil, err
	}

	manager, ok := result.(*DelegationManager)
	if !ok {
		return nil, errors.New(ufmt.Sprintf("failed to cast result to *DelegationManager: %T", result))
	}

	return manager, nil
}

func (s *govStakerStore) SetDelegationManager(manager *DelegationManager) error {
	return s.kvStore.Set(StoreKeyDelegationManager, manager)
}

func (s *govStakerStore) HasLaunchpadProjectDepositsStoreKey() bool {
	return s.kvStore.Has(StoreKeyLaunchpadProjectDeposits)
}

func (s *govStakerStore) GetLaunchpadProjectDeposits() (*LaunchpadProjectDeposits, error) {
	result, err := s.kvStore.Get(StoreKeyLaunchpadProjectDeposits)
	if err != nil {
		return nil, err
	}

	deposits, ok := result.(*LaunchpadProjectDeposits)
	if !ok {
		return nil, errors.New(ufmt.Sprintf("failed to cast result to *LaunchpadProjectDeposits: %T", result))
	}

	return deposits, nil
}

func (s *govStakerStore) SetLaunchpadProjectDeposits(deposits *LaunchpadProjectDeposits) error {
	return s.kvStore.Set(StoreKeyLaunchpadProjectDeposits, deposits)
}

// Helper functions
func int64ToString(n int64) string {
	return strconv.FormatInt(n, 10)
}
