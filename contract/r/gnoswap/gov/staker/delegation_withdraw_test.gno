package staker

import (
	"testing"

	"gno.land/p/nt/uassert"
)

// TestNewDelegationWithdraw tests creating withdrawal with lockup period
func TestNewDelegationWithdraw(t *testing.T) {
	tests := []struct {
		name                     string
		delegationID             int64
		unDelegateAmount         int64
		createdHeight            int64
		createdAt                int64
		unDelegationLockupPeriod int64
		expectedCollectableTime  int64
		expectedCollected        bool
	}{
		{
			name:                     "Create with standard lockup period",
			delegationID:             1,
			unDelegateAmount:         1000,
			createdHeight:            100,
			createdAt:                1000000,
			unDelegationLockupPeriod: 86400,
			expectedCollectableTime:  1086400,
			expectedCollected:        false,
		},
		{
			name:                     "Create with zero lockup period",
			delegationID:             2,
			unDelegateAmount:         500,
			createdHeight:            200,
			createdAt:                2000000,
			unDelegationLockupPeriod: 0,
			expectedCollectableTime:  2000000,
			expectedCollected:        false,
		},
	}

	for _, tc := range tests {
		t.Run(tc.name, func(t *testing.T) {
			// when
			withdraw := NewDelegationWithdraw(
				tc.delegationID,
				tc.unDelegateAmount,
				tc.createdHeight,
				tc.createdAt,
				tc.unDelegationLockupPeriod,
			)

			// then
			uassert.NotNil(t, withdraw)
			uassert.Equal(t, withdraw.DelegationID(), tc.delegationID)
			uassert.Equal(t, withdraw.UnDelegateAmount(), tc.unDelegateAmount)
			uassert.Equal(t, withdraw.UnDelegatedHeight(), tc.createdHeight)
			uassert.Equal(t, withdraw.UnDelegatedAt(), tc.createdAt)
			uassert.Equal(t, withdraw.CollectableTime(), tc.expectedCollectableTime)
			uassert.Equal(t, withdraw.CollectedAmount(), int64(0))
			uassert.Equal(t, withdraw.CollectedAt(), int64(0))
			uassert.Equal(t, withdraw.IsCollected(), tc.expectedCollected)
		})
	}
}

// TestNewDelegationWithdrawWithoutLockup tests creating withdrawal without lockup
func TestNewDelegationWithdrawWithoutLockup(t *testing.T) {
	tests := []struct {
		name             string
		delegationID     int64
		unDelegateAmount int64
		createdHeight    int64
		createdAt        int64
	}{
		{
			name:             "Create without lockup",
			delegationID:     1,
			unDelegateAmount: 1000,
			createdHeight:    100,
			createdAt:        1000000,
		},
		{
			name:             "Create with zero amount",
			delegationID:     2,
			unDelegateAmount: 0,
			createdHeight:    200,
			createdAt:        2000000,
		},
	}

	for _, tc := range tests {
		t.Run(tc.name, func(t *testing.T) {
			// when
			withdraw := NewDelegationWithdrawWithoutLockup(
				tc.delegationID,
				tc.unDelegateAmount,
				tc.createdHeight,
				tc.createdAt,
			)

			// then
			uassert.NotNil(t, withdraw)
			uassert.Equal(t, withdraw.DelegationID(), tc.delegationID)
			uassert.Equal(t, withdraw.UnDelegateAmount(), tc.unDelegateAmount)
			uassert.Equal(t, withdraw.UnDelegatedHeight(), tc.createdHeight)
			uassert.Equal(t, withdraw.UnDelegatedAt(), tc.createdAt)
			uassert.Equal(t, withdraw.CollectableTime(), tc.createdAt)
			uassert.Equal(t, withdraw.CollectedAmount(), tc.unDelegateAmount) // Immediately collected
			uassert.Equal(t, withdraw.CollectedAt(), tc.createdAt)
			uassert.True(t, withdraw.IsCollected())
		})
	}
}

// TestDelegationWithdraw_Setters tests setter methods
func TestDelegationWithdraw_Setters(t *testing.T) {
	tests := []struct {
		name              string
		initialAmount     int64
		newCollectedAmt   int64
		newCollectedAt    int64
		newCollectedState bool
	}{
		{
			name:              "Set collected amount and time",
			initialAmount:     1000,
			newCollectedAmt:   500,
			newCollectedAt:    2000000,
			newCollectedState: false,
		},
		{
			name:              "Set full collection",
			initialAmount:     1000,
			newCollectedAmt:   1000,
			newCollectedAt:    3000000,
			newCollectedState: true,
		},
	}

	for _, tc := range tests {
		t.Run(tc.name, func(t *testing.T) {
			// given
			withdraw := NewDelegationWithdraw(1, tc.initialAmount, 100, 1000000, 86400)

			// when
			withdraw.SetCollectedAmount(tc.newCollectedAmt)
			withdraw.SetCollectedAt(tc.newCollectedAt)
			withdraw.SetCollected(tc.newCollectedState)

			// then
			uassert.Equal(t, withdraw.CollectedAmount(), tc.newCollectedAmt)
			uassert.Equal(t, withdraw.CollectedAt(), tc.newCollectedAt)
			uassert.Equal(t, withdraw.IsCollected(), tc.newCollectedState)
		})
	}
}

// TestDelegationWithdraw_Getters tests all getter methods
func TestDelegationWithdraw_Getters(t *testing.T) {
	tests := []struct {
		name                     string
		delegationID             int64
		unDelegateAmount         int64
		createdHeight            int64
		createdAt                int64
		unDelegationLockupPeriod int64
	}{
		{
			name:                     "Get all values",
			delegationID:             123,
			unDelegateAmount:         5000,
			createdHeight:            500,
			createdAt:                5000000,
			unDelegationLockupPeriod: 172800,
		},
	}

	for _, tc := range tests {
		t.Run(tc.name, func(t *testing.T) {
			// given
			withdraw := NewDelegationWithdraw(
				tc.delegationID,
				tc.unDelegateAmount,
				tc.createdHeight,
				tc.createdAt,
				tc.unDelegationLockupPeriod,
			)

			// when & then
			uassert.Equal(t, withdraw.DelegationID(), tc.delegationID)
			uassert.Equal(t, withdraw.UnDelegateAmount(), tc.unDelegateAmount)
			uassert.Equal(t, withdraw.UnDelegatedHeight(), tc.createdHeight)
			uassert.Equal(t, withdraw.UnDelegatedAt(), tc.createdAt)
			uassert.Equal(t, withdraw.CollectableTime(), tc.createdAt+tc.unDelegationLockupPeriod)
			uassert.Equal(t, withdraw.CollectedAmount(), int64(0))
			uassert.Equal(t, withdraw.CollectedAt(), int64(0))
			uassert.False(t, withdraw.IsCollected())
		})
	}
}
