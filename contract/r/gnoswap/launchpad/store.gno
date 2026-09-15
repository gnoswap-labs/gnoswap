package launchpad

import (
	"errors"
	"strconv"

	"gno.land/p/gnoswap/store/v1"
	bptree "gno.land/p/nt/bptree/v0"
	ufmt "gno.land/p/nt/ufmt/v0"
)

// NewBPTreeN allocates a BP-tree under /r/gnoswap/launchpad's realm context
// (the realm that declares Project/Deposit/RewardManager). The tree's PkgID is
// therefore /r/gnoswap/launchpad, matching the domain values it stores, so
// tree.Set leaf-slot writes clear the readonly-taint gate regardless of which
// realm (launchpad/v1, mock, tests) calls Set. Implementations, mocks, and
// tests must allocate launchpad trees through here rather than calling
// bptree.NewBPTreeN directly in their own realm.
//
// Parameters:
//   - fanout: branching factor passed to the BP-tree constructor.
//
// Returns:
//   - tree: new BP-tree allocated under the launchpad realm's package context.
func NewBPTreeN(fanout int) *bptree.BPTree {
	return bptree.NewBPTreeN(fanout)
}

type StoreKey string

// String returns the textual key represented by this StoreKey.
//
// Returns:
//   - key: store key string used by the KV store.
func (s StoreKey) String() string {
	return string(s)
}

const (
	StoreKeyProjects                  StoreKey = "projects"                  // Projects tree
	StoreKeyProjectRecipients         StoreKey = "projectRecipients"         // Recipient membership tree
	StoreKeyProjectTierRewardManagers StoreKey = "projectTierRewardManagers" // Project tier reward managers tree
	StoreKeyDepositCounter            StoreKey = "depositCounter"            // Deposit counter
	StoreKeyDeposits                  StoreKey = "deposits"                  // Deposits tree
	StoreKeyTotalGNSStakedAmount      StoreKey = "totalGNSStakedAmount"      // Total active launchpad GNS stake
)

type launchpadStore struct {
	kvStore store.KVStore
}

// HasProjectsKey checks if the projects key exists in the store.
//
// Returns:
//   - exists: true when the projects tree key is present in the KV store.
func (s *launchpadStore) HasProjectsKey() bool {
	return s.kvStore.Has(StoreKeyProjects.String())
}

// GetProjects retrieves the projects tree.
//
// Returns:
//   - projects: stored projects BP-tree keyed by project ID; the method panics if the key is missing or has the wrong type.
func (s *launchpadStore) GetProjects() *bptree.BPTree {
	result, err := s.kvStore.Get(StoreKeyProjects.String())
	if err != nil {
		panic(err)
	}

	projects, ok := result.(*bptree.BPTree)
	if !ok {
		panic(ufmt.Sprintf("failed to cast result to *bptree.BPTree: %T", result))
	}

	return projects
}

// SetProjects stores the projects tree.
//
// Parameters:
//   - _: cross-call discriminator; callers pass 0.
//   - rlm: propagated realm context; it must be current (`rlm.IsCurrent()`), otherwise the write returns ErrSpoofedRealm.
//   - projects: projects BP-tree to persist under the projects store key.
//
// Returns:
//   - err: nil when the tree is stored; non-nil for a spoofed realm or an underlying KV-store write failure.
func (s *launchpadStore) SetProjects(_ int, rlm realm, projects *bptree.BPTree) error {
	if !rlm.IsCurrent() {
		return errors.New(ErrSpoofedRealm)
	}

	return s.kvStore.Set(0, rlm, StoreKeyProjects.String(), projects)
}

// HasProjectRecipientsKey checks if the recipient membership tree exists.
//
// Returns:
//   - exists: true when the project-recipient membership key is present in the KV store.
func (s *launchpadStore) HasProjectRecipientsKey() bool {
	return s.kvStore.Has(StoreKeyProjectRecipients.String())
}

// GetProjectRecipients retrieves the recipient address membership tree.
//
// Returns:
//   - recipients: stored recipient-membership BP-tree keyed by address string; the method panics if the key is missing or has the wrong type.
func (s *launchpadStore) GetProjectRecipients() *bptree.BPTree {
	result, err := s.kvStore.Get(StoreKeyProjectRecipients.String())
	if err != nil {
		panic(err)
	}

	recipients, ok := result.(*bptree.BPTree)
	if !ok {
		panic(ufmt.Sprintf("failed to cast result to *bptree.BPTree: %T", result))
	}

	return recipients
}

