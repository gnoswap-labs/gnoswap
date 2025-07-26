package access

import (
	"std"
	"testing"

	"gno.land/p/demo/uassert"
	prbac "gno.land/p/gnoswap/rbac"
)

func TestAssertIsAdminOrGovernance(t *testing.T) {
	// Save original state
	originalRoles := make(map[string]std.Address)
	for k, v := range roleAddresses {
		originalRoles[k] = v
	}
	defer func() {
		roleAddresses = originalRoles
	}()

	adminAddr := std.Address("g1admin123456789abcdef")
	govAddr := std.Address("g1governance123456789a")
	unauthorizedAddr := std.Address("g1unauthorized123456789")

	tests := []struct {
		name        string
		setupRoles  map[string]std.Address
		testAddr    std.Address
		shouldPanic bool
		expectedMsg string
	}{
		{
			name: "admin should pass",
			setupRoles: map[string]std.Address{
				prbac.ROLE_ADMIN.String():      adminAddr,
				prbac.ROLE_GOVERNANCE.String(): govAddr,
			},
			testAddr:    adminAddr,
			shouldPanic: false,
		},
		{
			name: "governance should pass",
			setupRoles: map[string]std.Address{
				prbac.ROLE_ADMIN.String():      adminAddr,
				prbac.ROLE_GOVERNANCE.String(): govAddr,
			},
			testAddr:    govAddr,
			shouldPanic: false,
		},
		{
			name: "unauthorized should panic",
			setupRoles: map[string]std.Address{
				prbac.ROLE_ADMIN.String():      adminAddr,
				prbac.ROLE_GOVERNANCE.String(): govAddr,
			},
			testAddr:    unauthorizedAddr,
			shouldPanic: true,
			expectedMsg: "unauthorized: caller " + unauthorizedAddr.String() + " is not admin or governance",
		},
		{
			name:        "no roles set should panic",
			setupRoles:  map[string]std.Address{},
			testAddr:    adminAddr,
			shouldPanic: true,
			expectedMsg: "unauthorized: caller " + adminAddr.String() + " is not admin or governance",
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			// Setup
			roleAddresses = make(map[string]std.Address)
			for role, addr := range tt.setupRoles {
				roleAddresses[role] = addr
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
	originalRoles := make(map[string]std.Address)
	for k, v := range roleAddresses {
		originalRoles[k] = v
	}
	defer func() {
		roleAddresses = originalRoles
	}()

	// Test addresses
	adminAddr := std.Address("g1admin123456789abcdef")
	govAddr := std.Address("g1governance123456789a")
	routerAddr := std.Address("g1router123456789abcdef")
	poolAddr := std.Address("g1pool1234567890abcdef")
	positionAddr := std.Address("g1position123456789abcd")
	stakerAddr := std.Address("g1staker123456789abcdef")
	launchpadAddr := std.Address("g1launchpad123456789ab")
	emissionAddr := std.Address("g1emission123456789abc")
	protocolFeeAddr := std.Address("g1protocolfee123456789")
	xgnsAddr := std.Address("g1xgns1234567890abcdef")
	govStakerAddr := std.Address("g1govstaker123456789ab")
	unauthorizedAddr := std.Address("g1unauthorized123456789")

	tests := []struct {
		name           string
		assertFunc     func(std.Address)
		role           string
		authorizedAddr std.Address
		testCases      []struct {
			name        string
			testAddr    std.Address
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
				testAddr    std.Address
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
				testAddr    std.Address
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
				testAddr    std.Address
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
				testAddr    std.Address
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
				testAddr    std.Address
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
				testAddr    std.Address
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
				testAddr    std.Address
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
				testAddr    std.Address
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
				testAddr    std.Address
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
				testAddr    std.Address
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
				testAddr    std.Address
				shouldPanic bool
			}{
				{"authorized gov staker", govStakerAddr, false},
				{"unauthorized address", unauthorizedAddr, true},
			},
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			// Setup role
			roleAddresses = make(map[string]std.Address)
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
	originalRoles := make(map[string]std.Address)
	for k, v := range roleAddresses {
		originalRoles[k] = v
	}
	defer func() {
		roleAddresses = originalRoles
	}()

	authorizedAddr := std.Address("g1authorized12345678ab")
	unauthorizedAddr := std.Address("g1unauthorized123456789")
	testRole := "test_role"

	tests := []struct {
		name        string
		setupRoles  map[string]std.Address
		testRole    string
		testAddr    std.Address
		shouldPanic bool
		expectedMsg string
	}{
		{
			name:        "non-existent role should panic",
			setupRoles:  map[string]std.Address{},
			testRole:    testRole,
			testAddr:    authorizedAddr,
			shouldPanic: true,
			expectedMsg: "role test_role does not exist",
		},
		{
			name: "authorized address should pass",
			setupRoles: map[string]std.Address{
				testRole: authorizedAddr,
			},
			testRole:    testRole,
			testAddr:    authorizedAddr,
			shouldPanic: false,
		},
		{
			name: "unauthorized address should panic",
			setupRoles: map[string]std.Address{
				testRole: authorizedAddr,
			},
			testRole:    testRole,
			testAddr:    unauthorizedAddr,
			shouldPanic: true,
			expectedMsg: "unauthorized: caller " + unauthorizedAddr.String() + " is not " + testRole,
		},
		{
			name: "wrong role should panic",
			setupRoles: map[string]std.Address{
				testRole: authorizedAddr,
			},
			testRole:    "wrong_role",
			testAddr:    authorizedAddr,
			shouldPanic: true,
			expectedMsg: "role wrong_role does not exist",
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			// Setup
			roleAddresses = make(map[string]std.Address)
			for role, addr := range tt.setupRoles {
				roleAddresses[role] = addr
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

func TestAssertIsRBAC(t *testing.T) {
	rbacAddr := std.NewCodeRealm("gno.land/r/gnoswap/v1/rbac").Address()
	unauthorizedAddr := std.Address("g1unauthorized123456789")

	tests := []struct {
		name        string
		testAddr    std.Address
		shouldPanic bool
		expectedMsg string
	}{
		{
			name:        "rbac address should pass",
			testAddr:    rbacAddr,
			shouldPanic: false,
		},
		{
			name:        "unauthorized address should panic",
			testAddr:    unauthorizedAddr,
			shouldPanic: true,
			expectedMsg: "unauthorized: caller " + unauthorizedAddr.String() + " is not rbac",
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			if tt.shouldPanic {
				uassert.PanicsWithMessage(t, tt.expectedMsg, func() {
					assertIsRBAC(tt.testAddr)
				})
			} else {
				uassert.NotPanics(t, func() {
					assertIsRBAC(tt.testAddr)
				})
			}
		})
	}
}
