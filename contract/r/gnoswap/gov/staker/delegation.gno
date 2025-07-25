package staker

import (
	"std"

	"gno.land/p/demo/ufmt"
)

type DelegationType string

const (
	DelegateType   DelegationType = "DELEGATE"
	UnDelegateType DelegationType = "UNDELEGATE"
)

func (d DelegationType) String() string {
	return string(d)
}

func (d DelegationType) IsDelegate() bool {
	return d == DelegateType
}

func (d DelegationType) IsUnDelegate() bool {
	return d == UnDelegateType
}

type Delegation struct {
	id               int64
	delegateAmount   int64
	unDelegateAmount int64
	collectedAmount  int64
	delegateFrom     std.Address
	delegateTo       std.Address
	createdAt        int64

	withdraws []*DelegationWithdraw
}

func (d *Delegation) ID() int64 {
	return d.id
}

func (d *Delegation) TotalDelegatedAmount() int64 {
	return d.delegateAmount
}

func (d *Delegation) DelegatedAmount() int64 {
	return d.delegateAmount - d.unDelegateAmount
}

func (d *Delegation) LockedAmount() int64 {
	return d.delegateAmount - d.collectedAmount
}

func (d *Delegation) UnDelegatedAmount() int64 {
	return d.unDelegateAmount
}

func (d *Delegation) CollectedAmount() int64 {
	return d.collectedAmount
}

func (d *Delegation) DelegateFrom() std.Address {
	return d.delegateFrom
}

func (d *Delegation) DelegateTo() std.Address {
	return d.delegateTo
}

func (d *Delegation) CreatedAt() int64 {
	return d.createdAt
}

func (d *Delegation) CollectableAmount(currentTime int64) int64 {
	collectableAmount := int64(0)

	for _, withdraw := range d.withdraws {
		collectableAmount += withdraw.CollectableAmount(currentTime)
	}

	return collectableAmount
}

func (d *Delegation) IsEmpty() bool {
	return d.delegateAmount-d.collectedAmount == 0
}

func (d *Delegation) unDelegate(
	amount,
	currentTime,
	unDelegationLockupPeriod int64,
) {
	d.unDelegateAmount += amount

	d.withdraws = append(d.withdraws, NewDelegationWithdraw(
		d.id,
		amount,
		currentTime,
		unDelegationLockupPeriod,
	))
}

func (d *Delegation) unDelegateWithoutLockup(
	amount,
	currentTime int64,
) {
	d.unDelegateAmount += amount
	d.collectedAmount += amount

	d.withdraws = append(d.withdraws, NewDelegationWithdrawWithoutLockup(
		d.id,
		amount,
		currentTime,
	))
}

func (d *Delegation) collect(amount int64, currentTime int64) error {
	if amount > d.CollectableAmount(currentTime) {
		return makeErrorWithDetails(
			errInvalidAmount,
			ufmt.Sprintf("amount to collect is greater than collectable amount"),
		)
	}

	collectAmount := amount

	for _, withdraw := range d.withdraws {
		if !withdraw.IsCollectable(currentTime) {
			continue
		}

		withdrawCollectAmount := collectAmount
		withdrawCollectableAmount := withdraw.CollectableAmount(currentTime)

		if withdrawCollectAmount > withdrawCollectableAmount {
			withdrawCollectAmount = withdrawCollectableAmount
		}

		err := withdraw.collect(withdrawCollectAmount, currentTime)
		if err != nil {
			return err
		}

		collectAmount -= withdrawCollectAmount
		d.collectedAmount += withdrawCollectAmount

		if collectAmount <= 0 {
			break
		}
	}

	return nil
}

func NewDelegation(
	id int64,
	delegateFrom std.Address,
	delegateTo std.Address,
	delegateAmount int64,
	createdAt int64,
) *Delegation {
	return &Delegation{
		id:               id,
		delegateFrom:     delegateFrom,
		delegateTo:       delegateTo,
		delegateAmount:   delegateAmount,
		createdAt:        createdAt,
		unDelegateAmount: 0,
		collectedAmount:  0,
		withdraws:        make([]*DelegationWithdraw, 0),
	}
}
