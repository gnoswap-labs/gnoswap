package staker

import (
	"std"
	"testing"

	"gno.land/p/demo/uassert"
)

// TestNewDelegationRecord tests the creation of new delegation records
func TestNewDelegationRecord(t *testing.T) {
	tests := []struct {
		name                  string
		delegationType        DelegationType
		delegationAmount      int64
		delegateFrom          std.Address
		delegateTo            std.Address
		createdAt             int64
		expectedDelegateAmount   int64
		expectedUnDelegateAmount int64
	}{
		{
			name:                     "Create delegate record",
			delegationType:           DelegateType,
			delegationAmount:         100,
			delegateFrom:             std.Address("g1from"),
			delegateTo:               std.Address("g1to"),
			createdAt:                1000,
			expectedDelegateAmount:   100,
			expectedUnDelegateAmount: 0,
		},
		{
			name:                     "Create undelegate record",
			delegationType:           UnDelegateType,
			delegationAmount:         50,
			delegateFrom:             std.Address("g1from"),
			delegateTo:               std.Address("g1to"),
			createdAt:                2000,
			expectedDelegateAmount:   0,
			expectedUnDelegateAmount: 50,
		},
	}

	for _, tc := range tests {
		t.Run(tc.name, func(t *testing.T) {
			// when
			record := NewDelegationRecord(
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

// TestNewDelegationDelegateRecordBy tests creating delegate records from delegation
func TestNewDelegationDelegateRecordBy(t *testing.T) {
	tests := []struct {
		name       string
		delegation *Delegation
	}{
		{
			name: "Create delegate record from delegation",
			delegation: &Delegation{
				id:             1,
				delegateAmount: 100,
				delegateFrom:   std.Address("g1from"),
				delegateTo:     std.Address("g1to"),
				createdAt:      1000,
			},
		},
	}

	for _, tc := range tests {
		t.Run(tc.name, func(t *testing.T) {
			// when
			record := NewDelegationDelegateRecordBy(tc.delegation)

			// then
			uassert.NotNil(t, record)
			uassert.Equal(t, record.DelegationType().String(), DelegateType.String())
			uassert.Equal(t, record.DelegateAmount(), tc.delegation.DelegatedAmount())
			uassert.Equal(t, record.DelegateFrom(), tc.delegation.DelegateFrom())
			uassert.Equal(t, record.DelegateTo(), tc.delegation.DelegateTo())
			uassert.Equal(t, record.CreatedAt(), tc.delegation.CreatedAt())
		})
	}
}

// TestNewDelegationWithdrawRecordBy tests creating withdraw records from delegation
func TestNewDelegationWithdrawRecordBy(t *testing.T) {
	tests := []struct {
		name           string
		delegation     *Delegation
		withdrawAmount int64
		currentTime    int64
	}{
		{
			name: "Create withdraw record from delegation",
			delegation: &Delegation{
				id:             1,
				delegateAmount: 100,
				delegateFrom:   std.Address("g1from"),
				delegateTo:     std.Address("g1to"),
				createdAt:      1000,
			},
			withdrawAmount: 50,
			currentTime:    2000,
		},
	}

	for _, tc := range tests {
		t.Run(tc.name, func(t *testing.T) {
			// when
			record := NewDelegationWithdrawRecordBy(
				tc.delegation,
				tc.withdrawAmount,
				tc.currentTime,
			)

			// then
			uassert.NotNil(t, record)
			uassert.Equal(t, record.DelegationType().String(), UnDelegateType.String())
			uassert.Equal(t, record.UnDelegateAmount(), tc.withdrawAmount)
			uassert.Equal(t, record.DelegateFrom(), tc.delegation.DelegateFrom())
			uassert.Equal(t, record.DelegateTo(), tc.delegation.DelegateTo())
			uassert.Equal(t, record.CreatedAt(), tc.currentTime)
		})
	}
}
