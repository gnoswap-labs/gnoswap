package v1

import (
	"chain/runtime"
	"math"
	"testing"
	"time"

	bptree "gno.land/p/nt/bptree/v0"
	testutils "gno.land/p/nt/testutils/v0"
	uassert "gno.land/p/nt/uassert/v0"

	gnsmath "gno.land/p/gnoswap/gnsmath"
	_ "gno.land/p/gnoswap/rbac"
	_ "gno.land/r/gnoswap/rbac"

	_ "gno.land/r/gnoswap/access"

	_ "gno.land/r/gnoswap/protocol_fee"
	_ "gno.land/r/gnoswap/protocol_fee/v1"

	_ "gno.land/r/gnoswap/gov/governance/v1"
	"gno.land/r/gnoswap/gov/staker"

	"gno.land/r/gnoswap/gns"
	"gno.land/r/gnoswap/gov/xgns"
	"gno.land/r/gnoswap/halt"
)

// Test Delegate function
func TestStakerDelegate_Delegate(cur realm, t *testing.T) {
	tests := []struct {
		name          string
		caller        address
		to            address
		amount        int64
		referrer      string
		expectPanic   bool
		expectedError string
	}{
		{
			name:        "Successful delegation with valid parameters",
			caller:      testutils.TestAddress("alice"),
			to:          testutils.TestAddress("validator1"),
			amount:      minimumAmount,
			referrer:    "",
			expectPanic: false,
		},
		{
			name:          "Invalid address should panic",
			caller:        testutils.TestAddress("alice"),
			to:            address(""),
			amount:        minimumAmount,
			referrer:      "",
			expectPanic:   true,
			expectedError: "invalid address: ",
		},
		{
			name:          "Amount less than minimum should panic",
			caller:        testutils.TestAddress("alice"),
			to:            testutils.TestAddress("validator1"),
			amount:        minimumAmount - 1,
			referrer:      "",
			expectPanic:   true,
			expectedError: "[GNOSWAP-GOV_STAKER-007] cannot delegate less than minimum amount || minimum amount to delegate is 1000000 (requested:999999)",
		},
		{
			name:          "Amount not multiple of minimum should panic",
			caller:        testutils.TestAddress("alice"),
			to:            testutils.TestAddress("validator1"),
			amount:        minimumAmount + 1,
			referrer:      "",
			expectPanic:   true,
			expectedError: "[GNOSWAP-GOV_STAKER-002] invalid amount || amount must be multiple of 1000000",
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(cur realm, t *testing.T) {
			// Given: fund caller and approve gov/staker to pull GNS
			setupStakerDelegateTestGNSBalance(cur, t)

			testing.SetRealm(testing.NewUserRealm(tt.caller))

			// When & Then: cross into the gov/staker proxy so rlm carries
			// addr=gov/staker and prev=user, matching production callers.
			if tt.expectPanic {
				uassert.AbortsWithMessage(t, cur, tt.expectedError, func() {
					staker.Delegate(cross(cur), tt.to, tt.amount, tt.referrer)
				})
			} else {
				result := staker.Delegate(cross(cur), tt.to, tt.amount, tt.referrer)
				uassert.Equal(t, result, tt.amount)
			}
		})
	}
}

func TestStakerDelegate_Delegate_AllowsContractCaller(cur realm, t *testing.T) {
	contractCallerRealm := testing.NewCodeRealm("gno.land/r/onbloc/delegator")
	contractCaller := contractCallerRealm.Address()
	// Use addresses isolated from TestStakerDelegate_Delegate (alice/validator1).
	originCaller := testutils.TestAddress("contract_origin")
	validator := testutils.TestAddress("validator_contract")
	amount := int64(minimumAmount)

	testing.SetRealm(adminRealm)
	gns.Transfer(cross(cur), contractCaller, amount)

	testing.SetRealm(contractCallerRealm)
	gns.Approve(cross(cur), govStakerAddr, amount)

	// Tx origin is alice, but the crossing caller is the contract realm.
	testing.SetRealm(testing.NewUserRealm(originCaller))
	testing.SetOriginCaller(originCaller)

	testing.SetRealm(contractCallerRealm)
	result := staker.Delegate(cross(cur), validator, amount, "")
	uassert.Equal(t, result, amount)

	delegationCount := staker.GetUserDelegationCount(contractCaller, validator)
	uassert.Equal(t, delegationCount, 1)

	delegationIDs := staker.GetUserDelegationIDs(contractCaller, validator)
	uassert.Equal(t, len(delegationIDs), 1)

	delegation, err := staker.GetDelegation(delegationIDs[0])
	uassert.NoError(t, err)
	uassert.Equal(t, delegation.DelegateFrom(), contractCaller)
	uassert.Equal(t, delegation.DelegateTo(), validator)
	uassert.Equal(t, delegation.TotalDelegatedAmount(), amount)

	uassert.Equal(t, staker.GetUserDelegationCount(originCaller, validator), 0)
}

