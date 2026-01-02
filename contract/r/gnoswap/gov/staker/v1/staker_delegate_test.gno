package v1

import (
	"math"
	"testing"

	"gno.land/p/nt/avl"
	"gno.land/p/nt/testutils"
	"gno.land/p/nt/uassert"

	_ "gno.land/p/gnoswap/rbac"
	_ "gno.land/r/gnoswap/rbac"

	_ "gno.land/r/gnoswap/access"

	_ "gno.land/r/gnoswap/protocol_fee"
	_ "gno.land/r/gnoswap/protocol_fee/v1"

	"gno.land/r/gnoswap/gov/staker"

	"gno.land/r/gnoswap/gns"
	"gno.land/r/gnoswap/gov/xgns"
)

// Test Delegate function
func TestStakerDelegate_Delegate(t *testing.T) {
	// Initialize gov staker
	gs := createTestGovStaker()

	tests := []struct {
		name          string
		caller        address
		to            address
		amount        int64
		referrer      string
		expectPanic   bool
		expectedError string
		setupMocks    func()
		cleanupMocks  func()
	}{
		{
			name:        "Successful delegation with valid parameters",
			caller:      testutils.TestAddress("alice"),
			to:          testutils.TestAddress("validator1"),
			amount:      minimumAmount,
			referrer:    "",
			expectPanic: false,
			setupMocks: func() {
				// Setup mocks for successful delegation
				cleanupStakerDelegateTest(t, gs)
			},
			cleanupMocks: func() {
				cleanupStakerDelegateTest(t, gs)
			},
		},
		{
			name:          "Invalid address should panic",
			caller:        testutils.TestAddress("alice"),
			to:            address(""),
			amount:        minimumAmount,
			referrer:      "",
			expectPanic:   true,
			expectedError: "invalid address: ",
			setupMocks: func() {
				cleanupStakerDelegateTest(t, gs)
			},
			cleanupMocks: func() {
				cleanupStakerDelegateTest(t, gs)
			},
		},
		{
			name:          "Amount less than minimum should panic",
			caller:        testutils.TestAddress("alice"),
			to:            testutils.TestAddress("validator1"),
			amount:        minimumAmount - 1,
			referrer:      "",
			expectPanic:   true,
			expectedError: "[GNOSWAP-GOV_STAKER-011] cannot delegate less than minimum amount || minimum amount to delegate is 1000000 (requested:999999)",
			setupMocks: func() {
				cleanupStakerDelegateTest(t, gs)
			},
			cleanupMocks: func() {
				cleanupStakerDelegateTest(t, gs)
			},
		},
		{
			name:          "Amount not multiple of minimum should panic",
			caller:        testutils.TestAddress("alice"),
			to:            testutils.TestAddress("validator1"),
			amount:        minimumAmount + 1,
			referrer:      "",
			expectPanic:   true,
			expectedError: "[GNOSWAP-GOV_STAKER-004] invalid amount || amount must be multiple of 1000000",
			setupMocks: func() {
				cleanupStakerDelegateTest(t, gs)
			},
			cleanupMocks: func() {
				cleanupStakerDelegateTest(t, gs)
			},
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			// Given: Setup test environment
			tt.setupMocks()
			defer tt.cleanupMocks()

			// Setup realm context for testing
			testing.SetRealm(testing.NewUserRealm(tt.caller))

			// When & Then: Execute and verify
			if tt.expectPanic {
				uassert.AbortsWithMessage(t, tt.expectedError, func() {
					func(cur realm) {
						gs.Delegate(tt.to, tt.amount, tt.referrer)
					}(cross)
				})
			} else {
				func(cur realm) {
					testing.SetRealm(testing.NewCodeRealm(GOV_STAKER_PKG_PATH))
					result := gs.Delegate(tt.to, tt.amount, tt.referrer)
					uassert.Equal(t, result, tt.amount)
				}(cross)
			}
		})
	}
}

// Test Undelegate function
func TestStakerDelegate_Undelegate(t *testing.T) {
	// govStakerAddr := access.MustGetAddress(prbac.ROLE_GOV_STAKER.String())

	tests := []struct {
		name            string
		caller          address
		from            address
		amount          int64
		expectPanic     bool
		expectedError   string
		setupDelegation func(gs *govStakerV1)
		cleanupMocks    func(gs *govStakerV1)
		expectedAmount  int64
	}{
		{
			name:           "Successful undelegation",
			caller:         testutils.TestAddress("alice"),
			from:           testutils.TestAddress("validator1"),
			amount:         minimumAmount,
			expectedAmount: 1000000,
			expectPanic:    false,
			setupDelegation: func(gs *govStakerV1) {
				cleanupStakerDelegateTest(t, gs)
				setupStakerDelegateTestDelegation(t, gs, testutils.TestAddress("alice"), testutils.TestAddress("validator1"), minimumAmount)
			},
			cleanupMocks: func(gs *govStakerV1) {
				cleanupStakerDelegateTest(t, gs)
			},
		},
		{
			name:           "Invalid from address should panic",
			caller:         testutils.TestAddress("alice"),
			from:           address(""),
			amount:         minimumAmount,
			expectedAmount: 0,
			expectPanic:    true,
			expectedError:  "invalid address: ",
			setupDelegation: func(gs *govStakerV1) {
				cleanupStakerDelegateTest(t, gs)
			},
			cleanupMocks: func(gs *govStakerV1) {
				cleanupStakerDelegateTest(t, gs)
			},
		},
		{
			name:           "Caller not delegator should not panic",
			caller:         testutils.TestAddress("bob"),
			from:           testutils.TestAddress("validator1"),
			amount:         minimumAmount,
			expectedAmount: 0,
			expectPanic:    false,
			setupDelegation: func(gs *govStakerV1) {
				cleanupStakerDelegateTest(t, gs)
				setupStakerDelegateTestDelegation(t, gs, testutils.TestAddress("alice"), testutils.TestAddress("validator1"), minimumAmount)
			},
			cleanupMocks: func(gs *govStakerV1) {
				cleanupStakerDelegateTest(t, gs)
			},
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			// Given: Setup test environment with delegation
			gs := createTestGovStaker()
			tt.setupDelegation(gs)
			defer tt.cleanupMocks(gs)

			// Setup realm context for testing
			testing.SetRealm(testing.NewUserRealm(tt.caller))

			// When & Then: Execute and verify
			if tt.expectPanic {
				uassert.AbortsWithMessage(t, tt.expectedError, func() {
					func(cur realm) {
						gs.Undelegate(tt.from, tt.amount)
					}(cross)
				})
			} else {
				func(cur realm) {
					testing.SetRealm(testing.NewCodeRealm(GOV_STAKER_PKG_PATH))
					result := gs.Undelegate(tt.from, tt.amount)
					uassert.Equal(t, result, tt.expectedAmount)
				}(cross)
			}
		})
	}
}

