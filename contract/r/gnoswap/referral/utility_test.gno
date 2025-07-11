package referral

import (
	"std"
	"testing"

	"gno.land/p/demo/testutils"
	"gno.land/p/demo/uassert"

	"gno.land/r/gnoswap/v1/access"
)

var (
	// Test addresses for utility tests
	utilityAddr1 = testutils.TestAddress("utility1")
	utilityAddr2 = testutils.TestAddress("utility2")
	utilityAddr3 = testutils.TestAddress("utility3")
	utilityAddr4 = testutils.TestAddress("utility4")
)

func setupUtilityKeeper() *keeper {
	return NewKeeper().(*keeper)
}

func mockValidCallerUtility() func() {
	origCaller := std.OriginCaller()
	routerAddr, _ := access.GetAddress(access.ROLE_ROUTER)
	routerRealm := std.NewUserRealm(routerAddr)
	testing.SetOriginCaller(routerAddr)
	testing.SetRealm(routerRealm)
	return func() {
		testing.SetOriginCaller(origCaller)
		testing.SetRealm(std.NewUserRealm(origCaller))
	}
}

// TestGlobalTryRegister tests the global TryRegister function
func TestGlobalTryRegister(t *testing.T) {
	tt := []struct {
		name           string
		userAddr       std.Address
		referrerAddr   string
		expectedResult bool
		shouldSetup    bool
	}{
		{
			name:           "successful registration",
			userAddr:       testutils.TestAddress("globalTryUnique1"),
			referrerAddr:   testutils.TestAddress("globalTryUnique2").String(),
			expectedResult: true,
			shouldSetup:    true,
		},
		{
			name:           "handles self referral",
			userAddr:       testutils.TestAddress("globalTryUnique3"),
			referrerAddr:   testutils.TestAddress("globalTryUnique3").String(),
			expectedResult: false,
			shouldSetup:    true,
		},
		{
			name:           "handles invalid address",
			userAddr:       testutils.TestAddress("globalTryUnique4"),
			referrerAddr:   "g1invalid",
			expectedResult: false,
			shouldSetup:    true,
		},
		{
			name:           "handles zero address referrer",
			userAddr:       testutils.TestAddress("globalTryUnique5"),
			referrerAddr:   zeroAddress.String(),
			expectedResult: true,
			shouldSetup:    true,
		},
		{
			name:           "handles unauthorized caller",
			userAddr:       testutils.TestAddress("globalTryUnique6"),
			referrerAddr:   testutils.TestAddress("globalTryUnique7").String(),
			expectedResult: false,
			shouldSetup:    false,
		},
	}

	for _, tc := range tt {
		t.Run(tc.name, func(t *testing.T) {
			// given
			gReferralKeeper = NewKeeper()

			var cleanup func()
			if tc.shouldSetup {
				cleanup = mockValidCallerUtility()
				defer cleanup()
				// Set the origin caller again like in the working test
				routerAddr, _ := access.GetAddress(access.ROLE_ROUTER)
				testing.SetOriginCaller(routerAddr)
			}

			// when
			result := TryRegister(cross, tc.userAddr, tc.referrerAddr)

			// then
			uassert.Equal(t, tc.expectedResult, result)
		})
	}
}