// SetProjectRecipients stores the recipient membership tree.
//
// Parameters:
//   - _: cross-call discriminator; callers pass 0.
//   - rlm: propagated realm context; it must be current (`rlm.IsCurrent()`), otherwise the write returns ErrSpoofedRealm.
//   - recipients: recipient-membership BP-tree to persist.
//
// Returns:
//   - err: nil when the tree is stored; non-nil for a spoofed realm or an underlying KV-store write failure.
func (s *launchpadStore) SetProjectRecipients(_ int, rlm realm, recipients *bptree.BPTree) error {
	if !rlm.IsCurrent() {
		return errors.New(ErrSpoofedRealm)
	}

	return s.kvStore.Set(0, rlm, StoreKeyProjectRecipients.String(), recipients)
}

// HasProjectTierRewardManagersKey checks if the project tier reward managers key exists in the store.
//
// Returns:
//   - exists: true when the project-tier reward-manager key is present in the KV store.
func (s *launchpadStore) HasProjectTierRewardManagersKey() bool {
	return s.kvStore.Has(StoreKeyProjectTierRewardManagers.String())
}

// GetProjectTierRewardManagers retrieves the project tier reward managers tree.
//
// Returns:
//   - managers: stored reward-manager BP-tree keyed by project-tier ID; the method panics if the key is missing or has the wrong type.
func (s *launchpadStore) GetProjectTierRewardManagers() *bptree.BPTree {
	result, err := s.kvStore.Get(StoreKeyProjectTierRewardManagers.String())
	if err != nil {
		panic(err)
	}

	managers, ok := result.(*bptree.BPTree)
	if !ok {
		panic(ufmt.Sprintf("failed to cast result to *bptree.BPTree: %T", result))
	}

	return managers
}

// SetProjectTierRewardManagers stores the project tier reward managers tree.
//
// Parameters:
//   - _: cross-call discriminator; callers pass 0.
//   - rlm: propagated realm context; it must be current (`rlm.IsCurrent()`), otherwise the write returns ErrSpoofedRealm.
//   - managers: project-tier reward-manager BP-tree to persist.
//
// Returns:
//   - err: nil when the tree is stored; non-nil for a spoofed realm or an underlying KV-store write failure.
func (s *launchpadStore) SetProjectTierRewardManagers(_ int, rlm realm, managers *bptree.BPTree) error {
	if !rlm.IsCurrent() {
		return errors.New(ErrSpoofedRealm)
	}

	return s.kvStore.Set(0, rlm, StoreKeyProjectTierRewardManagers.String(), managers)
}

// HasDepositCounterStoreKey checks if the deposit counter key exists in the store.
//
// Returns:
//   - exists: true when the deposit-counter key is present in the KV store.
func (s *launchpadStore) HasDepositCounterStoreKey() bool {
	return s.kvStore.Has(StoreKeyDepositCounter.String())
}

// GetDepositCounter retrieves the deposit counter.
//
// Returns:
//   - counter: stored deposit counter; the method panics if the key is missing or has the wrong type.
func (s *launchpadStore) GetDepositCounter() *Counter {
	result, err := s.kvStore.Get(StoreKeyDepositCounter.String())
	if err != nil {
		panic(err)
	}

	counter, ok := result.(*Counter)
	if !ok {
		panic(ufmt.Sprintf("failed to cast result to Counter: %T", result))
	}

	return counter
}

// SetDepositCounter stores the deposit counter under its dedicated key.
//
// Parameters:
//   - _: cross-call discriminator; callers pass 0.
//   - rlm: propagated realm context; it must be current (`rlm.IsCurrent()`), otherwise the write returns ErrSpoofedRealm.
//   - counter: deposit counter to persist.
//
// Returns:
//   - err: nil when the counter is stored; non-nil for a spoofed realm or an underlying KV-store write failure.
func (s *launchpadStore) SetDepositCounter(_ int, rlm realm, counter *Counter) error {
	if !rlm.IsCurrent() {
		return errors.New(ErrSpoofedRealm)
	}

	return s.kvStore.Set(0, rlm, StoreKeyDepositCounter.String(), counter)
}

