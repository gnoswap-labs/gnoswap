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
	StoreKeyDepositCounter            StoreKey = "depositCounter"            // Deposit counter
	StoreKeyDeposits                  StoreKey = "deposits"                  // Deposits tree
)

func makeDepositStoreKey(depositID string) string {
	return ufmt.Sprintf("%s:%s", StoreKeyDeposits.String(), depositID)
}

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

func (s *launchpadStore) HasDeposit(depositID string) bool {
	if s.kvStore.Has(makeDepositStoreKey(depositID)) {
		return true
	}

	if !s.HasDepositsKey() {
		return false
	}

	deposits := s.GetDeposits()
	_, ok := deposits.Get(depositID)
	return ok
}

func (s *launchpadStore) GetDeposit(depositID string) (*Deposit, bool) {
	depositStoreKey := makeDepositStoreKey(depositID)

	if s.kvStore.Has(depositStoreKey) {
		result, err := s.kvStore.Get(depositStoreKey)
		if err != nil {
			panic(err)
		}

		deposit, ok := result.(*Deposit)
		if !ok {
			panic(ufmt.Sprintf("failed to cast result to *Deposit: %T", result))
		}

		return deposit, true
	}

	if !s.HasDepositsKey() {
		return nil, false
	}

	deposits := s.GetDeposits()
	value, ok := deposits.Get(depositID)
	if !ok {
		return nil, false
	}

	deposit, ok := value.(*Deposit)
	if !ok {
		panic(ufmt.Sprintf("failed to cast result to *Deposit: %T", value))
	}

	return deposit, true
}

func (s *launchpadStore) SetDeposit(depositID string, deposit *Deposit) error {
	return s.kvStore.Set(makeDepositStoreKey(depositID), deposit)
}

// NewLaunchpadStore creates a new launchpad store instance with the provided KV store.
// This function is used by the upgrade system to create storage instances for each implementation.
func NewLaunchpadStore(kvStore store.KVStore) ILaunchpadStore {
	return &launchpadStore{
		kvStore: kvStore,
	}
}
