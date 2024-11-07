package staker

import (
	"std"
	"time"

	"gno.land/p/demo/ufmt"
)

var (
	totalDelegated  = uint64(0)
	delegatorAmount = make(map[std.Address]uint64)                 // caller => amount
	delegatedFromTo = make(map[std.Address]map[std.Address]uint64) // caller => to => amount
	delegatedTo     = make(map[std.Address]uint64)                 // to => amount
)

func delegate(to std.Address, amount uint64) {
	caller := std.PrevRealm().Addr()

	if delegatedFromTo[caller] == nil {
		delegatedFromTo[caller] = make(map[std.Address]uint64)
	}

	totalDelegated += amount
	delegatorAmount[caller] += amount
	delegatedFromTo[caller][to] += amount
	delegatedTo[to] += amount

	// Update delegation history
	delegation := DelegationHistory{
		to:        to,
		amount:    amount,
		timestamp: uint64(time.Now().Unix()),
		height:    uint64(std.GetHeight()),
		add:       true, // if true, delegation
	}
	delegationHistory[caller] = append(delegationHistory[caller], delegation)

	// get last data if exists
	updateAmount := uint64(0)

	statHistory, exist := delegationStatHistory[to]
	if !exist {
		updateAmount = amount // this is first delegation
	} else {
		lastAmount := statHistory[len(statHistory)-1].amount
		updateAmount = lastAmount + amount
	}

	delegationStatHistory[to] = append(delegationStatHistory[to], DelegationStatHistory{
		to:           to,
		amount:       updateAmount,
		updatedBlock: uint64(std.GetHeight()),
		updatedAt:    uint64(time.Now().Unix()),
	})
}

func undelegate(to std.Address, amount uint64) {
	caller := std.PrevRealm().Addr()

	_, exist := delegatedFromTo[caller]
	if !exist {
		panic(addDetailToError(
			errNoDelegatedAmount,
			ufmt.Sprintf("delegate_undelegate.gno__Undelegate() || caller(%s) has no delegated amount", caller),
		))
	}

	delegatedAmount, exist := delegatedFromTo[caller][to]
	if !exist {
		panic(addDetailToError(
			errNoDelegatedTarget,
			ufmt.Sprintf("delegate_undelegate.gno__Undelegate() || caller(%s) has no delegated amount to %s", caller, to),
		))
	}

	if delegatedAmount < amount {
		panic(addDetailToError(
			errNotEnoughDelegated,
			ufmt.Sprintf("delegate_undelegate.gno__Undelegate() || caller(%s) has only %d delegated amount(request: %d) to %s", caller, delegatedAmount, amount, to),
		))
	}

	totalDelegated -= amount
	delegatorAmount[caller] -= amount
	delegatedFromTo[caller][to] -= amount
	delegatedTo[to] -= amount

	// Update delegation history
	delegation := DelegationHistory{
		to:        to,
		amount:    amount,
		timestamp: uint64(time.Now().Unix()),
		height:    uint64(std.GetHeight()),
		add:       false, // if false, undelegation
	}
	delegationHistory[caller] = append(delegationHistory[caller], delegation)

	// update delegation stat history
	stat, exist := delegationStatHistory[to]
	if !exist {
		panic(addDetailToError(
			errDataNotFound,
			ufmt.Sprintf("delegate_undelegate.gno__Undelegate() || caller(%s) has no delegation stat history", caller),
		))
	}

	for i := 0; i < len(stat); i++ {
		leftAmount := stat[i].amount
		if leftAmount > 0 {
			if leftAmount < amount {
				// used all
				amount -= leftAmount

				// delete this record
				stat = append(stat[:i], stat[i+1:]...)
			} else {
				stat[i].amount -= amount
				stat[i].updatedAt = uint64(time.Now().Unix())
				break
			}
		}
	}
}
