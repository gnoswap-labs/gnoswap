package staker

import (
	"std"
	"time"

	"gno.land/p/demo/avl"
	"gno.land/p/demo/ufmt"
)

// stakerState encapsulates all staking-related data.
type stakerState struct {
	totalDelegated            uint64
	delegatorAmount           *avl.Tree // caller -> amount.
	delegatedFromTo           *avl.Tree // caller -> (inner tree: to -> amount).
	delegatedTo               *avl.Tree // to -> amount.
	delegationHistory         *avl.Tree // caller -> []DelegationHistory.
	delegationSnapShotHistory *avl.Tree // to -> []DelegationSnapShotHistory.
}

func (s stakerState) TotalDelegated() uint64               { return s.totalDelegated }
func (s stakerState) DelegatorAmount() *avl.Tree           { return s.delegatorAmount }
func (s stakerState) DelegatedFromTo() *avl.Tree           { return s.delegatedFromTo }
func (s stakerState) DelegatedTo() *avl.Tree               { return s.delegatedTo }
func (s stakerState) DelegationHistory() *avl.Tree         { return s.delegationHistory }
func (s stakerState) DelegationSnapShotHistory() *avl.Tree { return s.delegationSnapShotHistory }

// Global state instance.
var state = newStakerState()

// newStakerState creates and returns a new StakerState.
func newStakerState() *stakerState {
	return &stakerState{
		totalDelegated:            0,
		delegatorAmount:           avl.NewTree(),
		delegatedFromTo:           avl.NewTree(),
		delegatedTo:               avl.NewTree(),
		delegationHistory:         avl.NewTree(),
		delegationSnapShotHistory: avl.NewTree(),
	}
}

// getOrCreateInnerTree returns the inner tree for the given caller,
// creating it if it does not exist.
func (s *stakerState) getOrCreateInnerTree(caller string) *avl.Tree {
	if inner, exists := s.delegatedFromTo.Get(caller); exists {
		return inner.(*avl.Tree)
	}
	innerTree := avl.NewTree()
	s.delegatedFromTo.Set(caller, innerTree)
	return innerTree
}

// updateUint64 updates the value at key in the given tree by delta.
// If add is true, it increments the value; otherwise, it decrements.
func (s *stakerState) updateUint64(tree *avl.Tree, key string, delta uint64, add bool) {
	var current uint64 = 0
	if value, exists := tree.Get(key); exists {
		current = value.(uint64)
	}
	if add {
		current += delta
	} else {
		if current < delta {
			panic(ufmt.Sprintf("not enough value for key %s", key))
		}
		current -= delta
	}
	tree.Set(key, current)
}

// Delegate processes a delegation from the caller to the given address.
func (s *stakerState) Delegate(to std.Address, amount uint64) {
	caller := std.PrevRealm().Addr().String()
	toStr := to.String()

	innerTree := s.getOrCreateInnerTree(caller)

	s.totalDelegated += amount

	s.updateUint64(s.delegatorAmount, caller, amount, true)
	s.updateUint64(innerTree, toStr, amount, true)
	s.updateUint64(s.delegatedTo, toStr, amount, true)

	timeStamp := uint64(time.Now().Unix())

	// Update delegation history.
	history := []DelegationHistory{}
	if value, exists := s.delegationHistory.Get(caller); exists {
		history = value.([]DelegationHistory)
	}
	delegation := newDelegationHistory(to, amount, timeStamp, uint64(std.GetHeight()), true)
	history = append(history, delegation)
	s.delegationHistory.Set(caller, history)

	// Update snapshot history.
	updateAmount := amount
	snapShotHistory := []DelegationSnapShotHistory{}
	if value, exists := s.DelegationSnapShotHistory().Get(toStr); exists {
		snapShotHistory = value.([]DelegationSnapShotHistory)
		lastStat := snapShotHistory[len(snapShotHistory)-1]
		updateAmount = lastStat.amount + amount
	}
	snapShot := newDelegationSnapShotHistory(to, updateAmount, uint64(std.GetHeight()), timeStamp)
	snapShotHistory = append(snapShotHistory, snapShot)
	s.delegationSnapShotHistory.Set(toStr, snapShotHistory)
}

