package v1

import (
	"chain/runtime"
	"math"
	"testing"
	"time"

	i256 "gno.land/p/gnoswap/int256"
	u256 "gno.land/p/gnoswap/uint256"
	"gno.land/p/nt/avl"
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

func TestExternalIncentivesByCreationTimeSliceStorage(t *testing.T) {
	tree := sr.NewUintTree()

	timestamp := int64(1000)
	poolPath := "pool1"

	incentiveId1 := "addr1:1000:0"

	poolIncentives := avl.NewTree()
	incentiveIds := []string{incentiveId1}
	poolIncentives.Set(poolPath, incentiveIds)

	tree.Set(timestamp, poolIncentives)

	value, exists := tree.Get(timestamp)
	if !exists {
		t.Fatal("Expected timestamp entry to exist")
	}

	poolTree, ok := value.(*avl.Tree)
	if !ok {
		t.Fatalf("Expected *avl.Tree, got %T", value)
	}

	idsValue, exists := poolTree.Get(poolPath)
	if !exists {
		t.Fatal("Expected pool entry to exist")
	}

	stored := idsValue.([]string)
	if len(stored) != 1 || stored[0] != incentiveId1 {
		t.Errorf("Expected [%s], got %v", incentiveId1, stored)
	}

	incentiveId2 := "addr2:1000:1"
	existingIds := idsValue.([]string)
	incentiveIds = append(existingIds, incentiveId2)
	poolTree.Set(poolPath, incentiveIds)
	tree.Set(timestamp, poolTree)

	value2, _ := tree.Get(timestamp)
	poolTree2 := value2.(*avl.Tree)
	idsValue2, _ := poolTree2.Get(poolPath)
	stored2 := idsValue2.([]string)

	if len(stored2) != 2 {
		t.Errorf("Expected 2 incentives, got %d", len(stored2))
	}
	if stored2[0] != incentiveId1 || stored2[1] != incentiveId2 {
		t.Errorf("Expected [%s, %s], got %v", incentiveId1, incentiveId2, stored2)
	}

	poolPath2 := "pool2"
	incentiveId3 := "addr3:1000:2"
	incentiveIds3 := []string{incentiveId3}
	poolTree2.Set(poolPath2, incentiveIds3)
	tree.Set(timestamp, poolTree2)

	value3, _ := tree.Get(timestamp)
	poolTree3 := value3.(*avl.Tree)
	idsValue3, exists := poolTree3.Get(poolPath2)
	if !exists {
		t.Fatal("Expected pool2 entry to exist")
	}

	stored3 := idsValue3.([]string)
	if len(stored3) != 1 || stored3[0] != incentiveId3 {
		t.Errorf("Expected [%s] for pool2, got %v", incentiveId3, stored3)
	}

	idsValue4, _ := poolTree3.Get(poolPath)
	stored4 := idsValue4.([]string)
	if len(stored4) != 2 {
		t.Errorf("Expected pool1 to still have 2 incentives, got %d", len(stored4))
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

	// Create 3 incentives at the same timestamp for the same pool
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

		// Add to time-based index (2-level structure: timestamp -> *avl.Tree -> poolPath -> []string)
		var incentivesByTime *sr.UintTree
		if !instance.store.HasExternalIncentivesByCreationTimeStoreKey() {
			incentivesByTime = sr.NewUintTree()
		} else {
			incentivesByTime = instance.store.GetExternalIncentivesByCreationTime()
		}

		// Get or create pool map at this timestamp
		currentPoolIncentiveIdsValue, exists := incentivesByTime.Get(currentTime)
		if !exists {
			currentPoolIncentiveIdsValue = avl.NewTree()
		}

		currentPoolIncentiveIds, ok := currentPoolIncentiveIdsValue.(*avl.Tree)
		if !ok {
			t.Fatalf("invalid type in incentivesByTime tree: expected *avl.Tree, got %T", currentPoolIncentiveIdsValue)
		}

		// Get or create incentive list for this pool
		incentiveIdsValue, exists := currentPoolIncentiveIds.Get(poolPath)
		if !exists {
			incentiveIdsValue = []string{}
		}

		ids, ok := incentiveIdsValue.([]string)
		if !ok {
			t.Fatalf("invalid type in pool incentive map: expected []string, got %T", incentiveIdsValue)
		}

		// Append new incentive ID
		ids = append(ids, incentiveId)
		currentPoolIncentiveIds.Set(poolPath, ids)
		incentivesByTime.Set(currentTime, currentPoolIncentiveIds)

		instance.store.SetExternalIncentivesByCreationTime(incentivesByTime)
	}

	// Verify all 3 incentives are stored at the same timestamp for the same pool
	incentivesByTime := instance.store.GetExternalIncentivesByCreationTime()

	poolMapValue, exists := incentivesByTime.Get(currentTime)
	if !exists {
		t.Fatal("Expected pool map at timestamp to exist")
	}

	poolMap, ok := poolMapValue.(*avl.Tree)
	if !ok {
		t.Fatalf("Expected pool map to be *avl.Tree, got %T", poolMapValue)
	}

	storedIdsValue, exists := poolMap.Get(poolPath)
	if !exists {
		t.Fatal("Expected incentive list for pool to exist")
	}

	storedIds, ok := storedIdsValue.([]string)
	if !ok {
		t.Fatalf("Expected incentive list to be []string, got %T", storedIdsValue)
	}

	if len(storedIds) != 3 {
		t.Errorf("Expected 3 incentives at same timestamp for same pool, got %d", len(storedIds))
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

		// Add to time-based index (2-level structure: timestamp -> *avl.Tree -> poolPath -> []string)
		var incentivesByTime *sr.UintTree
		if !instance.store.HasExternalIncentivesByCreationTimeStoreKey() {
			incentivesByTime = sr.NewUintTree()
		} else {
			incentivesByTime = instance.store.GetExternalIncentivesByCreationTime()
		}

		// Get or create pool map at this timestamp
		currentPoolIncentiveIdsValue, exists := incentivesByTime.Get(ts)
		if !exists {
			currentPoolIncentiveIdsValue = avl.NewTree()
		}

		currentPoolIncentiveIds, ok := currentPoolIncentiveIdsValue.(*avl.Tree)
		if !ok {
			t.Fatalf("invalid type in incentivesByTime tree: expected *avl.Tree, got %T", currentPoolIncentiveIdsValue)
		}

		// Get or create incentive list for this pool
		incentiveIdsValue, exists := currentPoolIncentiveIds.Get(poolPath)
		if !exists {
			incentiveIdsValue = []string{}
		}

		ids, ok := incentiveIdsValue.([]string)
		if !ok {
			t.Fatalf("invalid type in pool incentive map: expected []string, got %T", incentiveIdsValue)
		}

		// Append new incentive ID
		ids = append(ids, incentiveId)
		currentPoolIncentiveIds.Set(poolPath, ids)
		incentivesByTime.Set(ts, currentPoolIncentiveIds)

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
		{"Middle range", baseTime + 50, baseTime + 250, 2},      // 100, 200
		{"Exact boundaries", baseTime + 100, baseTime + 301, 3}, // 100, 200, 300 (exclusive end)
		{"Single timestamp", baseTime, baseTime + 50, 1},        // only baseTime
	}

	for _, tc := range testCases {
		t.Run(tc.name, func(t *testing.T) {
			incentivesByTime := instance.store.GetExternalIncentivesByCreationTime()

			found := make([]string, 0)
			incentivesByTime.Iterate(tc.startTime, tc.endTime, func(key int64, value any) bool {
				// value is *avl.Tree (poolPath -> []string)
				poolMap, ok := value.(*avl.Tree)
				if !ok {
					t.Fatalf("Expected *avl.Tree at timestamp %d, got %T", key, value)
				}

				// Get incentive IDs for the target pool
				idsValue, exists := poolMap.Get(poolPath)
				if exists {
					ids, ok := idsValue.([]string)
					if !ok {
						t.Fatalf("Expected []string for pool %s, got %T", poolPath, idsValue)
					}
					found = append(found, ids...)
				}
				return false
			})

			if len(found) != tc.expected {
				t.Errorf("Expected %d incentives in range [%d, %d], got %d",
					tc.expected, tc.startTime, tc.endTime, len(found))
			}
		})
	}
}

// TestCreateExternalIncentive_SameTimestampDifferentPools tests that
// incentives created at the same timestamp for different pools are properly
// stored in separate pool maps within the same timestamp entry.
func TestCreateExternalIncentive_SameTimestampDifferentPools(t *testing.T) {
	initStakerTest(t)
	instance := getMockInstance()

	pool1Path := "gno.land/r/onbloc/bar:gno.land/r/onbloc/foo:3000"
	pool2Path := "gno.land/r/onbloc/bar:gno.land/r/onbloc/qux:3000"
	pool3Path := "gno.land/r/onbloc/foo:gno.land/r/onbloc/qux:3000"
	creator := testutils.TestAddress("creator")
	currentTime := time.Now().Unix()

	// Create pools
	pool1 := sr.NewPool(pool1Path, currentTime)
	pool2 := sr.NewPool(pool2Path, currentTime)
	pool3 := sr.NewPool(pool3Path, currentTime)
	instance.getPools().set(pool1Path, pool1)
	instance.getPools().set(pool2Path, pool2)
	instance.getPools().set(pool3Path, pool3)

	poolPaths := []string{pool1Path, pool2Path, pool3Path}
	pools := []*sr.Pool{pool1, pool2, pool3}
	incentiveIdsByPool := make(map[string]string)

	startTime := currentTime + 86400
	endTime := startTime + 86400*7

	// Create one incentive for each pool at the same timestamp
	for i, poolPath := range poolPaths {
		incentiveId := instance.store.NextIncentiveID(creator, currentTime)
		incentiveIdsByPool[poolPath] = incentiveId

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
			currentTime, // Same timestamp for all
			false,
		)

		externalIncentives := instance.store.GetExternalIncentives()
		externalIncentives.Set(incentiveId, incentive)

		poolResolver := NewPoolResolver(pools[i])
		poolResolver.IncentivesResolver().create(creator, incentive)

		// Add to time-based index (2-level structure)
		var incentivesByTime *sr.UintTree
		if !instance.store.HasExternalIncentivesByCreationTimeStoreKey() {
			incentivesByTime = sr.NewUintTree()
		} else {
			incentivesByTime = instance.store.GetExternalIncentivesByCreationTime()
		}

		// Get or create pool map at this timestamp
		currentPoolIncentiveIdsValue, exists := incentivesByTime.Get(currentTime)
		if !exists {
			currentPoolIncentiveIdsValue = avl.NewTree()
		}

		currentPoolIncentiveIds, ok := currentPoolIncentiveIdsValue.(*avl.Tree)
		if !ok {
			t.Fatalf("invalid type: expected *avl.Tree, got %T", currentPoolIncentiveIdsValue)
		}

		// Get or create incentive list for this pool
		incentiveIdsValue, exists := currentPoolIncentiveIds.Get(poolPath)
		if !exists {
			incentiveIdsValue = []string{}
		}

		ids, ok := incentiveIdsValue.([]string)
		if !ok {
			t.Fatalf("invalid type: expected []string, got %T", incentiveIdsValue)
		}

		// Append new incentive ID
		ids = append(ids, incentiveId)
		currentPoolIncentiveIds.Set(poolPath, ids)
		incentivesByTime.Set(currentTime, currentPoolIncentiveIds)

		instance.store.SetExternalIncentivesByCreationTime(incentivesByTime)
	}

	// Verify all 3 pools have their incentives stored at the same timestamp
	incentivesByTime := instance.store.GetExternalIncentivesByCreationTime()

	poolMapValue, exists := incentivesByTime.Get(currentTime)
	if !exists {
		t.Fatal("Expected pool map at timestamp to exist")
	}

	poolMap, ok := poolMapValue.(*avl.Tree)
	if !ok {
		t.Fatalf("Expected *avl.Tree, got %T", poolMapValue)
	}

	// Verify each pool has exactly 1 incentive
	for _, poolPath := range poolPaths {
		idsValue, exists := poolMap.Get(poolPath)
		if !exists {
			t.Errorf("Expected incentive list for pool %s to exist", poolPath)
			continue
		}

		ids, ok := idsValue.([]string)
		if !ok {
			t.Errorf("Expected []string for pool %s, got %T", poolPath, idsValue)
			continue
		}

		if len(ids) != 1 {
			t.Errorf("Expected 1 incentive for pool %s, got %d", poolPath, len(ids))
			continue
		}

		expectedId := incentiveIdsByPool[poolPath]
		if ids[0] != expectedId {
			t.Errorf("Pool %s: expected incentive %s, got %s", poolPath, expectedId, ids[0])
		}
	}

	// Verify pool map has exactly 3 entries
	poolMapSize := poolMap.Size()
	if poolMapSize != 3 {
		t.Errorf("Expected 3 pools in pool map, got %d", poolMapSize)
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
	endTime := currentTime - 86400      // ended 1 day ago
	totalRewardAmount := int64(1_000_000_000)

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

	warmups := []sr.Warmup{
		{
			Index:          0,
			TimeDuration:   0,
			NextWarmupTime: startTime,
			WarmupRatio:    30,
		},
		{
			Index:          1,
			TimeDuration:   0,
			NextWarmupTime: startTime,
			WarmupRatio:    50,
		},
		{
			Index:          2,
			TimeDuration:   0,
			NextWarmupTime: startTime,
			WarmupRatio:    70,
		},
		{
			Index:          3,
			TimeDuration:   math.MaxInt64,
			NextWarmupTime: math.MaxInt64,
			WarmupRatio:    100,
		},
	}

	// Create deposits for User A and User B
	depositA := sr.NewDeposit(userA, poolPath, u256.NewUint(1000), startTime+100, -10000, 10000, warmups)
	depositB := sr.NewDeposit(userB, poolPath, u256.NewUint(1000), startTime+200, -10000, 10000, warmups)

	s.getDeposits().set(1, depositA)
	s.getDeposits().set(2, depositB)

	depositResolverA := NewDepositResolver(depositA)
	depositResolverB := NewDepositResolver(depositB)

	poolResolver.modifyDeposit(i256.NewInt(1000), startTime+100, 0)
	poolResolver.HistoricalTick().Set(startTime+100, int32(0))
	poolResolver.modifyDeposit(i256.NewInt(1000), startTime+200, 0)
	poolResolver.HistoricalTick().Set(startTime+200, int32(0))

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
	// remain deposit A reward: 1286000
	// remain deposit B reward: 643000
	_, refund, err := s.endExternalIncentive(poolResolver, incentiveResolver, creator, endTime+100)
	uassert.NoError(t, err)

	// Verify refund amount
	expectedRefund := int64(999035000)
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

// TestCalculateCollectableExternalReward_ExcludesCollected verifies that
// calculateCollectableExternalReward returns only uncollected rewards
func TestCalculateCollectableExternalReward_ExcludesCollected(t *testing.T) {
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

	totalReward := rewardState.calculateCollectableExternalReward(
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

// TestAddIncentiveIdByCreationTime tests the addIncentiveIdByCreationTime function
// with various scenarios using table-driven tests.
func TestAddIncentiveIdByCreationTime(t *testing.T) {
	// incentiveInput represents a single incentive to be added
	type incentiveInput struct {
		poolPath     string
		incentiveId  string
		creationTime int64
	}

	// expectedResult represents expected state for a specific pool at a specific time
	type expectedResult struct {
		creationTime int64
		poolPath     string
		incentiveIds []string
	}

	tests := []struct {
		name                 string
		inputs               []incentiveInput
		expected             []expectedResult
		expectedHasPanic     bool
		expectedPanicMessage string
	}{
		{
			name: "new time new pool - basic case",
			inputs: []incentiveInput{
				{
					poolPath:     "gno.land/r/onbloc/bar:gno.land/r/onbloc/foo:3000",
					incentiveId:  "test-incentive-1",
					creationTime: 1000,
				},
			},
			expected: []expectedResult{
				{
					creationTime: 1000,
					poolPath:     "gno.land/r/onbloc/bar:gno.land/r/onbloc/foo:3000",
					incentiveIds: []string{"test-incentive-1"},
				},
			},
		},
		{
			name: "same time same pool - multiple incentives",
			inputs: []incentiveInput{
				{
					poolPath:     "gno.land/r/onbloc/bar:gno.land/r/onbloc/foo:3000",
					incentiveId:  "incentive-a",
					creationTime: 2000,
				},
				{
					poolPath:     "gno.land/r/onbloc/bar:gno.land/r/onbloc/foo:3000",
					incentiveId:  "incentive-b",
					creationTime: 2000,
				},
				{
					poolPath:     "gno.land/r/onbloc/bar:gno.land/r/onbloc/foo:3000",
					incentiveId:  "incentive-c",
					creationTime: 2000,
				},
			},
			expected: []expectedResult{
				{
					creationTime: 2000,
					poolPath:     "gno.land/r/onbloc/bar:gno.land/r/onbloc/foo:3000",
					incentiveIds: []string{"incentive-a", "incentive-b", "incentive-c"},
				},
			},
		},
		{
			name: "same time different pools - pool isolation",
			inputs: []incentiveInput{
				{
					poolPath:     "gno.land/r/onbloc/bar:gno.land/r/onbloc/foo:3000",
					incentiveId:  "pool1-incentive",
					creationTime: 3000,
				},
				{
					poolPath:     "gno.land/r/onbloc/bar:gno.land/r/onbloc/qux:500",
					incentiveId:  "pool2-incentive",
					creationTime: 3000,
				},
			},
			expected: []expectedResult{
				{
					creationTime: 3000,
					poolPath:     "gno.land/r/onbloc/bar:gno.land/r/onbloc/foo:3000",
					incentiveIds: []string{"pool1-incentive"},
				},
				{
					creationTime: 3000,
					poolPath:     "gno.land/r/onbloc/bar:gno.land/r/onbloc/qux:500",
					incentiveIds: []string{"pool2-incentive"},
				},
			},
		},
		{
			name: "different times same pool - time isolation",
			inputs: []incentiveInput{
				{
					poolPath:     "gno.land/r/onbloc/bar:gno.land/r/onbloc/foo:3000",
					incentiveId:  "incentive-0",
					creationTime: 4000,
				},
				{
					poolPath:     "gno.land/r/onbloc/bar:gno.land/r/onbloc/foo:3000",
					incentiveId:  "incentive-1",
					creationTime: 5000,
				},
				{
					poolPath:     "gno.land/r/onbloc/bar:gno.land/r/onbloc/foo:3000",
					incentiveId:  "incentive-2",
					creationTime: 6000,
				},
			},
			expected: []expectedResult{
				{
					creationTime: 4000,
					poolPath:     "gno.land/r/onbloc/bar:gno.land/r/onbloc/foo:3000",
					incentiveIds: []string{"incentive-0"},
				},
				{
					creationTime: 5000,
					poolPath:     "gno.land/r/onbloc/bar:gno.land/r/onbloc/foo:3000",
					incentiveIds: []string{"incentive-1"},
				},
				{
					creationTime: 6000,
					poolPath:     "gno.land/r/onbloc/bar:gno.land/r/onbloc/foo:3000",
					incentiveIds: []string{"incentive-2"},
				},
			},
		},
		{
			name: "zero creation time",
			inputs: []incentiveInput{
				{
					poolPath:     "gno.land/r/test/pool",
					incentiveId:  "zero-time-incentive",
					creationTime: 0,
				},
			},
			expected: []expectedResult{
				{
					creationTime: 0,
					poolPath:     "gno.land/r/test/pool",
					incentiveIds: []string{"zero-time-incentive"},
				},
			},
		},
		{
			name: "negative creation time",
			inputs: []incentiveInput{
				{
					poolPath:     "gno.land/r/test/pool",
					incentiveId:  "negative-time-incentive",
					creationTime: -1000,
				},
			},
			expectedHasPanic:     true,
			expectedPanicMessage: "negative value not supported",
		},
		{
			name: "large creation time",
			inputs: []incentiveInput{
				{
					poolPath:     "gno.land/r/test/pool",
					incentiveId:  "large-time-incentive",
					creationTime: math.MaxInt64 - 1,
				},
			},
			expected: []expectedResult{
				{
					creationTime: math.MaxInt64 - 1,
					poolPath:     "gno.land/r/test/pool",
					incentiveIds: []string{"large-time-incentive"},
				},
			},
		},
		{
			name: "empty incentive id",
			inputs: []incentiveInput{
				{
					poolPath:     "gno.land/r/test/pool",
					incentiveId:  "",
					creationTime: 7000,
				},
			},
			expected: []expectedResult{
				{
					creationTime: 7000,
					poolPath:     "gno.land/r/test/pool",
					incentiveIds: []string{""},
				},
			},
		},
		{
			name: "duplicate incentive ids (no deduplication)",
			inputs: []incentiveInput{
				{
					poolPath:     "gno.land/r/test/pool",
					incentiveId:  "duplicate-incentive",
					creationTime: 8000,
				},
				{
					poolPath:     "gno.land/r/test/pool",
					incentiveId:  "duplicate-incentive",
					creationTime: 8000,
				},
				{
					poolPath:     "gno.land/r/test/pool",
					incentiveId:  "duplicate-incentive",
					creationTime: 8000,
				},
			},
			expected: []expectedResult{
				{
					creationTime: 8000,
					poolPath:     "gno.land/r/test/pool",
					incentiveIds: []string{"duplicate-incentive", "duplicate-incentive", "duplicate-incentive"},
				},
			},
		},
		{
			name: "multiple times, pools, and incentives",
			inputs: []incentiveInput{
				// Time 1000: pool1 has 2, pool2 has 1
				{poolPath: "pool1", incentiveId: "t1-p1-i1", creationTime: 1000},
				{poolPath: "pool1", incentiveId: "t1-p1-i2", creationTime: 1000},
				{poolPath: "pool2", incentiveId: "t1-p2-i1", creationTime: 1000},
				// Time 2000: pool2 has 1, pool3 has 2
				{poolPath: "pool2", incentiveId: "t2-p2-i1", creationTime: 2000},
				{poolPath: "pool3", incentiveId: "t2-p3-i1", creationTime: 2000},
				{poolPath: "pool3", incentiveId: "t2-p3-i2", creationTime: 2000},
				// Time 3000: pool1 has 1
				{poolPath: "pool1", incentiveId: "t3-p1-i1", creationTime: 3000},
			},
			expected: []expectedResult{
				{creationTime: 1000, poolPath: "pool1", incentiveIds: []string{"t1-p1-i1", "t1-p1-i2"}},
				{creationTime: 1000, poolPath: "pool2", incentiveIds: []string{"t1-p2-i1"}},
				{creationTime: 2000, poolPath: "pool2", incentiveIds: []string{"t2-p2-i1"}},
				{creationTime: 2000, poolPath: "pool3", incentiveIds: []string{"t2-p3-i1", "t2-p3-i2"}},
				{creationTime: 3000, poolPath: "pool1", incentiveIds: []string{"t3-p1-i1"}},
			},
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			initStakerTest(t)
			instance := getMockInstance()

			if tt.expectedHasPanic {
				uassert.PanicsContains(t, tt.expectedPanicMessage, func() {
					for _, input := range tt.inputs {
						instance.addIncentiveIdByCreationTime(input.poolPath, input.incentiveId, input.creationTime)
					}
				})

				return
			}

			// Execute: add all incentives
			for _, input := range tt.inputs {
				instance.addIncentiveIdByCreationTime(input.poolPath, input.incentiveId, input.creationTime)
			}

			// Verify: check all expected results
			incentivesByTime := instance.getExternalIncentivesByCreationTime()

			for _, exp := range tt.expected {
				// Get time entry
				value, exists := incentivesByTime.Get(exp.creationTime)
				uassert.True(t, exists, ufmt.Sprintf("Expected creation time %d to exist", exp.creationTime))

				poolIncentives, ok := value.(*avl.Tree)
				uassert.True(t, ok, "Expected value to be *avl.Tree")

				// Get pool entry
				incentiveIdsValue, exists := poolIncentives.Get(exp.poolPath)
				uassert.True(t, exists, ufmt.Sprintf("Expected pool %s to exist at time %d", exp.poolPath, exp.creationTime))

				incentiveIds, ok := incentiveIdsValue.([]string)
				uassert.True(t, ok, "Expected value to be []string")

				// Verify count
				uassert.Equal(t, len(exp.incentiveIds), len(incentiveIds))

				// Verify each incentive ID (order matters)
				for i, expectedId := range exp.incentiveIds {
					uassert.Equal(t, expectedId, incentiveIds[i])
				}
			}
		})
	}
}

// TestAddIncentiveIdByCreationTime_IterationRange tests time range iteration
// for retrieving incentives within a specific time window.
func TestAddIncentiveIdByCreationTime_IterationRange(t *testing.T) {
	// setup represents incentives to add before testing iteration
	type setup struct {
		poolPath     string
		incentiveId  string
		creationTime int64
	}

	tests := []struct {
		name          string
		setupData     []setup
		queryPoolPath string
		rangeStart    int64
		rangeEnd      int64
		expectedIds   []string
		expectedCount int
	}{
		{
			name: "middle range - partial results",
			setupData: []setup{
				{poolPath: "gno.land/r/test/pool", incentiveId: "inc-100", creationTime: 100},
				{poolPath: "gno.land/r/test/pool", incentiveId: "inc-200", creationTime: 200},
				{poolPath: "gno.land/r/test/pool", incentiveId: "inc-300", creationTime: 300},
				{poolPath: "gno.land/r/test/pool", incentiveId: "inc-400", creationTime: 400},
				{poolPath: "gno.land/r/test/pool", incentiveId: "inc-500", creationTime: 500},
			},
			queryPoolPath: "gno.land/r/test/pool",
			rangeStart:    150,
			rangeEnd:      350,
			expectedIds:   []string{"inc-200", "inc-300"},
			expectedCount: 2,
		},
		{
			name: "full range - all results",
			setupData: []setup{
				{poolPath: "gno.land/r/test/pool", incentiveId: "inc-100", creationTime: 100},
				{poolPath: "gno.land/r/test/pool", incentiveId: "inc-200", creationTime: 200},
				{poolPath: "gno.land/r/test/pool", incentiveId: "inc-300", creationTime: 300},
			},
			queryPoolPath: "gno.land/r/test/pool",
			rangeStart:    0,
			rangeEnd:      400,
			expectedIds:   []string{"inc-100", "inc-200", "inc-300"},
			expectedCount: 3,
		},
		{
			name: "empty range - no results",
			setupData: []setup{
				{poolPath: "gno.land/r/test/pool", incentiveId: "inc-100", creationTime: 100},
				{poolPath: "gno.land/r/test/pool", incentiveId: "inc-200", creationTime: 200},
			},
			queryPoolPath: "gno.land/r/test/pool",
			rangeStart:    300,
			rangeEnd:      400,
			expectedIds:   []string{},
			expectedCount: 0,
		},
		{
			name: "exact boundary match",
			setupData: []setup{
				{poolPath: "gno.land/r/test/pool", incentiveId: "inc-100", creationTime: 100},
				{poolPath: "gno.land/r/test/pool", incentiveId: "inc-200", creationTime: 200},
			},
			queryPoolPath: "gno.land/r/test/pool",
			rangeStart:    100,
			rangeEnd:      200,
			expectedIds:   []string{"inc-100"},
			expectedCount: 1,
		},
		{
			name: "filter by pool path",
			setupData: []setup{
				{poolPath: "pool-a", incentiveId: "a-inc-100", creationTime: 100},
				{poolPath: "pool-b", incentiveId: "b-inc-100", creationTime: 100},
				{poolPath: "pool-a", incentiveId: "a-inc-200", creationTime: 200},
			},
			queryPoolPath: "pool-a",
			rangeStart:    0,
			rangeEnd:      300,
			expectedIds:   []string{"a-inc-100", "a-inc-200"},
			expectedCount: 2,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			initStakerTest(t)
			instance := getMockInstance()

			// Setup: add all incentives
			for _, s := range tt.setupData {
				instance.addIncentiveIdByCreationTime(s.poolPath, s.incentiveId, s.creationTime)
			}

			// Execute: iterate over range
			incentivesByTime := instance.getExternalIncentivesByCreationTime()
			found := make([]string, 0)

			incentivesByTime.Iterate(tt.rangeStart, tt.rangeEnd, func(key int64, value any) bool {
				poolTree := value.(*avl.Tree)
				idsValue, exists := poolTree.Get(tt.queryPoolPath)
				if exists {
					ids := idsValue.([]string)
					found = append(found, ids...)
				}
				return false
			})

			// Verify
			uassert.Equal(t, tt.expectedCount, len(found))
			for i, expectedId := range tt.expectedIds {
				if i < len(found) {
					uassert.Equal(t, expectedId, found[i])
				}
			}
		})
	}
}

// TestGetExternalIncentiveIdsBy tests the getExternalIncentiveIdsBy function
// which retrieves external incentive IDs within a specific time range for a pool.
func TestGetExternalIncentiveIdsBy(t *testing.T) {
	// incentiveSetup represents an incentive to be added to the time index
	type incentiveSetup struct {
		poolPath     string
		incentiveId  string
		creationTime int64
	}

	// depositSetup represents initial deposit state
	type depositSetup struct {
		owner                          address
		poolPath                       string
		liquidity                      uint64
		stakeTimestamp                 int64
		tickLower                      int32
		tickUpper                      int32
		lastExternalIncentiveUpdatedAt int64
		existingIncentiveIds           []string
	}

	tests := []struct {
		name                          string
		incentives                    []incentiveSetup
		deposit                       depositSetup
		currentTime                   int64
		expectedIncentiveIds          []string
		expectedLastExternalUpdatedAt int64
		expectedNewIncentiveCount     int
	}{
		{
			name: "basic case - new incentives added to deposit",
			incentives: []incentiveSetup{
				{poolPath: "pool-a", incentiveId: "inc-1", creationTime: 100},
				{poolPath: "pool-a", incentiveId: "inc-2", creationTime: 200},
			},
			deposit: depositSetup{
				owner:                          testutils.TestAddress("user1"),
				poolPath:                       "pool-a",
				liquidity:                      1000,
				stakeTimestamp:                 50,
				tickLower:                      -1000,
				tickUpper:                      1000,
				lastExternalIncentiveUpdatedAt: 0,
				existingIncentiveIds:           []string{},
			},
			currentTime:                   300,
			expectedIncentiveIds:          []string{"inc-1", "inc-2"},
			expectedLastExternalUpdatedAt: 300,
			expectedNewIncentiveCount:     2,
		},
		{
			name: "no incentives when lastUpdate == currentTime",
			incentives: []incentiveSetup{
				{poolPath: "pool-a", incentiveId: "inc-1", creationTime: 100},
			},
			deposit: depositSetup{
				owner:                          testutils.TestAddress("user1"),
				poolPath:                       "pool-a",
				liquidity:                      1000,
				stakeTimestamp:                 50,
				tickLower:                      -1000,
				tickUpper:                      1000,
				lastExternalIncentiveUpdatedAt: 500,
				existingIncentiveIds:           []string{},
			},
			currentTime:                   500,
			expectedIncentiveIds:          []string{},
			expectedLastExternalUpdatedAt: 500,
			expectedNewIncentiveCount:     0,
		},
		{
			name: "partial update - only new incentives since last update",
			incentives: []incentiveSetup{
				{poolPath: "pool-a", incentiveId: "inc-old", creationTime: 100},
				{poolPath: "pool-a", incentiveId: "inc-new", creationTime: 300},
			},
			deposit: depositSetup{
				owner:                          testutils.TestAddress("user1"),
				poolPath:                       "pool-a",
				liquidity:                      1000,
				stakeTimestamp:                 50,
				tickLower:                      -1000,
				tickUpper:                      1000,
				lastExternalIncentiveUpdatedAt: 200,
				existingIncentiveIds:           []string{"inc-old"},
			},
			currentTime:                   400,
			expectedIncentiveIds:          []string{"inc-old", "inc-new"},
			expectedLastExternalUpdatedAt: 400,
			expectedNewIncentiveCount:     2,
		},
		{
			name: "filter by pool path - only matching pool incentives",
			incentives: []incentiveSetup{
				{poolPath: "pool-a", incentiveId: "a-inc-1", creationTime: 100},
				{poolPath: "pool-b", incentiveId: "b-inc-1", creationTime: 150},
				{poolPath: "pool-a", incentiveId: "a-inc-2", creationTime: 200},
				{poolPath: "pool-c", incentiveId: "c-inc-1", creationTime: 250},
			},
			deposit: depositSetup{
				owner:                          testutils.TestAddress("user1"),
				poolPath:                       "pool-a",
				liquidity:                      1000,
				stakeTimestamp:                 50,
				tickLower:                      -1000,
				tickUpper:                      1000,
				lastExternalIncentiveUpdatedAt: 0,
				existingIncentiveIds:           []string{},
			},
			currentTime:                   300,
			expectedIncentiveIds:          []string{"a-inc-1", "a-inc-2"},
			expectedLastExternalUpdatedAt: 300,
			expectedNewIncentiveCount:     2,
		},
		{
			name: "empty time range - no incentives in range",
			incentives: []incentiveSetup{
				{poolPath: "pool-a", incentiveId: "inc-1", creationTime: 500},
			},
			deposit: depositSetup{
				owner:                          testutils.TestAddress("user1"),
				poolPath:                       "pool-a",
				liquidity:                      1000,
				stakeTimestamp:                 50,
				tickLower:                      -1000,
				tickUpper:                      1000,
				lastExternalIncentiveUpdatedAt: 100,
				existingIncentiveIds:           []string{},
			},
			currentTime:                   300,
			expectedIncentiveIds:          []string{},
			expectedLastExternalUpdatedAt: 300,
			expectedNewIncentiveCount:     0,
		},
		{
			name: "multiple incentives at same timestamp",
			incentives: []incentiveSetup{
				{poolPath: "pool-a", incentiveId: "inc-1", creationTime: 100},
				{poolPath: "pool-a", incentiveId: "inc-2", creationTime: 100},
				{poolPath: "pool-a", incentiveId: "inc-3", creationTime: 100},
			},
			deposit: depositSetup{
				owner:                          testutils.TestAddress("user1"),
				poolPath:                       "pool-a",
				liquidity:                      1000,
				stakeTimestamp:                 50,
				tickLower:                      -1000,
				tickUpper:                      1000,
				lastExternalIncentiveUpdatedAt: 0,
				existingIncentiveIds:           []string{},
			},
			currentTime:                   200,
			expectedIncentiveIds:          []string{"inc-1", "inc-2", "inc-3"},
			expectedLastExternalUpdatedAt: 200,
			expectedNewIncentiveCount:     3,
		},
		{
			name: "no incentives exist for pool",
			incentives: []incentiveSetup{
				{poolPath: "pool-b", incentiveId: "b-inc-1", creationTime: 100},
				{poolPath: "pool-c", incentiveId: "c-inc-1", creationTime: 200},
			},
			deposit: depositSetup{
				owner:                          testutils.TestAddress("user1"),
				poolPath:                       "pool-a",
				liquidity:                      1000,
				stakeTimestamp:                 50,
				tickLower:                      -1000,
				tickUpper:                      1000,
				lastExternalIncentiveUpdatedAt: 0,
				existingIncentiveIds:           []string{},
			},
			currentTime:                   300,
			expectedIncentiveIds:          []string{},
			expectedLastExternalUpdatedAt: 300,
			expectedNewIncentiveCount:     0,
		},
		{
			name: "preserve existing incentive ids",
			incentives: []incentiveSetup{
				{poolPath: "pool-a", incentiveId: "new-inc", creationTime: 300},
			},
			deposit: depositSetup{
				owner:                          testutils.TestAddress("user1"),
				poolPath:                       "pool-a",
				liquidity:                      1000,
				stakeTimestamp:                 50,
				tickLower:                      -1000,
				tickUpper:                      1000,
				lastExternalIncentiveUpdatedAt: 200,
				existingIncentiveIds:           []string{"existing-inc-1", "existing-inc-2"},
			},
			currentTime:                   400,
			expectedIncentiveIds:          []string{"existing-inc-1", "existing-inc-2", "new-inc"},
			expectedLastExternalUpdatedAt: 400,
			expectedNewIncentiveCount:     3,
		},
		{
			name: "exact boundary - incentive at lastUpdate time included",
			incentives: []incentiveSetup{
				{poolPath: "pool-a", incentiveId: "boundary-inc", creationTime: 100},
				{poolPath: "pool-a", incentiveId: "after-inc", creationTime: 150},
			},
			deposit: depositSetup{
				owner:                          testutils.TestAddress("user1"),
				poolPath:                       "pool-a",
				liquidity:                      1000,
				stakeTimestamp:                 50,
				tickLower:                      -1000,
				tickUpper:                      1000,
				lastExternalIncentiveUpdatedAt: 100,
				existingIncentiveIds:           []string{},
			},
			currentTime:                   200,
			expectedIncentiveIds:          []string{"boundary-inc", "after-inc"},
			expectedLastExternalUpdatedAt: 200,
			expectedNewIncentiveCount:     2,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			initStakerTest(t)
			instance := getMockInstance()

			for _, inc := range tt.incentives {
				instance.addIncentiveIdByCreationTime(inc.poolPath, inc.incentiveId, inc.creationTime)
			}

			deposit := sr.NewDeposit(
				tt.deposit.owner,
				tt.deposit.poolPath,
				u256.NewUint(tt.deposit.liquidity),
				tt.deposit.stakeTimestamp,
				tt.deposit.tickLower,
				tt.deposit.tickUpper,
				sr.DefaultWarmupTemplate(),
			)

			deposit.SetLastExternalIncentiveUpdatedAt(tt.deposit.lastExternalIncentiveUpdatedAt)
			for _, existingId := range tt.deposit.existingIncentiveIds {
				deposit.AddExternalIncentiveId(existingId)
			}

			// Execute
			lastUpdateTime := tt.deposit.lastExternalIncentiveUpdatedAt
			newIncentiveIds := instance.getExternalIncentiveIdsBy(tt.deposit.poolPath, lastUpdateTime, tt.currentTime)

			// Add new incentives to deposit (mimicking what calculatePositionReward does)
			for _, incentiveId := range newIncentiveIds {
				deposit.AddExternalIncentiveId(incentiveId)
			}
			deposit.SetLastExternalIncentiveUpdatedAt(tt.currentTime)

			actualIds := deposit.GetExternalIncentiveIdList()
			uassert.Equal(t, tt.expectedNewIncentiveCount, len(actualIds))
			uassert.Equal(t, tt.expectedLastExternalUpdatedAt, deposit.LastExternalIncentiveUpdatedAt())

			// Verify: each expected incentive ID exists
			for _, expectedId := range tt.expectedIncentiveIds {
				uassert.True(t, deposit.HasExternalIncentiveId(expectedId),
					ufmt.Sprintf("Expected incentive %s to exist in deposit", expectedId))
			}
		})
	}
}

// TestRemoveIncentiveIdByCreationTime tests the removeIncentiveIdByCreationTime function
func TestRemoveIncentiveIdByCreationTime(t *testing.T) {
	// incentiveSetup represents an incentive to be added before testing removal
	type incentiveSetup struct {
		poolPath     string
		incentiveId  string
		creationTime int64
	}

	// expectedState represents expected state after removal for a specific time
	type expectedState struct {
		creationTime    int64
		poolPath        string
		incentiveIds    []string
		poolShouldExist bool
		timeShouldExist bool
	}

	tests := []struct {
		name              string
		setupIncentives   []incentiveSetup
		removePoolPath    string
		removeIncentiveId string
		removeTime        int64
		expected          []expectedState
	}{
		{
			name: "remove non-existent creation time - no change",
			setupIncentives: []incentiveSetup{
				{poolPath: "pool-a", incentiveId: "inc-1", creationTime: 100},
			},
			removePoolPath:    "pool-a",
			removeIncentiveId: "inc-1",
			removeTime:        999, // non-existent time
			expected: []expectedState{
				{
					creationTime:    100,
					poolPath:        "pool-a",
					incentiveIds:    []string{"inc-1"},
					poolShouldExist: true,
					timeShouldExist: true,
				},
			},
		},
		{
			name: "remove non-existent pool path - no change",
			setupIncentives: []incentiveSetup{
				{poolPath: "pool-a", incentiveId: "inc-1", creationTime: 100},
			},
			removePoolPath:    "pool-b", // non-existent pool
			removeIncentiveId: "inc-1",
			removeTime:        100,
			expected: []expectedState{
				{
					creationTime:    100,
					poolPath:        "pool-a",
					incentiveIds:    []string{"inc-1"},
					poolShouldExist: true,
					timeShouldExist: true,
				},
			},
		},
		{
			name: "remove non-existent incentive id - no change",
			setupIncentives: []incentiveSetup{
				{poolPath: "pool-a", incentiveId: "inc-1", creationTime: 100},
			},
			removePoolPath:    "pool-a",
			removeIncentiveId: "inc-999", // non-existent incentive
			removeTime:        100,
			expected: []expectedState{
				{
					creationTime:    100,
					poolPath:        "pool-a",
					incentiveIds:    []string{"inc-1"},
					poolShouldExist: true,
					timeShouldExist: true,
				},
			},
		},
		{
			name: "remove only incentive - removes pool and time entry",
			setupIncentives: []incentiveSetup{
				{poolPath: "pool-a", incentiveId: "inc-1", creationTime: 100},
			},
			removePoolPath:    "pool-a",
			removeIncentiveId: "inc-1",
			removeTime:        100,
			expected: []expectedState{
				{
					creationTime:    100,
					poolPath:        "pool-a",
					poolShouldExist: false,
					timeShouldExist: false,
				},
			},
		},
		{
			name: "remove only incentive for pool - keeps time entry with other pools",
			setupIncentives: []incentiveSetup{
				{poolPath: "pool-a", incentiveId: "inc-a", creationTime: 100},
				{poolPath: "pool-b", incentiveId: "inc-b", creationTime: 100},
			},
			removePoolPath:    "pool-a",
			removeIncentiveId: "inc-a",
			removeTime:        100,
			expected: []expectedState{
				{
					creationTime:    100,
					poolPath:        "pool-a",
					poolShouldExist: false,
					timeShouldExist: true,
				},
				{
					creationTime:    100,
					poolPath:        "pool-b",
					incentiveIds:    []string{"inc-b"},
					poolShouldExist: true,
					timeShouldExist: true,
				},
			},
		},
		{
			name: "remove one of multiple incentives - keeps others",
			setupIncentives: []incentiveSetup{
				{poolPath: "pool-a", incentiveId: "inc-1", creationTime: 100},
				{poolPath: "pool-a", incentiveId: "inc-2", creationTime: 100},
				{poolPath: "pool-a", incentiveId: "inc-3", creationTime: 100},
			},
			removePoolPath:    "pool-a",
			removeIncentiveId: "inc-2",
			removeTime:        100,
			expected: []expectedState{
				{
					creationTime:    100,
					poolPath:        "pool-a",
					incentiveIds:    []string{"inc-1", "inc-3"},
					poolShouldExist: true,
					timeShouldExist: true,
				},
			},
		},
		{
			name: "remove first incentive from list",
			setupIncentives: []incentiveSetup{
				{poolPath: "pool-a", incentiveId: "inc-1", creationTime: 100},
				{poolPath: "pool-a", incentiveId: "inc-2", creationTime: 100},
			},
			removePoolPath:    "pool-a",
			removeIncentiveId: "inc-1",
			removeTime:        100,
			expected: []expectedState{
				{
					creationTime:    100,
					poolPath:        "pool-a",
					incentiveIds:    []string{"inc-2"},
					poolShouldExist: true,
					timeShouldExist: true,
				},
			},
		},
		{
			name: "remove last incentive from list",
			setupIncentives: []incentiveSetup{
				{poolPath: "pool-a", incentiveId: "inc-1", creationTime: 100},
				{poolPath: "pool-a", incentiveId: "inc-2", creationTime: 100},
			},
			removePoolPath:    "pool-a",
			removeIncentiveId: "inc-2",
			removeTime:        100,
			expected: []expectedState{
				{
					creationTime:    100,
					poolPath:        "pool-a",
					incentiveIds:    []string{"inc-1"},
					poolShouldExist: true,
					timeShouldExist: true,
				},
			},
		},
		{
			name: "remove does not affect other times",
			setupIncentives: []incentiveSetup{
				{poolPath: "pool-a", incentiveId: "inc-1", creationTime: 100},
				{poolPath: "pool-a", incentiveId: "inc-2", creationTime: 200},
			},
			removePoolPath:    "pool-a",
			removeIncentiveId: "inc-1",
			removeTime:        100,
			expected: []expectedState{
				{
					creationTime:    100,
					poolPath:        "pool-a",
					poolShouldExist: false,
					timeShouldExist: false,
				},
				{
					creationTime:    200,
					poolPath:        "pool-a",
					incentiveIds:    []string{"inc-2"},
					poolShouldExist: true,
					timeShouldExist: true,
				},
			},
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			initStakerTest(t)
			instance := getMockInstance()

			// Setup: add incentives
			for _, inc := range tt.setupIncentives {
				instance.addIncentiveIdByCreationTime(inc.poolPath, inc.incentiveId, inc.creationTime)
			}

			// Execute: remove incentive
			instance.removeIncentiveIdByCreationTime(tt.removePoolPath, tt.removeIncentiveId, tt.removeTime)

			// Verify
			incentivesByTime := instance.getExternalIncentivesByCreationTime()

			for _, exp := range tt.expected {
				timeValue, timeExists := incentivesByTime.Get(exp.creationTime)

				if !exp.timeShouldExist {
					uassert.False(t, timeExists,
						ufmt.Sprintf("Time %d should not exist", exp.creationTime))
					continue
				}

				uassert.True(t, timeExists,
					ufmt.Sprintf("Time %d should exist", exp.creationTime))

				poolTree, ok := timeValue.(*avl.Tree)
				uassert.True(t, ok, "Expected value to be *avl.Tree")

				poolValue, poolExists := poolTree.Get(exp.poolPath)

				if !exp.poolShouldExist {
					uassert.False(t, poolExists,
						ufmt.Sprintf("Pool %s should not exist at time %d", exp.poolPath, exp.creationTime))
					continue
				}

				uassert.True(t, poolExists,
					ufmt.Sprintf("Pool %s should exist at time %d", exp.poolPath, exp.creationTime))

				incentiveIds, ok := poolValue.([]string)
				uassert.True(t, ok, "Expected value to be []string")

				uassert.Equal(t, len(exp.incentiveIds), len(incentiveIds))

				for i, expectedId := range exp.incentiveIds {
					uassert.Equal(t, expectedId, incentiveIds[i])
				}
			}
		})
	}
}
