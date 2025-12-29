package access

import (
	"testing"

	"gno.land/p/nt/testutils"
	"gno.land/p/nt/uassert"
	"gno.land/p/nt/ufmt"
)

func TestGetAddress(t *testing.T) {
	// Setup test data
	testAddr := testutils.TestAddress("test")
	testRole := "test_role"

	// Save original state
	originalRoles := make(map[string]address)
	for k, v := range roleAddresses {
		originalRoles[k] = v
	}
	defer func() {
		roleAddresses = originalRoles
	}()

	tests := []struct {
		name           string
		setupRole      string
		setupAddr      address
		queryRole      string
		expectedAddr   address
		expectedExists bool
	}{
		{
			name:           "non-existent role",
			setupRole:      "",
			setupAddr:      address(""),
			queryRole:      testRole,
			expectedAddr:   "",
			expectedExists: false,
		},
		{
			name:           "existing role with single address",
			setupRole:      testRole,
			setupAddr:      testAddr,
			queryRole:      testRole,
			expectedAddr:   testAddr,
			expectedExists: true,
		},
		{
			name:           "query different role",
			setupRole:      testRole,
			setupAddr:      testAddr,
			queryRole:      "different_role",
			expectedAddr:   "",
			expectedExists: false,
		},
		{
			name:           "empty address list",
			setupRole:      "",
			setupAddr:      address(""),
			queryRole:      testRole,
			expectedAddr:   "",
			expectedExists: false,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			roleAddresses = make(map[string]address)

			// Setup
			if tt.setupRole != "" {
				roleAddresses[tt.setupRole] = tt.setupAddr
			}

			// Test
			addr, ok := GetAddress(tt.queryRole)

			// Verify
			if ok != tt.expectedExists {
				t.Errorf("Expected exists=%v, got %v", tt.expectedExists, ok)
			}
			if ok && addr != tt.expectedAddr {
				t.Errorf("Expected address=%s, got %s", tt.expectedAddr, addr)
			}

			// Cleanup
			if tt.setupRole != "" {
				delete(roleAddresses, tt.setupRole)
			}
		})
	}
}

func TestGetRoleAddresses(t *testing.T) {
	// Save original state
	originalRoles := make(map[string]address)
	for k, v := range roleAddresses {
		originalRoles[k] = v
	}
	defer func() {
		roleAddresses = originalRoles
	}()

	tests := []struct {
		name       string
		setupRoles map[string]address
		expected   map[string]address
	}{
		{
			name:       "empty roles",
			setupRoles: map[string]address{},
			expected:   map[string]address{},
		},
		{
			name: "single role",
			setupRoles: map[string]address{
				"role1": testutils.TestAddress("role1"),
			},
			expected: map[string]address{
				"role1": testutils.TestAddress("role1"),
			},
		},
		{
			name: "multiple roles",
			setupRoles: map[string]address{
				"role1": testutils.TestAddress("role1"),
				"role2": testutils.TestAddress("role2"),
				"role3": testutils.TestAddress("role3"),
			},
			expected: map[string]address{
				"role1": testutils.TestAddress("role1"),
				"role2": testutils.TestAddress("role2"),
				"role3": testutils.TestAddress("role3"),
			},
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
			addresses := GetRoleAddresses()

			// Verify length
			if len(addresses) != len(tt.expected) {
				t.Errorf("Expected %d roles, got %d", len(tt.expected), len(addresses))
			}

			// Verify each address array
			for role, expectedAddrs := range tt.expected {
				actualAddrs, exists := addresses[role]
				uassert.True(t, exists, "Expected role %s to exist", role)

				uassert.True(t, len(actualAddrs) == len(expectedAddrs),
				    ufmt.Sprintf("Role %s: expected %d addresses, got %d", role, len(expectedAddrs), len(actualAddrs)))

				uassert.True(t, actualAddrs == expectedAddrs,
				    ufmt.Sprintf("Role %s: expected %s, got %s", role, expectedAddrs, actualAddrs))
			}

			// Verify original map is not modified by modifying returned map
			addresses["new_role"] = testutils.TestAddress("new")

			uassert.True(t, len(roleAddresses) == len(tt.setupRoles),
			    ufmt.Sprintf("Original map should not be modified, expected %d, got %d", len(tt.setupRoles), len(roleAddresses)))
		})
	}
}

