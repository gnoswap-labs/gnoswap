package common

import (
	"std"
	"testing"

	"gno.land/p/demo/testutils"
	"gno.land/p/demo/uassert"

	prbac "gno.land/p/gnoswap/rbac"
	"gno.land/r/gnoswap/v1/access"
)

var (
	addr01 = testutils.TestAddress("addr01")
	addr02 = testutils.TestAddress("addr02")

	// Test role addresses
	testAdminAddr     = testutils.TestAddress("admin")
	testGovAddr       = testutils.TestAddress("governance")
	testGovStakerAddr = testutils.TestAddress("govstaker")
	testRouterAddr    = testutils.TestAddress("router")
	testPositionAddr  = testutils.TestAddress("position")
	testPoolAddr      = testutils.TestAddress("pool")
	testStakerAddr    = testutils.TestAddress("staker")
	testLaunchpadAddr = testutils.TestAddress("launchpad")
	testEmissionAddr  = testutils.TestAddress("emission")
)

// setupTestRoles initializes role addresses for testing
func setupTestRoles() {
	roleMap := map[string]std.Address{
		prbac.ROLE_ADMIN.String():      testAdminAddr,
		prbac.ROLE_GOVERNANCE.String(): testGovAddr,
		prbac.ROLE_GOV_STAKER.String(): testGovStakerAddr,
		prbac.ROLE_ROUTER.String():     testRouterAddr,
		prbac.ROLE_POSITION.String():   testPositionAddr,
		prbac.ROLE_POOL.String():       testPoolAddr,
		prbac.ROLE_STAKER.String():     testStakerAddr,
		prbac.ROLE_LAUNCHPAD.String():  testLaunchpadAddr,
		prbac.ROLE_EMISSION.String():   testEmissionAddr,
	}

	// Set up the test realm context to mimic RBAC package calling SetRoleAddresses
	testing.SetRealm(std.NewCodeRealm("gno.land/r/gnoswap/v1/rbac"))
	access.SetRoleAddresses(cross, roleMap)
}

func TestAssertCaller(t *testing.T) {
	t.Run("same caller", func(t *testing.T) {
		uassert.NoError(t, AssertCaller(addr01, addr01))
	})

	t.Run("different caller", func(t *testing.T) {
		uassert.Error(t, AssertCaller(addr01, addr02))
	})
}

func TestSatisfyCond(t *testing.T) {
	t.Run("true", func(t *testing.T) {
		uassert.NoError(t, SatisfyCond(true))
	})

	t.Run("false", func(t *testing.T) {
		uassert.Error(t, SatisfyCond(false))
	})
}

func TestIsAuthorized(t *testing.T) {
	setupTestRoles()

	t.Run("authorized admin", func(t *testing.T) {
		uassert.True(t, IsAuthorized(prbac.ROLE_ADMIN, testAdminAddr))
	})

	t.Run("unauthorized user for admin role", func(t *testing.T) {
		uassert.False(t, IsAuthorized(prbac.ROLE_ADMIN, addr01))
	})

	t.Run("authorized governance", func(t *testing.T) {
		uassert.True(t, IsAuthorized(prbac.ROLE_GOVERNANCE, testGovAddr))
	})

	t.Run("unauthorized user for governance role", func(t *testing.T) {
		uassert.False(t, IsAuthorized(prbac.ROLE_GOVERNANCE, addr01))
	})

	t.Run("authorized router", func(t *testing.T) {
		uassert.True(t, IsAuthorized(prbac.ROLE_ROUTER, testRouterAddr))
	})

	t.Run("cross-role authorization check", func(t *testing.T) {
		// Admin address should not be authorized for governance role
		uassert.False(t, IsAuthorized(prbac.ROLE_GOVERNANCE, testAdminAddr))
		// Governance address should not be authorized for admin role
		uassert.False(t, IsAuthorized(prbac.ROLE_ADMIN, testGovAddr))
	})
}

