package v1

import (
	"testing"

	"gno.land/p/nt/uassert"
	"gno.land/p/nt/testutils"

	"gno.land/r/gnoswap/gov/staker"
)

// TestGetter_GetTotalDelegated tests GetTotalDelegated
func TestGetter_GetTotalDelegated(t *testing.T) {
	tests := []struct {
		name     string
		amount   int64
		expected int64
	}{
		{
			name:     "Zero total delegated",
			amount:   0,
			expected: 0,
		},
		{
			name:     "Positive total delegated",
			amount:   1000,
			expected: 1000,
		},
		{
			name:     "Large total delegated",
			amount:   1_000_000_000_000,
			expected: 1_000_000_000_000,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			// Given: Setup store with total delegated amount
			store := newMockGovStakerStore().(*mockGovStakerStore)
			store.SetTotalDelegatedAmount(tt.amount)

			gs := &govStakerV1{store: store}

			// When: Get total delegated
			result := gs.GetTotalDelegated()

			// Then: Should return correct amount
			uassert.Equal(t, result, tt.expected)
		})
	}
}

// TestGetter_GetTotalLockedAmount tests GetTotalLockedAmount
func TestGetter_GetTotalLockedAmount(t *testing.T) {
	tests := []struct {
		name     string
		amount   int64
		expected int64
	}{
		{
			name:     "Zero total locked",
			amount:   0,
			expected: 0,
		},
		{
			name:     "Positive total locked",
			amount:   1000,
			expected: 1000,
		},
		{
			name:     "Large total locked",
			amount:   500_000_000_000,
			expected: 500_000_000_000,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			// Given: Setup store with total locked amount
			store := newMockGovStakerStore().(*mockGovStakerStore)
			store.SetTotalLockedAmount(tt.amount)

			gs := &govStakerV1{store: store}

			// When: Get total locked amount
			result := gs.GetTotalLockedAmount()

			// Then: Should return correct amount
			uassert.Equal(t, result, tt.expected)
		})
	}
}

// TestGetter_GetLockedAmount tests GetLockedAmount
func TestGetter_GetLockedAmount(t *testing.T) {
	tests := []struct {
		name     string
		amount   int64
		expected int64
	}{
		{
			name:     "Zero locked amount",
			amount:   0,
			expected: 0,
		},
		{
			name:     "Positive locked amount",
			amount:   1500,
			expected: 1500,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			// Given: Setup store
			store := newMockGovStakerStore().(*mockGovStakerStore)
			store.SetTotalLockedAmount(tt.amount)

			gs := &govStakerV1{store: store}

			// When: Get locked amount (should return same as GetTotalLockedAmount)
			result := gs.GetLockedAmount()

			// Then: Should return correct amount
			uassert.Equal(t, result, tt.expected)
		})
	}
}

// TestGetter_GetUnDelegationLockupPeriod tests GetUnDelegationLockupPeriod
func TestGetter_GetUnDelegationLockupPeriod(t *testing.T) {
	tests := []struct {
		name     string
		period   int64
		expected int64
	}{
		{
			name:     "One day lockup",
			period:   86400,
			expected: 86400,
		},
		{
			name:     "Seven days lockup",
			period:   604800,
			expected: 604800,
		},
		{
			name:     "Custom lockup period",
			period:   172800,
			expected: 172800,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			// Given: Setup store with lockup period
			store := newMockGovStakerStore().(*mockGovStakerStore)
			store.SetUnDelegationLockupPeriod(tt.period)

			gs := &govStakerV1{store: store}

			// When: Get lockup period
			result := gs.GetUnDelegationLockupPeriod()

			// Then: Should return correct period
			uassert.Equal(t, result, tt.expected)
		})
	}
}

