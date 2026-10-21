package rbac

import (
	"testing"

	prbac "gno.land/p/gnoswap/rbac/v1"
)

func Test_defaultRoleAddressesCompleteness(cur realm, t *testing.T) {
	// Test that all addresses are valid (non-empty)
	for role, addr := range _defaultRoleAddresses {
		if addr == "" {
			t.Errorf("Role %s has empty address", role.String())
		}

		if !addr.IsValid() {
			t.Errorf("Role %s has invalid address: %s", role.String(), addr)
		}
	}
}

func Test_defaultRoleAddressesMapping(cur realm, t *testing.T) {
	// Test specific role-address mappings
	tests := []struct {
		role         prbac.SystemRole
		expectedAddr address
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
		t.Run(tt.description, func(cur realm, t *testing.T) {
			actualAddr, exists := _defaultRoleAddresses[tt.role]
			if !exists {
				t.Errorf("Role %s not found in _defaultRoleAddresses", tt.role.String())
				return
			}

			if actualAddr != tt.expectedAddr {
				t.Errorf("Role %s address mismatch: got %s, want %s",
					tt.role.String(), actualAddr, tt.expectedAddr)
			}
		})
	}
}

func TestSystemRoleValidation(cur realm, t *testing.T) {
	// Test that all roles in _defaultRoleAddresses are system roles
	for role := range _defaultRoleAddresses {
		if !prbac.IsSystemRole(role.String()) {
			t.Errorf("Role %s should be a system role but IsSystemRole returned false",
				role.String())
		}
	}

	// Test that non-system roles are not in _defaultRoleAddresses
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

func TestRoleAddressUniqueness(cur realm, t *testing.T) {
	// Test that all role addresses are unique (no two roles share the same address)
	addressToRole := make(map[address]prbac.SystemRole)

	for role, addr := range _defaultRoleAddresses {
		if existingRole, exists := addressToRole[addr]; exists {
			t.Errorf("Address %s is assigned to multiple roles: %s and %s",
				addr, existingRole.String(), role.String())
		} else {
			addressToRole[addr] = role
		}
	}
}

func Test_defaultRoleAddressesIntegrationWithManager(cur realm, t *testing.T) {
	// Test that _defaultRoleAddresses works correctly with RBAC manager
	manager = prbac.NewRBACWithAddress(ADMIN)
	initRbac(cur)

	// Test that all roles from _defaultRoleAddresses are properly registered in manager
	for role, expectedAddr := range _defaultRoleAddresses {
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
