package emission

import (
	"math"
	"testing"

	"gno.land/p/nt/uassert"

	prbac "gno.land/p/gnoswap/rbac"
	"gno.land/r/gnoswap/access"
	"gno.land/r/gnoswap/gns"
)

func TestCalculateAmount_SecurityValidation(t *testing.T) {
	tests := []struct {
		name                 string
		amount               int64
		bptPct               int64
		expectedResult       int64
		expectedHasPanic     bool
		expectedPanicMessage string
	}{
		{
			name:             "Valid calculation",
			amount:           1000,
			bptPct:           7500,
			expectedResult:   750,
			expectedHasPanic: false,
		},
		{
			name:                 "Negative amount should panic",
			amount:               -1000,
			bptPct:               7500,
			expectedHasPanic:     true,
			expectedPanicMessage: "invalid amount or bptPct",
		},
		{
			name:                 "Negative percentage should panic",
			amount:               1000,
			bptPct:               -100,
			expectedHasPanic:     true,
			expectedPanicMessage: "invalid amount or bptPct",
		},
		{
			name:                 "Percentage over 100% should panic",
			amount:               1000,
			bptPct:               10001,
			expectedHasPanic:     true,
			expectedPanicMessage: "invalid amount or bptPct",
		},
		{
			name:                 "Amount too large should panic",
			amount:               9223372036854775807,
			bptPct:               10000,
			expectedHasPanic:     true,
			expectedPanicMessage: "amount too large, would cause overflow",
		},
		{
			name:             "Zero percentage should return zero",
			amount:           1000,
			bptPct:           0,
			expectedResult:   0,
			expectedHasPanic: false,
		},
		{
			name:             "Maximum safe amount",
			amount:           922337203685477,
			bptPct:           10000,
			expectedResult:   922337203685477,
			expectedHasPanic: false,
		},
	}

	for _, tc := range tests {
		t.Run(tc.name, func(t *testing.T) {
			defer func() {
				if r := recover(); r != nil {
					if tc.expectedHasPanic {
						uassert.Equal(t, tc.expectedPanicMessage, r.(string))
					} else {
						t.Errorf("[%s] unexpected panic: %v", tc.name, r)
					}
				}
			}()

			// when
			result := calculateAmount(tc.amount, tc.bptPct)

			// then
			if !tc.expectedHasPanic {
				uassert.Equal(t, tc.expectedResult, result)
			}
		})
	}
}

func TestSetLeftGNSAmount_SecurityValidation(t *testing.T) {
	tests := []struct {
		name                 string
		amount               int64
		expectedHasPanic     bool
		expectedPanicMessage string
	}{
		{
			name:             "Valid positive amount",
			amount:           1000,
			expectedHasPanic: false,
		},
		{
			name:             "Zero amount",
			amount:           0,
			expectedHasPanic: false,
		},
		{
			name:                 "Negative amount should panic",
			amount:               -100,
			expectedHasPanic:     true,
			expectedPanicMessage: "left GNS amount cannot be negative",
		},
	}

	for _, tc := range tests {
		t.Run(tc.name, func(t *testing.T) {
			defer func() {
				if r := recover(); r != nil {
					if tc.expectedHasPanic {
						uassert.Equal(t, tc.expectedPanicMessage, r.(string))
					} else {
						t.Errorf("[%s] unexpected panic: %v", tc.name, r)
					}
				}
			}()

			resetObject(t)

			// when
			setLeftGNSAmount(tc.amount)

			// then
			if !tc.expectedHasPanic {
				uassert.Equal(t, tc.amount, GetLeftGNSAmount())
			}
		})
	}
}

func TestSetLastExecutedHeight_SecurityValidation(t *testing.T) {
	tests := []struct {
		name                 string
		timestamp            int64
		expectedHasPanic     bool
		expectedPanicMessage string
	}{
		{
			name:             "Valid positive timestamp",
			timestamp:        1000,
			expectedHasPanic: false,
		},
		{
			name:             "Zero timestamp",
			timestamp:        0,
			expectedHasPanic: false,
		},
		{
			name:                 "Negative timestamp should panic",
			timestamp:            -100,
			expectedHasPanic:     true,
			expectedPanicMessage: "last executed timestamp cannot be negative",
		},
	}

	for _, tc := range tests {
		t.Run(tc.name, func(t *testing.T) {
			defer func() {
				if r := recover(); r != nil {
					if tc.expectedHasPanic {
						uassert.Equal(t, tc.expectedPanicMessage, r.(string))
					} else {
						t.Errorf("[%s] unexpected panic: %v", tc.name, r)
					}
				}
			}()

			resetObject(t)

			// when
			setLastExecutedTimestamp(tc.timestamp)

			// then
			if !tc.expectedHasPanic {
				uassert.Equal(t, tc.timestamp, GetLastExecutedTimestamp())
			}
		})
	}
}

