package staker

func GetDelegationSnapshots(snapshotTime int64) (DelegationSnapshot, bool) {
	delegationSnapshots := getDelegationSnapshots()
	currentDelegationSnapshot := delegationSnapshots.clone()

	delegationHistory := getDelegationHistory()
	historyRecords := delegationHistory.getRecordsBy(snapshotTime)

	for i := len(historyRecords) - 1; i >= 0; i-- {
		currentDelegationSnapshot = currentDelegationSnapshot.subRecord(historyRecords[i])
	}

	return currentDelegationSnapshot, true
}
