package staker

import "std"

// Error message constants
const (
	errCollectAmountExceedsCollectable = "amount to collect is greater than collectable amount"
	errOverflowInCollectedAmount       = "overflow in delegation collected amount: current(%d) + collect(%d)"
)

// DelegationType represents the type of delegation operation
type DelegationType string

const (
	DelegateType   DelegationType = "DELEGATE"
	UnDelegateType DelegationType = "UNDELEGATE"
)

func (d DelegationType) String() string     { return string(d) }
func (d DelegationType) IsDelegate() bool   { return d == DelegateType }
func (d DelegationType) IsUnDelegate() bool { return d == UnDelegateType }

// Delegation represents a delegation between two addresses
type Delegation struct {
	id               int64
	delegateAmount   int64
	unDelegateAmount int64
	collectedAmount  int64
	delegateFrom     std.Address
	delegateTo       std.Address
	createdHeight    int64
	createdAt        int64
	withdraws        []*DelegationWithdraw
}

// NewDelegation creates a new delegation
func NewDelegation(
	id int64,
	delegateFrom, delegateTo std.Address,
	delegateAmount, createdHeight, createdAt int64,
) *Delegation {
	return &Delegation{
		id:               id,
		delegateFrom:     delegateFrom,
		delegateTo:       delegateTo,
		delegateAmount:   delegateAmount,
		createdHeight:    createdHeight,
		createdAt:        createdAt,
		unDelegateAmount: 0,
		collectedAmount:  0,
		withdraws:        make([]*DelegationWithdraw, 0),
	}
}

// Basic getters
func (d *Delegation) ID() int64                 { return d.id }
func (d *Delegation) DelegateFrom() std.Address { return d.delegateFrom }
func (d *Delegation) DelegateTo() std.Address   { return d.delegateTo }
func (d *Delegation) CreatedAt() int64          { return d.createdAt }

// Amount getters
func (d *Delegation) TotalDelegatedAmount() int64 { return d.delegateAmount }
func (d *Delegation) UnDelegatedAmount() int64    { return d.unDelegateAmount }
func (d *Delegation) CollectedAmount() int64      { return d.collectedAmount }

// Calculated amounts
func (d *Delegation) DelegatedAmount() int64 { return d.delegateAmount - d.unDelegateAmount }
func (d *Delegation) LockedAmount() int64    { return d.delegateAmount - d.collectedAmount }
func (d *Delegation) IsEmpty() bool          { return d.LockedAmount() == 0 }

// CollectableAmount calculates the total amount that can be collected at the given time
func (d *Delegation) CollectableAmount(currentTime int64) (total int64) {
	for _, withdraw := range d.withdraws {
		total += withdraw.CollectableAmount(currentTime)
	}
	return
}

// unDelegate processes an undelegation with lockup period
func (d *Delegation) unDelegate(
	amount, currentHeight, currentTimestamp, unDelegationLockupPeriod int64,
) {
	d.unDelegateAmount += amount
	d.withdraws = append(d.withdraws, NewDelegationWithdraw(
		d.id,
		amount,
		currentHeight,
		currentTimestamp,
		unDelegationLockupPeriod,
	))
}

// UnDelegateWithoutLockup processes an immediate undelegation without lockup
func (d *Delegation) unDelegateWithoutLockup(
	amount, currentHeight, currentTime int64,
) {
	d.unDelegateAmount += amount
	d.collectedAmount += amount
	d.withdraws = append(d.withdraws, NewDelegationWithdrawWithoutLockup(
		d.id,
		amount,
		currentHeight,
		currentTime,
	))
}

// Collect processes the collection of available amounts
func (d *Delegation) collect(amount, currentTime int64) error {
	if amount > d.CollectableAmount(currentTime) {
		return makeErrorWithDetails(
			errInvalidAmount,
			errCollectAmountExceedsCollectable,
		)
	}

	return d.processCollection(amount, currentTime)
}

// processCollection handles the actual collection logic
func (d *Delegation) processCollection(amount, currentTime int64) error {
	remainingToCollect := amount

	for _, withdraw := range d.withdraws {
		if remainingToCollect <= 0 {
			break
		}

		if !withdraw.IsCollectable(currentTime) {
			continue
		}

		collectableAmount := withdraw.CollectableAmount(currentTime)
		if collectableAmount <= 0 {
			continue
		}

		amountToCollect := min(remainingToCollect, collectableAmount)

		if err := withdraw.collect(amountToCollect, currentTime); err != nil {
			return err
		}

		updatedAmount, err := addToCollectedAmount(d.collectedAmount, amountToCollect)
		if err != nil {
			return err
		}
		d.collectedAmount = updatedAmount
		remainingToCollect -= amountToCollect
	}

	return nil
}

func addToCollectedAmount(collectedAmount, amount int64) (int64, error) {
	return collectedAmount + amount, nil
}

// min returns the smaller of two int64 values
func min(a, b int64) int64 {
	if a < b {
		return a
	}
	return b
}
