package v1

import (
	"chain"
	"chain/runtime"
	"strconv"
	"testing"
	"time"

	prbac "gno.land/p/gnoswap/rbac"
	"gno.land/p/nt/avl"
	"gno.land/p/nt/testutils"

	"gno.land/r/gnoswap/access"
	"gno.land/r/gnoswap/gns"
	"gno.land/r/gnoswap/halt"
	"gno.land/r/gnoswap/launchpad"
	"gno.land/r/onbloc/obl"
)

const (
	testLaunchpadPkgPath = "gno.land/r/gnoswap/launchpad"
	testOblTokenPath     = "gno.land/r/onbloc/obl"
	testBlockTimeSeconds = int64(5)
)

// testEnvConfig holds environment configuration for test setup
type testEnvConfig struct {
	height      int64 // initial block height
	initialTime int64 // initial unix timestamp
}

// testProjectConfig holds project configuration for test setup
type testProjectConfig struct {
	name            string
	tokenPath       string
	rewardAmount    int64
	recipientSuffix string
	tier30Pct       int64
	tier90Pct       int64
	tier180Pct      int64
}

// testDepositConfig holds depositor configuration for test setup
type testDepositConfig struct {
	userSuffix    string
	depositAmount int64
	tier          int64
	depositDelay  int64 // heights to skip before this deposit
}

// =============================================================================
// Test Environment Setup Functions
// =============================================================================

// setupTestEnvironment initializes test environment with given config
// Returns launchpad address and admin realm
func setupTestEnvironment(t *testing.T, cfg testEnvConfig) (address, runtime.Realm) {
	resetTestStore()
	initTestStore()

	ctx := testing.GetContext()
	if cfg.height > 0 {
		ctx.Height = cfg.height
	} else {
		ctx.Height = 100
	}
	if cfg.initialTime > 0 {
		ctx.Time = time.Unix(cfg.initialTime, 0)
	}
	testing.SetContext(ctx)

	launchpadAddr := chain.PackageAddress(testLaunchpadPkgPath)
	adminAddr := access.MustGetAddress(prbac.ROLE_ADMIN.String())
	adminRealm := testing.NewUserRealm(adminAddr)

	testing.SetRealm(adminRealm)
	halt.SetHaltLevel(cross, halt.HaltLevelNone)

	return launchpadAddr, adminRealm
}

// =============================================================================
// Test Project Functions
// =============================================================================

// createTestProject creates a project with given config and returns project ID
func createTestProject(
	t *testing.T,
	lp *launchpadV1,
	launchpadAddr address,
	adminRealm runtime.Realm,
	cfg testProjectConfig,
) string {
	testing.SetRealm(adminRealm)

	tokenPath := cfg.tokenPath
	if tokenPath == "" {
		tokenPath = testOblTokenPath
	}

	if tokenPath == testOblTokenPath {
		obl.Approve(cross, launchpadAddr, cfg.rewardAmount)
	}

	startTime := testing.GetContext().Time.Unix() + projectMinimumStartDelayTime

	var projectID string
	func(cur realm) {
		testing.SetRealm(testing.NewCodeRealm(testLaunchpadPkgPath))

		name := cfg.name
		if name == "" {
			name = "Test Project"
		}

		projectID = lp.CreateProject(
			name,
			tokenPath,
			testutils.TestAddress(cfg.recipientSuffix),
			cfg.rewardAmount,
			"", "",
			cfg.tier30Pct, cfg.tier90Pct, cfg.tier180Pct,
			startTime,
		)
	}(cross)

	// Activate project by skipping past start time (add buffer to ensure activation)
	testing.SkipHeights(secondsToBlocks(projectMinimumStartDelayTime) + 20)

	return projectID
}

// createTestDeposit creates a deposit for given user and returns user address and deposit ID
func createTestDeposit(
	t *testing.T,
	lp *launchpadV1,
	launchpadAddr address,
	adminRealm runtime.Realm,
	projectID string,
	cfg testDepositConfig,
) (address, string) {
	if cfg.depositDelay > 0 {
		testing.SkipHeights(cfg.depositDelay)
	}

	userAddr := testutils.TestAddress(cfg.userSuffix)

	// Transfer GNS to user
	testing.SetRealm(adminRealm)
	gns.Transfer(cross, userAddr, cfg.depositAmount*2)

	// User approves and deposits
	testing.SetRealm(testing.NewUserRealm(userAddr))
	gns.Approve(cross, launchpadAddr, cfg.depositAmount)

	tier := cfg.tier
	if tier == 0 {
		tier = 30
	}

	var depositID string
	func(cur realm) {
		testing.SetRealm(testing.NewCodeRealm(testLaunchpadPkgPath))
		depositID = lp.DepositGns(projectID+":"+formatInt(tier), cfg.depositAmount, "")
	}(cross)

	return userAddr, depositID
}

// createTestDeposits creates multiple deposits and returns user addresses and deposit IDs
func createTestDeposits(
	t *testing.T,
	lp *launchpadV1,
	launchpadAddr address,
	adminRealm runtime.Realm,
	projectID string,
	configs []testDepositConfig,
) ([]address, []string) {
	userAddrs := make([]address, len(configs))
	depositIDs := make([]string, len(configs))

	for i, cfg := range configs {
		userAddrs[i], depositIDs[i] = createTestDeposit(t, lp, launchpadAddr, adminRealm, projectID, cfg)
	}

	return userAddrs, depositIDs
}

// =============================================================================
// Test Reward Collection Functions
// =============================================================================

// collectTestReward collects reward for given user and deposit
// Returns the reward amount
func collectTestReward(t *testing.T, lp *launchpadV1, userAddr address, depositID string) int64 {
	testing.SetRealm(testing.NewUserRealm(userAddr))

	var rewardAmount int64
	func(cur realm) {
		testing.SetRealm(testing.NewCodeRealm(testLaunchpadPkgPath))
		rewardAmount = lp.CollectRewardByDepositId(depositID)
	}(cross)

	return rewardAmount
}

// =============================================================================
// Test Constants
// =============================================================================

// Common skip heights for different tiers (claimable duration + buffer)
var (
	testSkipTier30Claimable  int64
	testSkipTier90Claimable  int64
	testSkipTier180Claimable int64
	testSkipTier30End        int64
)

func secondsToBlocks(seconds int64) int64 {
	if seconds <= 0 {
		return 0
	}
	return (seconds + testBlockTimeSeconds - 1) / testBlockTimeSeconds
}

func init() {
	testSkipTier30Claimable = secondsToBlocks(projectTierRewardCollectableDuration[projectTier30]) + 20
	testSkipTier90Claimable = secondsToBlocks(projectTierRewardCollectableDuration[projectTier90]) + 20
	testSkipTier180Claimable = secondsToBlocks(projectTierRewardCollectableDuration[projectTier180]) + 20
	testSkipTier30End = secondsToBlocks(projectTierDurationTimes[projectTier30]) + 20
}

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
	return strconv.FormatInt(s.depositCounter.Next(), 10)
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
