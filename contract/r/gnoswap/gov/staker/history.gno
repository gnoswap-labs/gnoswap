package staker

import (
	"std"
	"time"

	"gno.land/p/demo/avl"
	"gno.land/p/demo/ufmt"
)

// DelegationHistory represents a single delegation event
type DelegationHistory struct {
	to        std.Address
	amount    uint64
	timestamp uint64
	height    uint64
	add       bool
}

// DelegationSnapShotHistory represents delegation stat for to address
type DelegationSnapShotHistory struct {
	to           std.Address
	amount       uint64
	updatedBlock uint64
	updatedAt    uint64
}

var (
	delegationHistory         = avl.NewTree() // addr => []delegationHistory
	delegationSnapShotHistory = avl.NewTree() // addr => []delegationSnapShotHistory
)

// GetDelegatedCumulative gets the cumulative delegated amount for an address at a certain timestamp.
func GetDelegatedCumulative(delegator std.Address, endTimestamp uint64) uint64 {
	if !delegator.IsValid() {
		panic(addDetailToError(
			errInvalidAddress,
			ufmt.Sprintf("invalid delegator address: %s", delegator.String()),
		))
	}

	if endTimestamp > uint64(time.Now().Unix()) {
		panic(addDetailToError(
			errFutureTime,
			ufmt.Sprintf("endTimestamp(%d) > now(%d)", endTimestamp, time.Now().Unix()),
		))
	}

	history := make([]DelegationSnapShotHistory, 0)
	if value, exists := delegationSnapShotHistory.Get(delegator.String()); exists {
		history = value.([]DelegationSnapShotHistory)
	} else {
		return 0
	}

	// reverse history
	for i := len(history) - 1; i >= 0; i-- {
		record := history[i]

		if record.updatedAt > endTimestamp {
			continue
		}

		return record.amount // return last accumulated amount
	}

	return 0
}

// GetDelegateHistoryOf returns the delegation history for a delegator.
func GetDelegateHistoryOf(delegator std.Address) []DelegationHistory {
	if !delegator.IsValid() {
		panic(addDetailToError(
			errInvalidAddress,
			ufmt.Sprintf("invalid delegator address: %s", delegator.String()),
		))
	}

	history := make([]DelegationHistory, 0)
	if value, exists := delegationHistory.Get(delegator.String()); exists {
		history = value.([]DelegationHistory)
	}

	return history
}

// GetDelegationSnapShotHistoryOf returns the delegation snapshot history for a delegator.
func GetDelegationSnapShotHistoryOf(delegator std.Address) []DelegationSnapShotHistory {
	if !delegator.IsValid() {
		panic(addDetailToError(
			errInvalidAddress,
			ufmt.Sprintf("invalid delegator address: %s", delegator.String()),
		))
	}

	history := make([]DelegationSnapShotHistory, 0)
	if value, exists := delegationSnapShotHistory.Get(delegator.String()); exists {
		history = value.([]DelegationSnapShotHistory)
	}

	return history
}