// Test Undelegate function
func TestStakerDelegate_Undelegate(cur realm, t *testing.T) {
	tests := []struct {
		name            string
		caller          address
		delegator       address
		from            address
		amount          int64
		expectPanic     bool
		expectedError   string
		setupDelegation bool
		expectedAmount  int64
	}{
		{
			name:            "Successful undelegation",
			caller:          testutils.TestAddress("alice"),
			delegator:       testutils.TestAddress("alice"),
			from:            testutils.TestAddress("val_undelegate"),
			amount:          minimumAmount,
			setupDelegation: true,
			expectedAmount:  minimumAmount,
		},
		{
			name:           "Invalid from address should panic",
			caller:         testutils.TestAddress("alice"),
			delegator:      testutils.TestAddress("alice"),
			from:           address(""),
			amount:         minimumAmount,
			expectedAmount: 0,
			expectPanic:    true,
			expectedError:  "invalid address: ",
		},
		{
			name:            "Caller not delegator should not panic",
			caller:          testutils.TestAddress("bob"),
			delegator:       testutils.TestAddress("alice"),
			from:            testutils.TestAddress("val_undel_bob"),
			amount:          minimumAmount,
			setupDelegation: true,
			expectedAmount:  0,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(cur realm, t *testing.T) {
			setupStakerDelegateTestGNSBalance(cur, t)

			if tt.setupDelegation {
				testing.SetRealm(testing.NewUserRealm(tt.delegator))
				callStakerDelegate(cur, tt.from, minimumAmount, "")
			}

			testing.SetRealm(testing.NewUserRealm(tt.caller))

			if tt.expectPanic {
				uassert.AbortsWithMessage(t, cur, tt.expectedError, func() {
					callStakerUndelegate(cur, tt.from, tt.amount)
				})
			} else {
				result := callStakerUndelegate(cur, tt.from, tt.amount)
				uassert.Equal(t, result, tt.expectedAmount)
			}
		})
	}
}

