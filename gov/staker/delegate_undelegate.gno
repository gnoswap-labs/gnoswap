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
		height:    uint64(std.GetHeight()),
		add:       true, // if true, delegation
	}
	delegationHistory[caller] = append(delegationHistory[caller], delegation)

	modified := ModifiedDelegationHistory{
		to:                 to.String(),
		delegatedHeight:    uint64(std.GetHeight()),
		delegatedTimestamp: uint64(time.Now().Unix()),
		delegatedAmount:    amount,
	}
	delegationModifiedHistory[caller] = append(delegationModifiedHistory[caller], modified)
}

func undelegate(to std.Address, amount uint64) {
	caller := std.GetOrigCaller()

	_, exist := delegatedFromTo[caller.String()]
	if !exist {
		panic(ufmt.Sprintf("caller %s has no delegated amount", caller.String()))
	}

	delegatedAmount, exist := delegatedFromTo[caller.String()][to.String()]
	if !exist {
		panic(ufmt.Sprintf("caller %s has no delegated amount to %s", caller.String(), to.String()))
	}

	if delegatedAmount < amount {
		panic(ufmt.Sprintf("caller %s has only %d delegated amount to %s", caller.String(), delegatedAmount, to.String()))
	}

	totalDelegated -= amount
	delegatorAmount[caller.String()] -= amount
	delegatedFromTo[caller.String()][to.String()] -= amount
	delegatedTo[to.String()] -= amount

	// Update delegation history
	delegation := DelegationHistory{
		to:        to.String(),
		amount:    amount,
		timestamp: uint64(time.Now().Unix()),
		height:    uint64(std.GetHeight()),
		add:       false, // if false, undelegation
	}
	delegationHistory[caller] = append(delegationHistory[caller], delegation)

	// update modified history
	modified, exist := delegationModifiedHistory[caller]
	if !exist {
		panic(ufmt.Sprintf("caller %s has no modified delegation history", caller.String()))
	}

	// for i := len(modified) - 1; i >= 0; i-- {
	for i := 0; i < len(modified); i++ {
		if modified[i].to == to.String() {
			leftAmount := modified[i].delegatedAmount - modified[i].undelegatedAmount
			if leftAmount > 0 {
				if leftAmount < amount {
					modified[i].undelegatedAmount = modified[i].delegatedAmount
					amount -= leftAmount
					modified[i].undelegatedHeight = uint64(std.GetHeight())
					modified[i].undelegatedTimestamp = uint64(time.Now().Unix())
				} else {
					modified[i].undelegatedAmount += amount
					modified[i].undelegatedHeight = uint64(std.GetHeight())
					modified[i].undelegatedTimestamp = uint64(time.Now().Unix())
					break
				}
			}
		}
	}
}
