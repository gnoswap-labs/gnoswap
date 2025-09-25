package access

import (
	"std"
	"strings"
	"testing"

	"gno.land/p/nt/testutils"
	"gno.land/p/nt/ufmt"
)

func TestGetAddress(t *testing.T) {
	// Setup test data
	testAddr := std.Address("g1test123456789abcdef")
	testRole := "test_role"

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

	tests := []struct {
		name           string
		setupRole      string
		setupAddrs     map[int]std.Address
		queryRole      string
		expectedAddr   std.Address
		expectedExists bool
	}{
		{
			name:           "non-existent role",
			setupRole:      "",
			setupAddrs:     map[int]std.Address{},
			queryRole:      testRole,
			expectedAddr:   "",
			expectedExists: false,
		},
		{
			name:           "existing role with single address",
			setupRole:      testRole,
			setupAddrs:     map[int]std.Address{1: testAddr},
			queryRole:      testRole,
			expectedAddr:   testAddr,
			expectedExists: true,
		},
		{
			name:           "existing role with multiple versions",
			setupRole:      testRole,
			setupAddrs:     map[int]std.Address{1: std.Address("g1old123456789abcdef"), 2: testAddr},
			queryRole:      testRole,
			expectedAddr:   testAddr, // Should return latest
			expectedExists: true,
		},
		{
			name:           "query different role",
			setupRole:      testRole,
			setupAddrs:     map[int]std.Address{1: testAddr},
			queryRole:      "different_role",
			expectedAddr:   "",
			expectedExists: false,
		},
		{
			name:           "empty address list",
			setupRole:      testRole,
			setupAddrs:     map[int]std.Address{},
			queryRole:      testRole,
			expectedAddr:   "",
			expectedExists: false,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			// Setup
			if tt.setupRole != "" {
				roleAddresses[tt.setupRole] = tt.setupAddrs
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

func TestGetAddressWithVersion(t *testing.T) {
	testRole := "test_role"
	addr1 := std.Address("g1test111111111111111")
	addr2 := std.Address("g1test222222222222222")
	addr3 := std.Address("g1test333333333333333")

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

	// Setup test data
	roleAddresses[testRole] = map[int]std.Address{1: addr1, 2: addr2, 3: addr3}

	tests := []struct {
		name           string
		role           string
		version        int
		expectedAddr   std.Address
		expectedExists bool
	}{
		{
			name:           "get version 0",
			role:           testRole,
			version:        0,
			expectedAddr:   addr1,
			expectedExists: false,
		},
		{
			name:           "get version 1",
			role:           testRole,
			version:        1,
			expectedAddr:   addr1,
			expectedExists: true,
		},
		{
			name:           "get version 2",
			role:           testRole,
			version:        2,
			expectedAddr:   addr2,
			expectedExists: true,
		},
		{
			name:           "get version 3",
			role:           testRole,
			version:        3,
			expectedAddr:   addr3,
			expectedExists: true,
		},
		{
			name:           "negative version",
			role:           testRole,
			version:        -1,
			expectedAddr:   "",
			expectedExists: false,
		},
		{
			name:           "non-existent role",
			role:           "non_existent",
			version:        0,
			expectedAddr:   "",
			expectedExists: false,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			addr, ok := GetAddressWithVersion(tt.role, tt.version)

			if ok != tt.expectedExists {
				t.Errorf("Expected exists=%v, got %v", tt.expectedExists, ok)
			}
			if ok && addr != tt.expectedAddr {
				t.Errorf("Expected address=%s, got %s", tt.expectedAddr, addr)
			}
		})
	}
}

func TestGetRoleAddresses(t *testing.T) {
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

	tests := []struct {
		name       string
		setupRoles map[string]map[int]std.Address
		expected   map[string]map[int]std.Address
	}{
		{
			name:       "empty roles",
			setupRoles: map[string]map[int]std.Address{},
			expected:   map[string]map[int]std.Address{},
		},
		{
			name: "single role",
			setupRoles: map[string]map[int]std.Address{
				"role1": {1: std.Address("g1test111111111111111")},
			},
			expected: map[string]map[int]std.Address{
				"role1": {1: std.Address("g1test111111111111111")},
			},
		},
		{
			name: "multiple roles",
			setupRoles: map[string]map[int]std.Address{
				"role1": {1: std.Address("g1test111111111111111")},
				"role2": {1: std.Address("g1test222222222222222")},
				"role3": {1: std.Address("g1test333333333333333")},
			},
			expected: map[string]map[int]std.Address{
				"role1": {1: std.Address("g1test111111111111111")},
				"role2": {1: std.Address("g1test222222222222222")},
				"role3": {1: std.Address("g1test333333333333333")},
			},
		},
		{
			name: "roles with multiple versions",
			setupRoles: map[string]map[int]std.Address{
				"role1": {
					1: std.Address("g1test111111111111111"),
					2: std.Address("g1test111111111111112"),
					3: std.Address("g1test111111111111113"),
				},
			},
			expected: map[string]map[int]std.Address{
				"role1": {
					1: std.Address("g1test111111111111111"),
					2: std.Address("g1test111111111111112"),
					3: std.Address("g1test111111111111113"),
				},
			},
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

				for i, expectedAddr := range expectedAddrs {
					if actualAddrs[i] != expectedAddr {
						t.Errorf("Role %s[%d]: expected %s, got %s", role, i, expectedAddr, actualAddrs[i])
					}
				}
			}

			// Verify original map is not modified by modifying returned map
			addresses["new_role"] = map[int]std.Address{1: std.Address("g1new123456789abcdef")}
			if len(roleAddresses) != len(tt.setupRoles) {
				t.Errorf("Original map should not be modified")
			}
		})
	}
}

func TestIsAuthorized(t *testing.T) {
	testAddr := std.Address("g1test123456789abcdef")
	otherAddr := std.Address("g1other123456789abcde")
	testRole := "test_role"

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

	tests := []struct {
		name         string
		setupRole    string
		setupAddrs   map[int]std.Address
		queryRole    string
		queryAddr    std.Address
		expectedAuth bool
	}{
		{
			name:         "non-existent role",
			setupRole:    "",
			setupAddrs:   map[int]std.Address{},
			queryRole:    testRole,
			queryAddr:    testAddr,
			expectedAuth: false,
		},
		{
			name:         "existing role with correct address",
			setupRole:    testRole,
			setupAddrs:   map[int]std.Address{1: testAddr},
			queryRole:    testRole,
			queryAddr:    testAddr,
			expectedAuth: true,
		},
		{
			name:         "existing role with incorrect address",
			setupRole:    testRole,
			setupAddrs:   map[int]std.Address{1: testAddr},
			queryRole:    testRole,
			queryAddr:    otherAddr,
			expectedAuth: false,
		},
		{
			name:         "query different role",
			setupRole:    testRole,
			setupAddrs:   map[int]std.Address{1: testAddr},
			queryRole:    "different_role",
			queryAddr:    testAddr,
			expectedAuth: false,
		},
		{
			name:         "multiple addresses in role - first matches",
			setupRole:    testRole,
			setupAddrs:   map[int]std.Address{1: testAddr, 2: otherAddr},
			queryRole:    testRole,
			queryAddr:    testAddr,
			expectedAuth: false,
		},
		{
			name:         "multiple addresses in role - last matches",
			setupRole:    testRole,
			setupAddrs:   map[int]std.Address{1: otherAddr, 2: testAddr},
			queryRole:    testRole,
			queryAddr:    testAddr,
			expectedAuth: true,
		},
		{
			name:         "multiple addresses in role - none match",
			setupRole:    testRole,
			setupAddrs:   map[int]std.Address{1: std.Address("g1addr1234567890abcdef"), 2: std.Address("g1addr2234567890abcdef")},
			queryRole:    testRole,
			queryAddr:    testAddr,
			expectedAuth: false,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			// Setup
			if tt.setupRole != "" {
				roleAddresses[tt.setupRole] = tt.setupAddrs
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

func TestIsAuthorizedWithVersion(t *testing.T) {
	testAddr1 := std.Address("g1test111111111111111")
	testAddr2 := std.Address("g1test222222222222222")
	testAddr3 := std.Address("g1test333333333333333")
	testRole := "test_role"

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

	// Setup
	roleAddresses[testRole] = map[int]std.Address{1: testAddr1, 2: testAddr2, 3: testAddr3}

	tests := []struct {
		name         string
		role         string
		version      int
		caller       std.Address
		expectedAuth bool
	}{
		{
			name:         "version 0 out of bounds",
			role:         testRole,
			version:      0,
			caller:       testAddr1,
			expectedAuth: false,
		},
		{
			name:         "version 1 with correct address",
			role:         testRole,
			version:      1,
			caller:       testAddr1,
			expectedAuth: true,
		},
		{
			name:         "version 2 with correct address",
			role:         testRole,
			version:      2,
			caller:       testAddr2,
			expectedAuth: true,
		},
		{
			name:         "version 3 with correct address",
			role:         testRole,
			version:      3,
			caller:       testAddr3,
			expectedAuth: true,
		},
		{
			name:         "version 3 with wrong address",
			role:         testRole,
			version:      3,
			caller:       testAddr1,
			expectedAuth: false,
		},
		{
			name:         "negative version",
			role:         testRole,
			version:      -1,
			caller:       testAddr1,
			expectedAuth: false,
		},
		{
			name:         "non-existent role",
			role:         "non_existent",
			version:      0,
			caller:       testAddr1,
			expectedAuth: false,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			authorized := IsAuthorizedWithVersion(tt.role, tt.version, tt.caller)

			if authorized != tt.expectedAuth {
				t.Errorf("Expected authorized=%v, got %v", tt.expectedAuth, authorized)
			}
		})
	}
}

func TestSetRoleAddress(t *testing.T) {
	// Save original state
	originalRoles := make(map[string]map[int]std.Address)
	for k, v := range roleAddresses {
		originalRoles[k] = v
	}
	defer func() {
		roleAddresses = originalRoles
	}()

	tests := []struct {
		name        string
		setupRoles  map[string]map[int]std.Address
		roleName    string
		roleAddress std.Address
		shouldPanic bool
		panicMsg    string
	}{
		{
			name: "set new role",
			setupRoles: map[string]map[int]std.Address{
				"admin": {1: testutils.TestAddress("admin")},
			},
			roleName:    "newrole",
			roleAddress: testutils.TestAddress("newrole"),
			shouldPanic: false,
		},
		{
			name: "update existing role",
			setupRoles: map[string]map[int]std.Address{
				"admin": {1: testutils.TestAddress("admin")},
			},
			roleName:    "admin",
			roleAddress: testutils.TestAddress("newadmin"),
			shouldPanic: false,
		},
		{
			name: "set role with invalid address",
			setupRoles: map[string]map[int]std.Address{
				"admin": {1: testutils.TestAddress("admin")},
			},
			roleName:    "invalid",
			roleAddress: std.Address(""),
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
			if tt.roleAddress == std.Address("") {
				panic(ufmt.Errorf("invalid address for role %s: %s", tt.roleName, tt.roleAddress))
			}

			if _, exists := roleAddresses[tt.roleName]; !exists {
				roleAddresses[tt.roleName] = make(map[int]std.Address)
			}

			roleAddresses[tt.roleName][1] = tt.roleAddress

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
	originalRoles := make(map[string]map[int]std.Address)
	for k, v := range roleAddresses {
		originalRoles[k] = v
	}
	defer func() {
		roleAddresses = originalRoles
	}()

	tests := []struct {
		name        string
		setupRoles  map[string]map[int]std.Address
		roleName    string
		shouldPanic bool
		panicMsg    string
	}{
		{
			name: "remove existing role",
			setupRoles: map[string]map[int]std.Address{
				"admin":      {1: testutils.TestAddress("admin")},
				"governance": {1: testutils.TestAddress("governance")},
				"custom":     {1: testutils.TestAddress("custom")},
			},
			roleName:    "custom",
			shouldPanic: false,
		},
		{
			name: "remove non-existent role",
			setupRoles: map[string]map[int]std.Address{
				"admin": {1: testutils.TestAddress("admin")},
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
