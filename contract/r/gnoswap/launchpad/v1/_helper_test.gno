package v1

import (
	"chain"
	"chain/runtime"
	"strconv"
	"testing"
	"time"

	prbac "gno.land/p/gnoswap/rbac"
	bptree "gno.land/p/nt/bptree/v0"
	testutils "gno.land/p/nt/testutils/v0"
	uassert "gno.land/p/nt/uassert/v0"

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
func setupTestEnvironment(cur realm, t *testing.T, cfg testEnvConfig) (address, runtime.Realm) {
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
	halt.SetHaltLevel(cross(cur), halt.HaltLevelNone)

	return launchpadAddr, adminRealm
}

// =============================================================================
// Test Project Functions
// =============================================================================

// createTestProject creates a project with given config and returns project ID
func createTestProject(
	cur realm,
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
		obl.Approve(cross(cur), launchpadAddr, cfg.rewardAmount)
	}

	startTime := testing.GetContext().Time.Unix() + projectMinimumStartDelayTime

	name := cfg.name
	if name == "" {
		name = "Test Project"
	}

	project, err := lp.createProject(0, cur, &createProjectParams{
		name:                  name,
		tokenPath:             tokenPath,
		recipient:             testutils.TestAddress(cfg.recipientSuffix),
		depositAmount:         cfg.rewardAmount,
		tier30Ratio:           cfg.tier30Pct,
		tier90Ratio:           cfg.tier90Pct,
		tier180Ratio:          cfg.tier180Pct,
		startTime:             startTime,
		currentTime:           testing.GetContext().Time.Unix(),
		currentHeight:         testing.GetContext().Height,
		minimumStartDelayTime: projectMinimumStartDelayTime,
	})
	uassert.Nil(t, err)

	if tokenPath == testOblTokenPath {
		testing.SetRealm(adminRealm)
		obl.Transfer(cross(cur), launchpadAddr, cfg.rewardAmount)
	}

	projectID := project.ID()

	// Activate project by skipping past start time (add buffer to ensure activation)
	testing.SkipHeights(secondsToBlocks(projectMinimumStartDelayTime) + 20)

	return projectID
}

// createTestDeposit creates a deposit for given user and returns user address and deposit ID
func createTestDeposit(
	cur realm,
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
	gns.Transfer(cross(cur), userAddr, cfg.depositAmount*2)

	// User approves and deposits
	testing.SetRealm(testing.NewUserRealm(userAddr))
	gns.Approve(cross(cur), launchpadAddr, cfg.depositAmount)

	tier := cfg.tier
	if tier == 0 {
		tier = 30
	}

	var depositID string
	project, err := lp.getProject(projectID)
	uassert.Nil(t, err)

	deposit, _, _, _, err := lp.depositGns(0, cur, project, tier, cfg.depositAmount, userAddr)
	uassert.Nil(t, err)
	depositID = deposit.ID()

	return userAddr, depositID
}

// createTestDeposits creates multiple deposits and returns user addresses and deposit IDs
func createTestDeposits(
	cur realm,
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
		userAddrs[i], depositIDs[i] = createTestDeposit(cur, t, lp, launchpadAddr, adminRealm, projectID, cfg)
	}

	return userAddrs, depositIDs
}

// =============================================================================
// Test Reward Collection Functions
// =============================================================================

// collectTestReward collects reward for given user and deposit
// Returns the reward amount
func collectTestReward(cur realm, t *testing.T, lp *launchpadV1, userAddr address, depositID string) int64 {
	testing.SetRealm(testing.NewUserRealm(userAddr))

	var rewardAmount int64
	func(cur realm) {
		testing.SetRealm(testing.NewCodeRealm(testLaunchpadPkgPath))
		rewardAmount = lp.CollectRewardByDepositId(0, cur, depositID)
	}(cross(cur))

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
		projects:                  bptree.NewBPTreeN(16),
		projectTierRewardManagers: bptree.NewBPTreeN(16),
		depositCounter:            launchpad.NewCounter(),
		deposits:                  bptree.NewBPTreeN(16),
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
	projects                  *bptree.BPTree
	projectTierRewardManagers *bptree.BPTree
	depositCounter            *launchpad.Counter
	deposits                  *bptree.BPTree
}

