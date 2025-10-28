package v1

import (
	"testing"

	"gno.land/p/nt/uassert"
	"gno.land/r/gnoswap/gov/staker"
)

// TestNewDelegationRecord tests the creation of new delegation records
func TestNewDelegationRecord(t *testing.T) {
	tests := []struct {
		name                     string
		delegationType           staker.DelegationType
		delegationAmount         int64
		delegateFrom             address
		delegateTo               address
		createdAt                int64
		expectedDelegateAmount   int64
		expectedUnDelegateAmount int64
	}{
		{
			name:                     "Create delegate record",
			delegationType:           staker.DelegateType,
			delegationAmount:         100,
			delegateFrom:             address("g1from"),
			delegateTo:               address("g1to"),
			createdAt:                1000,
			expectedDelegateAmount:   100,
			expectedUnDelegateAmount: 0,
		},
		{
			name:                     "Create undelegate record",
			delegationType:           staker.UnDelegateType,
			delegationAmount:         50,
			delegateFrom:             address("g1from"),
			delegateTo:               address("g1to"),
			createdAt:                2000,
			expectedDelegateAmount:   0,
			expectedUnDelegateAmount: 50,
		},
	}

	for _, tc := range tests {
		t.Run(tc.name, func(t *testing.T) {
			// when
			record := staker.NewDelegationRecord(
				tc.delegationType,
				tc.delegationAmount,
				tc.delegateFrom,
				tc.delegateTo,
				tc.createdAt,
			)

			// then
			uassert.NotNil(t, record)
			uassert.Equal(t, record.DelegationType().String(), tc.delegationType.String())
			uassert.Equal(t, record.DelegateAmount(), tc.expectedDelegateAmount)
			uassert.Equal(t, record.UnDelegateAmount(), tc.expectedUnDelegateAmount)
			uassert.Equal(t, record.DelegateFrom(), tc.delegateFrom)
			uassert.Equal(t, record.DelegateTo(), tc.delegateTo)
			uassert.Equal(t, record.CreatedAt(), tc.createdAt)
		})
	}
}

// TestNewDelegationWithdrawRecordBy tests creating withdraw records from delegation
func TestNewDelegationWithdrawRecordBy(t *testing.T) {
	tests := []struct {
		name           string
		delegation     *staker.Delegation
		withdrawAmount int64
		currentTime    int64
	}{
		{
			name: "Create withdraw record from delegation",
			delegation: NewDelegation(1, address("g1from"), address("g1to"), 100, 1000, 1000),
			withdrawAmount: 50,
			currentTime:    2000,
		},
	}

	for _, tc := range tests {
		t.Run(tc.name, func(t *testing.T) {
			// when
			record := staker.NewDelegationWithdrawRecordBy(
				tc.delegation,
				tc.withdrawAmount,
				tc.currentTime,
			)

			// then
			uassert.NotNil(t, record)
			uassert.Equal(t, record.DelegationType().String(), staker.UnDelegateType.String())
			uassert.Equal(t, record.UnDelegateAmount(), tc.withdrawAmount)
			uassert.Equal(t, record.DelegateFrom(), tc.delegation.DelegateFrom())
			uassert.Equal(t, record.DelegateTo(), tc.delegation.DelegateTo())
			uassert.Equal(t, record.CreatedAt(), tc.currentTime)
		})
	}
}
