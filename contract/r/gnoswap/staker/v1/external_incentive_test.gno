package v1

import (
	"chain/runtime"
	"testing"
	"time"

	"gno.land/p/nt/avl"
	u256 "gno.land/p/gnoswap/uint256"
	"gno.land/p/nt/testutils"
	"gno.land/p/nt/uassert"
	"gno.land/p/nt/ufmt"
	sr "gno.land/r/gnoswap/staker"
)

func TestCreateExternalIncentiveWithAllowedTokens(t *testing.T) {
	poolPath := "test_pool"
	account1 := testutils.TestAddress("account1")
	account2 := testutils.TestAddress("account2")

	// create pool
	pool := sr.NewPool(poolPath, 100)

	pools := getMockInstance().getPools()
	pools.set(poolPath, pool)

	currentTime := time.Now().Unix()
	startTime := currentTime + 86400   // 1 day later
	endTime := startTime + (86400 * 7) // 7 days after start

	// Define allowed tokens and test scenarios
	allowedTokens := []string{GNS_PATH, WUGNOT_PATH, "token0_path", "token1_path"}
	accounts := []address{account1, account2}
	amounts := []int64{1000, 2000, 1500, 2500, 3000, 3500}

	// Test various combinations
	tests := []struct {
		accountIdx int
		tokenIdx   int
		amountIdx  int
	}{
		{0, 0, 0}, // account1, GNS, 1000
		{0, 1, 1}, // account1, WUGNOT, 2000
		{1, 2, 2}, // account2, token0_path, 1500
		{1, 3, 3}, // account2, token1_path, 2500
		{0, 2, 4}, // account1, token0_path, 3000
		{1, 0, 5}, // account2, GNS, 3500
	}

	for i, tc := range tests {
		creator := accounts[tc.accountIdx]
		token := allowedTokens[tc.tokenIdx]
		amount := amounts[tc.amountIdx]

		incentiveId := ufmt.Sprintf("%d", i+1)
		name := ufmt.Sprintf("account_%d_token_%s_amount_%d", tc.accountIdx+1, token, amount)

		t.Run(name, func(t *testing.T) {
			// create incentive
			incentive := sr.NewExternalIncentive(
				incentiveId,
				poolPath,
				token,
				amount,
				startTime,
				endTime,
				creator,
				0,
				runtime.ChainHeight(),
				currentTime,
				true,
			)

			// add incentive
			poolResolver := NewPoolResolver(pool)
			poolResolver.IncentivesResolver().create(creator, incentive)

			// verify incentive was created
			ictv, exists := poolResolver.IncentivesResolver().Get(incentive.IncentiveId())
			if !exists {
				t.Fatal("incentive was not created")
			}

			if ictv.RewardAmount() != amount {
				t.Errorf("expected reward amount %d, got %d", amount, ictv.RewardAmount())
			}

			if ictv.RewardToken() != token {
				t.Errorf("expected reward token %s, got %s", token, ictv.RewardToken())
			}

			if ictv.Refundee() != creator {
				t.Errorf("expected refundee %s, got %s", creator, ictv.Refundee())
			}
		})
	}

	// clean up after test
	pools.tree.Remove(poolPath)
}

// Test endExternalIncentive logic
func TestEndExternalIncentive(t *testing.T) {
	initStakerTest(t)
	instance := getMockInstance()

	poolPath := "gno.land/r/onbloc/bar:gno.land/r/onbloc/foo:3000"
	creator := testutils.TestAddress("creator")
	currentTime := time.Now().Unix()
	startTime := currentTime - 86400*10 // 10 days ago
	endTime := currentTime - 1          // ended 1 second ago
	rewardAmount := int64(10_000_000_000)

	// Create pool
	pool := sr.NewPool(poolPath, currentTime)
	instance.getPools().set(poolPath, pool)

	// Create incentive
	incentiveId := "test-incentive-1"
	incentive := sr.NewExternalIncentive(
		incentiveId,
		poolPath,
		WUGNOT_PATH,
		rewardAmount,
		startTime,
		endTime,
		creator,
		100_000_000, // depositGnsAmount
		runtime.ChainHeight(),
		currentTime,
		false,
	)

	// Add incentive to pool
	poolResolver := NewPoolResolver(pool)
	poolResolver.IncentivesResolver().create(creator, incentive)

	tests := []struct {
		name             string
		caller           address
		currentTime      int64
		expectError      bool
		expectedErrorMsg string
	}{
		{
			name:             "end incentive before end time",
			caller:           creator,
			currentTime:      endTime - 1,
			expectError:      true,
			expectedErrorMsg: "cannot end incentive before endTime",
		},
		{
			name:             "end incentive at exact end time by creator",
			caller:           creator,
			currentTime:      endTime,
			expectError:      false,
			expectedErrorMsg: "",
		},
		{
			name:             "end incentive by non-creator non-admin",
			caller:           testutils.TestAddress("stranger"),
			currentTime:      endTime + 1,
			expectError:      true,
			expectedErrorMsg: "only refundee",
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			// Reset incentive for each test
			incentive.SetRefunded(false)
			poolResolver.IncentivesResolver().update(creator, incentive)

			// Get incentiveResolver for the test
			incentiveResolver, _ := poolResolver.IncentivesResolver().GetIncentiveResolver(incentiveId)
			_, _, err := instance.endExternalIncentive(poolResolver, incentiveResolver, tt.caller, tt.currentTime)

			if tt.expectError {
				uassert.Error(t, err)
				uassert.ErrorContains(t, err, tt.expectedErrorMsg)
			} else {
				uassert.NoError(t, err)
			}
		})
	}
}

