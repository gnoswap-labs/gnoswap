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
			name:            "Success register with contract address referral (removal)",
			callerRealm:     routerRealm,
			addr:            testutils.TestAddress("user2"),
			refAddr:         contractAddress(),
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
			name:                 "Panic with unauthorized caller",
			callerRealm:          userRealm,
			addr:                 testutils.TestAddress("user4"),
			refAddr:              testutils.TestAddress("referrer2"),
			expectedSuccess:      false,
			expectedPanicMessage: "unauthorized caller",
		},
	}

	for _, tc := range tests {
		t.Run(tc.name, func(t *testing.T) {
			cleanup(t)

			// given
			testing.SetRealm(tc.callerRealm)

			// when/then
			if tc.expectedPanicMessage != "" {
				uassert.AbortsContains(t, tc.expectedPanicMessage, func() {
					TryRegister(cross, tc.addr, tc.refAddr.String())
				})
			} else {
				success := TryRegister(cross, tc.addr, tc.refAddr.String())
				uassert.Equal(t, tc.expectedSuccess, success)
			}
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
			name:          "False for contract address referral", // Contract address means removal
			addr:          testutils.TestAddress("user3"),
			setupReferral: true,
			refAddr:       contractAddress(),
			expectedHas:   false, // This should be false, not true
		},
	}

	for _, tc := range tests {
		t.Run(tc.name, func(t *testing.T) {
			cleanup(t)

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
			name:          "Empty result for contract address referral",
			addr:          testutils.TestAddress("user3"),
			setupReferral: true,
			refAddr:       contractAddress(),
			expectedAddr:  "", // Contract address means removal, returns empty string
			expectedError: false,
		},
	}

	for _, tc := range tests {
		t.Run(tc.name, func(t *testing.T) {
			cleanup(t)

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
			cleanup(t)

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
	k := NewKeeper().(*keeper)
	if k == nil {
		t.Fatal("keeper should not be nil")
	}

	uassert.True(t, k.isEmpty())
}

func TestKeeper_ContractAddressRemoval(t *testing.T) {
	t.Run("Remove existing referral with contract address", func(t *testing.T) {
		cleanup(t)
		testing.SetRealm(testing.NewCodeRealm("gno.land/r/gnoswap/router"))

		user := testutils.TestAddress("user1")
		referrer := testutils.TestAddress("referrer1")

		// Register referral first
		success := TryRegister(cross, user, referrer.String())
		uassert.True(t, success, "Initial registration should succeed")
		uassert.True(t, HasReferral(user.String()), "Referral should exist after registration")

		// Simulate time passage to bypass rate limit
		k := gReferralKeeper.(*keeper)
		k.lastOps.Set(user.String(), int64(0))

		// Remove by registering with contract address
		success = TryRegister(cross, user, contractAddress().String())
		uassert.True(t, success, "Removal with contract address should succeed")
		uassert.False(t, HasReferral(user.String()), "Referral should not exist after removal")
	})

	t.Run("Contract address removal is not rate limited", func(t *testing.T) {
		cleanup(t)
		testing.SetRealm(testing.NewCodeRealm("gno.land/r/gnoswap/router"))

		user := testutils.TestAddress("user2")
		referrer := testutils.TestAddress("referrer2")

		// Register referral
		success := TryRegister(cross, user, referrer.String())
		uassert.True(t, success)
		uassert.True(t, HasReferral(user.String()))

		// Immediately try to remove with contract address (no time passage)
		// This should succeed because contract address removal bypasses rate limit
		success = TryRegister(cross, user, contractAddress().String())
		uassert.True(t, success, "Contract address removal should bypass rate limit")
		uassert.False(t, HasReferral(user.String()))
	})

	t.Run("Re-register after contract address removal", func(t *testing.T) {
		cleanup(t)
		testing.SetRealm(testing.NewCodeRealm("gno.land/r/gnoswap/router"))

		user := testutils.TestAddress("user3")
		referrer1 := testutils.TestAddress("referrer3a")
		referrer2 := testutils.TestAddress("referrer3b")

		// Register first referral
		success := TryRegister(cross, user, referrer1.String())
		uassert.True(t, success)
		uassert.Equal(t, referrer1.String(), GetReferral(user.String()))

		// Remove with contract address (bypasses rate limit)
		success = TryRegister(cross, user, contractAddress().String())
		uassert.True(t, success)
		uassert.False(t, HasReferral(user.String()))

		// Re-register with new referrer should be rate limited
		// because lastOps was set during first registration
		success = TryRegister(cross, user, referrer2.String())
		uassert.False(t, success, "Re-registration should be rate limited")
	})

	t.Run("Contract address on non-existent referral is no-op", func(t *testing.T) {
		cleanup(t)
		testing.SetRealm(testing.NewCodeRealm("gno.land/r/gnoswap/router"))

		user := testutils.TestAddress("user4")

		// Try to remove non-existent referral
		success := TryRegister(cross, user, contractAddress().String())
		uassert.True(t, success, "Contract address on non-existent should succeed (no-op)")
		uassert.False(t, HasReferral(user.String()))
	})

	t.Run("Multiple contract address removals are allowed", func(t *testing.T) {
		cleanup(t)
		testing.SetRealm(testing.NewCodeRealm("gno.land/r/gnoswap/router"))

		user := testutils.TestAddress("user5")
		referrer := testutils.TestAddress("referrer5")

		// Register
		TryRegister(cross, user, referrer.String())

		// Multiple contract address calls should all succeed
		for i := 0; i < 3; i++ {
			success := TryRegister(cross, user, contractAddress().String())
			uassert.True(t, success, "Multiple contract address calls should succeed")
		}
	})
}
