package v1

import (
	"chain/runtime"
	"testing"
	"time"

	"gno.land/p/nt/testutils"
	"gno.land/p/nt/ufmt"
	sr "gno.land/r/gnoswap/staker"
)

func TestIncentives_ArchiveIncentive(t *testing.T) {
	poolPath := "test_pool_archive"
	creator := testutils.TestAddress("creator")

	pool := sr.NewPool(poolPath, time.Now().Unix())
	poolResolver := NewPoolResolver(pool)
	incentives := poolResolver.IncentivesResolver()

	currentTime := time.Now().Unix()
	incentive := sr.NewExternalIncentive(
		"test_incentive_1",
		poolPath,
		GNS_PATH,
		1000,
		currentTime-3600,
		currentTime+3600,
		creator,
		100,
		runtime.ChainHeight(),
		currentTime,
		false,
	)

	incentives.create(creator, incentive)

	// Verify incentive is in active collection
	retrieved, exists := incentives.Get(incentive.IncentiveId())
	if !exists {
		t.Fatal("incentive should exist in active collection")
	}
	if retrieved.IncentiveId() != incentive.IncentiveId() {
		t.Fatalf("expected incentiveId %s, got %s", incentive.IncentiveId(), retrieved.IncentiveId())
	}

	incentives.archiveIncentive(incentive.IncentiveId())

	// Verify incentive is no longer in active collection
	if _, exists := incentives.IncentiveTrees().Get(incentive.IncentiveId()); exists {
		t.Fatal("incentive should not exist in active collection after archiving")
	}

	// Verify incentive is in archived collection
	if _, exists := incentives.ArchivedIncentives().Get(incentive.IncentiveId()); !exists {
		t.Fatal("incentive should exist in archived collection")
	}

	// Verify Get() still finds the incentive (checks both collections)
	retrieved, exists = incentives.Get(incentive.IncentiveId())
	if !exists {
		t.Fatal("Get() should find incentive in archived collection")
	}
	if retrieved.IncentiveId() != incentive.IncentiveId() {
		t.Fatalf("expected incentiveId %s, got %s", incentive.IncentiveId(), retrieved.IncentiveId())
	}
}

func TestIncentives_GetAllInTimestamps_ExcludesArchived(t *testing.T) {
	poolPath := "test_pool_timestamps"
	creator := testutils.TestAddress("creator")

	pool := sr.NewPool(poolPath, time.Now().Unix())
	poolResolver := NewPoolResolver(pool)
	incentives := poolResolver.IncentivesResolver()
	currentTime := time.Now().Unix()

	activeIncentive := sr.NewExternalIncentive(
		"active_incentive",
		poolPath,
		GNS_PATH,
		1000,
		currentTime-1800,
		currentTime+1800,
		creator,
		100,
		runtime.ChainHeight(),
		currentTime,
		false,
	)

	// Create ended incentive (to be archived)
	endedIncentive := sr.NewExternalIncentive(
		"ended_incentive",
		poolPath,
		GNS_PATH,
		1000,
		currentTime-7200,
		currentTime-3600,
		creator,
		100,
		runtime.ChainHeight(),
		currentTime,
		false,
	)

	// Add both incentives to active collection
	incentives.create(creator, activeIncentive)
	incentives.create(creator, endedIncentive)

	// Before archiving: GetAllInTimestamps should return only the active incentive
	activeIncentives := incentives.GetAllInTimestamps(currentTime, currentTime+1)
	if len(activeIncentives) != 1 {
		t.Fatalf("expected 1 active incentive, got %d", len(activeIncentives))
	}
	if _, exists := activeIncentives[activeIncentive.IncentiveId()]; !exists {
		t.Fatal("active incentive should be included in GetAllInTimestamps")
	}

	// Archive the ended incentive
	incentives.archiveIncentive(endedIncentive.IncentiveId())

	// After archiving: GetAllInTimestamps should still return only the active incentive
	activeIncentives = incentives.GetAllInTimestamps(currentTime, currentTime+1)
	if len(activeIncentives) != 1 {
		t.Fatalf("expected 1 active incentive after archiving, got %d", len(activeIncentives))
	}
	if _, exists := activeIncentives[activeIncentive.IncentiveId()]; !exists {
		t.Fatal("active incentive should still be included after archiving")
	}
	if _, exists := activeIncentives[endedIncentive.IncentiveId()]; exists {
		t.Fatal("archived incentive should NOT be included in GetAllInTimestamps")
	}

	// Test with broader time range that would include the ended incentive
	broadRangeIncentives := incentives.GetAllInTimestamps(currentTime-7200, currentTime+3600)
	if len(broadRangeIncentives) != 1 {
		t.Fatalf("expected 1 active incentive with broad range, got %d", len(broadRangeIncentives))
	}
	if _, exists := broadRangeIncentives[endedIncentive.IncentiveId()]; exists {
		t.Fatal("archived incentive should NOT be included even with broad time range")
	}
}

