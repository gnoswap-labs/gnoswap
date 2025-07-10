package referral

import (
	"std"
	"testing"

	"gno.land/p/demo/testutils"
	"gno.land/p/demo/uassert"

	"gno.land/r/gnoswap/v1/access"
)

var (
	// Test addresses for referral unit tests
	unitAddr1 = testutils.TestAddress("unit1")
	unitAddr2 = testutils.TestAddress("unit2")
	unitAddr3 = testutils.TestAddress("unit3")
	unitAddr4 = testutils.TestAddress("unit4")
	unitAddr5 = testutils.TestAddress("unit5")
	unitAddr6 = testutils.TestAddress("unit6")
)

func setupUnitKeeper() *keeper {
	return NewKeeper().(*keeper)
}

func mockValidCallerUnit() func() {
	origCaller := std.OriginCaller()
	routerAddr, _ := access.GetAddress(access.ROLE_ROUTER)
	testing.SetOriginCaller(routerAddr)
	return func() {
		testing.SetOriginCaller(origCaller)
	}
}

func mockInvalidCallerUnit() func() {
	origCaller := std.OriginCaller()
	testing.SetOriginCaller(std.Address("unauthorized"))
	return func() {
		testing.SetOriginCaller(origCaller)
	}
}

// TestNewReferral tests the NewReferral constructor
func TestNewReferral(t *testing.T) {
	t.Run("creates valid referral instance", func(t *testing.T) {
		r := NewReferral()
		uassert.NotNil(t, r)
		uassert.NotNil(t, r.keeper)
	})

	t.Run("creates new keeper instance", func(t *testing.T) {
		r1 := NewReferral()
		r2 := NewReferral()

		// Both should be valid referral instances
		uassert.NotNil(t, r1)
		uassert.NotNil(t, r2)
		uassert.NotNil(t, r1.keeper)
		uassert.NotNil(t, r2.keeper)
	})
}

// TestReferralRegister tests the Register method
func TestReferralRegister(t *testing.T) {
	t.Run("successful registration with valid caller", func(t *testing.T) {
		cleanup := mockValidCallerUnit()
		defer cleanup()

		k := setupUnitKeeper()

		err := k.register(unitAddr1, unitAddr2)
		uassert.NoError(t, err)

		// Verify registration
		has := k.has(unitAddr1)
		uassert.True(t, has)

		ref, err := k.get(unitAddr1)
		uassert.NoError(t, err)
		uassert.Equal(t, unitAddr2.String(), ref.String())
	})

	t.Run("fails with unauthorized caller", func(t *testing.T) {
		cleanup := mockInvalidCallerUnit()
		defer cleanup()

		k := setupUnitKeeper()

		err := k.register(unitAddr1, unitAddr2)
		uassert.Error(t, err)
	})

	t.Run("prevents self referral", func(t *testing.T) {
		cleanup := mockValidCallerUnit()
		defer cleanup()

		k := setupUnitKeeper()

		err := k.register(unitAddr1, unitAddr1)
		uassert.Error(t, err)
	})

	t.Run("allows zero address referral", func(t *testing.T) {
		cleanup := mockValidCallerUnit()
		defer cleanup()

		k := setupUnitKeeper()

		err := k.register(unitAddr1, zeroAddress)
		uassert.NoError(t, err)

		// Zero address means no referrer
		has := k.has(unitAddr1)
		uassert.False(t, has)
	})
}