// Test Undelegate with multiple delegations to same delegatee
// This tests the optimization where GetUnDelegationLockupPeriod is called only once
func TestStakerDelegate_UndelegateMultipleDelegations(cur realm, t *testing.T) {
	tests := []struct {
		name                 string
		validator            address
		delegationAmounts    []int64
		undelegateAmount     int64
		expectedSuccess      bool
		minExpectedWithdraws int
		description          string
	}{
		{
			name:                 "Undelegate spanning multiple delegations",
			validator:            testutils.TestAddress("mval0"),
			delegationAmounts:    []int64{minimumAmount, minimumAmount * 2, minimumAmount * 3, minimumAmount * 4, minimumAmount * 5},
			undelegateAmount:     minimumAmount * 8,
			expectedSuccess:      true,
			minExpectedWithdraws: 3,
			description:          "Should process first 3 delegations (1M + 2M + 3M + 2M from 4th)",
		},
		{
			name:                 "Early exit - only first delegation needed",
			validator:            testutils.TestAddress("mval1"),
			delegationAmounts:    []int64{minimumAmount * 10, minimumAmount * 5, minimumAmount * 3},
			undelegateAmount:     minimumAmount * 5,
			expectedSuccess:      true,
			minExpectedWithdraws: 1,
			description:          "Should only process first delegation and exit early",
		},
		{
			name:                 "Exact match - first delegation",
			validator:            testutils.TestAddress("mval2"),
			delegationAmounts:    []int64{minimumAmount * 5, minimumAmount * 3, minimumAmount * 2},
			undelegateAmount:     minimumAmount * 5,
			expectedSuccess:      true,
			minExpectedWithdraws: 1,
			description:          "Should exactly match and consume first delegation",
		},
		{
			name:                 "Exact match - multiple delegations",
			validator:            testutils.TestAddress("mval3"),
			delegationAmounts:    []int64{minimumAmount, minimumAmount * 2, minimumAmount * 3},
			undelegateAmount:     minimumAmount * 6,
			expectedSuccess:      true,
			minExpectedWithdraws: 3,
			description:          "Should exactly consume all three delegations (1M + 2M + 3M)",
		},
		{
			name:                 "All delegations required",
			validator:            testutils.TestAddress("mval4"),
			delegationAmounts:    []int64{minimumAmount, minimumAmount * 2, minimumAmount * 3},
			undelegateAmount:     minimumAmount * 6,
			expectedSuccess:      true,
			minExpectedWithdraws: 3,
			description:          "Should process all delegations when amount equals total",
		},
		{
			name:                 "Partial last delegation",
			validator:            testutils.TestAddress("mval5"),
			delegationAmounts:    []int64{minimumAmount * 2, minimumAmount * 3, minimumAmount * 10},
			undelegateAmount:     minimumAmount * 7,
			expectedSuccess:      true,
			minExpectedWithdraws: 3,
			description:          "Should fully use first two and partially use third (2M + 3M + 2M)",
		},
		{
			name:                 "Single delegation - partial undelegate",
			validator:            testutils.TestAddress("mval6"),
			delegationAmounts:    []int64{minimumAmount * 10},
			undelegateAmount:     minimumAmount * 3,
			expectedSuccess:      true,
			minExpectedWithdraws: 1,
			description:          "Should handle single delegation case (boundary)",
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(cur realm, t *testing.T) {
			setupStakerDelegateTestGNSBalance(cur, t)

			user := testutils.TestAddress("alice")
			testing.SetRealm(testing.NewUserRealm(user))

			for _, amount := range tt.delegationAmounts {
				callStakerDelegate(cur, tt.validator, amount, "")
			}

			undelegatedAmount := callStakerUndelegate(cur, tt.validator, tt.undelegateAmount)

			if tt.expectedSuccess {
				uassert.Equal(t, undelegatedAmount, tt.undelegateAmount)

				delegationIDs := staker.GetUserDelegationIDs(user, tt.validator)
				totalWithdraws := 0
				totalUndelegated := int64(0)

				for _, delegationID := range delegationIDs {
					delegation, err := staker.GetDelegation(delegationID)
					if err == nil && delegation != nil {
						totalWithdraws += staker.GetDelegationWithdrawCount(delegationID)
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
func TestStakerDelegate_UndelegateMultipleDelegations_EdgeCases(cur realm, t *testing.T) {
	tests := []struct {
		name          string
		validator     address
		setupDelegate bool
		undelegateAmt int64
		expectPanic   bool
		expectedError string
		description   string
	}{
		{
			name:          "Undelegate from non-existent delegatee",
			validator:     testutils.TestAddress("edge_val0"),
			undelegateAmt: minimumAmount,
			expectPanic:   false,
			description:   "Should return 0 when no delegations exist",
		},
		{
			name:          "Undelegate more than total delegated",
			validator:     testutils.TestAddress("edge_val1"),
			setupDelegate: true,
			undelegateAmt: minimumAmount * 10,
			expectPanic:   true,
			expectedError: errNotEnoughDelegated.Error(),
			description:   "Should reject when requested exceeds delegated",
		},
		{
			name:          "Undelegate zero amount",
			validator:     testutils.TestAddress("edge_val2"),
			setupDelegate: true,
			undelegateAmt: 0,
			expectPanic:   true,
			expectedError: "[GNOSWAP-GOV_STAKER-007] cannot delegate less than minimum amount || minimum amount to delegate is 1000000 (requested:0)",
			description:   "Should reject zero amount",
		},
		{
			name:          "Undelegate negative amount",
			validator:     testutils.TestAddress("edge_val3"),
			setupDelegate: true,
			undelegateAmt: -minimumAmount,
			expectPanic:   true,
			expectedError: "[GNOSWAP-GOV_STAKER-007] cannot delegate less than minimum amount || minimum amount to delegate is 1000000 (requested:-1000000)",
			description:   "Should reject negative amount",
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(cur realm, t *testing.T) {
			setupStakerDelegateTestGNSBalance(cur, t)

			user := testutils.TestAddress("bob")
			testing.SetRealm(testing.NewUserRealm(user))

			if tt.setupDelegate {
				callStakerDelegate(cur, tt.validator, minimumAmount*5, "")
			}

			if tt.expectPanic {
				uassert.AbortsWithMessage(t, cur, tt.expectedError, func() {
					callStakerUndelegate(cur, tt.validator, tt.undelegateAmt)
				})
			} else {
				result := callStakerUndelegate(cur, tt.validator, tt.undelegateAmt)
				if tt.undelegateAmt > 0 {
					uassert.True(t, result >= 0)
				}
			}
		})
	}
}

// Test Redelegate function
func TestStakerDelegate_Redelegate(cur realm, t *testing.T) {
	tests := []struct {
		name             string
		caller           address
		from             address
		to               address
		amount           int64
		expectPanic      bool
		expectedError    string
		setupDelegation  bool
		delegationAmount int64
	}{
		{
			name:             "Successful redelegation",
			caller:           testutils.TestAddress("alice"),
			from:             testutils.TestAddress("reval_from"),
			to:               testutils.TestAddress("reval_to"),
			amount:           minimumAmount,
			setupDelegation:  true,
			delegationAmount: minimumAmount,
		},
		{
			name:             "Redelegate more than delegated should panic",
			caller:           testutils.TestAddress("alice"),
			from:             testutils.TestAddress("reval_from2"),
			to:               testutils.TestAddress("reval_to2"),
			amount:           minimumAmount * 2,
			expectPanic:      true,
			expectedError:    errNotEnoughDelegated.Error(),
			setupDelegation:  true,
			delegationAmount: minimumAmount,
		},
		{
			name:          "Redelegate without delegation should panic",
			caller:        testutils.TestAddress("alice"),
			from:          testutils.TestAddress("reval_from3"),
			to:            testutils.TestAddress("reval_to3"),
			amount:        minimumAmount,
			expectPanic:   true,
			expectedError: errNotEnoughDelegated.Error(),
		},
		{
			name:          "Invalid delegator address should panic",
			caller:        testutils.TestAddress("alice"),
			from:          address(""),
			to:            testutils.TestAddress("reval_to4"),
			amount:        minimumAmount,
			expectPanic:   true,
			expectedError: "invalid address: ",
		},
		{
			name:          "Invalid delegatee address should panic",
			caller:        testutils.TestAddress("alice"),
			from:          testutils.TestAddress("reval_from5"),
			to:            address(""),
			amount:        minimumAmount,
			expectPanic:   true,
			expectedError: "invalid address: ",
		},
		{
			name:          "Same delegatee should panic",
			caller:        testutils.TestAddress("alice"),
			from:          testutils.TestAddress("reval_same"),
			to:            testutils.TestAddress("reval_same"),
			amount:        minimumAmount,
			expectPanic:   true,
			expectedError: errSameDelegatee.Error(),
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(cur realm, t *testing.T) {
			setupStakerDelegateTestGNSBalance(cur, t)
			testing.SetRealm(testing.NewUserRealm(tt.caller))

			if tt.setupDelegation {
				callStakerDelegate(cur, tt.from, tt.delegationAmount, "")
			}

			if tt.expectPanic {
				uassert.AbortsWithMessage(t, cur, tt.expectedError, func() {
					callStakerRedelegate(cur, tt.from, tt.to, tt.amount)
				})
			} else {
				result := callStakerRedelegate(cur, tt.from, tt.to, tt.amount)
				uassert.Equal(t, result, tt.amount)
			}
		})
	}
}

func TestStakerDelegate_RedelegatePreservesTotalLockedAmount(cur realm, t *testing.T) {
	setupStakerDelegateTestGNSBalance(cur, t)

	user := testutils.TestAddress("charlie")
	validator1 := testutils.TestAddress("lr1")
	validator2 := testutils.TestAddress("lr2")
	validator3 := testutils.TestAddress("lr3")
	amount := int64(minimumAmount) * 5

	testing.SetRealm(testing.NewUserRealm(user))

	callStakerDelegate(cur, validator1, amount, "")

	lockedAfterDelegate := staker.GetTotalLockedAmount()
	delegatedAfterDelegate := staker.GetTotalDelegated()

	transitions := []struct {
		from address
		to   address
	}{
		{from: validator1, to: validator2},
		{from: validator2, to: validator3},
		{from: validator3, to: validator1},
		{from: validator1, to: validator2},
	}

	for _, transition := range transitions {
		result := callStakerRedelegate(cur, transition.from, transition.to, amount)
		uassert.Equal(t, result, amount)

		uassert.Equal(t, staker.GetTotalLockedAmount(), lockedAfterDelegate)
		uassert.Equal(t, staker.GetTotalDelegated(), delegatedAfterDelegate)
	}
}

func TestStakerDelegate_XgnsBurnOccursOnCollect(cur realm, t *testing.T) {
	setupStakerDelegateTestGNSBalance(cur, t)

	user := testutils.TestAddress("alice")
	validator := testutils.TestAddress("validator1")
	amount := int64(minimumAmount)

	testing.SetRealm(testing.NewUserRealm(admin))
	staker.SetUnDelegationLockupPeriodByAdmin(cross(cur), 0)

	initialSupply := xgns.TotalSupply()
	initialBalance := xgns.BalanceOf(user)

	testing.SetRealm(testing.NewUserRealm(user))
	callStakerDelegate(cur, validator, amount, "")

	uassert.Equal(t, xgns.TotalSupply(), gnsmath.SafeAddInt64(initialSupply, amount))
	uassert.Equal(t, xgns.BalanceOf(user), gnsmath.SafeAddInt64(initialBalance, amount))

	callStakerUndelegate(cur, validator, amount)

	uassert.Equal(t, xgns.TotalSupply(), gnsmath.SafeAddInt64(initialSupply, amount))
	uassert.Equal(t, xgns.BalanceOf(user), gnsmath.SafeAddInt64(initialBalance, amount))

	callStakerCollectUndelegatedGns(cur)

	uassert.Equal(t, xgns.TotalSupply(), initialSupply)
	uassert.Equal(t, xgns.BalanceOf(user), initialBalance)
}

// Test CollectUndelegatedGns function
func TestStakerDelegate_CollectUndelegatedGns(cur realm, t *testing.T) {
	tests := []struct {
		name             string
		caller           address
		expectPanic      bool
		expectedError    string
		setupCollectable func(cur realm, gs *govStakerV1)
		cleanupMocks     func(cur realm, gs *govStakerV1)
		expectedAmount   int64
	}{
		{
			name:        "Successful collection",
			caller:      testutils.TestAddress("alice"),
			expectPanic: false,
			setupCollectable: func(cur realm, gs *govStakerV1) {
				cleanupStakerDelegateTest(cur, t, gs)
				setupStakerDelegateTestCollectableAmount(cur, t, gs, testutils.TestAddress("alice"), minimumAmount)
			},
			cleanupMocks: func(cur realm, gs *govStakerV1) {
				cleanupStakerDelegateTest(cur, t, gs)
			},
			expectedAmount: minimumAmount,
		},
		{
			name:        "No collectable amount returns zero",
			caller:      testutils.TestAddress("alice"),
			expectPanic: false,
			setupCollectable: func(cur realm, gs *govStakerV1) {
				cleanupStakerDelegateTest(cur, t, gs)
			},
			cleanupMocks: func(cur realm, gs *govStakerV1) {
				cleanupStakerDelegateTest(cur, t, gs)
			},
			expectedAmount: 0,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(cur realm, t *testing.T) {
			// Given: Setup test environment with collectable amount
			gs := createTestGovStaker()

			tt.setupCollectable(cur, gs)
			defer tt.cleanupMocks(cur, gs)

			testing.SetRealm(testing.NewUserRealm(tt.caller))

			// When & Then: Execute and verify
			if tt.expectPanic {
				uassert.AbortsWithMessage(t, cur, tt.expectedError, func() {
					callMockCollectUndelegatedGns(cur, gs, tt.caller, time.Now().Unix())
				})
			} else {
				result := callMockCollectUndelegatedGns(cur, gs, tt.caller, time.Now().Unix())
				uassert.Equal(t, tt.expectedAmount, result)
			}
		})
	}
}

func TestStakerDelegate_CollectUndelegatedGns_EmergencyHaltAllowsRecovery(cur realm, t *testing.T) {
	gs := createTestGovStaker()
	cleanupStakerDelegateTest(cur, t, gs)
	setupStakerDelegateTestCollectableAmount(cur, t, gs, testutils.TestAddress("alice"), minimumAmount)
	defer cleanupStakerDelegateTest(cur, t, gs)

	testing.SetRealm(adminRealm)
	halt.SetHaltLevel(cross(cur), halt.HaltLevelEmergency)

	testing.SetRealm(testing.NewUserRealm(testutils.TestAddress("alice")))
	uassert.NotPanics(t, cur, func() {
		result := callMockCollectUndelegatedGns(cur, gs, testutils.TestAddress("alice"), time.Now().Unix())
		uassert.Equal(t, int64(minimumAmount), result)
	})

	testing.SetRealm(adminRealm)
	halt.SetHaltLevel(cross(cur), halt.HaltLevelNone)
}

// Test comprehensive delegation validation including edge cases
func TestStakerDelegate_DelegationValidationEdgeCases(cur realm, t *testing.T) {
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
			expectedError: "[GNOSWAP-GOV_STAKER-007] cannot delegate less than minimum amount || minimum amount to delegate is 1000000 (requested:999999)",
		},
		{
			name:          "fail - amount not multiple of minimum",
			caller:        testutils.TestAddress("alice"),
			to:            testutils.TestAddress("validator"),
			amount:        minimumAmount + 1,
			setupBalance:  minimumAmount * 2,
			expectPanic:   true,
			expectedError: "[GNOSWAP-GOV_STAKER-002] invalid amount || amount must be multiple of 1000000",
		},
		{
			name:          "fail - zero amount",
			caller:        testutils.TestAddress("alice"),
			to:            testutils.TestAddress("validator"),
			amount:        0,
			setupBalance:  minimumAmount * 2,
			expectPanic:   true,
			expectedError: "[GNOSWAP-GOV_STAKER-007] cannot delegate less than minimum amount || minimum amount to delegate is 1000000 (requested:0)",
		},
		{
			name:          "fail - negative amount",
			caller:        testutils.TestAddress("alice"),
			to:            testutils.TestAddress("validator"),
			amount:        -minimumAmount,
			setupBalance:  minimumAmount * 2,
			expectPanic:   true,
			expectedError: "[GNOSWAP-GOV_STAKER-007] cannot delegate less than minimum amount || minimum amount to delegate is 1000000 (requested:-1000000)",
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
			expectedError: "[GNOSWAP-GOV_STAKER-002] invalid amount || amount must be multiple of 1000000",
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(cur realm, t *testing.T) {
			setupStakerDelegateTestGNSBalance(cur, t)

			testing.SetRealm(testing.NewUserRealm(tt.caller))

			// When & Then: Execute and verify
			if tt.expectPanic {
				uassert.AbortsWithMessage(t, cur, tt.expectedError, func() {
					callStakerDelegate(cur, tt.to, tt.amount, "")
				})
			} else {
				result := callStakerDelegate(cur, tt.to, tt.amount, "")
				uassert.Equal(t, result, tt.amount)
			}
		})
	}
}

// Test lockup period and withdrawal timing
func TestStakerDelegate_LockupPeriodAndWithdrawal(cur realm, t *testing.T) {
	tests := []struct {
		name                string
		user                address
		validator           address
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
			user:                testutils.TestAddress("alice"),
			validator:           testutils.TestAddress("lock_v0"),
			delegateAmount:      minimumAmount * 10,
			undelegateAmount:    minimumAmount * 5,
			lockupPeriod:        7 * 24 * 3600, // 7 days in seconds
			waitTime:            8 * 24 * 3600, // 8 days wait
			expectedCollectable: minimumAmount * 5,
			shouldFail:          false,
		},
		{
			name:                "success - collect before lockup period ends but after undelegate",
			user:                testutils.TestAddress("bob"),
			validator:           testutils.TestAddress("lock_v1"),
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
			user:                testutils.TestAddress("charlie"),
			validator:           testutils.TestAddress("lock_v2"),
			delegateAmount:      minimumAmount * 10,
			undelegateAmount:    minimumAmount * 4,
			lockupPeriod:        7 * 24 * 3600,
			waitTime:            8 * 24 * 3600,
			expectedCollectable: minimumAmount * 4,
			shouldFail:          false,
		},
		{
			name:                "success - multiple collections",
			user:                testutils.TestAddress("alice"),
			validator:           testutils.TestAddress("lock_v3"),
			delegateAmount:      minimumAmount * 10,
			undelegateAmount:    minimumAmount * 6,
			lockupPeriod:        7 * 24 * 3600,
			waitTime:            8 * 24 * 3600,
			expectedCollectable: minimumAmount * 6,
			shouldFail:          false,
			description:         "Should be able to collect in multiple transactions",
		},
		{
			name:                "success - large amount collection without overflow",
			user:                testutils.TestAddress("charlie"),
			validator:           testutils.TestAddress("lock_v5"),
			delegateAmount:      minimumAmount * 10_000,
			undelegateAmount:    minimumAmount * 5_000,
			lockupPeriod:        7 * 24 * 3600,
			waitTime:            8 * 24 * 3600,
			expectedCollectable: minimumAmount * 5_000,
			shouldFail:          false,
			description:         "Large amounts but still within int64 range",
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(cur realm, t *testing.T) {
			setupStakerDelegateTestGNSBalance(cur, t)

			ctx := testing.GetContext()
			ctx.Height = 1000
			ctx.Time = time.Unix(1_000_000, 0)
			testing.SetContext(ctx)

			testing.SetRealm(adminRealm)
			gns.Transfer(cross(cur), tt.user, tt.delegateAmount*2)
			testing.SetRealm(testing.NewUserRealm(tt.user))
			gns.Approve(cross(cur), govStakerAddr, tt.delegateAmount*2)

			testing.SetRealm(testing.NewUserRealm(admin))
			staker.SetUnDelegationLockupPeriodByAdmin(cross(cur), tt.lockupPeriod)

			testing.SetRealm(testing.NewUserRealm(tt.user))
			callStakerDelegate(cur, tt.validator, tt.delegateAmount, "")
			callStakerUndelegate(cur, tt.validator, tt.undelegateAmount)

			blockTime := int64(5)
			testing.SkipHeights(tt.waitTime / blockTime)

			if tt.shouldFail {
				uassert.AbortsWithMessage(t, cur, tt.expectedError, func() {
					callStakerCollectUndelegatedGns(cur)
				})
			} else {
				result := callStakerCollectUndelegatedGns(cur)
				uassert.Equal(t, tt.expectedCollectable, result)
			}
		})
	}
}

// Test delegation with referrer functionality
func TestStakerDelegate_ReferrerFunctionality(cur realm, t *testing.T) {
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
		t.Run(tt.name, func(cur realm, t *testing.T) {
			setupStakerDelegateTestGNSBalance(cur, t)

			testing.SetRealm(testing.NewUserRealm(tt.caller))
			testing.SetOriginCaller(tt.caller)

			// When & Then: Execute delegation with referrer
			if tt.expectError {
				uassert.AbortsWithMessage(t, cur, "", func() {
					callStakerDelegate(cur, tt.to, tt.amount, tt.referrer)
				})
			} else {
				result := callStakerDelegate(cur, tt.to, tt.amount, tt.referrer)
				uassert.Equal(t, result, tt.amount)
			}
		})
	}
}

// Test edge cases for delegation operations
func TestStakerDelegate_EdgeCasesAndBoundaries(cur realm, t *testing.T) {
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
				return testutils.TestAddress("edge_u0"), testutils.TestAddress("edge_v0"), minimumAmount * 10
			},
			executeAction:  "undelegate",
			expectedResult: minimumAmount * 10,
			expectError:    false,
		},
		{
			name: "redelegate between validators",
			setupScenario: func() (address, address, int64) {
				return testutils.TestAddress("edge_u1"), testutils.TestAddress("edge_v2"), minimumAmount * 5
			},
			executeAction:  "redelegate",
			expectedResult: minimumAmount * 5,
			expectError:    false,
		},
		{
			name: "collect when no undelegated amount available",
			setupScenario: func() (address, address, int64) {
				return testutils.TestAddress("edge_u2"), testutils.TestAddress("edge_v3"), 0
			},
			executeAction:  "collect",
			expectedResult: 0,
			expectError:    false,
			description:    "Should return 0 when nothing to collect",
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(cur realm, t *testing.T) {
			setupStakerDelegateTestGNSBalance(cur, t)

			user, target, amount := tt.setupScenario()

			if amount > 0 {
				testing.SetRealm(adminRealm)
				gns.Transfer(cross(cur), user, amount*2)
				testing.SetRealm(testing.NewUserRealm(user))
				gns.Approve(cross(cur), govStakerAddr, amount*2)

				delegateTo := target
				if tt.executeAction == "redelegate" {
					delegateTo = testutils.TestAddress("edge_v1")
				}
				callStakerDelegate(cur, delegateTo, amount, "")
			}

			testing.SetRealm(testing.NewUserRealm(user))

			var result int64
			if tt.expectError {
				uassert.AbortsWithMessage(t, cur, "", func() {
					switch tt.executeAction {
					case "delegate":
						callStakerDelegate(cur, target, amount, "")
					case "undelegate":
						callStakerUndelegate(cur, target, amount)
					case "redelegate":
						callStakerRedelegate(cur, testutils.TestAddress("validator1"), target, amount)
					case "collect":
						callStakerCollectUndelegatedGns(cur)
					}
				})
			} else {
				switch tt.executeAction {
				case "delegate":
					result = callStakerDelegate(cur, target, amount, "")
				case "undelegate":
					result = callStakerUndelegate(cur, target, amount)
				case "redelegate":
					result = callStakerRedelegate(cur, testutils.TestAddress("edge_v1"), target, amount)
				case "collect":
					result = callStakerCollectUndelegatedGns(cur)
				}

				uassert.Equal(t, result, tt.expectedResult)
			}
		})
	}
}

