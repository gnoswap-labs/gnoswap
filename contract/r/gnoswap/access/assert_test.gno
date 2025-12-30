package access

import (
	"chain"
	"chain/runtime"
	"testing"

	"gno.land/p/nt/testutils"
	"gno.land/p/nt/uassert"
	"gno.land/p/nt/ufmt"

	prbac "gno.land/p/gnoswap/rbac"
)

func TestAssertIsAdminOrGovernance(t *testing.T) {
	// Save original state
	originalRoles := make(map[string]address)
	for k, v := range roleAddresses {
		originalRoles[k] = v
	}
	defer func() {
		roleAddresses = originalRoles
	}()

	adminAddr := testutils.TestAddress("admin")
	govAddr := testutils.TestAddress("governance")
	unauthorizedAddr := testutils.TestAddress("unauthorized")

	tests := []struct {
		name        string
		setupRoles  map[string]address
		testAddr    address
		shouldPanic bool
		expectedMsg string
	}{
		{
			name: "admin should pass",
			setupRoles: map[string]address{
				prbac.ROLE_ADMIN.String():      adminAddr,
				prbac.ROLE_GOVERNANCE.String(): govAddr,
			},
			testAddr:    adminAddr,
			shouldPanic: false,
		},
		{
			name: "governance should pass",
			setupRoles: map[string]address{
				prbac.ROLE_ADMIN.String():      adminAddr,
				prbac.ROLE_GOVERNANCE.String(): govAddr,
			},
			testAddr:    govAddr,
			shouldPanic: false,
		},
		{
			name: "unauthorized should panic",
			setupRoles: map[string]address{
				prbac.ROLE_ADMIN.String():      adminAddr,
				prbac.ROLE_GOVERNANCE.String(): govAddr,
			},
			testAddr:    unauthorizedAddr,
			shouldPanic: true,
			expectedMsg: "unauthorized: caller " + unauthorizedAddr.String() + " is not admin or governance",
		},
		{
			name:        "no roles set should panic",
			setupRoles:  map[string]address{},
			testAddr:    adminAddr,
			shouldPanic: true,
			expectedMsg: "unauthorized: caller " + adminAddr.String() + " is not admin or governance",
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			// Setup
			roleAddresses = make(map[string]address)
			for role, addrs := range tt.setupRoles {
				roleAddresses[role] = addrs
			}

			// Test
			if tt.shouldPanic {
				uassert.PanicsWithMessage(t, tt.expectedMsg, func() {
					AssertIsAdminOrGovernance(tt.testAddr)
				})
			} else {
				uassert.NotPanics(t, func() {
					AssertIsAdminOrGovernance(tt.testAddr)
				})
			}
		})
	}
}

