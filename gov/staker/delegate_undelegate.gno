package staker

import (
	"std"
	"time"

	"gno.land/p/demo/avl"
	"gno.land/p/demo/ufmt"
)

var (
	totalDelegated = uint64(0)

	delegatorAmount = avl.NewTree() // caller => amount
	delegatedFromTo = avl.NewTree() // caller => to => amount
	delegatedTo     = avl.NewTree() // to => amount
)

func delegate(to std.Address, amount uint64) {
	caller := std.PrevRealm().Addr().String()
	toStr := to.String()

	// initialize the internal tree for callers to `delegatedFromTo`
	var innerTree *avl.Tree
	if value, exists := delegatedFromTo.Get(caller); !exists {
		innerTree = avl.NewTree()
		delegatedFromTo.Set(caller, innerTree)
	} else {
		innerTree = value.(*avl.Tree)
	}

	totalDelegated += amount

	// update delegator amount
	currentAmount := uint64(0)
	if value, exists := delegatorAmount.Get(caller); exists {
		currentAmount = value.(uint64)
	}
	delegatorAmount.Set(caller, currentAmount+amount)

	// update delegatedFromTo's inner tree
	currentDelegated := uint64(0)
	if value, exists := innerTree.Get(toStr); exists {
		currentDelegated = value.(uint64)
	}
	innerTree.Set(toStr, currentDelegated+amount)

	// update delegatedTo
	currentToAmount := uint64(0)
	if value, exists := delegatedTo.Get(toStr); exists {
		currentToAmount = value.(uint64)
	}
	delegatedTo.Set(toStr, currentToAmount+amount)

	// update delegation history
	delegation := DelegationHistory{
		to:        to,
		amount:    amount,
		timestamp: uint64(time.Now().Unix()),
		height:    uint64(std.GetHeight()),
		add:       true, // if true, delegation
	}

	history := make([]DelegationHistory, 0)
	if value, exists := delegationHistory.Get(caller); exists {
		history = value.([]DelegationHistory)
	}
	history = append(history, delegation)
	delegationHistory.Set(caller, history)

	// update delegation stat history
	updateAmount := uint64(0)
	statHistory := make([]DelegationStatHistory, 0)
	if value, exists := delegationStatHistory.Get(toStr); exists {
		statHistory = value.([]DelegationStatHistory)
		lastStat := statHistory[len(statHistory)-1]
		updateAmount = lastStat.amount + amount
	} else {
		updateAmount = amount
	}

	statHistory = append(statHistory, DelegationStatHistory{
		to:           to,
		amount:       updateAmount,
		updatedBlock: uint64(std.GetHeight()),
		updatedAt:    uint64(time.Now().Unix()),
	})
	delegationStatHistory.Set(toStr, statHistory)
}

func undelegate(to std.Address, amount uint64) {
	caller := std.PrevRealm().Addr().String()
	toStr := to.String()

	// check caller's delegatedFromTo
	innerTree, exists := delegatedFromTo.Get(caller)
	if !exists {
		panic(addDetailToError(
			errNoDelegatedAmount,
			ufmt.Sprintf("caller(%s) has no delegated amount", caller),
		))
	}

	// check caller's delegatedFromTo's inner tree
	delegatedAmountValue, exists := innerTree.(*avl.Tree).Get(toStr)
	if !exists {
		panic(addDetailToError(
			errNoDelegatedTarget,
			ufmt.Sprintf("caller(%s) has no delegated amount to %s", caller, to),
		))
	}

	delegatedAmount := delegatedAmountValue.(uint64)
	if delegatedAmount < amount {
		panic(addDetailToError(
			errNotEnoughDelegated,
			ufmt.Sprintf("caller(%s) has only %d delegated amount(request: %d) to %s", caller, delegatedAmount, amount, to),
		))
	}

	// update total delegated amount
	totalDelegated -= amount

	currentAmount := uint64(0)
	if value, exists := delegatorAmount.Get(caller); exists {
		currentAmount = value.(uint64)
	}
	delegatorAmount.Set(caller, currentAmount-amount)

	innerTree.(*avl.Tree).Set(toStr, delegatedAmount-amount)

	currentToAmount := uint64(0)
	if value, exists := delegatedTo.Get(toStr); exists {
		currentToAmount = value.(uint64)
	}
	delegatedTo.Set(toStr, currentToAmount-amount)

	// update delegation history
	delegation := DelegationHistory{
		to:        to,
		amount:    amount,
		timestamp: uint64(time.Now().Unix()),
		height:    uint64(std.GetHeight()),
		add:       false,
	}
	var history []DelegationHistory
	if value, exists := delegationHistory.Get(caller); exists {
		history = value.([]DelegationHistory)
	}
	history = append(history, delegation)
	delegationHistory.Set(caller, history)

	// update delegation stat history
	statValue, exists := delegationStatHistory.Get(toStr)
	if !exists {
		panic(addDetailToError(
			errDataNotFound,
			ufmt.Sprintf("caller(%s) has no delegation stat history", caller),
		))
	}

	stat := statValue.([]DelegationStatHistory)
	remainingAmount := amount
	for i := 0; i < len(stat); i++ {
		if stat[i].amount > 0 {
			if stat[i].amount < remainingAmount {
				remainingAmount -= stat[i].amount
				stat = append(stat[:i], stat[i+1:]...)
				i--
			} else {
				stat[i].amount -= remainingAmount
				stat[i].updatedAt = uint64(time.Now().Unix())
				break
			}
		}
	}
	delegationStatHistory.Set(to.String(), stat)
}
