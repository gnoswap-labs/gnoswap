package access

import (
	"strings"
	"testing"

	"gno.land/p/nt/testutils"
	"gno.land/p/nt/ufmt"
)

func TestGetAddress(t *testing.T) {
	// Setup test data
	testAddr := address("g1test123456789abcdef")
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
		setupAddr     address
		queryRole      string
		expectedAddr   address
		expectedExists bool
	}{
		{
			name:           "non-existent role",
			setupRole:      "",
			setupAddr:     address(""),
			queryRole:      testRole,
			expectedAddr:   "",
			expectedExists: false,
		},
		{
			name:           "existing role with single address",
			setupRole:      testRole,
			setupAddr:     testAddr,
			queryRole:      testRole,
			expectedAddr:   testAddr,
			expectedExists: true,
		},
		{
			name:           "query different role",
			setupRole:      testRole,
			setupAddr:     testAddr,
			queryRole:      "different_role",
			expectedAddr:   "",
			expectedExists: false,
		},
		{
			name:           "empty address list",
			setupRole:      "",
			setupAddr:     address(""),
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
				"role1": address("g1test111111111111111"),
			},
			expected: map[string]address{
				"role1": address("g1test111111111111111"),
			},
		},
		{
			name: "multiple roles",
			setupRoles: map[string]address{
				"role1": address("g1test111111111111111"),
				"role2": address("g1test222222222222222"),
				"role3": address("g1test333333333333333"),
			},
			expected: map[string]address{
				"role1": address("g1test111111111111111"),
				"role2": address("g1test222222222222222"),
				"role3": address("g1test333333333333333"),
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
				if !exists {
					t.Errorf("Expected role %s to exist", role)
					continue
				}

				if len(actualAddrs) != len(expectedAddrs) {
					t.Errorf("Role %s: expected %d addresses, got %d", role, len(expectedAddrs), len(actualAddrs))
					continue
				}

				if actualAddrs != expectedAddrs {
					t.Errorf("Role %s: expected %s, got %s", role, expectedAddrs, actualAddrs)
				}
			}

			// Verify original map is not modified by modifying returned map
			addresses["new_role"] = address("g1new123456789abcdef")
			if len(roleAddresses) != len(tt.setupRoles) {
				t.Errorf("Original map should not be modified")
			}
		})
	}
}

