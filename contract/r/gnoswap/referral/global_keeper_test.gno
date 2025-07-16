package referral

import (
	"std"
	"testing"

	"gno.land/p/demo/testutils"
	"gno.land/p/demo/uassert"
	"gno.land/r/gnoswap/v1/access"
)

var (
	routerRealm = std.NewCodeRealm("gno.land/r/gnoswap/v1/router")
	userRealm   = std.NewCodeRealm("gno.land/r/demo/users")
)

func TestGlobalKeeper_TryRegister(t *testing.T) {
	tests := []struct {
		name                 string
		callerRealm          std.Realm
		addr                 std.Address
		referral             string
		expectedResult       bool
		expectedHasPanic     bool
		expectedPanicMessage string
	}{
		{
			name:           "Success register with valid addresses",
			callerRealm:    routerRealm,
			addr:           testutils.TestAddress("test1"),
			referral:       testutils.TestAddress("referrer1").String(),
			expectedResult: true,
			expectedHasPanic: false,
		},
		{
			name:           "Success register with zero referral",
			callerRealm:    routerRealm,
			addr:           testutils.TestAddress("test2"),
			referral:       zeroAddress.String(),
			expectedResult: true,
			expectedHasPanic: false,
		},
		{
			name:           "Fail register with same address as referral",
			callerRealm:    routerRealm,
			addr:           testutils.TestAddress("test3"),
			referral:       testutils.TestAddress("test3").String(),
			expectedResult: false,
			expectedHasPanic: false,
		},
		{
			name:           "Fail register existing referral",
			callerRealm:    routerRealm,
			addr:           testutils.TestAddress("test4"),
			referral:       testutils.TestAddress("referrer2").String(),
			expectedResult: false,
			expectedHasPanic: false,
		},
		{
			name:           "Fail register with unauthorized caller",
			callerRealm:    userRealm,
			addr:           testutils.TestAddress("test5"),
			referral:       testutils.TestAddress("referrer3").String(),
			expectedResult: false,
			expectedHasPanic: false,
		},
	}

	for _, tc := range tests {
		t.Run(tc.name, func(t *testing.T) {
			defer func() {
				if r := recover(); r != nil {
					if tc.expectedHasPanic {
						uassert.True(t, r != nil)
					} else {
						t.Errorf("[%s] unexpected panic: %v", tc.name, r)
					}
				}
			}()

			cleanup()

			// given
			testing.SetRealm(tc.callerRealm)
			
			// Set up pre-existing referral for failure test case
			if tc.name == "Fail register existing referral" {
				setupExistingReferral(tc.addr, testutils.TestAddress("existing"))
			}

			// when
			result := TryRegister(cross, tc.addr, tc.referral)

			// then
			if tc.expectedHasPanic {
				t.Errorf("[%s] expected panic but none occurred", tc.name)
			} else {
				uassert.Equal(t, tc.expectedResult, result)
			}
		})
	}
}

func TestGlobalKeeper_GetReferral(t *testing.T) {
	tests := []struct {
		name             string
		addr             string
		setupReferral    string
		expectedReferral string
	}{
		{
			name:             "Success get existing referral",
			addr:             testutils.TestAddress("user1").String(),
			setupReferral:    testutils.TestAddress("referrer1").String(),
			expectedReferral: testutils.TestAddress("referrer1").String(),
		},
		{
			name:             "Empty result for non-existing referral",
			addr:             testutils.TestAddress("user2").String(),
			setupReferral:    "",
			expectedReferral: "",
		},
		{
			name:             "Empty result for zero address referral",
			addr:             testutils.TestAddress("user3").String(),
			setupReferral:    "",
			expectedReferral: "",
		},
	}

	for _, tc := range tests {
		t.Run(tc.name, func(t *testing.T) {
			cleanup()

			// given
			routerAddr, _ := access.GetAddress(access.ROLE_ROUTER)
			testing.SetRealm(std.NewUserRealm(routerAddr))
			
			if tc.setupReferral != "" {
				setupExistingReferral(std.Address(tc.addr), std.Address(tc.setupReferral))
			}

			// when
			result := GetReferral(tc.addr)

			// then
			uassert.Equal(t, tc.expectedReferral, result)
		})
	}
}

func TestGlobalKeeper_HasReferral(t *testing.T) {
	tests := []struct {
		name          string
		addr          string
		setupReferral string
		expectedHas   bool
	}{
		{
			name:          "True for existing referral",
			addr:          testutils.TestAddress("user1").String(),
			setupReferral: testutils.TestAddress("referrer1").String(),
			expectedHas:   true,
		},
		{
			name:          "False for non-existing referral",
			addr:          testutils.TestAddress("user2").String(),
			setupReferral: "",
			expectedHas:   false,
		},
		{
			name:          "False for zero address referral",
			addr:          testutils.TestAddress("user3").String(),
			setupReferral: "",
			expectedHas:   false,
		},
	}

	for _, tc := range tests {
		t.Run(tc.name, func(t *testing.T) {
			cleanup()

			// given
			routerAddr, _ := access.GetAddress(access.ROLE_ROUTER)
			testing.SetRealm(std.NewUserRealm(routerAddr))
			
			if tc.setupReferral != "" {
				setupExistingReferral(std.Address(tc.addr), std.Address(tc.setupReferral))
			}

			// when
			result := HasReferral(tc.addr)

			// then
			uassert.Equal(t, tc.expectedHas, result)
		})
	}
}

func TestGlobalKeeper_IsEmpty(t *testing.T) {
	tests := []struct {
		name            string
		setupReferrals  map[string]string
		expectedIsEmpty bool
	}{
		{
			name:            "True when no referrals exist",
			setupReferrals:  map[string]string{},
			expectedIsEmpty: true,
		},
		{
			name: "False when referrals exist",
			setupReferrals: map[string]string{
				testutils.TestAddress("user1").String(): testutils.TestAddress("referrer1").String(),
			},
			expectedIsEmpty: false,
		},
		{
			name: "False when multiple referrals exist",
			setupReferrals: map[string]string{
				testutils.TestAddress("user1").String(): testutils.TestAddress("referrer1").String(),
				testutils.TestAddress("user2").String(): testutils.TestAddress("referrer2").String(),
			},
			expectedIsEmpty: false,
		},
	}

	for _, tc := range tests {
		t.Run(tc.name, func(t *testing.T) {
			cleanup()

			// given
			routerAddr, _ := access.GetAddress(access.ROLE_ROUTER)
			testing.SetRealm(std.NewUserRealm(routerAddr))
			
			for addr, referral := range tc.setupReferrals {
				setupExistingReferral(std.Address(addr), std.Address(referral))
			}

			// when
			result := IsEmpty()

			// then
			uassert.Equal(t, tc.expectedIsEmpty, result)
		})
	}
}

func TestGlobalKeeper_GetKeeper(t *testing.T) {
	tests := []struct {
		name           string
		expectedNotNil bool
	}{
		{
			name:           "Returns non-nil keeper instance",
			expectedNotNil: true,
		},
	}

	for _, tc := range tests {
		t.Run(tc.name, func(t *testing.T) {
			cleanup()

			// when
			keeper := GetKeeper()

			// then
			if tc.expectedNotNil {
				uassert.NotNil(t, keeper)
			} else {
				uassert.Nil(t, keeper)
			}
		})
	}
}

// Helper functions
func cleanup() {
	// Reset global keeper
	gReferralKeeper = NewKeeper()
}

func setupExistingReferral(addr, referralAddr std.Address) {
	TryRegister(cross, addr, referralAddr.String())
}
