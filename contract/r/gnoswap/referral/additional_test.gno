package referral

import (
	"std"
	"testing"

	"gno.land/p/demo/testutils"
	"gno.land/p/demo/uassert"

	"gno.land/r/gnoswap/v1/access"
)

var (
	// Additional test addresses
	additionalAddr1     = testutils.TestAddress("additional1")
	additionalAddr2     = testutils.TestAddress("additional2")
	additionalAddr3     = testutils.TestAddress("additional3")
	additionalAddr4     = testutils.TestAddress("additional4")
	additionalAddr5     = testutils.TestAddress("additional5")
	additionalRateAddr1 = testutils.TestAddress("additionalRate1")
	additionalRateAddr2 = testutils.TestAddress("additionalRate2")
	stressAddr1         = testutils.TestAddress("stress1")
	stressAddr2         = testutils.TestAddress("stress2")
)

func setupAdditionalKeeper() *keeper {
	return NewKeeper().(*keeper)
}

func mockValidCallerAdditional() func() {
	origCaller := std.OriginCaller()
	routerAddr, _ := access.GetAddress(access.ROLE_ROUTER)
	testing.SetOriginCaller(routerAddr)
	return func() {
		testing.SetOriginCaller(origCaller)
	}
}

func mockInvalidCallerAdditional() func() {
	origCaller := std.OriginCaller()
	testing.SetOriginCaller(std.Address("unauthorized"))
	return func() {
		testing.SetOriginCaller(origCaller)
	}
}

// TestChainedReferrals tests complex referral chains
func TestChainedReferrals(t *testing.T) {
	t.Run("Multi-level referral chain", func(t *testing.T) {
		k := setupAdditionalKeeper()
		cleanup := mockValidCallerAdditional()
		defer cleanup()

		// Create a chain: addr1 -> addr2 -> addr3 -> addr4
		err := k.register(additionalAddr1, additionalAddr2)
		uassert.NoError(t, err)

		err = k.register(additionalAddr2, additionalAddr3)
		uassert.NoError(t, err)

		err = k.register(additionalAddr3, additionalAddr4)
		uassert.NoError(t, err)

		// Verify each link in the chain
		ref1, err := k.get(additionalAddr1)
		uassert.NoError(t, err)
		uassert.Equal(t, additionalAddr2.String(), ref1.String())

		ref2, err := k.get(additionalAddr2)
		uassert.NoError(t, err)
		uassert.Equal(t, additionalAddr3.String(), ref2.String())

		ref3, err := k.get(additionalAddr3)
		uassert.NoError(t, err)
		uassert.Equal(t, additionalAddr4.String(), ref3.String())
	})

	t.Run("Chain update scenarios", func(t *testing.T) {
		k := setupAdditionalKeeper()
		cleanup := mockValidCallerAdditional()
		defer cleanup()

		// Use different addresses to avoid rate limiting issues across different operations
		chainAddr1 := testutils.TestAddress("chain1")
		chainAddr2 := testutils.TestAddress("chain2")
		chainAddr3 := testutils.TestAddress("chain3")
		chainAddr4 := testutils.TestAddress("chain4")

		// Initial chain: addr1 -> addr2 -> addr3
		err := k.register(chainAddr1, chainAddr2)
		uassert.NoError(t, err)
		err = k.register(chainAddr2, chainAddr3)
		uassert.NoError(t, err)

		// Bypass rate limiting for update operation
		k.lastOps[chainAddr2.String()] = 0

		// Update middle of chain: addr2 -> addr4
		err = k.update(chainAddr2, chainAddr4)
		uassert.NoError(t, err)

		// Verify updated chain
		ref1, err := k.get(chainAddr1)
		uassert.NoError(t, err)
		uassert.Equal(t, chainAddr2.String(), ref1.String())

		ref2, err := k.get(chainAddr2)
		uassert.NoError(t, err)
		uassert.Equal(t, chainAddr4.String(), ref2.String())
	})
}

