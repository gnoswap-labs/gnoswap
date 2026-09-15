package protocol_fee

import (
	"errors"

	bptree "gno.land/p/nt/bptree/v0"
	ufmt "gno.land/p/nt/ufmt/v0"

	"gno.land/p/gnoswap/gnsmath"
	"gno.land/p/gnoswap/store"
	"gno.land/p/gnoswap/utils"
)

type StoreKey string

// String returns the textual store-key value.
//
// Returns:
//   - key: The string representation of the StoreKey.
func (s StoreKey) String() string {
	return string(s)
}

const (
	// By default, devOps will get 0% of the protocol fee (which means gov/staker will get 100% of the protocol fee)
	// This percentage can be modified through governance.
	StoreKeyDevOpsPct StoreKey = "devOpsPct"

	// accuToGovStaker tracks the cumulative amount allocated to GovStaker,
	// including allocations that are still pending distribution.
	StoreKeyAccuToGovStaker StoreKey = "accuToGovStaker" // tokenPath -> amount
	// accuToDevOps tracks the cumulative amount allocated to DevOps,
	// including allocations that are still pending distribution.
	StoreKeyAccuToDevOps StoreKey = "accuToDevOps" // tokenPath -> amount

	// Distribution-history trees track cumulative amounts actually transferred.
	StoreKeyDistributedToGovStakerHistory StoreKey = "distributedToGovStakerHistory" // tokenPath -> amount
	StoreKeyDistributedToDevOpsHistory    StoreKey = "distributedToDevOpsHistory"    // tokenPath -> amount

	// reservedTokens tracks token paths collected but not yet distributed.
	StoreKeyReservedTokens StoreKey = "reservedTokens"

	// accrualEpoch, accrualBuckets and accrualPendingTokens track the gov/staker share
	// per token path and accrual epoch until gov/staker folds it into its accumulator.
	StoreKeyAccrualEpoch         StoreKey = "accrualEpoch"
	StoreKeyAccrualBuckets       StoreKey = "accrualBuckets"       // tokenPath -> (epoch -> amount)
	StoreKeyAccrualPendingTokens StoreKey = "accrualPendingTokens" // tokenPath -> true
)

const (
	defaultDevOpsPct = int64(0)
	errSpoofedRealm  = "rlm does not match the current crossing frame"
)

// NewBPTreeN allocates a BP-tree under /r/gnoswap/protocol_fee's realm context
// so tree.Set leaf-slot writes clear the readonly-taint gate regardless of
// which realm (protocol_fee/v1, mock, tests) calls Set. Callers must allocate
// protocol_fee trees through here rather than bptree.NewBPTreeN directly.
//
// Parameters:
//   - fanout: Branching factor passed to the BP-tree constructor.
//
// Returns:
//   - tree: A new BP-tree configured with fanout and allocated in the protocol-fee realm context.
func NewBPTreeN(fanout int) *bptree.BPTree {
	return bptree.NewBPTreeN(fanout)
}

type protocolFeeStore struct {
	kvStore store.KVStore
}

// handle devOpsPct store data
//
// Returns:
//   - exists: True when the DevOps percentage store key is present in the KV store.
func (s *protocolFeeStore) HasDevOpsPctStoreKey() bool {
	return s.kvStore.Has(StoreKeyDevOpsPct.String())
}

// InitializeDevOpsPct creates the DevOps allocation percentage entry with its default value.
//
// Parameters:
//   - _: Crossing discriminator for the store operation; pass 0.
//   - rlm: Propagated realm context for this store write; it must be current (`rlm.IsCurrent()`).
//
// Returns:
//   - err: Nil when the key is initialized; otherwise the current-realm or KV-store write error.
func (s *protocolFeeStore) InitializeDevOpsPct(_ int, rlm realm) error {
	if !rlm.IsCurrent() {
		return errors.New(errSpoofedRealm)
	}

	return s.kvStore.Set(0, rlm, StoreKeyDevOpsPct.String(), defaultDevOpsPct)
}

// GetDevOpsPct reads the persisted DevOps allocation percentage.
//
// Returns:
//   - pct: The stored DevOps allocation percentage in basis points; the method panics if the key is missing or cannot be decoded as int64.
func (s *protocolFeeStore) GetDevOpsPct() int64 {
	devOpsPct, err := s.kvStore.GetInt64(StoreKeyDevOpsPct.String())
	if err != nil {
		panic(err)
	}

	return devOpsPct
}

// SetDevOpsPct persists the DevOps allocation percentage.
//
// Parameters:
//   - _: Crossing discriminator for the store operation; pass 0.
//   - rlm: Propagated realm context for this store write; it must be current (`rlm.IsCurrent()`).
//   - pct: DevOps share of protocol fees in basis points; the state layer constrains this value to 0 through 10000 before calling the store.
//
// Returns:
//   - err: Nil when the percentage is persisted; otherwise the current-realm or KV-store write error.
func (s *protocolFeeStore) SetDevOpsPct(_ int, rlm realm, pct int64) error {
	if !rlm.IsCurrent() {
		return errors.New(errSpoofedRealm)
	}

	return s.kvStore.Set(0, rlm, StoreKeyDevOpsPct.String(), pct)
}

