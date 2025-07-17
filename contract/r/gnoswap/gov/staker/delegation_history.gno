package staker

type DelegationHistory []*DelegationRecord

func (dh DelegationHistory) getRecordsBy(snapshotTime int64) DelegationHistory {
	records := make(DelegationHistory, 0)

	historyIndex := -1

	for index, record := range dh {
		if record.CreatedAt() >= snapshotTime {
			historyIndex = index
			break
		}
	}

	if historyIndex == -1 {
		return records
	}

	records = append(records, dh[historyIndex:]...)
	
	return records
}

func (dh DelegationHistory) addRecord(delegationRecord *DelegationRecord) DelegationHistory {
	return append(dh, delegationRecord)
}

func (dh DelegationHistory) removeRecordsBy(previousTime int64) DelegationHistory {
	currentRecords := dh.getRecordsBy(previousTime)

	return currentRecords
}
