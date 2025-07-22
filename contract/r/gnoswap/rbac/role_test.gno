package rbac

import (
	"std"
	"testing"

	prbac "gno.land/p/gnoswap/rbac"
)

func TestDefaultRoleAddresses(t *testing.T) {
	// Test that all default role addresses are properly defined
	expectedRoles := []prbac.SystemRole{
		prbac.ROLE_ADMIN,
		prbac.ROLE_DEVOPS,
		prbac.ROLE_COMMUNITY_POOL,
		prbac.ROLE_GOVERNANCE,
		prbac.ROLE_GOV_STAKER,
		prbac.ROLE_XGNS,
		prbac.ROLE_POOL,
		prbac.ROLE_POSITION,
		prbac.ROLE_ROUTER,
		prbac.ROLE_STAKER,
		prbac.ROLE_EMISSION,
		prbac.ROLE_LAUNCHPAD,
		prbac.ROLE_PROTOCOL_FEE,
	}

	expectedAddresses := map[prbac.SystemRole]std.Address{
		prbac.ROLE_ADMIN:         ADMIN,
		prbac.ROLE_DEVOPS:        DEV_OPS,
		prbac.ROLE_COMMUNITY_POOL: COMMUNITY_POOL_ADDR,
		prbac.ROLE_GOVERNANCE:    GOV_GOVERNANCE_ADDR,
		prbac.ROLE_GOV_STAKER:     GOV_STAKER_ADDR,
		prbac.ROLE_XGNS:          GOV_XGNS_ADDR,
		prbac.ROLE_POOL:          POOL_ADDR,
		prbac.ROLE_POSITION:      POSITION_ADDR,
		prbac.ROLE_ROUTER:        ROUTER_ADDR,
		prbac.ROLE_STAKER:        STAKER_ADDR,
		prbac.ROLE_EMISSION:      EMISSION_ADDR,
		prbac.ROLE_LAUNCHPAD:     LAUNCHPAD_ADDR,
		prbac.ROLE_PROTOCOL_FEE:   PROTOCOL_FEE_ADDR,
	}

	// Test that all expected roles exist in DefaultRoleAddresses
	for _, role := range expectedRoles {
		addr, exists := DefaultRoleAddresses[role]
		if !exists {
			t.Errorf("Role %s not found in DefaultRoleAddresses", role.String())
			continue
		}

		expectedAddr := expectedAddresses[role]
		if addr != expectedAddr {
			t.Errorf("Role %s has incorrect address: got %s, want %s", 
				role.String(), addr, expectedAddr)
		}
	}

	// Test that DefaultRoleAddresses doesn't contain unexpected roles
	if len(DefaultRoleAddresses) != len(expectedRoles) {
		t.Errorf("DefaultRoleAddresses contains unexpected number of roles: got %d, want %d", 
			len(DefaultRoleAddresses), len(expectedRoles))
	}
}

func TestDefaultRoleAddressesCompleteness(t *testing.T) {
	// Test that all addresses are valid (non-empty)
	for role, addr := range DefaultRoleAddresses {
		if addr == "" {
			t.Errorf("Role %s has empty address", role.String())
		}

		if !addr.IsValid() {
			t.Errorf("Role %s has invalid address: %s", role.String(), addr)
		}
	}
}