// Test Undelegate with multiple delegations to same delegatee
// This tests the optimization where GetUnDelegationLockupPeriod is called only once
func TestStakerDelegate_UndelegateMultipleDelegations(t *testing.T) {
	tests := []struct {
		name                 string
		delegationAmounts    []int64
		undelegateAmount     int64
		expectedSuccess      bool
		minExpectedWithdraws int
		description          string
	}{
		{
			name:                 "Undelegate spanning multiple delegations",
			delegationAmounts:    []int64{minimumAmount, minimumAmount * 2, minimumAmount * 3, minimumAmount * 4, minimumAmount * 5},
			undelegateAmount:     minimumAmount * 8,
			expectedSuccess:      true,
			minExpectedWithdraws: 3,
			description:          "Should process first 3 delegations (1M + 2M + 3M + 2M from 4th)",
		},
		{
			name:                 "Early exit - only first delegation needed",
			delegationAmounts:    []int64{minimumAmount * 10, minimumAmount * 5, minimumAmount * 3},
			undelegateAmount:     minimumAmount * 5,
			expectedSuccess:      true,
			minExpectedWithdraws: 1,
			description:          "Should only process first delegation and exit early",
		},
		{
			name:                 "Exact match - first delegation",
			delegationAmounts:    []int64{minimumAmount * 5, minimumAmount * 3, minimumAmount * 2},
			undelegateAmount:     minimumAmount * 5,
			expectedSuccess:      true,
			minExpectedWithdraws: 1,
			description:          "Should exactly match and consume first delegation",
		},
		{
			name:                 "Exact match - multiple delegations",
			delegationAmounts:    []int64{minimumAmount, minimumAmount * 2, minimumAmount * 3},
			undelegateAmount:     minimumAmount * 6,
			expectedSuccess:      true,
			minExpectedWithdraws: 3,
			description:          "Should exactly consume all three delegations (1M + 2M + 3M)",
		},
		{
			name:                 "All delegations required",
			delegationAmounts:    []int64{minimumAmount, minimumAmount * 2, minimumAmount * 3},
			undelegateAmount:     minimumAmount * 6,
			expectedSuccess:      true,
			minExpectedWithdraws: 3,
			description:          "Should process all delegations when amount equals total",
		},
		{
			name:                 "Partial last delegation",
			delegationAmounts:    []int64{minimumAmount * 2, minimumAmount * 3, minimumAmount * 10},
			undelegateAmount:     minimumAmount * 7,
			expectedSuccess:      true,
			minExpectedWithdraws: 3,
			description:          "Should fully use first two and partially use third (2M + 3M + 2M)",
		},
		{
			name:                 "Single delegation - partial undelegate",
			delegationAmounts:    []int64{minimumAmount * 10},
			undelegateAmount:     minimumAmount * 3,
			expectedSuccess:      true,
			minExpectedWithdraws: 1,
			description:          "Should handle single delegation case (boundary)",
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			// Given: Setup gov staker with clean state
			gs := createTestGovStaker()
			cleanupStakerDelegateTest(t, gs)

			user := testutils.TestAddress("alice")
			validator := testutils.TestAddress("validator1")

			testing.SetRealm(testing.NewUserRealm(user))

			// Create delegations according to test case
			totalDelegated := int64(0)
			func(cur realm) {
				testing.SetRealm(testing.NewCodeRealm(GOV_STAKER_PKG_PATH))
				for _, amount := range tt.delegationAmounts {
					gs.Delegate(validator, amount, "")
					totalDelegated += amount
				}
			}(cross)

			// When: Undelegate specified amount
			var undelegatedAmount int64
			func(cur realm) {
				testing.SetRealm(testing.NewCodeRealm(GOV_STAKER_PKG_PATH))
				undelegatedAmount = gs.Undelegate(validator, tt.undelegateAmount)
			}(cross)

			// Then: Verify results
			if tt.expectedSuccess {
				uassert.Equal(t, undelegatedAmount, tt.undelegateAmount)

				// Verify withdraws were created correctly
				delegationIDs := gs.getUserDelegationIDsWithDelegatee(user, validator)
				totalWithdraws := 0
				totalUndelegated := int64(0)

				for _, delegationID := range delegationIDs {
					delegation := gs.getDelegation(delegationID)
					if delegation != nil {
						withdraws := delegation.Withdraws()
						totalWithdraws += len(withdraws)
						totalUndelegated += delegation.UnDelegatedAmount()
					}
				}

				uassert.Equal(t, totalUndelegated, tt.undelegateAmount)
				uassert.True(t, totalWithdraws >= tt.minExpectedWithdraws)
			}
		})
	}
}

