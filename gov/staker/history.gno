package staker

import (
	"std"
	"time"

	"gno.land/p/demo/ufmt"

	en "gno.land/r/gnoswap/v1/emission"
)

// DelegationHistory represents a single delegation event
type DelegationHistory struct {
	to        std.Address
	amount    uint64
	timestamp uint64
	height    uint64
	add       bool
}

// to address -> []delegationHistory
var delegationHistory = make(map[std.Address][]DelegationHistory)

// DelegationStatHistory represents delegation stat for to address
type DelegationStatHistory struct {
	to           std.Address
	amount       uint64
	updatedBlock uint64
	updatedAt    uint64
}

// to address -> []delegationStatHistory
var delegationStatHistory = make(map[std.Address][]DelegationStatHistory)

// GetDelegatedCumulative gets the cumulative delegated amount for an address at a certain timestamp.
func GetDelegatedCumulative(delegator std.Address, endTimestamp uint64) uint64 {
	en.MintAndDistributeGns()
	calculateReward()

	if !delegator.IsValid() {
		panic(addDetailToError(
			errInvalidAddress,
			ufmt.Sprintf("history.gno__GetDelegatedCumulative() || invalid delegator address: %s", delegator.String()),
		))
	}

	if endTimestamp > uint64(time.Now().Unix()) {
		panic(addDetailToError(
			errFutureTime,
			ufmt.Sprintf("history.gno__GetDelegatedCumulative() || endTimestamp(%d) > now(%d)", endTimestamp, time.Now().Unix()),
		))
	}

	history, exist := delegationStatHistory[delegator]
	if !exist || len(history) == 0 {
		return 0
	}

	// reverse history
	for i := len(history) - 1; i >= 0; i-- {
		record := history[i]

		if record.updatedAt > endTimestamp {
			continue
		}

		return record.amount // return last accu amount
	}

	return 0
}
