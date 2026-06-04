package launchpad

import (
	"strconv"

	"gno.land/p/gnoswap/store"
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
func NewBPTreeN(fanout int) *bptree.BPTree {
	return bptree.NewBPTreeN(fanout)
}

type StoreKey string

func (s StoreKey) String() string {
	return string(s)
}

const (
	StoreKeyProjects                  StoreKey = "projects"                  // Projects tree
	StoreKeyProjectTierRewardManagers StoreKey = "projectTierRewardManagers" // Project tier reward managers tree
	StoreKeyDepositCounter            StoreKey = "depositCounter"            // Deposit counter
	StoreKeyDeposits                  StoreKey = "deposits"                  // Deposits tree
)

type launchpadStore struct {
	kvStore store.KVStore
}

// HasProjectsKey checks if the projects key exists in the store.
func (s *launchpadStore) HasProjectsKey() bool {
	return s.kvStore.Has(StoreKeyProjects.String())
}

// GetProjects retrieves the projects tree.
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
func (s *launchpadStore) SetProjects(_ int, rlm realm, projects *bptree.BPTree) error {
	if !rlm.IsCurrent() {
		return ErrSpoofedRealm
	}

	return s.kvStore.Set(0, rlm, StoreKeyProjects.String(), projects)
}

// HasProjectTierRewardManagersKey checks if the project tier reward managers key exists in the store.
func (s *launchpadStore) HasProjectTierRewardManagersKey() bool {
	return s.kvStore.Has(StoreKeyProjectTierRewardManagers.String())
}

// GetProjectTierRewardManagers retrieves the project tier reward managers tree.
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
func (s *launchpadStore) SetProjectTierRewardManagers(_ int, rlm realm, managers *bptree.BPTree) error {
	if !rlm.IsCurrent() {
		return ErrSpoofedRealm
	}

	return s.kvStore.Set(0, rlm, StoreKeyProjectTierRewardManagers.String(), managers)
}

// HasDepositCounterStoreKey checks if the deposit counter key exists in the store.
func (s *launchpadStore) HasDepositCounterStoreKey() bool {
	return s.kvStore.Has(StoreKeyDepositCounter.String())
}

// GetDepositCounter retrieves the deposit counter.
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

func (s *launchpadStore) SetDepositCounter(_ int, rlm realm, counter *Counter) error {
	if !rlm.IsCurrent() {
		return ErrSpoofedRealm
	}

	return s.kvStore.Set(0, rlm, StoreKeyDepositCounter.String(), counter)
}

func (s *launchpadStore) NextDepositID() string {
	counter := s.GetDepositCounter()

	return strconv.FormatInt(counter.Next(), 10)
}

// SetDepositCounter stores the deposit counter.
// HasDepositsKey checks if the deposits key exists in the store.
func (s *launchpadStore) HasDepositsKey() bool {
	return s.kvStore.Has(StoreKeyDeposits.String())
}

// GetDeposits retrieves the deposits tree.
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
func (s *launchpadStore) SetDeposits(_ int, rlm realm, deposits *bptree.BPTree) error {
	if !rlm.IsCurrent() {
		return ErrSpoofedRealm
	}

	return s.kvStore.Set(0, rlm, StoreKeyDeposits.String(), deposits)
}

// NewLaunchpadStore creates a new launchpad store instance with the provided KV store.
// This function is used by the upgrade system to create storage instances for each implementation.
func NewLaunchpadStore(kvStore store.KVStore) ILaunchpadStore {
	return &launchpadStore{
		kvStore: kvStore,
	}
}
