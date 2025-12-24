package v1

import (
	"math"
	"testing"
	"time"

	"gno.land/p/nt/testutils"
	"gno.land/p/nt/uassert"

	"gno.land/r/gnoswap/gov/staker"
)

func TestApiStaker_GetLockedAmount(t *testing.T) {
	tests := []struct {
		name           string
		setup          func() *govStakerV1
		expectedAmount int64
	}{
		{
			name: "returns zero when no delegations",
			setup: func() *govStakerV1 {
				return createTestGovStaker()
			},
			expectedAmount: 0,
		},
		{
			name: "returns sum of locked amounts from single delegation",
			setup: func() *govStakerV1 {
				gs := createTestGovStaker()

				// Create delegation
				delegation := NewDelegation(
					1,
					testutils.TestAddress("alice"),
					testutils.TestAddress("validator1"),
					1000000,
					time.Now().Unix(),
					time.Now().Unix(),
				)

				_ = gs.store.SetDelegation(1, delegation)
				return gs
			},
			expectedAmount: 1000000,
		},
		{
			name: "returns sum of locked amounts from multiple delegations",
			setup: func() *govStakerV1 {
				gs := createTestGovStaker()
				now := time.Now().Unix()

				// Create multiple delegations
				delegation1 := NewDelegation(1, testutils.TestAddress("alice"), testutils.TestAddress("validator1"), 1000000, now, now)
				delegation2 := NewDelegation(2, testutils.TestAddress("bob"), testutils.TestAddress("validator2"), 2000000, now, now)
				delegation3 := NewDelegation(3, testutils.TestAddress("charlie"), testutils.TestAddress("validator3"), 500000, now, now)

				_ = gs.store.SetDelegation(1, delegation1)
				_ = gs.store.SetDelegation(2, delegation2)
				_ = gs.store.SetDelegation(3, delegation3)

				return gs
			},
			expectedAmount: 3500000,
		},
		{
			name: "handles delegation with zero locked amount",
			setup: func() *govStakerV1 {
				gs := createTestGovStaker()
				now := time.Now().Unix()

				delegation := NewDelegation(1, testutils.TestAddress("alice"), testutils.TestAddress("validator1"), 0, now, now)
				_ = gs.store.SetDelegation(1, delegation)

				return gs
			},
			expectedAmount: 0,
		},
	}

	for _, tc := range tests {
		t.Run(tc.name, func(t *testing.T) {
			// given
			gs := tc.setup()

			// when
			result := gs.GetLockedAmount()

			// then
			uassert.Equal(t, result, tc.expectedAmount)
		})
	}
}

func TestApiStaker_GetClaimableRewardByAddress(t *testing.T) {
	tests := []struct {
		name     string
		setup    func() *govStakerV1
		address  address
		expected string
	}{
		{
			name: "returns empty string when no rewards",
			setup: func() *govStakerV1 {
				gs := createTestGovStaker()
				return gs
			},
			address:  testutils.TestAddress("alice"),
			expected: "",
		},
	}

	for _, tc := range tests {
		t.Run(tc.name, func(t *testing.T) {
			// given
			gs := tc.setup()
			testing.SetRealm(testing.NewCodeRealm(GOV_STAKER_PKG_PATH))

			// when
			result := gs.GetClaimableRewardByAddress(tc.address)

			// then
			uassert.Equal(t, result, tc.expected)
		})
	}
}

func TestApiStaker_GetClaimableRewardByLaunchpad(t *testing.T) {
	tests := []struct {
		name     string
		setup    func() *govStakerV1
		address  address
		expected string
	}{
		{
			name: "returns empty string when no rewards",
			setup: func() *govStakerV1 {
				gs := createTestGovStaker()
				return gs
			},
			address:  testutils.TestAddress("launchpad1"),
			expected: "",
		},
	}

	for _, tc := range tests {
		t.Run(tc.name, func(t *testing.T) {
			// given
			gs := tc.setup()
			testing.SetRealm(testing.NewCodeRealm(GOV_STAKER_PKG_PATH))

			// when
			result := gs.GetClaimableRewardByLaunchpad(tc.address)

			// then
			uassert.Equal(t, result, tc.expected)
		})
	}
}

