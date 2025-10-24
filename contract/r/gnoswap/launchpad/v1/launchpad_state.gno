package v1

import (
	"gno.land/p/nt/avl"
	"gno.land/r/gnoswap/launchpad"
)

// launchpadState holds all the state variables for launchpad management
type launchpadState struct {
	// projectId -> Project
	projects *avl.Tree

	// projectTierId -> RewardManager
	projectTierRewardManagers *avl.Tree

	// Counter for generating unique deposit IDs
	depositCounter *Counter

	// depositId -> Deposit, Tree storing all deposits by ID
	deposits *avl.Tree
}

// Projects returns the projects tree.
func (ls *launchpadState) Projects() *avl.Tree {
	return ls.projects
}

// ProjectTierRewardManagers returns the project tier reward managers tree.
func (ls *launchpadState) ProjectTierRewardManagers() *avl.Tree {
	return ls.projectTierRewardManagers
}

// DepositCounter returns the deposit counter.
func (ls *launchpadState) DepositCounter() launchpad.Counter {
	return ls.depositCounter
}

// Deposits returns the deposits tree.
func (ls *launchpadState) Deposits() *avl.Tree {
	return ls.deposits
}

// NewLaunchpadState creates a new instance of launchpadState with initialized values
func NewLaunchpadState() launchpad.LaunchpadState {
	return &launchpadState{
		projects:                  avl.NewTree(),
		projectTierRewardManagers: avl.NewTree(),
		depositCounter:            NewCounter(),
		deposits:                  avl.NewTree(),
	}
}
