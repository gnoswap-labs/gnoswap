package referral

import (
	"std"
	"strings"
	"testing"

	"gno.land/p/demo/testutils"
	"gno.land/p/demo/uassert"

	prabc "gno.land/p/gnoswap/rbac"

	"gno.land/r/gnoswap/v1/access"
)

func TestValidation_SelfReferralPrevention(t *testing.T) {
	tests := []struct {
		name              string
		setupInitial      bool
		addr              std.Address
		initialRefAddr    std.Address
		targetRefAddr     std.Address
		operation         string // "register" or "update"
		expectedError     bool
		expectedErrorType error
		expectedRef       string
		expectedHas       bool
	}{
		{
			name:              "prevents self referral on register",
			setupInitial:      false,
			addr:              testutils.TestAddress("validation1"),
			initialRefAddr:    zeroAddress,
			targetRefAddr:     testutils.TestAddress("validation1"),
			operation:         "register",
			expectedError:     true,
			expectedErrorType: ErrSelfReferral,
			expectedRef:       "",
			expectedHas:       false,
		},
		{
			name:              "prevents self referral on update",
			setupInitial:      true,
			addr:              testutils.TestAddress("validation1"),
			initialRefAddr:    testutils.TestAddress("validation2"),
			targetRefAddr:     testutils.TestAddress("validation1"),
			operation:         "update",
			expectedError:     true,
			expectedErrorType: ErrSelfReferral,
			expectedRef:       testutils.TestAddress("validation2").String(),
			expectedHas:       true,
		},
		{
			name:              "allows same address as referrer for different users - first",
			setupInitial:      false,
			addr:              testutils.TestAddress("validation1"),
			initialRefAddr:    zeroAddress,
			targetRefAddr:     testutils.TestAddress("validation3"),
			operation:         "register",
			expectedError:     false,
			expectedErrorType: nil,
			expectedRef:       testutils.TestAddress("validation3").String(),
			expectedHas:       true,
		},
		{
			name:              "allows same address as referrer for different users - second",
			setupInitial:      false,
			addr:              testutils.TestAddress("validation2"),
			initialRefAddr:    zeroAddress,
			targetRefAddr:     testutils.TestAddress("validation3"),
			operation:         "register",
			expectedError:     false,
			expectedErrorType: nil,
			expectedRef:       testutils.TestAddress("validation3").String(),
			expectedHas:       true,
		},
	}

	for _, tc := range tests {
		t.Run(tc.name, func(t *testing.T) {
			// given
			cleanup := setupValidationCaller()
			defer cleanup()
			k := setupValidationKeeper()

			if tc.setupInitial {
				err := k.register(tc.addr, tc.initialRefAddr)
				uassert.NoError(t, err)
			}

			// when
			var err error
			switch tc.operation {
			case "register":
				err = k.register(tc.addr, tc.targetRefAddr)
			case "update":
				err = k.update(tc.addr, tc.targetRefAddr)
			}

			// then
			if tc.expectedError {
				uassert.Error(t, err)
				if tc.expectedErrorType != nil {
					uassert.ErrorIs(t, err, tc.expectedErrorType)
				}
			} else {
				uassert.NoError(t, err)
			}

			has := k.has(tc.addr)
			uassert.Equal(t, tc.expectedHas, has)

			if tc.expectedRef != "" {
				ref, err := k.get(tc.addr)
				uassert.NoError(t, err)
				uassert.Equal(t, tc.expectedRef, ref.String())
			}
		})
	}
}

func TestValidation_AddressValidation(t *testing.T) {
	tests := []struct {
		name          string
		addr          std.Address
		refAddr       std.Address
		operation     string
		expectedError bool
		expectedType  error
	}{
		{
			name:          "rejects invalid user address on register",
			addr:          std.Address(""),
			refAddr:       testutils.TestAddress("valid"),
			operation:     "register",
			expectedError: true,
			expectedType:  ErrInvalidAddress,
		},
		{
			name:          "rejects invalid referral address on register",
			addr:          testutils.TestAddress("valid"),
			refAddr:       std.Address("invalid"),
			operation:     "register",
			expectedError: true,
			expectedType:  ErrInvalidAddress,
		},
		{
			name:          "allows zero address as referral",
			addr:          testutils.TestAddress("valid"),
			refAddr:       zeroAddress,
			operation:     "register",
			expectedError: false,
			expectedType:  nil,
		},
		{
			name:          "rejects invalid user address on update",
			addr:          std.Address(""),
			refAddr:       testutils.TestAddress("valid"),
			operation:     "update",
			expectedError: true,
			expectedType:  ErrInvalidAddress,
		},
		{
			name:          "rejects invalid referral address on update",
			addr:          testutils.TestAddress("valid"),
			refAddr:       std.Address("invalid"),
			operation:     "update",
			expectedError: true,
			expectedType:  ErrInvalidAddress,
		},
	}

	for _, tc := range tests {
		t.Run(tc.name, func(t *testing.T) {
			// given
			cleanup := setupValidationCaller()
			defer cleanup()
			k := setupValidationKeeper()

			// when
			var err error
			switch tc.operation {
			case "register":
				err = k.register(tc.addr, tc.refAddr)
			case "update":
				err = k.update(tc.addr, tc.refAddr)
			}

			// then
			if tc.expectedError {
				uassert.Error(t, err)
				if tc.expectedType != nil {
					uassert.ErrorIs(t, err, tc.expectedType)
				}
			} else {
				uassert.NoError(t, err)
			}
		})
	}
}

