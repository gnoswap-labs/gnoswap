package referral

import (
	"chain/runtime"
	"strings"
	"testing"
	"time"

	"gno.land/p/nt/testutils"
	"gno.land/p/nt/uassert"

	prabc "gno.land/p/gnoswap/rbac"

	"gno.land/r/gnoswap/access"
)

func TestRateLimit_BasicFunctionality(t *testing.T) {
	tests := []struct {
		name          string
		userAddr      address
		referrerAddr  address
		secondAddr    address
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

	for _, tc := range tests {
		t.Run(tc.name, func(t *testing.T) {
			// given
			cleanup := setupValidCaller()
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

func TestRateLimit_OperationTypes(t *testing.T) {
	tests := []struct {
		name          string
		userAddr      address
		referrerAddr  address
		secondAddr    address
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

	for _, tc := range tests {
		t.Run(tc.name, func(t *testing.T) {
			// given
			cleanup := setupValidCaller()
			defer cleanup()
			k := setupRateLimitKeeper()

			// when & then
			switch tc.operation {
			case "register_then_update":
				err := k.register(tc.userAddr, tc.referrerAddr)
				uassert.NoError(t, err)
				err = k.update(tc.userAddr, tc.secondAddr)
				uassert.ErrorIs(t, err, tc.expectedError)
			case "update_then_register":
				err := k.update(tc.userAddr, tc.referrerAddr)
				uassert.NoError(t, err)
				err = k.register(tc.userAddr, tc.secondAddr)
				uassert.ErrorIs(t, err, tc.expectedError)
			case "multiple_updates":
				err := k.update(tc.userAddr, tc.referrerAddr)
				uassert.NoError(t, err)
				err = k.update(tc.userAddr, tc.secondAddr)
				uassert.ErrorIs(t, err, tc.expectedError)
			}
		})
	}
}

func TestRateLimit_ExceptionCases(t *testing.T) {
	tests := []struct {
		name          string
		userAddr      address
		referrerAddr  address
		operation     string
		expectedError error
		expectedHas   bool
	}{
		{
			name:          "zero address referral is not rate limited",
			userAddr:      testutils.TestAddress("exc1"),
			referrerAddr:  zeroAddress,
			operation:     "zero_referral",
			expectedError: nil,
			expectedHas:   false,
		},
		{
			name:          "remove operation is rate limited",
			userAddr:      testutils.TestAddress("exc2"),
			referrerAddr:  testutils.TestAddress("exc3"),
			operation:     "remove_after_register",
			expectedError: ErrTooManyRequests,
			expectedHas:   true,
		},
		{
			name:          "consecutive zero address operations not rate limited",
			userAddr:      testutils.TestAddress("exc4"),
			referrerAddr:  zeroAddress,
			operation:     "multiple_zero_operations",
			expectedError: nil,
			expectedHas:   false,
		},
	}

	for _, tc := range tests {
		t.Run(tc.name, func(t *testing.T) {
			// given
			cleanup := setupValidCaller()
			defer cleanup()
			k := setupRateLimitKeeper()

			// when & then
			switch tc.operation {
			case "zero_referral":
				err := k.register(tc.userAddr, tc.referrerAddr)
				uassert.ErrorIs(t, err, tc.expectedError)
				err = k.register(tc.userAddr, tc.referrerAddr)
				uassert.ErrorIs(t, err, tc.expectedError)
				uassert.Equal(t, tc.expectedHas, k.has(tc.userAddr))
			case "remove_after_register":
				err := k.register(tc.userAddr, tc.referrerAddr)
				uassert.NoError(t, err)
				err = k.remove(tc.userAddr)
				uassert.ErrorIs(t, err, tc.expectedError)
				uassert.Equal(t, tc.expectedHas, k.has(tc.userAddr))
			case "multiple_zero_operations":
				for i := 0; i < 3; i++ {
					err := k.register(tc.userAddr, tc.referrerAddr)
					uassert.ErrorIs(t, err, tc.expectedError)
				}
				uassert.Equal(t, tc.expectedHas, k.has(tc.userAddr))
			}
		})
	}
}

func TestRateLimit_BoundaryConditions(t *testing.T) {
	tests := []struct {
		name          string
		userAddr      address
		referrerAddr  address
		operation     string
		expectedError error
	}{
		{
			name:          "same referral address multiple times rate limited",
			userAddr:      testutils.TestAddress("bound1"),
			referrerAddr:  testutils.TestAddress("bound2"),
			operation:     "same_referral_multiple",
			expectedError: ErrTooManyRequests,
		},
		{
			name:          "different referral addresses rate limited",
			userAddr:      testutils.TestAddress("bound3"),
			referrerAddr:  testutils.TestAddress("bound4"),
			operation:     "different_referral_multiple",
			expectedError: ErrTooManyRequests,
		},
		{
			name:          "mixed operations rate limited",
			userAddr:      testutils.TestAddress("bound5"),
			referrerAddr:  testutils.TestAddress("bound6"),
			operation:     "mixed_operations",
			expectedError: ErrTooManyRequests,
		},
	}

	for _, tc := range tests {
		t.Run(tc.name, func(t *testing.T) {
			// given
			cleanup := setupValidCaller()
			defer cleanup()
			k := setupRateLimitKeeper()

			// when & then
			switch tc.operation {
			case "same_referral_multiple":
				err := k.register(tc.userAddr, tc.referrerAddr)
				uassert.NoError(t, err)
				err = k.register(tc.userAddr, tc.referrerAddr)
				uassert.ErrorIs(t, err, tc.expectedError)
			case "different_referral_multiple":
				err := k.register(tc.userAddr, tc.referrerAddr)
				uassert.NoError(t, err)
				err = k.update(tc.userAddr, testutils.TestAddress("bound7"))
				uassert.ErrorIs(t, err, tc.expectedError)
			case "mixed_operations":
				err := k.register(tc.userAddr, tc.referrerAddr)
				uassert.NoError(t, err)
				err = k.update(tc.userAddr, testutils.TestAddress("bound8"))
				uassert.ErrorIs(t, err, tc.expectedError)
			}
		})
	}
}

func TestRateLimit_ErrorPropagation(t *testing.T) {
	tests := []struct {
		name          string
		caller        string
		userAddr      address
		referrerAddr  address
		operation     string
		expectedError error
	}{
		{
			name:          "unauthorized caller error takes precedence",
			caller:        "unauthorized",
			userAddr:      testutils.TestAddress("err1"),
			referrerAddr:  testutils.TestAddress("err2"),
			operation:     "unauthorized_register",
			expectedError: ErrUnauthorized,
		},
		{
			name:          "self referral error takes precedence",
			caller:        "router",
			userAddr:      testutils.TestAddress("err3"),
			referrerAddr:  testutils.TestAddress("err3"),
			operation:     "self_referral_register",
			expectedError: ErrSelfReferral,
		},
		{
			name:          "rate limit error after valid registration",
			caller:        "router",
			userAddr:      testutils.TestAddress("err4"),
			referrerAddr:  testutils.TestAddress("err5"),
			operation:     "rate_limit_after_register",
			expectedError: ErrTooManyRequests,
		},
	}

	for _, tc := range tests {
		t.Run(tc.name, func(t *testing.T) {
			// given
			cleanup := setupRateLimitCaller(tc.caller)
			defer cleanup()
			k := setupRateLimitKeeper()

			// when & then
			switch tc.operation {
			case "unauthorized_register":
				err := k.register(tc.userAddr, tc.referrerAddr)
				uassert.Error(t, err)
				uassert.True(t, strings.Contains(err.Error(), "unauthorized caller"))
			case "self_referral_register":
				err := k.register(tc.userAddr, tc.referrerAddr)
				uassert.ErrorIs(t, err, tc.expectedError)
			case "rate_limit_after_register":
				err := k.register(tc.userAddr, tc.referrerAddr)
				uassert.NoError(t, err)
				err = k.update(tc.userAddr, testutils.TestAddress("err6"))
				uassert.ErrorIs(t, err, tc.expectedError)
			}
		})
	}
}

func TestRateLimit_TimeBoundaryConditions(t *testing.T) {
	tests := []struct {
		name             string
		userAddr         address
		referrerAddr     address
		secondRefAddr    address
		timeSinceLastOp  int64
		expectedError    error
		expectedErrorMsg string
	}{
		{
			name:             "24 hours minus 1 second - rate limited",
			userAddr:         testutils.TestAddress("timeBound1"),
			referrerAddr:     testutils.TestAddress("timeBound2"),
			secondRefAddr:    testutils.TestAddress("timeBound3"),
			timeSinceLastOp:  MinTimeBetweenUpdates - 1, // 86399
			expectedError:    ErrTooManyRequests,
			expectedErrorMsg: "too many requests",
		},
		{
			name:             "exactly 24 hours - allowed",
			userAddr:         testutils.TestAddress("timeBound4"),
			referrerAddr:     testutils.TestAddress("timeBound5"),
			secondRefAddr:    testutils.TestAddress("timeBound6"),
			timeSinceLastOp:  MinTimeBetweenUpdates, // 86400
			expectedError:    nil,
			expectedErrorMsg: "",
		},
		{
			name:             "24 hours plus 1 second - allowed",
			userAddr:         testutils.TestAddress("timeBound7"),
			referrerAddr:     testutils.TestAddress("timeBound8"),
			secondRefAddr:    testutils.TestAddress("timeBound9"),
			timeSinceLastOp:  MinTimeBetweenUpdates + 1, // 86401
			expectedError:    nil,
			expectedErrorMsg: "",
		},
	}

	for _, tc := range tests {
		t.Run(tc.name, func(t *testing.T) {
			// given
			cleanup := setupValidCaller()
			defer cleanup()
			k := setupRateLimitKeeper()

			// First registration
			err := k.register(tc.userAddr, tc.referrerAddr)
			uassert.NoError(t, err)

			// Manually set lastOps to simulate time passage
			now := time.Now().Unix()
			k.lastOps[tc.userAddr.String()] = now - tc.timeSinceLastOp

			// when - attempt update
			err = k.update(tc.userAddr, tc.secondRefAddr)

			// then
			if tc.expectedError != nil {
				uassert.ErrorIs(t, err, tc.expectedError)
			} else {
				uassert.NoError(t, err)
				// Verify update succeeded
				ref, err := k.get(tc.userAddr)
				uassert.NoError(t, err)
				uassert.Equal(t, tc.secondRefAddr.String(), ref.String())
			}
		})
	}
}

func TestRateLimit_AddressIsolation(t *testing.T) {
	tests := []struct {
		name          string
		addr1         address
		addr2         address
		ref1          address
		ref2          address
		expectedError error
	}{
		{
			name:          "different addresses not rate limited",
			addr1:         testutils.TestAddress("iso1"),
			addr2:         testutils.TestAddress("iso2"),
			ref1:          testutils.TestAddress("iso3"),
			ref2:          testutils.TestAddress("iso4"),
			expectedError: nil,
		},
		{
			name:          "same referrer different addresses not rate limited",
			addr1:         testutils.TestAddress("iso5"),
			addr2:         testutils.TestAddress("iso6"),
			ref1:          testutils.TestAddress("iso7"),
			ref2:          testutils.TestAddress("iso7"),
			expectedError: nil,
		},
	}

	for _, tc := range tests {
		t.Run(tc.name, func(t *testing.T) {
			// given
			cleanup := setupValidCaller()
			defer cleanup()
			k := setupRateLimitKeeper()

			// when
			err1 := k.register(tc.addr1, tc.ref1)
			err2 := k.register(tc.addr2, tc.ref2)

			// then
			uassert.ErrorIs(t, err1, tc.expectedError)
			uassert.ErrorIs(t, err2, tc.expectedError)

			if tc.expectedError == nil {
				uassert.True(t, k.has(tc.addr1))
				uassert.True(t, k.has(tc.addr2))
				ref1, err := k.get(tc.addr1)
				uassert.NoError(t, err)
				uassert.Equal(t, tc.ref1.String(), ref1.String())
				ref2, err := k.get(tc.addr2)
				uassert.NoError(t, err)
				uassert.Equal(t, tc.ref2.String(), ref2.String())
			}
		})
	}
}

// Helper functions at the bottom of the file

func setupRateLimitKeeper() *keeper {
	return NewKeeper().(*keeper)
}

func setupValidCaller() func() {
	origCaller := runtime.OriginCaller()
	routerAddr, _ := access.GetAddress(prabc.ROLE_ROUTER.String())
	testing.SetOriginCaller(routerAddr)
	return func() {
		testing.SetOriginCaller(origCaller)
	}
}

func setupRateLimitCaller(caller string) func() {
	origCaller := runtime.OriginCaller()
	switch caller {
	case "router":
		routerAddr, _ := access.GetAddress(prabc.ROLE_ROUTER.String())
		testing.SetOriginCaller(routerAddr)
	case "unauthorized":
		testing.SetOriginCaller(address("unauthorized"))
	}
	return func() {
		testing.SetOriginCaller(origCaller)
	}
}
