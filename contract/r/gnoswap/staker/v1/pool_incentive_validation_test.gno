package v1

import (
	"testing"
	"time"

	"gno.land/p/nt/testutils"
	"gno.land/p/nt/uassert"
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

// TestIsExternallyIncentivizedPool_InactiveIncentivePrecedesActive tests the fix for the bug where
// IsExternallyIncentivizedPool incorrectly returned false when an inactive
// incentive appeared earlier in the tree than an active one.
//
// Bug description:
// The iteration callback inside IsExternallyIncentivizedPool returned `true`
// when an incentive was *inactive*, which stopped traversal of the incentives tree.
// As a result, if an inactive incentive appeared earlier in the tree than an active one,
// the function would incorrectly report that the pool has no active external incentives.
//
// Fix:
// Invert the loop control so that it continues iterating over inactive incentives
// and breaks only when an active incentive is found.
func TestIsExternallyIncentivizedPool_InactiveIncentivePrecedesActive(t *testing.T) {
	tests := []struct {
		name        string
		description string
		setup       func(t *testing.T, pool *sr.Pool, currentTime int64)
		expected    bool
	}{
		{
			name:        "return false when pool has no incentives",
			description: "Pool with no external incentives should return false",
			setup:       func(t *testing.T, pool *sr.Pool, currentTime int64) {},
			expected:    false,
		},
		{
			name:        "return false when pool has only ended incentive",
			description: "Pool with only ended incentive should return false",
			setup: func(t *testing.T, pool *sr.Pool, currentTime int64) {
				// Execution flow:
				// 1. Create an ended incentive (startTime < currentTime < endTime is false)
				// 2. IsExternallyIncentivizedPool iterates over incentives
				// 3. isActive() returns false for the ended incentive
				// 4. Iteration continues (returns false to continue)
				// 5. No more incentives -> hasActive remains false
				creator := testutils.TestAddress("creator")
				endedIncentive := sr.NewExternalIncentive(
					"ended_only",
					pool.PoolPath(),
					GNS_PATH,
					1000,
					currentTime-7200, // Started 2 hours ago
					currentTime-3600, // Ended 1 hour ago
					creator,
					100,
					100,
					currentTime,
					false,
				)
				NewPoolResolver(pool).IncentivesResolver().create(creator, endedIncentive)
			},
			expected: false,
		},
		{
			name:        "return true when pool has active incentive",
			description: "Pool with active incentive should return true",
			setup: func(t *testing.T, pool *sr.Pool, currentTime int64) {
				// Execution flow:
				// 1. Create an active incentive (startTime <= currentTime <= endTime)
				// 2. IsExternallyIncentivizedPool iterates over incentives
				// 3. isActive() returns true for the active incentive
				// 4. hasActive = true, iteration stops (returns true to break)
				// 5. Function returns true
				creator := testutils.TestAddress("creator")
				activeIncentive := sr.NewExternalIncentive(
					"active_only",
					pool.PoolPath(),
					GNS_PATH,
					1000,
					currentTime-3600, // Started 1 hour ago
					currentTime+3600, // Ends in 1 hour
					creator,
					100,
					100,
					currentTime,
					false,
				)
				NewPoolResolver(pool).IncentivesResolver().create(creator, activeIncentive)
			},
			expected: true,
		},
		{
			name:        "return true when active incentive exists after inactive in tree order",
			description: "BUG FIX: Active incentive should be found even when inactive incentive appears first in tree iteration",
			setup: func(t *testing.T, pool *sr.Pool, currentTime int64) {
				// Execution flow (after fix):
				// 1. Create incentive "a_ended" (ID starts with 'a', appears first in AVL tree)
				// 2. Create incentive "b_active" (ID starts with 'b', appears second in AVL tree)
				// 3. IsExternallyIncentivizedPool iterates over incentives
				// 4. First: "a_ended" -> isActive() = false -> continue (returns false)
				// 5. Second: "b_active" -> isActive() = true -> hasActive = true, break (returns true)
				// 6. Function returns true (correctly finds active incentive)
				//
				// Before fix:
				// 4. First: "a_ended" -> isActive() = false -> returns true (WRONG: stops iteration)
				// 5. Function returns false (incorrectly misses active incentive)
				creator := testutils.TestAddress("creator")

				// First incentive: ended (ID "a_ended" comes first alphabetically)
				endedIncentive := sr.NewExternalIncentive(
					"a_ended",
					pool.PoolPath(),
					GNS_PATH,
					1000,
					currentTime-7200, // Started 2 hours ago
					currentTime-3600, // Ended 1 hour ago
					creator,
					100,
					100,
					currentTime,
					false,
				)
				NewPoolResolver(pool).IncentivesResolver().create(creator, endedIncentive)

				// Second incentive: active (ID "b_active" comes after "a_ended")
				activeIncentive := sr.NewExternalIncentive(
					"b_active",
					pool.PoolPath(),
					GNS_PATH,
					1000,
					currentTime-3600, // Started 1 hour ago
					currentTime+3600, // Ends in 1 hour
					creator,
					100,
					100,
					currentTime,
					false,
				)
				NewPoolResolver(pool).IncentivesResolver().create(creator, activeIncentive)
			},
			expected: true,
		},
		{
			name:        "return true when active incentive exists after multiple inactive",
			description: "Active incentive should be found even with multiple inactive incentives before it",
			setup: func(t *testing.T, pool *sr.Pool, currentTime int64) {
				// Execution flow:
				// 1. Create multiple ended incentives that appear first in tree
				// 2. Create one active incentive that appears last in tree
				// 3. Iteration should continue past all inactive incentives
				// 4. Function should correctly return true when active is found
				creator := testutils.TestAddress("creator")

				// Multiple ended incentives (alphabetically first)
				for i := 0; i < 3; i++ {
					ended := sr.NewExternalIncentive(
						"a_ended_"+string(rune('0'+i)),
						pool.PoolPath(),
						GNS_PATH,
						1000,
						currentTime-7200,
						currentTime-3600,
						creator,
						100,
						100,
						currentTime,
						false,
					)
					NewPoolResolver(pool).IncentivesResolver().create(creator, ended)
				}

				// One active incentive (alphabetically last)
				active := sr.NewExternalIncentive(
					"z_active",
					pool.PoolPath(),
					GNS_PATH,
					1000,
					currentTime-3600,
					currentTime+3600,
					creator,
					100,
					100,
					currentTime,
					false,
				)
				NewPoolResolver(pool).IncentivesResolver().create(creator, active)
			},
			expected: true,
		},
		{
			name:        "return true when pool has future incentive not yet ended",
			description: "Pool with future incentive (not started but not ended) should return true since isActive only checks endTimestamp",
			setup: func(t *testing.T, pool *sr.Pool, currentTime int64) {
				// Execution flow:
				// 1. Create future incentive: startTime > currentTime, but endTime > currentTime
				// 2. isActive() checks: currentTimestamp < endTimestamp -> true
				// 3. Note: isActive() does NOT check startTimestamp, only endTimestamp
				// 4. Function returns true (incentive is considered "active" for staking purposes)
				creator := testutils.TestAddress("creator")
				futureIncentive := sr.NewExternalIncentive(
					"future_only",
					pool.PoolPath(),
					GNS_PATH,
					1000,
					currentTime+3600, // Starts in 1 hour
					currentTime+7200, // Ends in 2 hours
					creator,
					100,
					100,
					currentTime,
					false,
				)
				NewPoolResolver(pool).IncentivesResolver().create(creator, futureIncentive)
			},
			expected: true,
		},
		{
			name:        "return true when active incentive exists after ended and future",
			description: "Active incentive should be found even with future and ended incentives before it",
			setup: func(t *testing.T, pool *sr.Pool, currentTime int64) {
				// Execution flow:
				// 1. Create ended incentive (appears first in tree)
				// 2. Create future incentive (appears second in tree)
				// 3. Create active incentive (appears last in tree)
				// 4. Iteration continues past ended -> continues past future -> finds active
				// 5. Function returns true
				creator := testutils.TestAddress("creator")

				// Ended incentive (alphabetically first)
				ended := sr.NewExternalIncentive(
					"a_ended",
					pool.PoolPath(),
					GNS_PATH,
					1000,
					currentTime-7200,
					currentTime-3600,
					creator,
					100,
					100,
					currentTime,
					false,
				)
				NewPoolResolver(pool).IncentivesResolver().create(creator, ended)

				// Future incentive (alphabetically second)
				future := sr.NewExternalIncentive(
					"b_future",
					pool.PoolPath(),
					GNS_PATH,
					1000,
					currentTime+3600,
					currentTime+7200,
					creator,
					100,
					100,
					currentTime,
					false,
				)
				NewPoolResolver(pool).IncentivesResolver().create(creator, future)

				// Active incentive (alphabetically last)
				active := sr.NewExternalIncentive(
					"c_active",
					pool.PoolPath(),
					GNS_PATH,
					1000,
					currentTime-3600,
					currentTime+3600,
					creator,
					100,
					100,
					currentTime,
					false,
				)
				NewPoolResolver(pool).IncentivesResolver().create(creator, active)
			},
			expected: true,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			initStakerTest(t)

			poolPath := "test_pool_" + tt.name
			currentTime := time.Now().Unix()

			testing.SetRealm(adminRealm)
			pool := sr.NewPool(poolPath, currentTime)
			getMockInstance().getPools().set(poolPath, pool)

			tt.setup(t, pool, currentTime)

			poolResolver := NewPoolResolver(pool)
			result := poolResolver.IsExternallyIncentivizedPool()

			uassert.Equal(t, tt.expected, result)

			t.Logf("✓ %s", tt.description)
		})
	}
}