// handle accuToGovStaker store data
//
// Returns:
//   - exists: True when the cumulative Gov/Staker allocation tree key is present in the KV store.
func (s *protocolFeeStore) HasAccuToGovStakerStoreKey() bool {
	return s.kvStore.Has(StoreKeyAccuToGovStaker.String())
}

// InitializeAccuToGovStaker creates the cumulative Gov/Staker allocation tree.
//
// Parameters:
//   - _: Crossing discriminator for the store operation; pass 0.
//   - rlm: Propagated realm context for this store write; it must be current (`rlm.IsCurrent()`).
//
// Returns:
//   - err: Nil when the tree is initialized; otherwise the current-realm or KV-store write error.
func (s *protocolFeeStore) InitializeAccuToGovStaker(_ int, rlm realm) error {
	if !rlm.IsCurrent() {
		return errors.New(errSpoofedRealm)
	}

	return s.kvStore.Set(0, rlm, StoreKeyAccuToGovStaker.String(), NewBPTreeN(16))
}

// GetAccuToGovStaker reads the cumulative Gov/Staker allocation tree.
//
// Returns:
//   - tree: The BP-tree mapping token paths to cumulative amounts; the method panics if the store value is absent or has the wrong type.
func (s *protocolFeeStore) GetAccuToGovStaker() *bptree.BPTree {
	accuToGovStaker, err := s.kvStore.GetBPTree(StoreKeyAccuToGovStaker.String())
	if err != nil {
		panic(err)
	}

	return accuToGovStaker
}

// GetAccuToGovStakerItem reads one token's cumulative Gov/Staker allocation.
//
// Parameters:
//   - tokenPath: Token path whose cumulative allocation should be looked up.
//
// Returns:
//   - amount: The stored cumulative allocation for tokenPath, or zero when no entry exists.
//   - found: True when tokenPath has an entry in the allocation tree; false when it is absent.
func (s *protocolFeeStore) GetAccuToGovStakerItem(tokenPath string) (int64, bool) {
	accuToGovStaker, err := s.kvStore.GetBPTree(StoreKeyAccuToGovStaker.String())
	if err != nil {
		panic(err)
	}

	result := accuToGovStaker.Get(tokenPath)
	if result == nil {
		return 0, false
	}

	amount, ok := result.(int64)
	if !ok {
		panic(ufmt.Errorf("failed to cast result to int64: %T", result))
	}

	return amount, true
}

// SetAccuToGovStakerItem updates one token's cumulative Gov/Staker allocation.
//
// Parameters:
//   - _: Crossing discriminator for the store operation; pass 0.
//   - rlm: Propagated realm context for this store write; it must be current (`rlm.IsCurrent()`).
//   - tokenPath: Token path whose cumulative allocation is replaced.
//   - amount: Cumulative Gov/Staker allocation to store for tokenPath.
//
// Returns:
//   - err: Nil when the allocation tree is persisted; otherwise the current-realm, tree-read, or KV-store write error.
func (s *protocolFeeStore) SetAccuToGovStakerItem(_ int, rlm realm, tokenPath string, amount int64) error {
	if !rlm.IsCurrent() {
		return errors.New(errSpoofedRealm)
	}

	accuToGovStaker, err := s.kvStore.GetBPTree(StoreKeyAccuToGovStaker.String())
	if err != nil {
		return err
	}

	accuToGovStaker.Set(tokenPath, amount)

	return s.kvStore.Set(0, rlm, StoreKeyAccuToGovStaker.String(), accuToGovStaker)
}

// handle accuToDevOps store data
//
// Returns:
//   - exists: True when the cumulative DevOps allocation tree key is present in the KV store.
func (s *protocolFeeStore) HasAccuToDevOpsStoreKey() bool {
	return s.kvStore.Has(StoreKeyAccuToDevOps.String())
}

// InitializeAccuToDevOps creates the cumulative DevOps allocation tree.
//
// Parameters:
//   - _: Crossing discriminator for the store operation; pass 0.
//   - rlm: Propagated realm context for this store write; it must be current (`rlm.IsCurrent()`).
//
// Returns:
//   - err: Nil when the tree is initialized; otherwise the current-realm or KV-store write error.
func (s *protocolFeeStore) InitializeAccuToDevOps(_ int, rlm realm) error {
	if !rlm.IsCurrent() {
		return errors.New(errSpoofedRealm)
	}

	return s.kvStore.Set(0, rlm, StoreKeyAccuToDevOps.String(), NewBPTreeN(16))
}

