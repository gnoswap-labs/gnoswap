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
	r.delegation.Withdraws().Iterate(0, currentTime+1, func(time int64, value any) bool {
		if withdraws, ok := value.([]*staker.DelegationWithdraw); ok {
			for _, withdraw := range withdraws {
				total = safeAddInt64(total, NewDelegationWithdrawResolver(withdraw).CollectableAmount(currentTime))
			}
		}
		return false
	})
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
	if amount < 0 {
		return nil
	}

	collected, err := r.processCollectionInternal(amount, currentTime)
	if err != nil {
		return err
	}

	if collected > 0 {
		newTotal := safeAddInt64(r.delegation.CollectedAmount(), collected)
		r.delegation.SetCollectedAmount(newTotal)
	}

	return nil
}

// processCollectionAll collects all available amounts without pre-calculating
// Returns the total amount collected and any error encountered
func (r *DelegationResolver) processCollectionAll(currentTime int64) (int64, error) {
	collected, err := r.processCollectionInternal(0, currentTime)
	if err != nil {
		return 0, err
	}

	if collected > 0 {
		newTotal := safeAddInt64(r.delegation.CollectedAmount(), collected)
		r.delegation.SetCollectedAmount(newTotal)
	}

	return collected, nil
}

// processCollectionInternal is the core collection logic
// If maxAmount <= 0, collects all available amounts
// Otherwise, collects up to maxAmount
func (r *DelegationResolver) processCollectionInternal(maxAmount, currentTime int64) (int64, error) {
	collectAll := maxAmount <= 0
	remaining := maxAmount
	totalCollected := int64(0)
	withdrawsTree := r.delegation.Withdraws()

	var err error

	withdrawsTree.Iterate(0, currentTime+1, func(collectableTime int64, value any) bool {
		withdraws, ok := value.([]*staker.DelegationWithdraw)
		if !ok {
			return false
		}

		collectedWithdrawIndexes := make(map[int]bool)

		for index, withdraw := range withdraws {
			// Stop if we've collected enough (only when maxAmount specified)
			if !collectAll && remaining <= 0 {
				break
			}

			resolver := NewDelegationWithdrawResolver(withdraw)

			collectableAmount := resolver.CollectableAmount(currentTime)
			if collectableAmount <= 0 {
				continue
			}

			// Determine how much to collect from this withdraw
			var amountToCollect int64
			if collectAll {
				amountToCollect = collectableAmount
			} else {
				amountToCollect = min(remaining, collectableAmount)
			}

			iErr := resolver.Collect(amountToCollect, currentTime)
			if iErr != nil {
				err = iErr
				return true
			}

			if !collectAll {
				remaining = safeSubInt64(remaining, amountToCollect)
			}
			totalCollected = safeAddInt64(totalCollected, amountToCollect)

			if withdraw.IsCollected() {
				collectedWithdrawIndexes[index] = true
			}
		}

		// Cleanup collected withdraws
		if len(withdraws) == len(collectedWithdrawIndexes) {
			withdrawsTree.Remove(collectableTime)
		} else {
			updatedWithdraws := make([]*staker.DelegationWithdraw, 0)
			for index, withdraw := range withdraws {
				if collectedWithdrawIndexes[index] {
					continue
				}
				updatedWithdraws = append(updatedWithdraws, withdraw)
			}
			withdrawsTree.Set(collectableTime, updatedWithdraws)
		}

		// Stop iteration early if we've collected enough (only when maxAmount specified)
		return !collectAll && remaining <= 0
	})

	return totalCollected, err
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
