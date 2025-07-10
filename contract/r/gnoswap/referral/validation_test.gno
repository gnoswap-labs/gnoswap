package referral

import (
	"std"
	"testing"

	"gno.land/p/demo/testutils"
	"gno.land/p/demo/uassert"

	"gno.land/r/gnoswap/v1/access"
)

var (
	// Test addresses for validation tests
	validationAddr1 = testutils.TestAddress("validation1")
	validationAddr2 = testutils.TestAddress("validation2")
	validationAddr3 = testutils.TestAddress("validation3")
	validationAddr4 = testutils.TestAddress("validation4")
)

func setupValidationKeeper() *keeper {
	return NewKeeper().(*keeper)
}

func mockValidCallerValidation() func() {
	origCaller := std.OriginCaller()
	routerAddr, _ := access.GetAddress(access.ROLE_ROUTER)
	testing.SetOriginCaller(routerAddr)
	return func() {
		testing.SetOriginCaller(origCaller)
	}
}

// TestSelfReferralValidation tests self-referral prevention
func TestSelfReferralValidation(t *testing.T) {
	t.Run("prevents self referral on register", func(t *testing.T) {
		cleanup := mockValidCallerValidation()
		defer cleanup()

		k := setupValidationKeeper()

		err := k.register(validationAddr1, validationAddr1)
		uassert.Error(t, err)
		uassert.True(t, err.Error() == ErrSelfReferral.Error())

		// Verify no referral was created
		has := k.has(validationAddr1)
		uassert.False(t, has)
	})

	t.Run("prevents self referral on update", func(t *testing.T) {
		cleanup := mockValidCallerValidation()
		defer cleanup()

		k := setupValidationKeeper()

		// Initial registration
		err := k.register(validationAddr1, validationAddr2)
		uassert.NoError(t, err)

		// Attempt self referral update
		err = k.update(validationAddr1, validationAddr1)
		uassert.Error(t, err)
		uassert.True(t, err.Error() == ErrSelfReferral.Error())

		// Original referral should remain
		ref, err := k.get(validationAddr1)
		uassert.NoError(t, err)
		uassert.Equal(t, validationAddr2.String(), ref.String())
	})

	t.Run("allows same address as referrer for different users", func(t *testing.T) {
		cleanup := mockValidCallerValidation()
		defer cleanup()

		k := setupValidationKeeper()

		// Two different users can have same referrer
		err := k.register(validationAddr1, validationAddr3)
		uassert.NoError(t, err)

		err = k.register(validationAddr2, validationAddr3)
		uassert.NoError(t, err)

		// Verify both referrals
		ref1, err := k.get(validationAddr1)
		uassert.NoError(t, err)
		uassert.Equal(t, validationAddr3.String(), ref1.String())

		ref2, err := k.get(validationAddr2)
		uassert.NoError(t, err)
		uassert.Equal(t, validationAddr3.String(), ref2.String())
	})
}

// TestZeroAddressValidation tests zero address handling
func TestZeroAddressValidation(t *testing.T) {
	t.Run("allows zero address as referrer", func(t *testing.T) {
		cleanup := mockValidCallerValidation()
		defer cleanup()

		k := setupValidationKeeper()

		err := k.register(validationAddr1, zeroAddress)
		uassert.NoError(t, err)

		// Zero address means no referrer stored
		has := k.has(validationAddr1)
		uassert.False(t, has)
	})

	t.Run("zero address referrer does not create storage entry", func(t *testing.T) {
		cleanup := mockValidCallerValidation()
		defer cleanup()

		k := setupValidationKeeper()

		err := k.register(validationAddr1, zeroAddress)
		uassert.NoError(t, err)

		// Should not exist in storage
		_, exists := k.store.Get(validationAddr1.String())
		uassert.False(t, exists)
	})

	t.Run("can update from real referrer to zero address", func(t *testing.T) {
		cleanup := mockValidCallerValidation()
		defer cleanup()

		k := setupValidationKeeper()

		// Initial registration with real referrer
		err := k.register(validationAddr1, validationAddr2)
		uassert.NoError(t, err)

		has := k.has(validationAddr1)
		uassert.True(t, has)

		// Update to zero address should succeed (zero address bypasses rate limiting)
		err = k.update(validationAddr1, zeroAddress)
		uassert.NoError(t, err)

		// Verify the referral was removed
		has = k.has(validationAddr1)
		uassert.False(t, has)
	})
}

