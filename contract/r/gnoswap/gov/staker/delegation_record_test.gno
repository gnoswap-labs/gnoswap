package staker

import (
	"testing"

	"gno.land/p/nt/uassert"
)

// TestDelegationRecord_NewDelegationHistory tests the creation of new delegation history
func TestDelegationRecord_NewDelegationHistory(t *testing.T) {
	// when
	history := NewDelegationHistory()

	// then
	uassert.NotNil(t, history)
	uassert.Equal(t, len(history), 0)
	uassert.Equal(t, len(history.Records()), 0)
}

// TestDelegationRecord_DelegationHistoryOperations tests DelegationHistory operations
func TestDelegationRecord_DelegationHistoryOperations(t *testing.T) {
	tests := []struct {
		name string
	}{
		{
			name: "Add records to history",
		},
	}

	for _, tc := range tests {
		t.Run(tc.name, func(t *testing.T) {
			// given
			history := NewDelegationHistory()
			record1 := NewDelegationRecord(DelegateType, 100, address("g1from"), address("g1to"), 1000)
			record2 := NewDelegationRecord(UnDelegateType, 50, address("g1from"), address("g1to"), 2000)

			// when - add first record
			history = history.AddRecord(record1)

			// then
			uassert.Equal(t, len(history), 1)
			uassert.Equal(t, len(history.Records()), 1)
			uassert.Equal(t, history.Records()[0].DelegateAmount(), int64(100))

			// when - add second record
			history = history.AddRecord(record2)

			// then
			uassert.Equal(t, len(history), 2)
			uassert.Equal(t, len(history.Records()), 2)
			uassert.Equal(t, history.Records()[1].UnDelegateAmount(), int64(50))

			// when - set records
			newRecords := []*DelegationRecord{record1}
			history = history.SetRecords(newRecords)

			// then
			uassert.Equal(t, len(history), 1)
			uassert.Equal(t, len(history.Records()), 1)
		})
	}
}

// TestNewDelegationRecord tests the creation of new delegation records
func TestNewDelegationRecord(t *testing.T) {
	tests := []struct {
		name                     string
		delegationType           DelegationType
		delegationAmount         int64
		delegateFrom             address
		delegateTo               address
		createdAt                int64
		expectedDelegateAmount   int64
		expectedUnDelegateAmount int64
	}{
		{
			name:                     "Create delegate record",
			delegationType:           DelegateType,
			delegationAmount:         100,
			delegateFrom:             address("g1from"),
			delegateTo:               address("g1to"),
			createdAt:                1000,
			expectedDelegateAmount:   100,
			expectedUnDelegateAmount: 0,
		},
		{
			name:                     "Create undelegate record",
			delegationType:           UnDelegateType,
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

// TestNewDelegationWithdrawRecordBy tests creating withdraw records from delegation
func TestNewDelegationWithdrawRecordBy(t *testing.T) {
	tests := []struct {
		name           string
		delegation     *Delegation
		withdrawAmount int64
		currentTime    int64
	}{
		{
			name:           "Create withdraw record from delegation",
			delegation:     NewDelegation(1, address("g1from"), address("g1to"), 100, 1000, 1000),
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

// TestNewDelegationDelegateRecordBy tests creating delegate records from delegation
func TestNewDelegationDelegateRecordBy(t *testing.T) {
	tests := []struct {
		name string
		// delegation *Delegation
		id             int64
		delegateFrom   address
		delegateTo     address
		delegateAmount int64
		createdAt      int64
	}{
		{
			name:           "Create delegate record from delegation",
			id:             1,
			delegateFrom:   address("g1from"),
			delegateTo:     address("g1to"),
			delegateAmount: 100,
			createdAt:      1000,
		},
	}

	for _, tc := range tests {
		t.Run(tc.name, func(t *testing.T) {
			// when
			delegation := NewDelegation(tc.id, tc.delegateFrom, tc.delegateTo, tc.delegateAmount, 1000, tc.createdAt)
			delegationAmount := delegation.TotalDelegatedAmount() - delegation.UnDelegatedAmount()
			record := NewDelegationDelegateRecordBy(delegation, delegationAmount, tc.createdAt)

			// then
			uassert.NotNil(t, record)
			uassert.Equal(t, record.DelegationType().String(), DelegateType.String())
			uassert.Equal(t, record.DelegateAmount(), tc.delegateAmount)
			uassert.Equal(t, record.DelegateFrom(), tc.delegateFrom)
			uassert.Equal(t, record.DelegateTo(), tc.delegateTo)
			uassert.Equal(t, record.CreatedAt(), tc.createdAt)
		})
	}
}