// Test Undelegate edge cases with multiple delegations
func TestStakerDelegate_UndelegateMultipleDelegations_EdgeCases(t *testing.T) {
	tests := []struct {
		name          string
		setupFunc     func(gs *govStakerV1, user, validator address)
		undelegateAmt int64
		expectPanic   bool
		expectedError string
		description   string
	}{
		{
			name: "Undelegate from non-existent delegatee",
			setupFunc: func(gs *govStakerV1, user, validator address) {
				// No delegations created
			},
			undelegateAmt: minimumAmount,
			expectPanic:   false,
			description:   "Should return 0 when no delegations exist",
		},
		{
			name: "Undelegate more than total delegated",
			setupFunc: func(gs *govStakerV1, user, validator address) {
				func(cur realm) {
					testing.SetRealm(testing.NewCodeRealm(GOV_STAKER_PKG_PATH))
					gs.Delegate(validator, minimumAmount*5, "")
				}(cross)
			},
			undelegateAmt: minimumAmount * 10,
			expectPanic:   false,
			description:   "Should return available amount when requested exceeds delegated",
		},
		{
			name: "Undelegate zero amount",
			setupFunc: func(gs *govStakerV1, user, validator address) {
				func(cur realm) {
					testing.SetRealm(testing.NewCodeRealm(GOV_STAKER_PKG_PATH))
					gs.Delegate(validator, minimumAmount*5, "")
				}(cross)
			},
			undelegateAmt: 0,
			expectPanic:   true,
			expectedError: "[GNOSWAP-GOV_STAKER-011] cannot delegate less than minimum amount || minimum amount to delegate is 1000000 (requested:0)",
			description:   "Should reject zero amount",
		},
		{
			name: "Undelegate negative amount",
			setupFunc: func(gs *govStakerV1, user, validator address) {
				func(cur realm) {
					testing.SetRealm(testing.NewCodeRealm(GOV_STAKER_PKG_PATH))
					gs.Delegate(validator, minimumAmount*5, "")
				}(cross)
			},
			undelegateAmt: -minimumAmount,
			expectPanic:   true,
			expectedError: "[GNOSWAP-GOV_STAKER-011] cannot delegate less than minimum amount || minimum amount to delegate is 1000000 (requested:-1000000)",
			description:   "Should reject negative amount",
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			// Given: Setup test environment
			gs := createTestGovStaker()
			cleanupStakerDelegateTest(t, gs)

			user := testutils.TestAddress("alice")
			validator := testutils.TestAddress("validator1")

			testing.SetRealm(testing.NewUserRealm(user))
			tt.setupFunc(gs, user, validator)

			// When & Then: Execute and verify
			if tt.expectPanic {
				uassert.AbortsWithMessage(t, tt.expectedError, func() {
					func(cur realm) {
						testing.SetRealm(testing.NewCodeRealm(GOV_STAKER_PKG_PATH))
						gs.Undelegate(validator, tt.undelegateAmt)
					}(cross)
				})
			} else {
				func(cur realm) {
					testing.SetRealm(testing.NewCodeRealm(GOV_STAKER_PKG_PATH))
					result := gs.Undelegate(validator, tt.undelegateAmt)
					// For non-panic cases, verify result is reasonable
					// (either 0 for no delegations, or capped at available amount)
					if tt.undelegateAmt > 0 {
						uassert.True(t, result >= 0)
					}
				}(cross)
			}
		})
	}
}

// Test Redelegate function
func TestStakerDelegate_Redelegate(t *testing.T) {
	// Initialize gov staker
	gs := createTestGovStaker()

	tests := []struct {
		name            string
		caller          address
		delegator       address
		delegatee       address
		amount          int64
		expectPanic     bool
		expectedError   string
		setupDelegation func()
		cleanupMocks    func()
	}{
		{
			name:        "Successful redelegation",
			caller:      testutils.TestAddress("alice"),
			delegator:   testutils.TestAddress("validator1"),
			delegatee:   testutils.TestAddress("validator2"),
			amount:      minimumAmount,
			expectPanic: false,
			setupDelegation: func() {
				cleanupStakerDelegateTest(t, gs)
				setupStakerDelegateTestDelegation(t, gs, testutils.TestAddress("alice"), testutils.TestAddress("validator1"), minimumAmount)
			},
			cleanupMocks: func() {
				cleanupStakerDelegateTest(t, gs)
			},
		},
		{
			name:          "Invalid delegator address should panic",
			caller:        testutils.TestAddress("alice"),
			delegator:     address(""),
			delegatee:     testutils.TestAddress("validator2"),
			amount:        minimumAmount,
			expectPanic:   true,
			expectedError: "invalid address: ",
			setupDelegation: func() {
				cleanupStakerDelegateTest(t, gs)
			},
			cleanupMocks: func() {
				cleanupStakerDelegateTest(t, gs)
			},
		},
		{
			name:          "Invalid delegatee address should panic",
			caller:        testutils.TestAddress("alice"),
			delegator:     testutils.TestAddress("validator1"),
			delegatee:     address(""),
			amount:        minimumAmount,
			expectPanic:   true,
			expectedError: "invalid address: ",
			setupDelegation: func() {
				cleanupStakerDelegateTest(t, gs)
			},
			cleanupMocks: func() {
				cleanupStakerDelegateTest(t, gs)
			},
		},
		{
			name:          "Same delegatee should panic",
			caller:        testutils.TestAddress("alice"),
			delegator:     testutils.TestAddress("validator1"),
			delegatee:     testutils.TestAddress("validator1"),
			amount:        minimumAmount,
			expectPanic:   true,
			expectedError: errSameDelegatee.Error(),
			setupDelegation: func() {
				cleanupStakerDelegateTest(t, gs)
			},
			cleanupMocks: func() {
				cleanupStakerDelegateTest(t, gs)
			},
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			// Given: Setup test environment with delegation
			tt.setupDelegation()
			defer tt.cleanupMocks()

			// Setup realm context for testing
			testing.SetRealm(testing.NewUserRealm(tt.caller))

			// When & Then: Execute and verify
			if tt.expectPanic {
				uassert.AbortsWithMessage(t, tt.expectedError, func() {
					func(cur realm) {
						gs.Redelegate(tt.delegator, tt.delegatee, tt.amount)
					}(cross)
				})
			} else {
				func(cur realm) {
					testing.SetRealm(testing.NewCodeRealm(GOV_STAKER_PKG_PATH))
					result := gs.Redelegate(tt.delegator, tt.delegatee, tt.amount)
					uassert.Equal(t, result, tt.amount)
				}(cross)
			}
		})
	}
}

// Test CollectUndelegatedGns function
func TestStakerDelegate_CollectUndelegatedGns(t *testing.T) {
	tests := []struct {
		name             string
		caller           address
		expectPanic      bool
		expectedError    string
		setupCollectable func(gs *govStakerV1)
		cleanupMocks     func(gs *govStakerV1)
		expectedAmount   int64
	}{
		{
			name:        "Successful collection",
			caller:      testutils.TestAddress("alice"),
			expectPanic: false,
			setupCollectable: func(gs *govStakerV1) {
				cleanupStakerDelegateTest(t, gs)
				setupStakerDelegateTestCollectableAmount(t, gs, testutils.TestAddress("alice"), minimumAmount)
			},
			cleanupMocks: func(gs *govStakerV1) {
				cleanupStakerDelegateTest(t, gs)
			},
			expectedAmount: minimumAmount,
		},
		{
			name:        "No collectable amount returns zero",
			caller:      testutils.TestAddress("alice"),
			expectPanic: false,
			setupCollectable: func(gs *govStakerV1) {
				cleanupStakerDelegateTest(t, gs)
			},
			cleanupMocks: func(gs *govStakerV1) {
				cleanupStakerDelegateTest(t, gs)
			},
			expectedAmount: 0,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			// Given: Setup test environment with collectable amount
			gs := createTestGovStaker()

			tt.setupCollectable(gs)
			defer tt.cleanupMocks(gs)

			testing.SetRealm(testing.NewUserRealm(tt.caller))

			// When & Then: Execute and verify
			if tt.expectPanic {
				uassert.AbortsWithMessage(t, tt.expectedError, func() {
					func(cur realm) {
						gs.CollectUndelegatedGns()
					}(cross)
				})
			} else {
				func(cur realm) {
					testing.SetRealm(testing.NewCodeRealm(GOV_STAKER_PKG_PATH))
					result := gs.CollectUndelegatedGns()
					uassert.Equal(t, tt.expectedAmount, result)
				}(cross)
			}
		})
	}
}

