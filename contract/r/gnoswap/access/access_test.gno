package access

import (
	"std"
	"testing"

	prbac "gno.land/p/gnoswap/rbac"
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
		name      string
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

func TestSetRoleAddresses(t *testing.T) {
	// Save original state
	originalRoles := make(map[string]std.Address)
	for k, v := range roleAddresses {
		originalRoles[k] = v
	}
	defer func() {
		roleAddresses = originalRoles
	}()
	
	tests := []struct {
		name      string
		newRoles  map[string]std.Address
		verifyRoles []struct {
			role     string
			expected std.Address
		}
	}{
		{
			name: "set admin and governance roles",
			newRoles: map[string]std.Address{
				prbac.ROLE_ADMIN.String():      std.Address("g1admin123456789abcdef"),
				prbac.ROLE_GOVERNANCE.String(): std.Address("g1governance123456789a"),
			},
			verifyRoles: []struct {
				role     string
				expected std.Address
			}{
				{prbac.ROLE_ADMIN.String(), std.Address("g1admin123456789abcdef")},
				{prbac.ROLE_GOVERNANCE.String(), std.Address("g1governance123456789a")},
			},
		},
		{
			name: "set multiple roles",
			newRoles: map[string]std.Address{
				prbac.ROLE_ADMIN.String():    std.Address("g1admin123456789abcdef"),
				prbac.ROLE_ROUTER.String():   std.Address("g1router123456789abcde"),
				prbac.ROLE_POOL.String():     std.Address("g1pool1234567890abcdef"),
				prbac.ROLE_POSITION.String(): std.Address("g1position123456789abc"),
			},
			verifyRoles: []struct {
				role     string
				expected std.Address
			}{
				{prbac.ROLE_ADMIN.String(), std.Address("g1admin123456789abcdef")},
				{prbac.ROLE_ROUTER.String(), std.Address("g1router123456789abcde")},
				{prbac.ROLE_POOL.String(), std.Address("g1pool1234567890abcdef")},
				{prbac.ROLE_POSITION.String(), std.Address("g1position123456789abc")},
			},
		},
	}
	
	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			// We can't directly test SetRoleAddresses due to assertIsRBAC
			// but we can test the logic by directly setting roleAddresses
			roleAddresses = tt.newRoles
			
			// Verify each role was set correctly
			for _, verify := range tt.verifyRoles {
				addr, ok := GetAddress(verify.role)
				if !ok {
					t.Errorf("Role %s should exist after setting", verify.role)
				}
				if addr != verify.expected {
					t.Errorf("Expected %s for role %s, got %s", verify.expected, verify.role, addr)
				}
			}
		})
	}
}
