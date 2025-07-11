package staker2

import (
	"fmt"
	"std"

	"gno.land/p/demo/ufmt"

	"gno.land/p/gnoswap/consts"
)

var delegationState = NewState()

var thresholdVotingWeightBlockHeight = consts.SECONDS_PER_DAY / milliToSec(consts.BLOCK_GENERATION_INTERVAL)

type (
	AmountMap   = map[string]uint64
	FromToMap   = map[string]AmountMap
	HistoryMap  = map[string][]DelegationHistory
	SnapShotMap = map[string][]DelegationSnapShotHistory
)

// DelegationHistory represents a single delegation event
type DelegationHistory struct {
	to        std.Address `json:"to"`
	amount    uint64      `json:"amount"`
	timestamp uint64      `json:"timestamp"`
	height    uint64      `json:"height"`
	add       bool        `json:"add"`
}

// DelegationSnapShotHistory represents delegation stat for to address
type DelegationSnapShotHistory struct {
	to           std.Address `json:"to"`
	amount       uint64      `json:"amount"`
	updatedBlock uint64      `json:"updatedBlock"`
	updatedAt    uint64      `json:"updatedAt"`
}

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

func NewState() *DelegationState {
	return &DelegationState{
		totalDelegated:  0,
		delegatorAmount: make(AmountMap),
		delegatedFromTo: make(FromToMap),
		delegatedTo:     make(AmountMap),
	}
}

func NewDelegationRecord(delegator string, delegatee string, amount uint64) *DelegationRecord {
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

	record := NewDelegationRecord(caller, toStr, amount)
	st = st.applyDelegationChange(*record, true)
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

	record := NewDelegationRecord(callerStr, toStr, amount)
	st = st.applyDelegationChange(*record, false)
	st.totalDelegated -= amount

	hs.AppendDelegationHistory(caller, to, amount, false)
	hs.UpdateDelegationSnapShotHistory(to, amount, false)

	return nil
}

func (st *DelegationState) applyDelegationChange(record DelegationRecord, add bool) *DelegationState {
	if add {
		return st.addDelegation(record)
	}
	return st.removeDelegation(record)
}

// addDelegation handles adding delegation amount to the state
func (st *DelegationState) addDelegation(record DelegationRecord) *DelegationState {
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

// removeDelegation handles removing delegation amount from the state
func (st *DelegationState) removeDelegation(record DelegationRecord) *DelegationState {
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

// GetDelegatedCumulative is a wrapper for HistoryState method
func GetDelegatedCumulative(delegator std.Address, endTimestamp uint64) uint64 {
	return historyState.GetDelegatedCumulative(delegator, endTimestamp)
}

// GetDelegateHistoryOf is a wrapper for HistoryState method
func GetDelegateHistoryOf(delegator std.Address) []DelegationHistory {
	return historyState.GetDelegateHistoryOf(delegator)
}

// GetDelegationSnapShotHistoryOf is a wrapper for HistoryState method
func GetDelegationSnapShotHistoryOf(delegator std.Address) []DelegationSnapShotHistory {
	return historyState.GetDelegationSnapShotHistoryOf(delegator)
}

// CleanDelegationStatHistory is a wrapper for HistoryState method
func CleanDelegationStatHistory(thresholdVotingWeightBlockHeight int64) {
	historyState.CleanDelegationStatHistory(thresholdVotingWeightBlockHeight)
}

// milliToSec converts milliseconds to seconds
func milliToSec(ms int64) int64 {
	return ms / consts.MILLISECONDS_PER_SECOND
}
