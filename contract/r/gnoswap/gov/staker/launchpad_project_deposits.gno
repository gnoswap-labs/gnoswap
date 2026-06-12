package staker

import (
	bptree "gno.land/p/nt/bptree/v0"
)

// LaunchpadProjectDeposits manages deposit amounts for launchpad projects.
// It tracks the total staked amount for each project identified by owner address.
type LaunchpadProjectDeposits struct {
	// deposits maps owner address to deposit amount
	deposits *bptree.BPTree // string -> int64
}

// NewLaunchpadProjectDeposits creates a new instance of LaunchpadProjectDeposits.
func NewLaunchpadProjectDeposits() *LaunchpadProjectDeposits {
	return &LaunchpadProjectDeposits{
		deposits: bptree.NewBPTreeN(16),
	}
}

// GetDeposits returns the entire deposits tree.
func (lpd *LaunchpadProjectDeposits) GetDeposits() *bptree.BPTree {
	return lpd.deposits
}

// SetDeposits sets the entire deposits tree.
func (lpd *LaunchpadProjectDeposits) SetDeposits(deposits *bptree.BPTree) {
	lpd.deposits = deposits
}

func (lpd *LaunchpadProjectDeposits) GetDeposit(ownerAddress string) (int64, bool) {
	deposit, exists := lpd.deposits.Get(ownerAddress)
	if !exists {
		return 0, false
	}
	amount, ok := deposit.(int64)
	return amount, ok
}

func (lpd *LaunchpadProjectDeposits) SetDeposit(ownerAddress string, amount int64) {
	lpd.deposits.Set(ownerAddress, amount)
}

func (lpd *LaunchpadProjectDeposits) RemoveDeposit(ownerAddress string) bool {
	_, ok := lpd.deposits.Remove(ownerAddress)
	return ok
}