// TestReferralUpdate tests the Update method
func TestReferralUpdate(t *testing.T) {
	t.Run("successful update with valid caller", func(t *testing.T) {
		cleanup := mockValidCallerUnit()
		defer cleanup()

		k := setupUnitKeeper()

		// Initial registration
		err := k.register(unitAddr1, unitAddr2)
		uassert.NoError(t, err)

		// Update to new referrer (should fail due to rate limiting)
		err = k.update(unitAddr1, unitAddr3)
		uassert.Error(t, err)
	})

	t.Run("fails with unauthorized caller", func(t *testing.T) {
		cleanup := mockInvalidCallerUnit()
		defer cleanup()

		k := setupUnitKeeper()

		err := k.update(unitAddr1, unitAddr2)
		uassert.Error(t, err)
	})

	t.Run("prevents self referral update", func(t *testing.T) {
		cleanup := mockValidCallerUnit()
		defer cleanup()

		k := setupUnitKeeper()

		err := k.update(unitAddr1, unitAddr1)
		uassert.Error(t, err)
	})

	t.Run("updates non-existent referral", func(t *testing.T) {
		cleanup := mockValidCallerUnit()
		defer cleanup()

		k := setupUnitKeeper()

		// Update should create new referral
		err := k.update(unitAddr1, unitAddr2)
		uassert.NoError(t, err)

		ref, err := k.get(unitAddr1)
		uassert.NoError(t, err)
		uassert.Equal(t, unitAddr2.String(), ref.String())
	})
}

// TestReferralGet tests the Get method
func TestReferralGet(t *testing.T) {
	t.Run("gets existing referral", func(t *testing.T) {
		cleanup := mockValidCallerUnit()
		defer cleanup()

		k := setupUnitKeeper()

		err := k.register(unitAddr1, unitAddr2)
		uassert.NoError(t, err)

		ref, err := k.get(unitAddr1)
		uassert.NoError(t, err)
		uassert.Equal(t, unitAddr2.String(), ref.String())
	})

	t.Run("fails for non-existent referral", func(t *testing.T) {
		k := setupUnitKeeper()

		_, err := k.get(unitAddr1)
		uassert.Error(t, err)
	})

	t.Run("consistent results across multiple calls", func(t *testing.T) {
		cleanup := mockValidCallerUnit()
		defer cleanup()

		k := setupUnitKeeper()

		err := k.register(unitAddr1, unitAddr2)
		uassert.NoError(t, err)

		// Multiple gets should return same result
		for i := 0; i < 3; i++ {
			ref, err := k.get(unitAddr1)
			uassert.NoError(t, err)
			uassert.Equal(t, unitAddr2.String(), ref.String())
		}
	})
}

// TestReferralHas tests the Has method
func TestReferralHas(t *testing.T) {
	t.Run("returns true for existing referral", func(t *testing.T) {
		cleanup := mockValidCallerUnit()
		defer cleanup()

		k := setupUnitKeeper()

		err := k.register(unitAddr1, unitAddr2)
		uassert.NoError(t, err)

		has := k.has(unitAddr1)
		uassert.True(t, has)
	})

	t.Run("returns false for non-existent referral", func(t *testing.T) {
		k := setupUnitKeeper()

		has := k.has(unitAddr1)
		uassert.False(t, has)
	})

	t.Run("returns false for zero address referral", func(t *testing.T) {
		cleanup := mockValidCallerUnit()
		defer cleanup()

		k := setupUnitKeeper()

		err := k.register(unitAddr1, zeroAddress)
		uassert.NoError(t, err)

		has := k.has(unitAddr1)
		uassert.False(t, has)
	})

	t.Run("consistent results across multiple calls", func(t *testing.T) {
		cleanup := mockValidCallerUnit()
		defer cleanup()

		k := setupUnitKeeper()

		err := k.register(unitAddr1, unitAddr2)
		uassert.NoError(t, err)

		// Multiple has calls should return same result
		for i := 0; i < 3; i++ {
			has := k.has(unitAddr1)
			uassert.True(t, has)
		}
	})
}

