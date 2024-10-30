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
var delegationModifiedHistory = make(map[std.Address][]ModifiedDelegationHistory)

// GetCurrentDelegated returns the current delegated amount for a delegate
func GetCurrentDelegated(delegator std.Address) string {
	en.MintAndDistributeGns()
	calculateReward()

	if !delegator.IsValid() {
		panic(ufmt.Sprintf("invalid delegator address: %s", delegator.String()))
	}

	history, exist := delegationModifiedHistory[delegator]

	if !exist || len(history) == 0 {
		return "0"
	}

	lastEntry := history[len(history)-1]
	res := lastEntry.delegatedAmount - lastEntry.undelegatedAmount
	// res := lastEntry.delegatedAmount

	return ufmt.Sprintf("%d", res)
}

// GetDelegatedAt returns the delegated amount for a delegate at a specific timestamp.
func GetDelegatedAt(delegator std.Address, timestamp uint64) string {
	en.MintAndDistributeGns()
	calculateReward()

	if !delegator.IsValid() {
		panic(ufmt.Sprintf("invalid delegator address: %s", delegator.String()))
	}

	history, exist := delegationModifiedHistory[delegator]
	if !exist || len(history) == 0 {
		return "0"
	}

	for i := len(history) - 1; i >= 0; i-- {
		if history[i].delegatedTimestamp <= timestamp {
			return ufmt.Sprintf("%d", history[i].delegatedAmount-history[i].undelegatedAmount)
			// return ufmt.Sprintf("%d", history[i].delegatedAmount)
		}
	}

	return "0"
}

// GetDelegatedCumulative gets the cumulative delegated amount for an address at a certain timestamp.
func GetDelegatedCumulative(delegator std.Address, timestamp uint64) uint64 {
	en.MintAndDistributeGns()
	calculateReward()

	if !delegator.IsValid() {
		panic(ufmt.Sprintf("invalid delegator address: %s", delegator.String()))
	}

	if timestamp >= uint64(time.Now().Unix()) {
		panic("FUTURE")
	}

	history, exist := delegationModifiedHistory[delegator]
	if !exist || len(history) == 0 {
		return 0
	}

	if timestamp < history[0].delegatedTimestamp {
		return 0
	}

	cumulativeAmount := uint64(0)

	for _, record := range history {
		if record.delegatedTimestamp > timestamp {
			// continue to next if this record uses future time
			continue
		}

		amount := record.delegatedAmount - record.undelegatedAmount
		if amount == 0 {
			// already undelegated full amount for this record
			continue
		}

		cumulativeAmount += amount
	}

	return cumulativeAmount
}

// GetAverageDelegated calculates the average delegated amount for a delegate over a given period
func GetAverageDelegated(delegator std.Address, start, end uint64) uint64 {
	en.MintAndDistributeGns()
	calculateReward()

	if !delegator.IsValid() {
		panic(ufmt.Sprintf("invalid delegator address: %s", delegator.String()))
	}

	if start > end {
		panic("start > end")
	}

	history, exist := delegationModifiedHistory[delegator]
	if !exist || len(history) == 0 {
		return 0
	}

	if end <= history[0].delegatedTimestamp {
		return 0
	}

	cumulativeAmount := uint64(0)

	for _, record := range history {
		if record.delegatedTimestamp > end {
			// continue to next if this record uses future time
			continue
		}

		amount := record.delegatedAmount - record.undelegatedAmount
		if amount == 0 {
			// already undelegated full amount for this record
			continue
		}

		cumulativeAmount += amount
	}

	totalDuration := end - start
	if totalDuration == 0 {
		return cumulativeAmount
	}

	return cumulativeAmount / totalDuration
}

// GetAverageDelegatedOverLastDuration gets the average amount delegated over the last period seconds.
func GetAverageDelegatedOverLastDuration(delegator std.Address, period uint64) uint64 {
	en.MintAndDistributeGns()
	calculateReward()

	now := uint64(time.Now().Unix())
	return GetAverageDelegated(delegator, now-period, now)
}
