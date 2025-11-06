package v1

import (
	"testing"

	"gno.land/p/nt/uassert"
	"gno.land/r/gnoswap/gov/staker"
)

// TestDelegationHistory_GetRecordsBy tests filtering records by snapshot time
func TestDelegationHistory_GetRecordsBy(t *testing.T) {
	tests := []struct {
		name          string
		records       staker.DelegationHistory
		snapshotTime  int64
		expectedCount int
	}{
		{
			name: "Get records after snapshot time",
			records: staker.DelegationHistory{
				staker.NewDelegationRecord(staker.DelegateType, 0, address("g1from"), address("g1to"), 100),
				staker.NewDelegationRecord(staker.DelegateType, 0, address("g1from"), address("g1to"), 200),
				staker.NewDelegationRecord(staker.DelegateType, 0, address("g1from"), address("g1to"), 300),
			},
			snapshotTime:  150,
			expectedCount: 2,
		},
		{
			name: "Get all records when snapshot time is before all",
			records: staker.DelegationHistory{
				staker.NewDelegationRecord(staker.DelegateType, 0, address("g1from"), address("g1to"), 100),
				staker.NewDelegationRecord(staker.DelegateType, 0, address("g1from"), address("g1to"), 200),
			},
			snapshotTime:  50,
			expectedCount: 2,
		},
		{
			name: "Get no records when snapshot time is after all",
			records: staker.DelegationHistory{
				staker.NewDelegationRecord(staker.DelegateType, 0, address("g1from"), address("g1to"), 100),
				staker.NewDelegationRecord(staker.DelegateType, 0, address("g1from"), address("g1to"), 200),
			},
			snapshotTime:  300,
			expectedCount: 0,
		},
		{
			name:          "Empty history",
			records:       staker.DelegationHistory{},
			snapshotTime:  100,
			expectedCount: 0,
		},
		{
			name: "Exact timestamp match",
			records: staker.DelegationHistory{
				staker.NewDelegationRecord(staker.DelegateType, 0, address("g1from"), address("g1to"), 100),
				staker.NewDelegationRecord(staker.DelegateType, 0, address("g1from"), address("g1to"), 200),
				staker.NewDelegationRecord(staker.DelegateType, 0, address("g1from"), address("g1to"), 300),
			},
			snapshotTime:  200,
			expectedCount: 2, // Should include the exact match and all after
		},
		{
			name: "Very large timestamp",
			records: staker.DelegationHistory{
				staker.NewDelegationRecord(staker.DelegateType, 0, address("g1from"), address("g1to"), 100),
				staker.NewDelegationRecord(staker.DelegateType, 0, address("g1from"), address("g1to"), 200),
			},
			snapshotTime:  9223372036854775807, // max int64
			expectedCount: 0,                   // No records after max timestamp
		},
	}

	for _, tc := range tests {
		t.Run(tc.name, func(t *testing.T) {
			historyResolver := NewDelegationHistoryResolver(tc.records)
			// when
			result := historyResolver.getRecordsBy(tc.snapshotTime)

			// then
			uassert.Equal(t, len(result), tc.expectedCount)
		})
	}
}

// TestDelegationHistory_AddRecord tests adding records to history
func TestDelegationHistory_AddRecord(t *testing.T) {
	tests := []struct {
		name           string
		initialRecords staker.DelegationHistory
		newRecord      *staker.DelegationRecord
		expectedCount  int
	}{
		{
			name:           "Add record to empty history",
			initialRecords: staker.DelegationHistory{},
			newRecord: staker.NewDelegationRecord(
				staker.DelegateType,
				0,
				address("g1from"),
				address("g1to"),
				100,
			),
			expectedCount: 1,
		},
		{
			name: "Add record to existing history",
			initialRecords: staker.DelegationHistory{
				staker.NewDelegationRecord(staker.DelegateType, 0, address("g1from"), address("g1to"), 100),
			},
			newRecord: staker.NewDelegationRecord(
				staker.UnDelegateType,
				0,
				address("g1from"),
				address("g1to"),
				200,
			),
			expectedCount: 2,
		},
		{
			name:           "Add multiple records sequentially",
			initialRecords: staker.DelegationHistory{},
			newRecord: staker.NewDelegationRecord(
				staker.DelegateType,
				0,
				address("g1from"),
				address("g1to"),
				100,
			),
			expectedCount: 1,
		},
		{
			name: "Add records with different delegation types",
			initialRecords: staker.DelegationHistory{
				staker.NewDelegationRecord(staker.DelegateType, 0, address("g1from"), address("g1to"), 100),
			},
			newRecord: staker.NewDelegationRecord(
				staker.UnDelegateType,
				0,
				address("g1from"),
				address("g1to"),
				200,
			),
			expectedCount: 2,
		},
	}

	for _, tc := range tests {
		t.Run(tc.name, func(t *testing.T) {
			// given
			history := tc.initialRecords
			historyResolver := NewDelegationHistoryResolver(history)

			// when
			history = historyResolver.addRecord(tc.newRecord)

			// then
			uassert.Equal(t, len(history), tc.expectedCount)
		})
	}
}