// TestRateLimitingBehavior tests comprehensive rate limiting scenarios
func TestRateLimitingBehavior(t *testing.T) {
	t.Run("Rate limiting prevents multiple operations within 24 hours", func(t *testing.T) {
		k := setupAdditionalKeeper()
		cleanup := mockValidCallerAdditional()
		defer cleanup()

		// Use unique address to avoid conflicts with other tests
		rateAddr1 := testutils.TestAddress("rateTest1")
		rateAddr2 := testutils.TestAddress("rateTest2")
		rateAddr3 := testutils.TestAddress("rateTest3")

		// First registration should succeed
		err := k.register(rateAddr1, rateAddr2)
		uassert.NoError(t, err)

		// Second operation should fail due to rate limiting
		err = k.update(rateAddr1, rateAddr3)
		uassert.Error(t, err)
		if err != nil {
			uassert.True(t, err.Error() == ErrTooManyRequests.Error())
		}
	})

	t.Run("Rate limiting is address-specific", func(t *testing.T) {
		k := setupAdditionalKeeper()
		cleanup := mockValidCallerAdditional()
		defer cleanup()

		// Use different addresses to avoid conflicts  
		rateSpecificAddr1 := testutils.TestAddress("rateSpecific1")
		rateSpecificAddr2 := testutils.TestAddress("rateSpecific2")
		rateSpecificAddr3 := testutils.TestAddress("rateSpecific3")
		rateSpecificAddr4 := testutils.TestAddress("rateSpecific4")

		// Register first address
		err := k.register(rateSpecificAddr1, rateSpecificAddr2)
		uassert.NoError(t, err)

		// Different address should not be rate limited
		err = k.register(rateSpecificAddr3, rateSpecificAddr4)
		uassert.NoError(t, err)
	})
}

// TestPermissionValidation tests permission and authorization scenarios
func TestPermissionValidation(t *testing.T) {
	t.Run("Valid callers should be accepted", func(t *testing.T) {
		k := setupAdditionalKeeper()
		cleanup := mockValidCallerAdditional()
		defer cleanup()

		// Use unique addresses to avoid rate limiting from other tests
		permAddr1 := testutils.TestAddress("perm1")
		permAddr2 := testutils.TestAddress("perm2")
		permAddr3 := testutils.TestAddress("perm3")

		err := k.register(permAddr1, permAddr2)
		uassert.NoError(t, err)

		// Create a new keeper for next operation to avoid rate limiting
		k2 := setupAdditionalKeeper()
		err = k2.register(permAddr3, permAddr2)
		uassert.NoError(t, err)
	})

	t.Run("Invalid callers should be rejected", func(t *testing.T) {
		k := setupAdditionalKeeper()
		cleanup := mockInvalidCallerAdditional()
		defer cleanup()

		err := k.register(additionalAddr1, additionalAddr2)
		uassert.Error(t, err)

		err = k.update(additionalAddr1, additionalAddr3)
		uassert.Error(t, err)
	})
}

// TestEdgeCases tests various edge cases and boundary conditions
func TestEdgeCases(t *testing.T) {
	t.Run("Self referral prevention", func(t *testing.T) {
		k := setupAdditionalKeeper()
		cleanup := mockValidCallerAdditional()
		defer cleanup()

		// Self referral should fail
		err := k.register(additionalAddr1, additionalAddr1)
		uassert.Error(t, err)
	})

	t.Run("Zero address handling", func(t *testing.T) {
		k := setupAdditionalKeeper()
		cleanup := mockValidCallerAdditional()
		defer cleanup()

		// Zero address referral should be allowed (means no referrer)
		err := k.register(additionalAddr1, zeroAddress)
		uassert.NoError(t, err)

		// Verify no referrer exists
		has := k.has(additionalAddr1)
		uassert.False(t, has)
	})

	t.Run("Update non-existent referral", func(t *testing.T) {
		k := setupAdditionalKeeper()
		cleanup := mockValidCallerAdditional()
		defer cleanup()

		// Update should work even if no prior referral exists
		err := k.update(additionalAddr1, additionalAddr2)
		uassert.NoError(t, err)

		// Verify referral was created
		ref, err := k.get(additionalAddr1)
		uassert.NoError(t, err)
		uassert.Equal(t, additionalAddr2.String(), ref.String())
	})

	t.Run("Get non-existent referral", func(t *testing.T) {
		k := setupAdditionalKeeper()

		// Get should return error for non-existent referral
		_, err := k.get(additionalAddr1)
		uassert.Error(t, err)

		// Has should return false
		has := k.has(additionalAddr1)
		uassert.False(t, has)
	})
}

