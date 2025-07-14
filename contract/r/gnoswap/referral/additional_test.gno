package referral

import (
	"std"
	"strings"
	"testing"

	"gno.land/p/demo/testutils"
	"gno.land/p/demo/uassert"

	"gno.land/r/gnoswap/v1/access"
)

func TestAdditional_ChainedReferrals(t *testing.T) {
	tests := []struct {
		name          string
		setupChain    func(*keeper) error
		verifyChain   func(*keeper) error
		expectedError error
	}{
		{
			name: "Multi-level referral chain success",
			setupChain: func(k *keeper) error {
				// Create a chain: addr1 -> addr2 -> addr3 -> addr4
				addr1 := testutils.TestAddress("additional1")
				addr2 := testutils.TestAddress("additional2")
				addr3 := testutils.TestAddress("additional3")
				addr4 := testutils.TestAddress("additional4")

				if err := k.register(addr1, addr2); err != nil {
					return err
				}
				if err := k.register(addr2, addr3); err != nil {
					return err
				}
				return k.register(addr3, addr4)
			},
			verifyChain: func(k *keeper) error {
				addr1 := testutils.TestAddress("additional1")
				addr2 := testutils.TestAddress("additional2")
				addr3 := testutils.TestAddress("additional3")
				addr4 := testutils.TestAddress("additional4")

				// Verify each link in the chain
				ref1, err := k.get(addr1)
				if err != nil {
					return err
				}
				if ref1.String() != addr2.String() {
					return ErrNotFound
				}

				ref2, err := k.get(addr2)
				if err != nil {
					return err
				}
				if ref2.String() != addr3.String() {
					return ErrNotFound
				}

				ref3, err := k.get(addr3)
				if err != nil {
					return err
				}
				if ref3.String() != addr4.String() {
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

				return k.register(chainAddr1, chainAddr2)
			},
			verifyChain: func(k *keeper) error {
				chainAddr1 := testutils.TestAddress("chain1")
				chainAddr2 := testutils.TestAddress("chain2")

				ref, err := k.get(chainAddr1)
				if err != nil {
					return err
				}
				if ref.String() != chainAddr2.String() {
					return ErrNotFound
				}
				return nil
			},
			expectedError: nil,
		},
	}

	for _, tc := range tests {
		t.Run(tc.name, func(t *testing.T) {
			// given
			k := setupAdditionalKeeper()
			cleanup := setupAdditionalCaller()
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

func TestAdditional_RateLimitingEdgeCases(t *testing.T) {
	tests := []struct {
		name          string
		setupTest     func(*keeper) error
		expectedError error
	}{
		{
			name: "Rate limiting with different operation types",
			setupTest: func(k *keeper) error {
				rateSpecificAddr1 := testutils.TestAddress("rateSpecific1")
				rateSpecificAddr2 := testutils.TestAddress("rateSpecific2")

				// Register first
				if err := k.register(rateSpecificAddr1, rateSpecificAddr2); err != nil {
					return err
				}

				// Try to update immediately (should be rate limited)
				return k.update(rateSpecificAddr1, testutils.TestAddress("rateSpecific3"))
			},
			expectedError: ErrTooManyRequests,
		},
		{
			name: "Rate limiting is per address",
			setupTest: func(k *keeper) error {
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

	for _, tc := range tests {
		t.Run(tc.name, func(t *testing.T) {
			// given
			k := setupAdditionalKeeper()
			cleanup := setupAdditionalCaller()
			defer cleanup()

			// when
			err := tc.setupTest(k)

			// then
			uassert.ErrorIs(t, err, tc.expectedError)
		})
	}
}

func TestAdditional_PermissionValidation(t *testing.T) {
	tests := []struct {
		name          string
		setupCaller   func() func()
		operation     func(*keeper) error
		expectError   bool
		errorContains string
	}{
		{
			name: "Valid caller can register",
			setupCaller: func() func() {
				return setupAdditionalCaller()
			},
			operation: func(k *keeper) error {
				return k.register(testutils.TestAddress("perm1"), testutils.TestAddress("perm2"))
			},
			expectError: false,
		},
		{
			name: "Invalid caller cannot register",
			setupCaller: func() func() {
				return setupInvalidCaller()
			},
			operation: func(k *keeper) error {
				return k.register(testutils.TestAddress("perm3"), testutils.TestAddress("perm4"))
			},
			expectError:   true,
			errorContains: "unauthorized caller",
		},
	}

	for _, tc := range tests {
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
						strings.Contains(err.Error(), tc.errorContains))
				}
			} else {
				uassert.NoError(t, err)
			}
		})
	}
}

func TestAdditional_EdgeCases(t *testing.T) {
	tests := []struct {
		name          string
		setupTest     func(*keeper) error
		verifyTest    func(*keeper) error
		expectedError error
	}{
		{
			name: "Multiple registrations same pair",
			setupTest: func(k *keeper) error {
				edgeAddr1 := testutils.TestAddress("edge1")
				edgeAddr2 := testutils.TestAddress("edge2")

				// Register once
				if err := k.register(edgeAddr1, edgeAddr2); err != nil {
					return err
				}
				// Try to register again with same pair (should be rate limited)
				return k.register(edgeAddr1, edgeAddr2)
			},
			verifyTest: func(k *keeper) error {
				return nil // No verification needed for expected error
			},
			expectedError: ErrTooManyRequests,
		},
		{
			name: "Zero address operations",
			setupTest: func(k *keeper) error {
				edgeAddr3 := testutils.TestAddress("edge3")
				// Register with zero address (should work and remove any existing)
				return k.register(edgeAddr3, zeroAddress)
			},
			verifyTest: func(k *keeper) error {
				edgeAddr3 := testutils.TestAddress("edge3")
				has := k.has(edgeAddr3)
				if has {
					return ErrInvalidAddress // Should not have referral
				}
				return nil
			},
			expectedError: nil,
		},
	}

	for _, tc := range tests {
		t.Run(tc.name, func(t *testing.T) {
			// given
			k := setupAdditionalKeeper()
			cleanup := setupAdditionalCaller()
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

func TestAdditional_StressScenarios(t *testing.T) {
	tests := []struct {
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
				// Verify all referrals exist
				for i := 0; i < 10; i++ {
					addr := testutils.TestAddress("stress" + string(rune(i+'0')))
					refAddr := testutils.TestAddress("ref" + string(rune(i+'0')))

					if !k.has(addr) {
						return ErrNotFound
					}
					ref, err := k.get(addr)
					if err != nil {
						return err
					}
					if ref.String() != refAddr.String() {
						return ErrNotFound
					}
				}
				return nil
			},
			expectedError: nil,
		},
		{
			name: "Large scale operations",
			setupTest: func(k *keeper) error {
				// Register many different referrals
				for i := 0; i < 50; i++ {
					addr := testutils.TestAddress("large" + string(rune(i+'0')))
					refAddr := testutils.TestAddress("largeRef" + string(rune(i+'0')))

					if err := k.register(addr, refAddr); err != nil {
						return err
					}
				}
				return nil
			},
			verifyTest: func(k *keeper) error {
				// Verify keeper is not empty
				if k.isEmpty() {
					return ErrNotFound
				}
				// Spot check a few entries
				for i := 0; i < 5; i++ {
					addr := testutils.TestAddress("large" + string(rune(i+'0')))
					if !k.has(addr) {
						return ErrNotFound
					}
				}
				return nil
			},
			expectedError: nil,
		},
	}

	for _, tc := range tests {
		t.Run(tc.name, func(t *testing.T) {
			// given
			k := setupAdditionalKeeper()
			cleanup := setupAdditionalCaller()
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

func TestAdditional_GlobalStateConsistency(t *testing.T) {
	tests := []struct {
		name           string
		operations     []func(*keeper) error
		finalCheck     func(*keeper) error
		expectedResult bool
	}{
		{
			name: "Mixed operations maintain consistency",
			operations: []func(*keeper) error{
				func(k *keeper) error {
					return k.register(testutils.TestAddress("mix1"), testutils.TestAddress("mix2"))
				},
				func(k *keeper) error {
					return k.register(testutils.TestAddress("mix3"), testutils.TestAddress("mix4"))
				},
				func(k *keeper) error {
					return k.remove(testutils.TestAddress("mix1"))
				},
			},
			finalCheck: func(k *keeper) error {
				// Should have mix3 but not mix1
				if k.has(testutils.TestAddress("mix1")) {
					return ErrInvalidAddress
				}
				if !k.has(testutils.TestAddress("mix3")) {
					return ErrNotFound
				}
				return nil
			},
			expectedResult: true,
		},
		{
			name: "Empty after all removals",
			operations: []func(*keeper) error{
				func(k *keeper) error {
					return k.register(testutils.TestAddress("temp1"), testutils.TestAddress("temp2"))
				},
				func(k *keeper) error {
					return k.register(testutils.TestAddress("temp3"), testutils.TestAddress("temp4"))
				},
				func(k *keeper) error {
					return k.remove(testutils.TestAddress("temp1"))
				},
				func(k *keeper) error {
					return k.remove(testutils.TestAddress("temp3"))
				},
			},
			finalCheck: func(k *keeper) error {
				if !k.isEmpty() {
					return ErrInvalidAddress
				}
				return nil
			},
			expectedResult: true,
		},
	}

	for _, tc := range tests {
		t.Run(tc.name, func(t *testing.T) {
			// given
			k := setupAdditionalKeeper()
			cleanup := setupAdditionalCaller()
			defer cleanup()

			// when
			for _, op := range tc.operations {
				err := op(k)
				uassert.NoError(t, err)
			}

			// then
			err := tc.finalCheck(k)
			if tc.expectedResult {
				uassert.NoError(t, err)
			} else {
				uassert.Error(t, err)
			}
		})
	}
}

// Helper functions at the bottom of the file

func setupAdditionalKeeper() *keeper {
	return NewKeeper().(*keeper)
}

func setupAdditionalCaller() func() {
	origCaller := std.OriginCaller()
	routerAddr, _ := access.GetAddress(access.ROLE_ROUTER)
	testing.SetOriginCaller(routerAddr)
	return func() {
		testing.SetOriginCaller(origCaller)
	}
}

func setupInvalidCaller() func() {
	origCaller := std.OriginCaller()
	testing.SetOriginCaller(std.Address("unauthorized"))
	return func() {
		testing.SetOriginCaller(origCaller)
	}
}
