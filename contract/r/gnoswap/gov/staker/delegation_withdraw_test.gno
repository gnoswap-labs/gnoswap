package staker

import (
	"testing"

	"gno.land/p/demo/uassert"
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
				tc.unDelegationLockupPeriod,
			)

			// then
			uassert.Equal(t, withdraw.DelegationID(), tc.delegationID)
			uassert.Equal(t, withdraw.UnDelegateAmount(), tc.unDelegateAmount)
			uassert.Equal(t, withdraw.UnDelegatedAt(), tc.createdAt)
			uassert.Equal(t, withdraw.collectableTime, tc.expectedCollectableTime)
			uassert.Equal(t, withdraw.IsCollected(), tc.expectedCollected)
			uassert.Equal(t, withdraw.CollectableAmount(tc.currentTime), tc.unDelegateAmount)
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
			)

			// then
			uassert.Equal(t, withdraw.DelegationID(), tc.delegationID)
			uassert.Equal(t, withdraw.UnDelegateAmount(), tc.unDelegateAmount)
			uassert.Equal(t, withdraw.UnDelegatedAt(), tc.createdAt)
			uassert.Equal(t, withdraw.collectableTime, tc.createdAt)
			uassert.True(t, withdraw.IsCollected())
			uassert.Equal(t, withdraw.CollectableAmount(tc.currentTime), int64(0))
		})
	}
}

// TestDelegationWithdraw_IsCollectable tests the collectable status
func TestDelegationWithdraw_IsCollectable(t *testing.T) {
	tests := []struct {
		name               string
		withdraw           *DelegationWithdraw
		currentTime        int64
		expectedCollectable bool
	}{
		{
			name: "Collectable after lockup period",
			withdraw: &DelegationWithdraw{
				unDelegateAmount: 100,
				unDelegatedAt:    1000,
				collectableTime:  1500,
				collected:        false,
				collectedAmount:  0,
			},
			currentTime:         2000,
			expectedCollectable: true,
		},
		{
			name: "Not collectable before lockup period",
			withdraw: &DelegationWithdraw{
				unDelegateAmount: 100,
				unDelegatedAt:    1000,
				collectableTime:  1500,
				collected:        false,
				collectedAmount:  0,
			},
			currentTime:         1200,
			expectedCollectable: false,
		},
		{
			name: "Not collectable if already collected",
			withdraw: &DelegationWithdraw{
				unDelegateAmount: 100,
				unDelegatedAt:    1000,
				collectableTime:  1500,
				collected:        true,
				collectedAmount:  100,
			},
			currentTime:         2000,
			expectedCollectable: false,
		},
		{
			name: "Not collectable if no amount to collect",
			withdraw: &DelegationWithdraw{
				unDelegateAmount: 0,
				unDelegatedAt:    1000,
				collectableTime:  1500,
				collected:        false,
				collectedAmount:  0,
			},
			currentTime:         2000,
			expectedCollectable: false,
		},
	}

	for _, tc := range tests {
		t.Run(tc.name, func(t *testing.T) {
			// when
			result := tc.withdraw.IsCollectable(tc.currentTime)

			// then
			uassert.Equal(t, result, tc.expectedCollectable)
		})
	}
}

// TestDelegationWithdraw_Collect tests the collection functionality
func TestDelegationWithdraw_Collect(t *testing.T) {
	tests := []struct {
		name                string
		withdraw            *DelegationWithdraw
		collectAmount       int64
		currentTime         int64
		expectedError       error
		expectedCollected   bool
		expectedCollectedAmount int64
	}{
		{
			name: "Successful collection",
			withdraw: &DelegationWithdraw{
				unDelegateAmount: 100,
				collected:        false,
				collectedAmount:  0,
			},
			collectAmount:           100,
			currentTime:             2000,
			expectedError:           nil,
			expectedCollected:       true,
			expectedCollectedAmount: 100,
		},
		{
			name: "Cannot collect if no amount",
			withdraw: &DelegationWithdraw{
				unDelegateAmount: 0,
				collected:        false,
				collectedAmount:  0,
			},
			collectAmount: 50,
			currentTime:   2000,
			expectedError: errInvalidAmount,
		},
		{
			name: "Cannot collect if already collected",
			withdraw: &DelegationWithdraw{
				unDelegateAmount: 100,
				collected:        true,
				collectedAmount:  100,
			},
			collectAmount: 50,
			currentTime:   2000,
			expectedError: errInvalidAmount,
		},
	}

	for _, tc := range tests {
		t.Run(tc.name, func(t *testing.T) {
			// when
			err := tc.withdraw.collect(tc.collectAmount, tc.currentTime)

			// then
			if tc.expectedError != nil {
				uassert.ErrorIs(t, err, tc.expectedError)
			} else {
				uassert.Equal(t, tc.withdraw.IsCollected(), tc.expectedCollected)
				uassert.Equal(t, tc.withdraw.collectedAmount, tc.expectedCollectedAmount)
				uassert.Equal(t, tc.withdraw.collectedAt, tc.currentTime)
			}
		})
	}
} 