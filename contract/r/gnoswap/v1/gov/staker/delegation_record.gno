package staker

import (
	"std"
)

// DelegationRecord represents a single delegation event in the system.
// This struct tracks delegation or undelegation actions with their associated metadata
// and is used for historical tracking and snapshot calculations.
type DelegationRecord struct {
	// delegationType indicates whether this is a delegation or undelegation action
	delegationType DelegationType
	// delegateFrom is the address of the user who initiated the delegation
	delegateFrom std.Address
	// delegateTo is the address of the user who received the delegation
	delegateTo std.Address
	// delegateAmount is the amount delegated (set only for delegation actions)
	delegateAmount int64
	// unDelegateAmount is the amount undelegated (set only for undelegation actions)
	unDelegateAmount int64
	// createdAt is the timestamp when this record was created
	createdAt int64
}

// DelegationType returns the type of delegation action (DELEGATE or UNDELEGATE).
//
// Returns:
//   - DelegationType: the type of this delegation record
func (d *DelegationRecord) DelegationType() DelegationType {
	return d.delegationType
}

// DelegateAmount returns the amount that was delegated.
// This value is non-zero only for delegation actions.
//
// Returns:
//   - int64: amount delegated (0 for undelegation records)
func (d *DelegationRecord) DelegateAmount() int64 {
	return d.delegateAmount
}

// UnDelegateAmount returns the amount that was undelegated.
// This value is non-zero only for undelegation actions.
//
// Returns:
//   - int64: amount undelegated (0 for delegation records)
func (d *DelegationRecord) UnDelegateAmount() int64 {
	return d.unDelegateAmount
}

// DelegateFrom returns the address of the user who initiated the delegation.
//
// Returns:
//   - std.Address: delegator's address
func (d *DelegationRecord) DelegateFrom() std.Address {
	return d.delegateFrom
}

// DelegateTo returns the address of the user who received the delegation.
//
// Returns:
//   - std.Address: delegatee's address
func (d *DelegationRecord) DelegateTo() std.Address {
	return d.delegateTo
}

// CreatedAt returns the timestamp when this delegation record was created.
//
// Returns:
//   - int64: creation timestamp
func (d *DelegationRecord) CreatedAt() int64 {
	return d.createdAt
}

// NewDelegationRecord creates a new delegation record with the specified parameters.
// This factory function properly sets either delegateAmount or unDelegateAmount based on the delegation type.
//
// Parameters:
//   - delegationType: type of delegation action (DELEGATE or UNDELEGATE)
//   - delegationAmount: amount being delegated or undelegated
//   - delegateFrom: address of the delegator
//   - delegateTo: address of the delegatee
//   - createdAt: timestamp of the action
//
// Returns:
//   - *DelegationRecord: newly created delegation record
func NewDelegationRecord(
	delegationType DelegationType,
	delegationAmount int64,
	delegateFrom std.Address,
	delegateTo std.Address,
	createdAt int64,
) *DelegationRecord {
	delegateAmount := int64(0)
	unDelegateAmount := int64(0)

	// Set the appropriate amount field based on delegation type
	if delegationType.IsDelegate() {
		delegateAmount = delegationAmount
	} else {
		unDelegateAmount = delegationAmount
	}

	return &DelegationRecord{
		delegationType:   delegationType,
		delegateAmount:   delegateAmount,
		unDelegateAmount: unDelegateAmount,
		delegateFrom:     delegateFrom,
		delegateTo:       delegateTo,
		createdAt:        createdAt,
	}
}

// NewDelegationDelegateRecordBy creates a delegation record from an existing Delegation instance.
// This factory function is used to create historical records for delegation actions.
//
// Parameters:
//   - delegation: the delegation instance to create a record from
//
// Returns:
//   - *DelegationRecord: delegation record representing the delegation action
func NewDelegationDelegateRecordBy(
	delegation *Delegation,
) *DelegationRecord {
	return NewDelegationRecord(
		DelegateType,
		delegation.DelegatedAmount(),
		delegation.DelegateFrom(),
		delegation.DelegateTo(),
		delegation.CreatedAt(),
	)
}

// NewDelegationWithdrawRecordBy creates an undelegation record for a withdrawal action.
// This factory function is used to create historical records for undelegation actions.
//
// Parameters:
//   - delegation: the delegation instance being withdrawn from
//   - withdrawAmount: amount being withdrawn
//   - currentTime: timestamp of the withdrawal action
//
// Returns:
//   - *DelegationRecord: delegation record representing the undelegation action
func NewDelegationWithdrawRecordBy(
	delegation *Delegation,
	withdrawAmount int64,
	currentTime int64,
) *DelegationRecord {
	return NewDelegationRecord(
		UnDelegateType,
		withdrawAmount,
		delegation.DelegateFrom(),
		delegation.DelegateTo(),
		currentTime,
	)
}
