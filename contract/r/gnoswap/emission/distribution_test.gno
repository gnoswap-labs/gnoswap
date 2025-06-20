package emission

import (
	"std"
	"testing"

	"gno.land/p/demo/avl"
	"gno.land/p/demo/uassert"

	"gno.land/r/gnoswap/v1/gns"
)

func TestChangeDistributionPctByAdmin(t *testing.T) {
	resetObject(t)

	originCallback := callbackStakerEmissionChange
	callbackStakerEmissionChange = func(amount int64) {}

	tests := []struct {
		name        string
		shouldPanic bool
		panicMsg    string
		setup       func()
		callerRealm std.Realm
		targets     []int
		pcts        []int64
		verify      func()
	}{
		{
			name:        "panic if caller is not admin",
			shouldPanic: true,
			panicMsg:    `caller(g10xg6559w9e93zfttlhvdmaaa0er3zewcr7nh20) is not authorized for role admin`,
			targets:     []int{1, 2, 3, 4},
			pcts:        []int64{1000, 2000, 3000, 4000},
		},
		{
			name:        "panic if target is invalid",
			shouldPanic: true,
			panicMsg:    "[GNOSWAP-EMISSION-002] invalid emission target || invalid target(9)",
			callerRealm: adminRealm,
			targets:     []int{1, 2, 3, 9},
			pcts:        []int64{1000, 2000, 3000, 4000},
		},
		{
			name:        "panic if sum of percentages is not 100%",
			shouldPanic: true,
			panicMsg:    "[GNOSWAP-EMISSION-002] invalid emission target || sum of percentages must be 10000, got 10001",
			callerRealm: adminRealm,
			targets:     []int{1, 2, 3, 4},
			pcts:        []int64{1000, 2000, 3000, 4001},
		},
		{
			name:        "success if admin",
			shouldPanic: false,
			callerRealm: adminRealm,
			targets:     []int{1, 2, 3, 4},
			pcts:        []int64{1000, 2000, 3000, 4000},
			verify: func() {
				uassert.Equal(t, int64(1000), GetDistributionBpsPct(int(1)))
				uassert.Equal(t, int64(2000), GetDistributionBpsPct(int(2)))
				uassert.Equal(t, int64(3000), GetDistributionBpsPct(int(3)))
				uassert.Equal(t, int64(4000), GetDistributionBpsPct(int(4)))
			},
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			if tt.setup != nil {
				tt.setup()
			}

			if tt.callerRealm != (std.Realm{}) {
				testing.SetRealm(tt.callerRealm)
			}

			target01, target02, target03, target04 := sliceToFourInt(t, tt.targets)
			pct01, pct02, pct03, pct04 := sliceToFourInt64(t, tt.pcts)

			if tt.shouldPanic {
				uassert.AbortsWithMessage(t, tt.panicMsg, func() {
					ChangeDistributionPctByAdmin(
						cross,
						target01, pct01,
						target02, pct02,
						target03, pct03,
						target04, pct04,
					)
				})
			} else {
				uassert.NotPanics(t, func() {
					ChangeDistributionPctByAdmin(
						cross,
						target01, pct01,
						target02, pct02,
						target03, pct03,
						target04, pct04,
					)
				})
				tt.verify()
			}
		})
	}
	callbackStakerEmissionChange = originCallback
}

