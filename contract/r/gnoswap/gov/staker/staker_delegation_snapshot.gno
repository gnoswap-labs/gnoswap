// TODO: Change file name

package staker

import (
	"std"
	"time"
)

// CleanStakerDelegationSnapshotByAdmin cleans staker delegation snapshot
func CleanStakerDelegationSnapshotByAdmin(cur realm, threshold int64) {
	caller := std.PreviousRealm().Address()
	assertCallerIsAdmin(caller)

	// Calculate cutoff time by subtracting threshold from current time
	cutoffTimestamp := time.Now().Unix() - threshold

	// Filter records after cutoff time
	delegationHistory := getDelegationHistory()
	recentDelegationHistory := delegationHistory.getRecordsBy(cutoffTimestamp)
	
	// Update delegation history with filtered records
	setDelegationHistory(recentDelegationHistory)
}

func SetUnDelegationLockupPeriodByAdmin(cur realm, period int64) {
	caller := std.PreviousRealm().Address()
	assertCallerIsAdmin(caller)

	if period < 0 {
		panic("period must be greater than 0")
	}

	setUnDelegationLockupPeriod(period)
}