func TestAssertValidDistributionPct_SecurityValidation(t *testing.T) {
	tests := []struct {
		name                 string
		pct01                int64
		pct02                int64
		pct03                int64
		pct04                int64
		expectedHasPanic     bool
		expectedPanicMessage string
	}{
		{
			name:             "Valid percentages that sum to 100%",
			pct01:            2500,
			pct02:            2500,
			pct03:            2500,
			pct04:            2500,
			expectedHasPanic: false,
		},
		{
			name:                 "Sum exceeds 100%",
			pct01:                3000,
			pct02:                3000,
			pct03:                3000,
			pct04:                2000,
			expectedHasPanic:     true,
			expectedPanicMessage: "[GNOSWAP-EMISSION-002] invalid emission percentage || sum of percentages must be 10000, got 11000",
		},
		{
			name:                 "Sum less than 100%",
			pct01:                2000,
			pct02:                2000,
			pct03:                2000,
			pct04:                2000,
			expectedHasPanic:     true,
			expectedPanicMessage: "[GNOSWAP-EMISSION-002] invalid emission percentage || sum of percentages must be 10000, got 8000",
		},
		{
			name:                 "Negative percentage 1",
			pct01:                -1000,
			pct02:                4000,
			pct03:                3000,
			pct04:                4000,
			expectedHasPanic:     true,
			expectedPanicMessage: "[GNOSWAP-EMISSION-002] invalid emission percentage || percentage 1 cannot be negative: -1000",
		},
		{
			name:                 "Percentage exceeds 100%",
			pct01:                15000,
			pct02:                0,
			pct03:                0,
			pct04:                0,
			expectedHasPanic:     true,
			expectedPanicMessage: "[GNOSWAP-EMISSION-002] invalid emission percentage || percentage 1 cannot exceed 100%: 15000",
		},
	}

	for _, tc := range tests {
		t.Run(tc.name, func(t *testing.T) {
			defer func() {
				if r := recover(); r != nil {
					if tc.expectedHasPanic {
						if errStr, ok := r.(string); ok {
							uassert.Equal(t, tc.expectedPanicMessage, errStr)
						} else {
							uassert.Equal(t, tc.expectedPanicMessage, r.(error).Error())
						}
					} else {
						t.Errorf("[%s] unexpected panic: %v", tc.name, r)
					}
				}
			}()

			// when
			assertValidDistributionPct(tc.pct01, tc.pct02, tc.pct03, tc.pct04)

			// then - if no panic expected, test passes
		})
	}
}

// Test the calculateAmount function in isolation
func TestCalculateAmount_IsolatedSecurity(t *testing.T) {
	tests := []struct {
		name                 string
		amount               int64
		bptPct               int64
		expectedResult       int64
		expectedHasPanic     bool
		expectedPanicMessage string
	}{
		{
			name:           "Valid calculation 75%",
			amount:         1000,
			bptPct:         7500,
			expectedResult: 750,
		},
		{
			name:           "Zero percentage",
			amount:         1000,
			bptPct:         0,
			expectedResult: 0,
		},
		{
			name:           "Maximum safe amount",
			amount:         922337203685477,
			bptPct:         10000,
			expectedResult: 922337203685477,
		},
		{
			name:                 "Negative amount should panic",
			amount:               -1000,
			bptPct:               7500,
			expectedHasPanic:     true,
			expectedPanicMessage: "invalid amount or bptPct",
		},
		{
			name:                 "Overflow amount should panic",
			amount:               9223372036854775807,
			bptPct:               10000,
			expectedHasPanic:     true,
			expectedPanicMessage: "amount too large, would cause overflow",
		},
	}

	for _, tc := range tests {
		t.Run(tc.name, func(t *testing.T) {
			defer func() {
				if r := recover(); r != nil {
					if tc.expectedHasPanic {
						uassert.Equal(t, tc.expectedPanicMessage, r.(string))
					} else {
						t.Errorf("[%s] unexpected panic: %v", tc.name, r)
					}
				}
			}()

			// given - test parameters are set in table

			// when
			result := calculateAmount(tc.amount, tc.bptPct)

			// then
			if !tc.expectedHasPanic {
				uassert.Equal(t, tc.expectedResult, result)
			}
		})
	}
}

func TestAssertValidDistributionPct_IsolatedSecurity(t *testing.T) {
	tests := []struct {
		name                 string
		pct01                int64
		pct02                int64
		pct03                int64
		pct04                int64
		expectedHasPanic     bool
		expectedPanicMessage string
	}{
		{
			name:  "Valid percentages sum to 100%",
			pct01: 2500,
			pct02: 2500,
			pct03: 2500,
			pct04: 2500,
		},
		{
			name:                 "Negative percentage should panic",
			pct01:                -1000,
			pct02:                4000,
			pct03:                3000,
			pct04:                4000,
			expectedHasPanic:     true,
			expectedPanicMessage: "[GNOSWAP-EMISSION-002] invalid emission percentage || percentage 1 cannot be negative: -1000",
		},
	}

	for _, tc := range tests {
		t.Run(tc.name, func(t *testing.T) {
			defer func() {
				if r := recover(); r != nil {
					if tc.expectedHasPanic {
						// Handle both string and error types
						var actual string
						if err, ok := r.(error); ok {
							actual = err.Error()
						} else if str, ok := r.(string); ok {
							actual = str
						} else {
							t.Errorf("Unexpected panic type: %T", r)
							return
						}
						uassert.Equal(t, tc.expectedPanicMessage, actual)
					} else {
						t.Errorf("[%s] unexpected panic: %v", tc.name, r)
					}
				}
			}()

			// given - test parameters are set in table

			// when
			assertValidDistributionPct(tc.pct01, tc.pct02, tc.pct03, tc.pct04)

			// then - if no panic expected, test passes
		})
	}
}