// Helper functions
func cleanupStakerDelegateTest(cur realm, t *testing.T, gs *govStakerV1) {
	// Mock store structures must be allocated inside a crossing frame so later
	// reads/writes from gs.Undelegate and similar are not readonly-tainted.
	func(cur realm) {
		mockStore := gs.store.(*mockGovStakerStore)
		mockStore.delegationNextID = staker.NewCounter()
		mockStore.delegations = bptree.NewBPTreeN(16)
		mockStore.totalDelegationHistory = staker.NewUintTree()
		mockStore.userDelegationHistory = bptree.NewBPTreeN(16)
		mockStore.userDelegations = bptree.NewBPTreeN(16)
		mockStore.delegationManager = staker.NewDelegationManager()
	}(cross(cur))

	setupStakerDelegateTestGNSBalance(cur, t)
}

func fundUserForStakerDelegate(cur realm, user address, amount int64) {
	testing.SetRealm(adminRealm)
	gns.Transfer(cross(cur), user, amount)

	testing.SetRealm(testing.NewUserRealm(user))
	gns.Approve(cross(cur), govStakerAddr, amount)
}

func setupStakerDelegateTestGNSBalance(cur realm, t *testing.T) {
	testing.SetRealm(adminRealm)

	amount := int64(1_000_000_000)
	gns.Transfer(cross(cur), testutils.TestAddress("alice"), amount)
	gns.Transfer(cross(cur), testutils.TestAddress("bob"), amount)
	gns.Transfer(cross(cur), testutils.TestAddress("charlie"), amount)
	gns.Transfer(cross(cur), testutils.TestAddress("validator1"), amount)
	gns.Transfer(cross(cur), testutils.TestAddress("validator2"), amount)
	gns.Transfer(cross(cur), testutils.TestAddress("validator3"), amount)

	testing.SetRealm(testing.NewUserRealm(testutils.TestAddress("alice")))
	gns.Approve(cross(cur), govStakerAddr, amount)

	testing.SetRealm(testing.NewUserRealm(testutils.TestAddress("bob")))
	gns.Approve(cross(cur), govStakerAddr, amount)

	testing.SetRealm(testing.NewUserRealm(testutils.TestAddress("charlie")))
	gns.Approve(cross(cur), govStakerAddr, amount)

	testing.SetRealm(testing.NewUserRealm(testutils.TestAddress("validator1")))
	gns.Approve(cross(cur), govStakerAddr, amount)

	testing.SetRealm(testing.NewUserRealm(testutils.TestAddress("validator2")))
	gns.Approve(cross(cur), govStakerAddr, amount)

	testing.SetRealm(testing.NewUserRealm(testutils.TestAddress("validator3")))
	gns.Approve(cross(cur), govStakerAddr, amount)
}