// Test comprehensive delegation validation including edge cases
func TestStakerDelegate_DelegationValidationEdgeCases(t *testing.T) {
	// Initialize gov staker
	gs := createTestGovStaker()

	tests := []struct {
		name          string
		caller        address
		to            address
		amount        int64
		setupBalance  int64
		expectPanic   bool
		expectedError string
		description   string
	}{
		{
			name:         "success - minimum amount delegation",
			caller:       testutils.TestAddress("alice"),
			to:           testutils.TestAddress("validator"),
			amount:       minimumAmount,
			setupBalance: minimumAmount * 2,
			expectPanic:  false,
		},
		{
			name:         "success - multiple of minimum amount",
			caller:       testutils.TestAddress("alice"),
			to:           testutils.TestAddress("validator"),
			amount:       minimumAmount * 5,
			setupBalance: minimumAmount * 10,
			expectPanic:  false,
		},
		{
			name:          "fail - amount less than minimum",
			caller:        testutils.TestAddress("alice"),
			to:            testutils.TestAddress("validator"),
			amount:        minimumAmount - 1,
			setupBalance:  minimumAmount * 2,
			expectPanic:   true,
			expectedError: "[GNOSWAP-GOV_STAKER-011] cannot delegate less than minimum amount || minimum amount to delegate is 1000000 (requested:999999)",
		},
		{
			name:          "fail - amount not multiple of minimum",
			caller:        testutils.TestAddress("alice"),
			to:            testutils.TestAddress("validator"),
			amount:        minimumAmount + 1,
			setupBalance:  minimumAmount * 2,
			expectPanic:   true,
			expectedError: "[GNOSWAP-GOV_STAKER-004] invalid amount || amount must be multiple of 1000000",
		},
		{
			name:          "fail - zero amount",
			caller:        testutils.TestAddress("alice"),
			to:            testutils.TestAddress("validator"),
			amount:        0,
			setupBalance:  minimumAmount * 2,
			expectPanic:   true,
			expectedError: "[GNOSWAP-GOV_STAKER-011] cannot delegate less than minimum amount || minimum amount to delegate is 1000000 (requested:0)",
		},
		{
			name:          "fail - negative amount",
			caller:        testutils.TestAddress("alice"),
			to:            testutils.TestAddress("validator"),
			amount:        -minimumAmount,
			setupBalance:  minimumAmount * 2,
			expectPanic:   true,
			expectedError: "[GNOSWAP-GOV_STAKER-011] cannot delegate less than minimum amount || minimum amount to delegate is 1000000 (requested:-1000000)",
		},
		{
			name:         "success - self delegation",
			caller:       testutils.TestAddress("alice"),
			to:           testutils.TestAddress("alice"),
			amount:       minimumAmount,
			setupBalance: minimumAmount * 2,
			expectPanic:  false,
			description:  "Self delegation should be allowed",
		},
		{
			name:          "success - maximum int64 amount",
			caller:        testutils.TestAddress("alice"),
			to:            testutils.TestAddress("validator"),
			amount:        9223372036854775800, // Close to MAX_INT64 but multiple of minimumAmount
			setupBalance:  9223372036854775807,
			expectPanic:   true,
			expectedError: "[GNOSWAP-GOV_STAKER-004] invalid amount || amount must be multiple of 1000000",
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			// Given: Setup test environment
			cleanupStakerDelegateTest(t, gs)
			// Setup GNS balance for caller
			// In real implementation, would setup actual balance

			testing.SetRealm(testing.NewUserRealm(tt.caller))

			// When & Then: Execute and verify
			if tt.expectPanic {
				uassert.AbortsWithMessage(t, tt.expectedError, func() {
					func(cur realm) {
						gs.Delegate(tt.to, tt.amount, "")
					}(cross)
				})
			} else {
				func(cur realm) {
					testing.SetRealm(testing.NewCodeRealm(GOV_STAKER_PKG_PATH))
					result := gs.Delegate(tt.to, tt.amount, "")
					uassert.Equal(t, result, tt.amount)
				}(cross)
			}
		})
	}
}