// TestAssertValidDistributionTarget tests validation of single distribution targets
func TestAssertValidDistributionTarget(t *testing.T) {
	tests := []struct {
		name        string
		target      int
		shouldPanic bool
		panicMsg    string
	}{
		{
			name:        "Valid target LIQUIDITY_STAKER",
			target:      LIQUIDITY_STAKER,
			shouldPanic: false,
		},
		{
			name:        "Valid target DEVOPS",
			target:      DEVOPS,
			shouldPanic: false,
		},
		{
			name:        "Valid target COMMUNITY_POOL",
			target:      COMMUNITY_POOL,
			shouldPanic: false,
		},
		{
			name:        "Valid target GOV_STAKER",
			target:      GOV_STAKER,
			shouldPanic: false,
		},
		{
			name:        "Invalid target 0",
			target:      0,
			shouldPanic: true,
			panicMsg:    "[GNOSWAP-EMISSION-001] invalid emission target || invalid target(0)",
		},
		{
			name:        "Invalid target -1",
			target:      -1,
			shouldPanic: true,
			panicMsg:    "[GNOSWAP-EMISSION-001] invalid emission target || invalid target(-1)",
		},
		{
			name:        "Invalid target 5",
			target:      5,
			shouldPanic: true,
			panicMsg:    "[GNOSWAP-EMISSION-001] invalid emission target || invalid target(5)",
		},
		{
			name:        "Invalid target 999",
			target:      999,
			shouldPanic: true,
			panicMsg:    "[GNOSWAP-EMISSION-001] invalid emission target || invalid target(999)",
		},
		{
			name:        "Invalid target max int",
			target:      2147483647,
			shouldPanic: true,
			panicMsg:    "[GNOSWAP-EMISSION-001] invalid emission target || invalid target(2147483647)",
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			if tt.shouldPanic {
				uassert.PanicsWithMessage(t, tt.panicMsg, func() {
					assertValidDistributionTarget(tt.target)
				})
			} else {
				uassert.NotPanics(t, func() {
					assertValidDistributionTarget(tt.target)
				})
			}
		})
	}
}

// TestAssertValidDistributionTargets tests validation of all four distribution targets
func TestAssertValidDistributionTargets_EdgeCases(t *testing.T) {
	tests := []struct {
		name        string
		target01    int
		target02    int
		target03    int
		target04    int
		shouldPanic bool
		panicMsg    string
	}{
		{
			name:        "All valid unique targets",
			target01:    LIQUIDITY_STAKER,
			target02:    DEVOPS,
			target03:    COMMUNITY_POOL,
			target04:    GOV_STAKER,
			shouldPanic: false,
		},
		{
			name:        "All valid targets in different order",
			target01:    GOV_STAKER,
			target02:    COMMUNITY_POOL,
			target03:    DEVOPS,
			target04:    LIQUIDITY_STAKER,
			shouldPanic: false,
		},
		{
			name:        "First target invalid",
			target01:    0,
			target02:    DEVOPS,
			target03:    COMMUNITY_POOL,
			target04:    GOV_STAKER,
			shouldPanic: true,
			panicMsg:    "[GNOSWAP-EMISSION-001] invalid emission target || invalid target(0)",
		},
		{
			name:        "Last target invalid",
			target01:    LIQUIDITY_STAKER,
			target02:    DEVOPS,
			target03:    COMMUNITY_POOL,
			target04:    99,
			shouldPanic: true,
			panicMsg:    "[GNOSWAP-EMISSION-001] invalid emission target || invalid target(99)",
		},
		{
			name:        "Duplicate first and second targets",
			target01:    LIQUIDITY_STAKER,
			target02:    LIQUIDITY_STAKER,
			target03:    COMMUNITY_POOL,
			target04:    GOV_STAKER,
			shouldPanic: true,
			panicMsg:    "[GNOSWAP-EMISSION-003] duplicate emission target",
		},
		{
			name:        "Duplicate last two targets",
			target01:    LIQUIDITY_STAKER,
			target02:    DEVOPS,
			target03:    GOV_STAKER,
			target04:    GOV_STAKER,
			shouldPanic: true,
			panicMsg:    "[GNOSWAP-EMISSION-003] duplicate emission target",
		},
		{
			name:        "All same targets",
			target01:    LIQUIDITY_STAKER,
			target02:    LIQUIDITY_STAKER,
			target03:    LIQUIDITY_STAKER,
			target04:    LIQUIDITY_STAKER,
			shouldPanic: true,
			panicMsg:    "[GNOSWAP-EMISSION-003] duplicate emission target",
		},
		{
			name:        "Three targets same",
			target01:    DEVOPS,
			target02:    DEVOPS,
			target03:    DEVOPS,
			target04:    GOV_STAKER,
			shouldPanic: true,
			panicMsg:    "[GNOSWAP-EMISSION-003] duplicate emission target",
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			if tt.shouldPanic {
				uassert.PanicsWithMessage(t, tt.panicMsg, func() {
					assertValidDistributionTargets(tt.target01, tt.target02, tt.target03, tt.target04)
				})
			} else {
				uassert.NotPanics(t, func() {
					assertValidDistributionTargets(tt.target01, tt.target02, tt.target03, tt.target04)
				})
			}
		})
	}
}

