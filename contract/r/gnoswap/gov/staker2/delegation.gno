package staker2

import (
	"fmt"
	"std"
	"time"

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
	to        std.Address
	amount    uint64
	timestamp uint64
	height    uint64
	add       bool
}

// DelegationSnapShotHistory represents delegation stat for to address
type DelegationSnapShotHistory struct {
	to           std.Address
	amount       uint64
	updatedBlock uint64
	updatedAt    uint64
}

// TODO: rename it to DelegationState
type State struct {
	totalDelegated    uint64
	delegatorAmount   AmountMap
	delegatedFromTo   FromToMap
	delegatedTo       AmountMap
	delegationHistory HistoryMap
	snapShotHistory   SnapShotMap
}

func (st *State) TotalDelegated() uint64        { return st.totalDelegated }
func (st *State) DelegatorAmount() AmountMap    { return st.delegatorAmount }
func (st *State) DelegatedFromTo() FromToMap    { return st.delegatedFromTo }
func (st *State) DelegatedTo() AmountMap        { return st.delegatedTo }
func (st *State) DelegationHistory() HistoryMap { return st.delegationHistory }
func (st *State) SnapShotHistory() SnapShotMap  { return st.snapShotHistory }

type DelegationRecord struct {
	Delegator string `json:"delegator"`
	Delegatee string `json:"delegatee"`
	Amount    uint64 `json:"amount"`
}

func NewState() *State {
	return &State{
		totalDelegated:    0,
		delegatorAmount:   make(AmountMap),
		delegatedFromTo:   make(FromToMap),
		delegatedTo:       make(AmountMap),
		delegationHistory: make(HistoryMap),
		snapShotHistory:   make(SnapShotMap),
	}
}

func NewDelegationRecord(delegator string, delegatee string, amount uint64) *DelegationRecord {
	return &DelegationRecord{
		Delegator: delegator,
		Delegatee: delegatee,
		Amount:    amount,
	}
}

func delegate(st *State, to std.Address, amount uint64) error {
	if amount == 0 {
		return fmt.Errorf("amount must be positive")
	}
	caller := std.PreviousRealm().Address().String()
	toStr := to.String()

	record := NewDelegationRecord(caller, toStr, amount)
	st = st.applyDelegationChange(*record, true)
	st.totalDelegated += amount

	st.appendDelegationHistory(std.Address(caller), to, amount, true)
	st.updateDelegationSnapShotHistory(to, amount, true)

	return nil
}

func undelegate(st *State, to std.Address, amount uint64) error {
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

	st.appendDelegationHistory(caller, to, amount, false)
	st.updateDelegationSnapShotHistory(to, amount, false)

	return nil
}

func (st *State) applyDelegationChange(record DelegationRecord, add bool) *State {
	if add {
		return st.addDelegation(record)
	}
	return st.removeDelegation(record)
}

// addDelegation handles adding delegation amount to the state
func (st *State) addDelegation(record DelegationRecord) *State {
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
func (st *State) removeDelegation(record DelegationRecord) *State {
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

func (st *State) appendDelegationHistory(from, to std.Address, amount uint64, add bool) error {
	ts := uint64(time.Now().Unix())
	if !(from.IsValid() || to.IsValid()) {
		return fmt.Errorf("invalid address")
	}

	history := DelegationHistory{
		to:        to,
		amount:    amount,
		timestamp: ts,
		height:    uint64(std.ChainHeight()),
		add:       add,
	}

	fromStr := from.String()
	st.delegationHistory[fromStr] = append(st.delegationHistory[fromStr], history)
	return nil
}

func (st *State) updateDelegationSnapShotHistory(to std.Address, amount uint64, add bool) error {
	if !to.IsValid() {
		return fmt.Errorf("invalid address")
	}
	toStr := to.String()

	ts := uint64(time.Now().Unix())
	height := uint64(std.ChainHeight())

	snapshots := st.snapShotHistory[toStr]
	prev := uint64(0)
	if len(snapshots) > 0 {
		prev = snapshots[len(snapshots)-1].amount
	}

	if add {
		prev += amount
	} else {
		if prev >= amount {
			prev -= amount
		} else {
			prev = 0
		}
	}

	snapshots = append(snapshots, DelegationSnapShotHistory{
		to:           to,
		amount:       prev,
		updatedBlock: height,
		updatedAt:    ts,
	})

	st.snapShotHistory[toStr] = snapshots
	return nil
}

func (st *State) GetDelegatedCumulative(delegator std.Address, endTimestamp uint64) uint64 {
	if !delegator.IsValid() {
		panic(ufmt.Sprintf("invalid delegator address: %s", delegator.String()))
	}
	if endTimestamp > uint64(time.Now().Unix()) {
		panic(ufmt.Sprintf("endTimestamp(%d) > now(%d)", endTimestamp, time.Now().Unix()))
	}
	toStr := delegator.String()
	history := st.snapShotHistory[toStr]
	for i := len(history) - 1; i >= 0; i-- {
		record := history[i]
		if record.updatedAt <= endTimestamp {
			return record.amount
		}
	}
	return 0
}

func (st *State) GetDelegateHistoryOf(delegator std.Address) []DelegationHistory {
	if !delegator.IsValid() {
		panic(ufmt.Sprintf("invalid delegator address: %s", delegator.String()))
	}
	return st.delegationHistory[delegator.String()]
}

func (st *State) GetDelegationSnapShotHistoryOf(delegator std.Address) []DelegationSnapShotHistory {
	if !delegator.IsValid() {
		panic(ufmt.Sprintf("invalid delegator address: %s", delegator.String()))
	}
	return st.snapShotHistory[delegator.String()]
}

// cleanDelegationStatHistory removes old delegation snapshots older than threshold
func (st *State) CleanDelegationStatHistory(lastCleanedHeight *uint64, thresholdVotingWeightBlockHeight int64) {
	height := uint64(std.ChainHeight())
	sinceLast := height - *lastCleanedHeight

	if sinceLast < uint64(thresholdVotingWeightBlockHeight) {
		return
	}

	*lastCleanedHeight = height
	keepFrom := height - uint64(thresholdVotingWeightBlockHeight)

	for key, history := range st.snapShotHistory {
		// keep only entries newer than keepFrom, keeping at least one entry
		for i := len(history) - 1; i >= 0; i-- {
			if history[i].updatedBlock > keepFrom {
				continue
			}
			st.snapShotHistory[key] = history[i:]
			break
		}
	}
}

// milliToSec converts milliseconds to seconds
func milliToSec(ms int64) int64 {
	return ms / consts.MILLISECONDS_PER_SECOND
}
