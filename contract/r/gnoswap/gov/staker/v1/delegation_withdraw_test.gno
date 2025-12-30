package v1

import (
	"math"
	"testing"

	"gno.land/p/nt/uassert"
	"gno.land/r/gnoswap/gov/staker"
)

// TestNewDelegationWithdraw tests the creation of new delegation withdraws
func TestNewDelegationWithdraw(t *testing.T) {
	tests := []struct {
		name                     string
		delegationID             int64
		unDelegateAmount         int64
		createdAt                int64
		unDelegationLockupPeriod int64
		currentTime              int64
		expectedCollectableTime  int64
		expectedCollected        bool
	}{
		{
			name:                     "Create delegation withdraw with lockup",
			delegationID:             1,
			unDelegateAmount:         100,
			createdAt:                1000,
			unDelegationLockupPeriod: 7 * 24 * 60 * 60, // 7 days
			currentTime:              1000 + 7*24*60*60,
			expectedCollectableTime:  1000 + 7*24*60*60,
			expectedCollected:        false,
		},
		{
			name:                     "Create delegation withdraw with zero lockup",
			delegationID:             2,
			unDelegateAmount:         50,
			createdAt:                2000,
			unDelegationLockupPeriod: 0,
			currentTime:              2000,
			expectedCollectableTime:  2000,
			expectedCollected:        false,
		},
	}

	for _, tc := range tests {
		t.Run(tc.name, func(t *testing.T) {
			// when
			withdraw := NewDelegationWithdraw(
				tc.delegationID,
				tc.unDelegateAmount,
				tc.createdAt,
				tc.createdAt,
				tc.unDelegationLockupPeriod,
			)

			resolver := NewDelegationWithdrawResolver(withdraw)

			// then
			uassert.Equal(t, resolver.Get().DelegationID(), tc.delegationID)
			uassert.Equal(t, resolver.Get().UnDelegateAmount(), tc.unDelegateAmount)
			uassert.Equal(t, resolver.Get().UnDelegatedAt(), tc.createdAt)
			uassert.Equal(t, resolver.Get().CollectableTime(), tc.expectedCollectableTime)
			uassert.Equal(t, resolver.Get().IsCollected(), tc.expectedCollected)
			uassert.Equal(t, resolver.CollectableAmount(tc.currentTime), tc.unDelegateAmount)
		})
	}
}

// TestNewDelegationWithdrawWithoutLockup tests creating withdraw without lockup
func TestNewDelegationWithdrawWithoutLockup(t *testing.T) {
	tests := []struct {
		name             string
		delegationID     int64
		unDelegateAmount int64
		createdAt        int64
		currentTime      int64
	}{
		{
			name:             "Create withdraw without lockup",
			delegationID:     1,
			unDelegateAmount: 100,
			createdAt:        1000,
			currentTime:      1000,
		},
	}

	for _, tc := range tests {
		t.Run(tc.name, func(t *testing.T) {
			// when
			withdraw := NewDelegationWithdrawWithoutLockup(
				tc.delegationID,
				tc.unDelegateAmount,
				tc.createdAt,
				tc.createdAt,
			)

			resolver := NewDelegationWithdrawResolver(withdraw)

			// then
			uassert.Equal(t, resolver.Get().DelegationID(), tc.delegationID)
			uassert.Equal(t, resolver.Get().UnDelegateAmount(), tc.unDelegateAmount)
			uassert.Equal(t, resolver.Get().UnDelegatedAt(), tc.createdAt)
			uassert.Equal(t, resolver.Get().CollectableTime(), tc.createdAt)
			uassert.True(t, resolver.Get().IsCollected())
			uassert.Equal(t, resolver.CollectableAmount(tc.currentTime), int64(0))
		})
	}
}

// TestDelegationWithdrawResolver_IsCollectable tests the collectable status
func TestDelegationWithdrawResolver_IsCollectable(t *testing.T) {
	tests := []struct {
		name                string
		withdraw            *staker.DelegationWithdraw
		currentTime         int64
		expectedCollectable bool
	}{
		{
			name: "Collectable after lockup period",
			withdraw: staker.NewDelegationWithdraw(
				1,    // delegationID
				100,  // unDelegateAmount
				100,  // createdHeight
				1000, // createdAt
				500,  // unDelegationLockupPeriod
			),
			currentTime:         2000, // After collectableTime (1000 + 500 = 1500)
			expectedCollectable: true,
		},
		{
			name: "Not collectable before lockup period",
			withdraw: staker.NewDelegationWithdraw(
				1,
				100,
				100,
				1000,
				500,
			),
			currentTime:         1200, // Before collectableTime (1500)
			expectedCollectable: false,
		},
		{
			name: "Not collectable if already collected",
			withdraw: staker.NewDelegationWithdrawWithoutLockup(
				1,
				100,
				100,
				1000,
			),
			currentTime:         2000,
			expectedCollectable: false, // Already collected in constructor
		},
		{
			name: "Not collectable if no amount to collect",
			withdraw: staker.NewDelegationWithdraw(
				1,
				0, // Zero amount
				100,
				1000,
				500,
			),
			currentTime:         2000,
			expectedCollectable: false,
		},
	}

	for _, tc := range tests {
		t.Run(tc.name, func(t *testing.T) {
			// given
			resolver := NewDelegationWithdrawResolver(tc.withdraw)

			// when
			result := resolver.IsCollectable(tc.currentTime)

			// then
			uassert.Equal(t, result, tc.expectedCollectable)
		})
	}
}