// TestGlobalKeeperFunctions tests the global keeper accessor functions
func TestGlobalKeeperFunctions(t *testing.T) {
	tt := []struct {
		name      string
		userAddr  std.Address
		refAddr   std.Address
		operation string
	}{
		{
			name:      "GetKeeper returns valid keeper",
			userAddr:  testutils.TestAddress("keeper1"),
			refAddr:   testutils.TestAddress("keeper2"),
			operation: "get_keeper",
		},
		{
			name:      "GetReferral returns correct referral",
			userAddr:  testutils.TestAddress("keeper3"),
			refAddr:   testutils.TestAddress("keeper4"),
			operation: "get_referral",
		},
		{
			name:      "HasReferral returns correct status",
			userAddr:  testutils.TestAddress("keeper5"),
			refAddr:   testutils.TestAddress("keeper6"),
			operation: "has_referral",
		},
		{
			name:      "IsEmpty returns correct state",
			userAddr:  testutils.TestAddress("keeper7"),
			refAddr:   testutils.TestAddress("keeper8"),
			operation: "is_empty",
		},
	}

	cleanup := mockValidCallerUtility()
	defer cleanup()

	for _, tc := range tt {
		t.Run(tc.name, func(t *testing.T) {
			// given
			gReferralKeeper = NewKeeper()

			// when & then
			switch tc.operation {
			case "get_keeper":
				keeper := GetKeeper()
				uassert.True(t, keeper != nil)
			case "get_referral":
				// Setup: Register a referral
				keeper := GetKeeper()
				err := keeper.register(tc.userAddr, tc.refAddr)
				uassert.NoError(t, err)

				// Test: Get referral should return the correct address
				refStr := GetReferral(tc.userAddr.String())
				uassert.Equal(t, tc.refAddr.String(), refStr)

				// Test: Non-existent referral should return empty string
				refStr = GetReferral(testutils.TestAddress("nonexistent").String())
				uassert.Equal(t, "", refStr)
			case "has_referral":
				// Setup: Register a referral
				keeper := GetKeeper()
				err := keeper.register(tc.userAddr, tc.refAddr)
				uassert.NoError(t, err)

				// Test: Should be true for existing referral
				has := HasReferral(tc.userAddr.String())
				uassert.True(t, has)

				// Test: Should be false for non-existent referral
				has = HasReferral(testutils.TestAddress("nonexistent").String())
				uassert.False(t, has)
			case "is_empty":
				// Test: Should be true for empty keeper
				isEmpty := IsEmpty()
				uassert.True(t, isEmpty)

				// Setup: Register a referral
				keeper := GetKeeper()
				err := keeper.register(tc.userAddr, tc.refAddr)
				uassert.NoError(t, err)

				// Test: Should be false after registering referrals
				isEmpty = IsEmpty()
				uassert.False(t, isEmpty)
			}
		})
	}
}

// TestUtilityFunctions tests utility and helper functions
func TestUtilityFunctions(t *testing.T) {
	tt := []struct {
		name      string
		testAddr1 std.Address
		testAddr2 std.Address
		operation string
	}{
		{
			name:      "address string conversion consistency",
			testAddr1: testutils.TestAddress("util1"),
			testAddr2: testutils.TestAddress("util2"),
			operation: "address_conversion",
		},
		{
			name:      "zero address handling",
			testAddr1: zeroAddress,
			testAddr2: testutils.TestAddress("util3"),
			operation: "zero_address",
		},
		{
			name:      "address comparison",
			testAddr1: testutils.TestAddress("util4"),
			testAddr2: testutils.TestAddress("util5"),
			operation: "address_comparison",
		},
	}

	for _, tc := range tt {
		t.Run(tc.name, func(t *testing.T) {
			// when & then
			switch tc.operation {
			case "address_conversion":
				addrStr := tc.testAddr1.String()
				uassert.True(t, len(addrStr) > 0)
				uassert.True(t, addrStr != "")
			case "zero_address":
				zeroStr := tc.testAddr1.String()
				uassert.True(t, len(zeroStr) >= 0)
				// Zero address should be different from regular addresses (unless empty)
				if zeroStr != "" {
					uassert.True(t, zeroStr != tc.testAddr2.String())
				}
			case "address_comparison":
				// Same address should have same string representation
				addr1Str1 := tc.testAddr1.String()
				addr1Str2 := tc.testAddr1.String()
				uassert.Equal(t, addr1Str1, addr1Str2)

				// Different addresses should have different string representations
				addr1Str := tc.testAddr1.String()
				addr2Str := tc.testAddr2.String()
				uassert.True(t, addr1Str != addr2Str)
			}
		})
	}
}

