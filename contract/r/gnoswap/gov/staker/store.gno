package staker

import (
	"strconv"

	"gno.land/p/gnoswap/store"
	bptree "gno.land/p/nt/bptree/v0"
	ufmt "gno.land/p/nt/ufmt/v0"
)

// Storage key constants
const (
	// Basic configuration
	StoreKeyUnDelegationLockupPeriod = "unDelegationLockupPeriod"
	StoreKeyTotalDelegatedAmount     = "totalDelegatedAmount"
	StoreKeyTotalLockedAmount        = "totalLockedAmount"

	// Counters
	StoreKeyDelegationNextID = "delegationNextID"

	// Complex data structures
	StoreKeyDelegations            = "delegations"            // BPTree of delegations
	StoreKeyTotalDelegationHistory = "totalDelegationHistory" // UintTree: timestamp -> int64 (cumulative total)
	StoreKeyUserDelegationHistory  = "userDelegationHistory"  // BPTree: address -> *UintTree[timestamp -> int64]

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

func (s *govStakerStore) GetUnDelegationLockupPeriod() int64 {
	result, err := s.kvStore.Get(StoreKeyUnDelegationLockupPeriod)
	if err != nil {
		panic(err)
	}

	period, ok := result.(int64)
	if !ok {
		panic(ufmt.Sprintf("failed to cast result to int64: %T", result))
	}

	return period
}

func (s *govStakerStore) SetUnDelegationLockupPeriod(_ int, rlm realm, period int64) error {
	if !rlm.IsCurrent() {
		return ErrSpoofedRealm
	}

	return s.kvStore.Set(0, rlm, StoreKeyUnDelegationLockupPeriod, period)
}

func (s *govStakerStore) HasTotalDelegatedAmountStoreKey() bool {
	return s.kvStore.Has(StoreKeyTotalDelegatedAmount)
}

func (s *govStakerStore) GetTotalDelegatedAmount() int64 {
	result, err := s.kvStore.Get(StoreKeyTotalDelegatedAmount)
	if err != nil {
		panic(err)
	}

	amount, ok := result.(int64)
	if !ok {
		panic(ufmt.Sprintf("failed to cast result to int64: %T", result))
	}

	return amount
}

func (s *govStakerStore) SetTotalDelegatedAmount(_ int, rlm realm, amount int64) error {
	if !rlm.IsCurrent() {
		return ErrSpoofedRealm
	}

	return s.kvStore.Set(0, rlm, StoreKeyTotalDelegatedAmount, amount)
}

func (s *govStakerStore) HasTotalLockedAmountStoreKey() bool {
	return s.kvStore.Has(StoreKeyTotalLockedAmount)
}

func (s *govStakerStore) GetTotalLockedAmount() int64 {
	result, err := s.kvStore.Get(StoreKeyTotalLockedAmount)
	if err != nil {
		panic(err)
	}

	amount, ok := result.(int64)
	if !ok {
		panic(ufmt.Sprintf("failed to cast result to int64: %T", result))
	}

	return amount
}

func (s *govStakerStore) SetTotalLockedAmount(_ int, rlm realm, amount int64) error {
	if !rlm.IsCurrent() {
		return ErrSpoofedRealm
	}

	return s.kvStore.Set(0, rlm, StoreKeyTotalLockedAmount, amount)
}

// Delegation management methods
func (s *govStakerStore) HasDelegationsStoreKey() bool {
	return s.kvStore.Has(StoreKeyDelegations)
}

func (s *govStakerStore) SetDelegations(_ int, rlm realm, delegations *bptree.BPTree) error {
	if !rlm.IsCurrent() {
		return ErrSpoofedRealm
	}

	return s.kvStore.Set(0, rlm, StoreKeyDelegations, delegations)
}

func (s *govStakerStore) HasDelegation(id int64) bool {
	delegations := s.GetAllDelegations()
	_, exists := delegations.Get(int64ToString(id))
	return exists
}

func (s *govStakerStore) GetDelegation(id int64) (*Delegation, bool) {
	delegations := s.GetAllDelegations()

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

func (s *govStakerStore) SetDelegation(_ int, rlm realm, id int64, delegation *Delegation) error {
	if !rlm.IsCurrent() {
		return ErrSpoofedRealm
	}

	delegations := s.GetAllDelegations()

	delegations.Set(int64ToString(id), delegation)
	return s.kvStore.Set(0, rlm, StoreKeyDelegations, delegations)
}

func (s *govStakerStore) RemoveDelegation(_ int, rlm realm, id int64) error {
	if !rlm.IsCurrent() {
		return ErrSpoofedRealm
	}

	delegations := s.GetAllDelegations()

	delegations.Remove(int64ToString(id))
	return s.kvStore.Set(0, rlm, StoreKeyDelegations, delegations)
}

func (s *govStakerStore) GetAllDelegations() *bptree.BPTree {
	result, err := s.kvStore.Get(StoreKeyDelegations)
	if err != nil {
		panic(err)
	}

	delegations, ok := result.(*bptree.BPTree)
	if !ok {
		panic(ufmt.Sprintf("failed to cast result to *bptree.BPTree: %T", result))
	}

	return delegations
}

func (s *govStakerStore) HasDelegationCounterStoreKey() bool {
	return s.kvStore.Has(StoreKeyDelegationNextID)
}

func (s *govStakerStore) GetDelegationCounter() *Counter {
	result, err := s.kvStore.Get(StoreKeyDelegationNextID)
	if err != nil {
		panic(err)
	}

	counter, ok := result.(*Counter)
	if !ok {
		panic(ufmt.Sprintf("failed to cast result to Counter: %T", result))
	}

	return counter
}

func (s *govStakerStore) SetDelegationCounter(_ int, rlm realm, counter *Counter) error {
	if !rlm.IsCurrent() {
		return ErrSpoofedRealm
	}

	return s.kvStore.Set(0, rlm, StoreKeyDelegationNextID, counter)
}

// Total delegation history methods (timestamp -> int64)
func (s *govStakerStore) HasTotalDelegationHistoryStoreKey() bool {
	return s.kvStore.Has(StoreKeyTotalDelegationHistory)
}

func (s *govStakerStore) GetTotalDelegationHistory() *UintTree {
	result, err := s.kvStore.Get(StoreKeyTotalDelegationHistory)
	if err != nil {
		panic(err)
	}

	history, ok := result.(*UintTree)
	if !ok {
		panic(ufmt.Sprintf("failed to cast result to *UintTree: %T", result))
	}

	return history
}

func (s *govStakerStore) SetTotalDelegationHistory(_ int, rlm realm, history *UintTree) error {
	if !rlm.IsCurrent() {
		return ErrSpoofedRealm
	}

	return s.kvStore.Set(0, rlm, StoreKeyTotalDelegationHistory, history)
}

// User delegation history methods (address -> *UintTree[timestamp -> int64])
func (s *govStakerStore) HasUserDelegationHistoryStoreKey() bool {
	return s.kvStore.Has(StoreKeyUserDelegationHistory)
}

func (s *govStakerStore) GetUserDelegationHistory() *bptree.BPTree {
	result, err := s.kvStore.Get(StoreKeyUserDelegationHistory)
	if err != nil {
		panic(err)
	}

	history, ok := result.(*bptree.BPTree)
	if !ok {
		panic(ufmt.Sprintf("failed to cast result to *bptree.BPTree: %T", result))
	}

	return history
}

func (s *govStakerStore) SetUserDelegationHistory(_ int, rlm realm, history *bptree.BPTree) error {
	if !rlm.IsCurrent() {
		return ErrSpoofedRealm
	}

	return s.kvStore.Set(0, rlm, StoreKeyUserDelegationHistory, history)
}

func (s *govStakerStore) HasEmissionRewardManagerStoreKey() bool {
	return s.kvStore.Has(StoreKeyEmissionRewardManager)
}

func (s *govStakerStore) GetEmissionRewardManager() *EmissionRewardManager {
	result, err := s.kvStore.Get(StoreKeyEmissionRewardManager)
	if err != nil {
		panic(err)
	}

	manager, ok := result.(*EmissionRewardManager)
	if !ok {
		panic(ufmt.Sprintf("failed to cast result to *EmissionRewardManager: %T", result))
	}

	return manager
}

func (s *govStakerStore) SetEmissionRewardManager(_ int, rlm realm, manager *EmissionRewardManager) error {
	if !rlm.IsCurrent() {
		return ErrSpoofedRealm
	}

	return s.kvStore.Set(0, rlm, StoreKeyEmissionRewardManager, manager)
}

func (s *govStakerStore) HasProtocolFeeRewardManagerStoreKey() bool {
	return s.kvStore.Has(StoreKeyProtocolFeeRewardManager)
}

func (s *govStakerStore) GetProtocolFeeRewardManager() *ProtocolFeeRewardManager {
	result, err := s.kvStore.Get(StoreKeyProtocolFeeRewardManager)
	if err != nil {
		panic(err)
	}

	manager, ok := result.(*ProtocolFeeRewardManager)
	if !ok {
		panic(ufmt.Sprintf("failed to cast result to *ProtocolFeeRewardManager: %T", result))
	}

	return manager
}

func (s *govStakerStore) SetProtocolFeeRewardManager(_ int, rlm realm, manager *ProtocolFeeRewardManager) error {
	if !rlm.IsCurrent() {
		return ErrSpoofedRealm
	}

	return s.kvStore.Set(0, rlm, StoreKeyProtocolFeeRewardManager, manager)
}

func (s *govStakerStore) HasDelegationManagerStoreKey() bool {
	return s.kvStore.Has(StoreKeyDelegationManager)
}

func (s *govStakerStore) GetDelegationManager() *DelegationManager {
	result, err := s.kvStore.Get(StoreKeyDelegationManager)
	if err != nil {
		panic(err)
	}

	manager, ok := result.(*DelegationManager)
	if !ok {
		panic(ufmt.Sprintf("failed to cast result to *DelegationManager: %T", result))
	}

	return manager
}

func (s *govStakerStore) SetDelegationManager(_ int, rlm realm, manager *DelegationManager) error {
	if !rlm.IsCurrent() {
		return ErrSpoofedRealm
	}

	return s.kvStore.Set(0, rlm, StoreKeyDelegationManager, manager)
}

func (s *govStakerStore) HasLaunchpadProjectDepositsStoreKey() bool {
	return s.kvStore.Has(StoreKeyLaunchpadProjectDeposits)
}

func (s *govStakerStore) GetLaunchpadProjectDeposits() *LaunchpadProjectDeposits {
	result, err := s.kvStore.Get(StoreKeyLaunchpadProjectDeposits)
	if err != nil {
		panic(err)
	}

	deposits, ok := result.(*LaunchpadProjectDeposits)
	if !ok {
		panic(ufmt.Sprintf("failed to cast result to *LaunchpadProjectDeposits: %T", result))
	}

	return deposits
}

func (s *govStakerStore) SetLaunchpadProjectDeposits(_ int, rlm realm, deposits *LaunchpadProjectDeposits) error {
	if !rlm.IsCurrent() {
		return ErrSpoofedRealm
	}

	return s.kvStore.Set(0, rlm, StoreKeyLaunchpadProjectDeposits, deposits)
}

// Helper functions
func int64ToString(n int64) string {
	return strconv.FormatInt(n, 10)
}
