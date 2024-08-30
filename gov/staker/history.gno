package staker

import (
	"std"
	"time"

	"gno.land/p/demo/ufmt"

	u256 "gno.land/p/gnoswap/uint256"
)

// DelegationHistory represents a single delegation event
type DelegationHistory struct {
	amount    uint64
	timestamp uint64
	add       bool
}

var delegationHistory = make(map[std.Address][]DelegationHistory)

// GetDelegatedCumulative gets the cumulative delegated amount * seconds for an address at a certain timestamp.
func GetDelegatedCumulative(_delegator string, timestamp uint64) string {
	delegator := std.Address(_delegator)
	if !delegator.IsValid() {
		panic(ufmt.Sprintf("invalid delegator address: %s", _delegator))
	}

	if timestamp >= uint64(time.Now().Unix()) {
		panic("FUTURE")
	}

	history, exist := delegationHistory[delegator]
	if !exist || len(history) == 0 {
		return "0"
	}

	if timestamp < history[0].timestamp {
		return "0"
	}

	cumulativeAmount := u256.Zero()

	for i, record := range history {
		if record.timestamp > timestamp {
			break
		}

		duration := timestamp - record.timestamp
		toAccu := new(u256.Uint).Mul(u256.NewUint(record.amount), u256.NewUint(duration))

		if record.add {
			cumulativeAmount = new(u256.Uint).Add(cumulativeAmount, toAccu)
		} else {
			cumulativeAmount = new(u256.Uint).Sub(cumulativeAmount, toAccu)
		}
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

	history, exist := delegationHistory[delegator]
	if !exist || len(history) == 0 {
		return "0"
	}

	if end <= history[0].timestamp {
		return "0"
	}

	cumulativeAmount := u256.Zero()

	for i, record := range history {
		if record.timestamp > end {
			break
		}

		duration := end - maxUint64(record.timestamp, start)
		toAccu := new(u256.Uint).Mul(u256.NewUint(record.amount), u256.NewUint(duration))

		if record.add {
			cumulativeAmount = new(u256.Uint).Add(cumulativeAmount, toAccu)
		} else {
			cumulativeAmount = new(u256.Uint).Sub(cumulativeAmount, toAccu)
		}
	}

	res := u256.Zero()
	totalDuration := end - start
	if totalDuration == 0 {
		res = cumulativeAmount.Clone()
		return res.ToString()
	}

	res = u256.Zero().Div(cumulativeAmount, u256.NewUint(totalDuration))
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

	history, exist := delegationHistory[delegator]

	if !exist || len(history) == 0 {
		return "0"
	}

	lastEntry := history[len(history)-1]
	res := lastEntry.amount

	return ufmt.Sprintf("%d", res)
}

// GetDelegatedAt returns the delegated amount for a delegate at a specific timestamp.
func GetDelegatedAt(_delegator string, timestamp uint64) string {
	delegator := std.Address(_delegator)
	if !delegator.IsValid() {
		panic(ufmt.Sprintf("invalid delegator address: %s", _delegator))
	}

	history, exist := delegationHistory[delegator]
	if !exist || len(history) == 0 {
		return "0"
	}

	for i := len(history) - 1; i >= 0; i-- {
		if history[i].timestamp <= timestamp {
			return ufmt.Sprintf("%d", history[i].amount)
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