func TestIncentives_ArchiveEdgeCasesAndMultiple(t *testing.T) {
	poolPath := "test_pool_combined"
	creator := testutils.TestAddress("creator")
	pool := sr.NewPool(poolPath, time.Now().Unix())
	poolResolver := NewPoolResolver(pool)
	incentives := poolResolver.IncentivesResolver()

	// Archive non-existent incentive (should not panic)
	incentives.archiveIncentive("non_existent_id")

	// Verify nothing was added to archived collection
	if incentives.ArchivedIncentives().Size() != 0 {
		t.Fatal("archived collection should remain empty when archiving non-existent incentive")
	}

	// Multiple incentive archiving
	currentTime := time.Now().Unix()

	// Create multiple incentives
	for i := 0; i < 5; i++ {
		incentive := sr.NewExternalIncentive(
			ufmt.Sprintf("incentive_%d", i),
			poolPath,
			GNS_PATH,
			1000,
			currentTime-int64((i+1)*1000),
			currentTime+int64((i+1)*1000),
			creator,
			100,
			runtime.ChainHeight(),
			currentTime,
			false,
		)
		incentives.create(creator, incentive)
	}

	// Archive incentives 0, 2, 4
	incentives.archiveIncentive("incentive_0")
	incentives.archiveIncentive("incentive_2")
	incentives.archiveIncentive("incentive_4")

	// Verify active collection has 2 incentives
	if incentives.IncentiveTrees().Size() != 2 {
		t.Fatalf("expected 2 incentives in active collection, got %d", incentives.IncentiveTrees().Size())
	}

	// Verify archived collection has 3 incentives
	if incentives.ArchivedIncentives().Size() != 3 {
		t.Fatalf("expected 3 incentives in archived collection, got %d", incentives.ArchivedIncentives().Size())
	}

	// Verify specific incentives are in correct collections
	if _, exists := incentives.IncentiveTrees().Get("incentive_1"); !exists {
		t.Fatal("incentive_1 should be in active collection")
	}
	if _, exists := incentives.IncentiveTrees().Get("incentive_3"); !exists {
		t.Fatal("incentive_3 should be in active collection")
	}
	if _, exists := incentives.ArchivedIncentives().Get("incentive_0"); !exists {
		t.Fatal("incentive_0 should be in archived collection")
	}
	if _, exists := incentives.ArchivedIncentives().Get("incentive_2"); !exists {
		t.Fatal("incentive_2 should be in archived collection")
	}
	if _, exists := incentives.ArchivedIncentives().Get("incentive_4"); !exists {
		t.Fatal("incentive_4 should be in archived collection")
	}
}

