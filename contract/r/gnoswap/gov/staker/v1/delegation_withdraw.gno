package v1

import (
	"gno.land/r/gnoswap/gov/staker"
)

type DelegationWithdrawResolver struct {
	withdraw *staker.DelegationWithdraw
}

func NewDelegationWithdrawResolver(withdraw *staker.DelegationWithdraw) *DelegationWithdrawResolver {
	return &DelegationWithdrawResolver{withdraw}
}

func (r *DelegationWithdrawResolver) Get() *staker.DelegationWithdraw {
	return r.withdraw
}

// CollectableAmount calculates the amount available for collection at the given time.
// Returns zero if the withdrawal is not yet collectable or has been fully collected.
//
// Parameters:
//   - currentTime: current timestamp to check collectability against
//
// Returns:
//   - int64: amount available for collection
func (r *DelegationWithdrawResolver) CollectableAmount(currentTime int64) int64 {
	if r.IsCollectable(currentTime) {
		return r.withdraw.UnDelegateAmount() - r.withdraw.CollectedAmount()
	}

	return 0
}

// IsCollectable determines whether the withdrawal can be collected at the given time.
// A withdrawal is collectable if:
// - The undelegated amount is positive
// - There is remaining uncollected amount
// - The current time is at or after the collectable time
//
// Parameters:
//   - currentTime: current timestamp to check against
//
// Returns:
//   - bool: true if the withdrawal can be collected, false otherwise
func (r *DelegationWithdrawResolver) IsCollectable(currentTime int64) bool {
	if r.withdraw.UnDelegateAmount() <= 0 {
		return false
	}

	if r.withdraw.UnDelegateAmount()-r.withdraw.CollectedAmount() <= 0 {
		return false
	}

	if currentTime < r.withdraw.CollectableTime() {
		return false
	}

	return true
}

// IsCollected returns whether the withdrawal has been fully collected.
//
// Returns:
//   - bool: true if fully collected, false otherwise
func (r *DelegationWithdrawResolver) IsCollected() bool {
	return r.withdraw.IsCollected()
}

// collect processes the collection of the specified amount from this withdrawal.
// This method validates collectability and updates the collection state.
//
// Parameters:
//   - amount: amount to collect
//   - currentTime: current timestamp
//
// Returns:
//   - error: nil on success, error if collection is not allowed
func (r *DelegationWithdrawResolver) Collect(amount int64, currentTime int64) error {
	if !r.IsCollectable(currentTime) {
		return staker.ErrWithdrawNotCollectable
	}

	r.withdraw.SetCollected(true)
	r.withdraw.SetCollectedAt(currentTime)
	r.withdraw.SetCollectedAmount(safeAddInt64(r.withdraw.CollectedAmount(), amount))

	return nil
}

// NewDelegationWithdraw creates a new delegation withdrawal with lockup period.
// This is a convenience wrapper around staker.NewDelegationWithdraw.
//
// Parameters:
//   - delegationID: unique identifier of the associated delegation
//   - unDelegateAmount: amount being withdrawn
//   - createdHeight: height when the withdrawal was created
//   - createdAt: timestamp when the withdrawal was created
//   - unDelegationLockupPeriod: duration of the lockup period in seconds
//
// Returns:
//   - *staker.DelegationWithdraw: new withdrawal instance with lockup
func NewDelegationWithdraw(
	delegationID,
	unDelegateAmount,
	createdHeight,
	createdAt,
	unDelegationLockupPeriod int64,
) *staker.DelegationWithdraw {
	return staker.NewDelegationWithdraw(
		delegationID,
		unDelegateAmount,
		createdHeight,
		createdAt,
		unDelegationLockupPeriod,
	)
}

// NewDelegationWithdrawWithoutLockup creates a new delegation withdrawal that is immediately collectable.
// This is a convenience wrapper around staker.NewDelegationWithdrawWithoutLockup.
//
// Parameters:
//   - delegationID: unique identifier of the associated delegation
//   - unDelegateAmount: amount being withdrawn
//   - createdHeight: height when the withdrawal was created
//   - createdAt: timestamp when the withdrawal was created
//
// Returns:
//   - *staker.DelegationWithdraw: new withdrawal instance that is immediately collected
func NewDelegationWithdrawWithoutLockup(
	delegationID,
	unDelegateAmount,
	createdHeight,
	createdAt int64,
) *staker.DelegationWithdraw {
	return staker.NewDelegationWithdrawWithoutLockup(
		delegationID,
		unDelegateAmount,
		createdHeight,
		createdAt,
	)
}