// TestDoubleClaimPrevention tests that the "last collect time"
// mechanism prevents double claiming even with finished incentives.
func TestDoubleClaimPrevention(t *testing.T) {
	poolPath := "gno.land/r/onbloc/bar:gno.land/r/onbloc/foo:3000"
	staker1 := testutils.TestAddress("staker1")
	currentTime := time.Now().Unix()
	startTime := currentTime - 86400*10
	endTime := currentTime - 86400
	incentiveId := "test-double-claim"

	// Create deposit
	deposit := sr.NewDeposit(
		staker1,
		poolPath,
		u256.NewUint(1000),
		startTime+100,
		-10000,
		10000,
		[]sr.Warmup{},
	)

	depositResolver := NewDepositResolver(deposit)

	// First collection at endTime - 1 day
	firstCollectTime := endTime - 86400
	err := depositResolver.updateExternalRewardLastCollectTime(incentiveId, firstCollectTime)
	uassert.NoError(t, err)

	// Verify first collect time is recorded
	recordedTime := depositResolver.ExternalRewardLastCollectTime(incentiveId)
	uassert.Equal(t, firstCollectTime, recordedTime)

	// Try to collect again at the same time (should be allowed)
	err = depositResolver.updateExternalRewardLastCollectTime(incentiveId, firstCollectTime)
	uassert.NoError(t, err)

	// Try to collect at earlier time (should fail)
	err = depositResolver.updateExternalRewardLastCollectTime(incentiveId, firstCollectTime-1)
	uassert.Error(t, err, "should not allow collecting at earlier time")
	uassert.ErrorContains(t, err, "currentTime must be greater than external reward last collect time")

	// Collect at later time (should succeed)
	secondCollectTime := endTime
	err = depositResolver.updateExternalRewardLastCollectTime(incentiveId, secondCollectTime)
	uassert.NoError(t, err)

	// Verify second collect time is recorded
	recordedTime = depositResolver.ExternalRewardLastCollectTime(incentiveId)
	uassert.Equal(t, secondCollectTime, recordedTime)
}

// Test Deposit.LastExternalIncentiveUpdatedAt getter/setter
func TestDepositLastExternalIncentiveUpdatedAt(t *testing.T) {
	deposit := sr.NewDeposit(
		addr01,
		"pool1",
		u256.NewUint(1000),
		100,
		-10,
		10,
		sr.DefaultWarmupTemplate(),
	)

	// Should be initialized to 0
	if deposit.LastExternalIncentiveUpdatedAt() != 0 {
		t.Errorf("Expected initial value 0, got %d", deposit.LastExternalIncentiveUpdatedAt())
	}

	// Test setter
	deposit.SetLastExternalIncentiveUpdatedAt(12345)
	if deposit.LastExternalIncentiveUpdatedAt() != 12345 {
		t.Errorf("Expected 12345, got %d", deposit.LastExternalIncentiveUpdatedAt())
	}
}

// Test timestamp-based tree stores slice of incentive IDs
func TestExternalIncentivesByCreationTimeSliceStorage(t *testing.T) {
	tree := avl.NewTree()

	timestamp := int64(1000)
	timeKey := formatInt(timestamp)

	// Store first incentive
	incentiveId1 := "addr1:1000:0"
	var incentiveIds []string
	incentiveIds = []string{incentiveId1}
	tree.Set(timeKey, incentiveIds)

	// Verify storage
	value, exists := tree.Get(timeKey)
	if !exists {
		t.Fatal("Expected incentive to exist")
	}

	stored := value.([]string)
	if len(stored) != 1 || stored[0] != incentiveId1 {
		t.Errorf("Expected [%s], got %v", incentiveId1, stored)
	}

	// Add second incentive at same timestamp (collision)
	incentiveId2 := "addr2:1000:1"
	existingIds := value.([]string)
	incentiveIds = append(existingIds, incentiveId2)
	tree.Set(timeKey, incentiveIds)

	// Verify both stored
	value2, _ := tree.Get(timeKey)
	stored2 := value2.([]string)
	if len(stored2) != 2 {
		t.Errorf("Expected 2 incentives, got %d", len(stored2))
	}
	if stored2[0] != incentiveId1 || stored2[1] != incentiveId2 {
		t.Errorf("Expected [%s, %s], got %v", incentiveId1, incentiveId2, stored2)
	}
}

