package v1

import (
	"chain"
	"testing"
	"time"

	testutils "gno.land/p/nt/testutils/v0"
	uassert "gno.land/p/nt/uassert/v0"

	gov_staker "gno.land/r/gnoswap/gov/staker"
	"gno.land/r/gnoswap/launchpad"
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
			name: "panic when contract has no project",
			setupFunc: func() {
				resetTestStore()
			},
			callerAddress:        testutils.TestAddress("contract"),
			callerIsUser:         false,
			expectedHasPanic:     true,
			expectedPanicMessage: "is not the owner of any project",
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

func TestLaunchpadProtocolFee_CollectProtocolFee_ContractRecipient(t *testing.T) {
	const contractPackagePath = "gno.land/r/test/contract"

	resetTestStore()
	impl := getTestImplementation()
	contractAddr := chain.PackageAddress(contractPackagePath)

	project := launchpad.NewProject(
		"Contract Recipient Project",
		"gno.land/r/demo/token",
		1000000,
		contractAddr,
		100,
		time.Now().Unix(),
	)
	impl.store.GetProjects().Set(project.ID(), project)

	testing.SetRealm(testing.NewCodeRealm(testLaunchpadPkgPath))
	gov_staker.SetAmountByProjectWallet(cross, contractAddr, 1, true)

	testing.SetRealm(testing.NewCodeRealm(contractPackagePath))
	func(cur realm) {
		testing.SetRealm(testing.NewCodeRealm(testLaunchpadPkgPath))
		impl.CollectProtocolFee()
	}(cross)
}