func TestAssertFunctions(t *testing.T) {
	// Save original state
	originalRoles := make(map[string]address)
	for k, v := range roleAddresses {
		originalRoles[k] = v
	}
	defer func() {
		roleAddresses = originalRoles
	}()

	// Test addresses
	adminAddr := testutils.TestAddress("admin")
	govAddr := testutils.TestAddress("governance")
	routerAddr := testutils.TestAddress("router")
	poolAddr := testutils.TestAddress("pool")
	positionAddr := testutils.TestAddress("position")
	stakerAddr := testutils.TestAddress("staker")
	launchpadAddr := testutils.TestAddress("launchpad")
	emissionAddr := testutils.TestAddress("emission")
	protocolFeeAddr := testutils.TestAddress("protocolfee")
	xgnsAddr := testutils.TestAddress("xgns")
	govStakerAddr := testutils.TestAddress("govstaker")
	unauthorizedAddr := testutils.TestAddress("unauthorized")

	tests := []struct {
		name           string
		assertFunc     func(address)
		role           string
		authorizedAddr address
		testCases      []struct {
			name        string
			testAddr    address
			shouldPanic bool
		}
	}{
		{
			name:           "AssertIsAdmin",
			assertFunc:     AssertIsAdmin,
			role:           prbac.ROLE_ADMIN.String(),
			authorizedAddr: adminAddr,
			testCases: []struct {
				name        string
				testAddr    address
				shouldPanic bool
			}{
				{"authorized admin", adminAddr, false},
				{"unauthorized address", unauthorizedAddr, true},
			},
		},
		{
			name:           "AssertIsGovernance",
			assertFunc:     AssertIsGovernance,
			role:           prbac.ROLE_GOVERNANCE.String(),
			authorizedAddr: govAddr,
			testCases: []struct {
				name        string
				testAddr    address
				shouldPanic bool
			}{
				{"authorized governance", govAddr, false},
				{"unauthorized address", unauthorizedAddr, true},
			},
		},
		{
			name:           "AssertIsRouter",
			assertFunc:     AssertIsRouter,
			role:           prbac.ROLE_ROUTER.String(),
			authorizedAddr: routerAddr,
			testCases: []struct {
				name        string
				testAddr    address
				shouldPanic bool
			}{
				{"authorized router", routerAddr, false},
				{"unauthorized address", unauthorizedAddr, true},
			},
		},
		{
			name:           "AssertIsPool",
			assertFunc:     AssertIsPool,
			role:           prbac.ROLE_POOL.String(),
			authorizedAddr: poolAddr,
			testCases: []struct {
				name        string
				testAddr    address
				shouldPanic bool
			}{
				{"authorized pool", poolAddr, false},
				{"unauthorized address", unauthorizedAddr, true},
			},
		},
		{
			name:           "AssertIsPosition",
			assertFunc:     AssertIsPosition,
			role:           prbac.ROLE_POSITION.String(),
			authorizedAddr: positionAddr,
			testCases: []struct {
				name        string
				testAddr    address
				shouldPanic bool
			}{
				{"authorized position", positionAddr, false},
				{"unauthorized address", unauthorizedAddr, true},
			},
		},
		{
			name:           "AssertIsStaker",
			assertFunc:     AssertIsStaker,
			role:           prbac.ROLE_STAKER.String(),
			authorizedAddr: stakerAddr,
			testCases: []struct {
				name        string
				testAddr    address
				shouldPanic bool
			}{
				{"authorized staker", stakerAddr, false},
				{"unauthorized address", unauthorizedAddr, true},
			},
		},
		{
			name:           "AssertIsLaunchpad",
			assertFunc:     AssertIsLaunchpad,
			role:           prbac.ROLE_LAUNCHPAD.String(),
			authorizedAddr: launchpadAddr,
			testCases: []struct {
				name        string
				testAddr    address
				shouldPanic bool
			}{
				{"authorized launchpad", launchpadAddr, false},
				{"unauthorized address", unauthorizedAddr, true},
			},
		},
		{
			name:           "AssertIsEmission",
			assertFunc:     AssertIsEmission,
			role:           prbac.ROLE_EMISSION.String(),
			authorizedAddr: emissionAddr,
			testCases: []struct {
				name        string
				testAddr    address
				shouldPanic bool
			}{
				{"authorized emission", emissionAddr, false},
				{"unauthorized address", unauthorizedAddr, true},
			},
		},
		{
			name:           "AssertIsProtocolFee",
			assertFunc:     AssertIsProtocolFee,
			role:           prbac.ROLE_PROTOCOL_FEE.String(),
			authorizedAddr: protocolFeeAddr,
			testCases: []struct {
				name        string
				testAddr    address
				shouldPanic bool
			}{
				{"authorized protocol fee", protocolFeeAddr, false},
				{"unauthorized address", unauthorizedAddr, true},
			},
		},
		{
			name:           "AssertIsGovXGNS",
			assertFunc:     AssertIsGovXGNS,
			role:           prbac.ROLE_XGNS.String(),
			authorizedAddr: xgnsAddr,
			testCases: []struct {
				name        string
				testAddr    address
				shouldPanic bool
			}{
				{"authorized xgns", xgnsAddr, false},
				{"unauthorized address", unauthorizedAddr, true},
			},
		},
		{
			name:           "AssertIsGovStaker",
			assertFunc:     AssertIsGovStaker,
			role:           prbac.ROLE_GOV_STAKER.String(),
			authorizedAddr: govStakerAddr,
			testCases: []struct {
				name        string
				testAddr    address
				shouldPanic bool
			}{
				{"authorized gov staker", govStakerAddr, false},
				{"unauthorized address", unauthorizedAddr, true},
			},
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			// Setup role - now using []std.Address
			roleAddresses = make(map[string]address)
			roleAddresses[tt.role] = tt.authorizedAddr

			for _, tc := range tt.testCases {
				if tc.shouldPanic {
					expectedMsg := "unauthorized: caller " + tc.testAddr.String() + " is not " + tt.role
					uassert.PanicsWithMessage(t, expectedMsg, func() {
						tt.assertFunc(tc.testAddr)
					})
				} else {
					uassert.NotPanics(t, func() {
						tt.assertFunc(tc.testAddr)
					})
				}
			}
		})
	}
}

