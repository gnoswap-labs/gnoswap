package staker

// DelegationSnapshot represents a point-in-time view of delegation states.
// It maps delegatee addresses to their corresponding delegation snapshot items,
// providing efficient lookup and manipulation of delegation states at specific timestamps.
type DelegationSnapshot map[string]*DelegationSnapshotItem

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
func (dsi *DelegationSnapshotItem) DelegatorAddress() address {
	return dsi.delegatorAddress
}

// DelegationAmount returns the total delegation amount for this delegatee.
//
// Returns:
//   - int64: total delegated amount
func (dsi *DelegationSnapshotItem) DelegationAmount() int64 {
	return dsi.delegationAmount
}

func (dsi *DelegationSnapshotItem) SetDelegationAmount(amount int64) {
	dsi.delegationAmount = amount
}

func (dsi *DelegationSnapshotItem) SetDelegatorAddress(delegatorAddress address) {
	dsi.delegatorAddress = delegatorAddress
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