// GetAccuToDevOps reads the cumulative DevOps allocation tree.
//
// Returns:
//   - tree: The BP-tree mapping token paths to cumulative amounts; the method panics if the store value is absent or has the wrong type.
func (s *protocolFeeStore) GetAccuToDevOps() *bptree.BPTree {
	accuToDevOps, err := s.kvStore.GetBPTree(StoreKeyAccuToDevOps.String())
	if err != nil {
		panic(err)
	}

	return accuToDevOps
}

// GetAccuToDevOpsItem reads one token's cumulative DevOps allocation.
//
// Parameters:
//   - tokenPath: Token path whose cumulative allocation should be looked up.
//
// Returns:
//   - amount: The stored cumulative allocation for tokenPath, or zero when no entry exists.
//   - found: True when tokenPath has an entry in the allocation tree; false when it is absent.
func (s *protocolFeeStore) GetAccuToDevOpsItem(tokenPath string) (int64, bool) {
	accuToDevOps, err := s.kvStore.GetBPTree(StoreKeyAccuToDevOps.String())
	if err != nil {
		panic(err)
	}

	result := accuToDevOps.Get(tokenPath)
	if result == nil {
		return 0, false
	}

	amount, ok := result.(int64)
	if !ok {
		panic(ufmt.Errorf("failed to cast result to int64: %T", result))
	}

	return amount, true
}

// SetAccuToDevOpsItem updates one token's cumulative DevOps allocation.
//
// Parameters:
//   - _: Crossing discriminator for the store operation; pass 0.
//   - rlm: Propagated realm context for this store write; it must be current (`rlm.IsCurrent()`).
//   - tokenPath: Token path whose cumulative allocation is replaced.
//   - amount: Cumulative DevOps allocation to store for tokenPath.
//
// Returns:
//   - err: Nil when the allocation tree is persisted; otherwise the current-realm, tree-read, or KV-store write error.
func (s *protocolFeeStore) SetAccuToDevOpsItem(_ int, rlm realm, tokenPath string, amount int64) error {
	if !rlm.IsCurrent() {
		return errors.New(errSpoofedRealm)
	}

	accuToDevOps, err := s.kvStore.GetBPTree(StoreKeyAccuToDevOps.String())
	if err != nil {
		return err
	}

	accuToDevOps.Set(tokenPath, amount)

	return s.kvStore.Set(0, rlm, StoreKeyAccuToDevOps.String(), accuToDevOps)
}

// handle distributedToGovStakerHistory store data
// HasDistributedToGovStakerHistoryStoreKey reports whether the Gov/Staker distribution-history tree exists.
//
// Returns:
//   - exists: True when the Gov/Staker distribution-history tree key is present in the KV store.
func (s *protocolFeeStore) HasDistributedToGovStakerHistoryStoreKey() bool {
	return s.kvStore.Has(StoreKeyDistributedToGovStakerHistory.String())
}

// InitializeDistributedToGovStakerHistory creates the Gov/Staker distribution-history tree.
//
// Parameters:
//   - _: Crossing discriminator for the store operation; pass 0.
//   - rlm: Propagated realm context for this store write; it must be current (`rlm.IsCurrent()`).
//
// Returns:
//   - err: Nil when the history tree is initialized; otherwise the current-realm or KV-store write error.
func (s *protocolFeeStore) InitializeDistributedToGovStakerHistory(_ int, rlm realm) error {
	if !rlm.IsCurrent() {
		return errors.New(errSpoofedRealm)
	}

	return s.kvStore.Set(0, rlm, StoreKeyDistributedToGovStakerHistory.String(), NewBPTreeN(16))
}

// GetDistributedToGovStakerHistory reads the cumulative Gov/Staker distribution-history tree.
//
// Returns:
//   - tree: The BP-tree mapping token paths to amounts actually distributed to Gov/Staker; the method panics if the stored value is absent or has the wrong type.
func (s *protocolFeeStore) GetDistributedToGovStakerHistory() *bptree.BPTree {
	distributedToGovStakerHistory, err := s.kvStore.GetBPTree(StoreKeyDistributedToGovStakerHistory.String())
	if err != nil {
		panic(err)
	}

	return distributedToGovStakerHistory
}

// GetDistributedToGovStakerHistoryItem reads one token's cumulative Gov/Staker distribution history.
//
// Parameters:
//   - tokenPath: Token path whose distributed amount should be looked up.
//
// Returns:
//   - amount: The stored cumulative amount distributed to Gov/Staker for tokenPath, or zero when no entry exists.
//   - found: True when tokenPath has a history entry; false when it is absent.
func (s *protocolFeeStore) GetDistributedToGovStakerHistoryItem(tokenPath string) (int64, bool) {
	distributedToGovStakerHistory, err := s.kvStore.GetBPTree(StoreKeyDistributedToGovStakerHistory.String())
	if err != nil {
		panic(err)
	}

	result := distributedToGovStakerHistory.Get(tokenPath)
	if result == nil {
		return 0, false
	}

	amount, ok := result.(int64)
	if !ok {
		panic(ufmt.Errorf("failed to cast result to int64: %T", result))
	}

	return amount, true
}

