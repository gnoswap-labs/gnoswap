package access

import (
	"std"
	"testing"

	"gno.land/p/nt/uassert"
	"gno.land/p/nt/ufmt"

	prbac "gno.land/p/gnoswap/rbac"
)

func TestAssertIsAdminOrGovernance(t *testing.T) {
	// Save original state
	originalRoles := make(map[string]map[int]std.Address)
	for k, v := range roleAddresses {
		addressCopy := make(map[int]std.Address)
		for k, v := range v {
			addressCopy[k] = v
		}
		originalRoles[k] = addressCopy
	}
	defer func() {
		roleAddresses = originalRoles
	}()

	adminAddr := std.Address("g1admin123456789abcdef")
	govAddr := std.Address("g1governance123456789a")
	unauthorizedAddr := std.Address("g1unauthorized123456789")

	tests := []struct {
		name        string
		setupRoles  map[string]map[int]std.Address
		testAddr    std.Address
		shouldPanic bool
		expectedMsg string
	}{
		{
			name: "admin should pass",
			setupRoles: map[string]map[int]std.Address{
				prbac.ROLE_ADMIN.String():      map[int]std.Address{1: adminAddr},
				prbac.ROLE_GOVERNANCE.String(): map[int]std.Address{1: govAddr},
			},
			testAddr:    adminAddr,
			shouldPanic: false,
		},
		{
			name: "governance should pass",
			setupRoles: map[string]map[int]std.Address{
				prbac.ROLE_ADMIN.String():      map[int]std.Address{1: adminAddr},
				prbac.ROLE_GOVERNANCE.String(): map[int]std.Address{1: govAddr},
			},
			testAddr:    govAddr,
			shouldPanic: false,
		},
		{
			name: "unauthorized should panic",
			setupRoles: map[string]map[int]std.Address{
				prbac.ROLE_ADMIN.String():      map[int]std.Address{1: adminAddr},
				prbac.ROLE_GOVERNANCE.String(): map[int]std.Address{1: govAddr},
			},
			testAddr:    unauthorizedAddr,
			shouldPanic: true,
			expectedMsg: "unauthorized: caller " + unauthorizedAddr.String() + " is not admin or governance",
		},
		{
			name:        "no roles set should panic",
			setupRoles:  map[string]map[int]std.Address{},
			testAddr:    adminAddr,
			shouldPanic: true,
			expectedMsg: "unauthorized: caller " + adminAddr.String() + " is not admin or governance",
		},
		{
			name: "admin in multiple versions should pass",
			setupRoles: map[string]map[int]std.Address{
				prbac.ROLE_ADMIN.String():      map[int]std.Address{1: std.Address("g1old123456789abcdef"), 2: adminAddr},
				prbac.ROLE_GOVERNANCE.String(): map[int]std.Address{1: govAddr},
			},
			testAddr:    adminAddr,
			shouldPanic: false,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			// Setup
			roleAddresses = make(map[string]map[int]std.Address)
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

func TestAssertIsAdminOrGovernanceWithVersion(t *testing.T) {
	// Save original state
	originalRoles := make(map[string]map[int]std.Address)
	for k, v := range roleAddresses {
		addressCopy := make(map[int]std.Address)
		for k, v := range v {
			addressCopy[k] = v
		}
		originalRoles[k] = addressCopy
	}
	defer func() {
		roleAddresses = originalRoles
	}()

	adminAddr1 := std.Address("g1admin111111111111111")
	adminAddr2 := std.Address("g1admin222222222222222")
	govAddr1 := std.Address("g1gov11111111111111111")
	govAddr2 := std.Address("g1gov22222222222222222")
	unauthorizedAddr := std.Address("g1unauthorized123456789")

	// Setup with multiple versions
	roleAddresses[prbac.ROLE_ADMIN.String()] = map[int]std.Address{1: adminAddr1, 2: adminAddr2}
	roleAddresses[prbac.ROLE_GOVERNANCE.String()] = map[int]std.Address{1: govAddr1, 2: govAddr2}

	tests := []struct {
		name        string
		version     int
		testAddr    std.Address
		shouldPanic bool
		expectedMsg string
	}{
		{
			name:        "admin version 1 should panic only latest admin address",
			version:     1,
			testAddr:    adminAddr1,
			shouldPanic: true,
			expectedMsg: "unauthorized: caller " + adminAddr1.String() + " is not admin or governance",
		},
		{
			name:        "governance version 1 should pass",
			version:     1,
			testAddr:    govAddr1,
			shouldPanic: false,
		},
		{
			name:        "admin version 2 should pass",
			version:     2,
			testAddr:    adminAddr2,
			shouldPanic: false,
		},
		{
			name:        "governance version 2 should pass",
			version:     2,
			testAddr:    govAddr2,
			shouldPanic: false,
		},
		{
			name:        "wrong version should panic",
			version:     0,
			testAddr:    govAddr2,
			shouldPanic: true,
			expectedMsg: "unauthorized: caller " + govAddr2.String() + " is not admin or governance",
		},
		{
			name:        "unauthorized should panic",
			version:     0,
			testAddr:    unauthorizedAddr,
			shouldPanic: true,
			expectedMsg: "unauthorized: caller " + unauthorizedAddr.String() + " is not admin or governance",
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			if tt.shouldPanic {
				uassert.PanicsWithMessage(t, tt.expectedMsg, func() {
					AssertIsAdminOrGovernanceWithVersion(tt.version, tt.testAddr)
				})
			} else {
				uassert.NotPanics(t, func() {
					AssertIsAdminOrGovernanceWithVersion(tt.version, tt.testAddr)
				})
			}
		})
	}
}

func TestAssertFunctions(t *testing.T) {
	// Save original state
	originalRoles := make(map[string]map[int]std.Address)
	for k, v := range roleAddresses {
		addressCopy := make(map[int]std.Address)
		for k, v := range v {
			addressCopy[k] = v
		}
		originalRoles[k] = addressCopy
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
			// Setup role - now using []std.Address
			roleAddresses = make(map[string]map[int]std.Address)
			roleAddresses[tt.role] = map[int]std.Address{1: tt.authorizedAddr}

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

func TestAssertFunctionsWithVersion(t *testing.T) {
	// Save original state
	originalRoles := make(map[string]map[int]std.Address)
	for k, v := range roleAddresses {
		addressCopy := make(map[int]std.Address)
		for k, v := range v {
			addressCopy[k] = v
		}
		originalRoles[k] = addressCopy
	}
	defer func() {
		roleAddresses = originalRoles
	}()

	// Test with versioned addresses
	routerAddr1 := std.Address("g1router111111111111111")
	routerAddr2 := std.Address("g1router222222222222222")
	poolAddr1 := std.Address("g1pool1111111111111111")
	poolAddr2 := std.Address("g1pool2222222222222222")
	unauthorizedAddr := std.Address("g1unauthorized123456789")

	tests := []struct {
		name             string
		assertFunc       func(int, std.Address)
		role             string
		setupAddrs       map[int]std.Address
		version          int
		testAddr         std.Address
		shouldPanic      bool
		expectedPanicMsg string
	}{
		{
			name:        "AssertIsRouterWithVersion - correct version",
			assertFunc:  AssertIsRouterWithVersion,
			role:        prbac.ROLE_ROUTER.String(),
			setupAddrs:  map[int]std.Address{1: routerAddr1, 2: routerAddr2},
			version:     1,
			testAddr:    routerAddr1,
			shouldPanic: false,
		},
		{
			name:             "AssertIsRouterWithVersion - wrong version",
			assertFunc:       AssertIsRouterWithVersion,
			role:             prbac.ROLE_ROUTER.String(),
			setupAddrs:       map[int]std.Address{1: routerAddr1, 2: routerAddr2},
			version:          1,
			testAddr:         routerAddr2,
			shouldPanic:      true,
			expectedPanicMsg: "unauthorized: caller " + routerAddr2.String() + " is not " + prbac.ROLE_ROUTER.String(),
		},
		{
			name:        "AssertIsPoolWithVersion - correct version",
			assertFunc:  AssertIsPoolWithVersion,
			role:        prbac.ROLE_POOL.String(),
			setupAddrs:  map[int]std.Address{1: poolAddr1, 2: poolAddr2},
			version:     2,
			testAddr:    poolAddr2,
			shouldPanic: false,
		},
		{
			name:             "AssertIsPoolWithVersion - not available version",
			assertFunc:       AssertIsPoolWithVersion,
			role:             prbac.ROLE_POOL.String(),
			setupAddrs:       map[int]std.Address{1: poolAddr1, 2: poolAddr2},
			version:          0,
			testAddr:         unauthorizedAddr,
			shouldPanic:      true,
			expectedPanicMsg: "role pool does not exist",
		},
		{
			name:             "AssertIsPoolWithVersion - not available version",
			assertFunc:       AssertIsPoolWithVersion,
			role:             prbac.ROLE_POOL.String(),
			setupAddrs:       map[int]std.Address{1: poolAddr1, 2: poolAddr2},
			version:          1,
			testAddr:         unauthorizedAddr,
			shouldPanic:      true,
			expectedPanicMsg: "unauthorized: caller " + unauthorizedAddr.String() + " is not " + prbac.ROLE_POOL.String(),
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			// Setup role with versions
			roleAddresses = make(map[string]map[int]std.Address)
			roleAddresses[tt.role] = tt.setupAddrs

			if tt.shouldPanic {
				uassert.PanicsWithMessage(t, tt.expectedPanicMsg, func() {
					tt.assertFunc(tt.version, tt.testAddr)
				})
			} else {
				uassert.NotPanics(t, func() {
					tt.assertFunc(tt.version, tt.testAddr)
				})
			}
		})
	}
}

func TestAssertIsAuthorized(t *testing.T) {
	// Save original state
	originalRoles := make(map[string]map[int]std.Address)
	for k, v := range roleAddresses {
		addressCopy := make(map[int]std.Address)
		for k, v := range v {
			addressCopy[k] = v
		}
		originalRoles[k] = addressCopy
	}
	defer func() {
		roleAddresses = originalRoles
	}()

	authorizedAddr := std.Address("g1authorized12345678ab")
	unauthorizedAddr := std.Address("g1unauthorized123456789")
	testRole := "test_role"

	tests := []struct {
		name        string
		setupRoles  map[string]map[int]std.Address
		testRole    string
		testAddr    std.Address
		shouldPanic bool
		expectedMsg string
	}{
		{
			name:        "non-existent role should panic",
			setupRoles:  map[string]map[int]std.Address{},
			testRole:    testRole,
			testAddr:    authorizedAddr,
			shouldPanic: true,
			expectedMsg: "role test_role does not exist",
		},
		{
			name: "authorized address should pass",
			setupRoles: map[string]map[int]std.Address{
				testRole: map[int]std.Address{1: authorizedAddr},
			},
			testRole:    testRole,
			testAddr:    authorizedAddr,
			shouldPanic: false,
		},
		{
			name: "unauthorized address should panic",
			setupRoles: map[string]map[int]std.Address{
				testRole: map[int]std.Address{1: authorizedAddr},
			},
			testRole:    testRole,
			testAddr:    unauthorizedAddr,
			shouldPanic: true,
			expectedMsg: "unauthorized: caller " + unauthorizedAddr.String() + " is not " + testRole,
		},
		{
			name: "multiple addresses with one authorized",
			setupRoles: map[string]map[int]std.Address{
				testRole: map[int]std.Address{1: unauthorizedAddr, 2: authorizedAddr},
			},
			testRole:    testRole,
			testAddr:    authorizedAddr,
			shouldPanic: false,
		},
		{
			name: "wrong role should panic",
			setupRoles: map[string]map[int]std.Address{
				"different_role": map[int]std.Address{1: authorizedAddr},
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
			roleAddresses = make(map[string]map[int]std.Address)
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

func TestAssertIsAuthorizedWithVersion(t *testing.T) {
	// Save original state
	originalRoles := make(map[string]map[int]std.Address)
	for k, v := range roleAddresses {
		addressCopy := make(map[int]std.Address)
		for k, v := range v {
			addressCopy[k] = v
		}
		originalRoles[k] = addressCopy
	}
	defer func() {
		roleAddresses = originalRoles
	}()

	addr1 := std.Address("g1addr1111111111111111")
	addr2 := std.Address("g1addr2222222222222222")
	addr3 := std.Address("g1addr3333333333333333")
	testRole := "test_role"

	// Setup role with multiple versions
	roleAddresses[testRole] = map[int]std.Address{1: addr1, 2: addr2, 3: addr3}

	tests := []struct {
		name        string
		testRole    string
		version     int
		testAddr    std.Address
		shouldPanic bool
		expectedMsg string
	}{
		{
			name:        "version 1 with correct address",
			testRole:    testRole,
			version:     1,
			testAddr:    addr1,
			shouldPanic: false,
		},
		{
			name:        "version 2 with correct address",
			testRole:    testRole,
			version:     2,
			testAddr:    addr2,
			shouldPanic: false,
		},
		{
			name:        "version 3 with correct address",
			testRole:    testRole,
			version:     3,
			testAddr:    addr3,
			shouldPanic: false,
		},
		{
			name:        "version 1 with wrong address",
			testRole:    testRole,
			version:     1,
			testAddr:    addr2,
			shouldPanic: true,
			expectedMsg: "unauthorized: caller " + addr2.String() + " is not " + testRole,
		},
		{
			name:        "invalid version",
			testRole:    testRole,
			version:     5,
			testAddr:    addr1,
			shouldPanic: true,
			expectedMsg: "role test_role does not exist",
		},
		{
			name:        "non-existent role",
			testRole:    "non_existent",
			version:     0,
			testAddr:    addr1,
			shouldPanic: true,
			expectedMsg: "role non_existent does not exist",
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			if tt.shouldPanic {
				uassert.PanicsWithMessage(t, tt.expectedMsg, func() {
					AssertIsAuthorizedWithVersion(tt.testRole, tt.version, tt.testAddr)
				})
			} else {
				uassert.NotPanics(t, func() {
					AssertIsAuthorizedWithVersion(tt.testRole, tt.version, tt.testAddr)
				})
			}
		})
	}
}

func TestAssertHasAnyRole(t *testing.T) {
	// Save original state
	originalRoles := make(map[string]map[int]std.Address)
	for k, v := range roleAddresses {
		addressCopy := make(map[int]std.Address)
		for k, v := range v {
			addressCopy[k] = v
		}
		originalRoles[k] = addressCopy
	}
	defer func() {
		roleAddresses = originalRoles
	}()

	adminAddr := std.Address("g1admin123456789abcdef")
	routerAddr := std.Address("g1router123456789abcde")
	poolAddr := std.Address("g1pool1234567890abcdef")
	unauthorizedAddr := std.Address("g1unauthorized123456789")

	tests := []struct {
		name        string
		setupRoles  map[string]map[int]std.Address
		testAddr    std.Address
		roleNames   []string
		shouldPanic bool
		expectedMsg string
	}{
		{
			name: "has one of the roles",
			setupRoles: map[string]map[int]std.Address{
				prbac.ROLE_ADMIN.String():  map[int]std.Address{1: adminAddr},
				prbac.ROLE_ROUTER.String(): map[int]std.Address{1: routerAddr},
				prbac.ROLE_POOL.String():   map[int]std.Address{1: poolAddr},
			},
			testAddr:    adminAddr,
			roleNames:   []string{prbac.ROLE_ADMIN.String(), prbac.ROLE_ROUTER.String()},
			shouldPanic: false,
		},
		{
			name: "has different role in list",
			setupRoles: map[string]map[int]std.Address{
				prbac.ROLE_ADMIN.String():  map[int]std.Address{1: adminAddr},
				prbac.ROLE_ROUTER.String(): map[int]std.Address{1: routerAddr},
				prbac.ROLE_POOL.String():   map[int]std.Address{1: poolAddr},
			},
			testAddr:    routerAddr,
			roleNames:   []string{prbac.ROLE_ADMIN.String(), prbac.ROLE_ROUTER.String()},
			shouldPanic: false,
		},
		{
			name: "has none of the roles",
			setupRoles: map[string]map[int]std.Address{
				prbac.ROLE_ADMIN.String():  map[int]std.Address{1: adminAddr},
				prbac.ROLE_ROUTER.String(): map[int]std.Address{1: routerAddr},
				prbac.ROLE_POOL.String():   map[int]std.Address{1: poolAddr},
			},
			testAddr:    unauthorizedAddr,
			roleNames:   []string{prbac.ROLE_ADMIN.String(), prbac.ROLE_ROUTER.String()},
			shouldPanic: true,
			expectedMsg: ufmt.Sprintf("unauthorized: caller %s is not any of the roles %v", unauthorizedAddr.String(), []string{prbac.ROLE_ADMIN.String(), prbac.ROLE_ROUTER.String()}),
		},
		{
			name:        "role does not exist",
			setupRoles:  map[string]map[int]std.Address{},
			testAddr:    adminAddr,
			roleNames:   []string{"non_existent_role"},
			shouldPanic: true,
			expectedMsg: "role non_existent_role does not exist",
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			// Setup
			roleAddresses = make(map[string]map[int]std.Address)
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

func TestAssertHasAnyRoleWithVersion(t *testing.T) {
	// Save original state
	originalRoles := make(map[string]map[int]std.Address)
	for k, v := range roleAddresses {
		addressCopy := make(map[int]std.Address)
		for k, v := range v {
			addressCopy[k] = v
		}
		originalRoles[k] = addressCopy
	}
	defer func() {
		roleAddresses = originalRoles
	}()

	adminAddr1 := std.Address("g1admin111111111111111")
	adminAddr2 := std.Address("g1admin222222222222222")
	routerAddr1 := std.Address("g1router11111111111111")
	routerAddr2 := std.Address("g1router22222222222222")
	unauthorizedAddr := std.Address("g1unauthorized123456789")

	// Setup roles with multiple versions
	roleAddresses[prbac.ROLE_ADMIN.String()] = map[int]std.Address{1: adminAddr1, 2: adminAddr2}
	roleAddresses[prbac.ROLE_ROUTER.String()] = map[int]std.Address{1: routerAddr1, 2: routerAddr2}

	tests := []struct {
		name        string
		version     int
		testAddr    std.Address
		roleNames   []string
		shouldPanic bool
		expectedMsg string
	}{
		{
			name:        "has admin role at version 1",
			version:     1,
			testAddr:    adminAddr1,
			roleNames:   []string{prbac.ROLE_ADMIN.String(), prbac.ROLE_ROUTER.String()},
			shouldPanic: false,
		},
		{
			name:        "has router role at version 2",
			version:     2,
			testAddr:    routerAddr2,
			roleNames:   []string{prbac.ROLE_ADMIN.String(), prbac.ROLE_ROUTER.String()},
			shouldPanic: false,
		},
		{
			name:        "wrong version for address",
			version:     1,
			testAddr:    adminAddr2,
			roleNames:   []string{prbac.ROLE_ADMIN.String(), prbac.ROLE_ROUTER.String()},
			shouldPanic: true,
			expectedMsg: ufmt.Sprintf("unauthorized: caller %s is not any of the roles %v", adminAddr2.String(), []string{prbac.ROLE_ADMIN.String(), prbac.ROLE_ROUTER.String()}),
		},
		{
			name:        "unauthorized address",
			version:     1,
			testAddr:    unauthorizedAddr,
			roleNames:   []string{prbac.ROLE_ADMIN.String(), prbac.ROLE_ROUTER.String()},
			shouldPanic: true,
			expectedMsg: ufmt.Sprintf("unauthorized: caller %s is not any of the roles %v", unauthorizedAddr.String(), []string{prbac.ROLE_ADMIN.String(), prbac.ROLE_ROUTER.String()}),
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			if tt.shouldPanic {
				uassert.PanicsWithMessage(t, tt.expectedMsg, func() {
					AssertHasAnyRoleWithVersion(tt.version, tt.testAddr, tt.roleNames...)
				})
			} else {
				uassert.NotPanics(t, func() {
					AssertHasAnyRoleWithVersion(tt.version, tt.testAddr, tt.roleNames...)
				})
			}
		})
	}
}

func TestAssertIsValidAddress(t *testing.T) {
	tests := []struct {
		name        string
		addr        std.Address
		shouldPanic bool
		expectedMsg string
	}{
		{
			name:        "valid address",
			addr:        std.Address("g1manfred47kzduec920z88wfr64ylksmdcedlf5"),
			shouldPanic: false,
		},
		{
			name:        "empty address",
			addr:        std.Address(""),
			shouldPanic: true,
			expectedMsg: "invalid address: ",
		},
		{
			name:        "invalid address format",
			addr:        std.Address("invalid"),
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
		realm       std.Realm
		shouldPanic bool
		expectedMsg string
	}{
		{
			name:        "user realm",
			realm:       std.NewUserRealm(std.Address("g1user1234567890abcdef")),
			shouldPanic: false,
		},
		{
			name:        "code realm",
			realm:       std.NewCodeRealm("gno.land/r/demo/example"),
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

func TestAssertIsSwapWhitelisted(t *testing.T) {
	// Save original state
	originalWhitelist := make(map[std.Address]bool)
	for k, v := range swapWhitelist {
		originalWhitelist[k] = v
	}
	originalRoles := make(map[string]map[int]std.Address)
	for k, v := range roleAddresses {
		addressCopy := make(map[int]std.Address)
		for k, v := range v {
			addressCopy[k] = v
		}
		originalRoles[k] = addressCopy
	}
	defer func() {
		swapWhitelist = originalWhitelist
		roleAddresses = originalRoles
	}()

	officialRouter := std.Address("g1official12345678abcd")
	whitelistedAddr := std.Address("g1whitelisted123456789a")
	notWhitelistedAddr := std.Address("g1notwhitelisted1234567")

	// Setup
	roleAddresses[prbac.ROLE_ROUTER.String()] = map[int]std.Address{1: officialRouter}
	swapWhitelist[whitelistedAddr] = true

	tests := []struct {
		name        string
		addr        std.Address
		shouldPanic bool
		expectedMsg string
	}{
		{
			name:        "official router",
			addr:        officialRouter,
			shouldPanic: false,
		},
		{
			name:        "whitelisted address",
			addr:        whitelistedAddr,
			shouldPanic: false,
		},
		{
			name:        "not whitelisted address",
			addr:        notWhitelistedAddr,
			shouldPanic: true,
			expectedMsg: ufmt.Sprintf("unauthorized: caller %s is not a whitelisted router", notWhitelistedAddr.String()),
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			if tt.shouldPanic {
				uassert.PanicsWithMessage(t, tt.expectedMsg, func() {
					AssertIsSwapWhitelisted(tt.addr)
				})
			} else {
				uassert.NotPanics(t, func() {
					AssertIsSwapWhitelisted(tt.addr)
				})
			}
		})
	}
}