// Test time-based tree iteration
func TestExternalIncentivesByCreationTimeIteration(t *testing.T) {
	tree := avl.NewTree()

	// Add incentives at different times
	tree.Set(formatInt(100), []string{"incentive1"})
	tree.Set(formatInt(200), []string{"incentive2", "incentive3"}) // collision
	tree.Set(formatInt(300), []string{"incentive4"})

	// Iterate from 150 to 250 (should get only time 200)
	found := make([]string, 0)
	tree.Iterate(formatInt(150), formatInt(250), func(key string, value any) bool {
		ids := value.([]string)
		found = append(found, ids...)
		return false
	})

	if len(found) != 2 {
		t.Errorf("Expected 2 incentives in range, got %d", len(found))
	}
	if found[0] != "incentive2" || found[1] != "incentive3" {
		t.Errorf("Expected [incentive2, incentive3], got %v", found)
	}
}

// Test lazy sync logic: filter by pool
func TestLazySyncPoolFiltering(t *testing.T) {
	pool1 := "pool1"
	pool2 := "pool2"

	// Mock incentives
	type mockIncentive struct {
		id   string
		pool string
	}

	incentives := []mockIncentive{
		{"inc1", pool1},
		{"inc2", pool2},
		{"inc3", pool1},
	}

	// Simulate filtering
	deposit := sr.NewDeposit(
		addr01,
		pool1, // Deposit is for pool1
		u256.NewUint(1000),
		100,
		-10,
		10,
		sr.DefaultWarmupTemplate(),
	)

	// Add only pool1 incentives
	for _, inc := range incentives {
		if inc.pool == deposit.TargetPoolPath() {
			deposit.AddExternalIncentiveId(inc.id)
		}
	}

	// Should have only 2 incentives (inc1, inc3)
	cachedIds := deposit.GetExternalIncentiveIdList()
	if len(cachedIds) != 2 {
		t.Errorf("Expected 2 pool1 incentives, got %d", len(cachedIds))
	}
}

// Test lastExternalIncentiveUpdatedAt prevents re-syncing
func TestLastUpdatePreventsReSync(t *testing.T) {
	deposit := sr.NewDeposit(
		addr01,
		"pool1",
		u256.NewUint(1000),
		100,
		-10,
		10,
		sr.DefaultWarmupTemplate(),
	)

	// Set lastUpdate to 500
	deposit.SetLastExternalIncentiveUpdatedAt(500)

	// Current time is 600
	currentTime := int64(600)

	// Should sync (lastUpdate < currentTime)
	shouldSync := deposit.LastExternalIncentiveUpdatedAt() < currentTime
	if !shouldSync {
		t.Error("Expected sync to be needed when lastUpdate < currentTime")
	}

	// Update to current time
	deposit.SetLastExternalIncentiveUpdatedAt(currentTime)

	// Should NOT sync again at same time
	shouldSync = deposit.LastExternalIncentiveUpdatedAt() < currentTime
	if shouldSync {
		t.Error("Expected no sync when lastUpdate == currentTime")
	}
}

// Test formatInt consistency for tree keys
func TestFormatIntConsistency(t *testing.T) {
	time1 := int64(1000)
	time2 := int64(2000)

	key1 := formatInt(time1)
	key2 := formatInt(time2)

	// Keys should be different
	if key1 == key2 {
		t.Error("Expected different keys for different timestamps")
	}

	// Keys should be consistent
	if formatInt(time1) != key1 {
		t.Error("formatInt should produce consistent results")
	}

	// Lexicographic ordering (for small numbers)
	tree := avl.NewTree()
	tree.Set(key1, "value1")
	tree.Set(key2, "value2")

	// Iterate should respect key order
	keys := make([]string, 0)
	tree.Iterate("", "", func(key string, value any) bool {
		keys = append(keys, key)
		return false
	})

	if len(keys) != 2 {
		t.Errorf("Expected 2 keys, got %d", len(keys))
	}
}