// SetDistributedToGovStakerHistoryItem updates one token's cumulative Gov/Staker distribution history.
//
// Parameters:
//   - _: Crossing discriminator for the store operation; pass 0.
//   - rlm: Propagated realm context for this store write; it must be current (`rlm.IsCurrent()`).
//   - tokenPath: Token path whose distributed amount is replaced.
//   - amount: Cumulative amount actually distributed to Gov/Staker to store for tokenPath.
//
// Returns:
//   - err: Nil when the history tree is persisted; otherwise the current-realm, tree-read, or KV-store write error.
func (s *protocolFeeStore) SetDistributedToGovStakerHistoryItem(_ int, rlm realm, tokenPath string, amount int64) error {
	if !rlm.IsCurrent() {
		return errors.New(errSpoofedRealm)
	}

	distributedToGovStakerHistory, err := s.kvStore.GetBPTree(StoreKeyDistributedToGovStakerHistory.String())
	if err != nil {
		return err
	}

	distributedToGovStakerHistory.Set(tokenPath, amount)

	return s.kvStore.Set(0, rlm, StoreKeyDistributedToGovStakerHistory.String(), distributedToGovStakerHistory)
}

// HasDistributedToDevOpsHistoryStoreKey reports whether the DevOps distribution-history tree exists.
//
// Returns:
//   - exists: True when the DevOps distribution-history tree key is present in the KV store.
//
// handle distributedToDevOpsHistory store data
func (s *protocolFeeStore) HasDistributedToDevOpsHistoryStoreKey() bool {
	return s.kvStore.Has(StoreKeyDistributedToDevOpsHistory.String())
}

// InitializeDistributedToDevOpsHistory creates the DevOps distribution-history tree.
//
// Parameters:
//   - _: Crossing discriminator for the store operation; pass 0.
//   - rlm: Propagated realm context for this store write; it must be current (`rlm.IsCurrent()`).
//
// Returns:
//   - err: Nil when the history tree is initialized; otherwise the current-realm or KV-store write error.
func (s *protocolFeeStore) InitializeDistributedToDevOpsHistory(_ int, rlm realm) error {
	if !rlm.IsCurrent() {
		return errors.New(errSpoofedRealm)
	}

	return s.kvStore.Set(0, rlm, StoreKeyDistributedToDevOpsHistory.String(), NewBPTreeN(16))
}

// GetDistributedToDevOpsHistory reads the cumulative DevOps distribution-history tree.
//
// Returns:
//   - tree: The BP-tree mapping token paths to amounts actually distributed to DevOps; the method panics if the stored value is absent or has the wrong type.
func (s *protocolFeeStore) GetDistributedToDevOpsHistory() *bptree.BPTree {
	distributedToDevOpsHistory, err := s.kvStore.GetBPTree(StoreKeyDistributedToDevOpsHistory.String())
	if err != nil {
		panic(err)
	}

	return distributedToDevOpsHistory
}

// GetDistributedToDevOpsHistoryItem reads one token's cumulative DevOps distribution history.
//
// Parameters:
//   - tokenPath: Token path whose distributed amount should be looked up.
//
// Returns:
//   - amount: The stored cumulative amount distributed to DevOps for tokenPath, or zero when no entry exists.
//   - found: True when tokenPath has a history entry; false when it is absent.
func (s *protocolFeeStore) GetDistributedToDevOpsHistoryItem(tokenPath string) (int64, bool) {
	distributedToDevOpsHistory, err := s.kvStore.GetBPTree(StoreKeyDistributedToDevOpsHistory.String())
	if err != nil {
		panic(err)
	}

	result := distributedToDevOpsHistory.Get(tokenPath)
	if result == nil {
		return 0, false
	}

	amount, ok := result.(int64)
	if !ok {
		panic(ufmt.Errorf("failed to cast result to int64: %T", result))
	}

	return amount, true
}

// SetDistributedToDevOpsHistoryItem updates one token's cumulative DevOps distribution history.
//
// Parameters:
//   - _: Crossing discriminator for the store operation; pass 0.
//   - rlm: Propagated realm context for this store write; it must be current (`rlm.IsCurrent()`).
//   - tokenPath: Token path whose distributed amount is replaced.
//   - amount: Cumulative amount actually distributed to DevOps to store for tokenPath.
//
// Returns:
//   - err: Nil when the history tree is persisted; otherwise the current-realm, tree-read, or KV-store write error.
func (s *protocolFeeStore) SetDistributedToDevOpsHistoryItem(_ int, rlm realm, tokenPath string, amount int64) error {
	if !rlm.IsCurrent() {
		return errors.New(errSpoofedRealm)
	}

	distributedToDevOpsHistory, err := s.kvStore.GetBPTree(StoreKeyDistributedToDevOpsHistory.String())
	if err != nil {
		return err
	}

	distributedToDevOpsHistory.Set(tokenPath, amount)

	return s.kvStore.Set(0, rlm, StoreKeyDistributedToDevOpsHistory.String(), distributedToDevOpsHistory)
}