// TestGetter_GetEmissionRewardBalance tests GetEmissionRewardBalance
func TestGetter_GetEmissionRewardBalance(t *testing.T) {
	tests := []struct {
		name     string
		balance  int64
		expected int64
	}{
		{
			name:     "Zero balance",
			balance:  0,
			expected: 0,
		},
		{
			name:     "Positive balance",
			balance:  50000,
			expected: 50000,
		},
		{
			name:     "Large balance",
			balance:  999_999_999_999,
			expected: 999_999_999_999,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			// Given: Setup store with emission balance
			store := newMockGovStakerStore().(*mockGovStakerStore)
			store.SetEmissionRewardBalance(tt.balance)

			gs := &govStakerV1{store: store}

			// When: Get emission reward balance
			result := gs.GetEmissionRewardBalance()

			// Then: Should return correct balance
			uassert.Equal(t, result, tt.expected)
		})
	}
}

// TestGetter_GetDelegationCount tests GetDelegationCount
func TestGetter_GetDelegationCount(t *testing.T) {
	tests := []struct {
		name              string
		delegationCount   int
		expectedCount     int
	}{
		{
			name:              "Empty store",
			delegationCount:   0,
			expectedCount:     0,
		},
		{
			name:              "Single delegation",
			delegationCount:   1,
			expectedCount:     1,
		},
		{
			name:              "Multiple delegations",
			delegationCount:   5,
			expectedCount:     5,
		},
		{
			name:              "Large number of delegations",
			delegationCount:   100,
			expectedCount:     100,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			// Given: Setup store with delegations
			store := newMockGovStakerStore().(*mockGovStakerStore)

			for i := 0; i < tt.delegationCount; i++ {
				delegation := NewDelegation(
					int64(i+1),
					address(testutils.TestAddress("delegator" + string(rune(i)))),
					address("g1v7n2w36m8q5p9vc6fmpcprgey4ck233jdgw3kl"),
					int64(1000*(i+1)),
					100,
					100,
				)
				store.SetDelegation(int64(i+1), delegation)
			}

			gs := &govStakerV1{store: store}

			// When: Get delegation count
			result := gs.GetDelegationCount()

			// Then: Should return correct count
			uassert.Equal(t, result, tt.expectedCount)
		})
	}
}

// TestGetter_GetDelegationIDs tests GetDelegationIDs pagination
func TestGetter_GetDelegationIDs(t *testing.T) {
	tests := []struct {
		name              string
		totalDelegations  int
		offset            int
		count             int
		expectedCount     int
	}{
		{
			name:              "Get first page",
			totalDelegations: 5,
			offset:           0,
			count:            2,
			expectedCount:    2,
		},
		{
			name:              "Get second page",
			totalDelegations: 5,
			offset:           2,
			count:            2,
			expectedCount:    2,
		},
		{
			name:              "Get last page with partial results",
			totalDelegations: 5,
			offset:           3,
			count:            3,
			expectedCount:    2,
		},
		{
			name:              "Offset beyond total",
			totalDelegations: 5,
			offset:           10,
			count:            2,
			expectedCount:    0,
		},
		{
			name:              "Get all at once",
			totalDelegations: 5,
			offset:           0,
			count:            10,
			expectedCount:    5,
		},
		{
			name:              "Empty store",
			totalDelegations: 0,
			offset:           0,
			count:            5,
			expectedCount:    0,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			// Given: Setup store with delegations
			store := newMockGovStakerStore().(*mockGovStakerStore)

			for i := 0; i < tt.totalDelegations; i++ {
				delegation := NewDelegation(
					int64(i+1),
					address(testutils.TestAddress("delegator" + string(rune(i)))),
					address("g1v7n2w36m8q5p9vc6fmpcprgey4ck233jdgw3kl"),
					int64(1000*(i+1)),
					100,
					100,
				)
				store.SetDelegation(int64(i+1), delegation)
			}

			gs := &govStakerV1{store: store}

			// When: Get delegations with pagination
			ids := gs.GetDelegationIDs(tt.offset, tt.count)

			// Then: Should return correct number of IDs
			uassert.Equal(t, len(ids), tt.expectedCount)

			// Verify IDs are sequential
			for i, id := range ids {
				expectedID := int64(tt.offset+i+1)
				uassert.Equal(t, id, expectedID)
			}
		})
	}
}

