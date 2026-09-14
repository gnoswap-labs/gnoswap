package launchpad

import (
	"testing"
	"time"

	testutils "gno.land/p/nt/testutils/v0"
	uassert "gno.land/p/nt/uassert/v0"
)

func TestAssert_assertIsValidAmount(cur realm, t *testing.T) {
	tests := []struct {
		name          string
		amount        int64
		expectedPanic bool
		expectedError string
	}{
		{
			name:          "valid amount - exactly minimum",
			amount:        1_000_000,
			expectedPanic: false,
		},
		{
			name:          "valid amount - 10x minimum",
			amount:        10_000_000,
			expectedPanic: false,
		},
		{
			name:          "panic when amount is not a multiple of minimum ",
			amount:        10_000_001,
			expectedPanic: true,
			expectedError: "GNOSWAP-LAUNCHPAD-010",
		},
		{
			name:          "panic when amount is not a multiple of minimum",
			amount:        1_000_001,
			expectedPanic: true,
			expectedError: "GNOSWAP-LAUNCHPAD-010",
		},
		{
			name:          "panic when amount is less than minimum",
			amount:        999_999,
			expectedPanic: true,
			expectedError: "GNOSWAP-LAUNCHPAD-010",
		},
		{
			name:          "panic when amount is zero",
			amount:        0,
			expectedPanic: true,
			expectedError: "GNOSWAP-LAUNCHPAD-010",
		},
		{
			name:          "panic when amount is negative",
			amount:        -1,
			expectedPanic: true,
			expectedError: "GNOSWAP-LAUNCHPAD-010",
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(cur realm, t *testing.T) {
			if tt.expectedPanic {
				uassert.PanicsContains(t, cur, tt.expectedError, func() {
					assertIsValidAmount(tt.amount)
				})
				return
			}

			assertIsValidAmount(tt.amount)
		})
	}
}

func TestAssert_assertIsDepositOwner(cur realm, t *testing.T) {
	ownerAddr := testutils.TestAddress("owner")
	otherAddr := testutils.TestAddress("other")

	tests := []struct {
		name          string
		setupDeposit  func(*launchpadV1) string
		depositID     string
		caller        address
		expectedPanic bool
		expectedError string
	}{
		{
			name: "valid - caller is deposit owner",
			setupDeposit: func(lp *launchpadV1) string {
				// Create a test deposit
				depositID := "test_deposit_1"
				deposit := newDeposit(
					depositID,
					"test_project:100",
					30,
					ownerAddr,
					1000000,
					100,
					time.Now().Unix(),
					time.Now().Unix()+1000,
				)
				deposits := lp.store.GetDeposits()
				deposits.Set(depositID, deposit)
				return depositID
			},
			caller:        ownerAddr,
			expectedPanic: false,
		},
		{
			name: "panic when deposit not found",
			setupDeposit: func(lp *launchpadV1) string {
				return "non_existent_deposit"
			},
			depositID:     "non_existent_deposit",
			caller:        ownerAddr,
			expectedPanic: true,
			expectedError: "GNOSWAP-LAUNCHPAD-012",
		},
		{
			name: "panic when caller is not owner",
			setupDeposit: func(lp *launchpadV1) string {
				depositID := "test_deposit_2"
				deposit := newDeposit(
					depositID,
					"test_project:100",
					30,
					ownerAddr,
					1000000,
					100,
					time.Now().Unix(),
					time.Now().Unix()+1000,
				)
				deposits := lp.store.GetDeposits()
				deposits.Set(depositID, deposit)
				return depositID
			},
			caller:        otherAddr,
			expectedPanic: true,
			expectedError: "GNOSWAP-LAUNCHPAD-014",
		},
		{
			name: "panic when depositID is empty",
			setupDeposit: func(lp *launchpadV1) string {
				return ""
			},
			depositID:     "",
			caller:        ownerAddr,
			expectedPanic: true,
			expectedError: "GNOSWAP-LAUNCHPAD-012",
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(cur realm, t *testing.T) {
			// given
			resetTestStore()
			lp := getTestImplementation()
			depositID := tt.setupDeposit(lp)

			// when & then
			if tt.expectedPanic {
				uassert.PanicsContains(t, cur, tt.expectedError, func() {
					lp.assertIsDepositOwner(depositID, tt.caller)
				})
				return
			}

			lp.assertIsDepositOwner(depositID, tt.caller)
		})
	}
}

func TestAssert_assertHasProject(cur realm, t *testing.T) {
	launchpadAddr, adminRealm := setupTestEnvironment(cur, t, testEnvConfig{})
	lp := getTestImplementation()
	recipient := testutils.TestAddress("project_owner")
	otherRecipient := testutils.TestAddress("other_owner")
	outsider := testutils.TestAddress("non_project_owner")

	uassert.PanicsContains(t, cur, "GNOSWAP-LAUNCHPAD-014", func() {
		lp.assertHasProject(recipient)
	})

	// Creating another project for the same recipient must preserve membership.
	for _, cfg := range []testProjectConfig{
		{name: "First", recipientSuffix: "project_owner", rewardAmount: 1000000, tier30Pct: 100},
		{name: "Shared recipient", recipientSuffix: "project_owner", rewardAmount: 1000000, tier30Pct: 100},
		{name: "Other recipient", recipientSuffix: "other_owner", rewardAmount: 1000000, tier30Pct: 100},
	} {
		createTestProject(cur, t, lp, launchpadAddr, adminRealm, cfg)
		// Reinitializing an implementation must not clear existing recipients.
		uassert.NoError(t, initStoreData(0, cur, lp.store))
		lp.assertHasProject(recipient)
		uassert.PanicsContains(t, cur, "GNOSWAP-LAUNCHPAD-014", func() {
			lp.assertHasProject(outsider)
		})
	}
	lp.assertHasProject(otherRecipient)
}
