package referral

import (
	"std"
	"testing"

	"gno.land/p/demo/testutils"
	"gno.land/p/demo/uassert"

	"gno.land/r/gnoswap/v1/access"
)

var (
	// Test addresses for rate limiting tests
	rateLimitAddr1 = testutils.TestAddress("rateLimit1")
	rateLimitAddr2 = testutils.TestAddress("rateLimit2")
	rateLimitAddr3 = testutils.TestAddress("rateLimit3")
	rateLimitAddr4 = testutils.TestAddress("rateLimit4")
	rateLimitAddr5 = testutils.TestAddress("rateLimit5")
)

func setupRateLimitKeeper() *keeper {
	return NewKeeper().(*keeper)
}

func mockValidCallerRateLimit() func() {
	origCaller := std.OriginCaller()
	routerAddr, _ := access.GetAddress(access.ROLE_ROUTER)
	testing.SetOriginCaller(routerAddr)
	return func() {
		testing.SetOriginCaller(origCaller)
	}
}

// TestRateLimitingBasic tests basic rate limiting functionality
func TestRateLimitingBasic(t *testing.T) {
	t.Run("allows first operation within 24 hours", func(t *testing.T) {
		cleanup := mockValidCallerRateLimit()
		defer cleanup()

		k := setupRateLimitKeeper()

		// First operation should succeed
		err := k.register(rateLimitAddr1, rateLimitAddr2)
		uassert.NoError(t, err)

		// Verify registration
		has := k.has(rateLimitAddr1)
		uassert.True(t, has)

		ref, err := k.get(rateLimitAddr1)
		uassert.NoError(t, err)
		uassert.Equal(t, rateLimitAddr2.String(), ref.String())
	})

	t.Run("blocks second operation within 24 hours", func(t *testing.T) {
		cleanup := mockValidCallerRateLimit()
		defer cleanup()

		k := setupRateLimitKeeper()

		// First operation succeeds
		err := k.register(rateLimitAddr1, rateLimitAddr2)
		uassert.NoError(t, err)

		// Second operation should fail due to rate limiting
		err = k.update(rateLimitAddr1, rateLimitAddr3)
		uassert.Error(t, err)
		if err != nil {
			uassert.True(t, err.Error() == ErrTooManyRequests.Error())
		}

		// Original referral should remain unchanged
		ref, err := k.get(rateLimitAddr1)
		uassert.NoError(t, err)
		uassert.Equal(t, rateLimitAddr2.String(), ref.String())
	})

	t.Run("rate limiting is address-specific", func(t *testing.T) {
		cleanup := mockValidCallerRateLimit()
		defer cleanup()

		k := setupRateLimitKeeper()

		// First address operation
		err := k.register(rateLimitAddr1, rateLimitAddr2)
		uassert.NoError(t, err)

		// Different address should not be rate limited
		err = k.register(rateLimitAddr3, rateLimitAddr4)
		uassert.NoError(t, err)

		// First address should still be rate limited
		err = k.update(rateLimitAddr1, rateLimitAddr4)
		uassert.Error(t, err)

		// Verify both registrations exist correctly
		ref1, err := k.get(rateLimitAddr1)
		uassert.NoError(t, err)
		uassert.Equal(t, rateLimitAddr2.String(), ref1.String())

		ref3, err := k.get(rateLimitAddr3)
		uassert.NoError(t, err)
		uassert.Equal(t, rateLimitAddr4.String(), ref3.String())
	})
}