func setupStakerDelegateTestDelegation(cur realm, t *testing.T, gs *govStakerV1, from, to address, amount int64) {
	delegationID := gs.nextDelegationID()
	delegation := staker.NewDelegation(delegationID, from, to, amount, 100, 100)

	testing.SetRealm(testing.NewUserRealm(from))
	func(cur realm) {
		gs.addDelegation(0, cur, delegationID, delegation)
	}(cross(cur))

	testing.SetRealm(testing.NewUserRealm(from))
	gns.Transfer(cross(cur), govStakerAddr, amount)

	mintXgnsForTest(cur, from, amount)
}

func mintXgnsForTest(cur realm, user address, amount int64) {
	testing.SetRealm(govStakerRealm)
	xgns.Mint(cross(cur), user, amount)
}

func setupStakerDelegateTestCollectableAmount(cur realm, t *testing.T, gs *govStakerV1, user address, amount int64) {
	// Create a delegation that has been undelegated and is collectable
	delegationID := gs.nextDelegationID()
	delegation := staker.NewDelegation(delegationID, user, testutils.TestAddress("validator1"), amount, 100, 100)
	resolver := NewDelegationResolver(delegation)

	// Undelegate with very short lockup period
	resolver.UnDelegate(amount, 200, 100, 0) // 0 second lockup

	testing.SetRealm(testing.NewUserRealm(user))
	func(cur realm) {
		gs.addDelegation(0, cur, delegationID, delegation)
	}(cross(cur))

	testing.SetRealm(testing.NewUserRealm(user))
	gns.Transfer(cross(cur), govStakerAddr, amount)

	mintXgnsForTest(cur, user, amount)
}