func TestRequireAuthorized(t *testing.T) {
	setupTestRoles()

	t.Run("authorized admin - should not panic", func(t *testing.T) {
		defer func() {
			if r := recover(); r != nil {
				t.Errorf("RequireAuthorized should not panic for authorized admin, but got: %v", r)
			}
		}()
		RequireAuthorized(prbac.ROLE_ADMIN, testAdminAddr)
	})

	t.Run("unauthorized user - should panic", func(t *testing.T) {
		defer func() {
			if r := recover(); r == nil {
				t.Error("RequireAuthorized should panic for unauthorized user")
			}
		}()
		RequireAuthorized(prbac.ROLE_ADMIN, addr01)
	})

	t.Run("authorized governance - should not panic", func(t *testing.T) {
		defer func() {
			if r := recover(); r != nil {
				t.Errorf("RequireAuthorized should not panic for authorized governance, but got: %v", r)
			}
		}()
		RequireAuthorized(prbac.ROLE_GOVERNANCE, testGovAddr)
	})
}

func TestAdminAuthorization(t *testing.T) {
	setupTestRoles()

	t.Run("admin is authorized", func(t *testing.T) {
		uassert.True(t, IsAuthorized(prbac.ROLE_ADMIN, testAdminAddr))
	})

	t.Run("non-admin is not authorized", func(t *testing.T) {
		uassert.False(t, IsAuthorized(prbac.ROLE_ADMIN, addr01))
	})
}

func TestGovernanceAuthorization(t *testing.T) {
	setupTestRoles()

	t.Run("governance is authorized", func(t *testing.T) {
		uassert.True(t, IsAuthorized(prbac.ROLE_GOVERNANCE, testGovAddr))
	})

	t.Run("non-governance is not authorized", func(t *testing.T) {
		uassert.False(t, IsAuthorized(prbac.ROLE_GOVERNANCE, addr01))
	})
}

func TestGovStakerAuthorization(t *testing.T) {
	setupTestRoles()

	t.Run("gov staker is authorized", func(t *testing.T) {
		uassert.True(t, IsAuthorized(prbac.ROLE_GOV_STAKER, testGovStakerAddr))
	})

	t.Run("non-gov staker is not authorized", func(t *testing.T) {
		uassert.False(t, IsAuthorized(prbac.ROLE_GOV_STAKER, addr01))
	})
}

func TestRouterAuthorization(t *testing.T) {
	setupTestRoles()

	t.Run("router is authorized", func(t *testing.T) {
		uassert.True(t, IsAuthorized(prbac.ROLE_ROUTER, testRouterAddr))
	})

	t.Run("non-router is not authorized", func(t *testing.T) {
		uassert.False(t, IsAuthorized(prbac.ROLE_ROUTER, addr01))
	})
}

func TestPositionAuthorization(t *testing.T) {
	setupTestRoles()

	t.Run("position is authorized", func(t *testing.T) {
		uassert.True(t, IsAuthorized(prbac.ROLE_POSITION, testPositionAddr))
	})

	t.Run("non-position is not authorized", func(t *testing.T) {
		uassert.False(t, IsAuthorized(prbac.ROLE_POSITION, addr01))
	})
}

func TestPoolAuthorization(t *testing.T) {
	setupTestRoles()

	t.Run("pool is authorized", func(t *testing.T) {
		uassert.True(t, IsAuthorized(prbac.ROLE_POOL, testPoolAddr))
	})

	t.Run("non-pool is not authorized", func(t *testing.T) {
		uassert.False(t, IsAuthorized(prbac.ROLE_POOL, addr01))
	})
}

func TestStakerAuthorization(t *testing.T) {
	setupTestRoles()

	t.Run("staker is authorized", func(t *testing.T) {
		uassert.True(t, IsAuthorized(prbac.ROLE_STAKER, testStakerAddr))
	})

	t.Run("non-staker is not authorized", func(t *testing.T) {
		uassert.False(t, IsAuthorized(prbac.ROLE_STAKER, addr01))
	})
}