func TestAssertIsAuthorized(t *testing.T) {
	// Save original state
	originalRoles := make(map[string]address)
	for k, v := range roleAddresses {
		originalRoles[k] = v
	}
	defer func() {
		roleAddresses = originalRoles
	}()

	authorizedAddr := testutils.TestAddress("authorized")
	unauthorizedAddr := testutils.TestAddress("unauthorized")
	testRole := "test_role"

	tests := []struct {
		name        string
		setupRoles  map[string]address
		testRole    string
		testAddr    address
		shouldPanic bool
		expectedMsg string
	}{
		{
			name:        "non-existent role should panic",
			setupRoles:  map[string]address{},
			testRole:    testRole,
			testAddr:    authorizedAddr,
			shouldPanic: true,
			expectedMsg: "role test_role not found",
		},
		{
			name: "authorized address should pass",
			setupRoles: map[string]address{
				testRole: authorizedAddr,
			},
			testRole:    testRole,
			testAddr:    authorizedAddr,
			shouldPanic: false,
		},
		{
			name: "unauthorized address should panic",
			setupRoles: map[string]address{
				testRole: authorizedAddr,
			},
			testRole:    testRole,
			testAddr:    unauthorizedAddr,
			shouldPanic: true,
			expectedMsg: "unauthorized: caller " + unauthorizedAddr.String() + " is not " + testRole,
		},
		{
			name: "wrong role should panic",
			setupRoles: map[string]address{
				"different_role": authorizedAddr,
			},
			testRole:    "wrong_role",
			testAddr:    authorizedAddr,
			shouldPanic: true,
			expectedMsg: "role wrong_role not found",
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			// Setup
			roleAddresses = make(map[string]address)
			for role, addrs := range tt.setupRoles {
				roleAddresses[role] = addrs
			}

			// Test
			if tt.shouldPanic {
				uassert.PanicsWithMessage(t, tt.expectedMsg, func() {
					AssertIsAuthorized(tt.testRole, tt.testAddr)
				})
			} else {
				uassert.NotPanics(t, func() {
					AssertIsAuthorized(tt.testRole, tt.testAddr)
				})
			}
		})
	}
}

func TestAssertHasAnyRole(t *testing.T) {
	// Save original state
	originalRoles := make(map[string]address)
	for k, v := range roleAddresses {
		originalRoles[k] = v
	}
	defer func() {
		roleAddresses = originalRoles
	}()

	adminAddr := testutils.TestAddress("admin")
	routerAddr := testutils.TestAddress("router")
	unauthorizedAddr := testutils.TestAddress("unauthorized")
	poolAddr := testutils.TestAddress("pool")

	tests := []struct {
		name        string
		setupRoles  map[string]address
		testAddr    address
		roleNames   []string
		shouldPanic bool
		expectedMsg string
	}{
		{
			name: "has one of the roles",
			setupRoles: map[string]address{
				prbac.ROLE_ADMIN.String():  adminAddr,
				prbac.ROLE_ROUTER.String(): routerAddr,
				prbac.ROLE_POOL.String():   poolAddr,
			},
			testAddr:    adminAddr,
			roleNames:   []string{prbac.ROLE_ADMIN.String(), prbac.ROLE_ROUTER.String()},
			shouldPanic: false,
		},
		{
			name: "has different role in list",
			setupRoles: map[string]address{
				prbac.ROLE_ADMIN.String():  adminAddr,
				prbac.ROLE_ROUTER.String(): routerAddr,
				prbac.ROLE_POOL.String():   poolAddr,
			},
			testAddr:    routerAddr,
			roleNames:   []string{prbac.ROLE_ADMIN.String(), prbac.ROLE_ROUTER.String()},
			shouldPanic: false,
		},
		{
			name: "has none of the roles",
			setupRoles: map[string]address{
				prbac.ROLE_ADMIN.String():  adminAddr,
				prbac.ROLE_ROUTER.String(): routerAddr,
				prbac.ROLE_POOL.String():   poolAddr,
			},
			testAddr:    unauthorizedAddr,
			roleNames:   []string{prbac.ROLE_ADMIN.String(), prbac.ROLE_ROUTER.String()},
			shouldPanic: true,
			expectedMsg: ufmt.Sprintf("unauthorized: caller %s is not any of the roles %v", unauthorizedAddr.String(), []string{prbac.ROLE_ADMIN.String(), prbac.ROLE_ROUTER.String()}),
		},
		{
			name:        "role does not exist",
			setupRoles:  map[string]address{},
			testAddr:    adminAddr,
			roleNames:   []string{"non_existent_role"},
			shouldPanic: true,
			expectedMsg: "role non_existent_role not found",
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			// Setup
			roleAddresses = make(map[string]address)
			for role, addrs := range tt.setupRoles {
				roleAddresses[role] = addrs
			}

			// Test
			if tt.shouldPanic {
				uassert.PanicsWithMessage(t, tt.expectedMsg, func() {
					AssertHasAnyRole(tt.testAddr, tt.roleNames...)
				})
			} else {
				uassert.NotPanics(t, func() {
					AssertHasAnyRole(tt.testAddr, tt.roleNames...)
				})
			}
		})
	}
}

