package common

import (
	"std"
	"testing"

	"gno.land/p/demo/testutils"
	"gno.land/p/demo/uassert"

	prbac "gno.land/p/gnoswap/rbac"
	"gno.land/r/gnoswap/v1/access"
)

var (
	addr01 = testutils.TestAddress("addr01")
	addr02 = testutils.TestAddress("addr02")

	// Test role addresses
	testAdminAddr     = testutils.TestAddress("admin")
	testGovAddr       = testutils.TestAddress("governance")
	testGovStakerAddr = testutils.TestAddress("govstaker")
	testRouterAddr    = testutils.TestAddress("router")
	testPositionAddr  = testutils.TestAddress("position")
	testPoolAddr      = testutils.TestAddress("pool")
	testStakerAddr    = testutils.TestAddress("staker")
	testLaunchpadAddr = testutils.TestAddress("launchpad")
	testEmissionAddr  = testutils.TestAddress("emission")
)

func TestAccess_AssertCaller(t *testing.T) {
	tests := []struct {
		name             string
		caller           std.Address
		expectedAddr     std.Address
		expectedHasError bool
	}{
		{
			name:             "Success - same caller",
			caller:           addr01,
			expectedAddr:     addr01,
			expectedHasError: false,
		},
		{
			name:             "Error - different caller",
			caller:           addr01,
			expectedAddr:     addr02,
			expectedHasError: true,
		},
		{
			name:             "Success - zero addresses",
			caller:           std.Address(""),
			expectedAddr:     std.Address(""),
			expectedHasError: false,
		},
		{
			name:             "Error - caller zero expected non-zero",
			caller:           std.Address(""),
			expectedAddr:     addr01,
			expectedHasError: true,
		},
		{
			name:             "Error - expected zero caller non-zero",
			caller:           addr01,
			expectedAddr:     std.Address(""),
			expectedHasError: true,
		},
	}

	for _, tc := range tests {
		t.Run(tc.name, func(t *testing.T) {
			// given
			// Setup is already done in test case

			// when
			err := AssertCaller(tc.caller, tc.expectedAddr)

			// then
			if tc.expectedHasError {
				uassert.Error(t, err)
			} else {
				uassert.NoError(t, err)
			}
		})
	}
}

func TestAccess_SatisfyCond(t *testing.T) {
	tests := []struct {
		name             string
		condition        bool
		expectedHasError bool
	}{
		{
			name:             "Success - true condition",
			condition:        true,
			expectedHasError: false,
		},
		{
			name:             "Error - false condition",
			condition:        false,
			expectedHasError: true,
		},
	}

	for _, tc := range tests {
		t.Run(tc.name, func(t *testing.T) {
			// given
			// Setup is already done in test case

			// when
			err := SatisfyCond(tc.condition)

			// then
			if tc.expectedHasError {
				uassert.Error(t, err)
			} else {
				uassert.NoError(t, err)
			}
		})
	}
}

func TestAccess_IsAuthorized(t *testing.T) {
	tests := []struct {
		name               string
		role               prbac.SystemRole
		caller             std.Address
		expectedAuthorized bool
	}{
		{
			name:               "Success - authorized admin",
			role:               prbac.ROLE_ADMIN,
			caller:             testAdminAddr,
			expectedAuthorized: true,
		},
		{
			name:               "Fail - unauthorized user for admin role",
			role:               prbac.ROLE_ADMIN,
			caller:             addr01,
			expectedAuthorized: false,
		},
		{
			name:               "Success - authorized governance",
			role:               prbac.ROLE_GOVERNANCE,
			caller:             testGovAddr,
			expectedAuthorized: true,
		},
		{
			name:               "Fail - unauthorized user for governance role",
			role:               prbac.ROLE_GOVERNANCE,
			caller:             addr01,
			expectedAuthorized: false,
		},
		{
			name:               "Success - authorized router",
			role:               prbac.ROLE_ROUTER,
			caller:             testRouterAddr,
			expectedAuthorized: true,
		},
		{
			name:               "Fail - cross-role authorization check (admin for governance)",
			role:               prbac.ROLE_GOVERNANCE,
			caller:             testAdminAddr,
			expectedAuthorized: false,
		},
		{
			name:               "Fail - cross-role authorization check (governance for admin)",
			role:               prbac.ROLE_ADMIN,
			caller:             testGovAddr,
			expectedAuthorized: false,
		},
		{
			name:               "Fail - zero address",
			role:               prbac.ROLE_ADMIN,
			caller:             std.Address(""),
			expectedAuthorized: false,
		},
		{
			name:               "Success - authorized gov staker",
			role:               prbac.ROLE_GOV_STAKER,
			caller:             testGovStakerAddr,
			expectedAuthorized: true,
		},
		{
			name:               "Success - authorized position",
			role:               prbac.ROLE_POSITION,
			caller:             testPositionAddr,
			expectedAuthorized: true,
		},
		{
			name:               "Success - authorized pool",
			role:               prbac.ROLE_POOL,
			caller:             testPoolAddr,
			expectedAuthorized: true,
		},
		{
			name:               "Success - authorized staker",
			role:               prbac.ROLE_STAKER,
			caller:             testStakerAddr,
			expectedAuthorized: true,
		},
		{
			name:               "Success - authorized launchpad",
			role:               prbac.ROLE_LAUNCHPAD,
			caller:             testLaunchpadAddr,
			expectedAuthorized: true,
		},
		{
			name:               "Success - authorized emission",
			role:               prbac.ROLE_EMISSION,
			caller:             testEmissionAddr,
			expectedAuthorized: true,
		},
	}

	for _, tc := range tests {
		t.Run(tc.name, func(t *testing.T) {
			// given
			setupTestRoles()

			// when
			result := IsAuthorized(tc.role, tc.caller)

			// then
			uassert.Equal(t, tc.expectedAuthorized, result)
		})
	}
}

