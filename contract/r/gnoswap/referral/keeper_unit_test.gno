package referral

import (
	"std"
	"testing"

	"gno.land/p/demo/testutils"
	"gno.land/p/demo/uassert"

	prabc "gno.land/p/gnoswap/rbac"

	"gno.land/r/gnoswap/v1/access"
)

var (
	// Test addresses for keeper unit tests
	keeperAddr1 = testutils.TestAddress("keeper1")
	keeperAddr2 = testutils.TestAddress("keeper2")
	keeperAddr3 = testutils.TestAddress("keeper3")
	keeperAddr4 = testutils.TestAddress("keeper4")
	keeperAddr5 = testutils.TestAddress("keeper5")
)

func setupKeeperUnit() *keeper {
	return NewKeeper().(*keeper)
}

func mockValidCallerKeeper() func() {
	origCaller := std.OriginCaller()
	routerAddr, _ := access.GetAddress(prabc.ROLE_ROUTER.String())
	testing.SetOriginCaller(routerAddr)
	return func() {
		testing.SetOriginCaller(origCaller)
	}
}

func mockInvalidCallerKeeper() func() {
	origCaller := std.OriginCaller()
	testing.SetOriginCaller(std.Address("unauthorized"))
	return func() {
		testing.SetOriginCaller(origCaller)
	}
}

// TestKeeperSetReferral tests the internal setReferral method
func TestKeeperSetReferral(t *testing.T) {
	t.Run("sets referral with register operation", func(t *testing.T) {
		cleanup := mockValidCallerKeeper()
		defer cleanup()

		k := setupKeeperUnit()

		err := k.setReferral(keeperAddr1, keeperAddr2, EventTypeRegister)
		uassert.NoError(t, err)

		// Verify referral was set
		has := k.has(keeperAddr1)
		uassert.True(t, has)

		ref, err := k.get(keeperAddr1)
		uassert.NoError(t, err)
		uassert.Equal(t, keeperAddr2.String(), ref.String())
	})

	t.Run("sets referral with update operation", func(t *testing.T) {
		cleanup := mockValidCallerKeeper()
		defer cleanup()

		k := setupKeeperUnit()

		// Initial registration
		err := k.setReferral(keeperAddr1, keeperAddr2, EventTypeRegister)
		uassert.NoError(t, err)

		// Update should fail due to rate limiting
		err = k.setReferral(keeperAddr1, keeperAddr3, EventTypeUpdate)
		uassert.Error(t, err)
	})

	t.Run("prevents self referral", func(t *testing.T) {
		cleanup := mockValidCallerKeeper()
		defer cleanup()

		k := setupKeeperUnit()

		err := k.setReferral(keeperAddr1, keeperAddr1, EventTypeRegister)
		uassert.Error(t, err)
	})

	t.Run("handles zero address referral", func(t *testing.T) {
		cleanup := mockValidCallerKeeper()
		defer cleanup()

		k := setupKeeperUnit()

		err := k.setReferral(keeperAddr1, zeroAddress, EventTypeRegister)
		uassert.NoError(t, err)

		// Zero address means no referrer stored
		has := k.has(keeperAddr1)
		uassert.False(t, has)
	})

	t.Run("fails with unauthorized caller", func(t *testing.T) {
		cleanup := mockInvalidCallerKeeper()
		defer cleanup()

		k := setupKeeperUnit()

		err := k.setReferral(keeperAddr1, keeperAddr2, EventTypeRegister)
		uassert.Error(t, err)
	})
}

