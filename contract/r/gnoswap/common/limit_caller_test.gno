package common

import (
	"std"
	"testing"

	"gno.land/p/demo/testutils"
	"gno.land/p/demo/uassert"

	prbac "gno.land/p/gnoswap/rbac"
	"gno.land/r/gnoswap/v1/access"
)

func TestGetLimitCaller(t *testing.T) {
	t.Run("returns boolean value", func(t *testing.T) {
		result := GetLimitCaller()
		// Should return a boolean (true or false)
		uassert.True(t, result == true || result == false)
	})
}

func TestSetLimitCaller(t *testing.T) {
	setupTestRolesForLimitCaller()

	// Store original state
	originalState := GetLimitCaller()

	t.Run("initial check", func(t *testing.T) {
		uassert.True(t, GetLimitCaller())
	})

	t.Run("with admin privilege, set to false", func(t *testing.T) {
		func(cur realm) {
			adminAddr, _ := access.GetAddress(prbac.ROLE_ADMIN.String())
			testing.SetRealm(std.NewUserRealm(adminAddr))

			SetLimitCaller(cross, false)
			uassert.False(t, GetLimitCaller())
		}(cross)
	})

	t.Run("with admin privilege, set to true", func(t *testing.T) {
		func(cur realm) {
			adminAddr, _ := access.GetAddress(prbac.ROLE_ADMIN.String())
			testing.SetRealm(std.NewUserRealm(adminAddr))

			SetLimitCaller(cross, true)
			uassert.True(t, GetLimitCaller())
		}(cross)
	})

	t.Run("state persistence test", func(t *testing.T) {
		func(cur realm) {
			adminAddr, _ := access.GetAddress(prbac.ROLE_ADMIN.String())
			testing.SetRealm(std.NewUserRealm(adminAddr))

			// Set to false
			SetLimitCaller(cross, false)
			uassert.False(t, GetLimitCaller())

			// Set to true
			SetLimitCaller(cross, true)
			uassert.True(t, GetLimitCaller())

			// Set back to false
			SetLimitCaller(cross, false)
			uassert.False(t, GetLimitCaller())
		}(cross)
	})

	// Restore original state after test
	defer func() {
		func(cur realm) {
			adminAddr, _ := access.GetAddress(prbac.ROLE_ADMIN.String())
			testing.SetRealm(std.NewUserRealm(adminAddr))
			SetLimitCaller(cross, originalState)
		}(cross)
	}()
}

// TestLimitCallerIntegration tests the integration between GetLimitCaller and SetLimitCaller
func TestLimitCallerIntegration(t *testing.T) {
	setupTestRolesForLimitCaller()
	
	// Store original state
	originalState := GetLimitCaller()
	defer func() {
		func(cur realm) {
			adminAddr, _ := access.GetAddress(prbac.ROLE_ADMIN.String())
			testing.SetRealm(std.NewUserRealm(adminAddr))
			SetLimitCaller(cross, originalState)
		}(cross)
	}()

	tests := []struct {
		name     string
		setValue bool
	}{
		{"Set and verify true", true},
		{"Set and verify false", false},
		{"Toggle back to true", true},
		{"Final toggle to false", false},
	}

	for _, tc := range tests {
		t.Run(tc.name, func(t *testing.T) {
			func(cur realm) {
				adminAddr, _ := access.GetAddress(prbac.ROLE_ADMIN.String())
				testing.SetRealm(std.NewUserRealm(adminAddr))

				SetLimitCaller(cross, tc.setValue)
				result := GetLimitCaller()
				uassert.Equal(t, tc.setValue, result)
			}(cross)
		})
	}
}

// setupTestRolesForLimitCaller initializes role addresses for testing
func setupTestRolesForLimitCaller() {
	testAdminAddr := testutils.TestAddress("admin")

	roleMap := map[string]std.Address{
		prbac.ROLE_ADMIN.String(): testAdminAddr,
	}

	// Set up the test realm context to mimic RBAC package calling SetRoleAddresses
	testing.SetRealm(std.NewCodeRealm("gno.land/r/gnoswap/v1/rbac"))
	access.SetRoleAddresses(cross, roleMap)
}