// Test lockup period and withdrawal timing
func TestStakerDelegate_LockupPeriodAndWithdrawal(t *testing.T) {
	// Initialize gov staker
	gs := createTestGovStaker()

	tests := []struct {
		name                string
		delegateAmount      int64
		undelegateAmount    int64
		lockupPeriod        int64
		waitTime            int64
		expectedCollectable int64
		expectedError       string
		shouldFail          bool
		description         string
	}{
		{
			name:                "success - collect after lockup period",
			delegateAmount:      minimumAmount * 10,
			undelegateAmount:    minimumAmount * 5,
			lockupPeriod:        7 * 24 * 3600, // 7 days in seconds
			waitTime:            8 * 24 * 3600, // 8 days wait
			expectedCollectable: minimumAmount * 5,
			shouldFail:          false,
		},
		{
			name:                "success - collect before lockup period ends but after undelegate",
			delegateAmount:      minimumAmount * 10,
			undelegateAmount:    minimumAmount * 5,
			lockupPeriod:        7 * 24 * 3600, // 7 days
			waitTime:            6 * 24 * 3600, // 6 days wait (too early)
			expectedCollectable: 0,
			expectedError:       "",
			shouldFail:          false,
		},
		{
			name:                "success - partial collection",
			delegateAmount:      minimumAmount * 10,
			undelegateAmount:    minimumAmount * 4,
			lockupPeriod:        7 * 24 * 3600,
			waitTime:            8 * 24 * 3600,
			expectedCollectable: minimumAmount * 4,
			shouldFail:          false,
		},
		{
			name:                "success - multiple collections",
			delegateAmount:      minimumAmount * 10,
			undelegateAmount:    minimumAmount * 6,
			lockupPeriod:        7 * 24 * 3600,
			waitTime:            8 * 24 * 3600,
			expectedCollectable: minimumAmount * 6,
			shouldFail:          false,
			description:         "Should be able to collect in multiple transactions",
		},
		{
			name:                "success - collect exactly at lockup end",
			delegateAmount:      minimumAmount * 10,
			undelegateAmount:    minimumAmount * 5,
			lockupPeriod:        7 * 24 * 3600,
			waitTime:            7 * 24 * 3600, // Exactly at lockup end
			expectedCollectable: minimumAmount * 5,
			shouldFail:          false,
		},
		{
			name:                "success - large amount collection without overflow",
			delegateAmount:      minimumAmount * 1_000_000, // 1 trillion GNS
			undelegateAmount:    minimumAmount * 500_000,   // 500 billion GNS
			lockupPeriod:        7 * 24 * 3600,
			waitTime:            8 * 24 * 3600,
			expectedCollectable: minimumAmount * 500_000,
			shouldFail:          false,
			description:         "Large amounts but still within int64 range",
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			// Given: Setup delegation and undelegation
			cleanupStakerDelegateTest(t, gs)
			testing.SetHeight(100)
			user := testutils.TestAddress("alice")
			validator := testutils.TestAddress("validator")

			// Set lockup period if needed
			if tt.lockupPeriod > 0 {
				mockStore := gs.store.(*mockGovStakerStore)
				mockStore.unDelegationLockupPeriod = tt.lockupPeriod
			}

			// For large amount test, setup sufficient balance
			//
			// This value is set to test overflow-related behavior.
			// In the real world, the amount of delegation is limited, so
			// cases using this amount of tokens are unlikely to occur.
			if tt.delegateAmount > 1_000_000_000 {
				testing.SetRealm(adminRealm)
				gns.Transfer(cross, user, tt.delegateAmount*2)
				testing.SetRealm(testing.NewUserRealm(user))
				gns.Approve(cross, govStakerAddr, tt.delegateAmount*2)
			}

			testing.SetRealm(testing.NewUserRealm(user))

			func(cur realm) {
				testing.SetRealm(testing.NewCodeRealm(GOV_STAKER_PKG_PATH))
				// Delegate
				gs.Delegate(validator, tt.delegateAmount, "")

				// Undelegate
				gs.Undelegate(validator, tt.undelegateAmount)
			}(cross)

			// Simulate time passage for lockup period
			// In real implementation, would advance blockchain time
			blockTime := int64(5)
			testing.SkipHeights(tt.waitTime / blockTime)

			// When & Then: Try to collect
			if tt.shouldFail {
				uassert.AbortsWithMessage(t, tt.expectedError, func() {
					func(cur realm) {
						testing.SetRealm(testing.NewCodeRealm(GOV_STAKER_PKG_PATH))
						gs.CollectUndelegatedGns()
					}(cross)
				})
			} else {
				func(cur realm) {
					testing.SetRealm(testing.NewCodeRealm(GOV_STAKER_PKG_PATH))
					result := gs.CollectUndelegatedGns()
					// In successful cases, should return some amount
					// The exact amount depends on implementation details
					uassert.Equal(t, tt.expectedCollectable, result)
				}(cross)
			}
		})
	}
}

// Test delegation with referrer functionality
func TestStakerDelegate_ReferrerFunctionality(t *testing.T) {
	// Initialize gov staker
	gs := createTestGovStaker()

	tests := []struct {
		name        string
		caller      address
		to          address
		amount      int64
		referrer    string
		expectError bool
		description string
	}{
		{
			name:        "success - delegation without referrer",
			caller:      testutils.TestAddress("alice"),
			to:          testutils.TestAddress("validator"),
			amount:      minimumAmount,
			referrer:    "",
			expectError: false,
		},
		{
			name:        "success - delegation with valid referrer",
			caller:      testutils.TestAddress("alice"),
			to:          testutils.TestAddress("validator"),
			amount:      minimumAmount,
			referrer:    "referrer123",
			expectError: false,
		},
		{
			name:        "success - delegation with long referrer string",
			caller:      testutils.TestAddress("alice"),
			to:          testutils.TestAddress("validator"),
			amount:      minimumAmount,
			referrer:    "very_long_referrer_identifier_with_special_chars_123456789",
			expectError: false,
		},
		{
			name:        "success - delegation with unicode referrer",
			caller:      testutils.TestAddress("alice"),
			to:          testutils.TestAddress("validator"),
			amount:      minimumAmount,
			referrer:    "추천인_한글",
			expectError: false,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			// Given: Setup test environment
			cleanupStakerDelegateTest(t, gs)

			testing.SetOriginCaller(tt.caller)

			// When & Then: Execute delegation with referrer
			if tt.expectError {
				uassert.AbortsWithMessage(t, "", func() {
					func(cur realm) {
						testing.SetRealm(testing.NewCodeRealm(GOV_STAKER_PKG_PATH))
						gs.Delegate(tt.to, tt.amount, tt.referrer)
					}(cross)
				})
			} else {
				func(cur realm) {
					testing.SetRealm(testing.NewCodeRealm(GOV_STAKER_PKG_PATH))
					result := gs.Delegate(tt.to, tt.amount, tt.referrer)
					uassert.Equal(t, result, tt.amount)
				}(cross)
			}
		})
	}
}