// TestKeeperValidateAddresses tests address validation
func TestKeeperValidateAddresses(t *testing.T) {
	t.Run("validates addresses through setReferral", func(t *testing.T) {
		cleanup := mockValidCallerKeeper()
		defer cleanup()

		k := setupKeeperUnit()

		// Valid address format
		err := k.setReferral(keeperAddr1, keeperAddr2, EventTypeRegister)
		uassert.NoError(t, err)

		// Self referral validation
		err = k.setReferral(keeperAddr3, keeperAddr3, EventTypeRegister)
		uassert.Error(t, err)
	})

	t.Run("rejects invalid operations through context", func(t *testing.T) {
		cleanup := mockInvalidCallerKeeper()
		defer cleanup()

		k := setupKeeperUnit()

		err := k.setReferral(keeperAddr1, keeperAddr2, EventTypeRegister)
		uassert.Error(t, err)
	})

	t.Run("validates through different caller contexts", func(t *testing.T) {
		origCaller := std.OriginCaller()
		testing.SetOriginCaller(std.Address(""))
		defer func() {
			testing.SetOriginCaller(origCaller)
		}()

		k := setupKeeperUnit()

		err := k.setReferral(keeperAddr1, keeperAddr2, EventTypeRegister)
		uassert.Error(t, err)
	})
}

// TestKeeperStorageOperations tests low-level storage operations
func TestKeeperStorageOperations(t *testing.T) {
	t.Run("stores and retrieves referral data", func(t *testing.T) {
		cleanup := mockValidCallerKeeper()
		defer cleanup()

		k := setupKeeperUnit()

		// Direct storage test
		err := k.register(keeperAddr1, keeperAddr2)
		uassert.NoError(t, err)

		// Verify storage consistency
		storedValue, exists := k.store.Get(keeperAddr1.String())
		uassert.True(t, exists)
		uassert.Equal(t, keeperAddr2.String(), storedValue)
	})

	t.Run("handles missing storage entries", func(t *testing.T) {
		k := setupKeeperUnit()

		// Check for non-existent entry
		_, exists := k.store.Get(keeperAddr1.String())
		uassert.False(t, exists)

		has := k.has(keeperAddr1)
		uassert.False(t, has)
	})

	t.Run("overwrites existing storage entries", func(t *testing.T) {
		cleanup := mockValidCallerKeeper()
		defer cleanup()

		k := setupKeeperUnit()

		// Set initial value
		err := k.register(keeperAddr1, keeperAddr2)
		uassert.NoError(t, err)

		// Verify initial value
		ref1, err := k.get(keeperAddr1)
		uassert.NoError(t, err)
		uassert.Equal(t, keeperAddr2.String(), ref1.String())

		// Attempt update (should fail due to rate limiting)
		err = k.update(keeperAddr1, keeperAddr3)
		uassert.Error(t, err)

		// Value should remain unchanged
		ref1, err = k.get(keeperAddr1)
		uassert.NoError(t, err)
		uassert.Equal(t, keeperAddr2.String(), ref1.String())
	})
}

// TestKeeperValidation tests input validation
func TestKeeperValidation(t *testing.T) {
	t.Run("validates address formats", func(t *testing.T) {
		cleanup := mockValidCallerKeeper()
		defer cleanup()

		k := setupKeeperUnit()

		// Valid address format
		err := k.register(keeperAddr1, keeperAddr2)
		uassert.NoError(t, err)

		// Self referral validation
		err = k.register(keeperAddr3, keeperAddr3)
		uassert.Error(t, err)
	})

	t.Run("handles edge case addresses", func(t *testing.T) {
		cleanup := mockValidCallerKeeper()
		defer cleanup()

		k := setupKeeperUnit()

		// Zero address as referrer
		err := k.register(keeperAddr1, zeroAddress)
		uassert.NoError(t, err)

		// Should not have referral stored
		has := k.has(keeperAddr1)
		uassert.False(t, has)
	})
}

// TestKeeperNewKeeper tests the NewKeeper constructor
func TestKeeperNewKeeper(t *testing.T) {
	t.Run("creates new keeper instance", func(t *testing.T) {
		k := NewKeeper()
		uassert.NotNil(t, k)

		// Should be able to call keeper methods
		isEmpty := k.isEmpty()
		uassert.True(t, isEmpty) // New keeper should be empty
	})

	t.Run("creates independent instances", func(t *testing.T) {
		k1 := NewKeeper()
		k2 := NewKeeper()

		// Both should be valid keepers but we can't directly compare interfaces
		// Instead verify they have independent state
		isEmpty1 := k1.isEmpty()
		isEmpty2 := k2.isEmpty()
		uassert.True(t, isEmpty1)
		uassert.True(t, isEmpty2)
	})
}

