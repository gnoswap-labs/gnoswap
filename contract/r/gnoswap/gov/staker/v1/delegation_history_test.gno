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

// TestNewDelegationHistoryResolver tests the constructor
func TestNewDelegationHistoryResolver(t *testing.T) {
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

// TestDelegationHistory_ErrorCases tests error and boundary cases
func TestDelegationHistory_ErrorCases(t *testing.T) {
	t.Run("getRecordsBy with exact timestamp match", func(t *testing.T) {
		// given
		records := staker.DelegationHistory{
			staker.NewDelegationRecord(staker.DelegateType, 0, address("g1from"), address("g1to"), 100),
			staker.NewDelegationRecord(staker.DelegateType, 0, address("g1from"), address("g1to"), 200),
			staker.NewDelegationRecord(staker.DelegateType, 0, address("g1from"), address("g1to"), 300),
		}
		resolver := NewDelegationHistoryResolver(records)

		// when - exact match on timestamp
		result := resolver.getRecordsBy(200)

		// then - should include the exact match and all after
		uassert.Equal(t, len(result), 2)
	})

	t.Run("addRecord multiple times", func(t *testing.T) {
		// given
		history := staker.DelegationHistory{}
		resolver := NewDelegationHistoryResolver(history)

		// when - add multiple records
		history = resolver.addRecord(staker.NewDelegationRecord(staker.DelegateType, 0, address("g1from"), address("g1to"), 100))
		resolver = NewDelegationHistoryResolver(history)
		history = resolver.addRecord(staker.NewDelegationRecord(staker.UnDelegateType, 0, address("g1from"), address("g1to"), 200))
		resolver = NewDelegationHistoryResolver(history)
		history = resolver.addRecord(staker.NewDelegationRecord(staker.DelegateType, 0, address("g1from"), address("g1to"), 300))

		// then - should have all records
		uassert.Equal(t, len(history), 3)
	})

	t.Run("removeRecordsBy with negative time", func(t *testing.T) {
		// given
		records := staker.DelegationHistory{
			staker.NewDelegationRecord(staker.DelegateType, 0, address("g1from"), address("g1to"), 100),
			staker.NewDelegationRecord(staker.DelegateType, 0, address("g1from"), address("g1to"), 200),
		}
		resolver := NewDelegationHistoryResolver(records)

		// when - remove with negative time
		result := resolver.removeRecordsBy(-100)

		// then - should return all records (all are after negative time)
		uassert.Equal(t, len(result), 2)
	})

	t.Run("getRecordsBy with very large timestamp", func(t *testing.T) {
		// given
		records := staker.DelegationHistory{
			staker.NewDelegationRecord(staker.DelegateType, 0, address("g1from"), address("g1to"), 100),
			staker.NewDelegationRecord(staker.DelegateType, 0, address("g1from"), address("g1to"), 200),
		}
		resolver := NewDelegationHistoryResolver(records)

		// when - get records with very large timestamp
		maxInt64 := int64(9223372036854775807)
		result := resolver.getRecordsBy(maxInt64)

		// then - should return empty (no records after max timestamp)
		uassert.Equal(t, len(result), 0)
	})

	t.Run("addRecord with different delegation types", func(t *testing.T) {
		// given
		history := staker.DelegationHistory{}
		resolver := NewDelegationHistoryResolver(history)

		// when - add different types of records
		history = resolver.addRecord(staker.NewDelegationRecord(staker.DelegateType, 0, address("g1from"), address("g1to"), 100))
		resolver = NewDelegationHistoryResolver(history)
		history = resolver.addRecord(staker.NewDelegationRecord(staker.UnDelegateType, 0, address("g1from"), address("g1to"), 200))
		resolver = NewDelegationHistoryResolver(history)
		history = resolver.addRecord(staker.NewDelegationRecord(staker.DelegateType, 0, address("g1from2"), address("g1to2"), 300))

		// then - should have all records
		uassert.Equal(t, len(history), 3)
	})

	t.Run("removeRecordsBy boundary - remove exactly at first record time", func(t *testing.T) {
		// given
		records := staker.DelegationHistory{
			staker.NewDelegationRecord(staker.DelegateType, 0, address("g1from"), address("g1to"), 100),
			staker.NewDelegationRecord(staker.DelegateType, 0, address("g1from"), address("g1to"), 200),
			staker.NewDelegationRecord(staker.DelegateType, 0, address("g1from"), address("g1to"), 300),
		}
		resolver := NewDelegationHistoryResolver(records)

		// when - remove at exact time of first record
		result := resolver.removeRecordsBy(100)

		// then - should keep all records (inclusive)
		uassert.Equal(t, len(result), 3)
	})
}
