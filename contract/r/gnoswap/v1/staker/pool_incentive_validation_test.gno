package staker

import (
	"testing"
	"time"

	"gno.land/p/nt/testutils"
)

// TestStakeToken_WithEndedIncentives tests that StakeToken incorrectly allows
// staking in pools that only have ended incentives due to the bug in IsExternallyIncentivizedPool
func TestStakeToken_WithEndedIncentives(t *testing.T) {
	poolPath := "test_pool_stake_validation"
	creator := testutils.TestAddress("creator")

	testing.SetRealm(adminRealm)
	pool := NewPool(poolPath, 100)
	pools.set(poolPath, pool)

	// Add an ended incentive
	currentTime := time.Now().Unix()
	endedIncentive := &ExternalIncentive{
		incentiveId:         "ended_incentive",
		targetPoolPath:      poolPath,
		startTimestamp:      currentTime - 7200, // Started 2 hours ago
		endTimestamp:        currentTime - 3600, // Ended 1 hour ago
		rewardToken:         GNS_PATH,
		rewardAmount:        1000,
		refundee:            creator,
		depositGnsAmount:    100,
	}
	pool.incentives.create(creator, endedIncentive)

	// After fix: pool should NOT show as incentivized with only ended incentives
	if pool.IsExternallyIncentivizedPool() {
		t.Fatal("pool should NOT show as incentivized with only ended incentives")
	}

	// Test poolHasIncentives validation
	// This would normally be called within StakeToken
	// Since poolTiers might not be initialized in test, we'll check external incentives only
	hasExternalIncentives := pool.IsExternallyIncentivizedPool()

	if hasExternalIncentives {
		t.Fatal("pool should NOT have external incentives when only ended incentives exist")
	}

	// Verify that there are actually no active incentives
	activeIncentives := pool.incentives.GetIncentivesForRewardCalculation(currentTime, currentTime+3600)
	if len(activeIncentives) != 0 {
		t.Fatalf("expected 0 active incentives, got %d", len(activeIncentives))
	}

	// Clean up
	pools.tree.Remove(poolPath)
}