// TestKeeperBulkOperations tests handling multiple operations
func TestKeeperBulkOperations(t *testing.T) {
	t.Run("handles multiple sequential registrations", func(t *testing.T) {
		cleanup := mockValidCallerKeeper()
		defer cleanup()

		k := setupKeeperUnit()

		// Register multiple users
		addresses := []std.Address{keeperAddr1, keeperAddr2, keeperAddr3, keeperAddr4}
		referrers := []std.Address{keeperAddr2, keeperAddr3, keeperAddr4, keeperAddr5}

		for i := 0; i < len(addresses); i++ {
			err := k.register(addresses[i], referrers[i])
			uassert.NoError(t, err)
		}

		// Verify all registrations
		for i := 0; i < len(addresses); i++ {
			has := k.has(addresses[i])
			uassert.True(t, has)

			ref, err := k.get(addresses[i])
			uassert.NoError(t, err)
			uassert.Equal(t, referrers[i].String(), ref.String())
		}
	})

	t.Run("maintains data integrity across operations", func(t *testing.T) {
		cleanup := mockValidCallerKeeper()
		defer cleanup()

		k := setupKeeperUnit()

		// Initial registration
		err := k.register(keeperAddr1, keeperAddr2)
		uassert.NoError(t, err)

		// Perform multiple read operations
		for i := 0; i < 10; i++ {
			has := k.has(keeperAddr1)
			uassert.True(t, has)

			ref, err := k.get(keeperAddr1)
			uassert.NoError(t, err)
			uassert.Equal(t, keeperAddr2.String(), ref.String())
		}

		// Attempt failed operation (self referral)
		err = k.register(keeperAddr3, keeperAddr3)
		uassert.Error(t, err)

		// Original data should remain intact
		has := k.has(keeperAddr1)
		uassert.True(t, has)

		ref, err := k.get(keeperAddr1)
		uassert.NoError(t, err)
		uassert.Equal(t, keeperAddr2.String(), ref.String())
	})
}

// TestKeeperErrorConditions tests various error scenarios
func TestKeeperErrorConditions(t *testing.T) {
	t.Run("handles authorization errors gracefully", func(t *testing.T) {
		cleanup := mockInvalidCallerKeeper()
		defer cleanup()

		k := setupKeeperUnit()

		err := k.register(keeperAddr1, keeperAddr2)
		uassert.Error(t, err)

		// State should remain clean
		has := k.has(keeperAddr1)
		uassert.False(t, has)
	})

	t.Run("handles validation errors gracefully", func(t *testing.T) {
		cleanup := mockValidCallerKeeper()
		defer cleanup()

		k := setupKeeperUnit()

		// Self referral error
		err := k.register(keeperAddr1, keeperAddr1)
		uassert.Error(t, err)

		// State should remain clean
		has := k.has(keeperAddr1)
		uassert.False(t, has)

		// Valid operation should still work
		err = k.register(keeperAddr1, keeperAddr2)
		uassert.NoError(t, err)

		has = k.has(keeperAddr1)
		uassert.True(t, has)
	})

	t.Run("recovers from partial failures", func(t *testing.T) {
		cleanup := mockValidCallerKeeper()
		defer cleanup()

		k := setupKeeperUnit()

		// Successful operation
		err := k.register(keeperAddr1, keeperAddr2)
		uassert.NoError(t, err)

		// Failed operation (rate limiting)
		err = k.update(keeperAddr1, keeperAddr3)
		uassert.Error(t, err)

		// Original state should be preserved
		ref, err := k.get(keeperAddr1)
		uassert.NoError(t, err)
		uassert.Equal(t, keeperAddr2.String(), ref.String())

		// New operations should still work
		err = k.register(keeperAddr4, keeperAddr5)
		uassert.NoError(t, err)
	})
}