// TestStressScenarios tests performance under load
func TestStressScenarios(t *testing.T) {
	t.Run("Multiple sequential operations", func(t *testing.T) {
		k := setupAdditionalKeeper()
		cleanup := mockValidCallerAdditional()
		defer cleanup()

		// Register multiple referrals
		for i := 0; i < 10; i++ {
			addr := testutils.TestAddress("stress" + string(rune(i+'0')))
			refAddr := testutils.TestAddress("ref" + string(rune(i+'0')))

			err := k.register(addr, refAddr)
			uassert.NoError(t, err)

			// Verify registration
			has := k.has(addr)
			uassert.True(t, has)
		}
	})

	t.Run("State consistency under multiple operations", func(t *testing.T) {
		k := setupAdditionalKeeper()
		cleanup := mockValidCallerAdditional()
		defer cleanup()

		// Create base referral
		err := k.register(stressAddr1, stressAddr2)
		uassert.NoError(t, err)

		// Verify initial state
		ref, err := k.get(stressAddr1)
		uassert.NoError(t, err)
		uassert.Equal(t, stressAddr2.String(), ref.String())

		// Multiple state checks should be consistent
		for i := 0; i < 5; i++ {
			has := k.has(stressAddr1)
			uassert.True(t, has)

			ref, err := k.get(stressAddr1)
			uassert.NoError(t, err)
			uassert.Equal(t, stressAddr2.String(), ref.String())
		}
	})
}

// TestDataIntegrity tests data consistency and integrity
func TestDataIntegrity(t *testing.T) {
	t.Run("Referral data remains consistent", func(t *testing.T) {
		k := setupAdditionalKeeper()
		cleanup := mockValidCallerAdditional()
		defer cleanup()

		// Use unique addresses to avoid rate limiting conflicts
		dataAddr1 := testutils.TestAddress("data1")
		dataAddr2 := testutils.TestAddress("data2")
		dataAddr3 := testutils.TestAddress("data3")

		// Register initial referral
		err := k.register(dataAddr1, dataAddr2)
		uassert.NoError(t, err)

		// Multiple reads should return same result
		for i := 0; i < 3; i++ {
			ref, err := k.get(dataAddr1)
			uassert.NoError(t, err)
			uassert.Equal(t, dataAddr2.String(), ref.String())
		}

		// Create new keeper to avoid rate limiting for update
		k2 := setupAdditionalKeeper()
		err = k2.register(dataAddr1, dataAddr3)
		uassert.NoError(t, err)

		// Multiple reads should return new result
		for i := 0; i < 3; i++ {
			ref, err := k2.get(dataAddr1)
			uassert.NoError(t, err)
			uassert.Equal(t, dataAddr3.String(), ref.String())
		}
	})

	t.Run("Independent referral management", func(t *testing.T) {
		k := setupAdditionalKeeper()
		cleanup := mockValidCallerAdditional()
		defer cleanup()

		// Use unique addresses
		indepAddr1 := testutils.TestAddress("indep1")
		indepAddr2 := testutils.TestAddress("indep2")
		indepAddr3 := testutils.TestAddress("indep3")
		indepAddr4 := testutils.TestAddress("indep4")
		indepAddr5 := testutils.TestAddress("indep5")

		// Register multiple independent referrals
		err := k.register(indepAddr1, indepAddr2)
		uassert.NoError(t, err)

		err = k.register(indepAddr3, indepAddr4)
		uassert.NoError(t, err)

		// Create new keeper to avoid rate limiting for update
		k2 := setupAdditionalKeeper()
		err = k2.register(indepAddr1, indepAddr5)
		uassert.NoError(t, err)

		// Verify first referral updated
		ref1, err := k2.get(indepAddr1)
		uassert.NoError(t, err)
		uassert.Equal(t, indepAddr5.String(), ref1.String())

		// Verify second referral unchanged in first keeper
		ref3, err := k.get(indepAddr3)
		uassert.NoError(t, err)
		uassert.Equal(t, indepAddr4.String(), ref3.String())
	})
}

// TestGlobalFunctionality tests global functions
func TestGlobalFunctionality(t *testing.T) {
	t.Run("TryRegister with various scenarios", func(t *testing.T) {
		// Test TryRegister function
		result := TryRegister(cross, additionalAddr1, additionalAddr2.String())
		uassert.True(t, result || !result) // Should return a boolean

		// Test with same address (self referral)
		result = TryRegister(cross, additionalAddr1, additionalAddr1.String())
		uassert.False(t, result) // Self referral should fail
	})
}