// TestGetter_ExistsDelegation tests ExistsDelegation
func TestGetter_ExistsDelegation(t *testing.T) {
	tests := []struct {
		name          string
		delegationID  int64
		shouldExist   bool
		setupStore    func(*mockGovStakerStore, int64)
	}{
		{
			name:         "Delegation exists",
			delegationID: 1,
			shouldExist:  true,
			setupStore: func(store *mockGovStakerStore, id int64) {
				delegation := NewDelegation(
					id,
					address("g1u7y667z64x2h7vc6fmpcprgey4ck233jaww9zq"),
					address("g1v7n2w36m8q5p9vc6fmpcprgey4ck233jdgw3kl"),
					1000,
					100,
					100,
				)
				store.SetDelegation(id, delegation)
			},
		},
		{
			name:         "Delegation does not exist",
			delegationID: 999,
			shouldExist:  false,
			setupStore: func(store *mockGovStakerStore, id int64) {
				// Do nothing
			},
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			// Given: Setup store
			store := newMockGovStakerStore().(*mockGovStakerStore)
			tt.setupStore(store, tt.delegationID)

			gs := &govStakerV1{store: store}

			// When: Check if delegation exists
			exists := gs.ExistsDelegation(tt.delegationID)

			// Then: Should return correct result
			uassert.Equal(t, exists, tt.shouldExist)
		})
	}
}

// TestGetter_GetDelegation tests GetDelegation
func TestGetter_GetDelegation(t *testing.T) {
	tests := []struct {
		name           string
		delegationID   int64
		shouldExist    bool
		expectedAmount int64
	}{
		{
			name:           "Get existing delegation",
			delegationID:   1,
			shouldExist:    true,
			expectedAmount: 1000,
		},
		{
			name:           "Get non-existent delegation",
			delegationID:   999,
			shouldExist:    false,
			expectedAmount: 0,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			// Given: Setup store
			store := newMockGovStakerStore().(*mockGovStakerStore)

			if tt.shouldExist {
				delegation := NewDelegation(
					tt.delegationID,
					address("g1u7y667z64x2h7vc6fmpcprgey4ck233jaww9zq"),
					address("g1v7n2w36m8q5p9vc6fmpcprgey4ck233jdgw3kl"),
					tt.expectedAmount,
					100,
					100,
				)
				store.SetDelegation(tt.delegationID, delegation)
			}

			gs := &govStakerV1{store: store}

			// When: Get delegation
			delegation, err := gs.GetDelegation(tt.delegationID)

			// Then: Should return correct result
			if tt.shouldExist {
				uassert.NoError(t, err)
				uassert.NotNil(t, delegation)
				uassert.Equal(t, delegation.TotalDelegatedAmount(), tt.expectedAmount)
			} else {
				uassert.NotNil(t, err)
				uassert.Nil(t, delegation)
			}
		})
	}
}

