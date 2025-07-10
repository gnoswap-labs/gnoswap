package referral

import (
	"std"
	"testing"

	"gno.land/p/demo/testutils"
	"gno.land/p/demo/uassert"

	"gno.land/r/gnoswap/v1/access"
)

var (
	// Test addresses for security tests
	secAddr1      = testutils.TestAddress("sec1")
	secAddr2      = testutils.TestAddress("sec2")
	maliciousAddr = testutils.TestAddress("malicious")
)

func setupSecurityKeeper() *keeper {
	return NewKeeper().(*keeper)
}

func mockAuthorizedCaller() func() {
	origCaller := std.OriginCaller()
	routerAddr, _ := access.GetAddress(access.ROLE_ROUTER)
	testing.SetOriginCaller(routerAddr)
	return func() {
		testing.SetOriginCaller(origCaller)
	}
}

func mockUnauthorizedCaller() func() {
	origCaller := std.OriginCaller()
	testing.SetOriginCaller(maliciousAddr)
	return func() {
		testing.SetOriginCaller(origCaller)
	}
}

// TestUnauthorizedAccess tests that unauthorized callers cannot perform operations
func TestUnauthorizedAccess(t *testing.T) {
	k := setupSecurityKeeper()

	t.Run("unauthorized register", func(t *testing.T) {
		cleanup := mockUnauthorizedCaller()
		defer cleanup()

		err := k.register(secAddr1, secAddr2)
		uassert.Error(t, err)
		uassert.True(t, err.Error() != "")
	})

	t.Run("unauthorized update", func(t *testing.T) {
		cleanup := mockUnauthorizedCaller()
		defer cleanup()

		err := k.update(secAddr1, secAddr2)
		uassert.Error(t, err)
		uassert.True(t, err.Error() != "")
	})

	t.Run("unauthorized remove", func(t *testing.T) {
		cleanup := mockUnauthorizedCaller()
		defer cleanup()

		err := k.remove(secAddr1)
		uassert.Error(t, err)
		uassert.True(t, err.Error() != "")
	})
}

// TestValidCallerAccess tests that authorized callers can perform operations
func TestValidCallerAccess(t *testing.T) {
	t.Run("authorized register", func(t *testing.T) {
		k := setupSecurityKeeper()
		cleanup := mockAuthorizedCaller()
		defer cleanup()

		validAddr1 := testutils.TestAddress("validReg1")
		validAddr2 := testutils.TestAddress("validReg2")

		err := k.register(validAddr1, validAddr2)
		uassert.NoError(t, err)
		uassert.True(t, k.has(validAddr1))
	})

	t.Run("authorized update", func(t *testing.T) {
		k := setupSecurityKeeper()
		cleanup := mockAuthorizedCaller()
		defer cleanup()

		validUpAddr1 := testutils.TestAddress("validUp1")
		validUpAddr2 := testutils.TestAddress("validUp2")
		validUpAddr3 := testutils.TestAddress("validUp3")

		// First register
		err := k.register(validUpAddr1, validUpAddr2)
		uassert.NoError(t, err)

		// Mock time to bypass rate limit
		k.lastOps[validUpAddr1.String()] = 0

		// Then update
		err = k.update(validUpAddr1, validUpAddr3)
		uassert.NoError(t, err)

		// Verify update
		refAddr, err := k.get(validUpAddr1)
		uassert.NoError(t, err)
		uassert.Equal(t, validUpAddr3.String(), refAddr.String())
	})

	t.Run("authorized remove", func(t *testing.T) {
		k := setupSecurityKeeper()
		cleanup := mockAuthorizedCaller()
		defer cleanup()

		validRemAddr1 := testutils.TestAddress("validRem1")
		validRemAddr2 := testutils.TestAddress("validRem2")

		// First register
		err := k.register(validRemAddr1, validRemAddr2)
		uassert.NoError(t, err)

		// Mock time to bypass rate limit
		k.lastOps[validRemAddr1.String()] = 0

		// Then remove
		err = k.remove(validRemAddr1)
		uassert.NoError(t, err)
		uassert.False(t, k.has(validRemAddr1))
	})
}

// TestInputSanitization tests that inputs are properly validated
func TestInputSanitization(t *testing.T) {
	k := setupSecurityKeeper()
	cleanup := mockAuthorizedCaller()
	defer cleanup()

	t.Run("invalid addresses rejected", func(t *testing.T) {
		invalidAddr := std.Address("invalid")
		err := k.register(invalidAddr, secAddr1)
		uassert.Error(t, err)
		uassert.Error(t, err)
		uassert.Equal(t, ErrInvalidAddress.Error(), err.Error())
	})

	t.Run("self referral prevented", func(t *testing.T) {
		err := k.register(secAddr1, secAddr1)
		uassert.Error(t, err)
		uassert.Error(t, err)
		uassert.Equal(t, ErrSelfReferral.Error(), err.Error())
	})

	t.Run("zero address handling", func(t *testing.T) {
		// Register first
		err := k.register(secAddr1, secAddr2)
		uassert.NoError(t, err)

		// Mock time to bypass rate limit
		k.lastOps[secAddr1.String()] = 0

		// Setting referral to zero address should remove it
		err = k.setReferral(secAddr1, zeroAddress, EventTypeUpdate)
		uassert.NoError(t, err)
		uassert.False(t, k.has(secAddr1))
	})
}