// TestDistributeToTarget_SafeMath tests safe math in distributeToTarget function
func TestDistributeToTarget_SafeMath(t *testing.T) {
	tests := []struct {
		name                 string
		description          string
		initialDistribution  int64
		amountToDistribute   int64
		pct01                int64
		pct02                int64
		pct03                int64
		pct04                int64
		expectedTotalSent    int64
		expectedShouldPanic  bool
		expectedPanicMessage string
		skipDueToSetupLimit  bool
	}{
		{
			name:                "normal distribution with standard percentages",
			description:         "75% staker, 20% devops, 5% community pool, 0% gov staker",
			initialDistribution: 0,
			amountToDistribute:  1000,
			pct01:               7500,
			pct02:               2000,
			pct03:               500,
			pct04:               0,
			expectedTotalSent:   1000,
			expectedShouldPanic: false,
		},
		{
			name:                "distribution with all equal percentages",
			description:         "25% each for all four targets",
			initialDistribution: 0,
			amountToDistribute:  1000,
			pct01:               2500,
			pct02:               2500,
			pct03:               2500,
			pct04:               2500,
			expectedTotalSent:   1000,
			expectedShouldPanic: false,
		},
		{
			name:                "zero amount distribution",
			description:         "distributing zero should result in zero sent",
			initialDistribution: 0,
			amountToDistribute:  0,
			pct01:               7500,
			pct02:               2000,
			pct03:               500,
			pct04:               0,
			expectedTotalSent:   0,
			expectedShouldPanic: false,
		},
		{
			name:                "small amount with rounding",
			description:         "small amount results in truncation: 10*75%=7, 10*20%=2, 10*5%=0, total=9",
			initialDistribution: 0,
			amountToDistribute:  10,
			pct01:               7500,
			pct02:               2000,
			pct03:               500,
			pct04:               0,
			expectedTotalSent:   9, // 7+2+0+0=9 due to integer division truncation
			expectedShouldPanic: false,
		},
		{
			name:                 "large amount near int64 boundary - overflow protection",
			description:          "test that overflow is caught for extremely large amounts",
			initialDistribution:  0,
			amountToDistribute:   math.MaxInt64,
			pct01:                10000,
			pct02:                0,
			pct03:                0,
			pct04:                0,
			expectedTotalSent:    0,
			expectedShouldPanic:  true,
			expectedPanicMessage: "amount too large, would cause overflow",
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			if tt.skipDueToSetupLimit {
				t.Skip("Skipping due to setup limitations")
				return
			}

			resetObject(t)

			// Setup balance for emission address (reasonable test amount)
			emissionAddr, _ := access.GetAddress(prbac.ROLE_EMISSION.String())
			testing.SetRealm(adminRealm)
			gns.Transfer(cross, emissionAddr, 1000000) // 1M GNS for tests

			// Setup distribution percentages
			distributionBpsPct[1] = tt.pct01
			distributionBpsPct[2] = tt.pct02
			distributionBpsPct[3] = tt.pct03
			distributionBpsPct[4] = tt.pct04

			if tt.expectedShouldPanic {
				uassert.PanicsWithMessage(t, tt.expectedPanicMessage, func() {
					distributeToTarget(tt.amountToDistribute)
				})
			} else {
				totalSent, err := distributeToTarget(tt.amountToDistribute)
				uassert.NoError(t, err)
				uassert.Equal(t, tt.expectedTotalSent, totalSent)
			}
		})
	}
}