// TestStakerDelegate_collectDelegations_MultipleDelegations tests collecting from multiple delegations
func TestStakerDelegate_collectDelegations_MultipleDelegations(cur realm, t *testing.T) {
	tests := []struct {
		name             string
		delegationCounts []int     // number of delegations to create
		amounts          [][]int64 // amounts for each delegation's withdrawals
		lockupPeriods    []int64   // lockup period for each delegation
		waitTime         int64     // time to wait before collecting
		expectedTotal    int64     // expected total collected amount
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
		t.Run(tt.name, func(cur realm, t *testing.T) {
			// Given: Create test environment
			gs := createTestGovStaker()
			cleanupStakerDelegateTest(cur, t, gs)

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

				testing.SetRealm(testing.NewUserRealm(user))
				func(cur realm) {
					gs.addDelegation(0, cur, delegationID, delegation)
				}(cross(cur))

				mintXgnsForTest(cur, user, totalAmount)
			}

			// When: Collect after waiting
			collectedTime := currentTime + tt.waitTime
			var collected int64
			var err error

			func(cur realm) {
				collected, err = gs.collectDelegations(0, cur, user, collectedTime)
			}(cross(cur))

			// Then: Verify collected amount
			uassert.NoError(t, err)
			uassert.Equal(t, collected, tt.expectedTotal)
		})
	}
}