// Test IsArchived function
func TestIsArchived(t *testing.T) {
	tests := []struct {
		name               string
		setupFunc          func(*IncentivesResolver, *sr.ExternalIncentive)
		expectedIsArchived bool
	}{
		{
			name: "before creating incentive - not archived",
			setupFunc: func(incentives *IncentivesResolver, incentive *sr.ExternalIncentive) {
				// Don't create incentive
			},
			expectedIsArchived: false,
		},
		{
			name: "after creating incentive - not archived",
			setupFunc: func(incentives *IncentivesResolver, incentive *sr.ExternalIncentive) {
				creator := testutils.TestAddress("creator")
				incentives.create(creator, incentive)
			},
			expectedIsArchived: false,
		},
		{
			name: "after archiving incentive - archived",
			setupFunc: func(incentives *IncentivesResolver, incentive *sr.ExternalIncentive) {
				creator := testutils.TestAddress("creator")
				incentives.create(creator, incentive)
				incentives.archiveIncentive(incentive.IncentiveId())
			},
			expectedIsArchived: true,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			poolPath := "test_pool_is_archived"
			creator := testutils.TestAddress("creator")
			pool := sr.NewPool(poolPath, time.Now().Unix())
			poolResolver := NewPoolResolver(pool)
			incentives := poolResolver.IncentivesResolver()

			currentTime := time.Now().Unix()
			incentive := sr.NewExternalIncentive(
				"test_incentive",
				poolPath,
				GNS_PATH,
				1000,
				currentTime,
				currentTime+3600,
				creator,
				100,
				runtime.ChainHeight(),
				currentTime,
				false,
			)

			tt.setupFunc(incentives, incentive)

			isArchived := incentives.IsArchived(incentive.IncentiveId())
			if isArchived != tt.expectedIsArchived {
				t.Fatalf("expected isArchived %v, got %v", tt.expectedIsArchived, isArchived)
			}
		})
	}
}

// Test create function
func TestIncentivesCreate(t *testing.T) {
	tests := []struct {
		name              string
		incentiveId       string
		rewardAmount      int64
		expectedExists    bool
		expectedRewardAmt int64
	}{
		{
			name:              "create incentive with 5000 reward",
			incentiveId:       "test_incentive_create",
			rewardAmount:      5000,
			expectedExists:    true,
			expectedRewardAmt: 5000,
		},
		{
			name:              "create incentive with 1000 reward",
			incentiveId:       "test_incentive_1000",
			rewardAmount:      1000,
			expectedExists:    true,
			expectedRewardAmt: 1000,
		},
		{
			name:              "create incentive with large reward",
			incentiveId:       "test_incentive_large",
			rewardAmount:      1_000_000_000,
			expectedExists:    true,
			expectedRewardAmt: 1_000_000_000,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			poolPath := "test_pool_create"
			creator := testutils.TestAddress("creator")
			pool := sr.NewPool(poolPath, time.Now().Unix())
			poolResolver := NewPoolResolver(pool)
			incentives := poolResolver.IncentivesResolver()

			currentTime := time.Now().Unix()
			incentive := sr.NewExternalIncentive(
				tt.incentiveId,
				poolPath,
				GNS_PATH,
				tt.rewardAmount,
				currentTime,
				currentTime+7200,
				creator,
				100,
				runtime.ChainHeight(),
				currentTime,
				false,
			)

			// Create incentive
			incentives.create(creator, incentive)

			// Verify incentive was created
			retrieved, exists := incentives.Get(incentive.IncentiveId())
			if exists != tt.expectedExists {
				t.Fatalf("expected exists %v, got %v", tt.expectedExists, exists)
			}
			if retrieved.IncentiveId() != incentive.IncentiveId() {
				t.Fatalf("expected incentiveId %s, got %s", incentive.IncentiveId(), retrieved.IncentiveId())
			}
			if retrieved.RewardAmount() != tt.expectedRewardAmt {
				t.Fatalf("expected reward amount %d, got %d", tt.expectedRewardAmt, retrieved.RewardAmount())
			}
		})
	}
}

