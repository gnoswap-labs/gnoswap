package staker

import (
	"std"
	"time"

	"gno.land/p/demo/ufmt"

	en "gno.land/r/gnoswap/v2/emission"
)

// DelegationHistory represents a single delegation event
type DelegationHistory struct {
	to        std.Address
	amount    uint64
	timestamp uint64
	height    uint64
	add       bool
}

// Raw history
var delegationHistory = make(map[std.Address][]DelegationHistory)

type ModifiedDelegationHistory struct {
	from                 std.Address
	to                   std.Address
	delegatedHeight      uint64
	delegatedTimestamp   uint64
	delegatedAmount      uint64
	undelegatedHeight    uint64
	undelegatedTimestamp uint64
	undelegatedAmount    uint64
}

// Modified History => if undelegated, amount will be taken from the first delegation
// to address -> modifiedDelegationHistory
var delegationModifiedHistory = make(map[std.Address][]ModifiedDelegationHistory)

// GetDelegatedCumulative gets the cumulative delegated amount for an address at a certain timestamp.
func GetDelegatedCumulative(delegator std.Address, endTimestamp uint64) uint64 {
	en.MintAndDistributeGns()
	calculateReward()

	if !delegator.IsValid() {
		panic(ufmt.Sprintf("invalid delegator address: %s", delegator.String()))
	}

	if endTimestamp > uint64(time.Now().Unix()) {
		panic("FUTURE")
	}

	history, exist := delegationModifiedHistory[delegator]
	if !exist || len(history) == 0 {
		return 0
	}

	if endTimestamp < history[0].delegatedTimestamp {
		return 0
	}

	cumulativeAmount := uint64(0)

	for _, record := range history {
		if record.delegatedTimestamp > endTimestamp {
			// continue to next if this record uses future time
			continue
		}

		amount := uint64(0)

		// if undelegated before endTimestamp, subtract undelegated amount
		if record.undelegatedTimestamp < endTimestamp {
			amount = record.delegatedAmount - record.undelegatedAmount
		} else {
			amount = record.delegatedAmount
		}

		if amount == 0 {
			// already undelegated full amount for this record
			continue
		}

		cumulativeAmount += amount
	}

	return cumulativeAmount
}
