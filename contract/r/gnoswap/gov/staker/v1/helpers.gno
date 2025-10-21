package v1

import (
	"chain"
	"chain/banker"
	"time"

	"gno.land/p/nt/avl"
	"gno.land/p/nt/ufmt"

	"gno.land/r/gnoland/wugnot"
	"gno.land/r/gnoswap/common"
	"gno.land/r/gnoswap/emission"
	"gno.land/r/gnoswap/gns"
	"gno.land/r/gnoswap/gov/xgns"
	"gno.land/r/gnoswap/protocol_fee"
	"gno.land/r/gnoswap/referral"
)

// Helper methods for govStakerV1 that wrap external package calls

// assertIsValidDelegateAmount validates delegation amount
func (gs *govStakerV1) assertIsValidDelegateAmount(amount int64) {
	assertIsValidDelegateAmount(amount)
}

// mintAndDistributeGns wraps emission package call
func (gs *govStakerV1) mintAndDistributeGns() {
	emission.MintAndDistributeGns()
}

// transferFromGns wraps GNS TransferFrom
func (gs *govStakerV1) transferFromGns(from, to address, amount int64) {
	gns.TransferFrom(from, to, amount)
}

// transferGns wraps GNS Transfer
func (gs *govStakerV1) transferGns(to address, amount int64) {
	gns.Transfer(to, amount)
}

// mintXgns wraps xGNS Mint
func (gs *govStakerV1) mintXgns(to address, amount int64) {
	xgns.Mint(to, amount)
}

// burnXgns wraps xGNS Burn
func (gs *govStakerV1) burnXgns(from address, amount int64) {
	xgns.Burn(from, amount)
}

// tryRegisterReferral wraps referral package call
func (gs *govStakerV1) tryRegisterReferral(caller address, referrer string) bool {
	return referral.TryRegister(caller, referrer)
}

// withdrawWugnot wraps wUGNOT withdrawal
func (gs *govStakerV1) withdrawWugnot(amount int64) {
	wugnot.Withdraw(amount)
}

// safeTransferGRC20 wraps common package GRC20 transfer
func (gs *govStakerV1) safeTransferGRC20(tokenPath string, to address, amount int64) {
	common.SafeGRC20Transfer(tokenPath, to, amount)
}

// distributeProtocolFee wraps protocol fee distribution
func (gs *govStakerV1) distributeProtocolFee() {
	protocol_fee.DistributeProtocolFee()
}

// getRecordsByTimestamp filters delegation history by timestamp
func (gs *govStakerV1) getRecordsByTimestamp(history *avl.Tree, cutoffTimestamp int64) *avl.Tree {
	filtered := avl.NewTree()
	
	history.Iterate("", "", func(key string, value interface{}) bool {
		record, ok := value.(*DelegationRecord)
		if !ok {
			panic(ufmt.Sprintf("failed to cast history element to *DelegationRecord: %T", value))
		}
		
		if record.CreatedAt() >= cutoffTimestamp {
			filtered.Set(key, value)
		}
		return false
	})
	
	return filtered
}

// addToCollectedAmount safely adds to collected amount with overflow protection
func addToCollectedAmount(current, additional int64) (int64, error) {
	result := current + additional
	if result < current {
		return current, errIntegerOverflow
	}
	return result, nil
}

// cloneDelegationSnapshot creates a deep copy of a delegation snapshot
func (gs *govStakerV1) cloneDelegationSnapshot(snapshot DelegationSnapshot) DelegationSnapshot {
	return snapshot.clone()
}

// getHistoryRecordsByTime retrieves delegation records at or after specified time
func (gs *govStakerV1) getHistoryRecordsByTime(history *avl.Tree, snapshotTime int64) DelegationHistory {
	records := make(DelegationHistory, 0)
	
	history.Iterate("", "", func(key string, value interface{}) bool {
		record, ok := value.(*DelegationRecord)
		if !ok {
			panic(ufmt.Sprintf("failed to cast history element to *DelegationRecord: %T", value))
		}
		
		if record.CreatedAt() >= snapshotTime {
			records = append(records, record)
		}
		return false
	})
	
	return records
}

// subRecordFromSnapshot subtracts a delegation record from a snapshot
func (gs *govStakerV1) subRecordFromSnapshot(snapshot DelegationSnapshot, record *DelegationRecord) DelegationSnapshot {
	return snapshot.subRecord(record)
}