// TestStakerDelegate_collectDelegations_NoCollectableAmount tests when there's nothing to collect
func TestStakerDelegate_collectDelegations_NoCollectableAmount(cur realm, t *testing.T) {
	tests := []struct {
		name        string
		setupFunc   func(cur realm, gs *govStakerV1) address
		description string
	}{
		{
			name: "user has no delegations",
			setupFunc: func(cur realm, gs *govStakerV1) address {
				return testutils.TestAddress("alice")
			},
			description: "Should return 0 when user has no delegations",
		},
		{
			name: "user has delegations but all still locked",
			setupFunc: func(cur realm, gs *govStakerV1) address {
				user := testutils.TestAddress("alice")
				validator := testutils.TestAddress("validator1")

				delegationID := gs.nextDelegationID()
				delegation := staker.NewDelegation(delegationID, user, validator, minimumAmount, 100, 1000)

				resolver := NewDelegationResolver(delegation)
				resolver.UnDelegate(minimumAmount, 100, 1000, 10000) // very long lockup

				testing.SetRealm(testing.NewUserRealm(user))
				func(cur realm) {
					gs.addDelegation(0, cur, delegationID, delegation)
				}(cross(cur))

				mintXgnsForTest(cur, user, minimumAmount)

				return user
			},
			description: "Should return 0 when all withdrawals are still locked",
		},
		{
			name: "user has delegations with no withdrawals",
			setupFunc: func(cur realm, gs *govStakerV1) address {
				user := testutils.TestAddress("alice")
				validator := testutils.TestAddress("validator1")

				delegationID := gs.nextDelegationID()
				delegation := staker.NewDelegation(delegationID, user, validator, minimumAmount, 100, 1000)

				testing.SetRealm(testing.NewUserRealm(user))
				func(cur realm) {
					gs.addDelegation(0, cur, delegationID, delegation)
				}(cross(cur))

				return user
			},
			description: "Should return 0 when delegations have no withdrawals",
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(cur realm, t *testing.T) {
			// Given: Create test environment
			gs := createTestGovStaker()
			cleanupStakerDelegateTest(cur, t, gs)

			user := tt.setupFunc(cur, gs)

			// When: Try to collect
			var collected int64
			var err error

			func(cur realm) {
				collected, err = gs.collectDelegations(0, cur, user, 2000)
			}(cross(cur))

			// Then: Should return 0
			uassert.NoError(t, err)
			uassert.Equal(t, collected, int64(0))
		})
	}
}

// Test boundary conditions where safe arithmetic is used in delegation store operations
func TestStakerDelegate_BoundaryConditions_TotalDelegatedAmount(cur realm, t *testing.T) {
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
		t.Run(tt.name, func(cur realm, t *testing.T) {
			gs := createTestGovStaker()

			// Given: Set initial total delegated amount
			err := gs.store.SetTotalDelegatedAmount(0, cur, tt.initialAmount)
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
					// This simulates the safe arithmetic used in delegate(0, cur)
					current := gs.store.GetTotalDelegatedAmount()
					newTotal := gnsmath.SafeAddInt64(current, tt.addAmount)
					_ = gs.store.SetTotalDelegatedAmount(0, cur, newTotal)
				}()
				uassert.True(t, didPanic)
			} else {
				// When: Add amount near boundary
				current := gs.store.GetTotalDelegatedAmount()
				newTotal := gnsmath.SafeAddInt64(current, tt.addAmount)
				err = gs.store.SetTotalDelegatedAmount(0, cur, newTotal)

				// Then: Should succeed
				uassert.NoError(t, err)
				result := gs.store.GetTotalDelegatedAmount()
				uassert.Equal(t, result, tt.initialAmount+tt.addAmount)
			}
		})
	}
}

