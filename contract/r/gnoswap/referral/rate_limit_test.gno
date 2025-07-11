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
	tt := []struct {
		name          string
		userAddr      std.Address
		referrerAddr  std.Address
		secondAddr    std.Address
		operation     string
		expectedError error
	}{
		{
			name:          "allows first operation within 24 hours",
			userAddr:      testutils.TestAddress("basic1"),
			referrerAddr:  testutils.TestAddress("basic2"),
			secondAddr:    testutils.TestAddress("basic3"),
			operation:     "register",
			expectedError: nil,
		},
		{
			name:          "blocks second operation within 24 hours",
			userAddr:      testutils.TestAddress("basic4"),
			referrerAddr:  testutils.TestAddress("basic5"),
			secondAddr:    testutils.TestAddress("basic6"),
			operation:     "update_after_register",
			expectedError: ErrTooManyRequests,
		},
		{
			name:          "rate limiting is address-specific",
			userAddr:      testutils.TestAddress("basic7"),
			referrerAddr:  testutils.TestAddress("basic8"),
			secondAddr:    testutils.TestAddress("basic9"),
			operation:     "different_address",
			expectedError: nil,
		},
	}

	for _, tc := range tt {
		t.Run(tc.name, func(t *testing.T) {
			// given
			cleanup := mockValidCallerRateLimit()
			defer cleanup()
			k := setupRateLimitKeeper()

			// when & then
			switch tc.operation {
			case "register":
				err := k.register(tc.userAddr, tc.referrerAddr)
				uassert.ErrorIs(t, err, tc.expectedError)
				if err == nil {
					uassert.True(t, k.has(tc.userAddr))
					ref, err := k.get(tc.userAddr)
					uassert.NoError(t, err)
					uassert.Equal(t, tc.referrerAddr.String(), ref.String())
				}
			case "update_after_register":
				err := k.register(tc.userAddr, tc.referrerAddr)
				uassert.NoError(t, err)
				err = k.update(tc.userAddr, tc.secondAddr)
				uassert.ErrorIs(t, err, tc.expectedError)
				// Verify original referral remains unchanged
				ref, err := k.get(tc.userAddr)
				uassert.NoError(t, err)
				uassert.Equal(t, tc.referrerAddr.String(), ref.String())
			case "different_address":
				err := k.register(tc.userAddr, tc.referrerAddr)
				uassert.NoError(t, err)
				err = k.register(tc.secondAddr, tc.referrerAddr)
				uassert.ErrorIs(t, err, tc.expectedError)
				// Verify both registrations exist correctly
				ref1, err := k.get(tc.userAddr)
				uassert.NoError(t, err)
				uassert.Equal(t, tc.referrerAddr.String(), ref1.String())
				ref2, err := k.get(tc.secondAddr)
				uassert.NoError(t, err)
				uassert.Equal(t, tc.referrerAddr.String(), ref2.String())
			}
		})
	}
}

