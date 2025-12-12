package v1

import (
	"chain/runtime"
	"testing"
	"time"

	u256 "gno.land/p/gnoswap/uint256"
	"gno.land/p/nt/testutils"
	"gno.land/p/nt/uassert"
	sr "gno.land/r/gnoswap/staker"
)

// TestRealFlow_CollectRewardAfterArchived tests the ACTUAL user flow:
// User stakes -> Incentive ends -> EndExternalIncentive called -> User tries to collect reward
func TestRealFlow_CollectRewardAfterArchived(t *testing.T) {
	initStakerTest(t)
	instance := getMockInstance()

	poolPath := "gno.land/r/onbloc/bar:gno.land/r/onbloc/foo:3000"
	creator := testutils.TestAddress("creator")
	staker1 := testutils.TestAddress("staker1")
	currentTime := time.Now().Unix()
	startTime := currentTime - 86400*10 // 10 days ago
	endTime := currentTime - 86400      // ended 1 day ago
	rewardAmount := int64(10_000_000_000)

	// Create pool
	pool := sr.NewPool(poolPath, currentTime)
	instance.getPools().set(poolPath, pool)

	// Create incentive
	incentiveId := "test-real-flow-collect"
	incentive := sr.NewExternalIncentive(
		incentiveId,
		poolPath,
		WUGNOT_PATH,
		rewardAmount,
		startTime,
		endTime,
		creator,
		100_000_000,
		runtime.ChainHeight(),
		currentTime-86400*11, // created before start
		false,
	)

	// Add incentive to pool
	poolResolver := NewPoolResolver(pool)
	incentivesResolver := poolResolver.IncentivesResolver()
	incentivesResolver.create(creator, incentive)

	// User stakes DURING the incentive period
	positionId := uint64(1)
	stakeTime := startTime + 100
	deposit := sr.NewDeposit(
		staker1,
		poolPath,
		u256.NewUint(1000),
		stakeTime,
		-10000,
		10000,
		[]sr.Warmup{},
	)
	instance.getDeposits().set(positionId, deposit)

	// Verify incentive is active before ending
	uassert.False(t, incentivesResolver.IsArchived(incentiveId), "should not be archived yet")

	// Incentive ends, refundee calls endExternalIncentive (internal method)
	incentiveResolver, _ := incentivesResolver.GetIncentiveResolver(incentiveId)
	_, _, err := instance.endExternalIncentive(poolResolver, incentiveResolver, creator, currentTime)
	uassert.NoError(t, err)

	// Archive the incentive (in production, this happens in the public EndExternalIncentive)
	// But since we're calling the internal method directly in tests, we need to archive manually
	err = instance.archiveEndedExternalIncentive(incentivesResolver, incentive)
	uassert.NoError(t, err)

	// Verify archived
	uassert.True(t, incentivesResolver.IsArchived(incentiveId), "should be archived after ending")

	// NOW: User tries to collect reward
	// This simulates the ACTUAL flow: calcPositionReward -> GetAllInTimestamps
	reward := instance.calcPositionReward(runtime.ChainHeight(), currentTime, positionId)

	// PROBLEM: GetAllInTimestamps only searches active tree
	// So archived incentive is NOT included
	// Result: User gets NO external reward!
	t.Logf("External rewards: %v", reward.External)
	t.Logf("Number of external rewards: %d", len(reward.External))

	// This SHOULD have rewards but GetAllInTimestamps excludes archived
	// Expected: reward.External[incentiveId] > 0
	// Actual: reward.External[incentiveId] doesn't exist!
	if len(reward.External) == 0 {
		t.Error("CRITICAL BUG: User received NO external rewards because incentive was archived!")
		t.Error("GetAllInTimestamps only searches active tree, missing archived incentives")
	}
}

// TestRealFlow_UnstakeAfterArchived tests unstaking after incentive is archived
func TestRealFlow_UnstakeAfterArchived(t *testing.T) {
	initStakerTest(t)
	instance := getMockInstance()

	poolPath := "gno.land/r/onbloc/bar:gno.land/r/onbloc/foo:3000"
	creator := testutils.TestAddress("creator")
	staker1 := testutils.TestAddress("staker1")
	currentTime := time.Now().Unix()
	startTime := currentTime - 86400*10
	endTime := currentTime - 86400
	rewardAmount := int64(10_000_000_000)

	// Setup: pool, incentive, deposit
	pool := sr.NewPool(poolPath, currentTime)
	instance.getPools().set(poolPath, pool)

	incentiveId := "test-unstake-flow"
	incentive := sr.NewExternalIncentive(
		incentiveId,
		poolPath,
		WUGNOT_PATH,
		rewardAmount,
		startTime,
		endTime,
		creator,
		100_000_000,
		runtime.ChainHeight(),
		currentTime-86400*11,
		false,
	)

	poolResolver := NewPoolResolver(pool)
	incentivesResolver := poolResolver.IncentivesResolver()
	incentivesResolver.create(creator, incentive)

	positionId := uint64(1)
	deposit := sr.NewDeposit(
		staker1,
		poolPath,
		u256.NewUint(1000),
		startTime+100,
		-10000,
		10000,
		[]sr.Warmup{},
	)
	instance.getDeposits().set(positionId, deposit)

	// End incentive and archive it
	incentiveResolver, _ := incentivesResolver.GetIncentiveResolver(incentiveId)
	_, _, err := instance.endExternalIncentive(poolResolver, incentiveResolver, creator, currentTime)
	uassert.NoError(t, err)

	// Archive manually (internal method doesn't archive automatically)
	err = instance.archiveEndedExternalIncentive(incentivesResolver, incentive)
	uassert.NoError(t, err)

	// User unstakes (which calls CollectReward internally)
	// But we can't actually call UnStakeToken in unit test due to dependencies
	// So we test the reward calculation part
	reward := instance.calcPositionReward(runtime.ChainHeight(), currentTime, positionId)

	if len(reward.External) == 0 {
		t.Error("CRITICAL BUG: Unstaking user gets NO external rewards from archived incentive!")
	}
}

