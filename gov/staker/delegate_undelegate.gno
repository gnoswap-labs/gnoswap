package staker

import (
	"std"

	"gno.land/p/demo/ufmt"
)

var (
	delegatorAmount = make(map[string]uint64)            // caller => amount
	delegatedFromTo = make(map[string]map[string]uint64) // caller => to => amount
	delegatedTo     = make(map[string]uint64)            // to => amount
)

func delegate(to std.Address, amount uint64) {
	caller := std.GetOrigCaller()

	if delegatedFromTo[caller.String()] == nil {
		delegatedFromTo[caller.String()] = make(map[string]uint64)
	}

	delegatorAmount[caller.String()] += amount
	delegatedFromTo[caller.String()][to.String()] += amount
	delegatedTo[to.String()] += amount

	// caller is just owner of token, not owner of voting power.
	// therefore no need to update caller's voting power
	// updateVotingPower(caller)

	updateVotingPower(to)
}

func undelegate(from std.Address, amount uint64) {
	caller := std.GetOrigCaller()

	_, exist := delegatedFromTo[caller.String()]
	if !exist {
		panic(ufmt.Sprintf("caller %s has no delegated amount", caller.String()))
	}

	delegatedAmount, exist := delegatedFromTo[caller.String()][from.String()]
	if !exist {
		panic(ufmt.Sprintf("caller %s has no delegated amount to %s", caller.String(), from.String()))
	}

	if delegatedAmount < amount {
		panic(ufmt.Sprintf("caller %s has only %d delegated amount to %s", caller.String(), delegatedAmount, from.String()))
	}

	delegatorAmount[caller.String()] -= amount
	delegatedFromTo[caller.String()][from.String()] -= amount
	delegatedTo[from.String()] -= amount

	// caller is just owner of token, not owner of voting power.
	// therefore no need to update caller's voting power
	// updateVotingPower(caller)

	updateVotingPower(from)
}

func updateVotingPower(addr std.Address) {
	// contract really doesn't need to know the exact voting power
	// calculation can be done on the client side
}