// TestRateLimitingOperationTypes tests rate limiting across different operation types
func TestRateLimitingOperationTypes(t *testing.T) {
	tt := []struct {
		name          string
		userAddr      std.Address
		referrerAddr  std.Address
		secondAddr    std.Address
		operation     string
		expectedError error
	}{
		{
			name:          "register followed by update is rate limited",
			userAddr:      testutils.TestAddress("op1"),
			referrerAddr:  testutils.TestAddress("op2"),
			secondAddr:    testutils.TestAddress("op3"),
			operation:     "register_then_update",
			expectedError: ErrTooManyRequests,
		},
		{
			name:          "update followed by register is rate limited",
			userAddr:      testutils.TestAddress("op4"),
			referrerAddr:  testutils.TestAddress("op5"),
			secondAddr:    testutils.TestAddress("op6"),
			operation:     "update_then_register",
			expectedError: ErrTooManyRequests,
		},
		{
			name:          "multiple update attempts are rate limited",
			userAddr:      testutils.TestAddress("op7"),
			referrerAddr:  testutils.TestAddress("op8"),
			secondAddr:    testutils.TestAddress("op9"),
			operation:     "multiple_updates",
			expectedError: ErrTooManyRequests,
		},
	}

	for _, tc := range tt {
		t.Run(tc.name, func(t *testing.T) {
			// given
			cleanup := mockValidCallerRateLimit()
			defer cleanup()
			k := setupRateLimitKeeper()

			// when & then
			switch tc.operation {
			case "register_then_update":
				err := k.register(tc.userAddr, tc.referrerAddr)
				uassert.NoError(t, err)
				err = k.update(tc.userAddr, tc.secondAddr)
				uassert.ErrorIs(t, err, tc.expectedError)
				// Verify original referral remains unchanged
				ref, err := k.get(tc.userAddr)
				uassert.NoError(t, err)
				uassert.Equal(t, tc.referrerAddr.String(), ref.String())
			case "update_then_register":
				err := k.update(tc.userAddr, tc.referrerAddr)
				uassert.NoError(t, err)
				err = k.register(tc.userAddr, tc.secondAddr)
				uassert.ErrorIs(t, err, tc.expectedError)
				// Verify original referral remains unchanged
				ref, err := k.get(tc.userAddr)
				uassert.NoError(t, err)
				uassert.Equal(t, tc.referrerAddr.String(), ref.String())
			case "multiple_updates":
				err := k.update(tc.userAddr, tc.referrerAddr)
				uassert.NoError(t, err)
				err = k.update(tc.userAddr, tc.secondAddr)
				uassert.ErrorIs(t, err, tc.expectedError)
				err = k.update(tc.userAddr, testutils.TestAddress("temp"))
				uassert.ErrorIs(t, err, tc.expectedError)
				// Verify original referral remains unchanged
				ref, err := k.get(tc.userAddr)
				uassert.NoError(t, err)
				uassert.Equal(t, tc.referrerAddr.String(), ref.String())
			}
		})
	}
}

// TestRateLimitingTimeWindow tests the 24-hour time window
func TestRateLimitingTimeWindow(t *testing.T) {
	tt := []struct {
		name          string
		userAddr      std.Address
		referrerAddr  std.Address
		secondAddr    std.Address
		operation     string
		expectedError error
	}{
		{
			name:          "tracks operation timestamps",
			userAddr:      testutils.TestAddress("time1"),
			referrerAddr:  testutils.TestAddress("time2"),
			secondAddr:    testutils.TestAddress("time3"),
			operation:     "register_then_update",
			expectedError: ErrTooManyRequests,
		},
		{
			name:          "maintains separate timestamps per address",
			userAddr:      testutils.TestAddress("time4"),
			referrerAddr:  testutils.TestAddress("time5"),
			secondAddr:    testutils.TestAddress("time6"),
			operation:     "separate_timestamps",
			expectedError: ErrTooManyRequests,
		},
		{
			name:          "validates time window calculation",
			userAddr:      testutils.TestAddress("time7"),
			referrerAddr:  testutils.TestAddress("time8"),
			secondAddr:    testutils.TestAddress("time9"),
			operation:     "immediate_second_operation",
			expectedError: ErrTooManyRequests,
		},
	}

	for _, tc := range tt {
		t.Run(tc.name, func(t *testing.T) {
			// given
			cleanup := mockValidCallerRateLimit()
			defer cleanup()
			k := setupRateLimitKeeper()

			// when & then
			switch tc.operation {
			case "register_then_update":
				err := k.register(tc.userAddr, tc.referrerAddr)
				uassert.NoError(t, err)
				err = k.update(tc.userAddr, tc.secondAddr)
				uassert.ErrorIs(t, err, tc.expectedError)
			case "separate_timestamps":
				err := k.register(tc.userAddr, tc.referrerAddr)
				uassert.NoError(t, err)
				err = k.register(tc.secondAddr, tc.referrerAddr)
				uassert.NoError(t, err)
				// Both should be independently rate limited
				err = k.update(tc.userAddr, tc.secondAddr)
				uassert.ErrorIs(t, err, tc.expectedError)
				err = k.update(tc.secondAddr, tc.userAddr)
				uassert.ErrorIs(t, err, tc.expectedError)
			case "immediate_second_operation":
				err := k.register(tc.userAddr, tc.referrerAddr)
				uassert.NoError(t, err)
				err = k.update(tc.userAddr, tc.secondAddr)
				uassert.ErrorIs(t, err, tc.expectedError)
			}
		})
	}
}