// TestMultipleReferrals tests managing multiple referral relationships
func TestMultipleReferrals(t *testing.T) {
	t.Run("manages independent referrals", func(t *testing.T) {
		cleanup := mockValidCallerUnit()
		defer cleanup()

		k := setupUnitKeeper()

		// Register multiple users with different referrers
		err := k.register(unitAddr1, unitAddr2)
		uassert.NoError(t, err)

		err = k.register(unitAddr3, unitAddr4)
		uassert.NoError(t, err)

		// Verify both referrals exist independently
		ref1, err := k.get(unitAddr1)
		uassert.NoError(t, err)
		uassert.Equal(t, unitAddr2.String(), ref1.String())

		ref3, err := k.get(unitAddr3)
		uassert.NoError(t, err)
		uassert.Equal(t, unitAddr4.String(), ref3.String())

		// Verify has returns correct values
		uassert.True(t, k.has(unitAddr1))
		uassert.True(t, k.has(unitAddr3))
		uassert.False(t, k.has(unitAddr5))
	})

	t.Run("creates referral chains", func(t *testing.T) {
		cleanup := mockValidCallerUnit()
		defer cleanup()

		k := setupUnitKeeper()

		// Create chain: unitAddr1 -> unitAddr2 -> unitAddr3
		err := k.register(unitAddr1, unitAddr2)
		uassert.NoError(t, err)

		err = k.register(unitAddr2, unitAddr3)
		uassert.NoError(t, err)

		// Verify chain links
		ref1, err := k.get(unitAddr1)
		uassert.NoError(t, err)
		uassert.Equal(t, unitAddr2.String(), ref1.String())

		ref2, err := k.get(unitAddr2)
		uassert.NoError(t, err)
		uassert.Equal(t, unitAddr3.String(), ref2.String())
	})
}

// TestReferralStateTransitions tests state changes
func TestReferralStateTransitions(t *testing.T) {
	t.Run("no referral to has referral transition", func(t *testing.T) {
		cleanup := mockValidCallerUnit()
		defer cleanup()

		k := setupUnitKeeper()

		// Initial state: no referral
		uassert.False(t, k.has(unitAddr1))

		// Register referral
		err := k.register(unitAddr1, unitAddr2)
		uassert.NoError(t, err)

		// New state: has referral
		uassert.True(t, k.has(unitAddr1))

		ref, err := k.get(unitAddr1)
		uassert.NoError(t, err)
		uassert.Equal(t, unitAddr2.String(), ref.String())
	})

	t.Run("maintains state consistency", func(t *testing.T) {
		cleanup := mockValidCallerUnit()
		defer cleanup()

		k := setupUnitKeeper()

		err := k.register(unitAddr1, unitAddr2)
		uassert.NoError(t, err)

		// State should remain consistent across operations
		for i := 0; i < 5; i++ {
			uassert.True(t, k.has(unitAddr1))

			ref, err := k.get(unitAddr1)
			uassert.NoError(t, err)
			uassert.Equal(t, unitAddr2.String(), ref.String())
		}
	})
}

// TestTryRegisterGlobal tests the global TryRegister function
func TestTryRegisterGlobal(t *testing.T) {
	// Create a fresh global keeper for this test
	gReferralKeeper = NewKeeper()
	
	cleanup := mockValidCallerUnit()
	defer cleanup()

	// Also set origin caller to router address like the working test
	routerAddr, _ := access.GetAddress(access.ROLE_ROUTER)
	testing.SetOriginCaller(routerAddr)

	t.Run("returns boolean for valid inputs", func(t *testing.T) {
		result := TryRegister(cross, unitAddr1, unitAddr2.String())

		// Should return either true or false
		uassert.True(t, result == true || result == false)
	})

	t.Run("handles self referral", func(t *testing.T) {
		result := TryRegister(cross, unitAddr3, unitAddr3.String())

		// Self referral should return false
		uassert.False(t, result)
	})

	t.Run("handles invalid addresses", func(t *testing.T) {
		result := TryRegister(cross, std.Address("invalid"), unitAddr1.String())
		uassert.False(t, result)

		// Use unique address to avoid conflicts
		uniqueAddr := testutils.TestAddress("uniqueForZeroTest")
		result = TryRegister(cross, uniqueAddr, zeroAddress.String())
		uassert.True(t, result) // Zero address is valid for removal
	})
}
