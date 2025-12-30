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

// UnDelegatedHeight returns the height when the undelegation occurred.
//
// Returns:
//   - int64: undelegation height
func (d *DelegationWithdraw) UnDelegatedHeight() int64 {
	return d.unDelegatedHeight
}

// CollectedAmount returns the amount that has already been collected.
//
// Returns:
//   - int64: collected amount
func (d *DelegationWithdraw) CollectedAmount() int64 {
	return d.collectedAmount
}

// CollectableTime returns the timestamp when collection becomes available.
//
// Returns:
//   - int64: collectable time
func (d *DelegationWithdraw) CollectableTime() int64 {
	return d.collectableTime
}

// CollectedAt returns the timestamp when collection occurred.
//
// Returns:
//   - int64: collection timestamp
func (d *DelegationWithdraw) CollectedAt() int64 {
	return d.collectedAt
}

// IsCollected returns whether the withdrawal has been fully collected.
//
// Returns:
//   - bool: true if fully collected, false otherwise
func (d *DelegationWithdraw) IsCollected() bool {
	return d.collected
}

// SetCollected sets the collected status.
//
// Parameters:
//   - collected: new collected status
func (d *DelegationWithdraw) SetCollected(collected bool) {
	d.collected = collected
}

// SetCollectedAt sets the collection timestamp.
//
// Parameters:
//   - collectedAt: collection timestamp
func (d *DelegationWithdraw) SetCollectedAt(collectedAt int64) {
	d.collectedAt = collectedAt
}

// SetCollectedAmount sets the collected amount.
//
// Parameters:
//   - amount: collected amount
func (d *DelegationWithdraw) SetCollectedAmount(amount int64) {
	d.collectedAmount = amount
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
		collectableTime:   safeAddInt64(createdAt, unDelegationLockupPeriod),
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
		collectedAmount:   unDelegateAmount, // Immediately collected
		collectedAt:       createdAt,
		collected:         true,
	}
}