// TestTransferToTarget_CEIPattern tests the Checks-Effects-Interactions pattern
// This verifies that state is updated BEFORE external calls (gns.Transfer)
func TestTransferToTarget_CEIPattern(t *testing.T) {
	tests := []struct {
		name                         string
		description                  string
		target                       int
		targetName                   string
		amount                       int64
		initialDistributed           int64
		initialAccuDistributed       int64
		expectedDistributedAfter     int64
		expectedAccuDistributedAfter int64
		expectedBalanceChange        int64
		setupBalance                 bool
		balanceToSetup               int64
	}{
		{
			name:                         "CEI pattern for LIQUIDITY_STAKER",
			description:                  "state should be updated before transfer",
			target:                       LIQUIDITY_STAKER,
			targetName:                   "LIQUIDITY_STAKER",
			amount:                       1000,
			initialDistributed:           0,
			initialAccuDistributed:       0,
			expectedDistributedAfter:     1000,
			expectedAccuDistributedAfter: 1000,
			expectedBalanceChange:        1000,
			setupBalance:                 true,
			balanceToSetup:               10000,
		},
		{
			name:                         "CEI pattern for DEVOPS",
			description:                  "state should be updated before transfer",
			target:                       DEVOPS,
			targetName:                   "DEVOPS",
			amount:                       500,
			initialDistributed:           100,
			initialAccuDistributed:       200,
			expectedDistributedAfter:     600,
			expectedAccuDistributedAfter: 700,
			expectedBalanceChange:        500,
			setupBalance:                 true,
			balanceToSetup:               10000,
		},
		{
			name:                         "CEI pattern for COMMUNITY_POOL",
			description:                  "state should be updated before transfer",
			target:                       COMMUNITY_POOL,
			targetName:                   "COMMUNITY_POOL",
			amount:                       250,
			initialDistributed:           50,
			initialAccuDistributed:       100,
			expectedDistributedAfter:     300,
			expectedAccuDistributedAfter: 350,
			expectedBalanceChange:        250,
			setupBalance:                 true,
			balanceToSetup:               10000,
		},
		{
			name:                         "CEI pattern for GOV_STAKER",
			description:                  "state should be updated before transfer",
			target:                       GOV_STAKER,
			targetName:                   "GOV_STAKER",
			amount:                       750,
			initialDistributed:           0,
			initialAccuDistributed:       0,
			expectedDistributedAfter:     750,
			expectedAccuDistributedAfter: 750,
			expectedBalanceChange:        750,
			setupBalance:                 true,
			balanceToSetup:               10000,
		},
		{
			name:                         "cumulative distribution to LIQUIDITY_STAKER",
			description:                  "multiple transfers should accumulate correctly",
			target:                       LIQUIDITY_STAKER,
			targetName:                   "LIQUIDITY_STAKER",
			amount:                       500,
			initialDistributed:           1000,
			initialAccuDistributed:       5000,
			expectedDistributedAfter:     1500,
			expectedAccuDistributedAfter: 5500,
			expectedBalanceChange:        500,
			setupBalance:                 true,
			balanceToSetup:               10000,
		},
		{
			name:                         "panic on transfer gns amount",
			description:                  "change state before transfer",
			target:                       LIQUIDITY_STAKER,
			targetName:                   "LIQUIDITY_STAKER",
			amount:                       math.MaxInt64,
			initialDistributed:           1000,
			initialAccuDistributed:       1000,
			expectedDistributedAfter:     1000,
			expectedAccuDistributedAfter: 1000,
			expectedBalanceChange:        0,
			setupBalance:                 false,
			balanceToSetup:               0,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			resetObject(t)

			// Setup initial state based on target
			switch tt.target {
			case LIQUIDITY_STAKER:
				distributedToStaker = tt.initialDistributed
				accuDistributedToStaker = tt.initialAccuDistributed
			case DEVOPS:
				distributedToDevOps = tt.initialDistributed
				accuDistributedToDevOps = tt.initialAccuDistributed
			case COMMUNITY_POOL:
				distributedToCommunityPool = tt.initialDistributed
				accuDistributedToCommunityPool = tt.initialAccuDistributed
			case GOV_STAKER:
				distributedToGovStaker = tt.initialDistributed
				accuDistributedToGovStaker = tt.initialAccuDistributed
			}

			// Setup balance for emission
			if tt.setupBalance {
				emissionAddr, _ := access.GetAddress(prbac.ROLE_EMISSION.String())
				testing.SetRealm(adminRealm)
				gns.Transfer(cross, emissionAddr, tt.balanceToSetup)
			}

			// Execute transfer
			beforeBalance := gns.BalanceOf(emissionAddr)

			var err error

			transferToTargetFunc := func(cur realm) error {
				testing.SetRealm(testing.NewUserRealm(emissionAddr))
				return transferToTarget(tt.target, tt.amount)
			}

			if !tt.setupBalance {
				uassert.AbortsContains(t, "overflow", func() {
					transferToTargetFunc(cross)
				})
			} else {
				err = transferToTargetFunc(cross)
			}

			balanceChange := beforeBalance - gns.BalanceOf(emissionAddr)

			uassert.NoError(t, err)

			// Verify state was updated correctly (CEI pattern confirmation)
			switch tt.target {
			case LIQUIDITY_STAKER:
				uassert.Equal(t, tt.expectedDistributedAfter, distributedToStaker)
				uassert.Equal(t, tt.expectedAccuDistributedAfter, accuDistributedToStaker)
			case DEVOPS:
				uassert.Equal(t, tt.expectedDistributedAfter, distributedToDevOps)
				uassert.Equal(t, tt.expectedAccuDistributedAfter, accuDistributedToDevOps)
			case COMMUNITY_POOL:
				uassert.Equal(t, tt.expectedDistributedAfter, distributedToCommunityPool)
				uassert.Equal(t, tt.expectedAccuDistributedAfter, accuDistributedToCommunityPool)
			case GOV_STAKER:
				uassert.Equal(t, tt.expectedDistributedAfter, distributedToGovStaker)
				uassert.Equal(t, tt.expectedAccuDistributedAfter, accuDistributedToGovStaker)
			}

			uassert.Equal(t, tt.expectedBalanceChange, balanceChange)
		})
	}
}