func TestAssertHasAnyRole_EdgeCases(t *testing.T) {
	// Save original state
	originalRoles := make(map[string]address)
	for k, v := range roleAddresses {
		originalRoles[k] = v
	}
	defer func() {
		roleAddresses = originalRoles
	}()

	adminAddr := testutils.TestAddress("admin")
	routerAddr := testutils.TestAddress("router")

	tests := []struct {
		name        string
		setupRoles  map[string]address
		testAddr    address
		roleNames   []string
		shouldPanic bool
		expectedMsg string
	}{
		{
			name:        "empty role array should panic",
			setupRoles:  map[string]address{},
			testAddr:    adminAddr,
			roleNames:   []string{},
			shouldPanic: true,
			expectedMsg: ufmt.Sprintf("unauthorized: caller %s is not any of the roles %v", adminAddr.String(), []string{}),
		},
		{
			name: "duplicate roles in array - should work",
			setupRoles: map[string]address{
				prbac.ROLE_ADMIN.String(): adminAddr,
			},
			testAddr:    adminAddr,
			roleNames:   []string{prbac.ROLE_ADMIN.String(), prbac.ROLE_ADMIN.String(), prbac.ROLE_ADMIN.String()},
			shouldPanic: false,
		},
		{
			name: "duplicate roles but unauthorized",
			setupRoles: map[string]address{
				prbac.ROLE_ADMIN.String():  adminAddr,
				prbac.ROLE_ROUTER.String(): routerAddr,
			},
			testAddr:    routerAddr,
			roleNames:   []string{prbac.ROLE_ADMIN.String(), prbac.ROLE_ADMIN.String()},
			shouldPanic: true,
			expectedMsg: ufmt.Sprintf("unauthorized: caller %s is not any of the roles %v", routerAddr.String(), []string{prbac.ROLE_ADMIN.String(), prbac.ROLE_ADMIN.String()}),
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			// Setup
			roleAddresses = make(map[string]address)
			for role, addrs := range tt.setupRoles {
				roleAddresses[role] = addrs
			}

			// Test
			if tt.shouldPanic {
				uassert.PanicsWithMessage(t, tt.expectedMsg, func() {
					AssertHasAnyRole(tt.testAddr, tt.roleNames...)
				})
			} else {
				uassert.NotPanics(t, func() {
					AssertHasAnyRole(tt.testAddr, tt.roleNames...)
				})
			}
		})
	}
}

