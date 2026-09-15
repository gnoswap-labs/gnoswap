package staker

import (
	"errors"
	"gno.land/p/gnoswap/store/v1"
	"gno.land/p/gnoswap/utils/v1"
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

// NewGovStakerStore creates a new governance staker store instance backed by kvStore.
//
// Parameters:
//   - kvStore: Key-value store used to persist governance staker state.
//
// Returns:
//   - IGovStakerStore: store implementation that reads and writes the supplied KV store.
func NewGovStakerStore(kvStore store.KVStore) IGovStakerStore {
	return &govStakerStore{
		kvStore: kvStore,
	}
}

// Basic configuration methods
// Returns:
//   - bool: true when the undelegation lockup-period key is present in storage.
func (s *govStakerStore) HasUnDelegationLockupPeriodStoreKey() bool {
	return s.kvStore.Has(StoreKeyUnDelegationLockupPeriod)
}

// GetUnDelegationLockupPeriod returns the configured undelegation lockup period in seconds.
//
// Returns:
//   - int64: lockup duration in seconds; panics if the stored value is unavailable or not int64.
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

// SetUnDelegationLockupPeriod stores the undelegation lockup period.
//
// Parameters:
//   - _: Internal call discriminator; pass 0.
//   - rlm: Propagated realm context; the write is accepted only when this realm is current.
//   - period: Undelegation lockup duration in seconds.
//
// Returns:
//   - error: nil on success; ErrSpoofedRealm when rlm is not current, or the underlying KV-store error.
func (s *govStakerStore) SetUnDelegationLockupPeriod(_ int, rlm realm, period int64) error {
	if !rlm.IsCurrent() {
		return errors.New(ErrSpoofedRealm)
	}

	return s.kvStore.Set(0, rlm, StoreKeyUnDelegationLockupPeriod, period)
}

// Returns:
//   - bool: true when the total delegated-amount key is present in storage.
func (s *govStakerStore) HasTotalDelegatedAmountStoreKey() bool {
	return s.kvStore.Has(StoreKeyTotalDelegatedAmount)
}

// GetTotalDelegatedAmount returns the total amount currently delegated.
//
// Returns:
//   - int64: aggregate delegated amount; panics if the stored value is unavailable or not int64.
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

// SetTotalDelegatedAmount stores the aggregate delegated amount.
//
// Parameters:
//   - _: Internal call discriminator; pass 0.
//   - rlm: Propagated realm context; the write is accepted only when this realm is current.
//   - amount: Aggregate amount of GNS delegated across all delegators.
//
// Returns:
//   - error: nil on success; ErrSpoofedRealm when rlm is not current, or the underlying KV-store error.
func (s *govStakerStore) SetTotalDelegatedAmount(_ int, rlm realm, amount int64) error {
	if !rlm.IsCurrent() {
		return errors.New(ErrSpoofedRealm)
	}

	return s.kvStore.Set(0, rlm, StoreKeyTotalDelegatedAmount, amount)
}

// Returns:
//   - bool: true when the total locked-amount key is present in storage.
func (s *govStakerStore) HasTotalLockedAmountStoreKey() bool {
	return s.kvStore.Has(StoreKeyTotalLockedAmount)
}

// GetTotalLockedAmount returns the total amount locked in undelegation withdrawals.
//
// Returns:
//   - int64: aggregate locked amount; panics if the stored value is unavailable or not int64.
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

// SetTotalLockedAmount stores the aggregate amount locked in undelegation.
//
// Parameters:
//   - _: Internal call discriminator; pass 0.
//   - rlm: Propagated realm context; the write is accepted only when this realm is current.
//   - amount: Aggregate GNS amount currently locked in undelegation withdrawals.
//
// Returns:
//   - error: nil on success; ErrSpoofedRealm when rlm is not current, or the underlying KV-store error.
func (s *govStakerStore) SetTotalLockedAmount(_ int, rlm realm, amount int64) error {
	if !rlm.IsCurrent() {
		return errors.New(ErrSpoofedRealm)
	}

	return s.kvStore.Set(0, rlm, StoreKeyTotalLockedAmount, amount)
}

// Delegation management methods
// Returns:
//   - bool: true when the delegations tree key is present in storage.
func (s *govStakerStore) HasDelegationsStoreKey() bool {
	return s.kvStore.Has(StoreKeyDelegations)
}

// SetDelegations replaces the persisted delegation tree.
//
// Parameters:
//   - _: Internal call discriminator; pass 0.
//   - rlm: Propagated realm context; the write is accepted only when this realm is current.
//   - delegations: BPTree containing delegation records keyed by decimal delegation ID.
//
// Returns:
//   - error: nil on success; ErrSpoofedRealm when rlm is not current, or the underlying KV-store error.
func (s *govStakerStore) SetDelegations(_ int, rlm realm, delegations *bptree.BPTree) error {
	if !rlm.IsCurrent() {
		return errors.New(ErrSpoofedRealm)
	}

	return s.kvStore.Set(0, rlm, StoreKeyDelegations, delegations)
}

// HasDelegation reports whether a delegation with id exists.
//
// Parameters:
//   - id: Numeric delegation identifier converted to the tree's decimal-string key.
//
// Returns:
//   - bool: true when a delegation record exists for id, false when the key is absent.
func (s *govStakerStore) HasDelegation(id int64) bool {
	delegations := s.GetAllDelegations()
	return delegations.Get(utils.Int64ToString(id)) != nil
}

// GetDelegation retrieves a delegation by id.
//
// Parameters:
//   - id: Numeric delegation identifier converted to the tree's decimal-string key.
//
// Returns:
//   - *Delegation: stored delegation, or nil when no record exists for id.
//   - bool: true when a delegation was found; false when id is absent.
func (s *govStakerStore) GetDelegation(id int64) (*Delegation, bool) {
	delegations := s.GetAllDelegations()

	result := delegations.Get(utils.Int64ToString(id))
	if result == nil {
		return nil, false
	}

	delegation, ok := result.(*Delegation)
	if !ok {
		panic(ufmt.Sprintf("failed to cast result to *Delegation: %T", result))
	}

	return delegation, true
}

// SetDelegation stores one delegation under id.
//
// Parameters:
//   - _: Internal call discriminator; pass 0.
//   - rlm: Propagated realm context; the write is accepted only when this realm is current.
//   - id: Numeric identifier used as the delegation's decimal-string tree key.
//   - delegation: Delegation record to store for id.
//
// Returns:
//   - error: nil on success; ErrSpoofedRealm when rlm is not current, or the underlying KV-store error.
func (s *govStakerStore) SetDelegation(_ int, rlm realm, id int64, delegation *Delegation) error {
	if !rlm.IsCurrent() {
		return errors.New(ErrSpoofedRealm)
	}

	delegations := s.GetAllDelegations()

	delegations.Set(utils.Int64ToString(id), delegation)
	return s.kvStore.Set(0, rlm, StoreKeyDelegations, delegations)
}

// RemoveDelegation deletes the delegation stored under id.
//
// Parameters:
//   - _: Internal call discriminator; pass 0.
//   - rlm: Propagated realm context; the write is accepted only when this realm is current.
//   - id: Numeric delegation identifier whose decimal-string tree entry is removed.
//
// Returns:
//   - error: nil on success; ErrSpoofedRealm when rlm is not current, or the underlying KV-store error.
func (s *govStakerStore) RemoveDelegation(_ int, rlm realm, id int64) error {
	if !rlm.IsCurrent() {
		return errors.New(ErrSpoofedRealm)
	}

	delegations := s.GetAllDelegations()

	delegations.Remove(utils.Int64ToString(id))
	return s.kvStore.Set(0, rlm, StoreKeyDelegations, delegations)
}

// GetAllDelegations returns the persisted tree of delegation records keyed by decimal ID.
//
// Returns:
//   - *bptree.BPTree: delegation tree; panics if storage is unavailable or contains a different type.
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

// Returns:
//   - bool: true when the next-delegation-ID counter key is present in storage.
func (s *govStakerStore) HasDelegationCounterStoreKey() bool {
	return s.kvStore.Has(StoreKeyDelegationNextID)
}

// GetDelegationCounter returns the counter used to allocate delegation IDs.
//
// Returns:
//   - *Counter: persisted next-ID counter; panics if storage is unavailable or contains a different type.
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

// SetDelegationCounter stores the counter used to allocate delegation IDs.
//
// Parameters:
//   - _: Internal call discriminator; pass 0.
//   - rlm: Propagated realm context; the write is accepted only when this realm is current.
//   - counter: Counter holding the next delegation ID.
//
// Returns:
//   - error: nil on success; ErrSpoofedRealm when rlm is not current, or the underlying KV-store error.
func (s *govStakerStore) SetDelegationCounter(_ int, rlm realm, counter *Counter) error {
	if !rlm.IsCurrent() {
		return errors.New(ErrSpoofedRealm)
	}

	return s.kvStore.Set(0, rlm, StoreKeyDelegationNextID, counter)
}

// Total delegation history methods (timestamp -> int64)
// Returns:
//   - bool: true when the total delegation-history key is present in storage.
func (s *govStakerStore) HasTotalDelegationHistoryStoreKey() bool {
	return s.kvStore.Has(StoreKeyTotalDelegationHistory)
}

// GetTotalDelegationHistory returns timestamp-indexed aggregate delegation history.
//
// Returns:
//   - *UintTree: history mapping Unix timestamps to cumulative delegated amounts; panics on missing or invalid storage.
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

// SetTotalDelegationHistory stores timestamp-indexed aggregate delegation history.
//
// Parameters:
//   - _: Internal call discriminator; pass 0.
//   - rlm: Propagated realm context; the write is accepted only when this realm is current.
//   - history: UintTree mapping timestamps to cumulative total delegated amounts.
//
// Returns:
//   - error: nil on success; ErrSpoofedRealm when rlm is not current, or the underlying KV-store error.
func (s *govStakerStore) SetTotalDelegationHistory(_ int, rlm realm, history *UintTree) error {
	if !rlm.IsCurrent() {
		return errors.New(ErrSpoofedRealm)
	}

	return s.kvStore.Set(0, rlm, StoreKeyTotalDelegationHistory, history)
}

// User delegation history methods (address -> *UintTree[timestamp -> int64])
// Returns:
//   - bool: true when the per-user delegation-history key is present in storage.
func (s *govStakerStore) HasUserDelegationHistoryStoreKey() bool {
	return s.kvStore.Has(StoreKeyUserDelegationHistory)
}

// GetUserDelegationHistory returns the address-indexed delegation-history tree.
//
// Returns:
//   - *bptree.BPTree: tree mapping delegator addresses to timestamp histories; panics on missing or invalid storage.
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

// SetUserDelegationHistory stores the address-indexed delegation-history tree.
//
// Parameters:
//   - _: Internal call discriminator; pass 0.
//   - rlm: Propagated realm context; the write is accepted only when this realm is current.
//   - history: BPTree mapping delegator addresses to their timestamp-indexed histories.
//
// Returns:
//   - error: nil on success; ErrSpoofedRealm when rlm is not current, or the underlying KV-store error.
func (s *govStakerStore) SetUserDelegationHistory(_ int, rlm realm, history *bptree.BPTree) error {
	if !rlm.IsCurrent() {
		return errors.New(ErrSpoofedRealm)
	}

	return s.kvStore.Set(0, rlm, StoreKeyUserDelegationHistory, history)
}

// Returns:
//   - bool: true when the emission-reward-manager key is present in storage.
func (s *govStakerStore) HasEmissionRewardManagerStoreKey() bool {
	return s.kvStore.Has(StoreKeyEmissionRewardManager)
}

// GetEmissionRewardManager returns the persisted emission reward manager.
//
// Returns:
//   - *EmissionRewardManager: emission reward accounting state; panics on missing or invalid storage.
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

// SetEmissionRewardManager stores the emission reward manager.
//
// Parameters:
//   - _: Internal call discriminator; pass 0.
//   - rlm: Propagated realm context; the write is accepted only when this realm is current.
//   - manager: Emission reward accounting state to persist.
//
// Returns:
//   - error: nil on success; ErrSpoofedRealm when rlm is not current, or the underlying KV-store error.
func (s *govStakerStore) SetEmissionRewardManager(_ int, rlm realm, manager *EmissionRewardManager) error {
	if !rlm.IsCurrent() {
		return errors.New(ErrSpoofedRealm)
	}

	return s.kvStore.Set(0, rlm, StoreKeyEmissionRewardManager, manager)
}

// Returns:
//   - bool: true when the protocol-fee reward-manager key is present in storage.
func (s *govStakerStore) HasProtocolFeeRewardManagerStoreKey() bool {
	return s.kvStore.Has(StoreKeyProtocolFeeRewardManager)
}

// GetProtocolFeeRewardManager returns the persisted protocol-fee reward manager.
//
// Returns:
//   - *ProtocolFeeRewardManager: protocol-fee reward accounting state; panics on missing or invalid storage.
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

// SetProtocolFeeRewardManager stores the protocol-fee reward manager.
//
// Parameters:
//   - _: Internal call discriminator; pass 0.
//   - rlm: Propagated realm context; the write is accepted only when this realm is current.
//   - manager: Protocol-fee reward accounting state to persist.
//
// Returns:
//   - error: nil on success; ErrSpoofedRealm when rlm is not current, or the underlying KV-store error.
func (s *govStakerStore) SetProtocolFeeRewardManager(_ int, rlm realm, manager *ProtocolFeeRewardManager) error {
	if !rlm.IsCurrent() {
		return errors.New(ErrSpoofedRealm)
	}

	return s.kvStore.Set(0, rlm, StoreKeyProtocolFeeRewardManager, manager)
}

// Returns:
//   - bool: true when the delegation-manager key is present in storage.
func (s *govStakerStore) HasDelegationManagerStoreKey() bool {
	return s.kvStore.Has(StoreKeyDelegationManager)
}

// GetDelegationManager returns the persisted delegation manager.
//
// Returns:
//   - *DelegationManager: delegation-management state; panics on missing or invalid storage.
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

// SetDelegationManager stores the delegation manager.
//
// Parameters:
//   - _: Internal call discriminator; pass 0.
//   - rlm: Propagated realm context; the write is accepted only when this realm is current.
//   - manager: Delegation-management state to persist.
//
// Returns:
//   - error: nil on success; ErrSpoofedRealm when rlm is not current, or the underlying KV-store error.
func (s *govStakerStore) SetDelegationManager(_ int, rlm realm, manager *DelegationManager) error {
	if !rlm.IsCurrent() {
		return errors.New(ErrSpoofedRealm)
	}

	return s.kvStore.Set(0, rlm, StoreKeyDelegationManager, manager)
}

// Returns:
//   - bool: true when the launchpad-project-deposits key is present in storage.
func (s *govStakerStore) HasLaunchpadProjectDepositsStoreKey() bool {
	return s.kvStore.Has(StoreKeyLaunchpadProjectDeposits)
}

// GetLaunchpadProjectDeposits returns persisted launchpad project deposit state.
//
// Returns:
//   - *LaunchpadProjectDeposits: launchpad deposit accounting state; panics on missing or invalid storage.
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

// SetLaunchpadProjectDeposits stores launchpad project deposit state.
//
// Parameters:
//   - _: Internal call discriminator; pass 0.
//   - rlm: Propagated realm context; the write is accepted only when this realm is current.
//   - deposits: Launchpad project deposit accounting state to persist.
//
// Returns:
//   - error: nil on success; ErrSpoofedRealm when rlm is not current, or the underlying KV-store error.
func (s *govStakerStore) SetLaunchpadProjectDeposits(_ int, rlm realm, deposits *LaunchpadProjectDeposits) error {
	if !rlm.IsCurrent() {
		return errors.New(ErrSpoofedRealm)
	}

	return s.kvStore.Set(0, rlm, StoreKeyLaunchpadProjectDeposits, deposits)
}