// Test update function
func TestIncentivesUpdate(t *testing.T) {
	tests := []struct {
		name        string
		incentiveId string
		updateFunc  func(*sr.ExternalIncentive)
		verifyFunc  func(*testing.T, *sr.ExternalIncentive)
	}{
		{
			name:        "update incentive - set refunded to true",
			incentiveId: "test_incentive_update",
			updateFunc: func(incentive *sr.ExternalIncentive) {
				incentive.SetRefunded(true)
			},
			verifyFunc: func(t *testing.T, retrieved *sr.ExternalIncentive) {
				if !retrieved.Refunded() {
					t.Fatal("incentive should be marked as refunded after update")
				}
			},
		},
		{
			name:        "update incentive - set refunded to false",
			incentiveId: "test_incentive_update_false",
			updateFunc: func(incentive *sr.ExternalIncentive) {
				incentive.SetRefunded(false)
			},
			verifyFunc: func(t *testing.T, retrieved *sr.ExternalIncentive) {
				if retrieved.Refunded() {
					t.Fatal("incentive should not be marked as refunded")
				}
			},
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			poolPath := "test_pool_update"
			creator := testutils.TestAddress("creator")
			pool := sr.NewPool(poolPath, time.Now().Unix())
			poolResolver := NewPoolResolver(pool)
			incentives := poolResolver.IncentivesResolver()

			currentTime := time.Now().Unix()
			incentive := sr.NewExternalIncentive(
				tt.incentiveId,
				poolPath,
				GNS_PATH,
				1000,
				currentTime,
				currentTime+3600,
				creator,
				100,
				runtime.ChainHeight(),
				currentTime,
				false,
			)

			// Create incentive
			incentives.create(creator, incentive)

			// Modify incentive
			tt.updateFunc(incentive)

			// Update incentive
			incentives.update(creator, incentive)

			// Verify update
			retrieved, exists := incentives.Get(incentive.IncentiveId())
			if !exists {
				t.Fatal("incentive should exist after update")
			}
			tt.verifyFunc(t, retrieved)
		})
	}
}

// Test startUnclaimablePeriod function
func TestStartUnclaimablePeriod(t *testing.T) {
	tests := []struct {
		name             string
		startTime        int64
		expectedEndValue int64
	}{
		{
			name:             "start unclaimable period at time 1000",
			startTime:        1000,
			expectedEndValue: 0,
		},
		{
			name:             "start unclaimable period at time 5000",
			startTime:        5000,
			expectedEndValue: 0,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			poolPath := "test_pool_start_unclaimable"
			pool := sr.NewPool(poolPath, time.Now().Unix())
			poolResolver := NewPoolResolver(pool)
			incentives := poolResolver.IncentivesResolver()

			// Start unclaimable period
			incentives.startUnclaimablePeriod(tt.startTime)

			// Verify period was started (value should be 0, meaning ongoing)
			value, exists := incentives.Incentives.UnclaimablePeriods().Get(tt.startTime)
			if !exists {
				t.Fatal("unclaimable period should exist after start")
			}
			endTime, ok := value.(int64)
			if !ok {
				t.Fatal("value should be int64")
			}
			if endTime != tt.expectedEndValue {
				t.Fatalf("expected ongoing period (%d), got %d", tt.expectedEndValue, endTime)
			}
		})
	}
}