// TestDelegationWithdrawResolver_CollectableAmount tests the collectable amount calculation
func TestDelegationWithdrawResolver_CollectableAmount(t *testing.T) {
	tests := []struct {
		name           string
		withdraw       *staker.DelegationWithdraw
		currentTime    int64
		expectedAmount int64
	}{
		{
			name: "Full amount collectable after lockup",
			withdraw: staker.NewDelegationWithdraw(
				1,
				100,
				100,
				1000,
				500,
			),
			currentTime:    2000,
			expectedAmount: 100,
		},
		{
			name: "Zero collectable before lockup",
			withdraw: staker.NewDelegationWithdraw(
				1,
				100,
				100,
				1000,
				500,
			),
			currentTime:    1200,
			expectedAmount: 0,
		},
		{
			name: "Zero collectable if already collected",
			withdraw: staker.NewDelegationWithdrawWithoutLockup(
				1,
				100,
				100,
				1000,
			),
			currentTime:    2000,
			expectedAmount: 0,
		},
	}

	for _, tc := range tests {
		t.Run(tc.name, func(t *testing.T) {
			// given
			resolver := NewDelegationWithdrawResolver(tc.withdraw)

			// when
			result := resolver.CollectableAmount(tc.currentTime)

			// then
			uassert.Equal(t, result, tc.expectedAmount)
		})
	}
}

// TestDelegationWithdrawResolver_Collect tests the collection functionality
func TestDelegationWithdrawResolver_Collect(t *testing.T) {
	tests := []struct {
		name                    string
		withdraw                *staker.DelegationWithdraw
		collectAmount           int64
		currentTime             int64
		expectedError           error
		expectedCollected       bool
		expectedCollectedAmount int64
	}{
		{
			name: "Successful collection",
			withdraw: staker.NewDelegationWithdraw(
				1,
				100,
				100,
				1000,
				500, // collectableTime will be 1500
			),
			collectAmount:           100,
			currentTime:             2000, // After collectableTime
			expectedError:           nil,
			expectedCollected:       true,
			expectedCollectedAmount: 100,
		},
		{
			name: "Cannot collect before lockup period",
			withdraw: staker.NewDelegationWithdraw(
				1,
				100,
				100,
				1000,
				500,
			),
			collectAmount: 50,
			currentTime:   1200, // Before collectableTime (1500)
			expectedError: staker.ErrWithdrawNotCollectable,
		},
		{
			name: "Cannot collect if no amount",
			withdraw: staker.NewDelegationWithdraw(
				1,
				0, // Zero amount
				100,
				1000,
				500,
			),
			collectAmount: 50,
			currentTime:   2000,
			expectedError: staker.ErrWithdrawNotCollectable,
		},
		{
			name: "Cannot collect if already collected",
			withdraw: staker.NewDelegationWithdrawWithoutLockup(
				1,
				100,
				100,
				1000,
			),
			collectAmount: 50,
			currentTime:   2000,
			expectedError: staker.ErrWithdrawNotCollectable,
		},
	}

	for _, tc := range tests {
		t.Run(tc.name, func(t *testing.T) {
			// given
			resolver := NewDelegationWithdrawResolver(tc.withdraw)

			// when
			err := resolver.Collect(tc.collectAmount, tc.currentTime)

			// then
			if tc.expectedError != nil {
				uassert.ErrorIs(t, err, tc.expectedError)
			} else {
				uassert.NoError(t, err)
				uassert.Equal(t, tc.withdraw.IsCollected(), tc.expectedCollected)
				uassert.Equal(t, tc.withdraw.CollectedAmount(), tc.expectedCollectedAmount)
				uassert.Equal(t, tc.withdraw.CollectedAt(), tc.currentTime)
			}
		})
	}
}