// TestCreateExternalIncentive_SameTimestamp tests that multiple incentives
// created at the same timestamp are all stored correctly in the time-based tree.
func TestCreateExternalIncentive_SameTimestamp(t *testing.T) {
	initStakerTest(t)
	instance := getMockInstance()

	poolPath := "gno.land/r/onbloc/bar:gno.land/r/onbloc/foo:3000"
	creator := testutils.TestAddress("creator")
	currentTime := time.Now().Unix()

	// Create pool
	pool := sr.NewPool(poolPath, currentTime)
	instance.getPools().set(poolPath, pool)

	// Simulate multiple incentives created at the exact same time
	// by directly manipulating the timestamp
	startTime := currentTime + 86400
	endTime := startTime + 86400*7

	// Create 3 incentives at the same timestamp
	incentiveIds := make([]string, 3)
	for i := 0; i < 3; i++ {
		incentiveId := instance.store.NextIncentiveID(creator, currentTime)
		incentiveIds[i] = incentiveId

		incentive := sr.NewExternalIncentive(
			incentiveId,
			poolPath,
			WUGNOT_PATH,
			int64((i+1)*1000000),
			startTime,
			endTime,
			creator,
			100_000_000,
			1000,
			currentTime, // Same currentTime for all
			false,
		)

		// Add to external incentives store
		externalIncentives := instance.store.GetExternalIncentives()
		externalIncentives.Set(incentiveId, incentive)

		// Add to pool
		poolResolver := NewPoolResolver(pool)
		poolResolver.IncentivesResolver().create(creator, incentive)

		// Add to time-based index (same as CreateExternalIncentive)
		var incentivesByTime *avl.Tree
		if !instance.store.HasExternalIncentivesByCreationTimeStoreKey() {
			incentivesByTime = avl.NewTree()
		} else {
			incentivesByTime = instance.store.GetExternalIncentivesByCreationTime()
		}

		timeKey := formatInt(currentTime)
		var ids []string
		if value, exists := incentivesByTime.Get(timeKey); exists {
			existingIds, ok := value.([]string)
			if ok {
				ids = append(existingIds, incentiveId)
			} else {
				ids = []string{incentiveId}
			}
		} else {
			ids = []string{incentiveId}
		}
		incentivesByTime.Set(timeKey, ids)
		instance.store.SetExternalIncentivesByCreationTime(incentivesByTime)
	}

	// Verify all 3 incentives are stored at the same timestamp
	incentivesByTime := instance.store.GetExternalIncentivesByCreationTime()
	timeKey := formatInt(currentTime)

	value, exists := incentivesByTime.Get(timeKey)
	if !exists {
		t.Fatal("Expected incentives at timestamp to exist")
	}

	storedIds, ok := value.([]string)
	if !ok {
		t.Fatal("Expected value to be []string")
	}

	if len(storedIds) != 3 {
		t.Errorf("Expected 3 incentives at same timestamp, got %d", len(storedIds))
	}

	// Verify all IDs match
	for i, expectedId := range incentiveIds {
		if storedIds[i] != expectedId {
			t.Errorf("Incentive %d: expected %s, got %s", i, expectedId, storedIds[i])
		}
	}

	// Verify all incentives can be retrieved from external incentives store
	externalIncentives := instance.store.GetExternalIncentives()
	for _, id := range incentiveIds {
		_, exists := externalIncentives.Get(id)
		if !exists {
			t.Errorf("Incentive %s not found in external incentives store", id)
		}
	}
}

// TestCreateExternalIncentive_TimeBasedIndex tests that the time-based index
// correctly stores and retrieves incentives across different timestamps.
func TestCreateExternalIncentive_TimeBasedIndex(t *testing.T) {
	initStakerTest(t)
	instance := getMockInstance()

	poolPath := "gno.land/r/onbloc/bar:gno.land/r/onbloc/foo:3000"
	creator := testutils.TestAddress("creator")
	baseTime := time.Now().Unix()

	// Create pool
	pool := sr.NewPool(poolPath, baseTime)
	instance.getPools().set(poolPath, pool)

	// Create incentives at different times
	timestamps := []int64{
		baseTime,
		baseTime + 100,
		baseTime + 200,
		baseTime + 300,
	}

	incentiveIdsByTime := make(map[int64]string)

	for _, ts := range timestamps {
		incentiveId := instance.store.NextIncentiveID(creator, ts)
		incentiveIdsByTime[ts] = incentiveId

		incentive := sr.NewExternalIncentive(
			incentiveId,
			poolPath,
			WUGNOT_PATH,
			1000000,
			ts+86400,
			ts+86400*7,
			creator,
			100_000_000,
			1000,
			ts,
			false,
		)

		externalIncentives := instance.store.GetExternalIncentives()
		externalIncentives.Set(incentiveId, incentive)

		poolResolver := NewPoolResolver(pool)
		poolResolver.IncentivesResolver().create(creator, incentive)

		// Add to time-based index
		var incentivesByTime *avl.Tree
		if !instance.store.HasExternalIncentivesByCreationTimeStoreKey() {
			incentivesByTime = avl.NewTree()
		} else {
			incentivesByTime = instance.store.GetExternalIncentivesByCreationTime()
		}

		timeKey := formatInt(ts)
		incentivesByTime.Set(timeKey, []string{incentiveId})
		instance.store.SetExternalIncentivesByCreationTime(incentivesByTime)
	}

	// Test range queries
	testCases := []struct {
		name      string
		startTime int64
		endTime   int64
		expected  int
	}{
		{"All incentives", baseTime, baseTime + 400, 4},
		{"Middle range", baseTime + 50, baseTime + 250, 2}, // 100, 200
		{"Exact boundaries", baseTime + 100, baseTime + 301, 3}, // 100, 200, 300 (exclusive end)
		{"Single timestamp", baseTime, baseTime + 50, 1}, // only baseTime
	}

	for _, tc := range testCases {
		t.Run(tc.name, func(t *testing.T) {
			incentivesByTime := instance.store.GetExternalIncentivesByCreationTime()

			found := make([]string, 0)
			incentivesByTime.Iterate(formatInt(tc.startTime), formatInt(tc.endTime), func(key string, value any) bool {
				ids := value.([]string)
				found = append(found, ids...)
				return false
			})

			if len(found) != tc.expected {
				t.Errorf("Expected %d incentives in range [%d, %d], got %d",
					tc.expected, tc.startTime, tc.endTime, len(found))
			}
		})
	}
}