func TestChangeDistributionPct(t *testing.T) {
	resetObject(t)

	originCallback := callbackStakerEmissionChange
	callbackStakerEmissionChange = func(amount int64) {}

	tests := []struct {
		name        string
		shouldPanic bool
		panicMsg    string
		setup       func()
		callerRealm std.Realm
		targets     []int
		pcts        []int64
		verify      func()
	}{
		{
			name:        "panic if caller is not governance",
			shouldPanic: true,
			panicMsg:    `caller(g10xg6559w9e93zfttlhvdmaaa0er3zewcr7nh20) is not authorized for role governance`,
			targets:     []int{1, 2, 3, 4},
			pcts:        []int64{1000, 2000, 3000, 4000},
		},
		{
			name:        "panic if target is invalid",
			shouldPanic: true,
			panicMsg:    "[GNOSWAP-EMISSION-002] invalid emission target || invalid target(9)",
			callerRealm: govRealm,
			targets:     []int{1, 2, 3, 9},
			pcts:        []int64{1000, 2000, 3000, 4000},
		},
		{
			name:        "panic if sum of percentages is not 100%",
			shouldPanic: true,
			panicMsg:    "[GNOSWAP-EMISSION-002] invalid emission target || sum of percentages must be 10000, got 10001",
			callerRealm: govRealm,
			targets:     []int{1, 2, 3, 4},
			pcts:        []int64{1000, 2000, 3000, 4001},
		},
		{
			name:        "success if governance",
			shouldPanic: false,
			callerRealm: govRealm,
			targets:     []int{1, 2, 3, 4},
			pcts:        []int64{1000, 2000, 3000, 4000},
			verify: func() {
				uassert.Equal(t, int64(1000), GetDistributionBpsPct(1))
				uassert.Equal(t, int64(2000), GetDistributionBpsPct(2))
				uassert.Equal(t, int64(3000), GetDistributionBpsPct(3))
				uassert.Equal(t, int64(4000), GetDistributionBpsPct(4))
			},
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			if tt.setup != nil {
				tt.setup()
			}

			if tt.callerRealm != (std.Realm{}) {
				testing.SetRealm(tt.callerRealm)
			}

			target01, target02, target03, target04 := sliceToFourInt(t, tt.targets)
			pct01, pct02, pct03, pct04 := sliceToFourInt64(t, tt.pcts)

			if tt.shouldPanic {
				uassert.AbortsWithMessage(t, tt.panicMsg, func() {
					ChangeDistributionPct(
						cross,
						target01, pct01,
						target02, pct02,
						target03, pct03,
						target04, pct04,
					)
				})
			} else {
				uassert.NotPanics(t, func() {
					ChangeDistributionPct(
						cross,
						target01, pct01,
						target02, pct02,
						target03, pct03,
						target04, pct04,
					)
				})
				tt.verify()
			}
		})
	}
	callbackStakerEmissionChange = originCallback
}

func TestChangeDistributionPcts(t *testing.T) {
	resetObject(t)

	originCallback := callbackStakerEmissionChange
	callbackStakerEmissionChange = func(amount int64) {}

	changeDistributionPcts(
		cross,
		1, 1000,
		2, 2000,
		3, 3000,
		4, 4000,
	)
	uassert.Equal(t, int64(1000), GetDistributionBpsPct(1))
	uassert.Equal(t, int64(2000), GetDistributionBpsPct(2))
	uassert.Equal(t, int64(3000), GetDistributionBpsPct(3))
	uassert.Equal(t, int64(4000), GetDistributionBpsPct(4))

	callbackStakerEmissionChange = originCallback
}

func TestCalculateAmount(t *testing.T) {
	tests := []struct {
		name     string
		pct      int64
		expected int64
	}{
		{name: "5% of 1_000", pct: 500, expected: 50},
		{name: "10% of 1_000", pct: 1000, expected: 100},
		{name: "55% of 1_000", pct: 5500, expected: 550},
		{name: "100% of 1_000", pct: 10000, expected: 1000},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			uassert.Equal(t, tt.expected, calculateAmount(int64(1000), tt.pct))
		})
	}
}