// TestRateLimitingEdgeCases tests edge cases in rate limiting
func TestRateLimitingEdgeCases(t *testing.T) {
	tt := []struct {
		name          string
		userAddr      std.Address
		referrerAddr  std.Address
		secondAddr    std.Address
		operation     string
		expectedError error
	}{
		{
			name:          "failed operations do not affect rate limiting",
			userAddr:      testutils.TestAddress("edge1"),
			referrerAddr:  testutils.TestAddress("edge2"),
			secondAddr:    testutils.TestAddress("edge3"),
			operation:     "failed_self_referral",
			expectedError: ErrTooManyRequests,
		},
		{
			name:          "zero address referrals respect rate limiting",
			userAddr:      testutils.TestAddress("edge4"),
			referrerAddr:  testutils.TestAddress("edge5"),
			secondAddr:    testutils.TestAddress("edge6"),
			operation:     "zero_address_referral",
			expectedError: ErrTooManyRequests,
		},
		{
			name:          "operations maintain proper state",
			userAddr:      testutils.TestAddress("edge7"),
			referrerAddr:  testutils.TestAddress("edge8"),
			secondAddr:    testutils.TestAddress("edge9"),
			operation:     "proper_state_maintenance",
			expectedError: ErrTooManyRequests,
		},
	}

	for _, tc := range tt {
		t.Run(tc.name, func(t *testing.T) {
			// given
			cleanup := mockValidCallerRateLimit()
			defer cleanup()
			k := setupRateLimitKeeper()

			// when & then
			switch tc.operation {
			case "failed_self_referral":
				// Failed operation (self referral) should not trigger rate limiting
				err := k.register(tc.userAddr, tc.userAddr)
				uassert.ErrorIs(t, err, ErrSelfReferral)
				// Subsequent valid operation should succeed
				err = k.register(tc.userAddr, tc.referrerAddr)
				uassert.NoError(t, err)
				// Now rate limiting should be active
				err = k.update(tc.userAddr, tc.secondAddr)
				uassert.ErrorIs(t, err, tc.expectedError)
				// Verify correct referral exists
				ref, err := k.get(tc.userAddr)
				uassert.NoError(t, err)
				uassert.Equal(t, tc.referrerAddr.String(), ref.String())
			case "zero_address_referral":
				// Register with zero address (no-op when no prior registration exists)
				err := k.register(tc.userAddr, zeroAddress)
				uassert.NoError(t, err)
				// Subsequent registration should succeed
				err = k.register(tc.userAddr, tc.referrerAddr)
				uassert.NoError(t, err)
				// Now rate limiting should apply
				err = k.update(tc.userAddr, tc.secondAddr)
				uassert.ErrorIs(t, err, tc.expectedError)
				// Verify correct referral exists
				ref, err := k.get(tc.userAddr)
				uassert.NoError(t, err)
				uassert.Equal(t, tc.referrerAddr.String(), ref.String())
			case "proper_state_maintenance":
				// Perform operation
				err := k.register(tc.userAddr, tc.referrerAddr)
				uassert.NoError(t, err)
				// Rate limited operation should fail
				err = k.update(tc.userAddr, tc.secondAddr)
				uassert.ErrorIs(t, err, tc.expectedError)
				// Verify state is maintained
				ref, err := k.get(tc.userAddr)
				uassert.NoError(t, err)
				uassert.Equal(t, tc.referrerAddr.String(), ref.String())
			}
		})
	}
}