func TestLaunchpadAuthorization(t *testing.T) {
	setupTestRoles()

	t.Run("launchpad is authorized", func(t *testing.T) {
		uassert.True(t, IsAuthorized(prbac.ROLE_LAUNCHPAD, testLaunchpadAddr))
	})

	t.Run("non-launchpad is not authorized", func(t *testing.T) {
		uassert.False(t, IsAuthorized(prbac.ROLE_LAUNCHPAD, addr01))
	})
}

func TestEmissionAuthorization(t *testing.T) {
	setupTestRoles()

	t.Run("emission is authorized", func(t *testing.T) {
		uassert.True(t, IsAuthorized(prbac.ROLE_EMISSION, testEmissionAddr))
	})

	t.Run("non-emission is not authorized", func(t *testing.T) {
		uassert.False(t, IsAuthorized(prbac.ROLE_EMISSION, addr01))
	})
}

func TestUserOnly(t *testing.T) {
	t.Run("caller is user", func(t *testing.T) {
		uassert.NoError(t, UserOnly(std.NewUserRealm(addr01)))
	})

	t.Run("caller is not user", func(t *testing.T) {
		uassert.Error(t, UserOnly(std.NewCodeRealm("gno.land/r/realm")))
	})
}

// TestAccessFunctions_EdgeCases tests edge cases for all access functions
func TestAccessFunctions_EdgeCases(t *testing.T) {
	setupTestRoles()
	zeroAddr := std.Address("")

	t.Run("AssertCaller with empty addresses", func(t *testing.T) {
		uassert.NoError(t, AssertCaller(zeroAddr, zeroAddr))
		uassert.Error(t, AssertCaller(addr01, zeroAddr))
		uassert.Error(t, AssertCaller(zeroAddr, addr01))
	})

	t.Run("IsAuthorized with zero address", func(t *testing.T) {
		uassert.False(t, IsAuthorized(prbac.ROLE_ADMIN, zeroAddr))
		uassert.False(t, IsAuthorized(prbac.ROLE_GOVERNANCE, zeroAddr))
	})

	t.Run("All role-based authorization with correct addresses", func(t *testing.T) {
		// Test that all roles authorize their respective addresses
		uassert.True(t, IsAuthorized(prbac.ROLE_ADMIN, testAdminAddr))
		uassert.True(t, IsAuthorized(prbac.ROLE_GOVERNANCE, testGovAddr))
		uassert.True(t, IsAuthorized(prbac.ROLE_GOV_STAKER, testGovStakerAddr))
		uassert.True(t, IsAuthorized(prbac.ROLE_ROUTER, testRouterAddr))
		uassert.True(t, IsAuthorized(prbac.ROLE_POOL, testPoolAddr))
		uassert.True(t, IsAuthorized(prbac.ROLE_POSITION, testPositionAddr))
		uassert.True(t, IsAuthorized(prbac.ROLE_STAKER, testStakerAddr))
		uassert.True(t, IsAuthorized(prbac.ROLE_LAUNCHPAD, testLaunchpadAddr))
		uassert.True(t, IsAuthorized(prbac.ROLE_EMISSION, testEmissionAddr))
	})

	t.Run("RequireAuthorized panic behavior", func(t *testing.T) {
		// Test that RequireAuthorized panics for unauthorized users
		defer func() {
			if r := recover(); r == nil {
				t.Error("RequireAuthorized should panic for unauthorized user")
			}
		}()
		RequireAuthorized(prbac.ROLE_ADMIN, addr01)
	})

	t.Run("Error message format validation", func(t *testing.T) {
		err := AssertCaller(addr01, addr02)
		uassert.Error(t, err)
		uassert.True(t, len(err.Error()) > 0)

		// Check that error contains the caller address
		errorMsg := err.Error()
		uassert.True(t, len(errorMsg) > len(addr01.String()))
	})
}
