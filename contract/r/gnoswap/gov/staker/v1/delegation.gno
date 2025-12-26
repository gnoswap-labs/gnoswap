package v1

import (
	"errors"

	"gno.land/r/gnoswap/gov/staker"
)

var (
	errCollectAmountExceedsCollectable = errors.New("amount to collect is greater than collectable amount")
)

type DelegationResolver struct {
	delegation *staker.Delegation
}

func NewDelegationResolver(delegation *staker.Delegation) *DelegationResolver {
	return &DelegationResolver{delegation}
}

func (r *DelegationResolver) Get() *staker.Delegation {
	return r.delegation
}

func (r *DelegationResolver) DelegatedAmount() int64 {
	return safeSubInt64(r.delegation.TotalDelegatedAmount(), r.delegation.UnDelegatedAmount())
}

func (r *DelegationResolver) LockedAmount() int64 {
	return safeSubInt64(r.delegation.TotalDelegatedAmount(), r.delegation.CollectedAmount())
}

func (r *DelegationResolver) IsEmpty() bool {
	return r.LockedAmount() == 0
}

// CollectableAmount calculates the total amount that can be collected at the given time
func (r *DelegationResolver) CollectableAmount(currentTime int64) (total int64) {
	for _, withdraw := range r.delegation.Withdraws() {
		total = safeAddInt64(total, NewDelegationWithdrawResolver(withdraw).CollectableAmount(currentTime))
	}
	return total
}

// UnDelegate processes an undelegation with lockup period
func (r *DelegationResolver) UnDelegate(
	amount, currentHeight, currentTimestamp, unDelegationLockupPeriod int64,
) {
	r.delegation.SetUnDelegateAmount(safeAddInt64(r.delegation.UnDelegatedAmount(), amount))

	withdraw := NewDelegationWithdraw(
		r.delegation.ID(),
		amount,
		currentHeight,
		currentTimestamp,
		unDelegationLockupPeriod,
	)
	r.delegation.AddWithdraw(withdraw)
}

// UnDelegateWithoutLockup processes an immediate undelegation without lockup
func (r *DelegationResolver) UnDelegateWithoutLockup(
	amount, currentHeight, currentTime int64,
) {
	r.delegation.SetUnDelegateAmount(safeAddInt64(r.delegation.UnDelegatedAmount(), amount))
	r.delegation.SetCollectedAmount(safeAddInt64(r.delegation.CollectedAmount(), amount))

	withdraw := NewDelegationWithdrawWithoutLockup(
		r.delegation.ID(),
		amount,
		currentHeight,
		currentTime,
	)

	r.delegation.AddWithdraw(withdraw)
}

// Collect processes the collection of available amounts
func (r *DelegationResolver) Collect(amount, currentTime int64) error {
	if amount > r.CollectableAmount(currentTime) {
		return errCollectAmountExceedsCollectable
	}

	return r.processCollection(amount, currentTime)
}

// processCollection handles the actual collection logic
func (r *DelegationResolver) processCollection(amount, currentTime int64) error {
	remainingToCollect := amount

	for _, withdraw := range r.delegation.Withdraws() {
		if remainingToCollect <= 0 {
			break
		}

		resolver := NewDelegationWithdrawResolver(withdraw)

		if !resolver.IsCollectable(currentTime) {
			continue
		}

		collectableAmount := resolver.CollectableAmount(currentTime)
		if collectableAmount <= 0 {
			continue
		}

		amountToCollect := min(remainingToCollect, collectableAmount)

		if err := resolver.Collect(amountToCollect, currentTime); err != nil {
			return err
		}

		updatedAmount, err := addToCollectedAmount(r.delegation.CollectedAmount(), amountToCollect)
		if err != nil {
			return err
		}
		r.delegation.SetCollectedAmount(updatedAmount)
		remainingToCollect = safeSubInt64(remainingToCollect, amountToCollect)
	}

	return nil
}

func addToCollectedAmount(collectedAmount, amount int64) (int64, error) {
	if amount < 0 {
		return 0, errors.New("amount must be non-negative")
	}
	return safeAddInt64(collectedAmount, amount), nil
}

// min returns the smaller of two int64 values
func min(a, b int64) int64 {
	if a < b {
		return a
	}
	return b
}

// NewDelegation creates a new delegation.
// This is a convenience wrapper around staker.NewDelegation.
//
// Parameters:
//   - id: delegation ID
//   - delegateFrom: delegator's address
//   - delegateTo: delegatee's address
//   - delegateAmount: amount to delegate
//   - createdHeight: creation block height
//   - createdAt: creation timestamp
//
// Returns:
//   - *staker.Delegation: new delegation instance
func NewDelegation(
	id int64,
	delegateFrom, delegateTo address,
	delegateAmount, createdHeight, createdAt int64,
) *staker.Delegation {
	return staker.NewDelegation(
		id,
		delegateFrom,
		delegateTo,
		delegateAmount,
		createdHeight,
		createdAt,
	)
}