// TestInputValidation tests various input validation scenarios
func TestInputValidation(t *testing.T) {
	t.Run("validates address consistency", func(t *testing.T) {
		cleanup := mockValidCallerValidation()
		defer cleanup()

		k := setupValidationKeeper()

		// Valid addresses should work
		err := k.register(validationAddr1, validationAddr2)
		uassert.NoError(t, err)

		// Verify registration
		ref, err := k.get(validationAddr1)
		uassert.NoError(t, err)
		uassert.Equal(t, validationAddr2.String(), ref.String())
	})

	t.Run("handles address edge cases", func(t *testing.T) {
		cleanup := mockValidCallerValidation()
		defer cleanup()

		k := setupValidationKeeper()

		// Test with different valid addresses
		testCases := []struct {
			user          std.Address
			referrer      std.Address
			shouldSucceed bool
		}{
			{validationAddr1, validationAddr2, true},
			{validationAddr2, validationAddr3, true},
			{validationAddr3, zeroAddress, true},
			{validationAddr4, validationAddr4, false}, // self referral
		}

		for _, tc := range testCases {
			err := k.register(tc.user, tc.referrer)
			if tc.shouldSucceed {
				uassert.NoError(t, err)
			} else {
				uassert.Error(t, err)
			}
		}
	})
}

// TestBusinessRuleValidation tests business logic validation
func TestBusinessRuleValidation(t *testing.T) {
	t.Run("enforces single referrer per user", func(t *testing.T) {
		cleanup := mockValidCallerValidation()
		defer cleanup()

		k := setupValidationKeeper()

		// Register user with referrer
		err := k.register(validationAddr1, validationAddr2)
		uassert.NoError(t, err)

		// User should have exactly one referrer
		ref, err := k.get(validationAddr1)
		uassert.NoError(t, err)
		uassert.Equal(t, validationAddr2.String(), ref.String())

		// Attempting to register again should fail (implicit in update failing due to rate limiting)
		err = k.register(validationAddr1, validationAddr3)
		uassert.Error(t, err)
	})

	t.Run("allows referral chains", func(t *testing.T) {
		cleanup := mockValidCallerValidation()
		defer cleanup()

		k := setupValidationKeeper()

		// Create referral chain: addr1 -> addr2 -> addr3 -> addr4
		err := k.register(validationAddr1, validationAddr2)
		uassert.NoError(t, err)

		err = k.register(validationAddr2, validationAddr3)
		uassert.NoError(t, err)

		err = k.register(validationAddr3, validationAddr4)
		uassert.NoError(t, err)

		// Verify chain
		ref1, err := k.get(validationAddr1)
		uassert.NoError(t, err)
		uassert.Equal(t, validationAddr2.String(), ref1.String())

		ref2, err := k.get(validationAddr2)
		uassert.NoError(t, err)
		uassert.Equal(t, validationAddr3.String(), ref2.String())

		ref3, err := k.get(validationAddr3)
		uassert.NoError(t, err)
		uassert.Equal(t, validationAddr4.String(), ref3.String())
	})

	t.Run("validates operation types", func(t *testing.T) {
		cleanup := mockValidCallerValidation()
		defer cleanup()

		k := setupValidationKeeper()

		// Register operation
		err := k.setReferral(validationAddr1, validationAddr2, EventTypeRegister)
		uassert.NoError(t, err)

		// Update operation (should fail due to rate limiting)
		err = k.setReferral(validationAddr1, validationAddr3, EventTypeUpdate)
		uassert.Error(t, err)
	})
}

