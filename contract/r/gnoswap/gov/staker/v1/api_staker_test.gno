package v1

import (
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