func TestAccess_RequireAuthorized(t *testing.T) {
	tests := []struct {
		name                 string
		role                 prbac.SystemRole
		caller               std.Address
		expectedHasPanic     bool
		expectedPanicMessage string
	}{
		{
			name:             "Success - authorized admin should not panic",
			role:             prbac.ROLE_ADMIN,
			caller:           testAdminAddr,
			expectedHasPanic: false,
		},
		{
			name:                 "Panic - unauthorized user should panic",
			role:                 prbac.ROLE_ADMIN,
			caller:               addr01,
			expectedHasPanic:     true,
			expectedPanicMessage: "caller(" + addr01.String() + ") has no permission",
		},
		{
			name:             "Success - authorized governance should not panic",
			role:             prbac.ROLE_GOVERNANCE,
			caller:           testGovAddr,
			expectedHasPanic: false,
		},
		{
			name:                 "Panic - zero address should panic",
			role:                 prbac.ROLE_ADMIN,
			caller:               std.Address(""),
			expectedHasPanic:     true,
			expectedPanicMessage: "caller() has no permission",
		},
	}

	for _, tc := range tests {
		t.Run(tc.name, func(t *testing.T) {
			// given
			setupTestRoles()

			// when & then
			if tc.expectedHasPanic {
				uassert.PanicsWithMessage(t, tc.expectedPanicMessage, func() {
					RequireAuthorized(tc.role, tc.caller)
				})
			} else {
				defer func() {
					if r := recover(); r != nil {
						t.Errorf("[%s] unexpected panic: %v", tc.name, r)
					}
				}()
				RequireAuthorized(tc.role, tc.caller)
			}
		})
	}
}

func TestAccess_UserOnly(t *testing.T) {
	tests := []struct {
		name             string
		realm            std.Realm
		expectedHasError bool
	}{
		{
			name:             "Success - caller is user",
			realm:            std.NewUserRealm(addr01),
			expectedHasError: false,
		},
		{
			name:             "Error - caller is not user",
			realm:            std.NewCodeRealm("gno.land/r/realm"),
			expectedHasError: true,
		},
	}

	for _, tc := range tests {
		t.Run(tc.name, func(t *testing.T) {
			// given
			// Setup is already done in test case

			// when
			err := UserOnly(tc.realm)

			// then
			if tc.expectedHasError {
				uassert.Error(t, err)
			} else {
				uassert.NoError(t, err)
			}
		})
	}
}

// setupTestRoles initializes role addresses for testing
func setupTestRoles() {
	roleMap := map[string]std.Address{
		prbac.ROLE_ADMIN.String():      testAdminAddr,
		prbac.ROLE_GOVERNANCE.String(): testGovAddr,
		prbac.ROLE_GOV_STAKER.String(): testGovStakerAddr,
		prbac.ROLE_ROUTER.String():     testRouterAddr,
		prbac.ROLE_POSITION.String():   testPositionAddr,
		prbac.ROLE_POOL.String():       testPoolAddr,
		prbac.ROLE_STAKER.String():     testStakerAddr,
		prbac.ROLE_LAUNCHPAD.String():  testLaunchpadAddr,
		prbac.ROLE_EMISSION.String():   testEmissionAddr,
	}

	// Set up the test realm context to mimic RBAC package calling SetRoleAddresses
	testing.SetRealm(std.NewCodeRealm("gno.land/r/gnoswap/v1/rbac"))
	access.SetRoleAddresses(cross, roleMap)
}
