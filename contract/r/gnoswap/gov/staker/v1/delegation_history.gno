package v1

import (
	"gno.land/r/gnoswap/gov/staker"
)

type DelegationHistoryResolver struct {
	staker.DelegationHistory
}

// getRecordsBy retrieves delegation records that occurred at or after the specified snapshot time.
// This method is used to filter historical records for calculating delegation snapshots at specific points in time.
//
// Parameters:
//   - snapshotTime: timestamp to filter records from (inclusive)
//
// Returns:
//   - DelegationHistory: filtered records occurring at or after snapshotTime
func (dh *DelegationHistoryResolver) getRecordsBy(snapshotTime int64) staker.DelegationHistory {
	records := make(staker.DelegationHistory, 0)

	historyIndex := -1

	// Find the first record at or after the snapshot time
	for index, record := range dh.Records() {
		if record.CreatedAt() >= snapshotTime {
			historyIndex = index
			break
		}
	}

	// If no records found at or after snapshot time, return empty slice
	if historyIndex == -1 {
		return records
	}

	// Return all records from the found index onwards
	records = append(records, dh.Records()[historyIndex:]...)

	return records
}

// addRecord appends a new delegation record to the history.
// This method maintains the chronological order of delegation events.
//
// Parameters:
//   - delegationRecord: the delegation record to add to history
//
// Returns:
//   - DelegationHistory: updated history with the new record appended
func (dh *DelegationHistoryResolver) addRecord(delegationRecord *staker.DelegationRecord) staker.DelegationHistory {
	return dh.AddRecord(delegationRecord)
}

// removeRecordsBy removes historical records that occurred before the specified time.
// This method is used for cleanup operations to remove old historical data.
//
// Parameters:
//   - previousTime: cutoff timestamp for record removal
//
// Returns:
//   - DelegationHistory: filtered history containing only records at or after previousTime
func (dh *DelegationHistoryResolver) removeRecordsBy(previousTime int64) staker.DelegationHistory {
	return dh.getRecordsBy(previousTime)
}

func NewDelegationHistoryResolver(history staker.DelegationHistory) *DelegationHistoryResolver {
	return &DelegationHistoryResolver{
		DelegationHistory: history,
	}
}
