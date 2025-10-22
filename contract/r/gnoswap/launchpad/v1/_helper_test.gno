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
		state: NewLaunchpadState(),
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
	state launchpad.LaunchpadState
}

func (s *testLaunchpadStore) GetProjects() *avl.Tree {
	if s.state == nil {
		return avl.NewTree()
	}
	return s.state.Projects()
}

func (s *testLaunchpadStore) SetProjects(projects *avl.Tree) error {
	// For test purposes, we don't actually update the state
	// as the state is managed internally
	return nil
}

func (s *testLaunchpadStore) GetProjectTierRewardManagers() *avl.Tree {
	if s.state == nil {
		return avl.NewTree()
	}
	return s.state.ProjectTierRewardManagers()
}

func (s *testLaunchpadStore) SetProjectTierRewardManagers(managers *avl.Tree) error {
	// For test purposes, we don't actually update the state
	return nil
}

func (s *testLaunchpadStore) GetDepositCounter() launchpad.Counter {
	if s.state == nil {
		return nil
	}
	return s.state.DepositCounter()
}

func (s *testLaunchpadStore) SetDepositCounter(counter launchpad.Counter) error {
	// For test purposes, we don't actually update the state
	return nil
}

func (s *testLaunchpadStore) GetDeposits() *avl.Tree {
	if s.state == nil {
		return avl.NewTree()
	}
	return s.state.Deposits()
}

func (s *testLaunchpadStore) SetDeposits(deposits *avl.Tree) error {
	// For test purposes, we don't actually update the state
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
		if state, ok := store.state.(*launchpadState); ok {
			state.projects = tree
		}
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
		if state, ok := store.state.(*launchpadState); ok {
			state.projectTierRewardManagers = tree
		}
	}
}

// getDeposit is a test helper to get a deposit by ID
func getDeposit(depositID string) (*Deposit, error) {
	if testStore == nil {
		return nil, makeErrorWithDetails(errNotExistDeposit, "test store not initialized")
	}
	lp := getTestImplementation()
	return lp.getDeposit(depositID)
}
