package staker

import "std"

type DelegationSnapshot map[string]*DelegationSnapshotItem

func (d *DelegationSnapshot) clone() DelegationSnapshot {
	clone := make(DelegationSnapshot)

	for k, v := range *d {
		clone[k] = v.clone()
	}

	return clone
}

func (d DelegationSnapshot) addRecord(delegationRecord *DelegationRecord) DelegationSnapshot {
	delegateTo := delegationRecord.DelegateTo()
	delegateToStr := delegateTo.String()

	_, ok := d[delegateToStr]
	if !ok {
		d[delegateToStr] = NewDelegationSnapshotItem(delegateTo)
	}

	d[delegateToStr].addRecord(delegationRecord)

	if d[delegateToStr].IsEmpty() {
		delete(d, delegateToStr)
	}

	return d
}

func (d DelegationSnapshot) subRecord(delegationRecord *DelegationRecord) DelegationSnapshot {
	delegateTo := delegationRecord.DelegateTo()
	delegateToStr := delegateTo.String()

	_, ok := d[delegateToStr]
	if !ok {
		d[delegateToStr] = NewDelegationSnapshotItem(delegateTo)
	}

	d[delegateToStr].subRecord(delegationRecord)

	return d
}

type DelegationSnapshotItem struct {
	delegationAmount int64
	delegatorAddress std.Address
}

func (d *DelegationSnapshotItem) DelegatorAddress() std.Address {
	return d.delegatorAddress
}

func (d *DelegationSnapshotItem) DelegationAmount() int64 {
	return d.delegationAmount
}

func (d *DelegationSnapshotItem) IsEmpty() bool {
	return d.delegationAmount == 0
}

func (d *DelegationSnapshotItem) clone() *DelegationSnapshotItem {
	return &DelegationSnapshotItem{
		delegatorAddress: d.delegatorAddress,
		delegationAmount: d.delegationAmount,
	}
}

func (d *DelegationSnapshotItem) addRecord(delegationRecord *DelegationRecord) {
	d.delegationAmount += delegationRecord.DelegateAmount()
	d.delegationAmount -= delegationRecord.UnDelegateAmount()
}

// subRecord subtracts the delegation amount from the snapshot
// by the delegation record.
// It is used to get previous delegation snapshots by the current delegation records.
func (d *DelegationSnapshotItem) subRecord(delegationRecord *DelegationRecord) {
	d.delegationAmount -= delegationRecord.DelegateAmount()
	d.delegationAmount += delegationRecord.UnDelegateAmount()
}

func NewDelegationSnapshotItem(delegatorAddress std.Address) *DelegationSnapshotItem {
	return &DelegationSnapshotItem{
		delegatorAddress: delegatorAddress,
		delegationAmount: 0,
	}
}
