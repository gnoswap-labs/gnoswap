package rbac

import (
	"testing"

	"gno.land/p/nt/uassert"
)

func TestSystemRole_String(t *testing.T) {
	tests := []struct {
		name     string
		role     SystemRole
		expected string
	}{
		{
			name:     "Valid system role - admin",
			role:     ROLE_ADMIN,
			expected: "admin",
		},
		{
			name:     "Valid system role - devops",
			role:     ROLE_DEVOPS,
			expected: "devops",
		},
		{
			name:     "Valid system role - governance",
			role:     ROLE_GOVERNANCE,
			expected: "governance",
		},
		{
			name:     "Valid system role - pool",
			role:     ROLE_POOL,
			expected: "pool",
		},
		{
			name:     "Valid system role - staker",
			role:     ROLE_STAKER,
			expected: "staker",
		},
		{
			name:     "Invalid system role - empty string",
			role:     SystemRole(""),
			expected: "Unknown",
		},
		{
			name:     "Invalid system role - random string",
			role:     SystemRole("random_role"),
			expected: "Unknown",
		},
		{
			name:     "Invalid system role - similar but wrong name",
			role:     SystemRole("admins"),
			expected: "Unknown",
		},
		{
			name:     "Invalid system role - uppercase",
			role:     SystemRole("ADMIN"),
			expected: "Unknown",
		},
		{
			name:     "Invalid system role - with spaces",
			role:     SystemRole("admin "),
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

func TestIsSystemRole(t *testing.T) {
	tests := []struct {
		name     string
		roleName string
		expected bool
	}{
		{
			name:     "Valid system role - admin",
			roleName: "admin",
			expected: true,
		},
		{
			name:     "Valid system role - devops",
			roleName: "devops",
			expected: true,
		},
		{
			name:     "Valid system role - community_pool",
			roleName: "community_pool",
			expected: true,
		},
		{
			name:     "Valid system role - governance",
			roleName: "governance",
			expected: true,
		},
		{
			name:     "Valid system role - gov_staker",
			roleName: "gov_staker",
			expected: true,
		},
		{
			name:     "Valid system role - xgns",
			roleName: "xgns",
			expected: true,
		},
		{
			name:     "Valid system role - pool",
			roleName: "pool",
			expected: true,
		},
		{
			name:     "Valid system role - position",
			roleName: "position",
			expected: true,
		},
		{
			name:     "Valid system role - router",
			roleName: "router",
			expected: true,
		},
		{
			name:     "Valid system role - staker",
			roleName: "staker",
			expected: true,
		},
		{
			name:     "Valid system role - emission",
			roleName: "emission",
			expected: true,
		},
		{
			name:     "Valid system role - launchpad",
			roleName: "launchpad",
			expected: true,
		},
		{
			name:     "Valid system role - protocol_fee",
			roleName: "protocol_fee",
			expected: true,
		},
		{
			name:     "Invalid role - empty string",
			roleName: "",
			expected: false,
		},
		{
			name:     "Invalid role - custom role",
			roleName: "custom_role",
			expected: false,
		},
		{
			name:     "Invalid role - uppercase",
			roleName: "ADMIN",
			expected: false,
		},
		{
			name:     "Invalid role - similar but wrong",
			roleName: "admins",
			expected: false,
		},
		{
			name:     "Invalid role - with spaces",
			roleName: "admin ",
			expected: false,
		},
		{
			name:     "Invalid role - partial match",
			roleName: "admi",
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

func TestSystemRole_AllRolesHaveValidString(t *testing.T) {
	// Test that all defined system role constants return valid strings
	allRoles := []struct {
		role     SystemRole
		expected string
	}{
		{ROLE_ADMIN, "admin"},
		{ROLE_DEVOPS, "devops"},
		{ROLE_COMMUNITY_POOL, "community_pool"},
		{ROLE_GOVERNANCE, "governance"},
		{ROLE_GOV_STAKER, "gov_staker"},
		{ROLE_XGNS, "xgns"},
		{ROLE_POOL, "pool"},
		{ROLE_POSITION, "position"},
		{ROLE_ROUTER, "router"},
		{ROLE_STAKER, "staker"},
		{ROLE_EMISSION, "emission"},
		{ROLE_LAUNCHPAD, "launchpad"},
		{ROLE_PROTOCOL_FEE, "protocol_fee"},
	}

	for _, item := range allRoles {
		t.Run("Role "+item.expected, func(t *testing.T) {
			result := item.role.String()
			uassert.Equal(t, result, item.expected)
			// Verify it's also recognized as a system role
			uassert.True(t, IsSystemRole(result))
		})
	}
}

func TestSystemRoleNames_MapCompleteness(t *testing.T) {
	// Verify that systemRoleNames map has exactly 13 entries
	expectedCount := 13
	actualCount := len(systemRoleNames)
	uassert.Equal(t, actualCount, expectedCount)

	// Verify all expected roles are in the map
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
		_, exists := systemRoleNames[roleName]
		uassert.True(t, exists)
	}
}
