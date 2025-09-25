package staker

import (
	"testing"
	"time"

	"gno.land/p/nt/ufmt"
	"gno.land/p/nt/testutils"
)

func TestIncentives_ArchiveIncentive(t *testing.T) {
	poolPath := "test_pool_archive"
	creator := testutils.TestAddress("creator")

	incentives := NewIncentives(poolPath)

	currentTime := time.Now().Unix()
	incentive := &ExternalIncentive{
		incentiveId:      "test_incentive_1",
		targetPoolPath:   poolPath,
		startTimestamp:   currentTime - 3600,
		endTimestamp:     currentTime + 3600,
		rewardToken:      GNS_PATH,
		rewardAmount:     1000,
		refundee:         creator,
		depositGnsAmount: 100,
	}

	incentives.create(creator, incentive)

	// Verify incentive is in active collection
	retrieved, exists := incentives.Get(incentive.incentiveId)
	if !exists {
		t.Fatal("incentive should exist in active collection")
	}
	if retrieved.incentiveId != incentive.incentiveId {
		t.Fatalf("expected incentiveId %s, got %s", incentive.incentiveId, retrieved.incentiveId)
	}

	incentives.archiveIncentive(incentive.incentiveId)

	// Verify incentive is no longer in active collection
	if _, exists := incentives.incentives.Get(incentive.incentiveId); exists {
		t.Fatal("incentive should not exist in active collection after archiving")
	}

	// Verify incentive is in archived collection
	if _, exists := incentives.archivedIncentives.Get(incentive.incentiveId); !exists {
		t.Fatal("incentive should exist in archived collection")
	}

	// Verify Get() still finds the incentive (checks both collections)
	retrieved, exists = incentives.Get(incentive.incentiveId)
	if !exists {
		t.Fatal("Get() should find incentive in archived collection")
	}
	if retrieved.incentiveId != incentive.incentiveId {
		t.Fatalf("expected incentiveId %s, got %s", incentive.incentiveId, retrieved.incentiveId)
	}
}

func TestIncentives_GetAllInTimestamps_ExcludesArchived(t *testing.T) {
	poolPath := "test_pool_timestamps"
	creator := testutils.TestAddress("creator")

	incentives := NewIncentives(poolPath)
	currentTime := time.Now().Unix()

	activeIncentive := &ExternalIncentive{
		incentiveId:      "active_incentive",
		targetPoolPath:   poolPath,
		startTimestamp:   currentTime - 1800,
		endTimestamp:     currentTime + 1800,
		rewardToken:      GNS_PATH,
		rewardAmount:     1000,
		refundee:         creator,
		depositGnsAmount: 100,
	}

	// Create ended incentive (to be archived)
	endedIncentive := &ExternalIncentive{
		incentiveId:      "ended_incentive",
		targetPoolPath:   poolPath,
		startTimestamp:   currentTime - 7200,
		endTimestamp:     currentTime - 3600,
		rewardToken:      GNS_PATH,
		rewardAmount:     1000,
		refundee:         creator,
		depositGnsAmount: 100,
	}

	// Add both incentives to active collection
	incentives.create(creator, activeIncentive)
	incentives.create(creator, endedIncentive)

	// Before archiving: GetAllInTimestamps should return only the active incentive
	activeIncentives := incentives.GetAllInTimestamps(currentTime, currentTime+1)
	if len(activeIncentives) != 1 {
		t.Fatalf("expected 1 active incentive, got %d", len(activeIncentives))
	}
	if _, exists := activeIncentives[activeIncentive.incentiveId]; !exists {
		t.Fatal("active incentive should be included in GetAllInTimestamps")
	}

	// Archive the ended incentive
	incentives.archiveIncentive(endedIncentive.incentiveId)

	// After archiving: GetAllInTimestamps should still return only the active incentive
	activeIncentives = incentives.GetAllInTimestamps(currentTime, currentTime+1)
	if len(activeIncentives) != 1 {
		t.Fatalf("expected 1 active incentive after archiving, got %d", len(activeIncentives))
	}
	if _, exists := activeIncentives[activeIncentive.incentiveId]; !exists {
		t.Fatal("active incentive should still be included after archiving")
	}
	if _, exists := activeIncentives[endedIncentive.incentiveId]; exists {
		t.Fatal("archived incentive should NOT be included in GetAllInTimestamps")
	}

	// Test with broader time range that would include the ended incentive
	broadRangeIncentives := incentives.GetAllInTimestamps(currentTime-7200, currentTime+3600)
	if len(broadRangeIncentives) != 1 {
		t.Fatalf("expected 1 active incentive with broad range, got %d", len(broadRangeIncentives))
	}
	if _, exists := broadRangeIncentives[endedIncentive.incentiveId]; exists {
		t.Fatal("archived incentive should NOT be included even with broad time range")
	}
}

func TestIncentives_ArchiveEdgeCasesAndMultiple(t *testing.T) {
	poolPath := "test_pool_combined"
	creator := testutils.TestAddress("creator")
	incentives := NewIncentives(poolPath)

	// Archive non-existent incentive (should not panic)
	incentives.archiveIncentive("non_existent_id")

	// Verify nothing was added to archived collection
	if incentives.archivedIncentives.Size() != 0 {
		t.Fatal("archived collection should remain empty when archiving non-existent incentive")
	}

	// Multiple incentive archiving
	currentTime := time.Now().Unix()

	// Create multiple incentives
	for i := 0; i < 5; i++ {
		incentive := &ExternalIncentive{
			incentiveId:      ufmt.Sprintf("incentive_%d", i),
			targetPoolPath:   poolPath,
			startTimestamp:   currentTime - int64(i*1000),
			endTimestamp:     currentTime + int64(i*1000),
			rewardToken:      GNS_PATH,
			rewardAmount:     1000,
			refundee:         creator,
			depositGnsAmount: 100,
			}
		incentives.create(creator, incentive)
	}

	// Archive incentives 0, 2, 4
	incentives.archiveIncentive("incentive_0")
	incentives.archiveIncentive("incentive_2")
	incentives.archiveIncentive("incentive_4")

	// Verify active collection has 2 incentives
	if incentives.incentives.Size() != 2 {
		t.Fatalf("expected 2 incentives in active collection, got %d", incentives.incentives.Size())
	}

	// Verify archived collection has 3 incentives
	if incentives.archivedIncentives.Size() != 3 {
		t.Fatalf("expected 3 incentives in archived collection, got %d", incentives.archivedIncentives.Size())
	}

	// Verify specific incentives are in correct collections
	if _, exists := incentives.incentives.Get("incentive_1"); !exists {
		t.Fatal("incentive_1 should be in active collection")
	}
	if _, exists := incentives.incentives.Get("incentive_3"); !exists {
		t.Fatal("incentive_3 should be in active collection")
	}
	if _, exists := incentives.archivedIncentives.Get("incentive_0"); !exists {
		t.Fatal("incentive_0 should be in archived collection")
	}
	if _, exists := incentives.archivedIncentives.Get("incentive_2"); !exists {
		t.Fatal("incentive_2 should be in archived collection")
	}
	if _, exists := incentives.archivedIncentives.Get("incentive_4"); !exists {
		t.Fatal("incentive_4 should be in archived collection")
	}
}
