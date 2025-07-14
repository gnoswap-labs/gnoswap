package referral

import (
	"std"
	"testing"

	"gno.land/p/demo/testutils"
	"gno.land/p/demo/uassert"

	"gno.land/r/gnoswap/v1/access"
)

func TestReferral_NewReferral(t *testing.T) {
	tests := []struct {
		name                 string
		expectedNotNil       bool
		expectedKeeperNotNil bool
	}{
		{
			name:                 "creates valid referral instance",
			expectedNotNil:       true,
			expectedKeeperNotNil: true,
		},
		{
			name:                 "creates new keeper instance",
			expectedNotNil:       true,
			expectedKeeperNotNil: true,
		},
	}

	for _, tc := range tests {
		t.Run(tc.name, func(t *testing.T) {
			// given
			// No setup needed for constructor test

			// when
			r := NewReferral()

			// then
			if tc.expectedNotNil {
				uassert.NotNil(t, r)
			}
			if tc.expectedKeeperNotNil {
				uassert.NotNil(t, r.keeper)
			}
		})
	}
}

func TestReferral_Register(t *testing.T) {
	tests := []struct {
		name          string
		caller        string
		addr          std.Address
		refAddr       std.Address
		expectedError bool
		expectedHas   bool
		expectedRef   string
	}{
		{
			name:          "successful registration with valid caller",
			caller:        "router",
			addr:          testutils.TestAddress("unit1"),
			refAddr:       testutils.TestAddress("unit2"),
			expectedError: false,
			expectedHas:   true,
			expectedRef:   testutils.TestAddress("unit2").String(),
		},
		{
			name:          "fails with unauthorized caller",
			caller:        "unauthorized",
			addr:          testutils.TestAddress("unit1"),
			refAddr:       testutils.TestAddress("unit2"),
			expectedError: true,
			expectedHas:   false,
			expectedRef:   "",
		},
		{
			name:          "prevents self referral",
			caller:        "router",
			addr:          testutils.TestAddress("unit1"),
			refAddr:       testutils.TestAddress("unit1"),
			expectedError: true,
			expectedHas:   false,
			expectedRef:   "",
		},
		{
			name:          "allows zero address referral",
			caller:        "router",
			addr:          testutils.TestAddress("unit1"),
			refAddr:       zeroAddress,
			expectedError: false,
			expectedHas:   false,
			expectedRef:   "",
		},
	}

	for _, tc := range tests {
		t.Run(tc.name, func(t *testing.T) {
			// given
			cleanup := setupCaller(tc.caller)
			defer cleanup()
			k := setupUnitKeeper()

			// when
			err := k.register(tc.addr, tc.refAddr)

			// then
			if tc.expectedError {
				uassert.Error(t, err)
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

func TestReferral_Update(t *testing.T) {
	tests := []struct {
		name            string
		caller          string
		initialRegister bool
		addr            std.Address
		initialRefAddr  std.Address
		updateRefAddr   std.Address
		expectedError   bool
		expectedRef     string
	}{
		{
			name:            "successful update with valid caller rate limited",
			caller:          "router",
			initialRegister: true,
			addr:            testutils.TestAddress("unit1"),
			initialRefAddr:  testutils.TestAddress("unit2"),
			updateRefAddr:   testutils.TestAddress("unit3"),
			expectedError:   true, // Should fail due to rate limiting
			expectedRef:     testutils.TestAddress("unit2").String(),
		},
		{
			name:            "fails with unauthorized caller",
			caller:          "unauthorized",
			initialRegister: false,
			addr:            testutils.TestAddress("unit1"),
			initialRefAddr:  zeroAddress,
			updateRefAddr:   testutils.TestAddress("unit2"),
			expectedError:   true,
			expectedRef:     "",
		},
		{
			name:            "prevents self referral update",
			caller:          "router",
			initialRegister: false,
			addr:            testutils.TestAddress("unit1"),
			initialRefAddr:  zeroAddress,
			updateRefAddr:   testutils.TestAddress("unit1"),
			expectedError:   true,
			expectedRef:     "",
		},
		{
			name:            "updates non-existent referral",
			caller:          "router",
			initialRegister: false,
			addr:            testutils.TestAddress("unit1"),
			initialRefAddr:  zeroAddress,
			updateRefAddr:   testutils.TestAddress("unit2"),
			expectedError:   false,
			expectedRef:     testutils.TestAddress("unit2").String(),
		},
	}

	for _, tc := range tests {
		t.Run(tc.name, func(t *testing.T) {
			// given
			cleanup := setupCaller(tc.caller)
			defer cleanup()
			k := setupUnitKeeper()

			if tc.initialRegister {
				err := k.register(tc.addr, tc.initialRefAddr)
				uassert.NoError(t, err)
			}

			// when
			err := k.update(tc.addr, tc.updateRefAddr)

			// then
			if tc.expectedError {
				uassert.Error(t, err)
			} else {
				uassert.NoError(t, err)
			}

			if tc.expectedRef != "" {
				ref, err := k.get(tc.addr)
				uassert.NoError(t, err)
				uassert.Equal(t, tc.expectedRef, ref.String())
			}
		})
	}
}

func TestReferral_Get(t *testing.T) {
	tests := []struct {
		name             string
		caller           string
		setupReferral    bool
		addr             std.Address
		refAddr          std.Address
		expectedError    bool
		expectedRef      string
		multipleCallTest bool
	}{
		{
			name:             "gets existing referral",
			caller:           "router",
			setupReferral:    true,
			addr:             testutils.TestAddress("unit1"),
			refAddr:          testutils.TestAddress("unit2"),
			expectedError:    false,
			expectedRef:      testutils.TestAddress("unit2").String(),
			multipleCallTest: false,
		},
		{
			name:             "fails for non-existent referral",
			caller:           "",
			setupReferral:    false,
			addr:             testutils.TestAddress("unit1"),
			refAddr:          zeroAddress,
			expectedError:    true,
			expectedRef:      "",
			multipleCallTest: false,
		},
		{
			name:             "consistent results across multiple calls",
			caller:           "router",
			setupReferral:    true,
			addr:             testutils.TestAddress("unit1"),
			refAddr:          testutils.TestAddress("unit2"),
			expectedError:    false,
			expectedRef:      testutils.TestAddress("unit2").String(),
			multipleCallTest: true,
		},
	}

	for _, tc := range tests {
		t.Run(tc.name, func(t *testing.T) {
			// given
			var cleanup func()
			if tc.caller != "" {
				cleanup = setupCaller(tc.caller)
				defer cleanup()
			}

			k := setupUnitKeeper()

			if tc.setupReferral {
				err := k.register(tc.addr, tc.refAddr)
				uassert.NoError(t, err)
			}

			// when & then
			if tc.multipleCallTest {
				// Multiple gets should return same result
				for i := 0; i < 3; i++ {
					ref, err := k.get(tc.addr)
					if tc.expectedError {
						uassert.Error(t, err)
					} else {
						uassert.NoError(t, err)
						uassert.Equal(t, tc.expectedRef, ref.String())
					}
				}
			} else {
				ref, err := k.get(tc.addr)
				if tc.expectedError {
					uassert.Error(t, err)
				} else {
					uassert.NoError(t, err)
					uassert.Equal(t, tc.expectedRef, ref.String())
				}
			}
		})
	}
}

func TestReferral_Has(t *testing.T) {
	tests := []struct {
		name          string
		caller        string
		setupReferral bool
		addr          std.Address
		refAddr       std.Address
		expectedHas   bool
	}{
		{
			name:          "returns true for existing referral",
			caller:        "router",
			setupReferral: true,
			addr:          testutils.TestAddress("unit1"),
			refAddr:       testutils.TestAddress("unit2"),
			expectedHas:   true,
		},
		{
			name:          "returns false for non-existent referral",
			caller:        "",
			setupReferral: false,
			addr:          testutils.TestAddress("unit1"),
			refAddr:       zeroAddress,
			expectedHas:   false,
		},
		{
			name:          "returns false for zero address referral",
			caller:        "router",
			setupReferral: true,
			addr:          testutils.TestAddress("unit1"),
			refAddr:       zeroAddress,
			expectedHas:   false,
		},
	}

	for _, tc := range tests {
		t.Run(tc.name, func(t *testing.T) {
			// given
			var cleanup func()
			if tc.caller != "" {
				cleanup = setupCaller(tc.caller)
				defer cleanup()
			}

			k := setupUnitKeeper()

			if tc.setupReferral {
				err := k.register(tc.addr, tc.refAddr)
				uassert.NoError(t, err)
			}

			// when
			has := k.has(tc.addr)

			// then
			uassert.Equal(t, tc.expectedHas, has)
		})
	}
}

func TestReferral_Remove(t *testing.T) {
	tests := []struct {
		name          string
		caller        string
		setupReferral bool
		addr          std.Address
		refAddr       std.Address
		expectedError bool
		expectedHas   bool
	}{
		{
			name:          "removes existing referral successfully",
			caller:        "router",
			setupReferral: true,
			addr:          testutils.TestAddress("unit1"),
			refAddr:       testutils.TestAddress("unit2"),
			expectedError: false,
			expectedHas:   false,
		},
		{
			name:          "fails with unauthorized caller",
			caller:        "unauthorized",
			setupReferral: true,
			addr:          testutils.TestAddress("unit1"),
			refAddr:       testutils.TestAddress("unit2"),
			expectedError: true,
			expectedHas:   true,
		},
		{
			name:          "removing non-existent referral is no-op",
			caller:        "router",
			setupReferral: false,
			addr:          testutils.TestAddress("unit1"),
			refAddr:       zeroAddress,
			expectedError: false,
			expectedHas:   false,
		},
	}

	for _, tc := range tests {
		t.Run(tc.name, func(t *testing.T) {
			// given
			k := setupUnitKeeper()

			if tc.setupReferral {
				// Set up referral with valid caller first
				validCleanup := setupCaller("router")
				err := k.register(tc.addr, tc.refAddr)
				uassert.NoError(t, err)
				validCleanup()
			}

			// Now set up the caller for the actual test
			cleanup := setupCaller(tc.caller)
			defer cleanup()

			// when
			err := k.remove(tc.addr)

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

// Helper functions at the bottom of the file

func setupUnitKeeper() *keeper {
	return NewKeeper().(*keeper)
}

func setupCaller(caller string) func() {
	origCaller := std.OriginCaller()
	switch caller {
	case "router":
		routerAddr, _ := access.GetAddress(access.ROLE_ROUTER)
		testing.SetOriginCaller(routerAddr)
	case "unauthorized":
		testing.SetOriginCaller(std.Address("unauthorized"))
	}
	return func() {
		testing.SetOriginCaller(origCaller)
	}
}

func cleanupGlobal() func() {
	origKeeper := gReferralKeeper
	gReferralKeeper = NewKeeper()
	return func() {
		gReferralKeeper = origKeeper
	}
}