func TestIsAuthorized(t *testing.T) {
	testAddr := testutils.TestAddress("test")
	otherAddr := testutils.TestAddress("other")
	testRole := "test_role"

	// Save original state
	originalRoles := make(map[string]address)
	for k, v := range roleAddresses {
		originalRoles[k] = v
	}
	defer func() {
		roleAddresses = originalRoles
	}()

	tests := []struct {
		name         string
		setupRole    string
		setupAddr    address
		queryRole    string
		queryAddr    address
		expectedAuth bool
	}{
		{
			name:         "non-existent role",
			setupRole:    "",
			setupAddr:    address(""),
			queryRole:    testRole,
			queryAddr:    testAddr,
			expectedAuth: false,
		},
		{
			name:         "existing role with correct address",
			setupRole:    testRole,
			setupAddr:    testAddr,
			queryRole:    testRole,
			queryAddr:    testAddr,
			expectedAuth: true,
		},
		{
			name:         "existing role with incorrect address",
			setupRole:    testRole,
			setupAddr:    testAddr,
			queryRole:    testRole,
			queryAddr:    otherAddr,
			expectedAuth: false,
		},
		{
			name:         "query different role",
			setupRole:    testRole,
			setupAddr:    testAddr,
			queryRole:    "different_role",
			queryAddr:    testAddr,
			expectedAuth: false,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			// Reset state at start of each test case
			roleAddresses = make(map[string]address)

			if tt.setupRole != "" {
				roleAddresses[tt.setupRole] = tt.setupAddr
			}

			authorized := IsAuthorized(tt.queryRole, tt.queryAddr)

			uassert.True(t, authorized == tt.expectedAuth,
			    ufmt.Sprintf("Expected authorized=%v, got %v", tt.expectedAuth, authorized))
		})
	}
}

func TestSetRoleAddress(t *testing.T) {
	// Save original state
	originalRoles := make(map[string]address)
	for k, v := range roleAddresses {
		originalRoles[k] = v
	}
	defer func() {
		roleAddresses = originalRoles
	}()

	tests := []struct {
		name        string
		realmPath   string
		userRealm   bool
		userAddr    address
		setupRoles  map[string]address
		roleName    string
		roleAddress address
		shouldAbort bool
		abortMsg    string
	}{
		{
			name:        "set new role",
			realmPath:   rbacPackagePath,
			setupRoles:  map[string]address{},
			roleName:    "newrole",
			roleAddress: testutils.TestAddress("newrole"),
			shouldAbort: false,
		},
		{
			name:      "update existing role",
			realmPath: rbacPackagePath,
			setupRoles: map[string]address{
				"admin": testutils.TestAddress("admin"),
			},
			roleName:    "admin",
			roleAddress: testutils.TestAddress("newadmin"),
			shouldAbort: false,
		},
		{
			name:        "set role with empty address",
			realmPath:   rbacPackagePath,
			setupRoles:  map[string]address{},
			roleName:    "invalid",
			roleAddress: address(""),
			shouldAbort: true,
			abortMsg:    "invalid address for role invalid",
		},
		{
			name:        "set role with invalid address format",
			realmPath:   rbacPackagePath,
			setupRoles:  map[string]address{},
			roleName:    "invalid",
			roleAddress: address("invalid_addr"),
			shouldAbort: true,
			abortMsg:    "invalid address for role invalid",
		},
		{
			name:        "unauthorized caller",
			realmPath:   "gno.land/r/demo/unauthorized",
			setupRoles:  map[string]address{},
			roleName:    "newrole",
			roleAddress: testutils.TestAddress("newrole"),
			shouldAbort: true,
			abortMsg:    "unauthorized",
		},
		{
			name:        "unauthorized user realm",
			userRealm:   true,
			userAddr:    testutils.TestAddress("user"),
			setupRoles:  map[string]address{},
			roleName:    "newrole",
			roleAddress: testutils.TestAddress("newrole"),
			shouldAbort: true,
			abortMsg:    "unauthorized",
		},
		{
			name:        "empty role name",
			realmPath:   rbacPackagePath,
			setupRoles:  map[string]address{},
			roleName:    "",
			roleAddress: testutils.TestAddress("valid"),
			shouldAbort: true,
			abortMsg:    "role name cannot be empty",
		},
		{
			name:        "whitespace role name",
			realmPath:   rbacPackagePath,
			setupRoles:  map[string]address{},
			roleName:    "  ",
			roleAddress: testutils.TestAddress("valid"),
			shouldAbort: true,
			abortMsg:    "role name cannot be empty",
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			// Setup initial roles
			roleAddresses = make(map[string]address)
			for k, v := range tt.setupRoles {
				roleAddresses[k] = v
			}

			// Set realm for this test case
			if tt.userRealm {
				testing.SetRealm(testing.NewUserRealm(tt.userAddr))
			} else {
				testing.SetRealm(testing.NewCodeRealm(tt.realmPath))
			}

			if tt.shouldAbort {
				uassert.AbortsContains(t, tt.abortMsg, func() {
					SetRoleAddress(cross, tt.roleName, tt.roleAddress)
				})
			} else {
				SetRoleAddress(cross, tt.roleName, tt.roleAddress)
				addr, ok := GetAddress(tt.roleName)
				uassert.True(t, ok, ufmt.Sprintf("Role %s should exist after set", tt.roleName))
				uassert.True(t, addr == tt.roleAddress, ufmt.Sprintf("Expected %s for role %s, got %s", tt.roleAddress, tt.roleName, addr))
			}
		})
	}
}

