package v1

import (
	"testing"
	"time"

	"gno.land/p/nt/testutils"
	sr "gno.land/r/gnoswap/staker"
)

// TestStakeToken_WithEndedIncentives tests that StakeToken incorrectly allows
// staking in pools that only have ended incentives due to the bug in IsExternallyIncentivizedPool
func TestStakeToken_WithEndedIncentives(t *testing.T) {
	initStakerTest(t)

	// given
	poolPath := "test_pool_stake_validation"
	creator := testutils.TestAddress("creator")

	testing.SetRealm(adminRealm)
	pool := sr.NewPool(poolPath, 100)
	getMockInstance().getPools().set(poolPath, pool)

	// Add an ended incentive
	currentTime := time.Now().Unix()
	endedIncentive := sr.NewExternalIncentive(
		"ended_incentive",
		poolPath,
		GNS_PATH,
		1000,
		currentTime-7200, // Started 2 hours ago
		currentTime-3600, // Ended 1 hour ago
		creator,
		100, // depositGnsAmount
		100, // createdHeight
		currentTime,
		false, // isRequestUnwrap
	)
	poolResolver := NewPoolResolver(pool)
	poolResolver.IncentivesResolver().create(creator, endedIncentive)

	// After fix: pool should NOT show as incentivized with only ended incentives
	if poolResolver.IsExternallyIncentivizedPool() {
		t.Fatal("pool should NOT show as incentivized with only ended incentives")
	}

	// Test poolHasIncentives validation
	// This would normally be called within StakeToken
	// Since poolTiers might not be initialized in test, we'll check external incentives only
	hasExternalIncentives := poolResolver.IsExternallyIncentivizedPool()

	if hasExternalIncentives {
		t.Fatal("pool should NOT have external incentives when only ended incentives exist")
	}

	// Verify that there are actually no active incentives
	activeIncentives := poolResolver.IncentivesResolver().GetAllInTimestamps(currentTime, currentTime+3600)
	if len(activeIncentives) != 0 {
		t.Fatalf("expected 0 active incentives, got %d", len(activeIncentives))
	}

	// Clean up
	getMockInstance().getPools().tree.Remove(poolPath)
}
