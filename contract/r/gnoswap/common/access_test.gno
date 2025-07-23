package common

import (
	"std"
	"testing"

	"gno.land/p/demo/testutils"
	"gno.land/p/demo/uassert"

	"gno.land/r/gnoswap/v1/access"
)

var (
	addr01 = testutils.TestAddress("addr01")
	addr02 = testutils.TestAddress("addr02")
)

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
	adminAddr, _ := access.GetAddress(access.ROLE_ADMIN)

	t.Run("caller is admin", func(t *testing.T) {
		uassert.NoError(t, AdminOnly(adminAddr))
	})

	t.Run("caller is not admin", func(t *testing.T) {
		uassert.Error(t, AdminOnly(addr01))
	})
}

func TestGovernanceOnly(t *testing.T) {
	govAddr, _ := access.GetAddress(access.ROLE_GOVERNANCE)

	t.Run("caller is governance", func(t *testing.T) {
		uassert.NoError(t, GovernanceOnly(govAddr))
	})

	t.Run("caller is not governance", func(t *testing.T) {
		uassert.Error(t, GovernanceOnly(addr01))
	})
}

func TestGovStakerOnly(t *testing.T) {
	govStakerAddr, _ := access.GetAddress(access.ROLE_GOV_STAKER)

	t.Run("caller is gov staker", func(t *testing.T) {
		uassert.NoError(t, GovStakerOnly(govStakerAddr))
	})

	t.Run("caller is not gov staker", func(t *testing.T) {
		uassert.Error(t, GovStakerOnly(addr01))
	})
}

func TestRouterOnly(t *testing.T) {
	routerAddr, _ := access.GetAddress(access.ROLE_ROUTER)

	t.Run("caller is router", func(t *testing.T) {
		uassert.NoError(t, RouterOnly(routerAddr))
	})

	t.Run("caller is not router", func(t *testing.T) {
		uassert.Error(t, RouterOnly(addr01))
	})
}

func TestPositionOnly(t *testing.T) {
	positionAddr, _ := access.GetAddress(access.ROLE_POSITION)

	t.Run("caller is position", func(t *testing.T) {
		uassert.NoError(t, PositionOnly(positionAddr))
	})

	t.Run("caller is not position", func(t *testing.T) {
		uassert.Error(t, PositionOnly(addr01))
	})
}

func TestPoolOnly(t *testing.T) {
	poolAddr, _ := access.GetAddress(access.ROLE_POOL)

	t.Run("caller is pool", func(t *testing.T) {
		uassert.NoError(t, PoolOnly(poolAddr))
	})

	t.Run("caller is not pool", func(t *testing.T) {
		uassert.Error(t, PoolOnly(addr01))
	})
}

func TestStakerOnly(t *testing.T) {
	stakerAddr, _ := access.GetAddress(access.ROLE_STAKER)

	t.Run("caller is staker", func(t *testing.T) {
		uassert.NoError(t, StakerOnly(stakerAddr))
	})

	t.Run("caller is not staker", func(t *testing.T) {
		uassert.Error(t, StakerOnly(addr01))
	})
}

func TestLaunchpadOnly(t *testing.T) {
	launchpadAddr, _ := access.GetAddress(access.ROLE_LAUNCHPAD)

	t.Run("caller is launchpad", func(t *testing.T) {
		uassert.NoError(t, LaunchpadOnly(launchpadAddr))
	})

	t.Run("caller is not launchpad", func(t *testing.T) {
		uassert.Error(t, LaunchpadOnly(addr01))
	})
}

func TestEmissionOnly(t *testing.T) {
	emissionAddr, _ := access.GetAddress(access.ROLE_EMISSION)

	t.Run("caller is emission", func(t *testing.T) {
		uassert.NoError(t, EmissionOnly(emissionAddr))
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
		// Get addresses from access package
		adminAddr, _ := access.GetAddress(access.ROLE_ADMIN)
		govAddr, _ := access.GetAddress(access.ROLE_GOVERNANCE)
		govStakerAddr, _ := access.GetAddress(access.ROLE_GOV_STAKER)
		routerAddr, _ := access.GetAddress(access.ROLE_ROUTER)
		poolAddr, _ := access.GetAddress(access.ROLE_POOL)
		positionAddr, _ := access.GetAddress(access.ROLE_POSITION)
		stakerAddr, _ := access.GetAddress(access.ROLE_STAKER)
		launchpadAddr, _ := access.GetAddress(access.ROLE_LAUNCHPAD)
		emissionAddr, _ := access.GetAddress(access.ROLE_EMISSION)

		// Test that all functions accept their respective addresses
		uassert.NoError(t, AdminOnly(adminAddr))
		uassert.NoError(t, GovernanceOnly(govAddr))
		uassert.NoError(t, GovStakerOnly(govStakerAddr))
		uassert.NoError(t, RouterOnly(routerAddr))
		uassert.NoError(t, PoolOnly(poolAddr))
		uassert.NoError(t, PositionOnly(positionAddr))
		uassert.NoError(t, StakerOnly(stakerAddr))
		uassert.NoError(t, LaunchpadOnly(launchpadAddr))
		uassert.NoError(t, EmissionOnly(emissionAddr))
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
