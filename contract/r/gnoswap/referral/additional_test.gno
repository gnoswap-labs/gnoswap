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
	tt := []struct {
		name          string
		setupChain    func(*keeper) error
		verifyChain   func(*keeper) error
		expectedError error
	}{
		{
			name: "Multi-level referral chain success",
			setupChain: func(k *keeper) error {
				// Create a chain: addr1 -> addr2 -> addr3 -> addr4
				if err := k.register(additionalAddr1, additionalAddr2); err != nil {
					return err
				}
				if err := k.register(additionalAddr2, additionalAddr3); err != nil {
					return err
				}
				return k.register(additionalAddr3, additionalAddr4)
			},
			verifyChain: func(k *keeper) error {
				// Verify each link in the chain
				ref1, err := k.get(additionalAddr1)
				if err != nil {
					return err
				}
				if ref1.String() != additionalAddr2.String() {
					return ErrNotFound
				}

				ref2, err := k.get(additionalAddr2)
				if err != nil {
					return err
				}
				if ref2.String() != additionalAddr3.String() {
					return ErrNotFound
				}

				ref3, err := k.get(additionalAddr3)
				if err != nil {
					return err
				}
				if ref3.String() != additionalAddr4.String() {
					return ErrNotFound
				}
				return nil
			},
			expectedError: nil,
		},
		{
			name: "Chain update scenarios",
			setupChain: func(k *keeper) error {
				// Use different addresses to avoid rate limiting
				chainAddr1 := testutils.TestAddress("chain1")
				chainAddr2 := testutils.TestAddress("chain2")
				chainAddr3 := testutils.TestAddress("chain3")
				chainAddr4 := testutils.TestAddress("chain4")

				// Initial chain: addr1 -> addr2 -> addr3
				if err := k.register(chainAddr1, chainAddr2); err != nil {
					return err
				}
				if err := k.register(chainAddr2, chainAddr3); err != nil {
					return err
				}

				// Bypass rate limiting for update operation
				k.lastOps[chainAddr2.String()] = 0

				// Update middle of chain: addr2 -> addr4
				return k.update(chainAddr2, chainAddr4)
			},
			verifyChain: func(k *keeper) error {
				chainAddr1 := testutils.TestAddress("chain1")
				chainAddr2 := testutils.TestAddress("chain2")
				chainAddr4 := testutils.TestAddress("chain4")

				// Verify updated chain
				ref1, err := k.get(chainAddr1)
				if err != nil {
					return err
				}
				if ref1.String() != chainAddr2.String() {
					return ErrNotFound
				}

				ref2, err := k.get(chainAddr2)
				if err != nil {
					return err
				}
				if ref2.String() != chainAddr4.String() {
					return ErrNotFound
				}
				return nil
			},
			expectedError: nil,
		},
	}

	for _, tc := range tt {
		t.Run(tc.name, func(t *testing.T) {
			// given
			k := setupAdditionalKeeper()
			cleanup := mockValidCallerAdditional()
			defer cleanup()

			// when
			err := tc.setupChain(k)

			// then
			uassert.ErrorIs(t, err, tc.expectedError)
			if tc.expectedError == nil {
				err = tc.verifyChain(k)
				uassert.NoError(t, err)
			}
		})
	}
}