// TestRateLimitingSecurity tests rate limiting as a security feature
func TestRateLimitingSecurity(t *testing.T) {
	k := setupSecurityKeeper()
	cleanup := mockAuthorizedCaller()
	defer cleanup()

	t.Run("prevents rapid fire operations", func(t *testing.T) {
		// First operation should succeed
		err := k.register(secAddr1, secAddr2)
		uassert.NoError(t, err)

		// Immediate second operation should fail
		err = k.update(secAddr1, maliciousAddr)
		uassert.Error(t, err)
		uassert.Equal(t, ErrTooManyRequests.Error(), err.Error())

		// Verify original referral is unchanged
		refAddr, err := k.get(secAddr1)
		uassert.NoError(t, err)
		uassert.Equal(t, secAddr2.String(), refAddr.String())
	})

	t.Run("rate limit applies per address", func(t *testing.T) {
		k1 := setupSecurityKeeper()
		cleanup := mockAuthorizedCaller()
		defer cleanup()

		// Use unique addresses to avoid conflicts
		rateAddr1 := testutils.TestAddress("rateSecAddr1")
		rateAddr2 := testutils.TestAddress("rateSecAddr2")
		rateAddr3 := testutils.TestAddress("rateSecAddr3")

		// Register different addresses
		err := k1.register(rateAddr1, rateAddr2)
		uassert.NoError(t, err)

		// Different address should not be rate limited
		err = k1.register(rateAddr3, rateAddr1)
		uassert.NoError(t, err)

		// But same address should still be rate limited
		err = k1.update(rateAddr1, rateAddr3)
		uassert.Error(t, err)
		uassert.Equal(t, ErrTooManyRequests.Error(), err.Error())
	})
}

// TestStateIntegrity tests that the internal state remains consistent
func TestStateIntegrity(t *testing.T) {
	k := setupSecurityKeeper()
	cleanup := mockAuthorizedCaller()
	defer cleanup()

	t.Run("consistent state after operations", func(t *testing.T) {
		// Register
		err := k.register(secAddr1, secAddr2)
		uassert.NoError(t, err)

		// State should be consistent
		uassert.True(t, k.has(secAddr1))
		refAddr, err := k.get(secAddr1)
		uassert.NoError(t, err)
		uassert.Equal(t, secAddr2.String(), refAddr.String())

		// Mock time to bypass rate limit
		k.lastOps[secAddr1.String()] = 0

		// Remove
		err = k.remove(secAddr1)
		uassert.NoError(t, err)

		// State should be consistent
		uassert.False(t, k.has(secAddr1))
		_, err = k.get(secAddr1)
		uassert.Error(t, err)
		uassert.Equal(t, ErrNotFound.Error(), err.Error())
	})

	t.Run("storage isolation", func(t *testing.T) {
		// Register multiple addresses
		err := k.register(secAddr1, secAddr2)
		uassert.NoError(t, err)

		err = k.register(maliciousAddr, secAddr1)
		uassert.NoError(t, err)

		// Operations on one should not affect the other
		uassert.True(t, k.has(secAddr1))
		uassert.True(t, k.has(maliciousAddr))

		// Mock time to bypass rate limit
		k.lastOps[secAddr1.String()] = 0

		// Remove one
		err = k.remove(secAddr1)
		uassert.NoError(t, err)

		// Only the removed one should be affected
		uassert.False(t, k.has(secAddr1))
		uassert.True(t, k.has(maliciousAddr))
	})
}

// TestCallerValidation tests the caller validation logic
func TestCallerValidation(t *testing.T) {
	t.Run("valid caller roles", func(t *testing.T) {
		validRoles := []string{
			access.ROLE_GOVERNANCE,
			access.ROLE_GOV_STAKER,
			access.ROLE_ROUTER,
			access.ROLE_POSITION,
			access.ROLE_STAKER,
			access.ROLE_LAUNCHPAD,
		}

		for _, role := range validRoles {
			addr, err := access.GetAddress(role)
			uassert.NoError(t, err)

			err = isValidCaller(addr)
			uassert.NoError(t, err)
		}
	})

	t.Run("invalid caller rejected", func(t *testing.T) {
		err := isValidCaller(maliciousAddr)
		uassert.Error(t, err)
		uassert.True(t, err.Error() != "")
	})
}
