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

var (
	delegationHistory = make(map[std.Address][]DelegationHistory)
)

// GetDelegatedCumulative gets the cumulative delegated amount * seconds for an address at a certain timestamp.
func GetDelegatedCumulative(_delegator string, timestamp uint64) string {
	delegator := std.Address(_delegator)
	if !delegator.IsValid() {
		panic(ufmt.Sprintf("invalid delegator address: %s", _delegator))
	}

	if uint64(time.Now().Unix()) <= timestamp {
		panic("FUTURE")
	}

	history, exist := delegationHistory[delegator]
	if !exist || len(history) == 0 {
		return "0"
	}

	var lastSnapshot DelegationHistory
	var cumulativeAmount *u256.Uint

	for _, snapshot := range history {
		if snapshot.timestamp > timestamp {
			break
		}

		if lastSnapshot.timestamp != 0 {
			duration := snapshot.timestamp - lastSnapshot.timestamp
			if lastSnapshot.add {
				cumulativeAmount = new(u256.Uint).Add(cumulativeAmount, new(u256.Uint).Mul(u256.NewUint(lastSnapshot.amount), u256.NewUint(duration)))
			} else {
				cumulativeAmount = new(u256.Uint).Sub(cumulativeAmount, new(u256.Uint).Mul(u256.NewUint(lastSnapshot.amount), u256.NewUint(duration)))
			}
		}
		lastSnapshot = snapshot
	}

	if lastSnapshot.timestamp < timestamp {
		duration := timestamp - lastSnapshot.timestamp

		if lastSnapshot.add {
			cumulativeAmount = new(u256.Uint).Add(cumulativeAmount, new(u256.Uint).Mul(u256.NewUint(lastSnapshot.amount), u256.NewUint(duration)))
		} else {
			cumulativeAmount = new(u256.Uint).Sub(cumulativeAmount, new(u256.Uint).Mul(u256.NewUint(lastSnapshot.amount), u256.NewUint(duration)))
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

	// if start >= history[len(history)-1].timestamp {
	// 	println("HMHMHMHM")
	// 	return ufmt.Sprintf("%d", history[len(history)-1].amount)
	// }

	var (
		totalAmount = u256.Zero()
	)

	for i, record := range history {
		println("i:", i)
		println("record.timestamp:", record.timestamp)
		println("record.amount:", record.amount)
		println("record.add:", record.add)
		println("start:", start)
		println("end:", end)

		if record.timestamp > end {
			println("BREAK")
			break
		}

		duration := end - maxUint64(record.timestamp, start)
		println("duration:", duration)
		println(" > end", end)
		println(" > maxUint64(record.timestamp, start)", maxUint64(record.timestamp, start))
		println("  > record.timestamp", record.timestamp)
		println("  > start", start)
		println()

		toAccu := new(u256.Uint).Mul(u256.NewUint(record.amount), u256.NewUint(duration))
		if record.add {
			println("ADD", toAccu.ToString(), "FROM", totalAmount.ToString())
			totalAmount = new(u256.Uint).Add(totalAmount, toAccu)
		} else {
			println("SUB", toAccu.ToString(), "FROM", totalAmount.ToString())
			totalAmount = new(u256.Uint).Sub(totalAmount, toAccu)
		}
		println()
	}

	res := u256.Zero()
	totalDuration := end - start
	if totalDuration == 0 {
		res = totalAmount.Clone()
		println("res #1", res.ToString())
		println(" > totalAmount", totalAmount.ToString())
		return res.ToString()
	}

	res = u256.Zero().Div(totalAmount, u256.NewUint(totalDuration))
	println("res #2", res.ToString())
	println(" > totalAmount", totalAmount.ToString())
	println(" > DIV BY (end - start)", totalDuration)
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