func TestTransferToTarget(t *testing.T) {
	resetObject(t)

	tests := []struct {
		name        string
		shouldPanic bool
		shouldAbort bool
		panicMsg    string
		setup       func()
		target      int
		amount      int64
		verify      func()
	}{
		{
			name:        "invalid target",
			shouldPanic: false,
			shouldAbort: true,
			panicMsg:    "[GNOSWAP-EMISSION-002] invalid emission target || invalid target(9)",
			target:      9,
			amount:      100,
		},
		{
			name:        "not enough balance for emission",
			shouldPanic: false,
			shouldAbort: true,
			panicMsg:    "insufficient balance",
			target:      LIQUIDITY_STAKER,
			amount:      1,
		},
		{
			name:   "transfer to LIQUIDITY_STAKER",
			target: LIQUIDITY_STAKER,
			setup: func() {
				testing.SetRealm(adminRealm)
				gns.Transfer(cross, emissionAddr, 100000) // give enough balance for emission
			},
			amount: 100,
			verify: func() {
				uassert.Equal(t, int64(100), distributedToStaker)
				uassert.Equal(t, int64(100), accuDistributedToStaker)
			},
		},
		{
			name:   "transfer to DEVOPS",
			target: DEVOPS,
			amount: 200,
			verify: func() {
				uassert.Equal(t, int64(200), distributedToDevOps)
				uassert.Equal(t, int64(200), accuDistributedToDevOps)
			},
		},
		{
			name:   "transfer to COMMUNITY_POOL",
			target: COMMUNITY_POOL,
			amount: 300,
			verify: func() {
				uassert.Equal(t, int64(300), distributedToCommunityPool)
				uassert.Equal(t, int64(300), accuDistributedToCommunityPool)
			},
		},
		{
			name:   "transfer to GOV_STAKER",
			target: GOV_STAKER,
			amount: 400,
			verify: func() {
				uassert.Equal(t, int64(400), distributedToGovStaker)
				uassert.Equal(t, int64(400), accuDistributedToGovStaker)
			},
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			if tt.setup != nil {
				tt.setup()
			}

			if tt.shouldPanic {
				uassert.PanicsWithMessage(t, tt.panicMsg, func() {
					transferToTarget(cross, tt.target, tt.amount)
				})
			} else if tt.shouldAbort {
				uassert.AbortsWithMessage(t, tt.panicMsg, func() {
					transferToTarget(cross, tt.target, tt.amount)
				})
			} else {
				uassert.NotPanics(t, func() {
					transferToTarget(cross, tt.target, tt.amount)
				})
				tt.verify()
			}
		})
	}
}

func TestClearDistributedToStaker(t *testing.T) {
	distributedToStaker = 100

	tests := []struct {
		name        string
		expected    uint64
		callerRealm std.Realm
		shouldPanic bool
		panicMsg    string
	}{
		{
			name:        "can not clear is caller is not staker",
			shouldPanic: true,
			panicMsg:    `caller(g10xg6559w9e93zfttlhvdmaaa0er3zewcr7nh20) is not authorized for role staker`,
		},
		{
			name:        "can clear if caller is staker",
			callerRealm: stakerRealm,
			expected:    0,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			if tt.callerRealm != (std.Realm{}) {
				testing.SetRealm(tt.callerRealm)
			}

			if tt.shouldPanic {
				uassert.AbortsWithMessage(t, tt.panicMsg, func() {
					ClearDistributedToStaker(cross)
				})
			} else {
				ClearDistributedToStaker(cross)
				if distributedToStaker != 0 {
					t.Errorf("distributedToStaker is not 0, got %d", distributedToStaker)
				}
			}
		})
	}
}

func TestClearClearDistributedToGovStaker(t *testing.T) {
	distributedToGovStaker = 100

	tests := []struct {
		name        string
		expected    uint64
		callerRealm std.Realm
		shouldPanic bool
		panicMsg    string
	}{
		{
			name:        "can not clear is caller is not gov/staker",
			shouldPanic: true,
			panicMsg:    `caller(g10xg6559w9e93zfttlhvdmaaa0er3zewcr7nh20) is not authorized for role gov_staker`,
		},
		{
			name:        "can clear if caller is gov/taker",
			callerRealm: govStakerRealm,
			expected:    0,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			if tt.callerRealm != (std.Realm{}) {
				testing.SetRealm(tt.callerRealm)
			}

			if tt.shouldPanic {
				uassert.AbortsWithMessage(t, tt.panicMsg, func() {
					ClearDistributedToGovStaker(cross)
				})
			} else {
				ClearDistributedToGovStaker(cross)
				if distributedToGovStaker != 0 {
					t.Errorf("distributedToGovStaker is not 0, got %d", distributedToGovStaker)
				}
			}
		})
	}
}

func sliceToFourInt(t *testing.T, slice []int) (int, int, int, int) {
	t.Helper()

	return slice[0], slice[1], slice[2], slice[3]
}

func sliceToFourInt64(t *testing.T, slice []int64) (int64, int64, int64, int64) {
	t.Helper()

	return slice[0], slice[1], slice[2], slice[3]
}

func sliceToFourUint64(t *testing.T, slice []uint64) (uint64, uint64, uint64, uint64) {
	t.Helper()

	return slice[0], slice[1], slice[2], slice[3]
}

