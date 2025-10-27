package staker

import (
	"gno.land/p/nt/avl"
)

// LaunchpadProjectDeposits manages deposit amounts for launchpad projects.
// It tracks the total staked amount for each project identified by owner address.
type LaunchpadProjectDeposits struct {
	// deposits maps owner address to deposit amount
	deposits *avl.Tree // string -> int64
}

// NewLaunchpadProjectDeposits creates a new instance of LaunchpadProjectDeposits.
func NewLaunchpadProjectDeposits() *LaunchpadProjectDeposits {
	return &LaunchpadProjectDeposits{
		deposits: avl.NewTree(),
	}
}

// GetDeposits returns the entire deposits tree.
func (lpd *LaunchpadProjectDeposits) GetDeposits() *avl.Tree {
	return lpd.deposits
}

// SetDeposits sets the entire deposits tree.
func (lpd *LaunchpadProjectDeposits) SetDeposits(deposits *avl.Tree) {
	lpd.deposits = deposits
}

// GetDeposit retrieves the deposit amount for a specific owner.
func (lpd *LaunchpadProjectDeposits) GetDeposit(ownerAddress string) (int64, bool) {
	deposit, exists := lpd.deposits.Get(ownerAddress)
	if !exists {
		return 0, false
	}
	
	amount, ok := deposit.(int64)
	if !ok {
		return 0, false
	}
	
	return amount, true
}

// SetDeposit sets the deposit amount for a specific owner.
func (lpd *LaunchpadProjectDeposits) SetDeposit(ownerAddress string, amount int64) {
	lpd.deposits.Set(ownerAddress, amount)
}

// RemoveDeposit removes the deposit for a specific owner.
func (lpd *LaunchpadProjectDeposits) RemoveDeposit(ownerAddress string) {
	lpd.deposits.Remove(ownerAddress)
}