// TestAPI_ArchivedIncentivesNotReturned tests that API methods don't return archived incentives
func TestAPI_ArchivedIncentivesNotReturned(t *testing.T) {
	initStakerTest(t)
	instance := getMockInstance()

	poolPath := "gno.land/r/onbloc/bar:gno.land/r/onbloc/foo:3000"
	creator := testutils.TestAddress("creator")
	currentTime := time.Now().Unix()

	// Create pool
	pool := sr.NewPool(poolPath, currentTime)
	instance.getPools().set(poolPath, pool)

	poolResolver := NewPoolResolver(pool)
	incentivesResolver := poolResolver.IncentivesResolver()

	// Create 2 incentives: one active, one archived
	activeId := "active-incentive"
	archivedId := "archived-incentive"

	activeIncentive := sr.NewExternalIncentive(
		activeId,
		poolPath,
		WUGNOT_PATH,
		10_000_000_000,
		currentTime,
		currentTime+86400,
		creator,
		100_000_000,
		runtime.ChainHeight(),
		currentTime,
		false,
	)
	incentivesResolver.create(creator, activeIncentive)

	archivedIncentive := sr.NewExternalIncentive(
		archivedId,
		poolPath,
		WUGNOT_PATH,
		10_000_000_000,
		currentTime-86400*10,
		currentTime-1,
		creator,
		100_000_000,
		runtime.ChainHeight(),
		currentTime-86400*11,
		false,
	)
	incentivesResolver.create(creator, archivedIncentive)

	// End archived incentive and archive it
	archivedIncentiveResolver := NewExternalIncentiveResolver(archivedIncentive)
	_, _, err := instance.endExternalIncentive(poolResolver, archivedIncentiveResolver, creator, currentTime)
	uassert.NoError(t, err)

	// Archive manually (internal method doesn't archive automatically)
	err = instance.archiveEndedExternalIncentive(incentivesResolver, archivedIncentive)
	uassert.NoError(t, err)

	// Call API methods
	// NOTE: These API methods iterate IncentiveTrees() only, NOT ArchivedIncentives()

	// ApiGetExternalIncentives - returns ALL external incentives
	allIncentivesJson := instance.ApiGetExternalIncentives()
	t.Logf("ApiGetExternalIncentives result: %s", allIncentivesJson)

	// ApiGetExternalIncentivesByPoolPath - returns incentives for specific pool
	poolIncentivesJson := instance.ApiGetExternalIncentivesByPoolPath(poolPath)
	t.Logf("ApiGetExternalIncentivesByPoolPath result: %s", poolIncentivesJson)

	// PROBLEM: Archived incentives are NOT returned by API!
	// Users/UI cannot see ended incentives that have been archived
	// This affects:
	// 1. Displaying historical incentive data
	// 2. Showing users their past participated incentives
	// 3. Transparency of incentive program status
}

// TestGetter_ArchivedIncentiveNotFound tests that getter methods fail to find archived incentives
func TestGetter_ArchivedIncentiveNotFound(t *testing.T) {
	initStakerTest(t)
	instance := getMockInstance()

	poolPath := "gno.land/r/onbloc/bar:gno.land/r/onbloc/foo:3000"
	creator := testutils.TestAddress("creator")
	currentTime := time.Now().Unix()

	pool := sr.NewPool(poolPath, currentTime)
	instance.getPools().set(poolPath, pool)

	poolResolver := NewPoolResolver(pool)
	incentivesResolver := poolResolver.IncentivesResolver()

	incentiveId := "test-getter-archived"
	incentive := sr.NewExternalIncentive(
		incentiveId,
		poolPath,
		WUGNOT_PATH,
		10_000_000_000,
		currentTime-86400*10,
		currentTime-1,
		creator,
		100_000_000,
		runtime.ChainHeight(),
		currentTime-86400*11,
		false,
	)
	incentivesResolver.create(creator, incentive)

	// End it and archive it
	incentiveResolver := NewExternalIncentiveResolver(incentive)
	_, _, err := instance.endExternalIncentive(poolResolver, incentiveResolver, creator, currentTime)
	uassert.NoError(t, err)

	// Archive manually (internal method doesn't archive automatically)
	err = instance.archiveEndedExternalIncentive(incentivesResolver, incentive)
	uassert.NoError(t, err)

	// Try to get incentive using getter
	// After our fix, this should work because getIncentive now searches both trees
	retrievedIncentive := instance.getIncentive(poolPath, incentiveId)
	uassert.NotEqual(t, nil, retrievedIncentive, "should find archived incentive")
	uassert.Equal(t, incentiveId, retrievedIncentive.IncentiveId(), "should return correct incentive")
}
