package staker

import (
	"std"
	"time"

	"gno.land/p/demo/ufmt"
)

var (
	totalDelegated  = uint64(0)
	delegatorAmount = make(map[string]uint64)            // caller => amount
	delegatedFromTo = make(map[string]map[string]uint64) // caller => to => amount
	delegatedTo     = make(map[string]uint64)            // to => amount
)

func delegate(to std.Address, amount uint64) {
	caller := std.GetOrigCaller()

	if delegatedFromTo[caller.String()] == nil {
		delegatedFromTo[caller.String()] = make(map[string]uint64)
	}

	totalDelegated += amount
	delegatorAmount[caller.String()] += amount
	delegatedFromTo[caller.String()][to.String()] += amount
	delegatedTo[to.String()] += amount

	// Update delegation history
	delegation := DelegationHistory{
		to:        to.String(),
		amount:    amount,
		timestamp: uint64(time.Now().Unix()),
		add:       true, // if true, delegation
	}
	delegationHistory[caller] = append(delegationHistory[caller], delegation)
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

	totalDelegated -= amount
	delegatorAmount[caller.String()] -= amount
	delegatedFromTo[caller.String()][from.String()] -= amount
	delegatedTo[from.String()] -= amount

	// Update delegation history
	delegation := DelegationHistory{
		to:        from.String(),
		amount:    amount,
		timestamp: uint64(time.Now().Unix()),
		add:       false, // if false, undelegation
	}
	delegationHistory[caller] = append(delegationHistory[caller], delegation)
}