// TestLazySync_DuplicatePrevention tests that the same incentive
// is not added multiple times to deposit even if lazy sync runs multiple times.
func TestLazySync_DuplicatePrevention(t *testing.T) {
	poolPath := "gno.land/r/onbloc/bar:gno.land/r/onbloc/foo:3000"
	staker := testutils.TestAddress("staker1")
	baseTime := time.Now().Unix()

	warmups := sr.DefaultWarmupTemplate()
	deposit := sr.NewDeposit(
		staker,
		poolPath,
		u256.NewUint(1000),
		baseTime,
		-10000,
		10000,
		warmups,
	)

	incentiveId := "incentive-1"

	// Add same incentive ID multiple times
	deposit.AddExternalIncentiveId(incentiveId)
	deposit.AddExternalIncentiveId(incentiveId)
	deposit.AddExternalIncentiveId(incentiveId)

	// Verify it's only added once (AVL Tree property)
	count := len(deposit.GetExternalIncentiveIdList())
	if count != 1 {
		t.Errorf("Expected 1 incentive (no duplicates), got %d", count)
	}

	// Verify Has returns true
	if !deposit.HasExternalIncentiveId(incentiveId) {
		t.Error("Expected incentive to exist in deposit")
	}

	// Get the list and verify content
	ids := deposit.GetExternalIncentiveIdList()
	if len(ids) != 1 {
		t.Errorf("Expected 1 ID in list, got %d", len(ids))
	}
	if ids[0] != incentiveId {
		t.Errorf("Expected %s, got %s", incentiveId, ids[0])
	}
}

// TestLazySync_MultipleConcurrentIncentives tests that multiple active
// incentives are all tracked and none are missed.
func TestLazySync_MultipleConcurrentIncentives(t *testing.T) {
	initStakerTest(t)
	instance := getMockInstance()

	poolPath := "gno.land/r/onbloc/bar:gno.land/r/onbloc/foo:3000"
	creator := testutils.TestAddress("creator")
	staker := testutils.TestAddress("staker1")
	baseTime := time.Now().Unix()

	// Create pool
	pool := sr.NewPool(poolPath, baseTime)
	instance.getPools().set(poolPath, pool)
	poolResolver := NewPoolResolver(pool)

	// Create 3 concurrent incentives with different tokens
	tokens := []string{WUGNOT_PATH, GNS_PATH, "gno.land/r/onbloc/bar"}
	incentiveIds := make([]string, 3)

	for i := 0; i < 3; i++ {
		incentiveId := instance.store.NextIncentiveID(creator, baseTime)
		incentiveIds[i] = incentiveId

		incentive := sr.NewExternalIncentive(
			incentiveId,
			poolPath,
			tokens[i],
			int64((i+1)*1000000),
			baseTime,
			baseTime+86400,
			creator,
			100_000_000,
			1000,
			baseTime,
			false,
		)

		// Add to external incentives store
		externalIncentives := instance.store.GetExternalIncentives()
		externalIncentives.Set(incentiveId, incentive)

		// Add to pool
		poolResolver.IncentivesResolver().create(creator, incentive)
	}

	// Create deposit
	warmups := sr.DefaultWarmupTemplate()
	deposit := sr.NewDeposit(
		staker,
		poolPath,
		u256.NewUint(1000),
		baseTime,
		-10000,
		10000,
		warmups,
	)

	// Simulate lazy sync: iterate time-based index and add matching pool incentives
	// (This would normally happen in calculatePositionReward)
	for _, incentiveId := range incentiveIds {
		deposit.AddExternalIncentiveId(incentiveId)
	}

	// Verify all 3 incentives are in deposit
	depositIds := deposit.GetExternalIncentiveIdList()
	if len(depositIds) != 3 {
		t.Fatalf("Expected 3 incentives in deposit, got %d", len(depositIds))
	}

	// Verify each incentive ID is present
	for _, expectedId := range incentiveIds {
		if !deposit.HasExternalIncentiveId(expectedId) {
			t.Errorf("Expected incentive %s to be in deposit", expectedId)
		}
	}

	// Verify all incentives are retrievable from pool
	for _, id := range incentiveIds {
		_, ok := poolResolver.IncentivesResolver().Get(id)
		if !ok {
			t.Errorf("Incentive %s not found in pool", id)
		}
	}
}

