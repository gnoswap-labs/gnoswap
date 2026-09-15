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

// NewLaunchpadProjectDeposits creates an empty owner-to-deposit tree.
//
// Returns:
//   - *LaunchpadProjectDeposits: deposit manager initialized with an empty tree.
func NewLaunchpadProjectDeposits() *LaunchpadProjectDeposits {
	return &LaunchpadProjectDeposits{
		deposits: bptree.NewBPTreeN(16),
	}
}

// GetDeposits returns the owner-to-deposit tree managed by this instance.
//
// Returns:
//   - *bptree.BPTree: tree keyed by owner address string and storing int64 amounts.
func (lpd *LaunchpadProjectDeposits) GetDeposits() *bptree.BPTree {
	return lpd.deposits
}

// SetDeposits replaces the owner-to-deposit tree.
//
// Parameters:
//   - deposits: tree keyed by owner address string and storing int64 amounts.
func (lpd *LaunchpadProjectDeposits) SetDeposits(deposits *bptree.BPTree) {
	lpd.deposits = deposits
}

// GetDeposit looks up a project's deposit by owner address.
//
// Parameters:
//   - ownerAddress: owner address string used as the deposit key.
//
// Returns:
//   - int64: stored deposit amount in the smallest token unit, or zero when absent.
//   - bool: true when an int64 deposit is stored for the owner.
func (lpd *LaunchpadProjectDeposits) GetDeposit(ownerAddress string) (int64, bool) {
	deposit := lpd.deposits.Get(ownerAddress)
	if deposit == nil {
		return 0, false
	}
	amount, ok := deposit.(int64)
	return amount, ok
}

// SetDeposit stores or replaces an owner's deposit amount.
//
// Parameters:
//   - ownerAddress: owner address string used as the deposit key.
//   - amount: deposit amount in the smallest token unit.
func (lpd *LaunchpadProjectDeposits) SetDeposit(ownerAddress string, amount int64) {
	lpd.deposits.Set(ownerAddress, amount)
}

// RemoveDeposit removes an owner's deposit entry.
//
// Parameters:
//   - ownerAddress: owner address string whose deposit entry should be removed.
//
// Returns:
//   - bool: true when an entry was removed; false when no entry existed.
func (lpd *LaunchpadProjectDeposits) RemoveDeposit(ownerAddress string) bool {
	_, ok := lpd.deposits.Remove(ownerAddress)
	return ok
}