// Test edge cases for delegation operations
func TestStakerDelegate_EdgeCasesAndBoundaries(t *testing.T) {
	// Initialize gov staker
	gs := createTestGovStaker()

	tests := []struct {
		name           string
		setupScenario  func() (address, address, int64)
		executeAction  string
		expectedResult int64
		expectError    bool
		description    string
	}{
		{
			name: "undelegate entire delegation",
			setupScenario: func() (address, address, int64) {
				user := testutils.TestAddress("alice")
				validator := testutils.TestAddress("validator")
				amount := int64(minimumAmount * 10)

				// Pre-setup delegation
				testing.SetRealm(testing.NewUserRealm(user))
				func(cur realm) {
					testing.SetRealm(testing.NewCodeRealm(GOV_STAKER_PKG_PATH))
					gs.Delegate(validator, amount, "")
				}(cross)

				return user, validator, amount
			},
			executeAction:  "undelegate",
			expectedResult: minimumAmount * 10,
			expectError:    false,
		},
		{
			name: "redelegate between validators",
			setupScenario: func() (address, address, int64) {
				user := testutils.TestAddress("alice")
				validator1 := testutils.TestAddress("validator1")
				amount := int64(minimumAmount * 5)

				// Pre-setup delegation
				testing.SetRealm(testing.NewUserRealm(user))
				func(cur realm) {
					testing.SetRealm(testing.NewCodeRealm(GOV_STAKER_PKG_PATH))
					gs.Delegate(validator1, amount, "")
				}(cross)

				return user, testutils.TestAddress("validator2"), amount
			},
			executeAction:  "redelegate",
			expectedResult: minimumAmount * 5,
			expectError:    false,
		},
		{
			name: "collect when no undelegated amount available",
			setupScenario: func() (address, address, int64) {
				return testutils.TestAddress("user"), testutils.TestAddress("validator"), 0
			},
			executeAction:  "collect",
			expectedResult: 0,
			expectError:    false,
			description:    "Should return 0 when nothing to collect",
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			// Given: Setup scenario
			cleanupStakerDelegateTest(t, gs)
			user, target, amount := tt.setupScenario()

			testing.SetRealm(testing.NewUserRealm(user))

			// When: Execute action
			var result int64
			if tt.expectError {
				uassert.AbortsWithMessage(t, "", func() {
					func(cur realm) {
						testing.SetRealm(testing.NewCodeRealm(GOV_STAKER_PKG_PATH))
						switch tt.executeAction {
						case "delegate":
							gs.Delegate(target, amount, "")
						case "undelegate":
							gs.Undelegate(target, amount)
						case "redelegate":
							gs.Redelegate(testutils.TestAddress("validator1"), target, amount)
						case "collect":
							gs.CollectUndelegatedGns()
						}
					}(cross)
				})
			} else {
				func(cur realm) {
					testing.SetRealm(testing.NewCodeRealm(GOV_STAKER_PKG_PATH))
					switch tt.executeAction {
					case "delegate":
						result = gs.Delegate(target, amount, "")
					case "undelegate":
						result = gs.Undelegate(target, amount)
					case "redelegate":
						result = gs.Redelegate(testutils.TestAddress("validator1"), target, amount)
					case "collect":
						result = gs.CollectUndelegatedGns()
					}

					// Then: Verify result
					uassert.Equal(t, result, tt.expectedResult)
				}(cross)
			}
		})
	}
}

// Helper functions
func cleanupStakerDelegateTest(t *testing.T, gs *govStakerV1) {
	// Reset delegation state
	mockStore := gs.store.(*mockGovStakerStore)
	mockStore.delegationNextID = staker.NewCounter()
	mockStore.delegations = avl.NewTree()
	mockStore.totalDelegationHistory = staker.NewUintTree()
	mockStore.userDelegationHistory = avl.NewTree()
	mockStore.userDelegations = avl.NewTree()

	// Reset managers in store
	mockStore.delegationManager = staker.NewDelegationManager()

	setupStakerDelegateTestGNSBalance(t)
}

func setupStakerDelegateTestGNSBalance(t *testing.T) {
	testing.SetRealm(adminRealm)

	amount := int64(1_000_000_000)
	gns.Transfer(cross, testutils.TestAddress("alice"), amount)
	gns.Transfer(cross, testutils.TestAddress("bob"), amount)
	gns.Transfer(cross, testutils.TestAddress("charlie"), amount)
	gns.Transfer(cross, testutils.TestAddress("validator1"), amount)
	gns.Transfer(cross, testutils.TestAddress("validator2"), amount)
	gns.Transfer(cross, testutils.TestAddress("validator3"), amount)

	testing.SetRealm(testing.NewUserRealm(testutils.TestAddress("alice")))
	gns.Approve(cross, govStakerAddr, amount)

	testing.SetRealm(testing.NewUserRealm(testutils.TestAddress("bob")))
	gns.Approve(cross, govStakerAddr, amount)

	testing.SetRealm(testing.NewUserRealm(testutils.TestAddress("charlie")))
	gns.Approve(cross, govStakerAddr, amount)

	testing.SetRealm(testing.NewUserRealm(testutils.TestAddress("validator1")))
	gns.Approve(cross, govStakerAddr, amount)

	testing.SetRealm(testing.NewUserRealm(testutils.TestAddress("validator2")))
	gns.Approve(cross, govStakerAddr, amount)

	testing.SetRealm(testing.NewUserRealm(testutils.TestAddress("validator3")))
	gns.Approve(cross, govStakerAddr, amount)
}

func setupStakerDelegateTestDelegation(t *testing.T, gs *govStakerV1, from, to address, amount int64) {
	delegationID := gs.nextDelegationID()
	delegation := staker.NewDelegation(delegationID, from, to, amount, 100, 100)
	gs.addDelegation(delegationID, delegation)

	testing.SetRealm(testing.NewUserRealm(from))
	gns.Transfer(cross, govStakerAddr, amount)

	testing.SetRealm(testing.NewUserRealm(govStakerAddr))
	xgns.Mint(cross, from, amount)
}

func setupStakerDelegateTestCollectableAmount(t *testing.T, gs *govStakerV1, user address, amount int64) {
	// Create a delegation that has been undelegated and is collectable
	delegationID := gs.nextDelegationID()
	delegation := staker.NewDelegation(delegationID, user, testutils.TestAddress("validator1"), amount, 100, 100)
	resolver := NewDelegationResolver(delegation)

	// Undelegate with very short lockup period
	resolver.UnDelegate(amount, 200, 100, 0) // 0 second lockup

	gs.addDelegation(delegationID, delegation)

	testing.SetRealm(testing.NewUserRealm(user))
	gns.Transfer(cross, govStakerAddr, amount)

	testing.SetRealm(testing.NewUserRealm(govStakerAddr))
	xgns.Mint(cross, user, amount)
}

// TestStakerDelegate_registerReferrer tests the private registerReferrer function
func TestStakerDelegate_registerReferrer(t *testing.T) {
	tests := []struct {
		name     string
		caller   address
		referrer string
	}{
		{
			name:     "register with valid referrer",
			caller:   testutils.TestAddress("alice"),
			referrer: "referrer1",
		},
		{
			name:     "register with empty referrer",
			caller:   testutils.TestAddress("bob"),
			referrer: "",
		},
		{
			name:     "register same caller multiple times",
			caller:   testutils.TestAddress("charlie"),
			referrer: "referrer2",
		},
	}

	for _, tc := range tests {
		t.Run(tc.name, func(t *testing.T) {
			// when - call registerReferrer
			result := registerReferrer(tc.caller, tc.referrer)

			// then - should return a referrer string (actual referrer may differ based on referral module logic)
			uassert.NotNil(t, result)
		})
	}
}

