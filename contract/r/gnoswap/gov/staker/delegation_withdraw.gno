package staker

type DelegationWithdraw struct {
	delegationID     int64
	unDelegateAmount int64
	unDelegatedAt    int64
	collectedAmount  int64
	collectableTime  int64
	collectedAt      int64
	collected        bool
}

func (d *DelegationWithdraw) DelegationID() int64 {
	return d.delegationID
}

func (d *DelegationWithdraw) UnDelegateAmount() int64 {
	return d.unDelegateAmount
}

func (d *DelegationWithdraw) UnDelegatedAt() int64 {
	return d.unDelegatedAt
}

func (d *DelegationWithdraw) CollectableAmount(currentTime int64) int64 {
	if d.IsCollectable(currentTime) {
		return d.unDelegateAmount - d.collectedAmount
	}

	return 0
}

func (d *DelegationWithdraw) IsCollectable(currentTime int64) bool {
	if d.unDelegateAmount <= 0 {
		return false
	}

	if d.unDelegateAmount - d.collectedAmount <= 0 {
		return false
	}

	if currentTime < d.collectableTime {
		return false
	}

	return true
}

func (d *DelegationWithdraw) IsCollected() bool {
	return d.collected
}

func (d *DelegationWithdraw) collect(amount int64, currentTime int64) error {
	if !d.IsCollectable(currentTime) {
		return errInvalidAmount
	}

	d.collected = true
	d.collectedAt = currentTime
	d.collectedAmount += amount

	return nil
}

func NewDelegationWithdraw(
	delegationID,
	unDelegateAmount,
	createdAt,
	unDelegationLockupPeriod int64,
) *DelegationWithdraw {
	return &DelegationWithdraw{
		delegationID:     delegationID,
		unDelegateAmount: unDelegateAmount,
		unDelegatedAt:    createdAt,
		collectableTime:  createdAt + unDelegationLockupPeriod,
		collectedAmount:  0,
		collectedAt:      0,
		collected:        false,
	}
}

func NewDelegationWithdrawWithoutLockup(
	delegationID,
	unDelegateAmount,
	createdAt int64,
) *DelegationWithdraw {
	return &DelegationWithdraw{
		delegationID:     delegationID,
		unDelegateAmount: unDelegateAmount,
		unDelegatedAt:    createdAt,
		collectableTime:  createdAt,
		collectedAmount:  unDelegateAmount,
		collectedAt:      createdAt,
		collected:        true,
	}
}
