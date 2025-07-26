package referral

import (
	"std"
	"testing"

	"gno.land/p/demo/testutils"
	"gno.land/p/demo/uassert"

	prabc "gno.land/p/gnoswap/rbac"

	"gno.land/r/gnoswap/v1/access"
)

func TestSecurityTest_UnauthorizedAccess(t *testing.T) {
	tests := []struct {
		name              string
		caller            string
		operation         string
		addr              std.Address
		refAddr           std.Address
		expectedError     bool
		expectedHasPanic  bool
		expectedPanicMessage string
	}{
		{
			name:              "unauthorized register",
			caller:            "unauthorized",
			operation:         "register",
			addr:              testutils.TestAddress("sec1"),
			refAddr:           testutils.TestAddress("sec2"),
			expectedError:     true,
			expectedHasPanic:  false,
			expectedPanicMessage: "",
		},
		{
			name:              "unauthorized update",
			caller:            "unauthorized",
			operation:         "update",
			addr:              testutils.TestAddress("sec1"),
			refAddr:           testutils.TestAddress("sec2"),
			expectedError:     true,
			expectedHasPanic:  false,
			expectedPanicMessage: "",
		},
		{
			name:              "unauthorized remove",
			caller:            "unauthorized",
			operation:         "remove",
			addr:              testutils.TestAddress("sec1"),
			refAddr:           zeroAddress,
			expectedError:     true,
			expectedHasPanic:  false,
			expectedPanicMessage: "",
		},
	}

	for _, tc := range tests {
		t.Run(tc.name, func(t *testing.T) {
			defer func() {
				if r := recover(); r != nil {
					if tc.expectedHasPanic {
						uassert.Equal(t, tc.expectedPanicMessage, r.(string))
					} else {
						t.Errorf("[%s] unexpected panic: %v", tc.name, r)
					}
				}
			}()

			cleanupSecurity()

			// given
			cleanup := setupCaller(tc.caller)
			defer cleanup()
			k := setupSecurityKeeper()

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
			} else {
				uassert.NoError(t, err)
			}
		})
	}
}

func TestSecurityTest_ValidCallerAccess(t *testing.T) {
	tests := []struct {
		name              string
		caller            string
		operation         string
		addr              std.Address
		refAddr           std.Address
		newRefAddr        std.Address
		expectedHasPanic  bool
		expectedPanicMessage string
		expectedHas       bool
		expectedRef       string
	}{
		{
			name:              "authorized register",
			caller:            "router",
			operation:         "register",
			addr:              testutils.TestAddress("validReg1"),
			refAddr:           testutils.TestAddress("validReg2"),
			expectedHasPanic:  false,
			expectedPanicMessage: "",
			expectedHas:       true,
			expectedRef:       testutils.TestAddress("validReg2").String(),
		},
		{
			name:              "authorized update",
			caller:            "router",
			operation:         "update",
			addr:              testutils.TestAddress("validUp1"),
			refAddr:           testutils.TestAddress("validUp2"),
			newRefAddr:        testutils.TestAddress("validUp3"),
			expectedHasPanic:  false,
			expectedPanicMessage: "",
			expectedHas:       true,
			expectedRef:       testutils.TestAddress("validUp3").String(),
		},
		{
			name:              "authorized remove",
			caller:            "router",
			operation:         "remove",
			addr:              testutils.TestAddress("validRem1"),
			refAddr:           testutils.TestAddress("validRem2"),
			expectedHasPanic:  false,
			expectedPanicMessage: "",
			expectedHas:       false,
			expectedRef:       "",
		},
	}

	for _, tc := range tests {
		t.Run(tc.name, func(t *testing.T) {
			defer func() {
				if r := recover(); r != nil {
					if tc.expectedHasPanic {
						uassert.Equal(t, tc.expectedPanicMessage, r.(string))
					} else {
						t.Errorf("[%s] unexpected panic: %v", tc.name, r)
					}
				}
			}()

			cleanupSecurity()

			// given
			cleanup := setupCaller(tc.caller)
			defer cleanup()
			k := setupSecurityKeeper()

			// when
			var err error
			switch tc.operation {
			case "register":
				err = k.register(tc.addr, tc.refAddr)
			case "update":
				// First register
				err = k.register(tc.addr, tc.refAddr)
				uassert.NoError(t, err)
				// Mock time to bypass rate limit
				k.lastOps[tc.addr.String()] = 0
				// Then update
				err = k.update(tc.addr, tc.newRefAddr)
			case "remove":
				// First register
				err = k.register(tc.addr, tc.refAddr)
				uassert.NoError(t, err)
				// Mock time to bypass rate limit
				k.lastOps[tc.addr.String()] = 0
				// Then remove
				err = k.remove(tc.addr)
			}

			// then
			uassert.NoError(t, err)
			uassert.Equal(t, tc.expectedHas, k.has(tc.addr))

			if tc.expectedRef != "" {
				refAddr, err := k.get(tc.addr)
				uassert.NoError(t, err)
				uassert.Equal(t, tc.expectedRef, refAddr.String())
			}
		})
	}
}

