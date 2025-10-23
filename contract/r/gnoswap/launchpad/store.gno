package launchpad

import (
	"gno.land/p/gnoswap/store"
	"gno.land/p/nt/avl"
	"gno.land/p/nt/ufmt"
)

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
func (s *launchpadStore) GetProjects() *avl.Tree {
	result, err := s.kvStore.Get(StoreKeyProjects.String())
	if err != nil {
		return avl.NewTree()
	}

	projects, ok := result.(*avl.Tree)
	if !ok {
		panic(ufmt.Sprintf("failed to cast result to *avl.Tree: %T", result))
	}

	return projects
}

// SetProjects stores the projects tree.
func (s *launchpadStore) SetProjects(projects *avl.Tree) error {
	return s.kvStore.Set(StoreKeyProjects.String(), projects)
}

// HasProjectTierRewardManagersKey checks if the project tier reward managers key exists in the store.
func (s *launchpadStore) HasProjectTierRewardManagersKey() bool {
	return s.kvStore.Has(StoreKeyProjectTierRewardManagers.String())
}

// GetProjectTierRewardManagers retrieves the project tier reward managers tree.
func (s *launchpadStore) GetProjectTierRewardManagers() *avl.Tree {
	result, err := s.kvStore.Get(StoreKeyProjectTierRewardManagers.String())
	if err != nil {
		return avl.NewTree()
	}

	managers, ok := result.(*avl.Tree)
	if !ok {
		panic(ufmt.Sprintf("failed to cast result to *avl.Tree: %T", result))
	}

	return managers
}

// SetProjectTierRewardManagers stores the project tier reward managers tree.
func (s *launchpadStore) SetProjectTierRewardManagers(managers *avl.Tree) error {
	return s.kvStore.Set(StoreKeyProjectTierRewardManagers.String(), managers)
}

// HasDepositCounterKey checks if the deposit counter key exists in the store.
func (s *launchpadStore) HasDepositCounterKey() bool {
	return s.kvStore.Has(StoreKeyDepositCounter.String())
}

// GetDepositCounter retrieves the deposit counter.
func (s *launchpadStore) GetDepositCounter() Counter {
	result, err := s.kvStore.Get(StoreKeyDepositCounter.String())
	if err != nil {
		return nil
	}

	counter, ok := result.(Counter)
	if !ok {
		panic(ufmt.Sprintf("failed to cast result to Counter: %T", result))
	}

	return counter
}

// SetDepositCounter stores the deposit counter.
func (s *launchpadStore) SetDepositCounter(counter Counter) error {
	return s.kvStore.Set(StoreKeyDepositCounter.String(), counter)
}

// HasDepositsKey checks if the deposits key exists in the store.
func (s *launchpadStore) HasDepositsKey() bool {
	return s.kvStore.Has(StoreKeyDeposits.String())
}

// GetDeposits retrieves the deposits tree.
func (s *launchpadStore) GetDeposits() *avl.Tree {
	result, err := s.kvStore.Get(StoreKeyDeposits.String())
	if err != nil {
		return avl.NewTree()
	}

	deposits, ok := result.(*avl.Tree)
	if !ok {
		panic(ufmt.Sprintf("failed to cast result to *avl.Tree: %T", result))
	}

	return deposits
}

// SetDeposits stores the deposits tree.
func (s *launchpadStore) SetDeposits(deposits *avl.Tree) error {
	return s.kvStore.Set(StoreKeyDeposits.String(), deposits)
}

// NewLaunchpadStore creates a new launchpad store instance with the provided KV store.
// This function is used by the upgrade system to create storage instances for each implementation.
func NewLaunchpadStore(kvStore store.KVStore) ILaunchpadStore {
	return &launchpadStore{
		kvStore: kvStore,
	}
}