func (s *testLaunchpadStore) HasProjectsKey() bool {
	return s.projects != nil
}

func (s *testLaunchpadStore) GetProjects() *bptree.BPTree {
	if s.projects == nil {
		return bptree.NewBPTreeN(16)
	}
	return s.projects
}

func (s *testLaunchpadStore) SetProjects(_ int, rlm realm, projects *bptree.BPTree) error {
	s.projects = projects
	return nil
}

func (s *testLaunchpadStore) HasProjectTierRewardManagersKey() bool {
	return s.projectTierRewardManagers != nil
}

func (s *testLaunchpadStore) GetProjectTierRewardManagers() *bptree.BPTree {
	if s.projectTierRewardManagers == nil {
		return bptree.NewBPTreeN(16)
	}
	return s.projectTierRewardManagers
}

func (s *testLaunchpadStore) SetProjectTierRewardManagers(_ int, rlm realm, managers *bptree.BPTree) error {
	s.projectTierRewardManagers = managers
	return nil
}

func (s *testLaunchpadStore) HasDepositCounterStoreKey() bool {
	return s.depositCounter != nil
}

func (s *testLaunchpadStore) GetDepositCounter() *launchpad.Counter {
	return s.depositCounter
}

func (s *testLaunchpadStore) SetDepositCounter(_ int, rlm realm, counter *launchpad.Counter) error {
	s.depositCounter = counter
	return nil
}

func (s *testLaunchpadStore) NextDepositID() string {
	return strconv.FormatInt(s.depositCounter.Next(), 10)
}

func (s *testLaunchpadStore) HasDepositsKey() bool {
	return s.deposits != nil
}

func (s *testLaunchpadStore) GetDeposits() *bptree.BPTree {
	if s.deposits == nil {
		return bptree.NewBPTreeN(16)
	}
	return s.deposits
}

func (s *testLaunchpadStore) SetDeposits(_ int, rlm realm, deposits *bptree.BPTree) error {
	s.deposits = deposits
	return nil
}

// Test helper functions to access state

// getTestProjects returns the projects tree
func getTestProjects() *bptree.BPTree {
	if testStore == nil {
		return bptree.NewBPTreeN(16)
	}
	return testStore.GetProjects()
}

// setTestProjects sets the projects tree
func setTestProjects(tree *bptree.BPTree) {
	if testStore == nil {
		initTestStore()
	}
	// Direct assignment for test purposes
	if store, ok := testStore.(*testLaunchpadStore); ok {
		store.projects = tree
	}
}

// getTestProjectTierRewardManagers returns the projectTierRewardManagers tree
func getTestProjectTierRewardManagers() *bptree.BPTree {
	if testStore == nil {
		return bptree.NewBPTreeN(16)
	}
	return testStore.GetProjectTierRewardManagers()
}

// setTestProjectTierRewardManagers sets the projectTierRewardManagers tree
func setTestProjectTierRewardManagers(tree *bptree.BPTree) {
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

func createProjectTest(
	cur realm,
	t *testing.T,
	projectName string,
	tokenPath string,
	recipient address,
	rewardAmount int64,
	tier30Pct int64,
	tier90Pct int64,
	tier180Pct int64,
	startTime int64,
) string {
	return func(cur realm) string {
		testing.SetRealm(testing.NewCodeRealm(testLaunchpadPkgPath))

		return testImpl.CreateProject(0, cur, projectName,
			tokenPath,
			recipient,
			rewardAmount,
			"", "",
			tier30Pct, tier90Pct, tier180Pct,
			startTime,
		)
	}(cross(cur))
}

func depositGnsTest(cur realm, t *testing.T, depositID string, depositAmount int64) string {
	return func(cur realm) string {
		testing.SetRealm(testing.NewCodeRealm(testLaunchpadPkgPath))

		return testImpl.DepositGns(0, cur, depositID,
			depositAmount,
			"",
		)
	}(cross(cur))
}

func collectRewardTest(cur realm, t *testing.T, depositID string) int64 {
	return func(cur realm) int64 {
		testing.SetRealm(testing.NewCodeRealm(testLaunchpadPkgPath))

		return testImpl.CollectRewardByDepositId(0, cur, depositID)
	}(cross(cur))
}
