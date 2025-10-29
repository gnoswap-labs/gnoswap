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
		runtime.ChainHeight(),
		100,
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
	if _, exists := incentives.Get(incentive.IncentiveId()); exists {
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
		runtime.ChainHeight(),
		100,
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
		runtime.ChainHeight(),
		100,
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
			currentTime-int64(i*1000),
			currentTime+int64(i*1000),
			creator,
			runtime.ChainHeight(),
			100,
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
