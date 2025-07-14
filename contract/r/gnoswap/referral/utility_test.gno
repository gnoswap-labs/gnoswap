package referral

import (
	"std"
	"testing"

	"gno.land/p/demo/testutils"
	"gno.land/p/demo/uassert"

	"gno.land/r/gnoswap/v1/access"
)

func TestUtility_GlobalTryRegister(t *testing.T) {
	tests := []struct {
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

	for _, tc := range tests {
		t.Run(tc.name, func(t *testing.T) {
			// given
			gReferralKeeper = NewKeeper()

			if tc.shouldSetup {
				routerAddr, _ := access.GetAddress(access.ROLE_ROUTER)
				testing.SetRealm(std.NewUserRealm(routerAddr))
			}

			// when
			result := TryRegister(cross, tc.userAddr, tc.referrerAddr)

			// then
			uassert.Equal(t, tc.expectedResult, result)
		})
	}
}

func TestUtility_GlobalKeeperFunctions(t *testing.T) {
	tests := []struct {
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

	for _, tc := range tests {
		t.Run(tc.name, func(t *testing.T) {
			// given
			cleanup := setupUtilityCaller()
			defer cleanup()
			gReferralKeeper = NewKeeper()

			// when & then
			switch tc.operation {
			case "get_keeper":
				keeper := GetKeeper()
				uassert.NotNil(t, keeper)
			case "get_referral":
				// Setup referral first
				err := gReferralKeeper.register(tc.userAddr, tc.refAddr)
				uassert.NoError(t, err)
				// Get referral
				result := GetReferral(tc.userAddr.String())
				uassert.Equal(t, tc.refAddr.String(), result)
			case "has_referral":
				// Initially should not have referral
				has := HasReferral(tc.userAddr.String())
				uassert.False(t, has)
				// Setup referral
				err := gReferralKeeper.register(tc.userAddr, tc.refAddr)
				uassert.NoError(t, err)
				// Should now have referral
				has = HasReferral(tc.userAddr.String())
				uassert.True(t, has)
			case "is_empty":
				// Initially should be empty
				empty := IsEmpty()
				uassert.True(t, empty)
				// Add referral
				err := gReferralKeeper.register(tc.userAddr, tc.refAddr)
				uassert.NoError(t, err)
				// Should not be empty
				empty = IsEmpty()
				uassert.False(t, empty)
			}
		})
	}
}

func TestUtility_FunctionConsistency(t *testing.T) {
	tests := []struct {
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

	for _, tc := range tests {
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

func TestUtility_ErrorHandlingInGlobalFunctions(t *testing.T) {
	tests := []struct {
		name           string
		userAddr       std.Address
		referrerAddr   std.Address
		setupReferral  bool
		operation      string
		expectedResult interface{}
	}{
		{
			name:           "GetReferral returns empty for non-existent",
			userAddr:       testutils.TestAddress("error1"),
			referrerAddr:   testutils.TestAddress("error2"),
			setupReferral:  false,
			operation:      "get_referral_empty",
			expectedResult: "",
		},
		{
			name:           "HasReferral returns false for non-existent",
			userAddr:       testutils.TestAddress("error3"),
			referrerAddr:   testutils.TestAddress("error4"),
			setupReferral:  false,
			operation:      "has_referral_false",
			expectedResult: false,
		},
		{
			name:           "GetReferral returns correct for existing",
			userAddr:       testutils.TestAddress("error5"),
			referrerAddr:   testutils.TestAddress("error6"),
			setupReferral:  true,
			operation:      "get_referral_existing",
			expectedResult: testutils.TestAddress("error6").String(),
		},
		{
			name:           "HasReferral returns true for existing",
			userAddr:       testutils.TestAddress("error7"),
			referrerAddr:   testutils.TestAddress("error8"),
			setupReferral:  true,
			operation:      "has_referral_true",
			expectedResult: true,
		},
	}

	for _, tc := range tests {
		t.Run(tc.name, func(t *testing.T) {
			// given
			cleanup := setupUtilityCaller()
			defer cleanup()
			gReferralKeeper = NewKeeper()

			if tc.setupReferral {
				err := gReferralKeeper.register(tc.userAddr, tc.referrerAddr)
				uassert.NoError(t, err)
			}

			// when & then
			switch tc.operation {
			case "get_referral_empty":
				result := GetReferral(tc.userAddr.String())
				uassert.Equal(t, tc.expectedResult, result)
			case "has_referral_false":
				result := HasReferral(tc.userAddr.String())
				uassert.Equal(t, tc.expectedResult, result)
			case "get_referral_existing":
				result := GetReferral(tc.userAddr.String())
				uassert.Equal(t, tc.expectedResult, result)
			case "has_referral_true":
				result := HasReferral(tc.userAddr.String())
				uassert.Equal(t, tc.expectedResult, result)
			}
		})
	}
}

func TestUtility_StateManipulation(t *testing.T) {
	tests := []struct {
		name      string
		userAddr  std.Address
		refAddr1  std.Address
		refAddr2  std.Address
		operation string
	}{
		{
			name:      "multiple operations on same address",
			userAddr:  testutils.TestAddress("state1"),
			refAddr1:  testutils.TestAddress("state2"),
			refAddr2:  testutils.TestAddress("state3"),
			operation: "multiple_ops_same_addr",
		},
		{
			name:      "multiple addresses same referrer",
			userAddr:  testutils.TestAddress("state4"),
			refAddr1:  testutils.TestAddress("state5"),
			refAddr2:  testutils.TestAddress("state6"),
			operation: "multiple_addr_same_ref",
		},
		{
			name:      "cross referencing",
			userAddr:  testutils.TestAddress("state7"),
			refAddr1:  testutils.TestAddress("state8"),
			refAddr2:  testutils.TestAddress("state9"),
			operation: "cross_referencing",
		},
	}

	for _, tc := range tests {
		t.Run(tc.name, func(t *testing.T) {
			// given
			cleanup := setupUtilityCaller()
			defer cleanup()
			gReferralKeeper = NewKeeper()

			// when & then
			switch tc.operation {
			case "multiple_ops_same_addr":
				// Register
				err := gReferralKeeper.register(tc.userAddr, tc.refAddr1)
				uassert.NoError(t, err)
				uassert.True(t, HasReferral(tc.userAddr.String()))
				uassert.Equal(t, tc.refAddr1.String(), GetReferral(tc.userAddr.String()))

				// Remove
				err = gReferralKeeper.remove(tc.userAddr)
				uassert.NoError(t, err)
				uassert.False(t, HasReferral(tc.userAddr.String()))

			case "multiple_addr_same_ref":
				// Register first address
				err := gReferralKeeper.register(tc.userAddr, tc.refAddr1)
				uassert.NoError(t, err)
				// Register second address with same referrer
				err = gReferralKeeper.register(tc.refAddr2, tc.refAddr1)
				uassert.NoError(t, err)

				uassert.True(t, HasReferral(tc.userAddr.String()))
				uassert.True(t, HasReferral(tc.refAddr2.String()))
				uassert.Equal(t, tc.refAddr1.String(), GetReferral(tc.userAddr.String()))
				uassert.Equal(t, tc.refAddr1.String(), GetReferral(tc.refAddr2.String()))

			case "cross_referencing":
				// A refers B, B refers C
				err := gReferralKeeper.register(tc.userAddr, tc.refAddr1)
				uassert.NoError(t, err)
				err = gReferralKeeper.register(tc.refAddr1, tc.refAddr2)
				uassert.NoError(t, err)

				uassert.True(t, HasReferral(tc.userAddr.String()))
				uassert.True(t, HasReferral(tc.refAddr1.String()))
				uassert.Equal(t, tc.refAddr1.String(), GetReferral(tc.userAddr.String()))
				uassert.Equal(t, tc.refAddr2.String(), GetReferral(tc.refAddr1.String()))
			}
		})
	}
}

func TestUtility_GlobalStateConsistency(t *testing.T) {
	tests := []struct {
		name         string
		numUsers     int
		operation    string
		expectedBase bool
	}{
		{
			name:         "empty state consistency",
			numUsers:     0,
			operation:    "empty_check",
			expectedBase: true,
		},
		{
			name:         "populated state consistency",
			numUsers:     5,
			operation:    "populated_check",
			expectedBase: false,
		},
		{
			name:         "partial removal consistency",
			numUsers:     3,
			operation:    "partial_removal",
			expectedBase: false,
		},
	}

	for _, tc := range tests {
		t.Run(tc.name, func(t *testing.T) {
			// given
			cleanup := setupUtilityCaller()
			defer cleanup()
			gReferralKeeper = NewKeeper()

			// when & then
			switch tc.operation {
			case "empty_check":
				uassert.Equal(t, tc.expectedBase, IsEmpty())
			case "populated_check":
				// Add users
				for i := 0; i < tc.numUsers; i++ {
					userAddr := testutils.TestAddress("user" + string(rune(i+'0')))
					refAddr := testutils.TestAddress("ref" + string(rune(i+'0')))
					err := gReferralKeeper.register(userAddr, refAddr)
					uassert.NoError(t, err)
				}
				uassert.Equal(t, tc.expectedBase, IsEmpty())
			case "partial_removal":
				// Add users
				var users []std.Address
				for i := 0; i < tc.numUsers; i++ {
					userAddr := testutils.TestAddress("user" + string(rune(i+'0')))
					refAddr := testutils.TestAddress("ref" + string(rune(i+'0')))
					users = append(users, userAddr)
					err := gReferralKeeper.register(userAddr, refAddr)
					uassert.NoError(t, err)
				}
				// Remove some users
				for i := 0; i < tc.numUsers/2; i++ {
					err := gReferralKeeper.remove(users[i])
					uassert.NoError(t, err)
				}
				uassert.Equal(t, tc.expectedBase, IsEmpty())
			}
		})
	}
}

// Helper functions at the bottom of the file

func setupUtilityKeeper() *keeper {
	return NewKeeper().(*keeper)
}

func setupUtilityCaller() func() {
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
