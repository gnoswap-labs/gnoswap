package staker

import (
	"std"
	"time"

	"gno.land/p/demo/ufmt"

	u256 "gno.land/p/gnoswap/uint256"
)

// DelegationHistory represents a single delegation event
type DelegationHistory struct {
	to        string
	amount    uint64
	timestamp uint64
	height    uint64
	add       bool
}

// Raw history
var delegationHistory = make(map[std.Address][]DelegationHistory)

type ModifiedDelegationHistory struct {
	to                   string
	delegatedHeight      uint64
	delegatedTimestamp   uint64
	delegatedAmount      uint64
	undelegatedHeight    uint64
	undelegatedTimestamp uint64
	undelegatedAmount    uint64
}

// Modified History => if undelegated, amount will be taken from the first delegation
var delegationModifiedHistory = make(map[std.Address][]ModifiedDelegationHistory)

// GetDelegatedCumulative gets the cumulative delegated amount * seconds for an address at a certain timestamp.
func GetDelegatedCumulative(_delegator string, timestamp uint64) string {
	delegator := std.Address(_delegator)
	if !delegator.IsValid() {
		panic(ufmt.Sprintf("invalid delegator address: %s", _delegator))
	}

	if timestamp >= uint64(time.Now().Unix()) {
		panic("FUTURE")
	}

	history, exist := delegationModifiedHistory[delegator]
	if !exist || len(history) == 0 {
		return "0"
	}

	if timestamp < history[0].delegatedTimestamp {
		return "0"
	}

	cumulativeAmount := u256.Zero()

	for i, record := range history {
		if record.delegatedTimestamp > timestamp || record.undelegatedTimestamp > timestamp {
			// continue to next if this record uses future time
			continue
		}

		amount := record.delegatedAmount - record.undelegatedAmount
		if amount == 0 {
			// already undelegated full amount for this record
			continue
		}

		laterTime := maxUint64(record.delegatedTimestamp, record.undelegatedTimestamp)

		duration := timestamp - laterTime

		toAccu := new(u256.Uint).Mul(u256.NewUint(amount), u256.NewUint(duration))

		cumulativeAmount = new(u256.Uint).Add(cumulativeAmount, toAccu)
	}

	return cumulativeAmount.ToString()
}

// GetAverageDelegated calculates the average delegated amount for a delegate over a given period
func GetAverageDelegated(_delegator string, start, end uint64) string {
	delegator := std.Address(_delegator)
	if !delegator.IsValid() {
		panic(ufmt.Sprintf("invalid delegator address: %s", _delegator))
	}

	if start > end {
		panic("start > end")
	}

	history, exist := delegationModifiedHistory[delegator]
	if !exist || len(history) == 0 {
		return "0"
	}

	if end <= history[0].delegatedTimestamp {
		return "0"
	}

	cumulativeAmount := u256.Zero()

	for i, record := range history {
		println()
		println("i:", i)
		if record.delegatedTimestamp > end || record.undelegatedTimestamp > end {
			println("FUTURE")
			// continue to next if this record uses future time
			continue
		}

		amount := record.delegatedAmount - record.undelegatedAmount
		println("amount:", amount)
		if amount == 0 {
			// already undelegated full amount for this record
			println("SPEND ALL")
			continue
		}

		duration := end - maxUint64(maxUint64(record.delegatedTimestamp, record.undelegatedTimestamp), start)
		println("duration:", duration)
		toAccu := new(u256.Uint).Mul(u256.NewUint(amount), u256.NewUint(duration))
		println("toAccu:", toAccu.ToString())

		cumulativeAmount = new(u256.Uint).Add(cumulativeAmount, toAccu)
		println("cumulativeAmount:", cumulativeAmount.ToString())
	}

	res := u256.Zero()
	totalDuration := end - start
	println("totalDuration:", totalDuration)
	if totalDuration == 0 {
		println("totalDuration == 0")
		res = cumulativeAmount.Clone()
		println("res #1:", res.ToString())
		return res.ToString()
	}

	res = u256.Zero().Div(cumulativeAmount, u256.NewUint(totalDuration))
	println("res #2:", res.ToString())
	return res.ToString()
}

// GetAverageDelegatedOverLast gets the average amount delegated over the last period seconds.
func GetAverageDelegatedOverLast(_delegator string, period uint64) string {
	now := uint64(time.Now().Unix())
	return GetAverageDelegated(_delegator, now-period, now)
}

// GetCurrentDelegated returns the current delegated amount for a delegate
func GetCurrentDelegated(_delegator string) string {
	delegator := std.Address(_delegator)
	if !delegator.IsValid() {
		panic(ufmt.Sprintf("invalid delegator address: %s", _delegator))
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
func GetDelegatedAt(_delegator string, timestamp uint64) string {
	delegator := std.Address(_delegator)
	if !delegator.IsValid() {
		panic(ufmt.Sprintf("invalid delegator address: %s", _delegator))
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

func maxUint64(a, b uint64) uint64 {
	if a > b {
		return a
	}
	return b
}
