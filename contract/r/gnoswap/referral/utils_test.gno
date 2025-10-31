package referral

import (
	"testing"

	"gno.land/p/nt/testutils"
	"gno.land/p/nt/uassert"

	prabc "gno.land/p/gnoswap/rbac"

	"gno.land/r/gnoswap/access"
)

func TestIsValidCaller_AllAuthorizedRoles(t *testing.T) {
	tests := []struct {
		name     string
		roleName string
	}{
		{
			name:     "ROLE_GOVERNANCE is authorized",
			roleName: prabc.ROLE_GOVERNANCE.String(),
		},
		{
			name:     "ROLE_GOV_STAKER is authorized",
			roleName: prabc.ROLE_GOV_STAKER.String(),
		},
		{
			name:     "ROLE_ROUTER is authorized",
			roleName: prabc.ROLE_ROUTER.String(),
		},
		{
			name:     "ROLE_POSITION is authorized",
			roleName: prabc.ROLE_POSITION.String(),
		},
		{
			name:     "ROLE_STAKER is authorized",
			roleName: prabc.ROLE_STAKER.String(),
		},
		{
			name:     "ROLE_LAUNCHPAD is authorized",
			roleName: prabc.ROLE_LAUNCHPAD.String(),
		},
	}

	for _, tc := range tests {
		t.Run(tc.name, func(t *testing.T) {
			// given
			roleAddr, ok := access.GetAddress(tc.roleName)
			if !ok {
				t.Skip("Role address not configured, skipping test")
			}

			// when
			err := isValidCaller(roleAddr)

			// then
			uassert.NoError(t, err)
		})
	}
}

func TestIsValidCaller_UnauthorizedCallers(t *testing.T) {
	tests := []struct {
		name   string
		caller address
	}{
		{
			name:   "unauthorized random address",
			caller: testutils.TestAddress("unauthorized1"),
		},
		{
			name:   "unauthorized user address",
			caller: testutils.TestAddress("user123"),
		},
		{
			name:   "unauthorized contract address",
			caller: testutils.TestAddress("contract456"),
		},
	}

	for _, tc := range tests {
		t.Run(tc.name, func(t *testing.T) {
			// when
			err := isValidCaller(tc.caller)

			// then
			uassert.Error(t, err)
		})
	}
}

func TestIsValidCaller_EdgeCases(t *testing.T) {
	tests := []struct {
		name   string
		caller address
	}{
		{
			name:   "zero address is unauthorized",
			caller: zeroAddress,
		},
		{
			name:   "invalid format address is unauthorized",
			caller: address("invalid"),
		},
	}

	for _, tc := range tests {
		t.Run(tc.name, func(t *testing.T) {
			// when
			err := isValidCaller(tc.caller)

			// then
			uassert.Error(t, err)
		})
	}
}

func TestIsValidCaller_MultipleRolesConsistency(t *testing.T) {
	// Test that multiple calls with the same authorized role return consistent results
	t.Run("consistent authorization for same role", func(t *testing.T) {
		// given
		routerAddr, ok := access.GetAddress(prabc.ROLE_ROUTER.String())
		if !ok {
			t.Skip("Router address not configured, skipping test")
		}

		// when & then - call multiple times
		for i := 0; i < 5; i++ {
			err := isValidCaller(routerAddr)
			uassert.NoError(t, err)
		}
	})

	t.Run("consistent rejection for unauthorized caller", func(t *testing.T) {
		// given
		unauthorizedAddr := testutils.TestAddress("unauthorized")

		// when & then - call multiple times
		for i := 0; i < 5; i++ {
			err := isValidCaller(unauthorizedAddr)
			uassert.Error(t, err)
		}
	})
}

func TestIsValidCaller_RoleIsolation(t *testing.T) {
	// Test that authorization is properly isolated by role
	t.Run("different authorized roles all work", func(t *testing.T) {
		roles := []string{
			prabc.ROLE_GOVERNANCE.String(),
			prabc.ROLE_ROUTER.String(),
			prabc.ROLE_POSITION.String(),
		}

		for _, roleName := range roles {
			roleAddr, ok := access.GetAddress(roleName)
			if !ok {
				continue // Skip if role not configured
			}

			err := isValidCaller(roleAddr)
			uassert.NoError(t, err)
		}
	})

	t.Run("unauthorized address between authorized roles", func(t *testing.T) {
		// given
		routerAddr, ok1 := access.GetAddress(prabc.ROLE_ROUTER.String())
		positionAddr, ok2 := access.GetAddress(prabc.ROLE_POSITION.String())

		if !ok1 || !ok2 {
			t.Skip("Role addresses not configured, skipping test")
		}

		unauthorizedAddr := testutils.TestAddress("between")

		// when
		routerErr := isValidCaller(routerAddr)
		unauthorizedErr := isValidCaller(unauthorizedAddr)
		positionErr := isValidCaller(positionAddr)

		// then
		uassert.NoError(t, routerErr)
		uassert.Error(t, unauthorizedErr)
		uassert.NoError(t, positionErr)
	})
}
