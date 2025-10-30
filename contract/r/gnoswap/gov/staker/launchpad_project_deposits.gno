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