// TestErrorHandlingInGlobalFunctions tests error handling in global functions
func TestErrorHandlingInGlobalFunctions(t *testing.T) {
	tt := []struct {
		name           string
		userAddr       std.Address
		referrerAddr   std.Address
		operation      string
		expectedResult bool
	}{
		{
			name:           "TryRegister handles unauthorized caller",
			userAddr:       testutils.TestAddress("errorUnique1"),
			referrerAddr:   testutils.TestAddress("errorUnique2"),
			operation:      "unauthorized_try_register",
			expectedResult: false,
		},
		{
			name:           "TryRegister handles authorized caller",
			userAddr:       testutils.TestAddress("errorUnique3"),
			referrerAddr:   testutils.TestAddress("errorUnique4"),
			operation:      "authorized_try_register",
			expectedResult: true,
		},
		{
			name:           "global functions handle missing data",
			userAddr:       testutils.TestAddress("errorUnique5"),
			referrerAddr:   testutils.TestAddress("errorUnique6"),
			operation:      "missing_data",
			expectedResult: false,
		},
	}

	for _, tc := range tt {
		t.Run(tc.name, func(t *testing.T) {
			// given
			gReferralKeeper = NewKeeper()

			// when & then
			switch tc.operation {
			case "unauthorized_try_register":
				// Without proper authorization should return false
				result := TryRegister(cross, tc.userAddr, tc.referrerAddr.String())
				uassert.Equal(t, tc.expectedResult, result)
			case "authorized_try_register":
				cleanup := mockValidCallerUtility()
				defer cleanup()
				// Set the origin caller again like in the working test
				routerAddr, _ := access.GetAddress(access.ROLE_ROUTER)
				testing.SetOriginCaller(routerAddr)
				result := TryRegister(cross, tc.userAddr, tc.referrerAddr.String())
				uassert.Equal(t, tc.expectedResult, result)
			case "missing_data":
				// Functions should work even when no referrals exist for specific addresses
				refStr := GetReferral("nonexistent")
				uassert.Equal(t, "", refStr)

				has := HasReferral("nonexistent")
				uassert.Equal(t, tc.expectedResult, has)
			}
		})
	}
}

// TestIntegrationWithKeeper tests integration between global functions and keeper
func TestIntegrationWithKeeper(t *testing.T) {
	tt := []struct {
		name       string
		userAddr   std.Address
		refAddr    std.Address
		operation  string
		shouldAuth bool
	}{
		{
			name:       "global functions reflect keeper state",
			userAddr:   testutils.TestAddress("integUnique1"),
			refAddr:    testutils.TestAddress("integUnique2"),
			operation:  "reflect_keeper_state",
			shouldAuth: true,
		},
		{
			name:       "TryRegister reflects authorization state",
			userAddr:   testutils.TestAddress("integUnique3"),
			refAddr:    testutils.TestAddress("integUnique4"),
			operation:  "authorization_state",
			shouldAuth: true,
		},
		{
			name:       "functions maintain consistency",
			userAddr:   testutils.TestAddress("integUnique5"),
			refAddr:    testutils.TestAddress("integUnique6"),
			operation:  "maintain_consistency",
			shouldAuth: true,
		},
	}

	for _, tc := range tt {
		t.Run(tc.name, func(t *testing.T) {
			// given
			gReferralKeeper = NewKeeper()

			var cleanup func()
			if tc.shouldAuth {
				cleanup = mockValidCallerUtility()
				defer cleanup()
			}

			// when & then
			switch tc.operation {
			case "reflect_keeper_state":
				// Create relationship through global keeper
				k := GetKeeper()
				err := k.register(tc.userAddr, tc.refAddr)
				uassert.NoError(t, err)

				// Global function should reflect new state
				has := HasReferral(tc.userAddr.String())
				uassert.True(t, has)

				refStr := GetReferral(tc.userAddr.String())
				uassert.Equal(t, tc.refAddr.String(), refStr)
			case "authorization_state":
				// With authorization, registration should work
				routerAddr, _ := access.GetAddress(access.ROLE_ROUTER)
				testing.SetOriginCaller(routerAddr)
				result := TryRegister(cross, tc.userAddr, tc.refAddr.String())
				uassert.True(t, result)
			case "maintain_consistency":
				// Create referral using global keeper
				k := GetKeeper()
				err := k.register(tc.userAddr, tc.refAddr)
				uassert.NoError(t, err)

				// Global functions should be consistent with keeper state
				uassert.True(t, k.has(tc.userAddr))

				has := HasReferral(tc.userAddr.String())
				uassert.True(t, has)

				refStr := GetReferral(tc.userAddr.String())
				uassert.Equal(t, tc.refAddr.String(), refStr)
			}
		})
	}
}
