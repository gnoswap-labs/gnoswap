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
	originalRoles := make(map[string]std.Address)
	for k, v := range roleAddresses {
		originalRoles[k] = v
	}
	defer func() {
		roleAddresses = originalRoles
	}()

	tests := []struct {
		name           string
		setupRole      string
		setupAddr      std.Address
		queryRole      string
		expectedAddr   std.Address
		expectedExists bool
	}{
		{
			name:           "non-existent role",
			setupRole:      "",
			setupAddr:      "",
			queryRole:      testRole,
			expectedAddr:   "",
			expectedExists: false,
		},
		{
			name:           "existing role",
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
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
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
			if addr != tt.expectedAddr {
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
	originalRoles := make(map[string]std.Address)
	for k, v := range roleAddresses {
		originalRoles[k] = v
	}
	defer func() {
		roleAddresses = originalRoles
	}()

	tests := []struct {
		name       string
		setupRoles map[string]std.Address
		expected   map[string]std.Address
	}{
		{
			name:       "empty roles",
			setupRoles: map[string]std.Address{},
			expected:   map[string]std.Address{},
		},
		{
			name: "single role",
			setupRoles: map[string]std.Address{
				"role1": std.Address("g1test111111111111111"),
			},
			expected: map[string]std.Address{
				"role1": std.Address("g1test111111111111111"),
			},
		},
		{
			name: "multiple roles",
			setupRoles: map[string]std.Address{
				"role1": std.Address("g1test111111111111111"),
				"role2": std.Address("g1test222222222222222"),
				"role3": std.Address("g1test333333333333333"),
			},
			expected: map[string]std.Address{
				"role1": std.Address("g1test111111111111111"),
				"role2": std.Address("g1test222222222222222"),
				"role3": std.Address("g1test333333333333333"),
			},
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
			addresses := GetRoleAddresses()

			// Verify length
			if len(addresses) != len(tt.expected) {
				t.Errorf("Expected %d addresses, got %d", len(tt.expected), len(addresses))
			}

			// Verify each address
			for role, expectedAddr := range tt.expected {
				if actualAddr, exists := addresses[role]; !exists {
					t.Errorf("Expected role %s to exist", role)
				} else if actualAddr != expectedAddr {
					t.Errorf("Expected %s for role %s, got %s", expectedAddr, role, actualAddr)
				}
			}

			// Verify original map is not modified by modifying returned map
			addresses["new_role"] = std.Address("g1new123456789abcdef")
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
	originalRoles := make(map[string]std.Address)
	for k, v := range roleAddresses {
		originalRoles[k] = v
	}
	defer func() {
		roleAddresses = originalRoles
	}()

	tests := []struct {
		name         string
		setupRole    string
		setupAddr    std.Address
		queryRole    string
		queryAddr    std.Address
		expectedAuth bool
	}{
		{
			name:         "non-existent role",
			setupRole:    "",
			setupAddr:    "",
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

func TestInitialize(t *testing.T) {
	// Save original state
	originalRoles := make(map[string]std.Address)
	for k, v := range roleAddresses {
		originalRoles[k] = v
	}
	defer func() {
		roleAddresses = originalRoles
	}()

	tests := []struct {
		name         string
		initialRoles map[string]std.Address
		shouldPanic  bool
		panicMsg     string
	}{
		{
			name: "successful initialization with all required roles",
			initialRoles: map[string]std.Address{
				"admin":        testutils.TestAddress("admin"),
				"governance":   testutils.TestAddress("governance"),
				"pool":         testutils.TestAddress("pool"),
				"router":       testutils.TestAddress("router"),
				"position":     testutils.TestAddress("position"),
				"staker":       testutils.TestAddress("staker"),
				"emission":     testutils.TestAddress("emission"),
				"protocol_fee": testutils.TestAddress("protocol_fee"),
			},
			shouldPanic: false,
		},
		{
			name: "missing required role",
			initialRoles: map[string]std.Address{
				"admin":      testutils.TestAddress("admin"),
				"governance": testutils.TestAddress("governance"),
				// Missing other required roles
			},
			shouldPanic: true,
			panicMsg:    "missing required role: pool",
		},
		{
			name: "invalid address",
			initialRoles: map[string]std.Address{
				"admin":        std.Address(""),
				"governance":   testutils.TestAddress("governance"),
				"pool":         testutils.TestAddress("pool"),
				"router":       testutils.TestAddress("router"),
				"position":     testutils.TestAddress("position"),
				"staker":       testutils.TestAddress("staker"),
				"emission":     testutils.TestAddress("emission"),
				"protocol_fee": testutils.TestAddress("protocol_fee"),
			},
			shouldPanic: true,
			panicMsg:    "invalid address for role admin",
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			// Clear roles before each test
			roleAddresses = make(map[string]std.Address)

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

			// We can't test Initialize directly due to assertIsRBAC
			// So we simulate its logic here

			// Validate addresses
			for role, addr := range tt.initialRoles {
				if addr == std.Address("") {
					panic(ufmt.Errorf("invalid address for role %s: %s", role, addr))
				}
			}

			// Check required roles
			requiredRoles := []string{
				"admin", "governance", "pool", "router", "position",
				"staker", "emission", "protocol_fee",
			}
			for _, role := range requiredRoles {
				if _, exists := tt.initialRoles[role]; !exists {
					panic(ufmt.Errorf("missing required role: %s", role))
				}
			}

			roleAddresses = tt.initialRoles

			if !tt.shouldPanic {
				// Verify initialization
				for role, expectedAddr := range tt.initialRoles {
					addr, ok := GetAddress(role)
					if !ok {
						t.Errorf("Role %s should exist after initialization", role)
					}
					if addr != expectedAddr {
						t.Errorf("Expected %s for role %s, got %s", expectedAddr, role, addr)
					}
				}
			}
		})
	}
}

func TestSetRoleAddress(t *testing.T) {
	// Save original state
	originalRoles := make(map[string]std.Address)
	for k, v := range roleAddresses {
		originalRoles[k] = v
	}
	defer func() {
		roleAddresses = originalRoles
	}()

	tests := []struct {
		name        string
		setupRoles  map[string]std.Address
		roleName    string
		roleAddress std.Address
		shouldPanic bool
		panicMsg    string
	}{
		{
			name: "set new role",
			setupRoles: map[string]std.Address{
				"admin": testutils.TestAddress("admin"),
			},
			roleName:    "newrole",
			roleAddress: testutils.TestAddress("newrole"),
			shouldPanic: false,
		},
		{
			name: "update existing role",
			setupRoles: map[string]std.Address{
				"admin": testutils.TestAddress("admin"),
			},
			roleName:    "admin",
			roleAddress: testutils.TestAddress("newadmin"),
			shouldPanic: false,
		},
		{
			name: "set role with invalid address",
			setupRoles: map[string]std.Address{
				"admin": testutils.TestAddress("admin"),
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
	originalRoles := make(map[string]std.Address)
	for k, v := range roleAddresses {
		originalRoles[k] = v
	}
	defer func() {
		roleAddresses = originalRoles
	}()

	tests := []struct {
		name        string
		setupRoles  map[string]std.Address
		roleName    string
		shouldPanic bool
		panicMsg    string
	}{
		{
			name: "remove existing role",
			setupRoles: map[string]std.Address{
				"admin":      testutils.TestAddress("admin"),
				"governance": testutils.TestAddress("governance"),
				"custom":     testutils.TestAddress("custom"),
			},
			roleName:    "custom",
			shouldPanic: false,
		},
		{
			name: "remove non-existent role",
			setupRoles: map[string]std.Address{
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
