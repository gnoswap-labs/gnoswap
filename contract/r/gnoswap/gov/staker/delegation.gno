package staker

import (
	"fmt"
	"std"

	"gno.land/p/demo/ufmt"
)

type (
	AmountMap = map[string]uint64
	FromToMap = map[string]AmountMap
)

type DelegationState struct {
	totalDelegated  uint64
	delegatorAmount AmountMap
	delegatedFromTo FromToMap
	delegatedTo     AmountMap
}

func (st *DelegationState) TotalDelegated() uint64     { return st.totalDelegated }
func (st *DelegationState) DelegatorAmount() AmountMap { return st.delegatorAmount }
func (st *DelegationState) DelegatedFromTo() FromToMap { return st.delegatedFromTo }
func (st *DelegationState) DelegatedTo() AmountMap     { return st.delegatedTo }

type DelegationRecord struct {
	Delegator string `json:"delegator"`
	Delegatee string `json:"delegatee"`
	Amount    uint64 `json:"amount"`
}

func newDelegationState() *DelegationState {
	return &DelegationState{
		totalDelegated:  0,
		delegatorAmount: make(AmountMap),
		delegatedFromTo: make(FromToMap),
		delegatedTo:     make(AmountMap),
	}
}

func newDelegationRecord(delegator string, delegatee string, amount uint64) *DelegationRecord {
	return &DelegationRecord{
		Delegator: delegator,
		Delegatee: delegatee,
		Amount:    amount,
	}
}

func delegate(st *DelegationState, hs *HistoryState, to std.Address, amount uint64) error {
	if amount == 0 {
		return fmt.Errorf("amount must be positive")
	}
	caller := std.PreviousRealm().Address().String()
	toStr := to.String()

	record := newDelegationRecord(caller, toStr, amount)
	st = st.update(*record, true)
	st.totalDelegated += amount

	hs.AppendDelegationHistory(std.Address(caller), to, amount, true)
	hs.UpdateDelegationSnapShotHistory(to, amount, true)

	return nil
}

func undelegate(st *DelegationState, hs *HistoryState, to std.Address, amount uint64) error {
	if amount == 0 {
		return fmt.Errorf("amount must be positive")
	}
	caller := std.PreviousRealm().Address()
	callerStr := caller.String()
	toStr := to.String()

	innerMap, ok := st.delegatedFromTo[callerStr]
	if !ok {
		return ufmt.Errorf("caller(%s) has no delegated amount", callerStr)
	}

	delegatedAmount, ok := innerMap[toStr]
	if !ok || delegatedAmount < amount {
		return ufmt.Errorf("caller(%s) has insufficient delegated amount to(%s)", callerStr, toStr)
	}

	record := newDelegationRecord(callerStr, toStr, amount)
	st = st.update(*record, false)
	st.totalDelegated -= amount

	hs.AppendDelegationHistory(caller, to, amount, false)
	hs.UpdateDelegationSnapShotHistory(to, amount, false)

	return nil
}

func (st *DelegationState) update(record DelegationRecord, add bool) *DelegationState {
	if add {
		return st.add(record)
	}
	return st.remove(record)
}

// add handles adding delegation amount to the state
func (st *DelegationState) add(record DelegationRecord) *DelegationState {
	delta := record.Amount

	// Update delegator's total delegated amount
	st.delegatorAmount[record.Delegator] += delta

	// Initialize delegator's from-to map if it doesn't exist
	if _, exists := st.delegatedFromTo[record.Delegator]; !exists {
		st.delegatedFromTo[record.Delegator] = make(AmountMap)
	}

	// Update specific delegation amount from delegator to delegatee
	st.delegatedFromTo[record.Delegator][record.Delegatee] += delta

	// Update delegatee's total received delegation amount
	st.delegatedTo[record.Delegatee] += delta

	return st
}

// remove handles removing delegation amount from the state
func (st *DelegationState) remove(record DelegationRecord) *DelegationState {
	delta := record.Amount

	// Update delegator's total delegated amount
	if currentAmount, exists := st.delegatorAmount[record.Delegator]; exists && currentAmount >= delta {
		st.delegatorAmount[record.Delegator] = currentAmount - delta
	} else {
		st.delegatorAmount[record.Delegator] = 0
	}

	// Update specific delegation amount from delegator to delegatee
	if delegatorMap, exists := st.delegatedFromTo[record.Delegator]; exists {
		if currentAmount, exists := delegatorMap[record.Delegatee]; exists && currentAmount >= delta {
			delegatorMap[record.Delegatee] = currentAmount - delta
		} else {
			// Remove the delegation entry if amount is insufficient or zero
			delete(delegatorMap, record.Delegatee)
		}
	}

	// Update delegatee's total received delegation amount
	if currentAmount, exists := st.delegatedTo[record.Delegatee]; exists && currentAmount >= delta {
		st.delegatedTo[record.Delegatee] = currentAmount - delta
	} else {
		st.delegatedTo[record.Delegatee] = 0
	}

	return st
}
