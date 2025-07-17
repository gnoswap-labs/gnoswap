package staker

import (
	"std"
)

type DelegationRecord struct {
	delegationType   DelegationType
	delegateFrom     std.Address
	delegateTo       std.Address
	delegateAmount   int64
	unDelegateAmount int64
	createdAt        int64
}

func (d *DelegationRecord) DelegationType() DelegationType {
	return d.delegationType
}

func (d *DelegationRecord) DelegateAmount() int64 {
	return d.delegateAmount
}

func (d *DelegationRecord) UnDelegateAmount() int64 {
	return d.unDelegateAmount
}

func (d *DelegationRecord) DelegateFrom() std.Address {
	return d.delegateFrom
}

func (d *DelegationRecord) DelegateTo() std.Address {
	return d.delegateTo
}

func (d *DelegationRecord) CreatedAt() int64 {
	return d.createdAt
}

func NewDelegationRecord(
	delegationType DelegationType,
	delegationAmount int64,
	delegateFrom std.Address,
	delegateTo std.Address,
	createdAt int64,
) *DelegationRecord {
	delegateAmount := int64(0)
	unDelegateAmount := int64(0)

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
