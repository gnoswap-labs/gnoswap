package v1

import (
	"testing"

	"gno.land/p/nt/testutils"
	"gno.land/p/nt/uassert"
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