func TestValidation_CallerAuthorization(t *testing.T) {
	tests := []struct {
		name          string
		caller        string
		addr          std.Address
		refAddr       std.Address
		operation     string
		expectedError bool
		expectedType  error
	}{
		{
			name:          "allows router to register",
			caller:        "router",
			addr:          testutils.TestAddress("user1"),
			refAddr:       testutils.TestAddress("ref1"),
			operation:     "register",
			expectedError: false,
			expectedType:  nil,
		},
		{
			name:          "allows router to update",
			caller:        "router",
			addr:          testutils.TestAddress("user2_update"),
			refAddr:       testutils.TestAddress("ref2_update"),
			operation:     "update",
			expectedError: false,
			expectedType:  nil,
		},
		{
			name:          "allows router to remove",
			caller:        "router",
			addr:          testutils.TestAddress("user3"),
			refAddr:       zeroAddress,
			operation:     "remove",
			expectedError: false,
			expectedType:  nil,
		},
		{
			name:          "rejects unauthorized register",
			caller:        "unauthorized",
			addr:          testutils.TestAddress("user4"),
			refAddr:       testutils.TestAddress("ref4"),
			operation:     "register",
			expectedError: true,
			expectedType:  nil, // Error message check instead of type check
		},
		{
			name:          "rejects unauthorized update",
			caller:        "unauthorized",
			addr:          testutils.TestAddress("user5"),
			refAddr:       testutils.TestAddress("ref5"),
			operation:     "update",
			expectedError: true,
			expectedType:  nil, // Error message check instead of type check
		},
		{
			name:          "rejects unauthorized remove",
			caller:        "unauthorized",
			addr:          testutils.TestAddress("user6"),
			refAddr:       zeroAddress,
			operation:     "remove",
			expectedError: true,
			expectedType:  nil, // Error message check instead of type check
		},
	}

	for _, tc := range tests {
		t.Run(tc.name, func(t *testing.T) {
			// given
			cleanup := setupSpecificCaller(tc.caller)
			defer cleanup()
			k := setupValidationKeeper()

			// Setup initial referral for update/remove operations
			if tc.operation == "update" || tc.operation == "remove" {
				routerCleanup := setupSpecificCaller("router")
				// For update test, create a new keeper with existing data to avoid rate limit
				if tc.operation == "update" {
					// Manually set up the initial referral without rate limiting
					k.store.Set(tc.addr.String(), testutils.TestAddress("initial").String())
				} else if tc.operation == "remove" && tc.caller == "router" {
					// For router remove test, manually set up initial referral without rate limiting
					k.store.Set(tc.addr.String(), testutils.TestAddress("initial").String())
				} else {
					k.register(tc.addr, testutils.TestAddress("initial"))
				}
				routerCleanup()
				// Reset caller to test caller
				cleanup()
				cleanup = setupSpecificCaller(tc.caller)
			}

		// when
		var err error
		switch tc.operation {
		case "register":
			err = k.register(tc.addr, tc.refAddr)
		case "update":
			err = k.update(tc.addr, tc.refAddr)
		case "remove":
			err = k.remove(tc.addr)
		}

		// then
		if tc.expectedError {
			uassert.Error(t, err)
			if tc.expectedType != nil {
				uassert.ErrorIs(t, err, tc.expectedType)
			} else if tc.caller == "unauthorized" {
				// For unauthorized callers, check that error message contains "unauthorized caller"
				uassert.True(t, strings.Contains(err.Error(), "unauthorized caller"))
			}
		} else {
			uassert.NoError(t, err)
		}
		})
	}
}