func TestRemoveRole(t *testing.T) {
	// Save original state
	originalRoles := make(map[string]address)
	for k, v := range roleAddresses {
		originalRoles[k] = v
	}
	defer func() {
		roleAddresses = originalRoles
	}()

	tests := []struct {
		name        string
		realmPath   string
		userRealm   bool
		userAddr    address
		setupRoles  map[string]address
		roleName    string
		shouldAbort bool
		abortMsg    string
	}{
		{
			name:      "remove existing role",
			realmPath: rbacPackagePath,
			setupRoles: map[string]address{
				"admin":      testutils.TestAddress("admin"),
				"governance": testutils.TestAddress("governance"),
				"custom":     testutils.TestAddress("custom"),
			},
			roleName:    "custom",
			shouldAbort: false,
		},
		{
			name:      "remove non-existent role",
			realmPath: rbacPackagePath,
			setupRoles: map[string]address{
				"admin": testutils.TestAddress("admin"),
			},
			roleName:    "nonexistent",
			shouldAbort: true,
			abortMsg:    "role nonexistent does not exist",
		},
		{
			name:      "unauthorized caller",
			realmPath: "gno.land/r/demo/unauthorized",
			setupRoles: map[string]address{
				"existing": testutils.TestAddress("existing"),
			},
			roleName:    "existing",
			shouldAbort: true,
			abortMsg:    "unauthorized",
		},
		{
			name:      "unauthorized user realm",
			userRealm: true,
			userAddr:  testutils.TestAddress("user"),
			setupRoles: map[string]address{
				"existing": testutils.TestAddress("existing"),
			},
			roleName:    "existing",
			shouldAbort: true,
			abortMsg:    "unauthorized",
		},
		{
			name:      "empty role name",
			realmPath: rbacPackagePath,
			setupRoles: map[string]address{
				"existing": testutils.TestAddress("existing"),
			},
			roleName:    "",
			shouldAbort: true,
			abortMsg:    "role name cannot be empty",
		},
		{
			name:      "whitespace role name",
			realmPath: rbacPackagePath,
			setupRoles: map[string]address{
				"existing": testutils.TestAddress("existing"),
			},
			roleName:    "  ",
			shouldAbort: true,
			abortMsg:    "role name cannot be empty",
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			// Setup roles
			roleAddresses = make(map[string]address)
			for k, v := range tt.setupRoles {
				roleAddresses[k] = v
			}

			// Set realm for this test case
			if tt.userRealm {
				testing.SetRealm(testing.NewUserRealm(tt.userAddr))
			} else {
				testing.SetRealm(testing.NewCodeRealm(tt.realmPath))
			}

			if tt.shouldAbort {
				uassert.AbortsContains(t, tt.abortMsg, func() {
					RemoveRole(cross, tt.roleName)
				})
			} else {
				RemoveRole(cross, tt.roleName)
				_, ok := GetAddress(tt.roleName)
				uassert.False(t, ok, ufmt.Sprintf("Role %s should not exist after removal", tt.roleName))
			}
		})
	}
}

func TestAccess_MustGetAddress(t *testing.T) {
	testRole := "test_role"
	testAddr := testutils.TestAddress("test")

	// Save original state
	originalRoles := make(map[string]address)
	for k, v := range roleAddresses {
		originalRoles[k] = v
	}
	defer func() {
		roleAddresses = originalRoles
	}()

	tests := []struct {
		name         string
		setupRole    string
		setupAddr    address
		queryRole    string
		expectedAddr address
		shouldPanic  bool
		panicMsg     string
	}{
		{
			name:         "existing role returns address",
			setupRole:    testRole,
			setupAddr:    testAddr,
			queryRole:    testRole,
			expectedAddr: testAddr,
			shouldPanic:  false,
		},
		{
			name:        "non-existent role panics",
			setupRole:   testRole,
			setupAddr:   testAddr,
			queryRole:   "nonexistent",
			shouldPanic: true,
			panicMsg:    "role nonexistent not found",
		},
		{
			name:        "empty role map panics",
			setupRole:   "",
			setupAddr:   address(""),
			queryRole:   testRole,
			shouldPanic: true,
			panicMsg:    "not found",
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			// Setup
			roleAddresses = make(map[string]address)
			if tt.setupRole != "" {
				roleAddresses[tt.setupRole] = tt.setupAddr
			}

			if tt.shouldPanic {
			    uassert.PanicsContains(t, tt.panicMsg, func() {
							MustGetAddress(tt.queryRole)
				})
			} else {
				addr := MustGetAddress(tt.queryRole)
				uassert.True(t, addr == tt.expectedAddr,
				    ufmt.Sprintf("Expected address=%s, got %s", tt.expectedAddr, addr))
			}
		})
	}
}