// NextDepositID increments the stored deposit counter and formats the new value as a decimal ID.
//
// Returns:
//   - depositID: next monotonically increasing deposit ID as a decimal string; the counter is incremented before formatting.
func (s *launchpadStore) NextDepositID() string {
	counter := s.GetDepositCounter()

	return strconv.FormatInt(counter.Next(), 10)
}

// HasDepositsKey checks if the deposits key exists in the store.
//
// Returns:
//   - exists: true when the deposits tree key is present in the KV store.
func (s *launchpadStore) HasDepositsKey() bool {
	return s.kvStore.Has(StoreKeyDeposits.String())
}

// GetDeposits retrieves the deposits tree.
//
// Returns:
//   - deposits: stored deposits BP-tree keyed by deposit ID; the method panics if the key is missing or has the wrong type.
func (s *launchpadStore) GetDeposits() *bptree.BPTree {
	result, err := s.kvStore.Get(StoreKeyDeposits.String())
	if err != nil {
		panic(err)
	}

	deposits, ok := result.(*bptree.BPTree)
	if !ok {
		panic(ufmt.Sprintf("failed to cast result to *bptree.BPTree: %T", result))
	}

	return deposits
}

// SetDeposits stores the deposits tree.
//
// Parameters:
//   - _: cross-call discriminator; callers pass 0.
//   - rlm: propagated realm context; it must be current (`rlm.IsCurrent()`), otherwise the write returns ErrSpoofedRealm.
//   - deposits: deposits BP-tree to persist.
//
// Returns:
//   - err: nil when the tree is stored; non-nil for a spoofed realm or an underlying KV-store write failure.
func (s *launchpadStore) SetDeposits(_ int, rlm realm, deposits *bptree.BPTree) error {
	if !rlm.IsCurrent() {
		return errors.New(ErrSpoofedRealm)
	}

	return s.kvStore.Set(0, rlm, StoreKeyDeposits.String(), deposits)
}

// HasTotalGNSStakedAmountKey checks if the total active GNS stake key exists in the store.
//
// Returns:
//   - exists: true when the total-GNS-staked amount key is present in the KV store.
func (s *launchpadStore) HasTotalGNSStakedAmountKey() bool {
	return s.kvStore.Has(StoreKeyTotalGNSStakedAmount.String())
}

// GetTotalGNSStakedAmount retrieves the total active GNS amount tracked by the store.
//
// Returns:
//   - amount: total currently staked GNS in base units; the method panics if the key is missing or has the wrong type.
func (s *launchpadStore) GetTotalGNSStakedAmount() int64 {
	result, err := s.kvStore.Get(StoreKeyTotalGNSStakedAmount.String())
	if err != nil {
		panic(err)
	}

	amount, ok := result.(int64)
	if !ok {
		panic(ufmt.Sprintf("failed to cast result to int64: %T", result))
	}

	return amount
}

// SetTotalGNSStakedAmount stores the total active GNS amount.
//
// Parameters:
//   - _: cross-call discriminator; callers pass 0.
//   - rlm: propagated realm context; it must be current (`rlm.IsCurrent()`), otherwise the write returns ErrSpoofedRealm.
//   - amount: total currently staked GNS in base units.
//
// Returns:
//   - err: nil when the amount is stored; non-nil for a spoofed realm or an underlying KV-store write failure.
func (s *launchpadStore) SetTotalGNSStakedAmount(_ int, rlm realm, amount int64) error {
	if !rlm.IsCurrent() {
		return errors.New(ErrSpoofedRealm)
	}

	return s.kvStore.Set(0, rlm, StoreKeyTotalGNSStakedAmount.String(), amount)
}

// NewLaunchpadStore creates a new launchpad store instance with the provided KV store.
// This function is used by the upgrade system to create storage instances for each implementation.
//
// Parameters:
//   - kvStore: key-value store used to persist launchpad state.
//
// Returns:
//   - launchpadStore: storage implementation backed by kvStore.
func NewLaunchpadStore(kvStore store.KVStore) ILaunchpadStore {
	return &launchpadStore{
		kvStore: kvStore,
	}
}