// TestRateLimitingOperationTypes tests rate limiting across different operation types
func TestRateLimitingOperationTypes(t *testing.T) {
	t.Run("register followed by update is rate limited", func(t *testing.T) {
		cleanup := mockValidCallerRateLimit()
		defer cleanup()

		k := setupRateLimitKeeper()

		// Register operation
		err := k.register(rateLimitAddr1, rateLimitAddr2)
		uassert.NoError(t, err)

		// Update operation should be rate limited
		err = k.update(rateLimitAddr1, rateLimitAddr3)
		uassert.Error(t, err)
		if err != nil {
			uassert.True(t, err.Error() == ErrTooManyRequests.Error())
		}
	})

	t.Run("update followed by register is rate limited", func(t *testing.T) {
		cleanup := mockValidCallerRateLimit()
		defer cleanup()

		k := setupRateLimitKeeper()

		// Update operation (creates new referral)
		err := k.update(rateLimitAddr1, rateLimitAddr2)
		uassert.NoError(t, err)

		// Register operation should be rate limited
		err = k.register(rateLimitAddr1, rateLimitAddr3)
		uassert.Error(t, err)
		if err != nil {
			uassert.True(t, err.Error() == ErrTooManyRequests.Error())
		}
	})

	t.Run("multiple update attempts are rate limited", func(t *testing.T) {
		cleanup := mockValidCallerRateLimit()
		defer cleanup()

		k := setupRateLimitKeeper()

		// First update creates referral
		err := k.update(rateLimitAddr1, rateLimitAddr2)
		uassert.NoError(t, err)

		// Subsequent updates should be rate limited
		err = k.update(rateLimitAddr1, rateLimitAddr3)
		uassert.Error(t, err)

		err = k.update(rateLimitAddr1, rateLimitAddr4)
		uassert.Error(t, err)

		// Original referral should remain
		ref, err := k.get(rateLimitAddr1)
		uassert.NoError(t, err)
		uassert.Equal(t, rateLimitAddr2.String(), ref.String())
	})
}

// TestRateLimitingTimeWindow tests the 24-hour time window
func TestRateLimitingTimeWindow(t *testing.T) {
	t.Run("tracks operation timestamps", func(t *testing.T) {
		cleanup := mockValidCallerRateLimit()
		defer cleanup()

		k := setupRateLimitKeeper()

		// Perform operation
		err := k.register(rateLimitAddr1, rateLimitAddr2)
		uassert.NoError(t, err)

		// Check that timestamp is recorded (indirectly by verifying rate limiting)
		err = k.update(rateLimitAddr1, rateLimitAddr3)
		uassert.Error(t, err)
		if err != nil {
			uassert.True(t, err.Error() == ErrTooManyRequests.Error())
		}
	})

	t.Run("maintains separate timestamps per address", func(t *testing.T) {
		cleanup := mockValidCallerRateLimit()
		defer cleanup()

		k := setupRateLimitKeeper()

		// Operations on different addresses at different times
		err := k.register(rateLimitAddr1, rateLimitAddr2)
		uassert.NoError(t, err)

		err = k.register(rateLimitAddr3, rateLimitAddr4)
		uassert.NoError(t, err)

		// Both should be independently rate limited
		err = k.update(rateLimitAddr1, rateLimitAddr3)
		uassert.Error(t, err)

		err = k.update(rateLimitAddr3, rateLimitAddr1)
		uassert.Error(t, err)
	})

	t.Run("validates time window calculation", func(t *testing.T) {
		cleanup := mockValidCallerRateLimit()
		defer cleanup()

		k := setupRateLimitKeeper()

		// Perform operation
		err := k.register(rateLimitAddr1, rateLimitAddr2)
		uassert.NoError(t, err)

		// Immediate second operation should fail
		err = k.update(rateLimitAddr1, rateLimitAddr3)
		uassert.Error(t, err)

		// Error message should indicate 24-hour limitation
		if err != nil {
			uassert.True(t, err.Error() == ErrTooManyRequests.Error())
		}
	})
}

