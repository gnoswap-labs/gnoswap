package launchpad

import (
	"gno.land/p/nt/avl"
	"gno.land/p/nt/ufmt"
)

var (
	// projectId -> Project
	projects *avl.Tree

	// projectTierId -> RewardManager
	projectTierRewardManagers *avl.Tree

	// Counter for generating unique deposit IDs
	depositCounter *Counter

	// depositId -> Deposit, Tree storing all deposits by ID
	deposits *avl.Tree
)

func init() {
	projects = avl.NewTree()
	projectTierRewardManagers = avl.NewTree()

	depositCounter = NewCounter()
	deposits = avl.NewTree()
}

func getProject(projectID string) (*Project, error) {
	project, ok := projects.Get(projectID)
	if !ok {
		return nil, makeErrorWithDetails(errDataNotFound, ufmt.Sprintf("project(%s) not found", projectID))
	}

	p, ok := project.(*Project)
	if !ok {
		return nil, makeErrorWithDetails(errDataNotFound, ufmt.Sprintf("project(%s) not found", projectID))
	}

	return p, nil
}

func getProjectTier(projectID string, tierDuration int64) (*ProjectTier, error) {
	project, err := getProject(projectID)
	if err != nil {
		return nil, err
	}

	tier, ok := project.tiers[tierDuration]
	if !ok {
		return nil, makeErrorWithDetails(errDataNotFound, ufmt.Sprintf("tier(%d) not found", tierDuration))
	}

	return tier, nil
}

func getProjectTierRewardManager(projectTierID string) (*RewardManager, error) {
	rewardManager, ok := projectTierRewardManagers.Get(projectTierID)
	if !ok {
		return nil, makeErrorWithDetails(errDataNotFound, ufmt.Sprintf("reward manager(%s) not found", projectTierID))
	}

	manager, ok := rewardManager.(*RewardManager)
	if !ok {
		return nil, makeErrorWithDetails(errDataNotFound, ufmt.Sprintf("reward manager(%s) not found", projectTierID))
	}

	return manager, nil
}

func mustGetDeposit(depositID string) *Deposit {
	deposit, err := getDeposit(depositID)
	if err != nil {
		panic(err)
	}

	return deposit
}

func getDeposit(depositID string) (*Deposit, error) {
	depositI, ok := deposits.Get(depositID)
	if !ok {
		return nil, makeErrorWithDetails(errNotExistDeposit, ufmt.Sprintf("(%s)", depositID))
	}

	deposit, ok := depositI.(*Deposit)
	if !ok {
		return nil, makeErrorWithDetails(errDataNotFound, ufmt.Sprintf("deposit(%s) not found", depositID))
	}

	return deposit, nil
}

// getCurrentDepositID returns the current deposit ID (last assigned).
func getCurrentDepositID() string {
	return formatInt(depositCounter.Get())
}

// nextDepositID increments and returns the next unique deposit ID.
// This is used when creating new deposits.
func nextDepositID() string {
	return formatInt(depositCounter.next())
}