// TestDelegationWithdrawResolver_CollectErrors tests additional error cases
func TestDelegationWithdrawResolver_CollectErrors(t *testing.T) {
	t.Run("Collect with negative amount", func(t *testing.T) {
		// given
		withdraw := staker.NewDelegationWithdraw(
			1,
			100,
			100,
			1000,
			500,
		)
		resolver := NewDelegationWithdrawResolver(withdraw)

		// when - try to collect negative amount after lockup
		currentTime := int64(2000)
		err := resolver.Collect(-50, currentTime)

		// then - should succeed (no validation on amount in Collect)
		uassert.NoError(t, err)
		uassert.Equal(t, withdraw.CollectedAmount(), int64(-50))
	})

	t.Run("Collect exactly at collectable time", func(t *testing.T) {
		// given
		createdAt := int64(1000)
		lockupPeriod := int64(500)
		withdraw := staker.NewDelegationWithdraw(
			1,
			100,
			100,
			createdAt,
			lockupPeriod,
		)
		resolver := NewDelegationWithdrawResolver(withdraw)

		// when - collect exactly when lockup expires
		collectableTime := createdAt + lockupPeriod
		err := resolver.Collect(100, collectableTime)

		// then - should succeed
		uassert.NoError(t, err)
		uassert.True(t, withdraw.IsCollected())
		uassert.Equal(t, withdraw.CollectedAmount(), int64(100))
	})

	t.Run("Collect one second before collectable time", func(t *testing.T) {
		// given
		createdAt := int64(1000)
		lockupPeriod := int64(500)
		withdraw := staker.NewDelegationWithdraw(
			1,
			100,
			100,
			createdAt,
			lockupPeriod,
		)
		resolver := NewDelegationWithdrawResolver(withdraw)

		// when - try to collect one second before lockup expires
		collectableTime := createdAt + lockupPeriod
		err := resolver.Collect(100, collectableTime-1)

		// then - should fail
		uassert.ErrorIs(t, err, staker.ErrWithdrawNotCollectable)
		uassert.False(t, withdraw.IsCollected())
	})

	t.Run("Collect with large amount value", func(t *testing.T) {
		// given
		largeAmount := int64(9223372036854775807) // max int64
		withdraw := staker.NewDelegationWithdraw(
			1,
			largeAmount,
			100,
			1000,
			500,
		)
		resolver := NewDelegationWithdrawResolver(withdraw)

		// when - collect large amount
		currentTime := int64(2000)
		err := resolver.Collect(largeAmount, currentTime)

		// then - should succeed
		uassert.NoError(t, err)
		uassert.True(t, withdraw.IsCollected())
		uassert.Equal(t, withdraw.CollectedAmount(), largeAmount)
	})

	t.Run("IsCollectable with negative undelegate amount", func(t *testing.T) {
		// given
		withdraw := staker.NewDelegationWithdraw(
			1,
			-100, // negative amount
			100,
			1000,
			500,
		)
		resolver := NewDelegationWithdrawResolver(withdraw)

		// when
		result := resolver.IsCollectable(2000)

		// then - should not be collectable due to negative amount
		uassert.False(t, result)
	})

	t.Run("CollectableAmount with partial collection", func(t *testing.T) {
		// given
		withdraw := staker.NewDelegationWithdraw(
			1,
			100,
			100,
			1000,
			500,
		)
		resolver := NewDelegationWithdrawResolver(withdraw)

		// when - collect partial amount first
		currentTime := int64(2000)
		_ = resolver.Collect(30, currentTime)
		remainingCollectable := resolver.CollectableAmount(currentTime)

		// then - should have remaining amount minus what was collected
		uassert.Equal(t, remainingCollectable, int64(70))
	})
}

// Test boundary conditions for safe arithmetic in delegation withdraw operations
func TestDelegationWithdraw_BoundaryConditions(t *testing.T) {
	t.Run("CollectableAmount with large amounts near max", func(t *testing.T) {
		// given: withdrawal with very large amount
		withdraw := staker.NewDelegationWithdraw(
			1,
			math.MaxInt64/2,
			100,
			1000,
			500,
		)
		resolver := NewDelegationWithdrawResolver(withdraw)

		// when: calculate collectable amount
		collectable := resolver.CollectableAmount(2000)

		// then: should handle large amount correctly
		uassert.Equal(t, collectable, int64(math.MaxInt64/2))
	})

	t.Run("Collect causing overflow in collected amount", func(t *testing.T) {
		// given: withdrawal at max
		withdraw := staker.NewDelegationWithdraw(
			1,
			math.MaxInt64,
			100,
			1000,
			500,
		)
		resolver := NewDelegationWithdrawResolver(withdraw)

		// when: try to collect amount that would overflow
		didPanic := false
		func() {
			defer func() {
				if r := recover(); r != nil {
					didPanic = true
				}
			}()
			// First collect to near max
			_ = resolver.Collect(math.MaxInt64-1, 2000)
			// This will overflow: (MaxInt64-1) + 2 = MaxInt64+1
			_ = resolver.Collect(2, 2000)
		}()

		// then: should panic on overflow
		uassert.True(t, didPanic)
	})

	t.Run("CollectableAmount subtraction with exact amounts", func(t *testing.T) {
		// given: withdrawal with specific amounts
		undelegateAmount := int64(1000000)
		withdraw := staker.NewDelegationWithdraw(
			1,
			undelegateAmount,
			100,
			1000,
			500,
		)
		resolver := NewDelegationWithdrawResolver(withdraw)

		// when: collect exactly the undelegate amount
		_ = resolver.Collect(undelegateAmount, 2000)
		remaining := resolver.CollectableAmount(2000)

		// then: remaining should be zero (safeSubInt64 result)
		uassert.Equal(t, remaining, int64(0))
	})
}
