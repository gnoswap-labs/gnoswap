package v1

import (
	"gno.land/p/nt/avl"
	"gno.land/r/gnoswap/launchpad"
)

// Test helper functions to access and manipulate state for testing purposes

// getTestStore returns the launchpad store for testing
func getTestStore() launchpad.ILaunchpadStore {
	return testStore
}

// getTestImplementation returns the launchpad implementation for testing
func getTestImplementation() *launchpadV1 {
	if testStore == nil {
		initTestStore()
	}
	if testImpl == nil {
		impl := NewLaunchpadV1(getTestStore())
		testImpl = impl.(*launchpadV1)
	}
	return testImpl
}

var (
	testStore launchpad.ILaunchpadStore
	testImpl  *launchpadV1
)

// initTestStore initializes a new test store
func initTestStore() {
	testStore = &testLaunchpadStore{
		projects:                  avl.NewTree(),
		projectTierRewardManagers: avl.NewTree(),
		depositCounter:            launchpad.NewCounter(),
		deposits:                  avl.NewTree(),
	}
	impl := NewLaunchpadV1(testStore)
	testImpl = impl.(*launchpadV1)
}

// resetTestStore resets the test store completely for a fresh start
func resetTestStore() {
	testStore = nil
	testImpl = nil
	initTestStore()
}

type testLaunchpadStore struct {
	projects                  *avl.Tree
	projectTierRewardManagers *avl.Tree
	depositCounter            *launchpad.Counter
	deposits                  *avl.Tree
}

func (s *testLaunchpadStore) HasProjectsKey() bool {
	return s.projects != nil
}

func (s *testLaunchpadStore) GetProjects() *avl.Tree {
	if s.projects == nil {
		return avl.NewTree()
	}
	return s.projects
}

func (s *testLaunchpadStore) SetProjects(projects *avl.Tree) error {
	s.projects = projects
	return nil
}

func (s *testLaunchpadStore) HasProjectTierRewardManagersKey() bool {
	return s.projectTierRewardManagers != nil
}

func (s *testLaunchpadStore) GetProjectTierRewardManagers() *avl.Tree {
	if s.projectTierRewardManagers == nil {
		return avl.NewTree()
	}
	return s.projectTierRewardManagers
}

func (s *testLaunchpadStore) SetProjectTierRewardManagers(managers *avl.Tree) error {
	s.projectTierRewardManagers = managers
	return nil
}

func (s *testLaunchpadStore) HasDepositCounterStoreKey() bool {
	return s.depositCounter != nil
}

func (s *testLaunchpadStore) GetDepositCounter() *launchpad.Counter {
	return s.depositCounter
}

func (s *testLaunchpadStore) SetDepositCounter(counter *launchpad.Counter) error {
	s.depositCounter = counter
	return nil
}

func (s *testLaunchpadStore) NextDepositID() string {
	return s.depositCounter.Next()
}

func (s *testLaunchpadStore) HasDepositsKey() bool {
	return s.deposits != nil
}

func (s *testLaunchpadStore) GetDeposits() *avl.Tree {
	if s.deposits == nil {
		return avl.NewTree()
	}
	return s.deposits
}

func (s *testLaunchpadStore) SetDeposits(deposits *avl.Tree) error {
	s.deposits = deposits
	return nil
}

// Test helper functions to access state

// getTestProjects returns the projects tree
func getTestProjects() *avl.Tree {
	if testStore == nil {
		return avl.NewTree()
	}
	return testStore.GetProjects()
}

// setTestProjects sets the projects tree
func setTestProjects(tree *avl.Tree) {
	if testStore == nil {
		initTestStore()
	}
	// Direct assignment for test purposes
	if store, ok := testStore.(*testLaunchpadStore); ok {
		store.projects = tree
	}
}

// getTestProjectTierRewardManagers returns the projectTierRewardManagers tree
func getTestProjectTierRewardManagers() *avl.Tree {
	if testStore == nil {
		return avl.NewTree()
	}
	return testStore.GetProjectTierRewardManagers()
}

// setTestProjectTierRewardManagers sets the projectTierRewardManagers tree
func setTestProjectTierRewardManagers(tree *avl.Tree) {
	if testStore == nil {
		initTestStore()
	}
	// Direct assignment for test purposes
	if store, ok := testStore.(*testLaunchpadStore); ok {
		store.projectTierRewardManagers = tree
	}
}

// getDeposit is a test helper to get a deposit by ID
func getDeposit(depositID string) (*launchpad.Deposit, error) {
	if testStore == nil {
		return nil, makeErrorWithDetails(errNotExistDeposit, "test store not initialized")
	}
	lp := getTestImplementation()
	return lp.getDeposit(depositID)
}
