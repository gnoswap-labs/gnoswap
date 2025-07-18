package staker

import (
	"std"
	"testing"

	"gno.land/p/demo/uassert"
)

// TestDelegationHistory_GetRecordsBy tests filtering records by snapshot time
func TestDelegationHistory_GetRecordsBy(t *testing.T) {
	tests := []struct {
		name          string
		records       DelegationHistory
		snapshotTime  int64
		expectedCount int
	}{
		{
			name: "Get records after snapshot time",
			records: DelegationHistory{
				&DelegationRecord{createdAt: 100},
				&DelegationRecord{createdAt: 200},
				&DelegationRecord{createdAt: 300},
			},
			snapshotTime:  150,
			expectedCount: 2,
		},
		{
			name: "Get all records when snapshot time is before all",
			records: DelegationHistory{
				&DelegationRecord{createdAt: 100},
				&DelegationRecord{createdAt: 200},
			},
			snapshotTime:  50,
			expectedCount: 2,
		},
		{
			name: "Get no records when snapshot time is after all",
			records: DelegationHistory{
				&DelegationRecord{createdAt: 100},
				&DelegationRecord{createdAt: 200},
			},
			snapshotTime:  300,
			expectedCount: 0,
		},
		{
			name:          "Empty history",
			records:       DelegationHistory{},
			snapshotTime:  100,
			expectedCount: 0,
		},
	}

	for _, tc := range tests {
		t.Run(tc.name, func(t *testing.T) {
			// when
			result := tc.records.getRecordsBy(tc.snapshotTime)

			// then
			uassert.Equal(t, len(result), tc.expectedCount)
		})
	}
}

// TestDelegationHistory_AddRecord tests adding records to history
func TestDelegationHistory_AddRecord(t *testing.T) {
	tests := []struct {
		name           string
		initialRecords DelegationHistory
		newRecord      *DelegationRecord
		expectedCount  int
	}{
		{
			name:           "Add record to empty history",
			initialRecords: DelegationHistory{},
			newRecord: &DelegationRecord{
				delegationType: DelegateType,
				delegateFrom:   std.Address("g1from"),
				delegateTo:     std.Address("g1to"),
				createdAt:      100,
			},
			expectedCount: 1,
		},
		{
			name: "Add record to existing history",
			initialRecords: DelegationHistory{
				&DelegationRecord{createdAt: 100},
			},
			newRecord: &DelegationRecord{
				delegationType: UnDelegateType,
				delegateFrom:   std.Address("g1from"),
				delegateTo:     std.Address("g1to"),
				createdAt:      200,
			},
			expectedCount: 2,
		},
	}

	for _, tc := range tests {
		t.Run(tc.name, func(t *testing.T) {
			// given
			history := tc.initialRecords

			// when
			history = history.addRecord(tc.newRecord)

			// then
			uassert.Equal(t, len(history), tc.expectedCount)
		})
	}
}

// TestDelegationHistory_RemoveRecordsBy tests removing records by time
func TestDelegationHistory_RemoveRecordsBy(t *testing.T) {
	tests := []struct {
		name           string
		initialRecords DelegationHistory
		previousTime   int64
		expectedCount  int
	}{
		{
			name: "Remove old records",
			initialRecords: DelegationHistory{
				&DelegationRecord{createdAt: 100},
				&DelegationRecord{createdAt: 200},
				&DelegationRecord{createdAt: 300},
			},
			previousTime:  150,
			expectedCount: 2,
		},
		{
			name: "Remove all records",
			initialRecords: DelegationHistory{
				&DelegationRecord{createdAt: 100},
				&DelegationRecord{createdAt: 200},
			},
			previousTime:  50,
			expectedCount: 2,
		},
		{
			name: "Remove no records",
			initialRecords: DelegationHistory{
				&DelegationRecord{createdAt: 100},
				&DelegationRecord{createdAt: 200},
			},
			previousTime:  300,
			expectedCount: 0,
		},
	}

	for _, tc := range tests {
		t.Run(tc.name, func(t *testing.T) {
			// given
			history := tc.initialRecords

			// when
			history = history.removeRecordsBy(tc.previousTime)

			// then
			uassert.Equal(t, len(history), tc.expectedCount)
		})
	}
}