// TestGetter_GetDelegationWithdrawCount tests GetDelegationWithdrawCount
func TestGetter_GetDelegationWithdrawCount(t *testing.T) {
	tests := []struct {
		name               string
		setupDelegation    func() *staker.Delegation
		expectedCount      int
	}{
		{
			name: "Delegation with no withdraws",
			setupDelegation: func() *staker.Delegation {
				return NewDelegation(
					1,
					address("g1u7y667z64x2h7vc6fmpcprgey4ck233jaww9zq"),
					address("g1v7n2w36m8q5p9vc6fmpcprgey4ck233jdgw3kl"),
					1000,
					100,
					100,
				)
			},
			expectedCount: 0,
		},
		{
			name: "Delegation with single withdraw",
			setupDelegation: func() *staker.Delegation {
				delegation := NewDelegation(
					1,
					address("g1u7y667z64x2h7vc6fmpcprgey4ck233jaww9zq"),
					address("g1v7n2w36m8q5p9vc6fmpcprgey4ck233jdgw3kl"),
					1000,
					100,
					100,
				)
				resolver := NewDelegationResolver(delegation)
				resolver.UnDelegate(300, 200, 200, 86400)
				return delegation
			},
			expectedCount: 1,
		},
		{
			name: "Delegation with multiple withdraws",
			setupDelegation: func() *staker.Delegation {
				delegation := NewDelegation(
					1,
					address("g1u7y667z64x2h7vc6fmpcprgey4ck233jaww9zq"),
					address("g1v7n2w36m8q5p9vc6fmpcprgey4ck233jdgw3kl"),
					1000,
					100,
					100,
				)
				resolver := NewDelegationResolver(delegation)
				resolver.UnDelegate(300, 200, 200, 86400)
				resolver.UnDelegate(200, 300, 300, 86400)
				return delegation
			},
			expectedCount: 2,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			// Given: Setup store with delegation
			store := newMockGovStakerStore().(*mockGovStakerStore)
			delegation := tt.setupDelegation()
			store.SetDelegation(1, delegation)

			gs := &govStakerV1{store: store}

			// When: Get withdraw count
			count := gs.GetDelegationWithdrawCount(1)

			// Then: Should return correct count
			uassert.Equal(t, count, tt.expectedCount)
		})
	}
}

// TestGetter_GetDelegationWithdraws tests GetDelegationWithdraws pagination
func TestGetter_GetDelegationWithdraws(t *testing.T) {
	tests := []struct {
		name                    string
		setupDelegation         func() *staker.Delegation
		offset                  int
		count                   int
		expectedCount           int
		expectedFirstWithdraw   int64
	}{
		{
			name: "Get first withdraw",
			setupDelegation: func() *staker.Delegation {
				delegation := NewDelegation(
					1,
					address("g1u7y667z64x2h7vc6fmpcprgey4ck233jaww9zq"),
					address("g1v7n2w36m8q5p9vc6fmpcprgey4ck233jdgw3kl"),
					1000,
					100,
					100,
				)
				resolver := NewDelegationResolver(delegation)
				resolver.UnDelegate(100, 200, 200, 86400)
				resolver.UnDelegate(150, 300, 300, 86400)
				return delegation
			},
			offset:                0,
			count:                 1,
			expectedCount:         1,
			expectedFirstWithdraw: 100,
		},
		{
			name: "Get multiple withdraws",
			setupDelegation: func() *staker.Delegation {
				delegation := NewDelegation(
					1,
					address("g1u7y667z64x2h7vc6fmpcprgey4ck233jaww9zq"),
					address("g1v7n2w36m8q5p9vc6fmpcprgey4ck233jdgw3kl"),
					1000,
					100,
					100,
				)
				resolver := NewDelegationResolver(delegation)
				resolver.UnDelegate(100, 200, 200, 86400)
				resolver.UnDelegate(150, 300, 300, 86400)
				resolver.UnDelegate(200, 400, 400, 86400)
				return delegation
			},
			offset:                0,
			count:                 2,
			expectedCount:         2,
			expectedFirstWithdraw: 100,
		},
		{
			name: "Get withdraws with offset",
			setupDelegation: func() *staker.Delegation {
				delegation := NewDelegation(
					1,
					address("g1u7y667z64x2h7vc6fmpcprgey4ck233jaww9zq"),
					address("g1v7n2w36m8q5p9vc6fmpcprgey4ck233jdgw3kl"),
					1000,
					100,
					100,
				)
				resolver := NewDelegationResolver(delegation)
				resolver.UnDelegate(100, 200, 200, 86400)
				resolver.UnDelegate(150, 300, 300, 86400)
				return delegation
			},
			offset:                1,
			count:                 1,
			expectedCount:         1,
			expectedFirstWithdraw: 150,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			// Given: Setup store with delegation
			store := newMockGovStakerStore().(*mockGovStakerStore)
			delegation := tt.setupDelegation()
			store.SetDelegation(1, delegation)

			gs := &govStakerV1{store: store}

			// When: Get withdraws
			withdraws, err := gs.GetDelegationWithdraws(1, tt.offset, tt.count)

			// Then: Should return correct withdraws
			uassert.NoError(t, err)
			uassert.Equal(t, len(withdraws), tt.expectedCount)
			if len(withdraws) > 0 {
				uassert.Equal(t, withdraws[0].UnDelegateAmount(), tt.expectedFirstWithdraw)
			}
		})
	}
}

