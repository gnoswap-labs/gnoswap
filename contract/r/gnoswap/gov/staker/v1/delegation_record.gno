package v1

import (
	"gno.land/r/gnoswap/gov/staker"
)

// NewDelegationDelegateRecordBy creates a delegation record from an existing Delegation instance.
// This factory function is used to create historical records for delegation actions.
//
// Parameters:
//   - delegation: the delegation instance to create a record from
//
// Returns:
//   - *DelegationRecord: delegation record representing the delegation action
func NewDelegationDelegateRecordBy(
	delegation *staker.Delegation,
) *staker.DelegationRecord {
	delegationResolver := NewDelegationResolver(delegation)
	return staker.NewDelegationRecord(
		staker.DelegateType,
		delegationResolver.DelegatedAmount(),
		delegation.DelegateFrom(),
		delegation.DelegateTo(),
		delegation.CreatedAt(),
	)
}
