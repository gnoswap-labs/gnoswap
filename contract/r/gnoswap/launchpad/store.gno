package launchpad

import (
	"strconv"

	"gno.land/p/gnoswap/store"
	avl "gno.land/p/nt/avl/v0"
	ufmt "gno.land/p/nt/ufmt/v0"
)

type StoreKey string

func (s StoreKey) String() string {
	return string(s)
}

const (
	StoreKeyProjects                  StoreKey = "projects"                  // Projects tree
	StoreKeyProjectTierRewardManagers StoreKey = "projectTierRewardManagers" // Project tier reward managers tree
	StoreKeyProjectIDs                StoreKey = "projectIDs"                // Project ID index tree
	StoreKeyProjectTierRewardManagerIDs StoreKey = "projectTierRewardManagerIDs" // Project tier reward manager ID index tree
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
		panic(err)
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

func makeStoreProjectKey(projectID string) string {
	return "project:" + projectID
}

func (s *launchpadStore) GetProject(projectID string) (*Project, bool) {
	storeKey := makeStoreProjectKey(projectID)
	if !s.kvStore.Has(storeKey) {
		return nil, false
	}

	result, err := s.kvStore.Get(storeKey)
	if err != nil {
		panic(err)
	}

	project, ok := result.(*Project)
	if !ok {
		panic(ufmt.Sprintf("failed to cast result to *Project: %T", result))
	}

	return project, true
}

func (s *launchpadStore) SetProject(projectID string, project *Project) error {
	return s.kvStore.Set(makeStoreProjectKey(projectID), project)
}

func (s *launchpadStore) HasProjectIDsKey() bool {
	return s.kvStore.Has(StoreKeyProjectIDs.String())
}

func (s *launchpadStore) GetProjectIDs() *avl.Tree {
	result, err := s.kvStore.Get(StoreKeyProjectIDs.String())
	if err != nil {
		panic(err)
	}

	projectIDs, ok := result.(*avl.Tree)
	if !ok {
		panic(ufmt.Sprintf("failed to cast result to *avl.Tree: %T", result))
	}

	return projectIDs
}

func (s *launchpadStore) SetProjectIDs(projectIDs *avl.Tree) error {
	return s.kvStore.Set(StoreKeyProjectIDs.String(), projectIDs)
}

// HasProjectTierRewardManagersKey checks if the project tier reward managers key exists in the store.
func (s *launchpadStore) HasProjectTierRewardManagersKey() bool {
	return s.kvStore.Has(StoreKeyProjectTierRewardManagers.String())
}

// GetProjectTierRewardManagers retrieves the project tier reward managers tree.
func (s *launchpadStore) GetProjectTierRewardManagers() *avl.Tree {
	result, err := s.kvStore.Get(StoreKeyProjectTierRewardManagers.String())
	if err != nil {
		panic(err)
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

func makeStoreProjectTierRewardManagerKey(projectTierID string) string {
	return "projectTierRewardManager:" + projectTierID
}

func (s *launchpadStore) GetProjectTierRewardManager(projectTierID string) (*RewardManager, bool) {
	storeKey := makeStoreProjectTierRewardManagerKey(projectTierID)
	if !s.kvStore.Has(storeKey) {
		return nil, false
	}

	result, err := s.kvStore.Get(storeKey)
	if err != nil {
		panic(err)
	}

	manager, ok := result.(*RewardManager)
	if !ok {
		panic(ufmt.Sprintf("failed to cast result to *RewardManager: %T", result))
	}

	return manager, true
}

func (s *launchpadStore) SetProjectTierRewardManager(projectTierID string, manager *RewardManager) error {
	return s.kvStore.Set(makeStoreProjectTierRewardManagerKey(projectTierID), manager)
}

func (s *launchpadStore) HasProjectTierRewardManagerIDsKey() bool {
	return s.kvStore.Has(StoreKeyProjectTierRewardManagerIDs.String())
}

func (s *launchpadStore) GetProjectTierRewardManagerIDs() *avl.Tree {
	result, err := s.kvStore.Get(StoreKeyProjectTierRewardManagerIDs.String())
	if err != nil {
		panic(err)
	}

	managerIDs, ok := result.(*avl.Tree)
	if !ok {
		panic(ufmt.Sprintf("failed to cast result to *avl.Tree: %T", result))
	}

	return managerIDs
}

func (s *launchpadStore) SetProjectTierRewardManagerIDs(managerIDs *avl.Tree) error {
	return s.kvStore.Set(StoreKeyProjectTierRewardManagerIDs.String(), managerIDs)
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

func (s *launchpadStore) SetDepositCounter(counter *Counter) error {
	return s.kvStore.Set(StoreKeyDepositCounter.String(), counter)
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
func (s *launchpadStore) GetDeposits() *avl.Tree {
	result, err := s.kvStore.Get(StoreKeyDeposits.String())
	if err != nil {
		panic(err)
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