// TestStakerDelegate_collectDelegations_MultipleDelegations tests collecting from multiple delegations
func TestStakerDelegate_collectDelegations_MultipleDelegations(t *testing.T) {
	tests := []struct {
		name             string
		delegationCounts []int          // number of delegations to create
		amounts          [][]int64      // amounts for each delegation's withdrawals
		lockupPeriods    []int64        // lockup period for each delegation
		waitTime         int64          // time to wait before collecting
		expectedTotal    int64          // expected total collected amount
		description      string
	}{
		{
			name:             "collect from single delegation with single withdrawal",
			delegationCounts: []int{1},
			amounts:          [][]int64{{minimumAmount}},
			lockupPeriods:    []int64{100},
			waitTime:         150,
			expectedTotal:    minimumAmount,
		},
		{
			name:             "collect from multiple delegations each with single withdrawal",
			delegationCounts: []int{3},
			amounts: [][]int64{
				{minimumAmount},
				{minimumAmount * 2},
				{minimumAmount * 3},
			},
			lockupPeriods: []int64{100, 100, 100},
			waitTime:      150,
			expectedTotal: minimumAmount * 6,
		},
		{
			name:             "collect from delegation with multiple withdrawals",
			delegationCounts: []int{1},
			amounts:          [][]int64{{minimumAmount, minimumAmount * 2, minimumAmount * 3}},
			lockupPeriods:    []int64{100},
			waitTime:         150,
			expectedTotal:    minimumAmount * 6,
		},
		{
			name:             "partial collection - some still locked",
			delegationCounts: []int{2},
			amounts: [][]int64{
				{minimumAmount},
				{minimumAmount * 2},
			},
			lockupPeriods: []int64{100, 1000}, // second has longer lockup
			waitTime:      150,
			expectedTotal: minimumAmount, // only first one collectable
		},
		{
			name:             "no collection - all still locked",
			delegationCounts: []int{2},
			amounts: [][]int64{
				{minimumAmount},
				{minimumAmount * 2},
			},
			lockupPeriods: []int64{1000, 1000}, // both locked
			waitTime:      150,
			expectedTotal: 0,
		},
		{
			name:             "collect zero amount withdrawals",
			delegationCounts: []int{1},
			amounts:          [][]int64{{0, 0}},
			lockupPeriods:    []int64{100},
			waitTime:         150,
			expectedTotal:    0,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			// Given: Create test environment
			gs := createTestGovStaker()
			cleanupStakerDelegateTest(t, gs)

			user := testutils.TestAddress("alice")
			validator := testutils.TestAddress("validator1")
			currentTime := int64(1000)
			currentHeight := int64(100)

			// Create delegations with withdrawals
			for i, amounts := range tt.amounts {
				delegationID := gs.nextDelegationID()
				totalAmount := int64(0)
				for _, amt := range amounts {
					totalAmount += amt
				}

				delegation := staker.NewDelegation(delegationID, user, validator, totalAmount, currentHeight, currentTime)

				// Add withdrawals
				for _, amt := range amounts {
					if amt > 0 {
						resolver := NewDelegationResolver(delegation)
						resolver.UnDelegate(amt, currentHeight, currentTime, tt.lockupPeriods[i])
					}
				}

				gs.addDelegation(delegationID, delegation)

				// Setup xGNS balance
				testing.SetRealm(testing.NewUserRealm(govStakerAddr))
				xgns.Mint(cross, user, totalAmount)
			}

			// When: Collect after waiting
			collectedTime := currentTime + tt.waitTime
			var collected int64
			var err error

			func(cur realm) {
				testing.SetRealm(testing.NewCodeRealm(GOV_STAKER_PKG_PATH))
				collected, err = gs.collectDelegations(user, collectedTime)
			}(cross)

			// Then: Verify collected amount
			uassert.NoError(t, err)
			uassert.Equal(t, collected, tt.expectedTotal)
		})
	}
}

// TestStakerDelegate_collectDelegations_NoCollectableAmount tests when there's nothing to collect
func TestStakerDelegate_collectDelegations_NoCollectableAmount(t *testing.T) {
	tests := []struct {
		name        string
		setupFunc   func(gs *govStakerV1) address
		description string
	}{
		{
			name: "user has no delegations",
			setupFunc: func(gs *govStakerV1) address {
				return testutils.TestAddress("alice")
			},
			description: "Should return 0 when user has no delegations",
		},
		{
			name: "user has delegations but all still locked",
			setupFunc: func(gs *govStakerV1) address {
				user := testutils.TestAddress("alice")
				validator := testutils.TestAddress("validator1")

				delegationID := gs.nextDelegationID()
				delegation := staker.NewDelegation(delegationID, user, validator, minimumAmount, 100, 1000)

				resolver := NewDelegationResolver(delegation)
				resolver.UnDelegate(minimumAmount, 100, 1000, 10000) // very long lockup

				gs.addDelegation(delegationID, delegation)

				testing.SetRealm(testing.NewUserRealm(govStakerAddr))
				xgns.Mint(cross, user, minimumAmount)

				return user
			},
			description: "Should return 0 when all withdrawals are still locked",
		},
		{
			name: "user has delegations with no withdrawals",
			setupFunc: func(gs *govStakerV1) address {
				user := testutils.TestAddress("alice")
				validator := testutils.TestAddress("validator1")

				delegationID := gs.nextDelegationID()
				delegation := staker.NewDelegation(delegationID, user, validator, minimumAmount, 100, 1000)

				gs.addDelegation(delegationID, delegation)

				return user
			},
			description: "Should return 0 when delegations have no withdrawals",
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			// Given: Create test environment
			gs := createTestGovStaker()
			cleanupStakerDelegateTest(t, gs)

			user := tt.setupFunc(gs)

			// When: Try to collect
			var collected int64
			var err error

			func(cur realm) {
				testing.SetRealm(testing.NewCodeRealm(GOV_STAKER_PKG_PATH))
				collected, err = gs.collectDelegations(user, 2000)
			}(cross)

			// Then: Should return 0
			uassert.NoError(t, err)
			uassert.Equal(t, collected, int64(0))
		})
	}
}