// handle reservedTokens store data
//
// reservedTokens is the set of token paths that collected a fee not yet transferred out
// by DistributeProtocolFee. It is kept as a tree so that a single token can be added or
// settled without rewriting the whole set.
//
// Returns:
//   - exists: True when the reserved-token index key is present in the KV store.
func (s *protocolFeeStore) HasReservedTokensStoreKey() bool {
	return s.kvStore.Has(StoreKeyReservedTokens.String())
}

// InitializeReservedTokens creates the reserved-token index tree.
//
// Parameters:
//   - _: Crossing discriminator for the store operation; pass 0.
//   - rlm: Propagated realm context for this store write; it must be current (`rlm.IsCurrent()`).
//
// Returns:
//   - err: Nil when the index tree is initialized; otherwise the current-realm or KV-store write error.
func (s *protocolFeeStore) InitializeReservedTokens(_ int, rlm realm) error {
	if !rlm.IsCurrent() {
		return errors.New(errSpoofedRealm)
	}

	return s.kvStore.Set(0, rlm, StoreKeyReservedTokens.String(), NewBPTreeN(16))
}

// getReservedTokenTree reads the reserved-token index tree.
//
// Returns:
//   - tree: The BP-tree containing token paths collected for later distribution; the method panics if the store value is absent or has the wrong type.
func (s *protocolFeeStore) getReservedTokenTree() *bptree.BPTree {
	reservedTokens, err := s.kvStore.GetBPTree(StoreKeyReservedTokens.String())
	if err != nil {
		panic(err)
	}

	return reservedTokens
}

// GetReservedTokens returns all token paths currently reserved for distribution.
//
// Returns:
//   - tokenPaths: Token paths present in the reserved-token index, in BP-tree iteration order.
func (s *protocolFeeStore) GetReservedTokens() []string {
	return collectTreeKeys(s.getReservedTokenTree())
}

// HasReservedToken reports whether tokenPath is currently reserved for distribution.
//
// Parameters:
//   - tokenPath: Token path to look up in the reserved-token index.
//
// Returns:
//   - exists: True when tokenPath is in the reserved-token index; false otherwise.
func (s *protocolFeeStore) HasReservedToken(tokenPath string) bool {
	return s.getReservedTokenTree().Has(tokenPath)
}

// AddReservedToken adds tokenPath to the reserved-token index.
//
// Parameters:
//   - _: Crossing discriminator for the store operation; pass 0.
//   - rlm: Propagated realm context for this store write; it must be current (`rlm.IsCurrent()`).
//   - tokenPath: Token path collected for protocol-fee distribution.
//
// Returns:
//   - err: Nil when tokenPath is already present or has been added; otherwise the current-realm or KV-store write error.
func (s *protocolFeeStore) AddReservedToken(_ int, rlm realm, tokenPath string) error {
	if !rlm.IsCurrent() {
		return errors.New(errSpoofedRealm)
	}

	reservedTokens := s.getReservedTokenTree()
	if reservedTokens.Has(tokenPath) {
		return nil
	}

	reservedTokens.Set(tokenPath, true)

	return s.kvStore.Set(0, rlm, StoreKeyReservedTokens.String(), reservedTokens)
}

// RemoveReservedToken removes one tokenPath from the reserved-token set when present.
//
// Parameters:
//   - _: Crossing discriminator for the store operation; pass 0.
//   - rlm: Propagated realm context for this store write; it must be current (`rlm.IsCurrent()`).
//   - tokenPath: Token path to remove from the reserved-token set.
//
// Returns:
//   - err: Nil when tokenPath is absent or has been removed; otherwise the current-realm or KV-store write error.
func (s *protocolFeeStore) RemoveReservedToken(_ int, rlm realm, tokenPath string) error {
	if !rlm.IsCurrent() {
		return errors.New(errSpoofedRealm)
	}

	reservedTokens := s.getReservedTokenTree()
	if _, removed := reservedTokens.Remove(tokenPath); !removed {
		return nil
	}

	return s.kvStore.Set(0, rlm, StoreKeyReservedTokens.String(), reservedTokens)
}

// handle accrualEpoch store data
//
// accrualEpoch numbers the intervals between gov/staker stake changes. gov/staker
// advances it on every stake change, so every fee that arrives is attributed to the
// stake distribution in force when it arrived.
//
// Returns:
//   - exists: True when the accrual-epoch store key is present in the KV store.
func (s *protocolFeeStore) HasAccrualEpochStoreKey() bool {
	return s.kvStore.Has(StoreKeyAccrualEpoch.String())
}

