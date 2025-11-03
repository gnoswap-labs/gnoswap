package v1

import (
	"gno.land/r/gnoswap/gov/staker"
)

type DelegationSnapshotResolver struct {
	snapshot staker.DelegationSnapshot
}

func NewDelegationSnapshotResolver(snapshot staker.DelegationSnapshot) *DelegationSnapshotResolver {
	return &DelegationSnapshotResolver{snapshot}
}

func (r *DelegationSnapshotResolver) Get() staker.DelegationSnapshot {
	return r.snapshot
}

func (r *DelegationSnapshotResolver) Clone() staker.DelegationSnapshot {
	clone := make(staker.DelegationSnapshot)

	for k, v := range r.snapshot {
		itemResolver := NewDelegationSnapshotItemResolver(v)
		clone[k] = itemResolver.Clone()
	}

	return clone
}

func (r *DelegationSnapshotResolver) AddRecord(record *staker.DelegationRecord) staker.DelegationSnapshot {
	delegateeAddr := record.DelegateTo().String()

	// Get or create snapshot item
	item, exists := r.snapshot[delegateeAddr]
	if !exists {
		item = staker.NewDelegationSnapshotItem(0, record.DelegateTo())
		r.snapshot[delegateeAddr] = item
	}

	// apply the record
	itemResolver := NewDelegationSnapshotItemResolver(item)
	newItem := itemResolver.AddRecord(record)
	r.snapshot[delegateeAddr] = newItem

	// Check if the new item is empty and delete if necessary
	newItemResolver := NewDelegationSnapshotItemResolver(newItem)
	if newItemResolver.IsEmpty() {
		delete(r.snapshot, delegateeAddr)
	}

	return r.snapshot
}

func (r *DelegationSnapshotResolver) SubRecord(record *staker.DelegationRecord) staker.DelegationSnapshot {
	delegateeAddr := record.DelegateTo().String()

	// Get or create snapshot item
	item, exists := r.snapshot[delegateeAddr]
	if !exists {
		item = staker.NewDelegationSnapshotItem(0, record.DelegateTo())
		r.snapshot[delegateeAddr] = item
	}

	// Subtract the record
	itemResolver := NewDelegationSnapshotItemResolver(item)
	newItem := itemResolver.SubRecord(record)
	r.snapshot[delegateeAddr] = newItem

	// Check if the new item is empty and delete if necessary
	newItemResolver := NewDelegationSnapshotItemResolver(newItem)
	if newItemResolver.IsEmpty() {
		delete(r.snapshot, delegateeAddr)
	}

	return r.snapshot
}

type DelegationSnapshotItemResolver struct {
	item *staker.DelegationSnapshotItem
}

func NewDelegationSnapshotItemResolver(item *staker.DelegationSnapshotItem) *DelegationSnapshotItemResolver {
	return &DelegationSnapshotItemResolver{item}
}

// Get returns the underlying item.
func (r *DelegationSnapshotItemResolver) Get() *staker.DelegationSnapshotItem {
	return r.item
}

// IsEmpty checks if the delegation amount is zero.
func (r *DelegationSnapshotItemResolver) IsEmpty() bool {
	return r.item.DelegationAmount() == 0
}

func (r *DelegationSnapshotItemResolver) Clone() *staker.DelegationSnapshotItem {
	return staker.NewDelegationSnapshotItem(
		r.item.DelegationAmount(),
		r.item.DelegatorAddress(),
	)
}

func (r *DelegationSnapshotItemResolver) AddRecord(record *staker.DelegationRecord) *staker.DelegationSnapshotItem {
	amount := r.item.DelegationAmount() + record.DelegateAmount() - record.UnDelegateAmount()
	return staker.NewDelegationSnapshotItem(amount, r.item.DelegatorAddress())
}

func (r *DelegationSnapshotItemResolver) SubRecord(record *staker.DelegationRecord) *staker.DelegationSnapshotItem {
	amount := r.item.DelegationAmount() - record.DelegateAmount() + record.UnDelegateAmount()
	return staker.NewDelegationSnapshotItem(amount, r.item.DelegatorAddress())
}