// getUint64OrPanic retrieves a uint64 value from the tree by key,
// panicking with an error message if the key does not exist.
func (s *stakerState) getUint64OrPanic(tree *avl.Tree, key, errMsg string) uint64 {
	if value, exists := tree.Get(key); exists {
		return value.(uint64)
	}
	panic(addDetailToError(
		errDataNotFound,
		ufmt.Sprintf("%s: %s", key, errMsg),
	))
}

// Undelegate processes an undelegation from the caller for the given address.
func (s *stakerState) Undelegate(to std.Address, amount uint64) {
	caller := std.PrevRealm().Addr().String()
	toStr := to.String()

	innerTreeValue, exists := s.DelegatedFromTo().Get(caller)
	if !exists {
		panic(addDetailToError(
			errNoDelegatedAmount,
			ufmt.Sprintf("caller(%s) has no delegated amount", caller),
		))
	}
	innerTree := innerTreeValue.(*avl.Tree)

	delegatedAmountValue, exists := innerTree.Get(toStr)
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
			ufmt.Sprintf("caller(%s) has only %d delegated amount (requested: %d) to %s", caller, delegatedAmount, amount, to),
		))
	}
	innerTree.Set(toStr, delegatedAmount-amount)
	s.DelegatedFromTo().Set(caller, innerTree)

	s.totalDelegated -= amount

	currentDelegatorAmount := s.getUint64OrPanic(s.delegatorAmount, caller, "has no delegated amount")
	if currentDelegatorAmount < amount {
		panic(addDetailToError(
			errNotEnoughDelegated,
			ufmt.Sprintf("caller(%s) has only %d delegated amount (requested: %d)", caller, currentDelegatorAmount, amount),
		))
	}
	s.delegatorAmount.Set(caller, currentDelegatorAmount-amount)

	currentDelegatedTo := s.getUint64OrPanic(s.delegatedTo, toStr, "target has no delegated amount")
	if currentDelegatedTo < amount {
		panic(addDetailToError(
			errNotEnoughDelegated,
			ufmt.Sprintf("to(%s) has only %d delegated amount (requested: %d)", toStr, currentDelegatedTo, amount),
		))
	}
	s.delegatedTo.Set(toStr, currentDelegatedTo-amount)

	// Update delegation history.
	history := []DelegationHistory{}
	if value, exists := s.delegationHistory.Get(caller); exists {
		history = value.([]DelegationHistory)
	}
	delegation := newDelegationHistory(to, amount, uint64(time.Now().Unix()), uint64(std.GetHeight()), false)
	history = append(history, delegation)
	s.delegationHistory.Set(caller, history)

	// Update snapshot history.
	statValue, exists := s.DelegationSnapShotHistory().Get(toStr)
	if !exists {
		panic(addDetailToError(
			errDataNotFound,
			ufmt.Sprintf("caller(%s) has no delegation stat history", caller),
		))
	}
	stats := statValue.([]DelegationSnapShotHistory)
	remainingAmount := amount
	for i := 0; i < len(stats); i++ {
		if stats[i].amount > 0 {
			if stats[i].amount < remainingAmount {
				remainingAmount -= stats[i].amount
				stats = append(stats[:i], stats[i+1:]...)
				i--
			} else {
				stats[i].amount -= remainingAmount
				stats[i].updatedAt = uint64(time.Now().Unix())
				remainingAmount = 0
				break
			}
		}
	}
	s.delegationSnapShotHistory.Set(toStr, stats)
}

// delegate is the external API for delegation.
func delegate(to std.Address, amount uint64) {
	state.Delegate(to, amount)
}

// undelegate is the external API for undelegation.
func undelegate(to std.Address, amount uint64) {
	state.Undelegate(to, amount)
}
