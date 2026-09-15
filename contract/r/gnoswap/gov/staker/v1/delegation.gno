package staker

import (
	"errors"

	gnsmath "gno.land/p/gnoswap/gnsmath/v1"

	"gno.land/r/gnoswap/gov/staker"
)

const errCollectAmountExceedsCollectable = "amount to collect is greater than collectable amount"

type DelegationResolver struct {
	delegation *staker.Delegation
}

// NewDelegationResolver wraps a delegation in a resolver for derived amounts and withdrawals.
//
// Parameters:
//   - delegation: delegation state to resolve
//
// Returns:
//   - *DelegationResolver: resolver backed by delegation
func NewDelegationResolver(delegation *staker.Delegation) *DelegationResolver {
	return &DelegationResolver{delegation}
}

// Get returns the underlying delegation state.
//
// Returns:
//   - *staker.Delegation: wrapped delegation instance
func (r *DelegationResolver) Get() *staker.Delegation {
	return r.delegation
}

// DelegatedAmount returns total delegated amount minus amount already undelegated.
//
// Returns:
//   - int64: amount still delegated
func (r *DelegationResolver) DelegatedAmount() int64 {
	return gnsmath.SafeSubInt64(r.delegation.TotalDelegatedAmount(), r.delegation.UnDelegatedAmount())
}

// LockedAmount returns total delegated amount minus amount already collected.
//
// Returns:
//   - int64: amount still locked in the delegation
func (r *DelegationResolver) LockedAmount() int64 {
	return gnsmath.SafeSubInt64(r.delegation.TotalDelegatedAmount(), r.delegation.CollectedAmount())
}

// IsEmpty reports whether no locked delegation amount remains.
//
// Returns:
//   - bool: true when LockedAmount is zero, otherwise false
func (r *DelegationResolver) IsEmpty() bool {
	return r.LockedAmount() == 0
}

// CollectableAmount calculates the total amount that can be collected at the given time.
//
// Parameters:
//   - currentTime: current Unix timestamp used to evaluate each withdrawal's lockup
//
// Returns:
//   - total: sum of all withdrawal amounts currently available for collection
func (r *DelegationResolver) CollectableAmount(currentTime int64) (total int64) {
	for _, withdraw := range r.delegation.Withdraws() {
		total = gnsmath.SafeAddInt64(total, NewDelegationWithdrawResolver(&withdraw).CollectableAmount(currentTime))
	}

	return total
}

// UnDelegate processes an undelegation with a time-based lockup period.
//
// Parameters:
//   - amount: amount to undelegate and place into a withdrawal
//   - currentHeight: block height at which the undelegation is recorded
//   - currentTimestamp: Unix timestamp at which the undelegation is recorded
//   - unDelegationLockupPeriod: lockup duration in seconds before the withdrawal is collectible
func (r *DelegationResolver) UnDelegate(
	amount, currentHeight, currentTimestamp, unDelegationLockupPeriod int64,
) {
	r.delegation.SetUnDelegateAmount(gnsmath.SafeAddInt64(r.delegation.UnDelegatedAmount(), amount))

	withdraw := NewDelegationWithdraw(
		r.delegation.ID(),
		amount,
		currentHeight,
		currentTimestamp,
		unDelegationLockupPeriod,
	)
	r.delegation.AddWithdraw(withdraw)
}

// UnDelegateWithoutLockup processes an immediate undelegation without lockup.
//
// Parameters:
//   - amount: amount to undelegate and mark as collected immediately
//   - currentHeight: current block height context; retained for API symmetry and unused by this immediate path
//   - currentTime: current Unix timestamp context; retained for API symmetry and unused by this immediate path
func (r *DelegationResolver) UnDelegateWithoutLockup(
	amount, currentHeight, currentTime int64,
) {
	r.delegation.SetUnDelegateAmount(gnsmath.SafeAddInt64(r.delegation.UnDelegatedAmount(), amount))
	r.delegation.SetCollectedAmount(gnsmath.SafeAddInt64(r.delegation.CollectedAmount(), amount))
}

// processCollection handles the actual collection logic
func (r *DelegationResolver) processCollection(currentTime int64) (int64, error) {
	collectedAmount := int64(0)
	withdraws := r.delegation.Withdraws()

	for i := range withdraws {
		resolver := NewDelegationWithdrawResolver(&withdraws[i])

		collectableAmount := resolver.CollectableAmount(currentTime)
		if collectableAmount <= 0 {
			continue
		}

		err := resolver.Collect(collectableAmount, currentTime)
		if err != nil {
			return 0, err
		}

		updatedAmount, err := addToCollectedAmount(r.delegation.CollectedAmount(), collectableAmount)
		if err != nil {
			return 0, err
		}

		r.delegation.SetCollectedAmount(updatedAmount)
		collectedAmount = gnsmath.SafeAddInt64(collectedAmount, collectableAmount)
	}

	// Skip filtering if nothing was collected
	if collectedAmount == 0 {
		return collectedAmount, nil
	}

	currentIndex := 0

	for i := range withdraws {
		if !withdraws[i].IsCollected() {
			r.delegation.SetWithdraw(currentIndex, withdraws[i])
			currentIndex++
		}
	}

	r.delegation.SetWithdraws(withdraws[:currentIndex])

	return collectedAmount, nil
}

func addToCollectedAmount(collectedAmount, amount int64) (int64, error) {
	if amount < 0 {
		return 0, errors.New(errAmountMustBeNonNegative)
	}
	return gnsmath.SafeAddInt64(collectedAmount, amount), nil
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