// InitializeAccrualEpoch initializes the current fee-accrual epoch to zero.
//
// Parameters:
//   - _: Crossing discriminator for the store operation; pass 0.
//   - rlm: Propagated realm context for this store write; it must be current (`rlm.IsCurrent()`).
//
// Returns:
//   - err: Nil when the epoch key is initialized; otherwise the current-realm or KV-store write error.
func (s *protocolFeeStore) InitializeAccrualEpoch(_ int, rlm realm) error {
	if !rlm.IsCurrent() {
		return errors.New(errSpoofedRealm)
	}

	return s.kvStore.Set(0, rlm, StoreKeyAccrualEpoch.String(), int64(0))
}

// GetAccrualEpoch reads the epoch under which new Gov/Staker accrual buckets are recorded.
//
// Returns:
//   - epoch: The persisted current accrual epoch; the method panics if the key is missing or cannot be decoded as int64.
func (s *protocolFeeStore) GetAccrualEpoch() int64 {
	accrualEpoch, err := s.kvStore.GetInt64(StoreKeyAccrualEpoch.String())
	if err != nil {
		panic(err)
	}

	return accrualEpoch
}

// SetAccrualEpoch persists the current fee-accrual epoch.
//
// Parameters:
//   - _: Crossing discriminator for the store operation; pass 0.
//   - rlm: Propagated realm context for this store write; it must be current (`rlm.IsCurrent()`).
//   - accrualEpoch: Epoch number assigned to newly collected Gov/Staker accrual buckets.
//
// Returns:
//   - err: Nil when the epoch is persisted; otherwise the current-realm or KV-store write error.
func (s *protocolFeeStore) SetAccrualEpoch(_ int, rlm realm, accrualEpoch int64) error {
	if !rlm.IsCurrent() {
		return errors.New(errSpoofedRealm)
	}

	return s.kvStore.Set(0, rlm, StoreKeyAccrualEpoch.String(), accrualEpoch)
}

// handle accrualBuckets store data
//
// accrualBuckets holds, per token path, the gov/staker share collected during each
// accrual epoch that gov/staker has not folded into its accumulator yet. Folding
// consumes the oldest buckets first, so a token is settled in epoch order.
//
// Returns:
//   - exists: True when the accrual-bucket store key is present in the KV store.
func (s *protocolFeeStore) HasAccrualBucketsStoreKey() bool {
	return s.kvStore.Has(StoreKeyAccrualBuckets.String())
}

// InitializeAccrualBuckets creates the nested accrual-bucket tree.
//
// Parameters:
//   - _: Crossing discriminator for the store operation; pass 0.
//   - rlm: Propagated realm context for this store write; it must be current (`rlm.IsCurrent()`).
//
// Returns:
//   - err: Nil when the bucket tree is initialized; otherwise the current-realm or KV-store write error.
func (s *protocolFeeStore) InitializeAccrualBuckets(_ int, rlm realm) error {
	if !rlm.IsCurrent() {
		return errors.New(errSpoofedRealm)
	}

	return s.kvStore.Set(0, rlm, StoreKeyAccrualBuckets.String(), NewBPTreeN(16))
}

// getAccrualBucketTree reads the top-level token-to-epoch bucket tree.
//
// Returns:
//   - tree: The BP-tree containing per-token accrual bucket trees; the method panics if the store value is absent or has the wrong type.
func (s *protocolFeeStore) getAccrualBucketTree() *bptree.BPTree {
	accrualBuckets, err := s.kvStore.GetBPTree(StoreKeyAccrualBuckets.String())
	if err != nil {
		panic(err)
	}

	return accrualBuckets
}

// getTokenAccrualBucketTree gets the epoch bucket tree for one token.
//
// Parameters:
//   - accrualBuckets: Top-level tree mapping token paths to their epoch bucket trees.
//   - tokenPath: Token path whose epoch bucket tree should be retrieved.
//
// Returns:
//   - tree: The token's epoch-to-amount BP-tree, or nil when tokenPath has no buckets; the method panics when the stored value has the wrong type.
func (s *protocolFeeStore) getTokenAccrualBucketTree(accrualBuckets *bptree.BPTree, tokenPath string) *bptree.BPTree {
	result := accrualBuckets.Get(tokenPath)
	if result == nil {
		return nil
	}

	tokenBuckets, ok := result.(*bptree.BPTree)
	if !ok {
		panic(ufmt.Errorf("failed to cast result to *bptree.BPTree: %T", result))
	}

	return tokenBuckets
}

