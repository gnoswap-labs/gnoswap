package v1

import (
	"math"

	"gno.land/p/nt/ufmt"
	"gno.land/r/gnoswap/gov/staker"
)

// HasDelegationSnapshotsKey returns true if delegation history exists.
func (gs *govStakerV1) HasDelegationSnapshotsKey() bool {
	return gs.store.HasTotalDelegationHistoryStoreKey()
}

// GetTotalDelegationAmountAtSnapshot returns the total delegation amount at a specific snapshot time.
// Uses ReverseIterate to find the most recent entry at or before the snapshot time.
//
// Parameters:
//   - snapshotTime: timestamp to retrieve the snapshot for
//
// Returns:
//   - int64: total delegation amount at the specified time
//   - bool: true if snapshot was exists, false otherwise
func (gs *govStakerV1) GetTotalDelegationAmountAtSnapshot(snapshotTime int64) (int64, bool) {
	history := gs.store.GetTotalDelegationHistory()
	if history.Size() == 0 {
		return 0, false
	}

	toTimestamp := snapshotTime
	if toTimestamp < math.MaxInt64 {
		toTimestamp = toTimestamp + 1
	}

	var (
		totalAmount int64
		exists      bool
	)

	// ReverseIterate from 0 to snapshotTime to find the most recent entry at or before snapshotTime
	history.ReverseIterate(0, toTimestamp, func(key int64, value any) bool {
		amountInt, ok := value.(int64)
		if !ok {
			panic(ufmt.Sprintf("invalid amount type: %T", value))
		}

		totalAmount = amountInt
		exists = true

		return true // stop after first (most recent) entry
	})

	return totalAmount, exists
}

// GetUserDelegationAmountAtSnapshot returns the delegation amount for a specific user at a specific snapshot time.
// Structure: address -> *UintTree[timestamp -> int64]
// Uses ReverseIterate to find the most recent entry at or before the snapshot time.
//
// Parameters:
//   - userAddr: address of the user to get delegation amount for
//   - snapshotTime: timestamp to retrieve the snapshot for
//
// Returns:
//   - int64: user delegation amount at the specified time
//   - bool: true if snapshot was exists, false otherwise
func (gs *govStakerV1) GetUserDelegationAmountAtSnapshot(userAddr address, snapshotTime int64) (int64, bool) {
	history := gs.store.GetUserDelegationHistory()

	// Get user's history tree
	userHistoryRaw, userHistoryExists := history.Get(userAddr.String())
	if !userHistoryExists {
		return 0, false
	}

	userHistory := userHistoryRaw.(*staker.UintTree)
	if userHistory.Size() == 0 {
		return 0, false
	}

	toTimestamp := snapshotTime
	if toTimestamp < math.MaxInt64 {
		toTimestamp = toTimestamp + 1
	}

	var (
		userAmount int64
		exists     bool
	)

	// ReverseIterate from 0 to snapshotTime to find the most recent entry at or before snapshotTime
	userHistory.ReverseIterate(0, toTimestamp, func(key int64, value any) bool {
		amountInt, ok := value.(int64)
		if !ok {
			panic(ufmt.Sprintf("invalid amount type: %T", value))
		}

		userAmount = amountInt
		exists = true

		return true // stop after first (most recent) entry
	})

	return userAmount, exists
}
