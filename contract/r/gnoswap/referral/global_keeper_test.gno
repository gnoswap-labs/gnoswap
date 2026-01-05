package referral

import (
	"chain/runtime"
	"testing"

	"gno.land/p/nt/testutils"
	"gno.land/p/nt/uassert"

	prbac "gno.land/p/gnoswap/rbac"
	"gno.land/r/gnoswap/access"
)

var (
	routerAddr  = access.MustGetAddress(prbac.ROLE_ROUTER.String())
	routerRealm = testing.NewCodeRealm("gno.land/r/gnoswap/router")
	userRealm   = testing.NewCodeRealm("gno.land/r/demo/users")
)

func TestGlobalKeeper_TryRegister(t *testing.T) {
	tests := []struct {
		name                 string
		callerRealm          runtime.Realm
		addr                 address
		referral             string
		expectedResult       bool
		expectedPanics       bool
		expectedPanicMessage string
	}{
		{
			name:                 "Success register with valid addresses",
			callerRealm:          routerRealm,
			addr:                 testutils.TestAddress("test1"),
			referral:             testutils.TestAddress("referrer1").String(),
			expectedResult:       true,
			expectedPanics:       false,
			expectedPanicMessage: "",
		},
		{
			name:                 "Success register with zero referral",
			callerRealm:          routerRealm,
			addr:                 testutils.TestAddress("test2"),
			referral:             zeroAddress.String(),
			expectedResult:       true,
			expectedPanics:       false,
			expectedPanicMessage: "",
		},
		{
			name:                 "Fail register with same address as referral",
			callerRealm:          routerRealm,
			addr:                 testutils.TestAddress("test3"),
			referral:             testutils.TestAddress("test3").String(),
			expectedResult:       false,
			expectedPanics:       false,
			expectedPanicMessage: "",
		},
		{
			name:                 "Fail register existing referral",
			callerRealm:          routerRealm,
			addr:                 testutils.TestAddress("test4"),
			referral:             testutils.TestAddress("referrer2").String(),
			expectedResult:       false,
			expectedPanics:       false,
			expectedPanicMessage: "",
		},
		{
			name:                 "Fail register with unauthorized caller",
			callerRealm:          userRealm,
			addr:                 testutils.TestAddress("test5"),
			referral:             testutils.TestAddress("referrer3").String(),
			expectedResult:       false,
			expectedPanics:       false,
			expectedPanicMessage: "",
		},
		{
			name:           "Fail register with invalid referral - invalid format",
			callerRealm:    routerRealm,
			addr:           testutils.TestAddress("test6"),
			referral:       "invalid_ref",
			expectedResult: false,
			expectedPanics: false,
		},
		{
			name:           "Fail register with invalid user address",
			callerRealm:    routerRealm,
			addr:           zeroAddress,
			referral:       testutils.TestAddress("referrer4").String(),
			expectedResult: false,
			expectedPanics: false,
		},
	}

	for _, tc := range tests {
		t.Run(tc.name, func(t *testing.T) {
			cleanup(t)

			// given
			testing.SetRealm(tc.callerRealm)

			// Set up pre-existing referral for failure test case
			if tc.name == "Fail register existing referral" {
				setupExistingReferral(t, tc.addr, testutils.TestAddress("existing"))
			}

			if tc.expectedPanics {
				uassert.PanicsContains(t, tc.expectedPanicMessage, func() {
					TryRegister(cross, tc.addr, tc.referral)
				})
			} else {
				result := TryRegister(cross, tc.addr, tc.referral)
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
		{
			name:             "Empty result for invalid address - empty string",
			addr:             "",
			setupReferral:    "",
			expectedReferral: "",
		},
		{
			name:             "Empty result for invalid address - invalid format",
			addr:             "invalid",
			setupReferral:    "",
			expectedReferral: "",
		},
	}

	for _, tc := range tests {
		t.Run(tc.name, func(t *testing.T) {
			cleanup(t)

			// given
			testing.SetRealm(testing.NewUserRealm(routerAddr))

			if tc.setupReferral != "" {
				setupExistingReferral(t, address(tc.addr), address(tc.setupReferral))
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
		{
			name:          "False for invalid address - empty string",
			addr:          "",
			setupReferral: "",
			expectedHas:   false,
		},
		{
			name:          "False for invalid address - invalid format",
			addr:          "invalid",
			setupReferral: "",
			expectedHas:   false,
		},
	}

	for _, tc := range tests {
		t.Run(tc.name, func(t *testing.T) {
			cleanup(t)

			// given
			testing.SetRealm(testing.NewUserRealm(routerAddr))

			if tc.setupReferral != "" {
				setupExistingReferral(t, address(tc.addr), address(tc.setupReferral))
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
			cleanup(t)

			// given
			testing.SetRealm(testing.NewUserRealm(routerAddr))

			for addr, referral := range tc.setupReferrals {
				setupExistingReferral(t, address(addr), address(referral))
			}

			// when
			result := IsEmpty()

			// then
			uassert.Equal(t, tc.expectedIsEmpty, result)
		})
	}
}

func TestGlobalKeeper_getKeeper(t *testing.T) {
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
			cleanup(t)

			// when
			keeper := gReferralKeeper

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
func cleanup(t *testing.T) {
	t.Helper()
	// Reset global keeper
	gReferralKeeper = NewKeeper()
}

func setupExistingReferral(t *testing.T, addr, referralAddr address) {
	t.Helper()
	TryRegister(cross, addr, referralAddr.String())
}