// TestDelegationHistory_RemoveRecordsBy tests removing records by time
func TestDelegationHistory_RemoveRecordsBy(t *testing.T) {
	tests := []struct {
		name           string
		initialRecords staker.DelegationHistory
		previousTime   int64
		expectedCount  int
	}{
		{
			name: "Remove old records",
			initialRecords: staker.DelegationHistory{
				staker.NewDelegationRecord(staker.DelegateType, 0, address("g1from"), address("g1to"), 100),
				staker.NewDelegationRecord(staker.DelegateType, 0, address("g1from"), address("g1to"), 200),
				staker.NewDelegationRecord(staker.DelegateType, 0, address("g1from"), address("g1to"), 300),
			},
			previousTime:  150,
			expectedCount: 2,
		},
		{
			name: "Remove all records",
			initialRecords: staker.DelegationHistory{
				staker.NewDelegationRecord(staker.DelegateType, 0, address("g1from"), address("g1to"), 100),
				staker.NewDelegationRecord(staker.DelegateType, 0, address("g1from"), address("g1to"), 200),
			},
			previousTime:  50,
			expectedCount: 2,
		},
		{
			name: "Remove no records",
			initialRecords: staker.DelegationHistory{
				staker.NewDelegationRecord(staker.DelegateType, 0, address("g1from"), address("g1to"), 100),
				staker.NewDelegationRecord(staker.DelegateType, 0, address("g1from"), address("g1to"), 200),
			},
			previousTime:  300,
			expectedCount: 0,
		},
		{
			name: "Remove with negative time",
			initialRecords: staker.DelegationHistory{
				staker.NewDelegationRecord(staker.DelegateType, 0, address("g1from"), address("g1to"), 100),
				staker.NewDelegationRecord(staker.DelegateType, 0, address("g1from"), address("g1to"), 200),
			},
			previousTime:  -100,
			expectedCount: 2, // All records are after negative time
		},
		{
			name: "Remove at exact first record time (boundary)",
			initialRecords: staker.DelegationHistory{
				staker.NewDelegationRecord(staker.DelegateType, 0, address("g1from"), address("g1to"), 100),
				staker.NewDelegationRecord(staker.DelegateType, 0, address("g1from"), address("g1to"), 200),
				staker.NewDelegationRecord(staker.DelegateType, 0, address("g1from"), address("g1to"), 300),
			},
			previousTime:  100,
			expectedCount: 3, // Should keep all records (inclusive)
		},
	}

	for _, tc := range tests {
		t.Run(tc.name, func(t *testing.T) {
			// given
			history := tc.initialRecords
			historyResolver := NewDelegationHistoryResolver(history)

			// when
			history = historyResolver.removeRecordsBy(tc.previousTime)

			// then
			uassert.Equal(t, len(history), tc.expectedCount)
		})
	}
}

// TestDelegationHistory_NewDelegationHistoryResolver tests the constructor
func TestDelegationHistory_NewDelegationHistoryResolver(t *testing.T) {
	tests := []struct {
		name    string
		history staker.DelegationHistory
	}{
		{
			name:    "Create with empty history",
			history: staker.DelegationHistory{},
		},
		{
			name: "Create with existing records",
			history: staker.DelegationHistory{
				staker.NewDelegationRecord(staker.DelegateType, 0, address("g1from"), address("g1to"), 100),
				staker.NewDelegationRecord(staker.UnDelegateType, 0, address("g1from"), address("g1to"), 200),
			},
		},
	}

	for _, tc := range tests {
		t.Run(tc.name, func(t *testing.T) {
			// when
			resolver := NewDelegationHistoryResolver(tc.history)

			// then
			uassert.NotNil(t, resolver)
			uassert.Equal(t, len(resolver.Records()), len(tc.history))
		})
	}
}

