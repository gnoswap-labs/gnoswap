package v3

import (
	"gno.land/p/nt/ufmt"
	"gno.land/r/gnoswap/launchpad"
)

// Helper functions that access state through launchpadState

func (lp *launchpadV1) getProject(projectID string) (*launchpad.Project, error) {
	projects := lp.store.GetProjects()
	project, ok := projects.Get(projectID)
	if !ok {
		return nil, makeErrorWithDetails(errDataNotFound, ufmt.Sprintf("project(%s) not found", projectID))
	}

	p, ok := project.(*launchpad.Project)
	if !ok {
		return nil, makeErrorWithDetails(errDataNotFound, ufmt.Sprintf("project(%s) not found", projectID))
	}

	return p, nil
}

func (lp *launchpadV1) getProjectTier(projectID string, tierDuration int64) (*launchpad.ProjectTier, error) {
	project, err := lp.getProject(projectID)
	if err != nil {
		return nil, err
	}

	tier, ok := project.Tiers()[tierDuration]
	if !ok {
		return nil, makeErrorWithDetails(errDataNotFound, ufmt.Sprintf("tier(%d) not found", tierDuration))
	}

	return tier, nil
}

func (lp *launchpadV1) getProjectTierRewardManager(projectTierID string) (*launchpad.RewardManager, error) {
	managers := lp.store.GetProjectTierRewardManagers()
	rewardManager, ok := managers.Get(projectTierID)
	if !ok {
		return nil, makeErrorWithDetails(errDataNotFound, ufmt.Sprintf("reward manager(%s) not found", projectTierID))
	}

	manager, ok := rewardManager.(*launchpad.RewardManager)
	if !ok {
		return nil, makeErrorWithDetails(errDataNotFound, ufmt.Sprintf("reward manager(%s) not found", projectTierID))
	}

	return manager, nil
}

func (lp *launchpadV1) mustGetDeposit(depositID string) *launchpad.Deposit {
	deposit, err := lp.getDeposit(depositID)
	if err != nil {
		panic(err)
	}

	return deposit
}

func (lp *launchpadV1) getDeposit(depositID string) (*launchpad.Deposit, error) {
	deposits := lp.store.GetDeposits()
	depositI, ok := deposits.Get(depositID)
	if !ok {
		return nil, makeErrorWithDetails(errNotExistDeposit, ufmt.Sprintf("(%s)", depositID))
	}

	deposit, ok := depositI.(*launchpad.Deposit)
	if !ok {
		return nil, makeErrorWithDetails(errDataNotFound, ufmt.Sprintf("deposit(%s) not found", depositID))
	}

	return deposit, nil
}

// nextDepositID increments and returns the next unique deposit ID.
// This is used when creating new deposits.
func (lp *launchpadV1) nextDepositID() string {
	return lp.store.NextDepositID()
}
