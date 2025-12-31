package referral

import (
	"chain/runtime"
	"testing"

	"gno.land/p/nt/testutils"
	"gno.land/p/nt/uassert"
)

func TestKeeper_Register(t *testing.T) {
	var (
		routerRealm = testing.NewCodeRealm("gno.land/r/gnoswap/router")
		userRealm   = testing.NewCodeRealm("gno.land/r/demo/users")
	)

	tests := []struct {
		name                 string
		callerRealm          runtime.Realm
		addr                 address
		refAddr              address
		expectedSuccess      bool
		expectedPanicMessage string
	}{
		{
			name:            "Success register with valid addresses",
			callerRealm:     routerRealm,
			addr:            testutils.TestAddress("user1"),
			refAddr:         testutils.TestAddress("referrer1"),
			expectedSuccess: true,
		},
		{
			name:            "Success register with zero address referral",
			callerRealm:     routerRealm,
			addr:            testutils.TestAddress("user2"),
			refAddr:         zeroAddress,
			expectedSuccess: true,
		},
		{
			name:            "Fail register with self referral",
			callerRealm:     routerRealm,
			addr:            testutils.TestAddress("user3"),
			refAddr:         testutils.TestAddress("user3"),
			expectedSuccess: false,
		},
		{
			name:            "Fail register with unauthorized caller",
			callerRealm:     userRealm,
			addr:            testutils.TestAddress("user4"),
			refAddr:         testutils.TestAddress("referrer2"),
			expectedSuccess: false,
		},
	}

	for _, tc := range tests {
		t.Run(tc.name, func(t *testing.T) {
			cleanupKeeper()

			// given
			testing.SetRealm(tc.callerRealm)

			// when
			success := TryRegister(cross, tc.addr, tc.refAddr.String())

			// then
			uassert.Equal(t, tc.expectedSuccess, success)
		})
	}
}

// Since there are no public update/remove functions in the API,
// these tests have been removed as they test internal implementation
// that requires realm context not available in unit tests.

func TestKeeper_Has(t *testing.T) {
	tests := []struct {
		name          string
		addr          address
		setupReferral bool
		refAddr       address
		expectedHas   bool
	}{
		{
			name:          "True for existing referral",
			addr:          testutils.TestAddress("user1"),
			setupReferral: true,
			refAddr:       testutils.TestAddress("referrer1"),
			expectedHas:   true,
		},
		{
			name:          "False for non-existing referral",
			addr:          testutils.TestAddress("user2"),
			setupReferral: false,
			expectedHas:   false,
		},
		{
			name:          "False for zero address referral", // Zero address means no referral
			addr:          testutils.TestAddress("user3"),
			setupReferral: true,
			refAddr:       zeroAddress,
			expectedHas:   false, // This should be false, not true
		},
	}

	for _, tc := range tests {
		t.Run(tc.name, func(t *testing.T) {
			cleanupKeeper()

			// given
			testing.SetRealm(testing.NewCodeRealm("gno.land/r/gnoswap/router"))

			if tc.setupReferral {
				TryRegister(cross, tc.addr, tc.refAddr.String())
			}

			// when
			result := HasReferral(tc.addr.String()) // Use global function instead of k.has()

			// then
			uassert.Equal(t, tc.expectedHas, result)
		})
	}
}

func TestKeeper_Get(t *testing.T) {
	tests := []struct {
		name          string
		addr          address
		setupReferral bool
		refAddr       address
		expectedAddr  string
		expectedError bool
	}{
		{
			name:          "Success get existing referral",
			addr:          testutils.TestAddress("user1"),
			setupReferral: true,
			refAddr:       testutils.TestAddress("referrer1"),
			expectedAddr:  testutils.TestAddress("referrer1").String(),
			expectedError: false,
		},
		{
			name:          "Empty result for non-existing referral",
			addr:          testutils.TestAddress("user2"),
			setupReferral: false,
			expectedAddr:  "",
			expectedError: false, // GetReferral returns empty string, not error
		},
		{
			name:          "Empty result for zero address referral",
			addr:          testutils.TestAddress("user3"),
			setupReferral: true,
			refAddr:       zeroAddress,
			expectedAddr:  "", // Zero address returns empty string
			expectedError: false,
		},
	}

	for _, tc := range tests {
		t.Run(tc.name, func(t *testing.T) {
			cleanupKeeper()

			// given
			testing.SetRealm(testing.NewCodeRealm("gno.land/r/gnoswap/router"))

			if tc.setupReferral {
				TryRegister(cross, tc.addr, tc.refAddr.String())
			}

			// when
			result := GetReferral(tc.addr.String()) // Use global function

			// then
			uassert.Equal(t, tc.expectedAddr, result)
		})
	}
}

func TestKeeper_IsEmpty(t *testing.T) {
	tests := []struct {
		name           string
		setupReferrals []struct {
			addr    address
			refAddr address
		}
		expectedIsEmpty bool
	}{
		{
			name: "True when no referrals exist",
			setupReferrals: []struct {
				addr    address
				refAddr address
			}{},
			expectedIsEmpty: true,
		},
		{
			name: "False when referrals exist",
			setupReferrals: []struct {
				addr    address
				refAddr address
			}{
				{testutils.TestAddress("user1"), testutils.TestAddress("referrer1")},
			},
			expectedIsEmpty: false,
		},
		{
			name: "False when multiple referrals exist",
			setupReferrals: []struct {
				addr    address
				refAddr address
			}{
				{testutils.TestAddress("user1"), testutils.TestAddress("referrer1")},
				{testutils.TestAddress("user2"), testutils.TestAddress("referrer2")},
			},
			expectedIsEmpty: false,
		},
	}

	for _, tc := range tests {
		t.Run(tc.name, func(t *testing.T) {
			cleanupKeeper()

			// given
			testing.SetRealm(testing.NewCodeRealm("gno.land/r/gnoswap/router"))

			for _, ref := range tc.setupReferrals {
				TryRegister(cross, ref.addr, ref.refAddr.String())
			}

			// when
			result := IsEmpty() // Use global function

			// then
			uassert.Equal(t, tc.expectedIsEmpty, result)
		})
	}
}

func TestKeeper_NewKeeper(t *testing.T) {
	k := NewKeeper()

	uassert.NotEqual(t, nil, k)
	uassert.True(t, k.isEmpty())
}

// Helper functions
func setupKeeperTest() *keeper {
	return NewKeeper().(*keeper)
}

func cleanupKeeper() {
	// Reset global keeper
	gReferralKeeper = NewKeeper()
}
