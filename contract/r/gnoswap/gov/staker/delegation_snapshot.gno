package staker

// DelegationSnapshot represents a point-in-time view of delegation states.
// It maps delegatee addresses to their corresponding delegation snapshot items,
// providing efficient lookup and manipulation of delegation states at specific timestamps.
type DelegationSnapshot map[string]*DelegationSnapshotItem

// Clone creates a deep copy of the delegation snapshot.
// This method is used to create independent copies for historical calculations
// without modifying the original snapshot state.
//
// Returns:
//   - DelegationSnapshot: deep copy of the current snapshot
func (d *DelegationSnapshot) Clone() DelegationSnapshot {
	clone := make(DelegationSnapshot)

	for k, v := range *d {
		clone[k] = v.Clone()
	}

	return clone
}

// AddRecord applies a delegation record to the snapshot, updating delegation amounts.
// This method creates new snapshot items if they don't exist and removes empty items.
//
// Parameters:
//   - delegationRecord: the delegation record to apply to the snapshot
//
// Returns:
//   - DelegationSnapshot: updated snapshot with the record applied
func (d DelegationSnapshot) AddRecord(delegationRecord *DelegationRecord) DelegationSnapshot {
	delegateTo := delegationRecord.DelegateTo()
	delegateToStr := delegateTo.String()

	// Create new snapshot item if it doesn't exist
	_, ok := d[delegateToStr]
	if !ok {
		d[delegateToStr] = NewDelegationSnapshotItem(0, delegateTo)
	}

	// Apply the delegation record to the snapshot item
	d[delegateToStr].AddRecord(delegationRecord)

	// Remove empty snapshot items to keep the map clean
	if d[delegateToStr].IsEmpty() {
		delete(d, delegateToStr)
	}

	return d
}

// SubRecord subtracts a delegation record from the snapshot.
// This method is used for calculating historical snapshots by removing
// the effects of delegation records that occurred after a specific time.
//
// Parameters:
//   - delegationRecord: the delegation record to subtract from the snapshot
//
// Returns:
//   - DelegationSnapshot: updated snapshot with the record subtracted
func (d DelegationSnapshot) SubRecord(delegationRecord *DelegationRecord) DelegationSnapshot {
	delegateTo := delegationRecord.DelegateTo()
	delegateToStr := delegateTo.String()

	// Create new snapshot item if it doesn't exist
	_, ok := d[delegateToStr]
	if !ok {
		d[delegateToStr] = NewDelegationSnapshotItem(0, delegateTo)
	}

	// Subtract the delegation record from the snapshot item
	d[delegateToStr].SubRecord(delegationRecord)

	return d
}

// DelegationSnapshotItem represents delegation information for a specific delegatee.
// It tracks the total delegation amount and the delegator's address.
type DelegationSnapshotItem struct {
	// delegationAmount is the total amount delegated to this delegatee
	delegationAmount int64
	// delegatorAddress is the address of the delegatee receiving delegations
	delegatorAddress address
}

// DelegatorAddress returns the address of the delegatee.
//
// Returns:
//   - std.Address: delegatee's address
func (d *DelegationSnapshotItem) DelegatorAddress() address {
	return d.delegatorAddress
}

// DelegationAmount returns the total delegation amount for this delegatee.
//
// Returns:
//   - int64: total delegated amount
func (d *DelegationSnapshotItem) DelegationAmount() int64 {
	return d.delegationAmount
}

// IsEmpty checks if the delegation amount is zero.
// Empty snapshot items are typically removed from the snapshot map.
//
// Returns:
//   - bool: true if delegation amount is zero, false otherwise
func (d *DelegationSnapshotItem) IsEmpty() bool {
	return d.delegationAmount == 0
}

// Clone creates a deep copy of the delegation snapshot item.
//
// Returns:
//   - *DelegationSnapshotItem: independent copy of the snapshot item
func (d *DelegationSnapshotItem) Clone() *DelegationSnapshotItem {
	return &DelegationSnapshotItem{
		delegatorAddress: d.delegatorAddress,
		delegationAmount: d.delegationAmount,
	}
}

// AddRecord applies a delegation record to this snapshot item.
// It increases the delegation amount for delegate actions and decreases for undelegate actions.
//
// Parameters:
//   - delegationRecord: the delegation record to apply
func (d *DelegationSnapshotItem) AddRecord(delegationRecord *DelegationRecord) {
	d.delegationAmount += delegationRecord.DelegateAmount()
	d.delegationAmount -= delegationRecord.UnDelegateAmount()
}

// SubRecord subtracts the delegation amount from the snapshot by the delegation record.
// It is used to get previous delegation snapshots by reversing the effects of current delegation records.
// This method performs the inverse operation of AddRecord.
//
// Parameters:
//   - delegationRecord: the delegation record to subtract from the snapshot
func (d *DelegationSnapshotItem) SubRecord(delegationRecord *DelegationRecord) {
	d.delegationAmount -= delegationRecord.DelegateAmount()
	d.delegationAmount += delegationRecord.UnDelegateAmount()
}

// NewDelegationSnapshotItem creates a new delegation snapshot item for a delegatee.
// The initial delegation amount is set to zero.
//
// Parameters:
//   - delegatorAddress: address of the delegatee
//
// Returns:
//   - *DelegationSnapshotItem: new snapshot item with zero delegation amount
func NewDelegationSnapshotItem(amount int64, delegatorAddress address) *DelegationSnapshotItem {
	return &DelegationSnapshotItem{
		delegatorAddress: delegatorAddress,
		delegationAmount: amount,
	}
}
