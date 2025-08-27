package staker

// DelegationWithdraw represents a pending withdrawal from a delegation.
// This struct tracks undelegated amounts that are subject to lockup periods
// and manages the collection process once the lockup period expires.
type DelegationWithdraw struct {
	// delegationID is the unique identifier of the associated delegation
	delegationID int64
	// unDelegateAmount is the total amount that was undelegated
	unDelegateAmount int64
	// unDelegatedHeight is the height when the undelegation occurred
	unDelegatedHeight int64
	// unDelegatedAt is the timestamp when the undelegation occurred
	unDelegatedAt int64
	// collectedAmount is the amount that has already been collected
	collectedAmount int64
	// collectableTime is the timestamp when collection becomes available
	collectableTime int64
	// collectedAt is the timestamp when collection occurred
	collectedAt int64
	// collected indicates whether the withdrawal has been fully collected
	collected bool
}

// DelegationID returns the unique identifier of the associated delegation.
//
// Returns:
//   - int64: delegation ID
func (d *DelegationWithdraw) DelegationID() int64 {
	return d.delegationID
}

// UnDelegateAmount returns the total amount that was undelegated.
//
// Returns:
//   - int64: undelegated amount
func (d *DelegationWithdraw) UnDelegateAmount() int64 {
	return d.unDelegateAmount
}

// UnDelegatedAt returns the timestamp when the undelegation occurred.
//
// Returns:
//   - int64: undelegation timestamp
func (d *DelegationWithdraw) UnDelegatedAt() int64 {
	return d.unDelegatedAt
}

// CollectableAmount calculates the amount available for collection at the given time.
// Returns zero if the withdrawal is not yet collectable or has been fully collected.
//
// Parameters:
//   - currentTime: current timestamp to check collectability against
//
// Returns:
//   - int64: amount available for collection
func (d *DelegationWithdraw) CollectableAmount(currentTime int64) int64 {
	if d.IsCollectable(currentTime) {
		return d.unDelegateAmount - d.collectedAmount
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
func (d *DelegationWithdraw) IsCollectable(currentTime int64) bool {
	if d.unDelegateAmount <= 0 {
		return false
	}

	if d.unDelegateAmount-d.collectedAmount <= 0 {
		return false
	}

	if currentTime < d.collectableTime {
		return false
	}

	return true
}

// IsCollected returns whether the withdrawal has been fully collected.
//
// Returns:
//   - bool: true if fully collected, false otherwise
func (d *DelegationWithdraw) IsCollected() bool {
	return d.collected
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
func (d *DelegationWithdraw) collect(amount int64, currentTime int64) error {
	if !d.IsCollectable(currentTime) {
		return errInvalidAmount
	}

	d.collected = true
	d.collectedAt = currentTime
	d.collectedAmount += amount

	return nil
}

// NewDelegationWithdraw creates a new delegation withdrawal with lockup period.
// The withdrawal will be collectable after the lockup period expires.
//
// Parameters:
//   - delegationID: unique identifier of the associated delegation
//   - unDelegateAmount: amount being withdrawn
//   - createdAt: timestamp when the withdrawal was created
//   - unDelegationLockupPeriod: duration of the lockup period in seconds
//
// Returns:
//   - *DelegationWithdraw: new withdrawal instance with lockup
func NewDelegationWithdraw(
	delegationID,
	unDelegateAmount,
	createdHeight,
	createdAt,
	unDelegationLockupPeriod int64,
) *DelegationWithdraw {
	return &DelegationWithdraw{
		delegationID:      delegationID,
		unDelegateAmount:  unDelegateAmount,
		unDelegatedHeight: createdHeight,
		unDelegatedAt:     createdAt,
		collectableTime:   createdAt + unDelegationLockupPeriod,
		collectedAmount:   0,
		collectedAt:       0,
		collected:         false,
	}
}

// NewDelegationWithdrawWithoutLockup creates a new delegation withdrawal that is immediately collectable.
// This is used for special cases like redelegation where no lockup period is required.
//
// Parameters:
//   - delegationID: unique identifier of the associated delegation
//   - unDelegateAmount: amount being withdrawn
//   - createdAt: timestamp when the withdrawal was created
//
// Returns:
//   - *DelegationWithdraw: new withdrawal instance that is immediately collected
func NewDelegationWithdrawWithoutLockup(
	delegationID,
	unDelegateAmount,
	createdHeight,
	createdAt int64,
) *DelegationWithdraw {
	return &DelegationWithdraw{
		delegationID:      delegationID,
		unDelegateAmount:  unDelegateAmount,
		unDelegatedHeight: createdHeight,
		unDelegatedAt:     createdAt,
		collectableTime:   createdAt,
		collectedAmount:   unDelegateAmount,
		collectedAt:       createdAt,
		collected:         true,
	}
}
