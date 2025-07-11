package staker2

import (
	"fmt"
	"std"
	"time"

	"gno.land/p/demo/ufmt"
)

var historyState = NewHistoryState()

// HistoryState manages all delegation history data
type HistoryState struct {
	delegationHistory HistoryMap
	snapshotHistory   SnapShotMap
	lastCleanedHeight uint64
}

func NewHistoryState() *HistoryState {
	return &HistoryState{
		delegationHistory: make(HistoryMap),
		snapshotHistory:   make(SnapShotMap),
		lastCleanedHeight: 0,
	}
}

// Getter methods
func (hs *HistoryState) DelegationHistory() HistoryMap { return hs.delegationHistory }
func (hs *HistoryState) SnapshotHistory() SnapShotMap  { return hs.snapshotHistory }
func (hs *HistoryState) LastCleanedHeight() uint64     { return hs.lastCleanedHeight }

// AppendDelegationHistory adds a new delegation history record
func (hs *HistoryState) AppendDelegationHistory(from, to std.Address, amount uint64, add bool) error {
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
	hs.delegationHistory[fromStr] = append(hs.delegationHistory[fromStr], history)
	return nil
}

// UpdateDelegationSnapShotHistory updates delegation snapshot for a delegatee
func (hs *HistoryState) UpdateDelegationSnapShotHistory(to std.Address, amount uint64, add bool) error {
	if !to.IsValid() {
		return fmt.Errorf("invalid address")
	}
	toStr := to.String()

	ts := uint64(time.Now().Unix())
	height := uint64(std.ChainHeight())

	snapshots := hs.snapshotHistory[toStr]
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

	hs.snapshotHistory[toStr] = snapshots
	return nil
}

// GetDelegatedCumulative returns cumulative delegated amount at specific timestamp
func (hs *HistoryState) GetDelegatedCumulative(delegator std.Address, endTimestamp uint64) uint64 {
	if !delegator.IsValid() {
		panic(ufmt.Sprintf("invalid delegator address: %s", delegator.String()))
	}
	if endTimestamp > uint64(time.Now().Unix()) {
		panic(ufmt.Sprintf("endTimestamp(%d) > now(%d)", endTimestamp, time.Now().Unix()))
	}
	toStr := delegator.String()
	history := hs.snapshotHistory[toStr]
	for i := len(history) - 1; i >= 0; i-- {
		record := history[i]
		if record.updatedAt <= endTimestamp {
			return record.amount
		}
	}
	return 0
}

// GetDelegateHistoryOf returns delegation history for a delegator
func (hs *HistoryState) GetDelegateHistoryOf(delegator std.Address) []DelegationHistory {
	if !delegator.IsValid() {
		panic(ufmt.Sprintf("invalid delegator address: %s", delegator.String()))
	}
	return hs.delegationHistory[delegator.String()]
}

// GetDelegationSnapShotHistoryOf returns snapshot history for a delegator
func (hs *HistoryState) GetDelegationSnapShotHistoryOf(delegator std.Address) []DelegationSnapShotHistory {
	if !delegator.IsValid() {
		panic(ufmt.Sprintf("invalid delegator address: %s", delegator.String()))
	}
	return hs.snapshotHistory[delegator.String()]
}

// CleanDelegationStatHistory removes old delegation snapshots older than threshold
func (hs *HistoryState) CleanDelegationStatHistory(thresholdVotingWeightBlockHeight int64) {
	height := uint64(std.ChainHeight())
	sinceLast := height - hs.lastCleanedHeight

	if sinceLast < uint64(thresholdVotingWeightBlockHeight) {
		return
	}

	hs.lastCleanedHeight = height
	keepFrom := height - uint64(thresholdVotingWeightBlockHeight)

	for key, history := range hs.snapshotHistory {
		// keep only entries newer than keepFrom, keeping at least one entry
		for i := len(history) - 1; i >= 0; i-- {
			if history[i].updatedBlock > keepFrom {
				continue
			}
			hs.snapshotHistory[key] = history[i:]
			break
		}
	}
}