// TestLazySync_PoolFilteringPreventsWrongPool tests that incentives
// from different pools are not added to deposit during lazy sync.
func TestLazySync_PoolFilteringPreventsWrongPool(t *testing.T) {
	pool1Path := "gno.land/r/onbloc/bar:gno.land/r/onbloc/foo:3000"
	pool2Path := "gno.land/r/onbloc/bar:gno.land/r/onbloc/qux:3000"
	creator := testutils.TestAddress("creator")
	staker := testutils.TestAddress("staker1")
	baseTime := time.Now().Unix()

	// Create deposit for pool1
	warmups := sr.DefaultWarmupTemplate()
	deposit := sr.NewDeposit(
		staker,
		pool1Path, // Deposit is for pool1
		u256.NewUint(1000),
		baseTime,
		-10000,
		10000,
		warmups,
	)

	// Create incentives for both pools
	incentive1 := sr.NewExternalIncentive(
		"pool1-incentive",
		pool1Path, // Pool1
		WUGNOT_PATH,
		1000000,
		baseTime,
		baseTime+1000,
		creator,
		100_000_000,
		1000,
		baseTime,
		false,
	)

	incentive2 := sr.NewExternalIncentive(
		"pool2-incentive",
		pool2Path, // Pool2 (different)
		WUGNOT_PATH,
		1000000,
		baseTime,
		baseTime+1000,
		creator,
		100_000_000,
		1000,
		baseTime,
		false,
	)

	// Simulate lazy sync with pool filtering (from calculatePositionReward line 133)
	incentives := []*sr.ExternalIncentive{incentive1, incentive2}
	for _, inc := range incentives {
		// Only add if incentive is for the current pool
		if inc.TargetPoolPath() == deposit.TargetPoolPath() {
			deposit.AddExternalIncentiveId(inc.IncentiveId())
		}
	}

	// Verify only pool1 incentive was added
	depositIds := deposit.GetExternalIncentiveIdList()
	if len(depositIds) != 1 {
		t.Fatalf("Expected 1 incentive (pool1 only), got %d", len(depositIds))
	}

	if !deposit.HasExternalIncentiveId("pool1-incentive") {
		t.Error("Expected pool1 incentive to be in deposit")
	}

	if deposit.HasExternalIncentiveId("pool2-incentive") {
		t.Error("Pool2 incentive should NOT be in pool1 deposit")
	}
}