// TestAccumulatedDistribution_SafeMath tests safe math for accumulated distribution values
func TestAccumulatedDistribution_SafeMath(t *testing.T) {
	tests := []struct {
		name                    string
		description             string
		target                  int
		targetName              string
		initialDistributed      int64
		initialAccuDistributed  int64
		amountToAdd             int64
		expectedDistributed     int64
		expectedAccuDistributed int64
		shouldPanic             bool
		panicMessage            string
	}{
		{
			name:                    "normal accumulation for LIQUIDITY_STAKER",
			description:             "adding normal amount should work correctly",
			target:                  LIQUIDITY_STAKER,
			targetName:              "LIQUIDITY_STAKER",
			initialDistributed:      1000,
			initialAccuDistributed:  5000,
			amountToAdd:             500,
			expectedDistributed:     1500,
			expectedAccuDistributed: 5500,
			shouldPanic:             false,
		},
		{
			name:                    "zero amount addition",
			description:             "adding zero should not change values",
			target:                  DEVOPS,
			targetName:              "DEVOPS",
			initialDistributed:      100,
			initialAccuDistributed:  200,
			amountToAdd:             0,
			expectedDistributed:     100,
			expectedAccuDistributed: 200,
			shouldPanic:             false,
		},
		{
			name:                    "large but safe accumulation",
			description:             "large values within int64 range should work",
			target:                  COMMUNITY_POOL,
			targetName:              "COMMUNITY_POOL",
			initialDistributed:      1000000000000,
			initialAccuDistributed:  5000000000000,
			amountToAdd:             1000000000000,
			expectedDistributed:     2000000000000,
			expectedAccuDistributed: 6000000000000,
			shouldPanic:             false,
		},
		{
			name:                    "overflow detection for distributed amount",
			description:             "adding to near-max value should panic",
			target:                  GOV_STAKER,
			targetName:              "GOV_STAKER",
			initialDistributed:      math.MaxInt64 - 100,
			initialAccuDistributed:  0,
			amountToAdd:             200,
			expectedDistributed:     0,
			expectedAccuDistributed: 0,
			shouldPanic:             true,
			panicMessage:            "int64 addition overflow",
		},
		{
			name:                    "overflow detection for accumulated amount",
			description:             "accumulated amount overflow should panic",
			target:                  LIQUIDITY_STAKER,
			targetName:              "LIQUIDITY_STAKER",
			initialDistributed:      0,
			initialAccuDistributed:  math.MaxInt64 - 50,
			amountToAdd:             100,
			expectedDistributed:     0,
			expectedAccuDistributed: 0,
			shouldPanic:             true,
			panicMessage:            "int64 addition overflow",
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			resetObject(t)

			// Setup initial state
			switch tt.target {
			case LIQUIDITY_STAKER:
				distributedToStaker = tt.initialDistributed
				accuDistributedToStaker = tt.initialAccuDistributed
			case DEVOPS:
				distributedToDevOps = tt.initialDistributed
				accuDistributedToDevOps = tt.initialAccuDistributed
			case COMMUNITY_POOL:
				distributedToCommunityPool = tt.initialDistributed
				accuDistributedToCommunityPool = tt.initialAccuDistributed
			case GOV_STAKER:
				distributedToGovStaker = tt.initialDistributed
				accuDistributedToGovStaker = tt.initialAccuDistributed
			}

			// Setup balance for emission
			emissionAddr, _ := access.GetAddress(prbac.ROLE_EMISSION.String())
			testing.SetRealm(adminRealm)
			gns.Transfer(cross, emissionAddr, 1000000000)

			if tt.shouldPanic {
				uassert.PanicsWithMessage(t, tt.panicMessage, func() {
					transferToTarget(tt.target, tt.amountToAdd)
				})
			} else {
				err := transferToTarget(tt.target, tt.amountToAdd)
				uassert.NoError(t, err)

				// Verify final state
				switch tt.target {
				case LIQUIDITY_STAKER:
					uassert.Equal(t, tt.expectedDistributed, distributedToStaker)
					uassert.Equal(t, tt.expectedAccuDistributed, accuDistributedToStaker)
				case DEVOPS:
					uassert.Equal(t, tt.expectedDistributed, distributedToDevOps)
					uassert.Equal(t, tt.expectedAccuDistributed, accuDistributedToDevOps)
				case COMMUNITY_POOL:
					uassert.Equal(t, tt.expectedDistributed, distributedToCommunityPool)
					uassert.Equal(t, tt.expectedAccuDistributed, accuDistributedToCommunityPool)
				case GOV_STAKER:
					uassert.Equal(t, tt.expectedDistributed, distributedToGovStaker)
					uassert.Equal(t, tt.expectedAccuDistributed, accuDistributedToGovStaker)
				}
			}
		})
	}
}

