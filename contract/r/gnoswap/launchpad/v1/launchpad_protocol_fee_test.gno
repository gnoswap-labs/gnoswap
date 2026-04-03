package v1

import (
	"testing"

	testutils "gno.land/p/nt/testutils/v0"
	uassert "gno.land/p/nt/uassert/v0"
	"gno.land/r/gnoswap/halt"
	_ "gno.land/r/gnoswap/launchpad"
	_ "gno.land/r/gnoswap/rbac"
)

func TestLaunchpadProtocolFee_CollectProtocolFee(t *testing.T) {
	userWithoutProject := testutils.TestAddress("user_no_project")

	tests := []struct {
		name                 string
		setupFunc            func()
		callerAddress        address
		callerIsUser         bool
		expectedHasPanic     bool
		expectedPanicMessage string
	}{
		{
			name: "panic when user has no project",
			setupFunc: func() {
				resetTestStore()
			},
			callerAddress:        userWithoutProject,
			callerIsUser:         true,
			expectedHasPanic:     true,
			expectedPanicMessage: "is not the owner of any project",
		},
		{
			name: "panic when caller is not user",
			setupFunc: func() {
				resetTestStore()
			},
			callerAddress:        testutils.TestAddress("contract"),
			callerIsUser:         false,
			expectedHasPanic:     true,
			expectedPanicMessage: "caller is not user",
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			// Setup
			tt.setupFunc()
			impl := getTestImplementation()

			// Set realm for the test
			if tt.callerIsUser {
				testing.SetRealm(testing.NewUserRealm(tt.callerAddress))
			} else {
				testing.SetRealm(testing.NewCodeRealm("gno.land/r/test/contract"))
			}

			// Execute
			collectFn := func() {
				func(cur realm) {
					impl.CollectProtocolFee()
				}(cross)
			}

			if tt.expectedHasPanic {
				uassert.AbortsContains(t, tt.expectedPanicMessage, collectFn)
				return
			}

			// No panic case
			collectFn()
		})
	}
}

// TestEmergencyHaltAllowsCollectProtocolFee verifies that launchpad protocol-fee
// collection is allowed during emergency, consistent with other withdrawal paths.
func TestEmergencyHaltAllowsCollectProtocolFee(t *testing.T) {
	launchpadAddr, adminRealm := setupTestEnvironment(t, testEnvConfig{initialTime: 9000000})
	lp := getTestImplementation()
	projectOwner := testutils.TestAddress("project_owner")

	projectID := createTestProject(t, lp, launchpadAddr, adminRealm, testProjectConfig{
		name:            "Emergency Allow Test Project",
		rewardAmount:    1_000_000,
		recipientSuffix: "project_owner",
		tier30Pct:       10,
		tier90Pct:       30,
		tier180Pct:      60,
	})

	// A deposit must exist so that gov/staker has a registered project wallet.
	createTestDeposit(t, lp, launchpadAddr, adminRealm, projectID, testDepositConfig{
		userSuffix:    "depositor1",
		depositAmount: 1_000_000_000,
		tier:          30,
	})

	testing.SetRealm(adminRealm)
	halt.SetHaltLevel(cross, halt.HaltLevelEmergency)
	defer func() {
		testing.SetRealm(adminRealm)
		halt.SetHaltLevel(cross, halt.HaltLevelNone)
	}()

	uassert.True(t, halt.IsHaltedLaunchpad(), "emergency should halt launchpad operations")
	uassert.True(t, halt.IsHaltedGovStaker(), "emergency should halt gov_staker operations")
	uassert.False(t, halt.IsHaltedWithdraw(), "emergency should keep withdraw enabled")

	testing.SetRealm(testing.NewUserRealm(projectOwner))
	uassert.NotPanics(t, func() {
		func(cur realm) {
			testing.SetRealm(testing.NewCodeRealm(testLaunchpadPkgPath))
			lp.CollectProtocolFee()
		}(cross)
	})
}
