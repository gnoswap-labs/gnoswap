package v1

import (
	"time"

	"gno.land/p/nt/ufmt"

	"gno.land/r/gnoswap/gov/governance"
)

// assertIsValidDelegateAmount validates that the delegation amount meets system requirements.
// This function checks minimum amount and multiple requirements.
//
// Parameters:
//   - amount: amount to validate
//
// Returns:
//   - error: nil if valid, error describing validation failure
func assertIsValidDelegateAmount(amount int64) {
	if amount < minimumAmount {
		panic(makeErrorWithDetails(
			errLessThanMinimum,
			ufmt.Sprintf("minimum amount to delegate is %d (requested:%d)", minimumAmount, amount),
		))
	}

	if amount%minimumAmount != 0 {
		panic(makeErrorWithDetails(
			errInvalidAmount,
			ufmt.Sprintf("amount must be multiple of %d", minimumAmount),
		))
	}
}

func assertIsValidSnapshotTime(snapshotTime int64) {
	if snapshotTime < 0 {
		panic(makeErrorWithDetails(
			errInvalidSnapshotTime,
			ufmt.Sprintf("snapshot time must be greater than 0 (requested:%d)", snapshotTime),
		))
	}

	currentTime := time.Now().Unix()
	maxSmoothingPeriod := governance.GetMaxSmoothingPeriod()

	if snapshotTime > currentTime-maxSmoothingPeriod {
		panic(makeErrorWithDetails(
			errInvalidSnapshotTime,
			ufmt.Sprintf("snapshot time must be less than %d (requested:%d)", currentTime-maxSmoothingPeriod, snapshotTime),
		))
	}
}

// assertIsAvailableCleanupSnapshotTime checks that no active proposals need
func assertIsAvailableCleanupSnapshotTime(cleanupSnapshotTime int64) {
	oldestActiveSnapshotTime, hasActiveProposal := governance.GetOldestActiveProposalSnapshotTime()
	if !hasActiveProposal {
		// No active proposals, cleanup is safe
		return
	}

	if cleanupSnapshotTime > oldestActiveSnapshotTime {
		panic(makeErrorWithDetails(
			errInvalidSnapshotTime,
			ufmt.Sprintf(
				"cannot cleanup delegation history: active proposal requires data from snapshot time %d, but cleanup would remove data before %d",
				oldestActiveSnapshotTime,
				cleanupSnapshotTime,
			),
		))
	}
}

func assertNoActiveProposal() {
	_, hasActiveProposal := governance.GetOldestActiveProposalSnapshotTime()
	if hasActiveProposal {
		panic(errActiveProposal)
	}
}

func assertNoSelfDelegation(delegatee, newDelegatee address) {
	if delegatee == newDelegatee {
		panic(errSameDelegatee)
	}
}