// GetAccrualBuckets returns up to limit of the oldest pending buckets of tokenPath in
// epoch order. A limit of zero or less returns every pending bucket.
//
// Parameters:
//   - tokenPath: Token path whose pending Gov/Staker accrual buckets should be read.
//   - limit: Maximum number of buckets to return; zero or a negative value returns all pending buckets.
//
// Returns:
//   - epochs: Epoch numbers for the returned buckets, in ascending BP-tree iteration order.
//   - amounts: Gov/Staker amounts for the returned epochs; amounts[i] corresponds to epochs[i].
func (s *protocolFeeStore) GetAccrualBuckets(tokenPath string, limit int) ([]int64, []int64) {
	epochs := []int64{}
	amounts := []int64{}

	tokenBuckets := s.getTokenAccrualBucketTree(s.getAccrualBucketTree(), tokenPath)
	if tokenBuckets == nil {
		return epochs, amounts
	}

	tokenBuckets.Iterate("", "", func(key string, value any) bool {
		if limit > 0 && len(epochs) >= limit {
			return true
		}

		amount, ok := value.(int64)
		if !ok {
			panic(ufmt.Errorf("failed to cast result to int64: %T", value))
		}

		epochs = append(epochs, decodeEpochKey(key))
		amounts = append(amounts, amount)

		return false
	})

	return epochs, amounts
}

// AddAccrualBucket adds amount to the bucket of tokenPath at epoch.
//
// Parameters:
//   - _: Crossing discriminator for the store operation; pass 0.
//   - rlm: Propagated realm context for this store write; it must be current (`rlm.IsCurrent()`).
//   - tokenPath: Token path whose Gov/Staker accrual bucket is updated.
//   - epoch: Non-negative accrual epoch identifying the bucket; negative epochs panic during key encoding.
//   - amount: Amount to add to the existing bucket value.
//
// Returns:
//   - err: Nil when the bucket tree is persisted; otherwise the current-realm or KV-store write error.
func (s *protocolFeeStore) AddAccrualBucket(_ int, rlm realm, tokenPath string, epoch int64, amount int64) error {
	if !rlm.IsCurrent() {
		return errors.New(errSpoofedRealm)
	}

	accrualBuckets := s.getAccrualBucketTree()
	tokenBuckets := s.getTokenAccrualBucketTree(accrualBuckets, tokenPath)
	if tokenBuckets == nil {
		tokenBuckets = NewBPTreeN(16)
		accrualBuckets.Set(tokenPath, tokenBuckets)
	}

	key := encodeEpochKey(epoch)
	existing := int64(0)
	if result := tokenBuckets.Get(key); result != nil {
		current, ok := result.(int64)
		if !ok {
			panic(ufmt.Errorf("failed to cast result to int64: %T", result))
		}
		existing = current
	}

	tokenBuckets.Set(key, gnsmath.SafeAddInt64(existing, amount))

	return s.kvStore.Set(0, rlm, StoreKeyAccrualBuckets.String(), accrualBuckets)
}

// RemoveAccrualBuckets drops the buckets of tokenPath at the given epochs. The token's
// tree is dropped as well once no bucket remains.
//
// Parameters:
//   - _: Crossing discriminator for the store operation; pass 0.
//   - rlm: Propagated realm context for this store write; it must be current (`rlm.IsCurrent()`).
//   - tokenPath: Token path whose selected accrual buckets are removed.
//   - epochs: Epoch numbers whose buckets should be deleted; an absent token or epoch is ignored.
//
// Returns:
//   - err: Nil when removals are applied (including an absent token); otherwise the current-realm or KV-store write error.
func (s *protocolFeeStore) RemoveAccrualBuckets(_ int, rlm realm, tokenPath string, epochs []int64) error {
	if !rlm.IsCurrent() {
		return errors.New(errSpoofedRealm)
	}

	accrualBuckets := s.getAccrualBucketTree()
	tokenBuckets := s.getTokenAccrualBucketTree(accrualBuckets, tokenPath)
	if tokenBuckets == nil {
		return nil
	}

	for _, epoch := range epochs {
		tokenBuckets.Remove(encodeEpochKey(epoch))
	}

	if tokenBuckets.Size() == 0 {
		accrualBuckets.Remove(tokenPath)
	}

	return s.kvStore.Set(0, rlm, StoreKeyAccrualBuckets.String(), accrualBuckets)
}

// handle accrualPendingTokens store data
//
// accrualPendingTokens is the set of token paths that still own at least one accrual
// bucket, so gov/staker can enumerate what it has to fold without scanning every token.
//
// Returns:
//   - exists: True when the pending-token index key is present in the KV store.
func (s *protocolFeeStore) HasAccrualPendingTokensStoreKey() bool {
	return s.kvStore.Has(StoreKeyAccrualPendingTokens.String())
}

// InitializeAccrualPendingTokens creates the index of tokens with pending accrual buckets.
//
// Parameters:
//   - _: Crossing discriminator for the store operation; pass 0.
//   - rlm: Propagated realm context for this store write; it must be current (`rlm.IsCurrent()`).
//
// Returns:
//   - err: Nil when the pending-token index is initialized; otherwise the current-realm or KV-store write error.
func (s *protocolFeeStore) InitializeAccrualPendingTokens(_ int, rlm realm) error {
	if !rlm.IsCurrent() {
		return errors.New(errSpoofedRealm)
	}

	return s.kvStore.Set(0, rlm, StoreKeyAccrualPendingTokens.String(), NewBPTreeN(16))
}