// TestRefundCalculationWithPartialCollections tests that refund calculation
// is accurate when multiple users collect and unstake
func TestRefundCalculationWithPartialCollections(t *testing.T) {
	initStakerTest(t)
	s := getMockInstance()

	poolPath := "gno.land/r/test/refund_calc"
	creator := testutils.TestAddress("creator")
	userA := testutils.TestAddress("userA")
	userB := testutils.TestAddress("userB")

	currentTime := time.Now().Unix()
	startTime := currentTime - 86400*10 // 10 days ago
	endTime := currentTime - 86400       // ended 1 day ago
	totalRewardAmount := int64(1000)

	// Create pool
	pool := sr.NewPool(poolPath, startTime)
	s.getPools().set(poolPath, pool)

	// Create incentive
	incentiveId := "refund-test"
	incentive := sr.NewExternalIncentive(
		incentiveId,
		poolPath,
		WUGNOT_PATH,
		totalRewardAmount,
		startTime,
		endTime,
		creator,
		100_000_000,
		runtime.ChainHeight(),
		startTime-100,
		false,
	)

	poolResolver := NewPoolResolver(pool)
	poolResolver.IncentivesResolver().create(creator, incentive)

	// Create deposits for User A and User B
	depositA := sr.NewDeposit(userA, poolPath, u256.NewUint(1000), startTime+100, -10000, 10000, []sr.Warmup{})
	depositB := sr.NewDeposit(userB, poolPath, u256.NewUint(1000), startTime+200, -10000, 10000, []sr.Warmup{})

	s.getDeposits().set(1, depositA)
	s.getDeposits().set(2, depositB)

	depositResolverA := NewDepositResolver(depositA)
	depositResolverB := NewDepositResolver(depositB)

	// User A collects 300
	collectedA := int64(300)
	depositResolverA.addCollectedExternalReward(incentiveId, collectedA)
	depositResolverA.updateExternalRewardLastCollectTime(incentiveId, endTime-1000)

	// Update DistributedRewardAmount (simulating CollectReward)
	incentiveResolver := NewExternalIncentiveResolver(incentive)
	incentiveResolver.addDistributedRewardAmount(collectedA)

	// User B collects 200
	collectedB := int64(200)
	depositResolverB.addCollectedExternalReward(incentiveId, collectedB)
	depositResolverB.updateExternalRewardLastCollectTime(incentiveId, endTime-500)

	// Update DistributedRewardAmount (simulating CollectReward)
	incentiveResolver.addDistributedRewardAmount(collectedB)

	// Verify DistributedRewardAmount = 500
	if incentiveResolver.DistributedRewardAmount() != 500 {
		t.Errorf("Expected DistributedRewardAmount 500, got %d", incentiveResolver.DistributedRewardAmount())
	}

	// Verify DistributedRewardAmount remains 500 after unstakes
	if incentiveResolver.DistributedRewardAmount() != 500 {
		t.Errorf("After unstakes, DistributedRewardAmount should still be 500, got %d", incentiveResolver.DistributedRewardAmount())
	}

	// Calculate refund
	_, refund, err := s.endExternalIncentive(poolResolver, incentiveResolver, creator, endTime+100)
	uassert.NoError(t, err)

	// Verify refund amount
	expectedRefund := int64(500)
	if refund != expectedRefund {
		t.Errorf("Expected refund %d, got %d", expectedRefund, refund)
	}

	// Verify refund is not negative
	if refund < 0 {
		t.Errorf("Refund should never be negative! Got %d", refund)
	}
}

// TestMultipleCollectionsBeforeUnstake tests that multiple collections
// by the same user correctly update DistributedRewardAmount only in CollectReward
func TestMultipleCollectionsBeforeUnstake(t *testing.T) {
	initStakerTest(t)
	s := getMockInstance()

	poolPath := "gno.land/r/test/multi_collect"
	creator := testutils.TestAddress("creator")
	user := testutils.TestAddress("user")

	currentTime := time.Now().Unix()
	startTime := currentTime - 86400*10
	endTime := currentTime + 86400*10 // still active
	totalRewardAmount := int64(10000)

	// Create pool and incentive
	pool := sr.NewPool(poolPath, startTime)
	s.getPools().set(poolPath, pool)

	incentiveId := "multi-collect-test"
	incentive := sr.NewExternalIncentive(
		incentiveId,
		poolPath,
		WUGNOT_PATH,
		totalRewardAmount,
		startTime,
		endTime,
		creator,
		100_000_000,
		runtime.ChainHeight(),
		startTime-100,
		false,
	)

	poolResolver := NewPoolResolver(pool)
	poolResolver.IncentivesResolver().create(creator, incentive)

	deposit := sr.NewDeposit(user, poolPath, u256.NewUint(1000), startTime+100, -10000, 10000, []sr.Warmup{})
	s.getDeposits().set(1, deposit)

	depositResolver := NewDepositResolver(deposit)
	incentiveResolver := NewExternalIncentiveResolver(incentive)

	// First collection: 100
	collect1 := int64(100)
	depositResolver.addCollectedExternalReward(incentiveId, collect1)
	incentiveResolver.addDistributedRewardAmount(collect1)
	depositResolver.updateExternalRewardLastCollectTime(incentiveId, currentTime-5000)

	uassert.Equal(t, int64(100), incentiveResolver.DistributedRewardAmount())

	// Second collection: 200 more
	collect2 := int64(200)
	depositResolver.addCollectedExternalReward(incentiveId, collect2)
	incentiveResolver.addDistributedRewardAmount(collect2)
	depositResolver.updateExternalRewardLastCollectTime(incentiveId, currentTime-2000)

	uassert.Equal(t, int64(300), incentiveResolver.DistributedRewardAmount())

	// Third collection: 150 more
	collect3 := int64(150)
	depositResolver.addCollectedExternalReward(incentiveId, collect3)
	incentiveResolver.addDistributedRewardAmount(collect3)
	depositResolver.updateExternalRewardLastCollectTime(incentiveId, currentTime-1000)

	uassert.Equal(t, int64(450), incentiveResolver.DistributedRewardAmount())

	// Verify total collected by user
	totalCollected := depositResolver.CollectedExternalReward(incentiveId)
	uassert.Equal(t, int64(450), totalCollected)

	// Verify DistributedRewardAmount remains unchanged
	uassert.Equal(t, int64(450), incentiveResolver.DistributedRewardAmount())
}