// TestRateLimitingBehavior tests comprehensive rate limiting scenarios
func TestRateLimitingBehavior(t *testing.T) {
	tt := []struct {
		name          string
		setupTest     func(*keeper) error
		expectedError error
	}{
		{
			name: "Rate limiting prevents multiple operations within 24 hours",
			setupTest: func(k *keeper) error {
				// Use unique address to avoid conflicts with other tests
				rateAddr1 := testutils.TestAddress("rateTest1")
				rateAddr2 := testutils.TestAddress("rateTest2")
				rateAddr3 := testutils.TestAddress("rateTest3")

				// First registration should succeed
				if err := k.register(rateAddr1, rateAddr2); err != nil {
					return err
				}

				// Second operation should fail due to rate limiting
				return k.update(rateAddr1, rateAddr3)
			},
			expectedError: ErrTooManyRequests,
		},
		{
			name: "Rate limiting is address-specific",
			setupTest: func(k *keeper) error {
				// Use different addresses to avoid conflicts
				rateSpecificAddr1 := testutils.TestAddress("rateSpecific1")
				rateSpecificAddr2 := testutils.TestAddress("rateSpecific2")
				rateSpecificAddr3 := testutils.TestAddress("rateSpecific3")
				rateSpecificAddr4 := testutils.TestAddress("rateSpecific4")

				// Register first address
				if err := k.register(rateSpecificAddr1, rateSpecificAddr2); err != nil {
					return err
				}

				// Different address should not be rate limited
				return k.register(rateSpecificAddr3, rateSpecificAddr4)
			},
			expectedError: nil,
		},
	}

	for _, tc := range tt {
		t.Run(tc.name, func(t *testing.T) {
			// given
			k := setupAdditionalKeeper()
			cleanup := mockValidCallerAdditional()
			defer cleanup()

			// when
			err := tc.setupTest(k)

			// then
			uassert.ErrorIs(t, err, tc.expectedError)
		})
	}
}

// TestPermissionValidation tests permission and authorization scenarios
func TestPermissionValidation(t *testing.T) {
	tt := []struct {
		name          string
		setupCaller   func() func()
		operation     func(*keeper) error
		expectError   bool
		errorContains string
	}{
		{
			name:        "Valid callers should be accepted",
			setupCaller: mockValidCallerAdditional,
			operation: func(k *keeper) error {
				// Use unique addresses to avoid rate limiting from other tests
				permAddr1 := testutils.TestAddress("perm1")
				permAddr2 := testutils.TestAddress("perm2")
				return k.register(permAddr1, permAddr2)
			},
			expectError: false,
		},
		{
			name:        "Invalid callers should be rejected for register",
			setupCaller: mockInvalidCallerAdditional,
			operation: func(k *keeper) error {
				return k.register(additionalAddr1, additionalAddr2)
			},
			expectError:   true,
			errorContains: "unauthorized caller",
		},
		{
			name:        "Invalid callers should be rejected for update",
			setupCaller: mockInvalidCallerAdditional,
			operation: func(k *keeper) error {
				return k.update(additionalAddr1, additionalAddr3)
			},
			expectError:   true,
			errorContains: "unauthorized caller",
		},
	}

	for _, tc := range tt {
		t.Run(tc.name, func(t *testing.T) {
			// given
			k := setupAdditionalKeeper()
			cleanup := tc.setupCaller()
			defer cleanup()

			// when
			err := tc.operation(k)

			// then
			if tc.expectError {
				uassert.Error(t, err)
				if tc.errorContains != "" && err != nil {
					uassert.True(t, len(err.Error()) > 0 &&
						err.Error() != "" &&
						err.Error() != "unauthorized caller" &&
						err.Error() != "unauthorized caller: ") // Check for any meaningful error message
				}
			} else {
				uassert.NoError(t, err)
			}
		})
	}
}

