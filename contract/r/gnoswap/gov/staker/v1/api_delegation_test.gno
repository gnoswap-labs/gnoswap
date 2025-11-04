package v1

import (
	"testing"

	"gno.land/p/nt/uassert"
)

func TestApiDelegation_GetTotalxGnsSupply(t *testing.T) {
	tests := []struct {
		name     string
		setup    func() *govStakerV1
		expected int64
	}{
		{
			name: "returns total xGNS supply",
			setup: func() *govStakerV1 {
				return createTestGovStaker()
			},
			// xGNS supply is determined by the actual xgns module state
			expected: 0, // Initially 0 in test environment
		},
	}

	for _, tc := range tests {
		t.Run(tc.name, func(t *testing.T) {
			// given
			gs := tc.setup()

			// when
			result := gs.GetTotalxGnsSupply()

			// then
			uassert.Equal(t, result, tc.expected)
		})
	}
}

func TestApiDelegation_GetTotalVoteWeight(t *testing.T) {
	tests := []struct {
		name     string
		setup    func() *govStakerV1
		expected int64
	}{
		{
			name: "returns total vote weight",
			setup: func() *govStakerV1 {
				return createTestGovStaker()
			},
			// Vote weight is total supply minus launchpad balance
			expected: 0, // Initially 0 in test environment
		},
	}

	for _, tc := range tests {
		t.Run(tc.name, func(t *testing.T) {
			// given
			gs := tc.setup()

			// when
			result := gs.GetTotalVoteWeight()

			// then
			uassert.Equal(t, result, tc.expected)
		})
	}
}

func TestApiDelegation_GetTotalDelegated(t *testing.T) {
	tests := []struct {
		name                 string
		setup                func() *govStakerV1
		expectedAmount       int64
		expectedHasPanic     bool
		expectedPanicMessage string
	}{
		{
			name: "returns total delegated amount - zero",
			setup: func() *govStakerV1 {
				gs := createTestGovStaker()
				_ = gs.store.SetTotalDelegatedAmount(0)
				return gs
			},
			expectedAmount:   0,
			expectedHasPanic: false,
		},
		{
			name: "returns total delegated amount - positive",
			setup: func() *govStakerV1 {
				gs := createTestGovStaker()
				_ = gs.store.SetTotalDelegatedAmount(1000000)
				return gs
			},
			expectedAmount:   1000000,
			expectedHasPanic: false,
		},
		{
			name: "returns total delegated amount - large value",
			setup: func() *govStakerV1 {
				gs := createTestGovStaker()
				_ = gs.store.SetTotalDelegatedAmount(9223372036854775807) // max int64
				return gs
			},
			expectedAmount:   9223372036854775807,
			expectedHasPanic: false,
		},
	}

	for _, tc := range tests {
		t.Run(tc.name, func(t *testing.T) {
			if tc.expectedHasPanic {
				defer func() {
					if r := recover(); r == nil {
						t.Errorf("expected panic but did not panic")
					}
				}()
			}

			// given
			gs := tc.setup()

			// when
			result := gs.GetTotalDelegated()

			// then
			if !tc.expectedHasPanic {
				uassert.Equal(t, result, tc.expectedAmount)
			}
		})
	}
}

func TestApiDelegation_GetTotalLockedAmount(t *testing.T) {
	tests := []struct {
		name                 string
		setup                func() *govStakerV1
		expectedAmount       int64
		expectedHasPanic     bool
		expectedPanicMessage string
	}{
		{
			name: "returns total locked amount - zero",
			setup: func() *govStakerV1 {
				gs := createTestGovStaker()
				_ = gs.store.SetTotalLockedAmount(0)
				return gs
			},
			expectedAmount:   0,
			expectedHasPanic: false,
		},
		{
			name: "returns total locked amount - positive",
			setup: func() *govStakerV1 {
				gs := createTestGovStaker()
				_ = gs.store.SetTotalLockedAmount(500000)
				return gs
			},
			expectedAmount:   500000,
			expectedHasPanic: false,
		},
		{
			name: "returns total locked amount - large value",
			setup: func() *govStakerV1 {
				gs := createTestGovStaker()
				_ = gs.store.SetTotalLockedAmount(9223372036854775807) // max int64
				return gs
			},
			expectedAmount:   9223372036854775807,
			expectedHasPanic: false,
		},
		{
			name: "returns total locked amount - boundary value",
			setup: func() *govStakerV1 {
				gs := createTestGovStaker()
				_ = gs.store.SetTotalLockedAmount(1)
				return gs
			},
			expectedAmount:   1,
			expectedHasPanic: false,
		},
	}

	for _, tc := range tests {
		t.Run(tc.name, func(t *testing.T) {
			if tc.expectedHasPanic {
				defer func() {
					if r := recover(); r == nil {
						t.Errorf("expected panic but did not panic")
					}
				}()
			}

			// given
			gs := tc.setup()

			// when
			result := gs.GetTotalLockedAmount()

			// then
			if !tc.expectedHasPanic {
				uassert.Equal(t, result, tc.expectedAmount)
			}
		})
	}
}