// TestRateLimitingEdgeCases tests edge cases in rate limiting
func TestRateLimitingEdgeCases(t *testing.T) {
	t.Run("failed operations do not affect rate limiting", func(t *testing.T) {
		cleanup := mockValidCallerRateLimit()
		defer cleanup()

		k := setupRateLimitKeeper()

		// Failed operation (self referral) should not trigger rate limiting
		err := k.register(rateLimitAddr1, rateLimitAddr1)
		uassert.Error(t, err)
		if err != nil {
			uassert.True(t, err.Error() == ErrSelfReferral.Error())
		}

		// Subsequent valid operation should succeed
		err = k.register(rateLimitAddr1, rateLimitAddr2)
		uassert.NoError(t, err)

		// Now rate limiting should be active
		err = k.update(rateLimitAddr1, rateLimitAddr3)
		uassert.Error(t, err)
		if err != nil {
			uassert.True(t, err.Error() == ErrTooManyRequests.Error())
		}
	})

	t.Run("zero address referrals respect rate limiting", func(t *testing.T) {
		cleanup := mockValidCallerRateLimit()
		defer cleanup()

		k := setupRateLimitKeeper()

		// Register with zero address (when no prior registration exists, this is just a no-op)
		err := k.register(rateLimitAddr1, zeroAddress)
		uassert.NoError(t, err)

		// Since zero address registration is a no-op when no prior entry exists,
		// there should be no rate limiting for subsequent operations
		err = k.register(rateLimitAddr1, rateLimitAddr2)
		uassert.NoError(t, err)

		// Now the regular rate limiting should apply
		err = k.update(rateLimitAddr1, rateLimitAddr3)
		uassert.Error(t, err)
		if err != nil {
			uassert.True(t, err.Error() == ErrTooManyRequests.Error())
		}
	})

	t.Run("unauthorized operations do not affect rate limiting", func(t *testing.T) {
		k := setupRateLimitKeeper()

		// Unauthorized operation should fail without affecting rate limiting
		err := k.register(rateLimitAddr1, rateLimitAddr2)
		uassert.Error(t, err)

		// Now with valid authorization
		cleanup := mockValidCallerRateLimit()
		defer cleanup()

		// Should succeed (no rate limiting from unauthorized attempt)
		err = k.register(rateLimitAddr1, rateLimitAddr2)
		uassert.NoError(t, err)

		// Now should be rate limited
		err = k.update(rateLimitAddr1, rateLimitAddr3)
		uassert.Error(t, err)
		if err != nil {
			uassert.True(t, err.Error() == ErrTooManyRequests.Error())
		}
	})
}

// TestRateLimitingConsistency tests consistency of rate limiting behavior
func TestRateLimitingConsistency(t *testing.T) {
	t.Run("consistent rate limiting across multiple operations", func(t *testing.T) {
		cleanup := mockValidCallerRateLimit()
		defer cleanup()

		k := setupRateLimitKeeper()

		// First operation
		err := k.register(rateLimitAddr1, rateLimitAddr2)
		uassert.NoError(t, err)

		// Multiple rate-limited attempts should all fail consistently
		for i := 0; i < 5; i++ {
			err = k.update(rateLimitAddr1, testutils.TestAddress("temp"+string(rune(i+'0'))))
			uassert.Error(t, err)
			if err != nil {
				uassert.True(t, err.Error() == ErrTooManyRequests.Error())
			}
		}

		// Original referral should remain unchanged
		ref, err := k.get(rateLimitAddr1)
		uassert.NoError(t, err)
		uassert.Equal(t, rateLimitAddr2.String(), ref.String())
	})

	t.Run("rate limiting preserves data integrity", func(t *testing.T) {
		cleanup := mockValidCallerRateLimit()
		defer cleanup()

		k := setupRateLimitKeeper()

		// Establish initial state
		err := k.register(rateLimitAddr1, rateLimitAddr2)
		uassert.NoError(t, err)

		err = k.register(rateLimitAddr3, rateLimitAddr4)
		uassert.NoError(t, err)

		// Rate-limited operations should not affect other data
		err = k.update(rateLimitAddr1, rateLimitAddr5)
		uassert.Error(t, err)

		// Both original referrals should be intact
		ref1, err := k.get(rateLimitAddr1)
		uassert.NoError(t, err)
		uassert.Equal(t, rateLimitAddr2.String(), ref1.String())

		ref3, err := k.get(rateLimitAddr3)
		uassert.NoError(t, err)
		uassert.Equal(t, rateLimitAddr4.String(), ref3.String())
	})

	t.Run("independent rate limiting per address", func(t *testing.T) {
		cleanup := mockValidCallerRateLimit()
		defer cleanup()

		k := setupRateLimitKeeper()

		// Multiple addresses with operations
		addresses := []std.Address{rateLimitAddr1, rateLimitAddr2, rateLimitAddr3}
		referrers := []std.Address{rateLimitAddr4, rateLimitAddr5, rateLimitAddr1}

		// Each address gets one operation
		for i, addr := range addresses {
			err := k.register(addr, referrers[i])
			uassert.NoError(t, err)
		}

		// Each address should be independently rate limited
		for _, addr := range addresses {
			err := k.update(addr, rateLimitAddr5)
			uassert.Error(t, err)
			if err != nil {
				uassert.True(t, err.Error() == ErrTooManyRequests.Error())
			}
		}
	})
}
