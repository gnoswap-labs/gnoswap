package v1

import (
	"time"

	gs "gno.land/r/gnoswap/gov/staker"
	"gno.land/r/gnoswap/launchpad"
)

// GetProjectCount returns the total number of projects.
func (lp *launchpadV1) GetProjectCount() int64 {
	projects := lp.store.GetProjects()
	return int64(projects.Size())
}

// GetDepositCount returns the total number of deposits.
func (lp *launchpadV1) GetDepositCount() int64 {
	deposits := lp.store.GetDeposits()
	return int64(deposits.Size())
}

// GetRewardManagerCount returns the total number of reward managers.
func (lp *launchpadV1) GetRewardManagerCount() int64 {
	managers := lp.store.GetProjectTierRewardManagers()
	return int64(managers.Size())
}

// GetCurrentDepositId returns the current deposit counter value.
func (lp *launchpadV1) GetCurrentDepositId() int64 {
	counter := lp.store.GetDepositCounter()
	return counter.Get()
}

// GetProject retrieves a project by its ID.
// Returns a cloned project to prevent external modification.
// Returns nil and error if project not found.
func (lp *launchpadV1) GetProject(projectId string) (*launchpad.Project, error) {
	projects := lp.store.GetProjects()
	value, exists := projects.Get(projectId)
	if !exists {
		return nil, errProjectNotFound
	}

	project, ok := value.(*launchpad.Project)
	if !ok {
		return nil, errInvalidProjectType
	}

	return project.Clone(), nil
}

// GetDeposit retrieves a deposit by its ID.
// Returns a cloned deposit to prevent external modification.
// Returns nil and error if deposit not found.
func (lp *launchpadV1) GetDeposit(depositId string) (*launchpad.Deposit, error) {
	deposits := lp.store.GetDeposits()
	value, exists := deposits.Get(depositId)
	if !exists {
		return nil, errDepositNotFound
	}

	deposit, ok := value.(*launchpad.Deposit)
	if !ok {
		return nil, errInvalidDepositType
	}

	return deposit.Clone(), nil
}

// GetProjectTier retrieves a specific tier of a project.
// Returns a cloned tier to prevent external modification.
// Returns nil and error if project or tier not found.
func (lp *launchpadV1) GetProjectTier(projectId string, tier int64) (*launchpad.ProjectTier, error) {
	project, err := lp.getProject(projectId)
	if err != nil {
		return nil, err
	}

	projectTier, err := getProjectTier(project, tier)
	if err != nil {
		return nil, err
	}

	return projectTier.Clone(), nil
}

// GetProjectCondition retrieves a specific condition of a project.
// Returns a cloned condition to prevent external modification.
// Returns nil and error if project or condition not found.
func (lp *launchpadV1) GetProjectCondition(projectId string, tokenPath string) (*launchpad.ProjectCondition, error) {
	project, err := lp.getProject(projectId)
	if err != nil {
		return nil, err
	}

	conditions := project.Conditions()
	condition, exists := conditions[tokenPath]
	if !exists {
		return nil, errConditionNotFound
	}

	return condition.Clone(), nil
}

// GetRewardManager retrieves a reward manager by project tier ID.
// Returns a cloned reward manager to prevent external modification.
// Returns nil and error if reward manager not found.
func (lp *launchpadV1) GetRewardManager(projectTierId string) (*launchpad.RewardManager, error) {
	managers := lp.store.GetProjectTierRewardManagers()
	value, exists := managers.Get(projectTierId)
	if !exists {
		return nil, errRewardManagerNotFound
	}

	manager, ok := value.(*launchpad.RewardManager)
	if !ok {
		return nil, errInvalidRewardManagerType
	}

	return manager.Clone(), nil
}