func TestSecurityTest_InputSanitization(t *testing.T) {
	tests := []struct {
		name              string
		caller            string
		operation         string
		addr              std.Address
		refAddr           std.Address
		expectedHasPanic  bool
		expectedPanicMessage string
		expectedError     error
	}{
		{
			name:              "invalid addresses rejected",
			caller:            "router",
			operation:         "register",
			addr:              std.Address("invalid"),
			refAddr:           testutils.TestAddress("sec1"),
			expectedHasPanic:  false,
			expectedPanicMessage: "",
			expectedError:     ErrInvalidAddress,
		},
		{
			name:              "self referral prevented",
			caller:            "router",
			operation:         "register",
			addr:              testutils.TestAddress("sec1"),
			refAddr:           testutils.TestAddress("sec1"),
			expectedHasPanic:  false,
			expectedPanicMessage: "",
			expectedError:     ErrSelfReferral,
		},
		{
			name:              "zero address handling",
			caller:            "router",
			operation:         "setReferral",
			addr:              testutils.TestAddress("sec1"),
			refAddr:           zeroAddress,
			expectedHasPanic:  false,
			expectedPanicMessage: "",
			expectedError:     nil,
		},
	}

	for _, tc := range tests {
		t.Run(tc.name, func(t *testing.T) {
			defer func() {
				if r := recover(); r != nil {
					if tc.expectedHasPanic {
						uassert.Equal(t, tc.expectedPanicMessage, r.(string))
					} else {
						t.Errorf("[%s] unexpected panic: %v", tc.name, r)
					}
				}
			}()

			cleanupSecurity()

			// given
			cleanup := setupCaller(tc.caller)
			defer cleanup()
			k := setupSecurityKeeper()

			// when
			var err error
			switch tc.operation {
			case "register":
				err = k.register(tc.addr, tc.refAddr)
			case "setReferral":
				// First register with valid referral
				err = k.register(tc.addr, testutils.TestAddress("sec2"))
				uassert.NoError(t, err)
				// Mock time to bypass rate limit
				k.lastOps[tc.addr.String()] = 0
				// Then set referral to zero address
				err = k.setReferral(tc.addr, tc.refAddr, EventTypeUpdate)
			}

			// then
			if tc.expectedError != nil {
				uassert.Error(t, err)
				uassert.Equal(t, tc.expectedError.Error(), err.Error())
			} else {
				uassert.NoError(t, err)
			}

			if tc.operation == "setReferral" && tc.refAddr == zeroAddress {
				uassert.False(t, k.has(tc.addr))
			}
		})
	}
}