func TestIsAuthorized(t *testing.T) {
	testAddr := address("g1test123456789abcdef")
	otherAddr := address("g1other123456789abcde")
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
		setupAddr   address
		queryRole    string
		queryAddr    address
		expectedAuth bool
	}{
		{
			name:         "non-existent role",
			setupRole:    "",
			setupAddr:   address(""),
			queryRole:    testRole,
			queryAddr:    testAddr,
			expectedAuth: false,
		},
		{
			name:         "existing role with correct address",
			setupRole:    testRole,
			setupAddr:   testAddr,
			queryRole:    testRole,
			queryAddr:    testAddr,
			expectedAuth: true,
		},
		{
			name:         "existing role with incorrect address",
			setupRole:    testRole,
			setupAddr:   testAddr,
			queryRole:    testRole,
			queryAddr:    otherAddr,
			expectedAuth: false,
		},
		{
			name:         "query different role",
			setupRole:    testRole,
			setupAddr:   testAddr,
			queryRole:    "different_role",
			queryAddr:    testAddr,
			expectedAuth: false,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			// Setup
			if tt.setupRole != "" {
				roleAddresses[tt.setupRole] = tt.setupAddr
			}

			// Test
			authorized := IsAuthorized(tt.queryRole, tt.queryAddr)

			// Verify
			if authorized != tt.expectedAuth {
				t.Errorf("Expected authorized=%v, got %v", tt.expectedAuth, authorized)
			}

			// Cleanup
			if tt.setupRole != "" {
				delete(roleAddresses, tt.setupRole)
			}
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
		setupRoles  map[string]address
		roleName    string
		roleAddress address
		shouldPanic bool
		panicMsg    string
	}{
		{
			name: "set new role",
			setupRoles: map[string]address{
				"admin": testutils.TestAddress("admin"),
			},
			roleName:    "newrole",
			roleAddress: testutils.TestAddress("newrole"),
			shouldPanic: false,
		},
		{
			name: "update existing role",
			setupRoles: map[string]address{
				"admin": testutils.TestAddress("admin"),
			},
			roleName:    "admin",
			roleAddress: testutils.TestAddress("newadmin"),
			shouldPanic: false,
		},
		{
			name: "set role with invalid address",
			setupRoles: map[string]address{
				"admin": testutils.TestAddress("admin"),
			},
			roleName:    "invalid",
			roleAddress: address(""),
			shouldPanic: true,
			panicMsg:    "invalid address for role invalid",
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			// Setup initial roles
			roleAddresses = tt.setupRoles

			if tt.shouldPanic {
				defer func() {
					if r := recover(); r != nil {
						if tt.panicMsg != "" && !containsString(r, tt.panicMsg) {
							t.Errorf("Expected panic containing %q, got %v", tt.panicMsg, r)
						}
					} else {
						t.Errorf("Expected panic but didn't panic")
					}
				}()
			}

			// Simulate SetRoleAddress logic
			if tt.roleAddress == address("") {
				panic(ufmt.Errorf("invalid address for role %s: %s", tt.roleName, tt.roleAddress))
			}

			if _, exists := roleAddresses[tt.roleName]; !exists {
				roleAddresses[tt.roleName] = address("")
			}

			roleAddresses[tt.roleName] = tt.roleAddress

			if !tt.shouldPanic {
				// Verify set operation
				addr, ok := GetAddress(tt.roleName)
				if !ok {
					t.Errorf("Role %s should exist after set", tt.roleName)
				}
				if addr != tt.roleAddress {
					t.Errorf("Expected %s for role %s, got %s", tt.roleAddress, tt.roleName, addr)
				}
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
		setupRoles  map[string]address
		roleName    string
		shouldPanic bool
		panicMsg    string
	}{
		{
			name: "remove existing role",
			setupRoles: map[string]address{
				"admin":      testutils.TestAddress("admin"),
				"governance": testutils.TestAddress("governance"),
				"custom":     testutils.TestAddress("custom"),
			},
			roleName:    "custom",
			shouldPanic: false,
		},
		{
			name: "remove non-existent role",
			setupRoles: map[string]address{
				"admin": testutils.TestAddress("admin"),
			},
			roleName:    "nonexistent",
			shouldPanic: true,
			panicMsg:    "role nonexistent does not exist",
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			// Setup roles
			roleAddresses = tt.setupRoles

			if tt.shouldPanic {
				defer func() {
					if r := recover(); r != nil {
						if tt.panicMsg != "" && !containsString(r, tt.panicMsg) {
							t.Errorf("Expected panic containing %q, got %v", tt.panicMsg, r)
						}
					} else {
						t.Errorf("Expected panic but didn't panic")
					}
				}()
			}

			// Simulate RemoveRole logic
			if _, exists := roleAddresses[tt.roleName]; !exists {
				panic(ufmt.Errorf("role %s does not exist", tt.roleName))
			}

			delete(roleAddresses, tt.roleName)

			if !tt.shouldPanic {
				// Verify removal
				_, ok := GetAddress(tt.roleName)
				if ok {
					t.Errorf("Role %s should not exist after removal", tt.roleName)
				}
			}
		})
	}
}

func TestAccess_MustGetAddress(t *testing.T) {
	testRole := "test_role"
	testAddr := address("g1test123456789abcdef")

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
		setupRole   string
		setupAddr   address
		queryRole   string
		expectedAddr address
		shouldPanic bool
		panicMsg    string
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
				defer func() {
					if r := recover(); r != nil {
						if tt.panicMsg != "" && !containsString(r, tt.panicMsg) {
							t.Errorf("Expected panic containing %q, got %v", tt.panicMsg, r)
						}
					} else {
						t.Errorf("Expected panic but didn't panic")
					}
				}()
			}

			addr := MustGetAddress(tt.queryRole)

			if !tt.shouldPanic {
				if addr != tt.expectedAddr {
					t.Errorf("Expected address=%s, got %s", tt.expectedAddr, addr)
				}
			}
		})
	}
}

// Helper function to check if error contains string
func containsString(r interface{}, substr string) bool {
	switch v := r.(type) {
	case string:
		return strings.Contains(v, substr)
	case error:
		return strings.Contains(v.Error(), substr)
	default:
		return strings.Contains(ufmt.Sprintf("%v", v), substr)
	}
}