// Test boundary conditions where safe arithmetic is used for subtraction in store operations
func TestStakerDelegate_BoundaryConditions_Undelegate(cur realm, t *testing.T) {
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
		t.Run(tt.name, func(cur realm, t *testing.T) {
			gs := createTestGovStaker()

			// Given: Set initial total delegated amount
			err := gs.store.SetTotalDelegatedAmount(0, cur, tt.totalDelegated)
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
					// This simulates the safe arithmetic used in unDelegate(0, cur)
					current := gs.store.GetTotalDelegatedAmount()
					newTotal := gnsmath.SafeSubInt64(current, tt.subAmount)
					_ = gs.store.SetTotalDelegatedAmount(0, cur, newTotal)
				}()
				uassert.True(t, didPanic)
			} else {
				// When: Subtract amount
				current := gs.store.GetTotalDelegatedAmount()
				newTotal := gnsmath.SafeSubInt64(current, tt.subAmount)
				err = gs.store.SetTotalDelegatedAmount(0, cur, newTotal)

				// Then: Should succeed
				uassert.NoError(t, err)
				result := gs.store.GetTotalDelegatedAmount()
				uassert.Equal(t, result, tt.totalDelegated-tt.subAmount)
			}
		})
	}
}

// Test boundary conditions in collect operations
func TestStakerDelegate_BoundaryConditions_CollectDelegations(cur realm, t *testing.T) {
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
		t.Run(tt.name, func(cur realm, t *testing.T) {
			gs := createTestGovStaker()
			cleanupStakerDelegateTest(cur, t, gs)

			// Given: Set initial locked amount
			err := gs.store.SetTotalLockedAmount(0, cur, tt.initialLocked)
			uassert.NoError(t, err)

			// When: Simulate collection logic
			currentLocked := gs.store.GetTotalLockedAmount()
			newLocked := gnsmath.SafeSubInt64(currentLocked, tt.collectAmount)
			if newLocked < 0 {
				newLocked = 0
			}

			// Then: Should succeed and clamp to valid range
			uassert.True(t, newLocked >= 0)
			uassert.True(t, newLocked <= tt.initialLocked)

			err = gs.store.SetTotalLockedAmount(0, cur, newLocked)
			uassert.NoError(t, err)

			result := gs.store.GetTotalLockedAmount()
			uassert.Equal(t, result, newLocked)
		})
	}
}

// Test accumulation of collected amounts from multiple delegations
func TestStakerDelegate_BoundaryConditions_AccumulateCollected(cur realm, t *testing.T) {
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
		t.Run(tt.name, func(cur realm, t *testing.T) {
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
						collected = gnsmath.SafeAddInt64(collected, amt)
					}
				}()
				uassert.True(t, didPanic)
			} else {
				collected := int64(0)
				for _, amt := range tt.amounts {
					collected = gnsmath.SafeAddInt64(collected, amt)
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

func setGovStakerProxyRealm(caller address) {
	// Mirror production: user -> gov/staker proxy -> v1 impl.
	testing.SetRealm(testing.NewCodeRealm("gno.land/r/gnoswap/gov/staker/v1"))
	testing.SetRealm(testing.NewCodeRealm(GOV_STAKER_PKG_PATH))
	testing.SetRealm(testing.NewUserRealm(caller))
}

// callMockUnDelegate exercises unDelegate on an isolated mock store.
func callMockUnDelegate(cur realm, gs *govStakerV1, delegator, delegatee address, amount int64) int64 {
	setGovStakerProxyRealm(delegator)
	var result int64
	func(cur realm) {
		var err error
		result, err = gs.unDelegate(
			0,
			cur,
			delegator,
			delegatee,
			amount,
			runtime.ChainHeight(),
			time.Now().Unix(),
		)
		if err != nil {
			panic(err)
		}
	}(cross(cur))
	return result
}

func callMockUnDelegateValidated(cur realm, gs *govStakerV1, delegator, delegatee address, amount int64) int64 {
	assertTestAddress(delegatee)
	assertIsValidDelegateAmount(amount)
	return callMockUnDelegate(cur, gs, delegator, delegatee, amount)
}

func callMockRedelegate(cur realm, gs *govStakerV1, delegator, delegatee, newDelegatee address, amount int64) int64 {
	setGovStakerProxyRealm(delegator)
	var result int64
	func(cur realm) {
		currentHeight := runtime.ChainHeight()
		currentTimestamp := time.Now().Unix()

		unDelegationAmount, err := gs.unDelegateWithoutLockup(
			0,
			cur,
			delegator,
			delegatee,
			amount,
			currentHeight,
			currentTimestamp,
		)
		if err != nil {
			panic(err)
		}

		_, err = gs.delegate(
			0,
			cur,
			delegator,
			newDelegatee,
			unDelegationAmount,
			currentHeight,
			currentTimestamp,
		)
		if err != nil {
			panic(err)
		}

		result = amount
	}(cross(cur))
	return result
}

func callMockRedelegateValidated(cur realm, gs *govStakerV1, delegator, delegatee, newDelegatee address, amount int64) int64 {
	assertTestAddress(delegatee)
	assertTestAddress(newDelegatee)
	assertIsValidDelegateAmount(amount)
	assertNoSameDelegatee(delegatee, newDelegatee)
	return callMockRedelegate(cur, gs, delegator, delegatee, newDelegatee, amount)
}

func assertTestAddress(addr address) {
	if addr == "" {
		panic("invalid address: ")
	}
}

func callMockCollectUndelegatedGns(cur realm, gs *govStakerV1, caller address, collectTime int64) int64 {
	setGovStakerProxyRealm(caller)
	var result int64
	func(cur realm) {
		var err error
		result, err = gs.collectDelegations(0, cur, caller, collectTime)
		if err != nil {
			panic(err)
		}
		if result > 0 {
			if err := gs.decreaseTotalLockedAmount(0, cur, result); err != nil {
				panic(err)
			}
		}
	}(cross(cur))
	return result
}