// getAccrualPendingTokenTree reads the pending-token index tree.
//
// Returns:
//   - tree: The BP-tree containing token paths with at least one pending bucket; the method panics if the store value is absent or has the wrong type.
func (s *protocolFeeStore) getAccrualPendingTokenTree() *bptree.BPTree {
	accrualPendingTokens, err := s.kvStore.GetBPTree(StoreKeyAccrualPendingTokens.String())
	if err != nil {
		panic(err)
	}

	return accrualPendingTokens
}

// GetAccrualPendingTokens returns token paths that still own accrual buckets.
//
// Returns:
//   - tokenPaths: Token paths in the pending-accrual index, in BP-tree iteration order.
func (s *protocolFeeStore) GetAccrualPendingTokens() []string {
	return collectTreeKeys(s.getAccrualPendingTokenTree())
}

// AddAccrualPendingToken adds tokenPath to the pending-accrual index.
//
// Parameters:
//   - _: Crossing discriminator for the store operation; pass 0.
//   - rlm: Propagated realm context for this store write; it must be current (`rlm.IsCurrent()`).
//   - tokenPath: Token path with at least one accrual bucket pending.
//
// Returns:
//   - err: Nil when tokenPath is already present or has been added; otherwise the current-realm or KV-store write error.
func (s *protocolFeeStore) AddAccrualPendingToken(_ int, rlm realm, tokenPath string) error {
	if !rlm.IsCurrent() {
		return errors.New(errSpoofedRealm)
	}

	accrualPendingTokens := s.getAccrualPendingTokenTree()
	if accrualPendingTokens.Has(tokenPath) {
		return nil
	}

	accrualPendingTokens.Set(tokenPath, true)

	return s.kvStore.Set(0, rlm, StoreKeyAccrualPendingTokens.String(), accrualPendingTokens)
}

// RemoveAccrualPendingToken drops one token from the set. It writes only when the
// token was listed.
//
// Parameters:
//   - _: Crossing discriminator for the store operation; pass 0.
//   - rlm: Propagated realm context for this store write; it must be current (`rlm.IsCurrent()`).
//   - tokenPath: Token path to remove from the pending-accrual index.
//
// Returns:
//   - err: Nil when tokenPath is absent or has been removed; otherwise the current-realm or KV-store write error.
func (s *protocolFeeStore) RemoveAccrualPendingToken(_ int, rlm realm, tokenPath string) error {
	if !rlm.IsCurrent() {
		return errors.New(errSpoofedRealm)
	}

	accrualPendingTokens := s.getAccrualPendingTokenTree()
	if _, removed := accrualPendingTokens.Remove(tokenPath); !removed {
		return nil
	}

	return s.kvStore.Set(0, rlm, StoreKeyAccrualPendingTokens.String(), accrualPendingTokens)
}

// collectTreeKeys returns every key in a BP-tree.
//
// Parameters:
//   - tree: BP-tree whose keys should be collected.
//
// Returns:
//   - keys: All keys visited in BP-tree iteration order.
func collectTreeKeys(tree *bptree.BPTree) []string {
	keys := make([]string, 0, tree.Size())
	tree.Iterate("", "", func(key string, _ any) bool {
		keys = append(keys, key)
		return false
	})

	return keys
}

// encodeEpochKey converts a non-negative accrual epoch to the ordered tree-key encoding.
//
// Parameters:
//   - epoch: Non-negative epoch number to encode; a negative value causes a panic.
//
// Returns:
//   - key: Uint64 encoding of epoch suitable for lexicographic BP-tree iteration.
func encodeEpochKey(epoch int64) string {
	if epoch < 0 {
		panic(ufmt.Sprintf("negative epoch not supported: %d", epoch))
	}

	return utils.EncodeUint64(uint64(epoch))
}

// decodeEpochKey converts an encoded accrual epoch tree key back to int64.
//
// Parameters:
//   - key: Uint64-encoded epoch key produced by encodeEpochKey.
//
// Returns:
//   - epoch: Decoded accrual epoch number.
func decodeEpochKey(key string) int64 {
	return gnsmath.SafeUint64ToInt64(utils.DecodeUint64(key))
}

// NewProtocolFeeStore creates a protocol-fee store backed by the provided KV store.
// This function is used by the upgrade system to create storage instances for each implementation.
//
// Parameters:
//   - kvStore: Domain KV store used to persist protocol-fee state.
//
// Returns:
//   - protocolFeeStore: An IProtocolFeeStore implementation backed by kvStore.
func NewProtocolFeeStore(kvStore store.KVStore) IProtocolFeeStore {
	return &protocolFeeStore{
		kvStore: kvStore,
	}
}
