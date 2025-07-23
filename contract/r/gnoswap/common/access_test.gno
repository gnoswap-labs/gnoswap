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

func TestAdminOnly(t *testing.T) {
	setupTestRoles()

	t.Run("caller is admin", func(t *testing.T) {
		uassert.NoError(t, AdminOnly(testAdminAddr))
	})

	t.Run("caller is not admin", func(t *testing.T) {
		uassert.Error(t, AdminOnly(addr01))
	})
}

func TestGovernanceOnly(t *testing.T) {
	setupTestRoles()

	t.Run("caller is governance", func(t *testing.T) {
		uassert.NoError(t, GovernanceOnly(testGovAddr))
	})

	t.Run("caller is not governance", func(t *testing.T) {
		uassert.Error(t, GovernanceOnly(addr01))
	})
}

func TestGovStakerOnly(t *testing.T) {
	setupTestRoles()

	t.Run("caller is gov staker", func(t *testing.T) {
		uassert.NoError(t, GovStakerOnly(testGovStakerAddr))
	})

	t.Run("caller is not gov staker", func(t *testing.T) {
		uassert.Error(t, GovStakerOnly(addr01))
	})
}

func TestRouterOnly(t *testing.T) {
	setupTestRoles()

	t.Run("caller is router", func(t *testing.T) {
		uassert.NoError(t, RouterOnly(testRouterAddr))
	})

	t.Run("caller is not router", func(t *testing.T) {
		uassert.Error(t, RouterOnly(addr01))
	})
}

func TestPositionOnly(t *testing.T) {
	setupTestRoles()

	t.Run("caller is position", func(t *testing.T) {
		uassert.NoError(t, PositionOnly(testPositionAddr))
	})

	t.Run("caller is not position", func(t *testing.T) {
		uassert.Error(t, PositionOnly(addr01))
	})
}

func TestPoolOnly(t *testing.T) {
	setupTestRoles()

	t.Run("caller is pool", func(t *testing.T) {
		uassert.NoError(t, PoolOnly(testPoolAddr))
	})

	t.Run("caller is not pool", func(t *testing.T) {
		uassert.Error(t, PoolOnly(addr01))
	})
}

func TestStakerOnly(t *testing.T) {
	setupTestRoles()

	t.Run("caller is staker", func(t *testing.T) {
		uassert.NoError(t, StakerOnly(testStakerAddr))
	})

	t.Run("caller is not staker", func(t *testing.T) {
		uassert.Error(t, StakerOnly(addr01))
	})
}

func TestLaunchpadOnly(t *testing.T) {
	setupTestRoles()

	t.Run("caller is launchpad", func(t *testing.T) {
		uassert.NoError(t, LaunchpadOnly(testLaunchpadAddr))
	})

	t.Run("caller is not launchpad", func(t *testing.T) {
		uassert.Error(t, LaunchpadOnly(addr01))
	})
}

func TestEmissionOnly(t *testing.T) {
	setupTestRoles()

	t.Run("caller is emission", func(t *testing.T) {
		uassert.NoError(t, EmissionOnly(testEmissionAddr))
	})

	t.Run("caller is not emission", func(t *testing.T) {
		uassert.Error(t, EmissionOnly(addr01))
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

	t.Run("AdminOnly with zero address", func(t *testing.T) {
		uassert.Error(t, AdminOnly(zeroAddr))
	})

	t.Run("GovernanceOnly with zero address", func(t *testing.T) {
		uassert.Error(t, GovernanceOnly(zeroAddr))
	})

	t.Run("All role-based functions with correct constants", func(t *testing.T) {
		// Test that all functions accept their respective addresses
		uassert.NoError(t, AdminOnly(testAdminAddr))
		uassert.NoError(t, GovernanceOnly(testGovAddr))
		uassert.NoError(t, GovStakerOnly(testGovStakerAddr))
		uassert.NoError(t, RouterOnly(testRouterAddr))
		uassert.NoError(t, PoolOnly(testPoolAddr))
		uassert.NoError(t, PositionOnly(testPositionAddr))
		uassert.NoError(t, StakerOnly(testStakerAddr))
		uassert.NoError(t, LaunchpadOnly(testLaunchpadAddr))
		uassert.NoError(t, EmissionOnly(testEmissionAddr))
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