// TestGetter_GetCollectableWithdrawAmount tests GetCollectableWithdrawAmount
func TestGetter_GetCollectableWithdrawAmount(t *testing.T) {
	tests := []struct {
		name               string
		setupDelegation    func() *staker.Delegation
		expectedAmount     int64
	}{
		{
			name: "No collectable amount",
			setupDelegation: func() *staker.Delegation {
				return NewDelegation(
					1,
					address("g1u7y667z64x2h7vc6fmpcprgey4ck233jaww9zq"),
					address("g1v7n2w36m8q5p9vc6fmpcprgey4ck233jdgw3kl"),
					1000,
					100,
					100,
				)
			},
			expectedAmount: 0,
		},
		{
			name: "Single undelegation with lockup",
			setupDelegation: func() *staker.Delegation {
				delegation := NewDelegation(
					1,
					address("g1u7y667z64x2h7vc6fmpcprgey4ck233jaww9zq"),
					address("g1v7n2w36m8q5p9vc6fmpcprgey4ck233jdgw3kl"),
					1000,
					100,
					100,
				)
				resolver := NewDelegationResolver(delegation)
				resolver.UnDelegate(300, 200, 200, 86400)
				return delegation
			},
			expectedAmount: 300,
		},
		{
			name: "Multiple undelegations with partial collection",
			setupDelegation: func() *staker.Delegation {
				delegation := NewDelegation(
					1,
					address("g1u7y667z64x2h7vc6fmpcprgey4ck233jaww9zq"),
					address("g1v7n2w36m8q5p9vc6fmpcprgey4ck233jdgw3kl"),
					1000,
					100,
					100,
				)
				resolver := NewDelegationResolver(delegation)
				resolver.UnDelegate(300, 200, 200, 86400)
				resolver.UnDelegateWithoutLockup(200, 300, 300) // Already collected
				return delegation
			},
			expectedAmount: 300, // Only the locked one counts
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			// Given: Setup store with delegation
			store := newMockGovStakerStore().(*mockGovStakerStore)
			delegation := tt.setupDelegation()
			store.SetDelegation(1, delegation)

			gs := &govStakerV1{store: store}

			// When: Get collectable withdraw amount
			amount := gs.GetCollectableWithdrawAmount(1)

			// Then: Should return correct amount
			uassert.Equal(t, amount, tt.expectedAmount)
		})
	}
}

// TestGetter_HasDelegationSnapshotsKey tests HasDelegationSnapshotsKey
func TestGetter_HasDelegationSnapshotsKey(t *testing.T) {
	tests := []struct {
		name                    string
		hasTotalDelegationKey   bool
		expected                bool
	}{
		{
			name:                    "Store has snapshots key",
			hasTotalDelegationKey:   true,
			expected:                true,
		},
		{
			name:                    "Store without snapshots key",
			hasTotalDelegationKey:   false,
			expected:                false,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			// Given: Setup store
			mockStore := newMockGovStakerStore().(*mockGovStakerStore)
			mockStore.hasTotalDelegationHistoryKey = tt.hasTotalDelegationKey

			gs := &govStakerV1{store: mockStore}

			// When: Check if snapshots key exists
			result := gs.HasDelegationSnapshotsKey()

			// Then: Should return expected result
			uassert.Equal(t, result, tt.expected)
		})
	}
}