func TestApiStaker_GetClaimableRewardByRewardID(t *testing.T) {
	tests := []struct {
		name     string
		setup    func() *govStakerV1
		rewardID string
		expected string
	}{
		{
			name: "returns empty string when no rewards and no delegations",
			setup: func() *govStakerV1 {
				gs := createTestGovStaker()

				// Initialize emission reward manager
				emissionManager := staker.NewEmissionRewardManager()
				_ = gs.store.SetEmissionRewardManager(emissionManager)

				// Initialize protocol fee reward manager
				protocolFeeManager := staker.NewProtocolFeeRewardManager()
				_ = gs.store.SetProtocolFeeRewardManager(protocolFeeManager)

				return gs
			},
			rewardID: testutils.TestAddress("alice").String(),
			expected: "",
		},
	}

	for _, tc := range tests {
		t.Run(tc.name, func(t *testing.T) {
			// given
			gs := tc.setup()
			testing.SetRealm(testing.NewCodeRealm(GOV_STAKER_PKG_PATH))

			// when
			result := gs.GetClaimableRewardByRewardID(tc.rewardID)

			// then
			uassert.Equal(t, result, tc.expected)
		})
	}
}
// Test boundary conditions for safe arithmetic in API functions
func TestApiStaker_BoundaryConditions(t *testing.T) {
	t.Run("GetLockedAmount with large locked amounts", func(t *testing.T) {
		// given: multiple delegations with large locked amounts
		gs := createTestGovStaker()
		testing.SetRealm(testing.NewUserRealm(admin))

		alice := testutils.TestAddress("alice")
		bob := testutils.TestAddress("bob")
		validator := testutils.TestAddress("validator")

		// Create delegations with large locked amounts
		func(cur realm) {
			// First delegation with large locked amount
			delegation1 := staker.NewDelegation(
				1,
				alice,
				validator,
				math.MaxInt64/4,
				100,
				100,
			)
			// Add undelegation to create locked amount
			NewDelegationResolver(delegation1).UnDelegate(math.MaxInt64/8, 100, 100, 7*24*60*60)
			gs.store.SetDelegation(1, delegation1)

			// Second delegation with large locked amount
			delegation2 := staker.NewDelegation(
				2,
				bob,
				validator,
				math.MaxInt64/4,
				200,
				200,
			)
			NewDelegationResolver(delegation2).UnDelegate(math.MaxInt64/8, 200, 200, 7*24*60*60)
			gs.store.SetDelegation(2, delegation2)
		}(cross)

		// when: get total locked amount (uses safeAddInt64 at line 25)
		func(cur realm) {
			lockedAmount := gs.GetLockedAmount()

			// then: should succeed without overflow
			// Each delegation has locked amount of MaxInt64/8
			expectedMin := int64((math.MaxInt64 / 8) * 2)
			uassert.True(t, lockedAmount >= expectedMin)
		}(cross)
	})

	t.Run("GetLockedAmount overflow panic", func(t *testing.T) {
		// given: multiple delegations where sum of locked amounts would overflow
		gs := createTestGovStaker()
		testing.SetRealm(testing.NewUserRealm(admin))

		alice := testutils.TestAddress("alice")
		bob := testutils.TestAddress("bob")
		validator := testutils.TestAddress("validator")

		// Create delegations where LockedAmount is valid individually,
		// but their sum causes overflow in safeAddInt64
		func(cur realm) {
			// First delegation with large locked amount
			// LockedAmount = TotalDelegatedAmount - CollectedAmount
			delegation1 := staker.NewDelegation(
				1,
				alice,
				validator,
				math.MaxInt64/2+1000, // Total delegated
				100,
				100,
			)
			// Collect a small amount, leaving most as locked
			// LockedAmount = (MaxInt64/2+1000) - 1000 = MaxInt64/2
			resolver1 := NewDelegationResolver(delegation1)
			resolver1.delegation.SetCollectedAmount(1000)
			gs.store.SetDelegation(1, delegation1)

			// Second delegation with large locked amount
			delegation2 := staker.NewDelegation(
				2,
				bob,
				validator,
				math.MaxInt64/2+2000, // Total delegated
				200,
				200,
			)
			// LockedAmount = (MaxInt64/2+2000) - 1000 = MaxInt64/2+1000
			resolver2 := NewDelegationResolver(delegation2)
			resolver2.delegation.SetCollectedAmount(1000)
			gs.store.SetDelegation(2, delegation2)

			// Sum: (MaxInt64/2) + (MaxInt64/2+1000) = MaxInt64 + 1000 > MaxInt64 (overflow!)
		}(cross)

		// when: get total locked amount causing overflow in safeAddInt64
		didPanic := false
		func(cur realm) {
			defer func() {
				if r := recover(); r != nil {
					didPanic = true
				}
			}()
			_ = gs.GetLockedAmount()
		}(cross)

		// then: should panic on overflow
		uassert.True(t, didPanic)
	})
}