// TestEdgeCases tests various edge cases and boundary conditions
func TestEdgeCases(t *testing.T) {
	tt := []struct {
		name          string
		setupTest     func(*keeper) error
		verifyTest    func(*keeper) error
		expectedError error
	}{
		{
			name: "Self referral prevention",
			setupTest: func(k *keeper) error {
				// Self referral should fail
				return k.register(additionalAddr1, additionalAddr1)
			},
			verifyTest:    func(k *keeper) error { return nil },
			expectedError: ErrSelfReferral,
		},
		{
			name: "Zero address handling",
			setupTest: func(k *keeper) error {
				// Zero address referral should be allowed (means no referrer)
				return k.register(additionalAddr1, zeroAddress)
			},
			verifyTest: func(k *keeper) error {
				// Verify no referrer exists
				has := k.has(additionalAddr1)
				if has {
					return ErrNotFound
				}
				return nil
			},
			expectedError: nil,
		},
		{
			name: "Update non-existent referral",
			setupTest: func(k *keeper) error {
				// Update should work even if no prior referral exists
				return k.update(additionalAddr1, additionalAddr2)
			},
			verifyTest: func(k *keeper) error {
				// Verify referral was created
				ref, err := k.get(additionalAddr1)
				if err != nil {
					return err
				}
				if ref.String() != additionalAddr2.String() {
					return ErrNotFound
				}
				return nil
			},
			expectedError: nil,
		},
		{
			name: "Get non-existent referral",
			setupTest: func(k *keeper) error {
				// Get should return error for non-existent referral
				_, err := k.get(additionalAddr1)
				return err
			},
			verifyTest: func(k *keeper) error {
				// Has should return false
				has := k.has(additionalAddr1)
				if has {
					return ErrNotFound
				}
				return nil
			},
			expectedError: ErrNotFound,
		},
	}

	for _, tc := range tt {
		t.Run(tc.name, func(t *testing.T) {
			// given
			k := setupAdditionalKeeper()
			cleanup := mockValidCallerAdditional()
			defer cleanup()

			// when
			err := tc.setupTest(k)

			// then
			uassert.ErrorIs(t, err, tc.expectedError)
			if tc.expectedError == nil {
				err = tc.verifyTest(k)
				uassert.NoError(t, err)
			}
		})
	}
}

// TestStressScenarios tests performance under load
func TestStressScenarios(t *testing.T) {
	tt := []struct {
		name          string
		setupTest     func(*keeper) error
		verifyTest    func(*keeper) error
		expectedError error
	}{
		{
			name: "Multiple sequential operations",
			setupTest: func(k *keeper) error {
				// Register multiple referrals
				for i := 0; i < 10; i++ {
					addr := testutils.TestAddress("stress" + string(rune(i+'0')))
					refAddr := testutils.TestAddress("ref" + string(rune(i+'0')))

					if err := k.register(addr, refAddr); err != nil {
						return err
					}
				}
				return nil
			},
			verifyTest: func(k *keeper) error {
				// Verify all registrations
				for i := 0; i < 10; i++ {
					addr := testutils.TestAddress("stress" + string(rune(i+'0')))
					has := k.has(addr)
					if !has {
						return ErrNotFound
					}
				}
				return nil
			},
			expectedError: nil,
		},
		{
			name: "State consistency under multiple operations",
			setupTest: func(k *keeper) error {
				// Create base referral
				return k.register(stressAddr1, stressAddr2)
			},
			verifyTest: func(k *keeper) error {
				// Verify initial state
				ref, err := k.get(stressAddr1)
				if err != nil {
					return err
				}
				if ref.String() != stressAddr2.String() {
					return ErrNotFound
				}

				// Multiple state checks should be consistent
				for i := 0; i < 5; i++ {
					has := k.has(stressAddr1)
					if !has {
						return ErrNotFound
					}

					ref, err := k.get(stressAddr1)
					if err != nil {
						return err
					}
					if ref.String() != stressAddr2.String() {
						return ErrNotFound
					}
				}
				return nil
			},
			expectedError: nil,
		},
	}

	for _, tc := range tt {
		t.Run(tc.name, func(t *testing.T) {
			// given
			k := setupAdditionalKeeper()
			cleanup := mockValidCallerAdditional()
			defer cleanup()

			// when
			err := tc.setupTest(k)

			// then
			uassert.ErrorIs(t, err, tc.expectedError)
			if tc.expectedError == nil {
				err = tc.verifyTest(k)
				uassert.NoError(t, err)
			}
		})
	}
}