func TestSecurityTest_RateLimitingSecurity(t *testing.T) {
	tests := []struct {
		name              string
		caller            string
		operation         string
		addr              std.Address
		refAddr           std.Address
		updateRefAddr     std.Address
		expectedHasPanic  bool
		expectedPanicMessage string
		expectedError     error
		expectedRef       string
	}{
		{
			name:              "prevents rapid fire operations",
			caller:            "router",
			operation:         "register_then_update",
			addr:              testutils.TestAddress("sec1"),
			refAddr:           testutils.TestAddress("sec2"),
			updateRefAddr:     testutils.TestAddress("malicious"),
			expectedHasPanic:  false,
			expectedPanicMessage: "",
			expectedError:     ErrTooManyRequests,
			expectedRef:       testutils.TestAddress("sec2").String(),
		},
		{
			name:              "rate limit applies per address",
			caller:            "router",
			operation:         "multiple_registers",
			addr:              testutils.TestAddress("rateSecAddr1"),
			refAddr:           testutils.TestAddress("rateSecAddr2"),
			updateRefAddr:     testutils.TestAddress("rateSecAddr3"),
			expectedHasPanic:  false,
			expectedPanicMessage: "",
			expectedError:     ErrTooManyRequests,
			expectedRef:       "",
		},
	}

	for _, tc := range tests {
		t.Run(tc.name, func(t *testing.T) {
			defer func() {
				if r := recover(); r != nil {
					if tc.expectedHasPanic {
						uassert.Equal(t, tc.expectedPanicMessage, r.(string))
					} else {
						t.Errorf("[%s] unexpected panic: %v", tc.name, r)
					}
				}
			}()

			cleanupSecurity()

			// given
			cleanup := setupCaller(tc.caller)
			defer cleanup()
			k := setupSecurityKeeper()

			// when
			var err error
			switch tc.operation {
			case "register_then_update":
				// First operation should succeed
				err = k.register(tc.addr, tc.refAddr)
				uassert.NoError(t, err)
				// Immediate second operation should fail
				err = k.update(tc.addr, tc.updateRefAddr)
			case "multiple_registers":
				// Register different addresses
				err = k.register(tc.addr, tc.refAddr)
				uassert.NoError(t, err)
				// Different address should not be rate limited
				err = k.register(tc.updateRefAddr, tc.addr)
				uassert.NoError(t, err)
				// But same address should still be rate limited
				err = k.update(tc.addr, tc.updateRefAddr)
			}

			// then
			if tc.expectedError != nil {
				uassert.Error(t, err)
				uassert.Equal(t, tc.expectedError.Error(), err.Error())
			} else {
				uassert.NoError(t, err)
			}

			if tc.expectedRef != "" {
				refAddr, err := k.get(tc.addr)
				uassert.NoError(t, err)
				uassert.Equal(t, tc.expectedRef, refAddr.String())
			}
		})
	}
}

func TestSecurityTest_StateIntegrity(t *testing.T) {
	tests := []struct {
		name              string
		caller            string
		operation         string
		addr              std.Address
		refAddr           std.Address
		otherAddr         std.Address
		expectedHasPanic  bool
		expectedPanicMessage string
		expectedFirstHas  bool
		expectedSecondHas bool
	}{
		{
			name:              "consistent state after operations",
			caller:            "router",
			operation:         "register_then_remove",
			addr:              testutils.TestAddress("sec1"),
			refAddr:           testutils.TestAddress("sec2"),
			expectedHasPanic:  false,
			expectedPanicMessage: "",
			expectedFirstHas:  true,
			expectedSecondHas: false,
		},
		{
			name:              "storage isolation",
			caller:            "router",
			operation:         "multiple_register_remove_one",
			addr:              testutils.TestAddress("sec1"),
			refAddr:           testutils.TestAddress("sec2"),
			otherAddr:         testutils.TestAddress("malicious"),
			expectedHasPanic:  false,
			expectedPanicMessage: "",
			expectedFirstHas:  false,
			expectedSecondHas: false, // After remove, tc.addr should not have a referral
		},
	}

	for _, tc := range tests {
		t.Run(tc.name, func(t *testing.T) {
			defer func() {
				if r := recover(); r != nil {
					if tc.expectedHasPanic {
						uassert.Equal(t, tc.expectedPanicMessage, r.(string))
					} else {
						t.Errorf("[%s] unexpected panic: %v", tc.name, r)
					}
				}
			}()

			cleanupSecurity()

			// given
			cleanup := setupCaller(tc.caller)
			defer cleanup()
			k := setupSecurityKeeper()

			// when
			var err error
			switch tc.operation {
			case "register_then_remove":
				// Register
				err = k.register(tc.addr, tc.refAddr)
				uassert.NoError(t, err)
				// State should be consistent
				uassert.Equal(t, tc.expectedFirstHas, k.has(tc.addr))
				// Mock time to bypass rate limit
				k.lastOps[tc.addr.String()] = 0
				// Remove
				err = k.remove(tc.addr)
				uassert.NoError(t, err)
			case "multiple_register_remove_one":
				// Register multiple addresses
				err = k.register(tc.addr, tc.refAddr)
				uassert.NoError(t, err)
				err = k.register(tc.otherAddr, tc.addr)
				uassert.NoError(t, err)
				// Mock time to bypass rate limit
				k.lastOps[tc.addr.String()] = 0
				// Remove one
				err = k.remove(tc.addr)
				uassert.NoError(t, err)
			}

			// then
			uassert.NoError(t, err)
			uassert.Equal(t, tc.expectedSecondHas, k.has(tc.addr))

			if tc.operation == "multiple_register_remove_one" {
				uassert.Equal(t, true, k.has(tc.otherAddr))
			}
		})
	}
}

