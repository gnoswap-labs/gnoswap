package v1

import (
	"testing"
	"time"

	"gno.land/p/nt/testutils"
	"gno.land/p/nt/uassert"

	"gno.land/r/gnoswap/launchpad"
)

func TestAssert_assertIsValidAmount(t *testing.T) {
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
			expectedError: "GNOSWAP-LAUNCHPAD-017",
		},
		{
			name:          "panic when amount is not a multiple of minimum",
			amount:        1_000_001,
			expectedPanic: true,
			expectedError: "GNOSWAP-LAUNCHPAD-017",
		},
		{
			name:          "panic when amount is less than minimum",
			amount:        999_999,
			expectedPanic: true,
			expectedError: "GNOSWAP-LAUNCHPAD-017",
		},
		{
			name:          "panic when amount is zero",
			amount:        0,
			expectedPanic: true,
			expectedError: "GNOSWAP-LAUNCHPAD-017",
		},
		{
			name:          "panic when amount is negative",
			amount:        -1,
			expectedPanic: true,
			expectedError: "GNOSWAP-LAUNCHPAD-017",
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			if tt.expectedPanic {
				uassert.PanicsContains(t, tt.expectedError, func() {
					assertIsValidAmount(tt.amount)
				})
				return
			}

			assertIsValidAmount(tt.amount)
		})
	}
}

func TestAssert_assertIsDepositOwner(t *testing.T) {
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
			expectedError: "GNOSWAP-LAUNCHPAD-020",
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
			expectedError: "GNOSWAP-LAUNCHPAD-026",
		},
		{
			name: "panic when depositID is empty",
			setupDeposit: func(lp *launchpadV1) string {
				return ""
			},
			depositID:     "",
			caller:        ownerAddr,
			expectedPanic: true,
			expectedError: "GNOSWAP-LAUNCHPAD-020",
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			// given
			resetTestStore()
			lp := getTestImplementation()
			depositID := tt.setupDeposit(lp)

			// when & then
			if tt.expectedPanic {
				uassert.PanicsContains(t, tt.expectedError, func() {
					lp.assertIsDepositOwner(depositID, tt.caller)
				})
				return
			}

			lp.assertIsDepositOwner(depositID, tt.caller)
		})
	}
}

func TestAssert_assertHasProject(t *testing.T) {
	projectOwner := testutils.TestAddress("project_owner")
	otherUser := testutils.TestAddress("other_user")

	tests := []struct {
		name          string
		setupProjects func(*launchpadV1)
		caller        address
		expectedPanic bool
		expectedError string
	}{
		{
			name: "valid - caller owns at least one project",
			setupProjects: func(lp *launchpadV1) {
				project := launchpad.NewProject(
					"Test Project",
					"gno.land/r/demo/token",
					1000000,
					projectOwner,
					100,
					time.Now().Unix(),
				)
				projects := lp.store.GetProjects()
				projects.Set(project.ID(), project)
			},
			caller:        projectOwner,
			expectedPanic: false,
		},
		{
			name: "panic when caller owns no project",
			setupProjects: func(lp *launchpadV1) {
				project := launchpad.NewProject(
					"Test Project",
					"gno.land/r/demo/token",
					1000000,
					projectOwner,
					100,
					time.Now().Unix(),
				)
				projects := lp.store.GetProjects()
				projects.Set(project.ID(), project)
			},
			caller:        otherUser,
			expectedPanic: true,
			expectedError: "GNOSWAP-LAUNCHPAD-026",
		},
		{
			name: "panic when projects tree is empty",
			setupProjects: func(lp *launchpadV1) {
				// Don't add any projects
			},
			caller:        otherUser,
			expectedPanic: true,
			expectedError: "GNOSWAP-LAUNCHPAD-026",
		},
		{
			name: "valid - caller owns one of multiple projects",
			setupProjects: func(lp *launchpadV1) {
				projects := lp.store.GetProjects()

				// Add project owned by someone else
				project1 := launchpad.NewProject(
					"Other Project",
					"gno.land/r/demo/token1",
					1000000,
					otherUser,
					100,
					time.Now().Unix(),
				)
				projects.Set(project1.ID(), project1)

				// Add project owned by caller
				project2 := launchpad.NewProject(
					"My Project",
					"gno.land/r/demo/token2",
					1000000,
					projectOwner,
					101,
					time.Now().Unix(),
				)
				projects.Set(project2.ID(), project2)
			},
			caller:        projectOwner,
			expectedPanic: false,
		},
		{
			name: "panic when multiple projects exist but caller owns none",
			setupProjects: func(lp *launchpadV1) {
				projects := lp.store.GetProjects()

				// Add multiple projects owned by others
				for i := 0; i < 3; i++ {
					project := launchpad.NewProject(
						"Other Project",
						"gno.land/r/demo/token",
						1000000,
						otherUser,
						int64(100+i),
						time.Now().Unix(),
					)
					projects.Set(project.ID(), project)
				}
			},
			caller:        projectOwner,
			expectedPanic: true,
			expectedError: "GNOSWAP-LAUNCHPAD-026",
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			// given
			resetTestStore()
			lp := getTestImplementation()
			tt.setupProjects(lp)

			// when & then
			if tt.expectedPanic {
				uassert.PanicsContains(t, tt.expectedError, func() {
					lp.assertHasProject(tt.caller)
				})
				return
			}

			lp.assertHasProject(tt.caller)
		})
	}
}
