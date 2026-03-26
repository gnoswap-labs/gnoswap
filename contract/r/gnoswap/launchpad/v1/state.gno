package v1

import (
	avl "gno.land/p/nt/avl/v0"
	ufmt "gno.land/p/nt/ufmt/v0"
	"gno.land/r/gnoswap/launchpad"
)

// Helper functions that access state through launchpadState

func (lp *launchpadV1) getProject(projectID string) (*launchpad.Project, error) {
	project, exists := lp.store.GetProject(projectID)
	if exists {
		return project, nil
	}

	projects := lp.store.GetProjects()
	projectI, ok := projects.Get(projectID)
	if !ok {
		return nil, makeErrorWithDetails(errDataNotFound, ufmt.Sprintf("project(%s) not found", projectID))
	}

	p, ok := projectI.(*launchpad.Project)
	if !ok {
		return nil, makeErrorWithDetails(errDataNotFound, ufmt.Sprintf("project(%s) not found", projectID))
	}

	return p, nil
}

func (lp *launchpadV1) setProject(projectID string, project *launchpad.Project) error {
	projectIDs := avl.NewTree()
	if lp.store.HasProjectIDsKey() {
		projectIDs = lp.store.GetProjectIDs()
	}
	projectIDs.Set(projectID, true)

	if err := lp.store.SetProject(projectID, project); err != nil {
		return err
	}

	if err := lp.store.SetProjectIDs(projectIDs); err != nil {
		return err
	}

	return nil
}

func (lp *launchpadV1) getAllProjectIDs() *avl.Tree {
	projectIDs := avl.NewTree()

	if lp.store.HasProjectIDsKey() {
		storedProjectIDs := lp.store.GetProjectIDs()
		storedProjectIDs.Iterate("", "", func(key string, value interface{}) bool {
			projectIDs.Set(key, true)
			return false
		})
	}

	if lp.store.HasProjectsKey() {
		projects := lp.store.GetProjects()
		projects.Iterate("", "", func(key string, value interface{}) bool {
			projectIDs.Set(key, true)
			return false
		})
	}

	return projectIDs
}

func (lp *launchpadV1) getProjectTier(projectID string, tierDuration int64) (*launchpad.ProjectTier, error) {
	project, err := lp.getProject(projectID)
	if err != nil {
		return nil, err
	}

	tier, err := project.GetTier(tierDuration)
	if err != nil {
		return nil, makeErrorWithDetails(errDataNotFound, err.Error())
	}

	return tier, nil
}

func (lp *launchpadV1) getProjectTierRewardManager(projectTierID string) (*launchpad.RewardManager, error) {
	rewardManager, exists := lp.store.GetProjectTierRewardManager(projectTierID)
	if exists {
		return rewardManager, nil
	}

	managers := lp.store.GetProjectTierRewardManagers()
	rewardManagerI, ok := managers.Get(projectTierID)
	if !ok {
		return nil, makeErrorWithDetails(errDataNotFound, ufmt.Sprintf("reward manager(%s) not found", projectTierID))
	}

	manager, ok := rewardManagerI.(*launchpad.RewardManager)
	if !ok {
		return nil, makeErrorWithDetails(errDataNotFound, ufmt.Sprintf("reward manager(%s) not found", projectTierID))
	}

	return manager, nil
}

func (lp *launchpadV1) setProjectTierRewardManager(projectTierID string, rewardManager *launchpad.RewardManager) error {
	managerIDs := avl.NewTree()
	if lp.store.HasProjectTierRewardManagerIDsKey() {
		managerIDs = lp.store.GetProjectTierRewardManagerIDs()
	}
	managerIDs.Set(projectTierID, true)

	if err := lp.store.SetProjectTierRewardManager(projectTierID, rewardManager); err != nil {
		return err
	}

	if err := lp.store.SetProjectTierRewardManagerIDs(managerIDs); err != nil {
		return err
	}

	return nil
}

func (lp *launchpadV1) getAllProjectTierRewardManagerIDs() *avl.Tree {
	managerIDs := avl.NewTree()

	if lp.store.HasProjectTierRewardManagerIDsKey() {
		storedManagerIDs := lp.store.GetProjectTierRewardManagerIDs()
		storedManagerIDs.Iterate("", "", func(key string, value interface{}) bool {
			managerIDs.Set(key, true)
			return false
		})
	}

	if lp.store.HasProjectTierRewardManagersKey() {
		managers := lp.store.GetProjectTierRewardManagers()
		managers.Iterate("", "", func(key string, value interface{}) bool {
			managerIDs.Set(key, true)
			return false
		})
	}

	return managerIDs
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
