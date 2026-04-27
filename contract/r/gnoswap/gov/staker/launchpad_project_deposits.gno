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
// TODO: consider NewBPTreeN(64) (RULE 4) — per-project participants, N grows with deposits.
func NewLaunchpadProjectDeposits() *LaunchpadProjectDeposits {
	return &LaunchpadProjectDeposits{
		deposits: bptree.NewBPTree32(),
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
