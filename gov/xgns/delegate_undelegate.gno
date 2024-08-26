package xgns

import (
	"std"

	"gno.land/p/demo/ufmt"
)

var (
	delegated = make(map[string]map[string]uint64) // caller => to => amount
)

func delegate(to std.Address, amount uint64) {
	caller := std.GetOrigCaller()

	totalDelegated := sumDelegated(caller)
	totalXGns := BalanceOf(a2u(caller))

	if totalDelegated+amount > totalXGns {
		panic(ufmt.Sprintf("insufficient balance to delegate %d XGNS(total: %d, delegated:%d)", amount, totalXGns, totalDelegated))
	}

	if delegated[caller.String()] == nil {
		delegated[caller.String()] = make(map[string]uint64)
	}

	delegated[caller.String()][to.String()] += amount

	// TODO:
	// std.Emit()

	// TODO:
	// voting power
}

func undelegate(from std.Address, amount uint64) {
	caller := std.GetOrigCaller()
	if delegated[from.String()] == nil {
		return
	}

	if delegated[from.String()][caller.String()] < amount {
		panic(ufmt.Sprintf("insufficient delegated amount to undelegate %d XGNS from %s", amount, from.String()))
	}

	delegated[from.String()][caller.String()] -= amount
}

func sumDelegated(from std.Address) uint64 {
	sum := uint64(0)
	for _, amount := range delegated[from.String()] {
		sum += amount
	}
	return sum
}