func setupTestEnv(t *testing.T) {
	distributionBpsPct = avl.NewTree()

	distributionBpsPct.Set("1", int64(7500)) // LIQUIDITY_STAKER
	distributionBpsPct.Set("2", int64(2000)) // DEVOPS
	distributionBpsPct.Set("3", int64(500))  // COMMUNITY_POOL
	distributionBpsPct.Set("4", int64(0))    // GOV_STAKER

	distributedToStaker = 0
	distributedToDevOps = 0
	distributedToCommunityPool = 0
	distributedToGovStaker = 0

	testing.SetRealm(adminRealm)
	gns.Transfer(cross, emissionAddr, 1000000)
}

func TestDistributeToTarget(t *testing.T) {
	// Initialize test environment
	resetObject(t)

	// Test case 1: Basic distribution test
	t.Run("Basic distribution test", func(t *testing.T) {
		setupTestEnv(t)
		amount := int64(10000)
		totalSent := distributeToTarget(cross, amount)

		// Expected distribution amounts
		expectedStaker := int64(7500)   // 75%
		expectedDevOps := int64(2000)   // 20%
		expectedCommunity := int64(500) // 5%
		expectedGov := int64(0)         // 0%

		// Verify actual distribution amounts
		if distributedToStaker != expectedStaker {
			t.Errorf("Staker distribution amount mismatch: expected %d, got %d", expectedStaker, distributedToStaker)
		}
		if distributedToDevOps != expectedDevOps {
			t.Errorf("DevOps distribution amount mismatch: expected %d, got %d", expectedDevOps, distributedToDevOps)
		}
		if distributedToCommunityPool != expectedCommunity {
			t.Errorf("Community pool distribution amount mismatch: expected %d, got %d", expectedCommunity, distributedToCommunityPool)
		}
		if distributedToGovStaker != expectedGov {
			t.Errorf("Governance staker distribution amount mismatch: expected %d, got %d", expectedGov, distributedToGovStaker)
		}

		// Verify total distribution amount
		expectedTotal := expectedStaker + expectedDevOps + expectedCommunity + expectedGov
		if totalSent != expectedTotal {
			t.Errorf("Total distribution amount mismatch: expected %d, got %d", expectedTotal, totalSent)
		}

		// Verify accumulated distribution amounts
		if accuDistributedToStaker != expectedStaker {
			t.Errorf("Staker accumulated distribution amount mismatch: expected %d, got %d", expectedStaker, accuDistributedToStaker)
		}
		if accuDistributedToDevOps != expectedDevOps {
			t.Errorf("DevOps accumulated distribution amount mismatch: expected %d, got %d", expectedDevOps, accuDistributedToDevOps)
		}
		if accuDistributedToCommunityPool != expectedCommunity {
			t.Errorf("Community pool accumulated distribution amount mismatch: expected %d, got %d", expectedCommunity, accuDistributedToCommunityPool)
		}
		if accuDistributedToGovStaker != expectedGov {
			t.Errorf("Governance staker accumulated distribution amount mismatch: expected %d, got %d", expectedGov, accuDistributedToGovStaker)
		}
	})

	// Test case 2: Zero amount distribution test
	t.Run("Zero amount distribution test", func(t *testing.T) {
		resetObject(t)
		amount := int64(0)
		totalSent := distributeToTarget(cross, amount)

		if totalSent != 0 {
			t.Errorf("Total distribution amount is not 0 for zero amount: %d", totalSent)
		}

		// Verify all distribution amounts are 0
		if distributedToStaker != 0 || distributedToDevOps != 0 ||
			distributedToCommunityPool != 0 || distributedToGovStaker != 0 {
			t.Error("All distribution amounts should be 0 for zero amount")
		}
	})

	// Test case 3: Large amount distribution test
	t.Run("Large amount distribution test", func(t *testing.T) {
		resetObject(t)
		setupTestEnv(t)
		amount := int64(1000000)
		totalSent := distributeToTarget(cross, amount)

		// Expected distribution amounts
		expectedStaker := int64(750000)   // 75%
		expectedDevOps := int64(200000)   // 20%
		expectedCommunity := int64(50000) // 5%
		expectedGov := int64(0)           // 0%

		// Verify actual distribution amounts
		if distributedToStaker != expectedStaker {
			t.Errorf("Staker distribution amount mismatch: expected %d, got %d", expectedStaker, distributedToStaker)
		}
		if distributedToDevOps != expectedDevOps {
			t.Errorf("DevOps distribution amount mismatch: expected %d, got %d", expectedDevOps, distributedToDevOps)
		}
		if distributedToCommunityPool != expectedCommunity {
			t.Errorf("Community pool distribution amount mismatch: expected %d, got %d", expectedCommunity, distributedToCommunityPool)
		}
		if distributedToGovStaker != expectedGov {
			t.Errorf("Governance staker distribution amount mismatch: expected %d, got %d", expectedGov, distributedToGovStaker)
		}

		// Verify total distribution amount
		expectedTotal := expectedStaker + expectedDevOps + expectedCommunity + expectedGov
		if totalSent != expectedTotal {
			t.Errorf("Total distribution amount mismatch: expected %d, got %d", expectedTotal, totalSent)
		}

		// Verify accumulated distribution amounts
		if accuDistributedToStaker != expectedStaker {
			t.Errorf("Staker accumulated distribution amount mismatch: expected %d, got %d", expectedStaker, accuDistributedToStaker)
		}
		if accuDistributedToDevOps != expectedDevOps {
			t.Errorf("DevOps accumulated distribution amount mismatch: expected %d, got %d", expectedDevOps, accuDistributedToDevOps)
		}
		if accuDistributedToCommunityPool != expectedCommunity {
			t.Errorf("Community pool accumulated distribution amount mismatch: expected %d, got %d", expectedCommunity, accuDistributedToCommunityPool)
		}
		if accuDistributedToGovStaker != expectedGov {
			t.Errorf("Governance staker accumulated distribution amount mismatch: expected %d, got %d", expectedGov, accuDistributedToGovStaker)
		}
	})

	// Test case 4: Negative amount distribution test
	t.Run("Negative amount distribution test", func(t *testing.T) {
		resetObject(t)
		setupTestEnv(t)
		amount := int64(-10000)

		// Negative amount should cause panic
		uassert.AbortsWithMessage(t, "invalid amount or bptPct", func() {
			distributeToTarget(cross, amount)
		})

		// Verify all distribution amounts are 0
		if distributedToStaker != 0 || distributedToDevOps != 0 ||
			distributedToCommunityPool != 0 || distributedToGovStaker != 0 {
			t.Error("All distribution amounts should be 0 for negative amount")
		}
	})

	// Test case 5: Maximum value distribution test
	t.Run("Maximum value distribution test", func(t *testing.T) {
		resetObject(t)
		setupTestEnv(t)
		amount := int64(9223372036854775807) // int64 maximum value

		// Maximum value should cause panic
		uassert.AbortsWithMessage(t, "amount too large", func() {
			distributeToTarget(cross, amount)
		})

		// Verify all distribution amounts are 0
		if distributedToStaker != 0 || distributedToDevOps != 0 ||
			distributedToCommunityPool != 0 || distributedToGovStaker != 0 {
			t.Error("All distribution amounts should be 0 for maximum value")
		}
	})

	// Test case 6: Decimal amount distribution test
	t.Run("Decimal amount distribution test", func(t *testing.T) {
		resetObject(t)
		setupTestEnv(t)
		amount := int64(10001) // Amount with decimal point (e.g., 10000.1)
		totalSent := distributeToTarget(cross, amount)

		// Expected distribution amounts (decimal part is truncated)
		expectedStaker := int64(7500)   // 75%
		expectedDevOps := int64(2000)   // 20%
		expectedCommunity := int64(500) // 5%
		expectedGov := int64(0)         // 0%

		// Verify actual distribution amounts
		if distributedToStaker != expectedStaker {
			t.Errorf("Staker distribution amount mismatch: expected %d, got %d", expectedStaker, distributedToStaker)
		}
		if distributedToDevOps != expectedDevOps {
			t.Errorf("DevOps distribution amount mismatch: expected %d, got %d", expectedDevOps, distributedToDevOps)
		}
		if distributedToCommunityPool != expectedCommunity {
			t.Errorf("Community pool distribution amount mismatch: expected %d, got %d", expectedCommunity, distributedToCommunityPool)
		}
		if distributedToGovStaker != expectedGov {
			t.Errorf("Governance staker distribution amount mismatch: expected %d, got %d", expectedGov, distributedToGovStaker)
		}

		// Verify total distribution amount
		expectedTotal := expectedStaker + expectedDevOps + expectedCommunity + expectedGov
		if totalSent != expectedTotal {
			t.Errorf("Total distribution amount mismatch: expected %d, got %d", expectedTotal, totalSent)
		}
	})
}