// GetRewardState retrieves a reward state by project tier ID and deposit ID.
// Returns a cloned reward state to prevent external modification.
// Returns nil and error if reward manager or reward state not found.
func (lp *launchpadV1) GetRewardState(projectTierId string, depositId string) (*launchpad.RewardState, error) {
	managers := lp.store.GetProjectTierRewardManagers()
	value, exists := managers.Get(projectTierId)
	if !exists {
		return nil, errRewardManagerNotFound
	}

	manager, ok := value.(*launchpad.RewardManager)
	if !ok {
		return nil, errInvalidRewardManagerType
	}

	rewards := manager.Rewards()
	rewardValue, exists := rewards.Get(depositId)
	if !exists {
		return nil, errRewardStateNotFound
	}

	rewardState, ok := rewardValue.(*launchpad.RewardState)
	if !ok {
		return nil, errInvalidRewardStateType
	}

	return rewardState.Clone(), nil
}

// GetClaimableRewardByProjectId returns the claimable reward for a project's recipient.
// Returns "0" and error if project not found.
func (lp *launchpadV1) GetClaimableRewardByProjectId(projectId string) (string, error) {
	projects := lp.store.GetProjects()
	value, exists := projects.Get(projectId)
	if !exists {
		return "0", errProjectNotFound
	}

	project, ok := value.(*launchpad.Project)
	if !ok {
		return "0", errInvalidProjectType
	}

	return gs.GetClaimableRewardByAddress(project.Recipient()), nil
}

// GetClaimableRewardByAddress returns the claimable reward for a specific address.
// Returns "0" if address is invalid.
func (lp *launchpadV1) GetClaimableRewardByAddress(addr address) string {
	if !addr.IsValid() {
		return "0"
	}

	return gs.GetClaimableRewardByAddress(addr)
}

// GetProjectActiveStatus returns whether a project is currently active.
// Returns false and error if project not found.
func (lp *launchpadV1) GetProjectActiveStatus(projectId string) (bool, error) {
	project, err := lp.getProject(projectId)
	if err != nil {
		return false, err
	}

	currentTime := time.Now().Unix()
	return isProjectActive(project, currentTime), nil
}

// GetProjects returns a paginated list of project IDs.
// Returns empty slice if offset is negative or limit is non-positive.
func (lp *launchpadV1) GetProjects(offset, limit int64) []string {
	if offset < 0 || limit <= 0 {
		return []string{}
	}

	projects := lp.store.GetProjects()
	projectIds := make([]string, 0, limit)
	currentIndex := int64(0)
	collected := int64(0)

	projects.Iterate("", "", func(key string, value interface{}) bool {
		if currentIndex < offset {
			currentIndex++
			return false
		}

		if collected >= limit {
			return true
		}

		projectIds = append(projectIds, key)
		collected++
		currentIndex++
		return false
	})

	return projectIds
}

// GetDeposits returns a paginated list of deposit IDs.
// Returns empty slice if offset is negative or limit is non-positive.
func (lp *launchpadV1) GetDeposits(offset, limit int64) []string {
	if offset < 0 || limit <= 0 {
		return []string{}
	}

	deposits := lp.store.GetDeposits()
	depositIds := make([]string, 0, limit)
	currentIndex := int64(0)
	collected := int64(0)

	deposits.Iterate("", "", func(key string, value interface{}) bool {
		if currentIndex < offset {
			currentIndex++
			return false
		}

		if collected >= limit {
			return true
		}

		depositIds = append(depositIds, key)
		collected++
		currentIndex++
		return false
	})

	return depositIds
}

// GetRewardManagers returns a paginated list of project tier IDs (reward manager keys).
// Returns empty slice if offset is negative or limit is non-positive.
func (lp *launchpadV1) GetRewardManagers(offset, limit int64) []string {
	if offset < 0 || limit <= 0 {
		return []string{}
	}

	managers := lp.store.GetProjectTierRewardManagers()
	managerIds := make([]string, 0, limit)
	currentIndex := int64(0)
	collected := int64(0)

	managers.Iterate("", "", func(key string, value interface{}) bool {
		if currentIndex < offset {
			currentIndex++
			return false
		}

		if collected >= limit {
			return true
		}

		managerIds = append(managerIds, key)
		collected++
		currentIndex++
		return false
	})

	return managerIds
}