// TestFormatUint tests formatUint function with edge cases
func TestFormatUint(t *testing.T) {
	tests := []struct {
		name        string
		value       any
		expected    string
		shouldPanic bool
	}{
		{
			name:     "uint8 zero",
			value:    uint8(0),
			expected: "0",
		},
		{
			name:     "uint8 max",
			value:    uint8(255),
			expected: "255",
		},
		{
			name:     "uint32 zero",
			value:    uint32(0),
			expected: "0",
		},
		{
			name:     "uint32 max",
			value:    uint32(4294967295),
			expected: "4294967295",
		},
		{
			name:     "uint64 zero",
			value:    uint64(0),
			expected: "0",
		},
		{
			name:     "uint64 max",
			value:    uint64(18446744073709551615),
			expected: "18446744073709551615",
		},
		{
			name:        "invalid type int",
			value:       int(123),
			shouldPanic: true,
		},
		{
			name:        "invalid type string",
			value:       "123",
			shouldPanic: true,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			if tt.shouldPanic {
				defer func() {
					if r := recover(); r == nil {
						t.Errorf("Expected panic but got none")
					}
				}()
				formatUint(tt.value)
			} else {
				result := formatUint(tt.value)
				uassert.Equal(t, tt.expected, result)
			}
		})
	}
}

// TestFormatInt tests formatInt function with edge cases
func TestFormatInt(t *testing.T) {
	tests := []struct {
		name        string
		value       any
		expected    string
		shouldPanic bool
	}{
		{
			name:     "int zero",
			value:    int(0),
			expected: "0",
		},
		{
			name:     "int positive",
			value:    int(123),
			expected: "123",
		},
		{
			name:     "int negative",
			value:    int(-123),
			expected: "-123",
		},
		{
			name:     "int32 zero",
			value:    int32(0),
			expected: "0",
		},
		{
			name:     "int32 max",
			value:    int32(2147483647),
			expected: "2147483647",
		},
		{
			name:     "int32 min",
			value:    int32(-2147483648),
			expected: "-2147483648",
		},
		{
			name:     "int64 zero",
			value:    int64(0),
			expected: "0",
		},
		{
			name:     "int64 max",
			value:    int64(9223372036854775807),
			expected: "9223372036854775807",
		},
		{
			name:     "int64 min",
			value:    int64(-9223372036854775808),
			expected: "-9223372036854775808",
		},
		{
			name:        "invalid type uint",
			value:       uint(123),
			shouldPanic: true,
		},
		{
			name:        "invalid type string",
			value:       "123",
			shouldPanic: true,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			if tt.shouldPanic {
				defer func() {
					if r := recover(); r == nil {
						t.Errorf("Expected panic but got none")
					}
				}()
				formatInt(tt.value)
			} else {
				result := formatInt(tt.value)
				uassert.Equal(t, tt.expected, result)
			}
		})
	}
}