func TestAssertIsAuthorized_EdgeCases(t *testing.T) {
	// Save original state
	originalRoles := make(map[string]address)
	for k, v := range roleAddresses {
		originalRoles[k] = v
	}
	defer func() {
		roleAddresses = originalRoles
	}()

	authorizedAddr := testutils.TestAddress("authorized")

	unauthorizedAddr := testutils.TestAddress("unauthorized")

	tests := []struct {
		name        string
		setupRoles  map[string]address
		testRole    string
		testAddr    address
		shouldPanic bool
		expectedMsg string
	}{
		{
			name:        "empty string role name should panic",
			setupRoles:  map[string]address{},
			testRole:    "",
			testAddr:    authorizedAddr,
			shouldPanic: true,
			expectedMsg: "role  not found",
		},
		{
			name: "role exists but caller address doesn't match",
			setupRoles: map[string]address{
				"admin": authorizedAddr,
			},
			testRole:    "admin",
			testAddr:    unauthorizedAddr,
			shouldPanic: true,
			expectedMsg: "unauthorized: caller " + unauthorizedAddr.String() + " is not admin",
		},
		{
			name: "role exists and caller address matches",
			setupRoles: map[string]address{
				"admin": authorizedAddr,
			},
			testRole:    "admin",
			testAddr:    authorizedAddr,
			shouldPanic: false,
		},
		{
			name: "role with special characters doesn't exist",
			setupRoles: map[string]address{
				"admin": authorizedAddr,
			},
			testRole:    "admin!@#$",
			testAddr:    authorizedAddr,
			shouldPanic: true,
			expectedMsg: "role admin!@#$ not found",
		},
		{
			name: "empty address with existing role",
			setupRoles: map[string]address{
				"admin": authorizedAddr,
			},
			testRole:    "admin",
			testAddr:    address(""),
			shouldPanic: true,
			expectedMsg: "unauthorized: caller " + address("").String() + " is not admin",
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			// Setup
			roleAddresses = make(map[string]address)
			for role, addrs := range tt.setupRoles {
				roleAddresses[role] = addrs
			}

			// Test
			if tt.shouldPanic {
				uassert.PanicsWithMessage(t, tt.expectedMsg, func() {
					AssertIsAuthorized(tt.testRole, tt.testAddr)
				})
			} else {
				uassert.NotPanics(t, func() {
					AssertIsAuthorized(tt.testRole, tt.testAddr)
				})
			}
		})
	}
}

func TestAssertIsValidAddress(t *testing.T) {
	tests := []struct {
		name        string
		addr        address
		shouldPanic bool
		expectedMsg string
	}{
		{
			name:        "valid address",
			addr:        address("g1manfred47kzduec920z88wfr64ylksmdcedlf5"),
			shouldPanic: false,
		},
		{
			name:        "empty address",
			addr:        address(""),
			shouldPanic: true,
			expectedMsg: "invalid address: ",
		},
		{
			name:        "invalid address format",
			addr:        address("invalid"),
			shouldPanic: true,
			expectedMsg: "invalid address: invalid",
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			if tt.shouldPanic {
				uassert.PanicsWithMessage(t, tt.expectedMsg, func() {
					AssertIsValidAddress(tt.addr)
				})
			} else {
				uassert.NotPanics(t, func() {
					AssertIsValidAddress(tt.addr)
				})
			}
		})
	}
}

func TestAssertIsUser(t *testing.T) {
	tests := []struct {
		name        string
		realm       runtime.Realm
		shouldPanic bool
		expectedMsg string
	}{
		{
			name:        "user realm",
			realm:       testing.NewUserRealm(testutils.TestAddress("user")),
			shouldPanic: false,
		},
		{
			name:        "code realm",
			realm:       testing.NewCodeRealm("gno.land/r/demo/example"),
			shouldPanic: true,
			expectedMsg: "caller is not user",
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			if tt.shouldPanic {
				uassert.PanicsWithMessage(t, tt.expectedMsg, func() {
					AssertIsUser(tt.realm)
				})
			} else {
				uassert.NotPanics(t, func() {
					AssertIsUser(tt.realm)
				})
			}
		})
	}
}

func TestAssert_assertIsRBAC(t *testing.T) {
	rbacAddress := chain.PackageAddress("gno.land/r/gnoswap/rbac")
	unauthorizedAddr := testutils.TestAddress("unauthorized")

	tests := []struct {
		name        string
		caller      address
		shouldPanic bool
	}{
		{"rbac package address", rbacAddress, false},
		{"unauthorized address", unauthorizedAddr, true},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			if tt.shouldPanic {
				expectedMsg := ufmt.Sprintf("unauthorized: caller %s is not rbac", tt.caller.String())
				uassert.PanicsWithMessage(t, expectedMsg, func() {
					assertIsRBAC(tt.caller)
				})
			} else {
				uassert.NotPanics(t, func() {
					assertIsRBAC(tt.caller)
				})
			}
		})
	}
}