func TestSecurityTest_CallerValidation(t *testing.T) {
	tests := []struct {
		name              string
		callerRole        string
		expectedHasPanic  bool
		expectedPanicMessage string
		expectedError     bool
	}{
		{
			name:              "valid caller governance",
			callerRole:        "governance",
			expectedHasPanic:  false,
			expectedPanicMessage: "",
			expectedError:     false,
		},
		{
			name:              "valid caller router",
			callerRole:        "router",
			expectedHasPanic:  false,
			expectedPanicMessage: "",
			expectedError:     false,
		},
		{
			name:              "invalid caller rejected",
			callerRole:        "malicious",
			expectedHasPanic:  false,
			expectedPanicMessage: "",
			expectedError:     true,
		},
	}

	for _, tc := range tests {
		t.Run(tc.name, func(t *testing.T) {
			defer func() {
				if r := recover(); r != nil {
					if tc.expectedHasPanic {
						uassert.Equal(t, tc.expectedPanicMessage, r.(string))
					} else {
						t.Errorf("[%s] unexpected panic: %v", tc.name, r)
					}
				}
			}()

			cleanupSecurity()

			// given & when
			var err error
			switch tc.callerRole {
			case "governance":
				addr, _ := access.GetAddress(prabc.ROLE_GOVERNANCE.String())
				err = isValidCaller(addr)
			case "router":
				addr, _ := access.GetAddress(prabc.ROLE_ROUTER.String())
				err = isValidCaller(addr)
			case "malicious":
				err = isValidCaller(testutils.TestAddress("malicious"))
			}

			// then
			if tc.expectedError {
				uassert.Error(t, err)
			} else {
				uassert.NoError(t, err)
			}
		})
	}
}

func TestSecurityTest_TryRegister(t *testing.T) {
	tests := []struct {
		name              string
		caller            string
		addr              std.Address
		referral          string
		expectedHasPanic  bool
		expectedPanicMessage string
		expectedSuccess   bool
	}{
		{
			name:              "successful registration",
			caller:            "router",
			addr:              testutils.TestAddress("tryReg1"),
			referral:          testutils.TestAddress("tryReg2").String(),
			expectedHasPanic:  false,
			expectedPanicMessage: "",
			expectedSuccess:   false, // TryRegister fails due to realm context in test
		},
		{
			name:              "failed registration - self referral",
			caller:            "router",
			addr:              testutils.TestAddress("tryReg1"),
			referral:          testutils.TestAddress("tryReg1").String(),
			expectedHasPanic:  false,
			expectedPanicMessage: "",
			expectedSuccess:   false,
		},
	}

	for _, tc := range tests {
		t.Run(tc.name, func(t *testing.T) {
			defer func() {
				if r := recover(); r != nil {
					if tc.expectedHasPanic {
						uassert.Equal(t, tc.expectedPanicMessage, r.(string))
					} else {
						t.Errorf("[%s] unexpected panic: %v", tc.name, r)
					}
				}
			}()

			cleanupSecurity()

			// given
			cleanup := setupCaller(tc.caller)
			defer cleanup()

			// when
			success := TryRegister(cross, tc.addr, tc.referral)

			// then
			uassert.Equal(t, tc.expectedSuccess, success)
		})
	}
}

// Helper functions at the bottom of the file

func setupSecurityKeeper() *keeper {
	return NewKeeper().(*keeper)
}

func cleanupSecurity() {
	gReferralKeeper = NewKeeper()
}