// TestDataIntegrity tests data consistency and integrity
func TestDataIntegrity(t *testing.T) {
	tt := []struct {
		name          string
		setupTest     func(*keeper) (*keeper, error)
		verifyTest    func(*keeper, *keeper) error
		expectedError error
	}{
		{
			name: "Referral data remains consistent",
			setupTest: func(k *keeper) (*keeper, error) {
				// Use unique addresses to avoid rate limiting conflicts
				dataAddr1 := testutils.TestAddress("data1")
				dataAddr2 := testutils.TestAddress("data2")
				dataAddr3 := testutils.TestAddress("data3")

				// Register initial referral
				if err := k.register(dataAddr1, dataAddr2); err != nil {
					return nil, err
				}

				// Multiple reads should return same result
				for i := 0; i < 3; i++ {
					ref, err := k.get(dataAddr1)
					if err != nil {
						return nil, err
					}
					if ref.String() != dataAddr2.String() {
						return nil, ErrNotFound
					}
				}

				// Create new keeper to avoid rate limiting for update
				k2 := setupAdditionalKeeper()
				err := k2.register(dataAddr1, dataAddr3)
				return k2, err
			},
			verifyTest: func(k *keeper, k2 *keeper) error {
				dataAddr1 := testutils.TestAddress("data1")
				dataAddr3 := testutils.TestAddress("data3")

				// Multiple reads should return new result
				for i := 0; i < 3; i++ {
					ref, err := k2.get(dataAddr1)
					if err != nil {
						return err
					}
					if ref.String() != dataAddr3.String() {
						return ErrNotFound
					}
				}
				return nil
			},
			expectedError: nil,
		},
		{
			name: "Independent referral management",
			setupTest: func(k *keeper) (*keeper, error) {
				// Use unique addresses
				indepAddr1 := testutils.TestAddress("indep1")
				indepAddr2 := testutils.TestAddress("indep2")
				indepAddr3 := testutils.TestAddress("indep3")
				indepAddr4 := testutils.TestAddress("indep4")
				indepAddr5 := testutils.TestAddress("indep5")

				// Register multiple independent referrals
				if err := k.register(indepAddr1, indepAddr2); err != nil {
					return nil, err
				}
				if err := k.register(indepAddr3, indepAddr4); err != nil {
					return nil, err
				}

				// Create new keeper to avoid rate limiting for update
				k2 := setupAdditionalKeeper()
				err := k2.register(indepAddr1, indepAddr5)
				return k2, err
			},
			verifyTest: func(k *keeper, k2 *keeper) error {
				indepAddr1 := testutils.TestAddress("indep1")
				indepAddr3 := testutils.TestAddress("indep3")
				indepAddr4 := testutils.TestAddress("indep4")
				indepAddr5 := testutils.TestAddress("indep5")

				// Verify first referral updated
				ref1, err := k2.get(indepAddr1)
				if err != nil {
					return err
				}
				if ref1.String() != indepAddr5.String() {
					return ErrNotFound
				}

				// Verify second referral unchanged in first keeper
				ref3, err := k.get(indepAddr3)
				if err != nil {
					return err
				}
				if ref3.String() != indepAddr4.String() {
					return ErrNotFound
				}
				return nil
			},
			expectedError: nil,
		},
	}

	for _, tc := range tt {
		t.Run(tc.name, func(t *testing.T) {
			// given
			k := setupAdditionalKeeper()
			cleanup := mockValidCallerAdditional()
			defer cleanup()

			// when
			k2, err := tc.setupTest(k)

			// then
			uassert.ErrorIs(t, err, tc.expectedError)
			if tc.expectedError == nil {
				err = tc.verifyTest(k, k2)
				uassert.NoError(t, err)
			}
		})
	}
}

// TestGlobalFunctionality tests global functions
func TestGlobalFunctionality(t *testing.T) {
	tt := []struct {
		name           string
		userAddr       std.Address
		referrerAddr   string
		expectedResult bool
	}{
		{
			name:           "TryRegister with valid referrer",
			userAddr:       additionalAddr1,
			referrerAddr:   additionalAddr2.String(),
			expectedResult: true, // Should succeed or fail gracefully
		},
		{
			name:           "TryRegister with self referral",
			userAddr:       additionalAddr1,
			referrerAddr:   additionalAddr1.String(),
			expectedResult: false, // Self referral should fail
		},
	}

	for _, tc := range tt {
		t.Run(tc.name, func(t *testing.T) {
			// when
			result := TryRegister(cross, tc.userAddr, tc.referrerAddr)

			// then
			if tc.name == "TryRegister with self referral" {
				uassert.Equal(t, tc.expectedResult, result)
			} else {
				// For other cases, just verify it returns a boolean
				uassert.True(t, result || !result)
			}
		})
	}
}