func TestValidation_EdgeCases(t *testing.T) {
	tests := []struct {
		name          string
		addr          std.Address
		refAddr       std.Address
		operation     string
		setupRef      bool
		expectedError bool
		expectedHas   bool
	}{
		{
			name:          "register with zero address removes existing referral",
			addr:          testutils.TestAddress("edge1"),
			refAddr:       zeroAddress,
			operation:     "register_zero",
			setupRef:      true,
			expectedError: false,
			expectedHas:   false,
		},
		{
			name:          "update with zero address removes existing referral",
			addr:          testutils.TestAddress("edge2"),
			refAddr:       zeroAddress,
			operation:     "update_zero",
			setupRef:      true,
			expectedError: false,
			expectedHas:   false,
		},
		{
			name:          "register zero address on empty state",
			addr:          testutils.TestAddress("edge3"),
			refAddr:       zeroAddress,
			operation:     "register_zero_empty",
			setupRef:      false,
			expectedError: false,
			expectedHas:   false,
		},
		{
			name:          "update zero address on empty state",
			addr:          testutils.TestAddress("edge4"),
			refAddr:       zeroAddress,
			operation:     "update_zero_empty",
			setupRef:      false,
			expectedError: false,
			expectedHas:   false,
		},
	}

	for _, tc := range tests {
		t.Run(tc.name, func(t *testing.T) {
			// given
			cleanup := setupValidationCaller()
			defer cleanup()
			k := setupValidationKeeper()

			if tc.setupRef {
				err := k.register(tc.addr, testutils.TestAddress("initial"))
				uassert.NoError(t, err)
			}

			// when
			var err error
			switch tc.operation {
			case "register_zero", "register_zero_empty":
				err = k.register(tc.addr, tc.refAddr)
			case "update_zero", "update_zero_empty":
				err = k.update(tc.addr, tc.refAddr)
			}

			// then
			if tc.expectedError {
				uassert.Error(t, err)
			} else {
				uassert.NoError(t, err)
			}

			has := k.has(tc.addr)
			uassert.Equal(t, tc.expectedHas, has)
		})
	}
}

func TestValidation_ConsistencyChecks(t *testing.T) {
	tests := []struct {
		name          string
		operations    []struct {
			addr    std.Address
			refAddr std.Address
			op      string
		}
		expectedFinalStates map[string]bool
	}{
		{
			name: "multiple users same referrer",
			operations: []struct {
				addr    std.Address
				refAddr std.Address
				op      string
			}{
				{testutils.TestAddress("user1"), testutils.TestAddress("ref1"), "register"},
				{testutils.TestAddress("user2"), testutils.TestAddress("ref1"), "register"},
				{testutils.TestAddress("user3"), testutils.TestAddress("ref1"), "register"},
			},
			expectedFinalStates: map[string]bool{
				testutils.TestAddress("user1").String(): true,
				testutils.TestAddress("user2").String(): true,
				testutils.TestAddress("user3").String(): true,
			},
		},
		{
			name: "chained referrals",
			operations: []struct {
				addr    std.Address
				refAddr std.Address
				op      string
			}{
				{testutils.TestAddress("user1"), testutils.TestAddress("user2"), "register"},
				{testutils.TestAddress("user2"), testutils.TestAddress("user3"), "register"},
				{testutils.TestAddress("user3"), testutils.TestAddress("user4"), "register"},
			},
			expectedFinalStates: map[string]bool{
				testutils.TestAddress("user1").String(): true,
				testutils.TestAddress("user2").String(): true,
				testutils.TestAddress("user3").String(): true,
			},
		},
	}

	for _, tc := range tests {
		t.Run(tc.name, func(t *testing.T) {
			// given
			cleanup := setupValidationCaller()
			defer cleanup()
			k := setupValidationKeeper()

			// when
			for _, op := range tc.operations {
				switch op.op {
				case "register":
					err := k.register(op.addr, op.refAddr)
					uassert.NoError(t, err)
				case "update":
					err := k.update(op.addr, op.refAddr)
					uassert.NoError(t, err)
				}
			}

			// then
			for addrStr, expectedHas := range tc.expectedFinalStates {
				addr := std.Address(addrStr)
				has := k.has(addr)
				uassert.Equal(t, expectedHas, has)
			}
		})
	}
}

// Helper functions at the bottom of the file

func setupValidationKeeper() *keeper {
	return NewKeeper().(*keeper)
}

func setupValidationCaller() func() {
	origCaller := std.OriginCaller()
	routerAddr, _ := access.GetAddress(prabc.ROLE_ROUTER.String())
	testing.SetOriginCaller(routerAddr)
	return func() {
		testing.SetOriginCaller(origCaller)
	}
}

func setupSpecificCaller(caller string) func() {
	origCaller := std.OriginCaller()
	switch caller {
	case "router":
		routerAddr, _ := access.GetAddress(prabc.ROLE_ROUTER.String())
		testing.SetOriginCaller(routerAddr)
	case "unauthorized":
		testing.SetOriginCaller(std.Address("unauthorized"))
	}
	return func() {
		testing.SetOriginCaller(origCaller)
	}
}