// TestSafeAddInt64 tests the safeAddInt64 function for overflow and underflow protection
func TestSafeAddInt64(t *testing.T) {
	tests := []struct {
		name        string
		a           int64
		b           int64
		expected    int64
		shouldPanic bool
		panicMsg    string
	}{
		{
			name:     "positive + positive",
			a:        100,
			b:        200,
			expected: 300,
		},
		{
			name:     "negative + negative",
			a:        -100,
			b:        -200,
			expected: -300,
		},
		{
			name:     "positive + negative",
			a:        100,
			b:        -50,
			expected: 50,
		},
		{
			name:     "negative + positive",
			a:        -100,
			b:        150,
			expected: 50,
		},
		{
			name:     "zero + positive",
			a:        0,
			b:        100,
			expected: 100,
		},
		{
			name:     "zero + negative",
			a:        0,
			b:        -100,
			expected: -100,
		},
		{
			name:     "zero + zero",
			a:        0,
			b:        0,
			expected: 0,
		},
		{
			name:     "max int64 + 0",
			a:        math.MaxInt64,
			b:        0,
			expected: math.MaxInt64,
		},
		{
			name:     "min int64 + 0",
			a:        math.MinInt64,
			b:        0,
			expected: math.MinInt64,
		},
		{
			name:        "overflow: max int64 + 1",
			a:           math.MaxInt64,
			b:           1,
			shouldPanic: true,
			panicMsg:    "int64 addition overflow",
		},
		{
			name:        "overflow: max int64 + max int64",
			a:           math.MaxInt64,
			b:           math.MaxInt64,
			shouldPanic: true,
			panicMsg:    "int64 addition overflow",
		},
		{
			name:        "overflow: large positive + large positive",
			a:           math.MaxInt64 - 100,
			b:           200,
			shouldPanic: true,
			panicMsg:    "int64 addition overflow",
		},
		{
			name:        "underflow: min int64 + (-1)",
			a:           math.MinInt64,
			b:           -1,
			shouldPanic: true,
			panicMsg:    "int64 addition underflow",
		},
		{
			name:        "underflow: min int64 + min int64",
			a:           math.MinInt64,
			b:           math.MinInt64,
			shouldPanic: true,
			panicMsg:    "int64 addition underflow",
		},
		{
			name:        "underflow: large negative + large negative",
			a:           math.MinInt64 + 100,
			b:           -200,
			shouldPanic: true,
			panicMsg:    "int64 addition underflow",
		},
		{
			name:     "boundary: max int64 - 1 + 1",
			a:        math.MaxInt64 - 1,
			b:        1,
			expected: math.MaxInt64,
		},
		{
			name:     "boundary: min int64 + 1 + (-1)",
			a:        math.MinInt64 + 1,
			b:        -1,
			expected: math.MinInt64,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			if tt.shouldPanic {
				uassert.PanicsWithMessage(t, tt.panicMsg, func() {
					safeAddInt64(tt.a, tt.b)
				})
			} else {
				uassert.NotPanics(t, func() {
					result := safeAddInt64(tt.a, tt.b)
					uassert.Equal(t, tt.expected, result)
				})
			}
		})
	}
}

// TestSafeSubInt64 tests the safeSubInt64 function for overflow and underflow protection
func TestSafeSubInt64(t *testing.T) {
	tests := []struct {
		name        string
		a           int64
		b           int64
		expected    int64
		shouldPanic bool
		panicMsg    string
	}{
		{
			name:     "positive - positive (positive result)",
			a:        200,
			b:        100,
			expected: 100,
		},
		{
			name:     "positive - positive (negative result)",
			a:        100,
			b:        200,
			expected: -100,
		},
		{
			name:     "negative - negative",
			a:        -100,
			b:        -200,
			expected: 100,
		},
		{
			name:     "positive - negative",
			a:        100,
			b:        -50,
			expected: 150,
		},
		{
			name:     "negative - positive",
			a:        -100,
			b:        50,
			expected: -150,
		},
		{
			name:     "zero - positive",
			a:        0,
			b:        100,
			expected: -100,
		},
		{
			name:     "zero - negative",
			a:        0,
			b:        -100,
			expected: 100,
		},
		{
			name:     "zero - zero",
			a:        0,
			b:        0,
			expected: 0,
		},
		{
			name:     "max int64 - 0",
			a:        math.MaxInt64,
			b:        0,
			expected: math.MaxInt64,
		},
		{
			name:     "min int64 - 0",
			a:        math.MinInt64,
			b:        0,
			expected: math.MinInt64,
		},
		{
			name:        "underflow: min int64 - 1",
			a:           math.MinInt64,
			b:           1,
			shouldPanic: true,
			panicMsg:    "int64 subtraction underflow",
		},
		{
			name:        "underflow: min int64 - max int64",
			a:           math.MinInt64,
			b:           math.MaxInt64,
			shouldPanic: true,
			panicMsg:    "int64 subtraction underflow",
		},
		{
			name:        "underflow: large negative - large positive",
			a:           math.MinInt64 + 100,
			b:           200,
			shouldPanic: true,
			panicMsg:    "int64 subtraction underflow",
		},
		{
			name:        "overflow: max int64 - (-1)",
			a:           math.MaxInt64,
			b:           -1,
			shouldPanic: true,
			panicMsg:    "int64 subtraction overflow",
		},
		{
			name:        "overflow: max int64 - min int64",
			a:           math.MaxInt64,
			b:           math.MinInt64,
			shouldPanic: true,
			panicMsg:    "int64 subtraction overflow",
		},
		{
			name:        "overflow: large positive - large negative",
			a:           math.MaxInt64 - 100,
			b:           -200,
			shouldPanic: true,
			panicMsg:    "int64 subtraction overflow",
		},
		{
			name:     "boundary: min int64 + 1 - 1",
			a:        math.MinInt64 + 1,
			b:        1,
			expected: math.MinInt64,
		},
		{
			name:     "boundary: max int64 - 1 - (-1)",
			a:        math.MaxInt64 - 1,
			b:        -1,
			expected: math.MaxInt64,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			if tt.shouldPanic {
				uassert.PanicsWithMessage(t, tt.panicMsg, func() {
					safeSubInt64(tt.a, tt.b)
				})
			} else {
				uassert.NotPanics(t, func() {
					result := safeSubInt64(tt.a, tt.b)
					uassert.Equal(t, tt.expected, result)
				})
			}
		})
	}
}
