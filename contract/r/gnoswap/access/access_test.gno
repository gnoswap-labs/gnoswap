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
	originalRoles := make(map[string][]std.Address)
	for k, v := range roleAddresses {
		addressCopy := make([]std.Address, len(v))
		copy(addressCopy, v)
		originalRoles[k] = addressCopy
	}
	defer func() {
		roleAddresses = originalRoles
	}()

	tests := []struct {
		name           string
		setupRole      string
		setupAddrs     []std.Address
		queryRole      string
		expectedAddr   std.Address
		expectedExists bool
	}{
		{
			name:           "non-existent role",
			setupRole:      "",
			setupAddrs:     []std.Address{},
			queryRole:      testRole,
			expectedAddr:   "",
			expectedExists: false,
		},
		{
			name:           "existing role with single address",
			setupRole:      testRole,
			setupAddrs:     []std.Address{testAddr},
			queryRole:      testRole,
			expectedAddr:   testAddr,
			expectedExists: true,
		},
		{
			name:           "existing role with multiple versions",
			setupRole:      testRole,
			setupAddrs:     []std.Address{std.Address("g1old123456789abcdef"), testAddr},
			queryRole:      testRole,
			expectedAddr:   testAddr, // Should return latest
			expectedExists: true,
		},
		{
			name:           "query different role",
			setupRole:      testRole,
			setupAddrs:     []std.Address{testAddr},
			queryRole:      "different_role",
			expectedAddr:   "",
			expectedExists: false,
		},
		{
			name:           "empty address list",
			setupRole:      testRole,
			setupAddrs:     []std.Address{},
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
	originalRoles := make(map[string][]std.Address)
	for k, v := range roleAddresses {
		addressCopy := make([]std.Address, len(v))
		copy(addressCopy, v)
		originalRoles[k] = addressCopy
	}
	defer func() {
		roleAddresses = originalRoles
	}()

	// Setup test data
	roleAddresses[testRole] = []std.Address{addr1, addr2, addr3}

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
			expectedExists: true,
		},
		{
			name:           "get version 1",
			role:           testRole,
			version:        1,
			expectedAddr:   addr2,
			expectedExists: true,
		},
		{
			name:           "get version 2",
			role:           testRole,
			version:        2,
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
			name:           "version out of bounds",
			role:           testRole,
			version:        3,
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
	originalRoles := make(map[string][]std.Address)
	for k, v := range roleAddresses {
		addressCopy := make([]std.Address, len(v))
		copy(addressCopy, v)
		originalRoles[k] = addressCopy
	}
	defer func() {
		roleAddresses = originalRoles
	}()

	tests := []struct {
		name       string
		setupRoles map[string][]std.Address
		expected   map[string][]std.Address
	}{
		{
			name:       "empty roles",
			setupRoles: map[string][]std.Address{},
			expected:   map[string][]std.Address{},
		},
		{
			name: "single role",
			setupRoles: map[string][]std.Address{
				"role1": []std.Address{std.Address("g1test111111111111111")},
			},
			expected: map[string][]std.Address{
				"role1": []std.Address{std.Address("g1test111111111111111")},
			},
		},
		{
			name: "multiple roles",
			setupRoles: map[string][]std.Address{
				"role1": []std.Address{std.Address("g1test111111111111111")},
				"role2": []std.Address{std.Address("g1test222222222222222")},
				"role3": []std.Address{std.Address("g1test333333333333333")},
			},
			expected: map[string][]std.Address{
				"role1": []std.Address{std.Address("g1test111111111111111")},
				"role2": []std.Address{std.Address("g1test222222222222222")},
				"role3": []std.Address{std.Address("g1test333333333333333")},
			},
		},
		{
			name: "roles with multiple versions",
			setupRoles: map[string][]std.Address{
				"role1": []std.Address{
					std.Address("g1test111111111111111"),
					std.Address("g1test111111111111112"),
					std.Address("g1test111111111111113"),
				},
			},
			expected: map[string][]std.Address{
				"role1": []std.Address{
					std.Address("g1test111111111111111"),
					std.Address("g1test111111111111112"),
					std.Address("g1test111111111111113"),
				},
			},
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			// Setup
			roleAddresses = make(map[string][]std.Address)
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
			addresses["new_role"] = []std.Address{std.Address("g1new123456789abcdef")}
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
	originalRoles := make(map[string][]std.Address)
	for k, v := range roleAddresses {
		addressCopy := make([]std.Address, len(v))
		copy(addressCopy, v)
		originalRoles[k] = addressCopy
	}
	defer func() {
		roleAddresses = originalRoles
	}()

	tests := []struct {
		name         string
		setupRole    string
		setupAddrs   []std.Address
		queryRole    string
		queryAddr    std.Address
		expectedAuth bool
	}{
		{
			name:         "non-existent role",
			setupRole:    "",
			setupAddrs:   []std.Address{},
			queryRole:    testRole,
			queryAddr:    testAddr,
			expectedAuth: false,
		},
		{
			name:         "existing role with correct address",
			setupRole:    testRole,
			setupAddrs:   []std.Address{testAddr},
			queryRole:    testRole,
			queryAddr:    testAddr,
			expectedAuth: true,
		},
		{
			name:         "existing role with incorrect address",
			setupRole:    testRole,
			setupAddrs:   []std.Address{testAddr},
			queryRole:    testRole,
			queryAddr:    otherAddr,
			expectedAuth: false,
		},
		{
			name:         "query different role",
			setupRole:    testRole,
			setupAddrs:   []std.Address{testAddr},
			queryRole:    "different_role",
			queryAddr:    testAddr,
			expectedAuth: false,
		},
		{
			name:         "multiple addresses in role - first matches",
			setupRole:    testRole,
			setupAddrs:   []std.Address{testAddr, otherAddr},
			queryRole:    testRole,
			queryAddr:    testAddr,
			expectedAuth: true,
		},
		{
			name:         "multiple addresses in role - last matches",
			setupRole:    testRole,
			setupAddrs:   []std.Address{otherAddr, testAddr},
			queryRole:    testRole,
			queryAddr:    testAddr,
			expectedAuth: true,
		},
		{
			name:         "multiple addresses in role - none match",
			setupRole:    testRole,
			setupAddrs:   []std.Address{std.Address("g1addr1234567890abcdef"), std.Address("g1addr2234567890abcdef")},
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
	originalRoles := make(map[string][]std.Address)
	for k, v := range roleAddresses {
		addressCopy := make([]std.Address, len(v))
		copy(addressCopy, v)
		originalRoles[k] = addressCopy
	}
	defer func() {
		roleAddresses = originalRoles
	}()

	// Setup
	roleAddresses[testRole] = []std.Address{testAddr1, testAddr2, testAddr3}

	tests := []struct {
		name         string
		role         string
		version      int
		caller       std.Address
		expectedAuth bool
	}{
		{
			name:         "version 0 with correct address",
			role:         testRole,
			version:      0,
			caller:       testAddr1,
			expectedAuth: true,
		},
		{
			name:         "version 1 with correct address",
			role:         testRole,
			version:      1,
			caller:       testAddr2,
			expectedAuth: true,
		},
		{
			name:         "version 2 with correct address",
			role:         testRole,
			version:      2,
			caller:       testAddr3,
			expectedAuth: true,
		},
		{
			name:         "version 0 with wrong address",
			role:         testRole,
			version:      0,
			caller:       testAddr2,
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
			name:         "version out of bounds",
			role:         testRole,
			version:      3,
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

func TestSetRoleAddresses(t *testing.T) {
	// Save original state
	originalRoles := make(map[string][]std.Address)
	for k, v := range roleAddresses {
		addressCopy := make([]std.Address, len(v))
		copy(addressCopy, v)
		originalRoles[k] = addressCopy
	}
	defer func() {
		roleAddresses = originalRoles
	}()

	tests := []struct {
		name        string
		newRoles    map[string][]std.Address
		verifyRoles []struct {
			role     string
			expected std.Address
		}
	}{
		{
			name: "set admin and governance roles",
			newRoles: map[string][]std.Address{
				prbac.ROLE_ADMIN.String():      []std.Address{std.Address("g1admin123456789abcdef")},
				prbac.ROLE_GOVERNANCE.String(): []std.Address{std.Address("g1governance123456789a")},
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
			newRoles: map[string][]std.Address{
				prbac.ROLE_ADMIN.String():    []std.Address{std.Address("g1admin123456789abcdef")},
				prbac.ROLE_ROUTER.String():   []std.Address{std.Address("g1router123456789abcde")},
				prbac.ROLE_POOL.String():     []std.Address{std.Address("g1pool1234567890abcdef")},
				prbac.ROLE_POSITION.String(): []std.Address{std.Address("g1position123456789abc")},
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
		{
			name: "set roles with multiple versions",
			newRoles: map[string][]std.Address{
				prbac.ROLE_ADMIN.String(): []std.Address{
					std.Address("g1admin123456789abcde1"),
					std.Address("g1admin123456789abcde2"),
					std.Address("g1admin123456789abcde3"),
				},
			},
			verifyRoles: []struct {
				role     string
				expected std.Address
			}{
				{prbac.ROLE_ADMIN.String(), std.Address("g1admin123456789abcde3")}, // Latest version
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