// Test endUnclaimablePeriod function
func TestEndUnclaimablePeriod(t *testing.T) {
	tests := []struct {
		name            string
		startTime       int64
		endTime         int64
		expectedEndTime int64
		shouldExist     bool
	}{
		{
			name:            "end unclaimable period after 3600 seconds",
			startTime:       1000,
			endTime:         4600,
			expectedEndTime: 4600,
			shouldExist:     true,
		},
		{
			name:            "end unclaimable period after 1 second",
			startTime:       1000,
			endTime:         1001,
			expectedEndTime: 1001,
			shouldExist:     true,
		},
		{
			name:            "end unclaimable period at same time (should remove)",
			startTime:       1000,
			endTime:         1000,
			expectedEndTime: 0,
			shouldExist:     false,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			poolPath := "test_pool_end_unclaimable"
			pool := sr.NewPool(poolPath, time.Now().Unix())
			poolResolver := NewPoolResolver(pool)
			incentives := poolResolver.IncentivesResolver()

			// Start unclaimable period
			incentives.startUnclaimablePeriod(tt.startTime)

			// End unclaimable period
			incentives.endUnclaimablePeriod(tt.endTime)

			// Verify period state
			value, exists := incentives.Incentives.UnclaimablePeriods().Get(tt.startTime)
			if exists != tt.shouldExist {
				t.Fatalf("expected period existence %v, got %v", tt.shouldExist, exists)
			}

			if tt.shouldExist {
				storedEndTime, ok := value.(int64)
				if !ok {
					t.Fatal("value should be int64")
				}
				if storedEndTime != tt.expectedEndTime {
					t.Fatalf("expected end time %d, got %d", tt.expectedEndTime, storedEndTime)
				}
			}
		})
	}
}

// Note: calculateUnclaimableReward is indirectly tested through calculateUnClaimableDuration tests
// Direct testing of calculateUnclaimableReward is complex due to shared pool state
// The core logic is validated through TestCalculateUnClaimableDuration below

// Test calculateUnClaimableDuration function
func TestCalculateUnClaimableDuration(t *testing.T) {
	tests := []struct {
		name                    string
		unclaimableStart        int64
		unclaimableEnd          int64
		incentiveStartTimestamp int64
		incentiveEndTimestamp   int64
		expectedDuration        int64
	}{
		{
			name:                    "full overlap",
			unclaimableStart:        1000,
			unclaimableEnd:          2000,
			incentiveStartTimestamp: 1000,
			incentiveEndTimestamp:   2000,
			expectedDuration:        1000,
		},
		{
			name:                    "partial overlap - unclaimable starts earlier",
			unclaimableStart:        500,
			unclaimableEnd:          1500,
			incentiveStartTimestamp: 1000,
			incentiveEndTimestamp:   2000,
			expectedDuration:        500,
		},
		{
			name:                    "partial overlap - unclaimable ends later",
			unclaimableStart:        1500,
			unclaimableEnd:          2500,
			incentiveStartTimestamp: 1000,
			incentiveEndTimestamp:   2000,
			expectedDuration:        500,
		},
		{
			name:                    "no overlap - unclaimable before incentive",
			unclaimableStart:        500,
			unclaimableEnd:          800,
			incentiveStartTimestamp: 1000,
			incentiveEndTimestamp:   2000,
			expectedDuration:        0,
		},
		{
			name:                    "no overlap - unclaimable after incentive",
			unclaimableStart:        2500,
			unclaimableEnd:          3000,
			incentiveStartTimestamp: 1000,
			incentiveEndTimestamp:   2000,
			expectedDuration:        0,
		},
		{
			name:                    "unclaimable fully contains incentive",
			unclaimableStart:        500,
			unclaimableEnd:          2500,
			incentiveStartTimestamp: 1000,
			incentiveEndTimestamp:   2000,
			expectedDuration:        1000,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			duration := calculateUnClaimableDuration(
				tt.unclaimableStart,
				tt.unclaimableEnd,
				tt.incentiveStartTimestamp,
				tt.incentiveEndTimestamp,
			)
			if duration != tt.expectedDuration {
				t.Fatalf("expected duration %d, got %d", tt.expectedDuration, duration)
			}
		})
	}
}

// Test NewIncentivesResolver function
func TestNewIncentivesResolver(t *testing.T) {
	poolPath := "test_pool_new_resolver"
	pool := sr.NewPool(poolPath, time.Now().Unix())

	// Create resolver using constructor
	resolver := NewIncentivesResolver(pool.Incentives())

	// Verify resolver was created
	if resolver == nil {
		t.Fatal("resolver should not be nil")
	}
	if resolver.Incentives == nil {
		t.Fatal("resolver.Incentives should not be nil")
	}
}
