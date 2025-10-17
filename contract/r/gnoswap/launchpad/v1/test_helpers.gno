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

func (s *testLaunchpadStore) GetLaunchpadState() launchpad.LaunchpadState {
	return s.state
}

func (s *testLaunchpadStore) SetLaunchpadState(state launchpad.LaunchpadState) error {
	s.state = state
	return nil
}

// Test helper functions to access state

// getTestProjects returns the projects tree
func getTestProjects() *avl.Tree {
	if testStore == nil {
		return avl.NewTree()
	}
	lp := getTestImplementation()
	state := lp.getLaunchpadState()
	return state.Projects()
}

// setTestProjects sets the projects tree
func setTestProjects(tree *avl.Tree) {
	if testStore == nil {
		initTestStore()
	}
	lp := getTestImplementation()
	state := lp.getLaunchpadState()
	state.projects = tree
}

// getTestProjectTierRewardManagers returns the projectTierRewardManagers tree
func getTestProjectTierRewardManagers() *avl.Tree {
	if testStore == nil {
		return avl.NewTree()
	}
	lp := getTestImplementation()
	state := lp.getLaunchpadState()
	return state.ProjectTierRewardManagers()
}

// setTestProjectTierRewardManagers sets the projectTierRewardManagers tree
func setTestProjectTierRewardManagers(tree *avl.Tree) {
	if testStore == nil {
		initTestStore()
	}
	lp := getTestImplementation()
	state := lp.getLaunchpadState()
	state.projectTierRewardManagers = tree
}

// getTestDeposits returns the deposits tree
func getTestDeposits() *avl.Tree {
	if testStore == nil {
		return avl.NewTree()
	}
	lp := getTestImplementation()
	state := lp.getLaunchpadState()
	return state.Deposits()
}

// setTestDeposits sets the deposits tree
func setTestDeposits(tree *avl.Tree) {
	if testStore == nil {
		initTestStore()
	}
	lp := getTestImplementation()
	state := lp.getLaunchpadState()
	state.deposits = tree
}

// getTestDepositCounter returns the depositCounter
func getTestDepositCounter() launchpad.Counter {
	if testStore == nil {
		return NewCounter()
	}
	lp := getTestImplementation()
	state := lp.getLaunchpadState()
	return state.DepositCounter()
}

// setTestDepositCounter sets the depositCounter
func setTestDepositCounter(counter *Counter) {
	if testStore == nil {
		initTestStore()
	}
	lp := getTestImplementation()
	state := lp.getLaunchpadState()
	state.depositCounter = counter
}

// getDeposit is a test helper to get a deposit by ID
func getDeposit(depositID string) (*Deposit, error) {
	if testStore == nil {
		return nil, makeErrorWithDetails(errNotExistDeposit, "test store not initialized")
	}
	lp := getTestImplementation()
	return lp.getDeposit(depositID)
}
