package v1

import (
	"gno.land/p/nt/ufmt"
)

// Helper functions that access state through launchpadState

func (lp *launchpadV1) getProject(projectID string) (*Project, error) {
	projects := lp.store.GetProjects()
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

func (lp *launchpadV1) getProjectTier(projectID string, tierDuration int64) (*ProjectTier, error) {
	project, err := lp.getProject(projectID)
	if err != nil {
		return nil, err
	}

	tier, ok := project.tiers[tierDuration]
	if !ok {
		return nil, makeErrorWithDetails(errDataNotFound, ufmt.Sprintf("tier(%d) not found", tierDuration))
	}

	return tier, nil
}

func (lp *launchpadV1) getProjectTierRewardManager(projectTierID string) (*RewardManager, error) {
	managers := lp.store.GetProjectTierRewardManagers()
	rewardManager, ok := managers.Get(projectTierID)
	if !ok {
		return nil, makeErrorWithDetails(errDataNotFound, ufmt.Sprintf("reward manager(%s) not found", projectTierID))
	}

	manager, ok := rewardManager.(*RewardManager)
	if !ok {
		return nil, makeErrorWithDetails(errDataNotFound, ufmt.Sprintf("reward manager(%s) not found", projectTierID))
	}

	return manager, nil
}

func (lp *launchpadV1) mustGetDeposit(depositID string) *Deposit {
	deposit, err := lp.getDeposit(depositID)
	if err != nil {
		panic(err)
	}

	return deposit
}

func (lp *launchpadV1) getDeposit(depositID string) (*Deposit, error) {
	deposits := lp.store.GetDeposits()
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
func (lp *launchpadV1) getCurrentDepositID() string {
	counter := lp.store.GetDepositCounter()
	return formatInt(counter.Get())
}

// nextDepositID increments and returns the next unique deposit ID.
// This is used when creating new deposits.
func (lp *launchpadV1) nextDepositID() string {
	counter := lp.store.GetDepositCounter()
	return formatInt(counter.Next())
}