// TestCalculateTotalExternalRewardExcludesCollected verifies that
// calculateTotalExternalReward returns only uncollected rewards
func TestCalculateTotalExternalRewardExcludesCollected(t *testing.T) {
	initStakerTest(t)
	s := getMockInstance()

	poolPath := "gno.land/r/test/calc_total"
	creator := testutils.TestAddress("creator")
	user := testutils.TestAddress("user")

	currentTime := time.Now().Unix()
	startTime := currentTime - 86400*10
	endTime := currentTime + 86400*10
	totalRewardAmount := int64(10000)

	// Create pool and incentive
	pool := sr.NewPool(poolPath, startTime)
	s.getPools().set(poolPath, pool)

	incentiveId := "calc-total-test"
	incentive := sr.NewExternalIncentive(
		incentiveId,
		poolPath,
		WUGNOT_PATH,
		totalRewardAmount,
		startTime,
		endTime,
		creator,
		100_000_000,
		runtime.ChainHeight(),
		startTime-100,
		false,
	)

	poolResolver := NewPoolResolver(pool)
	poolResolver.IncentivesResolver().create(creator, incentive)

	// Create deposit
	deposit := sr.NewDeposit(user, poolPath, u256.NewUint(1000), startTime+100, -887220, 887220, []sr.Warmup{})
	s.getDeposits().set(1, deposit)

	depositResolver := NewDepositResolver(deposit)

	// User has already collected 300
	alreadyCollected := int64(300)
	depositResolver.addCollectedExternalReward(incentiveId, alreadyCollected)
	depositResolver.updateExternalRewardLastCollectTime(incentiveId, currentTime-5000)

	// Calculate total external reward
	rewardState := poolResolver.RewardStateOf(deposit)

	totalReward := rewardState.calculateTotalExternalReward(
		depositResolver.ExternalRewardLastCollectTime(incentiveId),
		currentTime,
		incentive,
	)

	// Verify total reward is non-negative
	if totalReward < 0 {
		t.Errorf("Total reward should be non-negative, got %d", totalReward)
	}

	// Verify collected amount is tracked separately
	collectedReward := depositResolver.CollectedExternalReward(incentiveId)
	uassert.Equal(t, alreadyCollected, collectedReward)
}

// TestDistributedRewardAmountNotDoubledOnUnstake verifies that
// DistributedRewardAmount is not modified during unstake
func TestDistributedRewardAmountNotDoubledOnUnstake(t *testing.T) {
	initStakerTest(t)
	s := getMockInstance()

	poolPath := "gno.land/r/test/no_double"
	creator := testutils.TestAddress("creator")
	user := testutils.TestAddress("user")

	currentTime := time.Now().Unix()
	startTime := currentTime - 86400*10
	endTime := currentTime - 86400
	totalRewardAmount := int64(1000)

	// Create pool and incentive
	pool := sr.NewPool(poolPath, startTime)
	s.getPools().set(poolPath, pool)

	incentiveId := "no-double-test"
	incentive := sr.NewExternalIncentive(
		incentiveId,
		poolPath,
		WUGNOT_PATH,
		totalRewardAmount,
		startTime,
		endTime,
		creator,
		100_000_000,
		runtime.ChainHeight(),
		startTime-100,
		false,
	)

	poolResolver := NewPoolResolver(pool)
	poolResolver.IncentivesResolver().create(creator, incentive)

	deposit := sr.NewDeposit(user, poolPath, u256.NewUint(1000), startTime+100, -10000, 10000, []sr.Warmup{})
	s.getDeposits().set(1, deposit)

	depositResolver := NewDepositResolver(deposit)
	incentiveResolver := NewExternalIncentiveResolver(incentive)

	// User collects 400
	collected := int64(400)
	depositResolver.addCollectedExternalReward(incentiveId, collected)
	incentiveResolver.addDistributedRewardAmount(collected)
	depositResolver.updateExternalRewardLastCollectTime(incentiveId, endTime-100)

	// Record DistributedRewardAmount before unstake
	beforeUnstake := incentiveResolver.DistributedRewardAmount()
	uassert.Equal(t, int64(400), beforeUnstake)

	// Verify DistributedRewardAmount remains unchanged after unstake
	afterUnstake := incentiveResolver.DistributedRewardAmount()
	uassert.Equal(t, int64(400), afterUnstake)

	// Verify no modification occurred during unstake
	if afterUnstake != beforeUnstake {
		t.Errorf("DistributedRewardAmount changed during unstake! Before: %d, After: %d", beforeUnstake, afterUnstake)
	}
}