func TestDefaultRoleAddressesMapping(t *testing.T) {
	// Test specific role-address mappings
	tests := []struct {
		role         prbac.SystemRole
		expectedAddr std.Address
		description  string
	}{
		{
			role:         prbac.ROLE_ADMIN,
			expectedAddr: ADMIN,
			description:  "Admin role should map to ADMIN address",
		},
		{
			role:         prbac.ROLE_DEVOPS,
			expectedAddr: DEV_OPS,
			description:  "DevOps role should map to DEV_OPS address",
		},
		{
			role:         prbac.ROLE_COMMUNITY_POOL,
			expectedAddr: COMMUNITY_POOL_ADDR,
			description:  "Community pool role should map to COMMUNITY_POOL_ADDR",
		},
		{
			role:         prbac.ROLE_GOVERNANCE,
			expectedAddr: GOV_GOVERNANCE_ADDR,
			description:  "Governance role should map to GOV_GOVERNANCE_ADDR",
		},
		{
			role:         prbac.ROLE_GOV_STAKER,
			expectedAddr: GOV_STAKER_ADDR,
			description:  "Gov staker role should map to GOV_STAKER_ADDR",
		},
		{
			role:         prbac.ROLE_XGNS,
			expectedAddr: GOV_XGNS_ADDR,
			description:  "XGNS role should map to GOV_XGNS_ADDR",
		},
		{
			role:         prbac.ROLE_POOL,
			expectedAddr: POOL_ADDR,
			description:  "Pool role should map to POOL_ADDR",
		},
		{
			role:         prbac.ROLE_POSITION,
			expectedAddr: POSITION_ADDR,
			description:  "Position role should map to POSITION_ADDR",
		},
		{
			role:         prbac.ROLE_ROUTER,
			expectedAddr: ROUTER_ADDR,
			description:  "Router role should map to ROUTER_ADDR",
		},
		{
			role:         prbac.ROLE_STAKER,
			expectedAddr: STAKER_ADDR,
			description:  "Staker role should map to STAKER_ADDR",
		},
		{
			role:         prbac.ROLE_EMISSION,
			expectedAddr: EMISSION_ADDR,
			description:  "Emission role should map to EMISSION_ADDR",
		},
		{
			role:         prbac.ROLE_LAUNCHPAD,
			expectedAddr: LAUNCHPAD_ADDR,
			description:  "Launchpad role should map to LAUNCHPAD_ADDR",
		},
		{
			role:         prbac.ROLE_PROTOCOL_FEE,
			expectedAddr: PROTOCOL_FEE_ADDR,
			description:  "Protocol fee role should map to PROTOCOL_FEE_ADDR",
		},
	}

	for _, tt := range tests {
		t.Run(tt.description, func(t *testing.T) {
			actualAddr, exists := DefaultRoleAddresses[tt.role]
			if !exists {
				t.Errorf("Role %s not found in DefaultRoleAddresses", tt.role.String())
				return
			}

			if actualAddr != tt.expectedAddr {
				t.Errorf("Role %s address mismatch: got %s, want %s", 
					tt.role.String(), actualAddr, tt.expectedAddr)
			}
		})
	}
}

func TestRoleStringRepresentation(t *testing.T) {
	// Test that all roles have proper string representation
	expectedStrings := map[prbac.SystemRole]string{
		prbac.ROLE_ADMIN:         "admin",
		prbac.ROLE_DEVOPS:        "devops",
		prbac.ROLE_COMMUNITY_POOL: "community_pool",
		prbac.ROLE_GOVERNANCE:    "governance",
		prbac.ROLE_GOV_STAKER:     "gov_staker",
		prbac.ROLE_XGNS:          "xgns",
		prbac.ROLE_POOL:          "pool",
		prbac.ROLE_POSITION:      "position",
		prbac.ROLE_ROUTER:        "router",
		prbac.ROLE_STAKER:        "staker",
		prbac.ROLE_EMISSION:      "emission",
		prbac.ROLE_LAUNCHPAD:     "launchpad",
		prbac.ROLE_PROTOCOL_FEE:   "protocol_fee",
	}

	for role := range DefaultRoleAddresses {
		expectedStr := expectedStrings[role]
		actualStr := role.String()
		
		if actualStr != expectedStr {
			t.Errorf("Role %s string representation mismatch: got %s, want %s", 
				role, actualStr, expectedStr)
		}
	}
}

func TestSystemRoleValidation(t *testing.T) {
	// Test that all roles in DefaultRoleAddresses are system roles
	for role := range DefaultRoleAddresses {
		if !prbac.IsSystemRole(role.String()) {
			t.Errorf("Role %s should be a system role but IsSystemRole returned false", 
				role.String())
		}
	}

	// Test that non-system roles are not in DefaultRoleAddresses
	nonSystemRoles := []string{
		"custom_role",
		"user_defined_role",
		"test_role",
		"unknown_role",
	}

	for _, roleName := range nonSystemRoles {
		if prbac.IsSystemRole(roleName) {
			t.Errorf("Role %s should not be a system role but IsSystemRole returned true", 
				roleName)
		}
	}
}

func TestRoleAddressUniqueness(t *testing.T) {
	// Test that all role addresses are unique (no two roles share the same address)
	addressToRole := make(map[std.Address]prbac.SystemRole)
	
	for role, addr := range DefaultRoleAddresses {
		if existingRole, exists := addressToRole[addr]; exists {
			t.Errorf("Address %s is assigned to multiple roles: %s and %s", 
				addr, existingRole.String(), role.String())
		} else {
			addressToRole[addr] = role
		}
	}
}

func TestDefaultRoleAddressesIntegrationWithManager(t *testing.T) {
	// Test that DefaultRoleAddresses works correctly with RBAC manager
	manager = prbac.NewRBACWithAddress(ADMIN)
	initRbac()

	// Test that all roles from DefaultRoleAddresses are properly registered in manager
	for role, expectedAddr := range DefaultRoleAddresses {
		actualAddr, err := manager.GetRoleAddress(role.String())
		if err != nil {
			t.Errorf("Failed to get address for role %s: %v", role.String(), err)
			continue
		}

		if actualAddr != expectedAddr {
			t.Errorf("Manager has incorrect address for role %s: got %s, want %s", 
				role.String(), actualAddr, expectedAddr)
		}
	}
} 