// TestRateLimitingConsistency tests consistency of rate limiting behavior
func TestRateLimitingConsistency(t *testing.T) {
	tt := []struct {
		name          string
		userAddr      std.Address
		referrerAddr  std.Address
		secondAddr    std.Address
		operation     string
		expectedError error
	}{
		{
			name:          "consistent rate limiting across multiple operations",
			userAddr:      testutils.TestAddress("cons1"),
			referrerAddr:  testutils.TestAddress("cons2"),
			secondAddr:    testutils.TestAddress("cons3"),
			operation:     "multiple_operations",
			expectedError: nil,
		},
		{
			name:          "rate limiting preserves data integrity",
			userAddr:      testutils.TestAddress("cons4"),
			referrerAddr:  testutils.TestAddress("cons5"),
			secondAddr:    testutils.TestAddress("cons6"),
			operation:     "data_integrity",
			expectedError: ErrTooManyRequests,
		},
		{
			name:          "independent rate limiting per address",
			userAddr:      testutils.TestAddress("cons7"),
			referrerAddr:  testutils.TestAddress("cons8"),
			secondAddr:    testutils.TestAddress("cons9"),
			operation:     "independent_limiting",
			expectedError: nil,
		},
	}

	for _, tc := range tt {
		t.Run(tc.name, func(t *testing.T) {
			// given
			cleanup := mockValidCallerRateLimit()
			defer cleanup()
			k := setupRateLimitKeeper()

			// when & then
			switch tc.operation {
			case "multiple_operations":
				// First operation
				err := k.register(tc.userAddr, tc.referrerAddr)
				uassert.NoError(t, err)
				// Multiple rate-limited attempts should all fail consistently
				for i := 0; i < 5; i++ {
					err = k.update(tc.userAddr, testutils.TestAddress("temp"+string(rune(i+'0'))))
					uassert.ErrorIs(t, err, ErrTooManyRequests)
				}
				// Original referral should remain unchanged
				ref, err := k.get(tc.userAddr)
				uassert.NoError(t, err)
				uassert.Equal(t, tc.referrerAddr.String(), ref.String())
			case "data_integrity":
				// Establish initial state
				err := k.register(tc.userAddr, tc.referrerAddr)
				uassert.NoError(t, err)
				err = k.register(tc.secondAddr, tc.referrerAddr)
				uassert.NoError(t, err)
				// Rate-limited operations should not affect other data
				err = k.update(tc.userAddr, tc.secondAddr)
				uassert.ErrorIs(t, err, tc.expectedError)
				// Both original referrals should be intact
				ref1, err := k.get(tc.userAddr)
				uassert.NoError(t, err)
				uassert.Equal(t, tc.referrerAddr.String(), ref1.String())
				ref2, err := k.get(tc.secondAddr)
				uassert.NoError(t, err)
				uassert.Equal(t, tc.referrerAddr.String(), ref2.String())
			case "independent_limiting":
				// Multiple addresses with operations
				addrs := []std.Address{tc.userAddr, tc.referrerAddr, tc.secondAddr}
				refs := []std.Address{
					testutils.TestAddress("indep1"),
					testutils.TestAddress("indep2"),
					testutils.TestAddress("indep3"),
				}
				// Each address gets one operation
				for i, addr := range addrs {
					err := k.register(addr, refs[i])
					uassert.NoError(t, err)
				}
				// Each address should be independently rate limited
				for _, addr := range addrs {
					err := k.update(addr, testutils.TestAddress("temp"))
					uassert.ErrorIs(t, err, ErrTooManyRequests)
				}
				// Verify all original referrals are intact
				for i, addr := range addrs {
					ref, err := k.get(addr)
					uassert.NoError(t, err)
					uassert.Equal(t, refs[i].String(), ref.String())
				}
			}
		})
	}
}
