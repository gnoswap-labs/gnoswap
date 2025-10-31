package rbac

import (
	"testing"

	"gno.land/p/nt/uassert"
)

func TestTypes_SystemRoleString(t *testing.T) {
	tests := []struct {
		name     string
		role     SystemRole
		expected string
	}{
		{
			name:     "ROLE_ADMIN returns admin",
			role:     ROLE_ADMIN,
			expected: "admin",
		},
		{
			name:     "ROLE_DEVOPS returns devops",
			role:     ROLE_DEVOPS,
			expected: "devops",
		},
		{
			name:     "ROLE_COMMUNITY_POOL returns community_pool",
			role:     ROLE_COMMUNITY_POOL,
			expected: "community_pool",
		},
		{
			name:     "ROLE_GOVERNANCE returns governance",
			role:     ROLE_GOVERNANCE,
			expected: "governance",
		},
		{
			name:     "ROLE_GOV_STAKER returns gov_staker",
			role:     ROLE_GOV_STAKER,
			expected: "gov_staker",
		},
		{
			name:     "ROLE_XGNS returns xgns",
			role:     ROLE_XGNS,
			expected: "xgns",
		},
		{
			name:     "ROLE_POOL returns pool",
			role:     ROLE_POOL,
			expected: "pool",
		},
		{
			name:     "ROLE_POSITION returns position",
			role:     ROLE_POSITION,
			expected: "position",
		},
		{
			name:     "ROLE_ROUTER returns router",
			role:     ROLE_ROUTER,
			expected: "router",
		},
		{
			name:     "ROLE_STAKER returns staker",
			role:     ROLE_STAKER,
			expected: "staker",
		},
		{
			name:     "ROLE_EMISSION returns emission",
			role:     ROLE_EMISSION,
			expected: "emission",
		},
		{
			name:     "ROLE_LAUNCHPAD returns launchpad",
			role:     ROLE_LAUNCHPAD,
			expected: "launchpad",
		},
		{
			name:     "ROLE_PROTOCOL_FEE returns protocol_fee",
			role:     ROLE_PROTOCOL_FEE,
			expected: "protocol_fee",
		},
		{
			name:     "Unknown role returns Unknown",
			role:     SystemRole("unknown_role"),
			expected: "Unknown",
		},
		{
			name:     "Empty role returns Unknown",
			role:     SystemRole(""),
			expected: "Unknown",
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			result := tt.role.String()
			uassert.Equal(t, result, tt.expected)
		})
	}
}

func TestTypes_IsSystemRole(t *testing.T) {
	tests := []struct {
		name     string
		roleName string
		expected bool
	}{
		{
			name:     "admin is system role",
			roleName: "admin",
			expected: true,
		},
		{
			name:     "devops is system role",
			roleName: "devops",
			expected: true,
		},
		{
			name:     "community_pool is system role",
			roleName: "community_pool",
			expected: true,
		},
		{
			name:     "governance is system role",
			roleName: "governance",
			expected: true,
		},
		{
			name:     "gov_staker is system role",
			roleName: "gov_staker",
			expected: true,
		},
		{
			name:     "xgns is system role",
			roleName: "xgns",
			expected: true,
		},
		{
			name:     "pool is system role",
			roleName: "pool",
			expected: true,
		},
		{
			name:     "position is system role",
			roleName: "position",
			expected: true,
		},
		{
			name:     "router is system role",
			roleName: "router",
			expected: true,
		},
		{
			name:     "staker is system role",
			roleName: "staker",
			expected: true,
		},
		{
			name:     "emission is system role",
			roleName: "emission",
			expected: true,
		},
		{
			name:     "launchpad is system role",
			roleName: "launchpad",
			expected: true,
		},
		{
			name:     "protocol_fee is system role",
			roleName: "protocol_fee",
			expected: true,
		},
		{
			name:     "custom_role is not system role",
			roleName: "custom_role",
			expected: false,
		},
		{
			name:     "editor is not system role",
			roleName: "editor",
			expected: false,
		},
		{
			name:     "empty string is not system role",
			roleName: "",
			expected: false,
		},
		{
			name:     "Admin with capital A is not system role",
			roleName: "Admin",
			expected: false,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			result := IsSystemRole(tt.roleName)
			uassert.Equal(t, result, tt.expected)
		})
	}
}

func TestTypes_AllSystemRolesConsistency(t *testing.T) {
	// Test that all SystemRole constants can be found in systemRoleNames map
	allRoles := []SystemRole{
		ROLE_ADMIN,
		ROLE_DEVOPS,
		ROLE_COMMUNITY_POOL,
		ROLE_GOVERNANCE,
		ROLE_GOV_STAKER,
		ROLE_XGNS,
		ROLE_POOL,
		ROLE_POSITION,
		ROLE_ROUTER,
		ROLE_STAKER,
		ROLE_EMISSION,
		ROLE_LAUNCHPAD,
		ROLE_PROTOCOL_FEE,
	}

	for _, role := range allRoles {
		t.Run("Consistency check for "+string(role), func(t *testing.T) {
			// String() should return the role name
			roleName := role.String()
			uassert.NotEqual(t, roleName, "Unknown")

			// IsSystemRole should return true for the role name
			isSystem := IsSystemRole(roleName)
			uassert.True(t, isSystem)

			// The role should be in systemRoleNames map
			_, exists := systemRoleNames[roleName]
			uassert.True(t, exists)
		})
	}
}

func TestTypes_SystemRoleNamesMapCompleteness(t *testing.T) {
	// Verify systemRoleNames map has exactly 13 entries
	expectedCount := 13
	actualCount := len(systemRoleNames)

	uassert.Equal(t, actualCount, expectedCount)

	// Verify all expected roles are present
	expectedRoles := []string{
		"admin",
		"devops",
		"community_pool",
		"governance",
		"gov_staker",
		"xgns",
		"pool",
		"position",
		"router",
		"staker",
		"emission",
		"launchpad",
		"protocol_fee",
	}

	for _, roleName := range expectedRoles {
		t.Run("Map contains "+roleName, func(t *testing.T) {
			_, exists := systemRoleNames[roleName]
			uassert.True(t, exists)
		})
	}
}