// TestDataConsistencyValidation tests data consistency rules
func TestDataConsistencyValidation(t *testing.T) {
	t.Run("maintains referral data consistency", func(t *testing.T) {
		cleanup := mockValidCallerValidation()
		defer cleanup()

		k := setupValidationKeeper()

		// Register referral
		err := k.register(validationAddr1, validationAddr2)
		uassert.NoError(t, err)

		// Multiple reads should return consistent data
		for i := 0; i < 5; i++ {
			has := k.has(validationAddr1)
			uassert.True(t, has)

			ref, err := k.get(validationAddr1)
			uassert.NoError(t, err)
			uassert.Equal(t, validationAddr2.String(), ref.String())
		}
	})

	t.Run("isolates user data", func(t *testing.T) {
		cleanup := mockValidCallerValidation()
		defer cleanup()

		k := setupValidationKeeper()

		// Register multiple users
		err := k.register(validationAddr1, validationAddr2)
		uassert.NoError(t, err)

		err = k.register(validationAddr3, validationAddr4)
		uassert.NoError(t, err)

		// Each user should have isolated data
		ref1, err := k.get(validationAddr1)
		uassert.NoError(t, err)
		uassert.Equal(t, validationAddr2.String(), ref1.String())

		ref3, err := k.get(validationAddr3)
		uassert.NoError(t, err)
		uassert.Equal(t, validationAddr4.String(), ref3.String())

		// Non-existent user should not have data
		has := k.has(testutils.TestAddress("nonexistent"))
		uassert.False(t, has)
	})

	t.Run("handles storage state correctly", func(t *testing.T) {
		cleanup := mockValidCallerValidation()
		defer cleanup()

		k := setupValidationKeeper()

		// Before registration
		has := k.has(validationAddr1)
		uassert.False(t, has)

		_, exists := k.store.Get(validationAddr1.String())
		uassert.False(t, exists)

		// After registration
		err := k.register(validationAddr1, validationAddr2)
		uassert.NoError(t, err)

		has = k.has(validationAddr1)
		uassert.True(t, has)

		value, exists := k.store.Get(validationAddr1.String())
		uassert.True(t, exists)
		uassert.Equal(t, validationAddr2.String(), value)
	})
}

// TestErrorValidation tests error handling validation
func TestErrorValidation(t *testing.T) {
	t.Run("returns appropriate error messages", func(t *testing.T) {
		k := setupValidationKeeper()

		// Test self referral error with valid caller
		cleanup := mockValidCallerValidation()
		err := k.register(validationAddr1, validationAddr1)
		cleanup()
		
		uassert.Error(t, err)
		uassert.True(t, err.Error() == ErrSelfReferral.Error())

		// Test with invalid address - skip authorization test due to context issues
		invalidAddr := std.Address("invalid")
		err = k.validateAddresses(invalidAddr, validationAddr2)
		uassert.Error(t, err)
	})

	t.Run("preserves state on errors", func(t *testing.T) {
		cleanup := mockValidCallerValidation()
		defer cleanup()

		k := setupValidationKeeper()

		// Successful operation
		err := k.register(validationAddr1, validationAddr2)
		uassert.NoError(t, err)

		// Failed operation (self referral)
		err = k.register(validationAddr3, validationAddr3)
		uassert.Error(t, err)

		// Original state should be preserved
		ref, err := k.get(validationAddr1)
		uassert.NoError(t, err)
		uassert.Equal(t, validationAddr2.String(), ref.String())

		// Non-failed user should not exist
		has := k.has(validationAddr3)
		uassert.False(t, has)
	})

	t.Run("validates operation context", func(t *testing.T) {
		k := setupValidationKeeper()

		// Missing authorization context
		err := k.register(validationAddr1, validationAddr2)
		uassert.Error(t, err)

		// State should remain clean
		has := k.has(validationAddr1)
		uassert.False(t, has)
	})
}
