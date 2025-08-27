package staker

import (
	"std"
	"time"

	"gno.land/r/gnoswap/access"
	"gno.land/r/gnoswap/halt"
)

// CleanStakerDelegationSnapshotByAdmin cleans old delegation history records.
// This administrative function removes delegation history records older than the specified threshold
// to prevent unlimited growth of historical data and optimize storage usage.
//
// The cleanup process:
// 1. Calculates cutoff time by subtracting threshold from current time
// 2. Filters delegation history to keep only records after cutoff time
// 3. Updates the delegation history with filtered records
//
// Parameters:
//   - cur: realm context for cross-realm calls
//   - threshold: time threshold in seconds (records older than this will be removed)
//
// Panics:
//   - if caller is not admin
//
// Note: This operation is irreversible and will permanently remove historical data
func CleanStakerDelegationSnapshotByAdmin(cur realm, threshold int64) {
	halt.AssertIsNotHaltedGovStaker()

	caller := std.PreviousRealm().Address()
	access.AssertIsAdminOrGovernance(caller)

	// Calculate cutoff time by subtracting threshold from current time
	cutoffTimestamp := time.Now().Unix() - threshold

	// Filter records after cutoff time
	delegationHistory := getDelegationHistory()
	recentDelegationHistory := delegationHistory.getRecordsBy(cutoffTimestamp)

	// Update delegation history with filtered records
	setDelegationHistory(recentDelegationHistory)
}

// SetUnDelegationLockupPeriodByAdmin sets the undelegation lockup period.
// This administrative function configures the time period that undelegated tokens
// must wait before they can be collected by users.
//
// The lockup period serves as a security mechanism to:
// - Prevent rapid delegation/undelegation cycles
// - Provide time for governance decisions to take effect
// - Maintain system stability during volatile periods
//
// Parameters:
//   - cur: realm context for cross-realm calls
//   - period: lockup period in seconds (must be non-negative)
//
// Panics:
//   - if caller is not admin
//   - if period is negative
//
// Note: This change affects all future undelegation operations
func SetUnDelegationLockupPeriodByAdmin(cur realm, period int64) {
	halt.AssertIsNotHaltedGovStaker()

	caller := std.PreviousRealm().Address()
	access.AssertIsAdminOrGovernance(caller)

	if period < 0 {
		panic("period must be greater than 0")
	}

	setUnDelegationLockupPeriod(period)

	previousRealm := std.PreviousRealm()
	std.Emit(
		"SetUnDelegationLockupPeriod",
		"prevAddr", previousRealm.Address().String(),
		"prevRealm", previousRealm.PkgPath(),
		"period", formatInt(period),
	)
}