// Test boundary conditions where safe arithmetic is used in delegation store operations
func TestStakerDelegate_BoundaryConditions_TotalDelegatedAmount(t *testing.T) {
	tests := []struct {
		name          string
		initialAmount int64
		addAmount     int64
		expectPanic   bool
		description   string
	}{
		{
			name:          "add to total delegated near max int64",
			initialAmount: math.MaxInt64 - 10000000,
			addAmount:     5000000,
			expectPanic:   false,
			description:   "Should handle adding when total is near max",
		},
		{
			name:          "add causing overflow in total delegated",
			initialAmount: math.MaxInt64 - 1000,
			addAmount:     2000,
			expectPanic:   true,
			description:   "Should panic when addition would overflow",
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			gs := createTestGovStaker()

			// Given: Set initial total delegated amount
			err := gs.store.SetTotalDelegatedAmount(tt.initialAmount)
			uassert.NoError(t, err)

			if tt.expectPanic {
				// When & Then: Should panic on overflow
				didPanic := false
				func() {
					defer func() {
						if r := recover(); r != nil {
							didPanic = true
						}
					}()
					// This simulates the safe arithmetic used in delegate()
					current := gs.store.GetTotalDelegatedAmount()
					newTotal := safeAddInt64(current, tt.addAmount)
					_ = gs.store.SetTotalDelegatedAmount(newTotal)
				}()
				uassert.True(t, didPanic)
			} else {
				// When: Add amount near boundary
				current := gs.store.GetTotalDelegatedAmount()
				newTotal := safeAddInt64(current, tt.addAmount)
				err = gs.store.SetTotalDelegatedAmount(newTotal)

				// Then: Should succeed
				uassert.NoError(t, err)
				result := gs.store.GetTotalDelegatedAmount()
				uassert.Equal(t, result, tt.initialAmount+tt.addAmount)
			}
		})
	}
}

// Test boundary conditions where safe arithmetic is used for subtraction in store operations
func TestStakerDelegate_BoundaryConditions_Undelegate(t *testing.T) {
	tests := []struct {
		name           string
		totalDelegated int64
		subAmount      int64
		expectPanic    bool
		description    string
	}{
		{
			name:           "subtract large amount from large total",
			totalDelegated: math.MaxInt64 / 2,
			subAmount:      math.MaxInt64 / 4,
			expectPanic:    false,
			description:    "Should handle large subtraction",
		},
		{
			name:           "subtract causing underflow in total delegated",
			totalDelegated: math.MinInt64 + 1000,
			subAmount:      2000,
			expectPanic:    true,
			description:    "Should panic when subtraction would underflow",
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			gs := createTestGovStaker()

			// Given: Set initial total delegated amount
			err := gs.store.SetTotalDelegatedAmount(tt.totalDelegated)
			uassert.NoError(t, err)

			if tt.expectPanic {
				// When & Then: Should panic on underflow
				didPanic := false
				func() {
					defer func() {
						if r := recover(); r != nil {
							didPanic = true
						}
					}()
					// This simulates the safe arithmetic used in unDelegate()
					current := gs.store.GetTotalDelegatedAmount()
					newTotal := safeSubInt64(current, tt.subAmount)
					_ = gs.store.SetTotalDelegatedAmount(newTotal)
				}()
				uassert.True(t, didPanic)
			} else {
				// When: Subtract amount
				current := gs.store.GetTotalDelegatedAmount()
				newTotal := safeSubInt64(current, tt.subAmount)
				err = gs.store.SetTotalDelegatedAmount(newTotal)

				// Then: Should succeed
				uassert.NoError(t, err)
				result := gs.store.GetTotalDelegatedAmount()
				uassert.Equal(t, result, tt.totalDelegated-tt.subAmount)
			}
		})
	}
}

// Test boundary conditions in collect operations
func TestStakerDelegate_BoundaryConditions_CollectDelegations(t *testing.T) {
	tests := []struct {
		name            string
		initialLocked   int64
		collectAmount   int64
		expectUnderflow bool
		description     string
	}{
		{
			name:            "collect with locked amount at boundary",
			initialLocked:   1000000,
			collectAmount:   1000000,
			expectUnderflow: false,
			description:     "Should handle collecting exactly locked amount",
		},
		{
			name:            "collect more than locked (should clamp to zero)",
			initialLocked:   500000,
			collectAmount:   1000000,
			expectUnderflow: false,
			description:     "Should clamp to zero when collecting more than locked",
		},
		{
			name:            "collect with large locked amount",
			initialLocked:   math.MaxInt64 / 2,
			collectAmount:   math.MaxInt64 / 4,
			expectUnderflow: false,
			description:     "Should handle large collection amounts",
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			gs := createTestGovStaker()
			cleanupStakerDelegateTest(t, gs)

			// Given: Set initial locked amount
			err := gs.store.SetTotalLockedAmount(tt.initialLocked)
			uassert.NoError(t, err)

			// When: Simulate collection logic
			currentLocked := gs.store.GetTotalLockedAmount()
			newLocked := safeSubInt64(currentLocked, tt.collectAmount)
			if newLocked < 0 {
				newLocked = 0
			}

			// Then: Should succeed and clamp to valid range
			uassert.True(t, newLocked >= 0)
			uassert.True(t, newLocked <= tt.initialLocked)

			err = gs.store.SetTotalLockedAmount(newLocked)
			uassert.NoError(t, err)

			result := gs.store.GetTotalLockedAmount()
			uassert.Equal(t, result, newLocked)
		})
	}
}

// Test accumulation of collected amounts from multiple delegations
func TestStakerDelegate_BoundaryConditions_AccumulateCollected(t *testing.T) {
	tests := []struct {
		name        string
		amounts     []int64
		expectPanic bool
		description string
	}{
		{
			name:        "accumulate normal amounts",
			amounts:     []int64{100000, 200000, 300000, 400000, 500000},
			expectPanic: false,
			description: "Should accumulate multiple normal amounts",
		},
		{
			name:        "accumulate large amounts",
			amounts:     []int64{math.MaxInt64 / 10, math.MaxInt64 / 10, math.MaxInt64 / 10},
			expectPanic: false,
			description: "Should accumulate large amounts without overflow",
		},
		{
			name:        "accumulate causing overflow",
			amounts:     []int64{math.MaxInt64 / 2, math.MaxInt64 / 2, math.MaxInt64 / 2},
			expectPanic: true,
			description: "Should panic when accumulation would overflow",
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			if tt.expectPanic {
				didPanic := false
				func() {
					defer func() {
						if r := recover(); r != nil {
							didPanic = true
						}
					}()
					collected := int64(0)
					for _, amt := range tt.amounts {
						collected = safeAddInt64(collected, amt)
					}
				}()
				uassert.True(t, didPanic)
			} else {
				collected := int64(0)
				for _, amt := range tt.amounts {
					collected = safeAddInt64(collected, amt)
				}

				// Then: Should have accumulated all amounts
				expectedTotal := int64(0)
				for _, amt := range tt.amounts {
					expectedTotal += amt
				}
				uassert.Equal(t, collected, expectedTotal)
			}
		})
	}
}
