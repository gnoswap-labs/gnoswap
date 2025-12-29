package v1

import (
	"errors"
	"math"

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
	r.delegation.Withdraws().Iterate(0, math.MaxInt64, func(time int64, value any) bool {
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
	remaining := amount
	timesToRemove := make([]int64, 0)

	// Iterate time buckets where collectableTime <= currentTime
	// Note: AVL Iterate uses exclusive end, so we add 1 to make it inclusive
	r.delegation.Withdraws().Iterate(0, currentTime+1, func(collectableTime int64, value any) bool {
		withdraws, ok := value.([]*staker.DelegationWithdraw)
		if !ok {
			return false
		}

		// Process all withdraws in this time bucket
		uncollected, collected := r.processTimeBucket(withdraws, &remaining, currentTime)

		// Update tree based on results
		if len(uncollected) == 0 {
			timesToRemove = append(timesToRemove, collectableTime)
		} else if collected > 0 {
			r.delegation.Withdraws().Set(collectableTime, uncollected)
		}

		return false
	})

	// Clean up empty time buckets
	for _, time := range timesToRemove {
		r.delegation.Withdraws().Remove(time)
	}

	return nil
}

// processTimeBucket processes all withdraws in a single time bucket
// Returns (uncollected withdraws, number of withdraws collected)
func (r *DelegationResolver) processTimeBucket(withdraws []*staker.DelegationWithdraw, remaining *int64, currentTime int64) ([]*staker.DelegationWithdraw, int) {
	uncollected := make([]*staker.DelegationWithdraw, 0, len(withdraws))
	numCollected := 0

	for _, withdraw := range withdraws {
		if *remaining > 0 {
			collected := r.tryCollectFromWithdraw(withdraw, remaining, currentTime)
			if collected > 0 {
				numCollected++
			}
		}

		// Keep withdraw if not fully collected
		if !withdraw.IsCollected() {
			uncollected = append(uncollected, withdraw)
		}
	}

	return uncollected, numCollected
}

// tryCollectFromWithdraw attempts to collect from a single withdraw
// Returns the amount collected
func (r *DelegationResolver) tryCollectFromWithdraw(withdraw *staker.DelegationWithdraw, remaining *int64, currentTime int64) int64 {
	resolver := NewDelegationWithdrawResolver(withdraw)
	collectableAmount := resolver.CollectableAmount(currentTime)

	if collectableAmount == 0 {
		return 0
	}

	// Collect up to remaining amount
	amountToCollect := min(*remaining, collectableAmount)
	if err := resolver.Collect(amountToCollect, currentTime); err != nil {
		return 0
	}

	// Update delegation's total collected amount
	newTotal := safeAddInt64(r.delegation.CollectedAmount(), amountToCollect)
	r.delegation.SetCollectedAmount(newTotal)

	// Update remaining
	*remaining = safeSubInt64(*remaining, amountToCollect)

	return amountToCollect
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
