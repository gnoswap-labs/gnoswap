package v1

import (
	"errors"
	"time"

	"gno.land/p/gnoswap/uint256"
	"gno.land/r/gnoswap/launchpad"
)

// GetProjectCount returns the total number of projects.
func (lp *launchpadV1) GetProjectCount() int64 {
	projects := lp.store.GetProjects()
	return int64(projects.Size())
}

// GetProjectIDs returns a paginated list of project IDs.
// Returns empty slice if offset is negative or limit is non-positive.
func (lp *launchpadV1) GetProjectIDs(offset, limit int64) []string {
	if offset < 0 || limit <= 0 {
		return []string{}
	}

	projects := lp.store.GetProjects()
	projectIds := make([]string, 0, limit)
	currentIndex := int64(0)
	collected := int64(0)

	projects.Iterate("", "", func(key string, value any) bool {
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

// GetProject retrieves a project by its ID.
// Returns a cloned project to prevent external modification.
// Returns nil and error if project not found.
func (lp *launchpadV1) GetProject(projectId string) (*launchpad.Project, error) {
	projects := lp.store.GetProjects()
	value, exists := projects.Get(projectId)
	if !exists {
		return nil, errors.New("project not found")
	}

	project, ok := value.(*launchpad.Project)
	if !ok {
		return nil, errors.New("invalid project type")
	}

	return project.Clone(), nil
}

// GetProjectName returns the name of a project by its ID.
// Returns empty string and error if project not found.
func (lp *launchpadV1) GetProjectName(projectId string) (string, error) {
	project, err := lp.getProject(projectId)
	if err != nil {
		return "", err
	}

	return project.Name(), nil
}

// GetProjectTokenPath returns the token path of a project by its ID.
// Returns empty string and error if project not found.
func (lp *launchpadV1) GetProjectTokenPath(projectId string) (string, error) {
	project, err := lp.getProject(projectId)
	if err != nil {
		return "", err
	}

	return project.TokenPath(), nil
}

// GetProjectDepositAmount returns the deposit amount of a project by its ID.
// Returns 0 and error if project not found.
func (lp *launchpadV1) GetProjectDepositAmount(projectId string) (int64, error) {
	project, err := lp.getProject(projectId)
	if err != nil {
		return 0, err
	}

	return project.DepositAmount(), nil
}

// GetProjectRecipient returns the recipient address of a project by its ID.
// Returns empty address and error if project not found.
func (lp *launchpadV1) GetProjectRecipient(projectId string) (address, error) {
	project, err := lp.getProject(projectId)
	if err != nil {
		return address(""), err
	}

	return project.Recipient(), nil
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
		return nil, errors.New("condition not found")
	}

	return condition.Clone(), nil
}

// GetProjectTiersRatios returns the tiers ratios map of a project by its ID.
// Returns empty map and error if project not found.
func (lp *launchpadV1) GetProjectTiersRatios(projectId string) (map[int64]int64, error) {
	project, err := lp.getProject(projectId)
	if err != nil {
		return nil, err
	}

	return project.TiersRatios(), nil
}

// GetProjectCreatedHeight returns the created height of a project by its ID.
// Returns 0 and error if project not found.
func (lp *launchpadV1) GetProjectCreatedHeight(projectId string) (int64, error) {
	project, err := lp.getProject(projectId)
	if err != nil {
		return 0, err
	}

	return project.CreatedHeight(), nil
}

// GetProjectCreatedAt returns the created time of a project by its ID.
// Returns 0 and error if project not found.
func (lp *launchpadV1) GetProjectCreatedAt(projectId string) (int64, error) {
	project, err := lp.getProject(projectId)
	if err != nil {
		return 0, err
	}

	return project.CreatedAt(), nil
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

// GetProjectTierDistributeAmountPerSecondX128 returns the distribute amount per second (Q128) of a project tier.
// Returns 0 and error if project or tier not found.
func (lp *launchpadV1) GetProjectTierDistributeAmountPerSecondX128(projectId string, tier int64) (*uint256.Uint, error) {
	projectTier, err := lp.GetProjectTier(projectId, tier)
	if err != nil {
		return uint256.NewUint(0), err
	}

	return projectTier.DistributeAmountPerSecondX128().Clone(), nil
}

// GetProjectTierTotalDistributeAmount returns the total distribute amount of a project tier.
// Returns 0 and error if project or tier not found.
func (lp *launchpadV1) GetProjectTierTotalDistributeAmount(projectId string, tier int64) (int64, error) {
	projectTier, err := lp.GetProjectTier(projectId, tier)
	if err != nil {
		return 0, err
	}

	return projectTier.TotalDistributeAmount(), nil
}

// GetProjectTierTotalDepositAmount returns the total deposit amount of a project tier.
// Returns 0 and error if project or tier not found.
func (lp *launchpadV1) GetProjectTierTotalDepositAmount(projectId string, tier int64) (int64, error) {
	projectTier, err := lp.GetProjectTier(projectId, tier)
	if err != nil {
		return 0, err
	}

	return projectTier.TotalDepositAmount(), nil
}

// GetProjectTierTotalWithdrawAmount returns the total withdraw amount of a project tier.
// Returns 0 and error if project or tier not found.
func (lp *launchpadV1) GetProjectTierTotalWithdrawAmount(projectId string, tier int64) (int64, error) {
	projectTier, err := lp.GetProjectTier(projectId, tier)
	if err != nil {
		return 0, err
	}

	return projectTier.TotalWithdrawAmount(), nil
}

// GetProjectTierTotalDepositCount returns the total deposit count of a project tier.
// Returns 0 and error if project or tier not found.
func (lp *launchpadV1) GetProjectTierTotalDepositCount(projectId string, tier int64) (int64, error) {
	projectTier, err := lp.GetProjectTier(projectId, tier)
	if err != nil {
		return 0, err
	}

	return projectTier.TotalDepositCount(), nil
}

// GetProjectTierTotalWithdrawCount returns the total withdraw count of a project tier.
// Returns 0 and error if project or tier not found.
func (lp *launchpadV1) GetProjectTierTotalWithdrawCount(projectId string, tier int64) (int64, error) {
	projectTier, err := lp.GetProjectTier(projectId, tier)
	if err != nil {
		return 0, err
	}

	return projectTier.TotalWithdrawCount(), nil
}

// GetProjectTierTotalCollectedAmount returns the total collected amount of a project tier.
// Returns 0 and error if project or tier not found.
func (lp *launchpadV1) GetProjectTierTotalCollectedAmount(projectId string, tier int64) (int64, error) {
	projectTier, err := lp.GetProjectTier(projectId, tier)
	if err != nil {
		return 0, err
	}

	return projectTier.TotalCollectedAmount(), nil
}

// GetProjectTierStartTime returns the start time of a project tier.
// Returns 0 and error if project or tier not found.
func (lp *launchpadV1) GetProjectTierStartTime(projectId string, tier int64) (int64, error) {
	projectTier, err := lp.GetProjectTier(projectId, tier)
	if err != nil {
		return 0, err
	}

	return projectTier.StartTime(), nil
}

// GetProjectTierEndTime returns the end time of a project tier.
// Returns 0 and error if project or tier not found.
func (lp *launchpadV1) GetProjectTierEndTime(projectId string, tier int64) (int64, error) {
	projectTier, err := lp.GetProjectTier(projectId, tier)
	if err != nil {
		return 0, err
	}

	return projectTier.EndTime(), nil
}

// GetDepositCount returns the total number of deposits.
func (lp *launchpadV1) GetDepositCount() int64 {
	deposits := lp.store.GetDeposits()
	return int64(deposits.Size())
}

// GetDeposits returns a paginated list of deposit IDs.
// Returns empty slice if offset is negative or limit is non-positive.
func (lp *launchpadV1) GetDepositIDs(offset, limit int64) []string {
	if offset < 0 || limit <= 0 {
		return []string{}
	}

	deposits := lp.store.GetDeposits()
	depositIds := make([]string, 0, limit)
	currentIndex := int64(0)
	collected := int64(0)

	deposits.Iterate("", "", func(key string, value any) bool {
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

// GetCurrentDepositId returns the current deposit counter value.
func (lp *launchpadV1) GetCurrentDepositId() int64 {
	counter := lp.store.GetDepositCounter()
	return counter.Get()
}

// GetDeposit retrieves a deposit by its ID.
// Returns a cloned deposit to prevent external modification.
// Returns nil and error if deposit not found.
func (lp *launchpadV1) GetDeposit(depositId string) (*launchpad.Deposit, error) {
	deposits := lp.store.GetDeposits()
	value, exists := deposits.Get(depositId)
	if !exists {
		return nil, errors.New("deposit not found")
	}

	deposit, ok := value.(*launchpad.Deposit)
	if !ok {
		return nil, errors.New("invalid deposit type")
	}

	return deposit.Clone(), nil
}

// GetDepositProjectID returns the project ID of a deposit by its ID.
// Returns empty string and error if deposit not found.
func (lp *launchpadV1) GetDepositProjectID(depositId string) (string, error) {
	deposits := lp.store.GetDeposits()
	value, exists := deposits.Get(depositId)
	if !exists {
		return "", errors.New("deposit not found")
	}

	deposit, ok := value.(*launchpad.Deposit)
	if !ok {
		return "", errors.New("invalid deposit type")
	}

	return deposit.ProjectID(), nil
}

// GetDepositTier returns the tier of a deposit by its ID.
// Returns 0 and error if deposit not found.
func (lp *launchpadV1) GetDepositTier(depositId string) (int64, error) {
	deposits := lp.store.GetDeposits()
	value, exists := deposits.Get(depositId)
	if !exists {
		return 0, errors.New("deposit not found")
	}

	deposit, ok := value.(*launchpad.Deposit)
	if !ok {
		return 0, errors.New("invalid deposit type")
	}

	return deposit.Tier(), nil
}

// GetDepositProjectTierID returns the project tier ID of a deposit by its ID.
// Returns empty string and error if deposit not found.
func (lp *launchpadV1) GetDepositProjectTierID(depositId string) (string, error) {
	deposits := lp.store.GetDeposits()
	value, exists := deposits.Get(depositId)
	if !exists {
		return "", errors.New("deposit not found")
	}

	deposit, ok := value.(*launchpad.Deposit)
	if !ok {
		return "", errors.New("invalid deposit type")
	}

	return deposit.ProjectTierID(), nil
}

// GetDepositAmount returns the deposit amount of a deposit by its ID.
// Returns 0 and error if deposit not found.
func (lp *launchpadV1) GetDepositAmount(depositId string) (int64, error) {
	deposits := lp.store.GetDeposits()
	value, exists := deposits.Get(depositId)
	if !exists {
		return 0, errors.New("deposit not found")
	}

	deposit, ok := value.(*launchpad.Deposit)
	if !ok {
		return 0, errors.New("invalid deposit type")
	}

	return deposit.DepositAmount(), nil
}

// GetDepositWithdrawnHeight returns the withdrawn height of a deposit by its ID.
// Returns 0 and error if deposit not found.
func (lp *launchpadV1) GetDepositWithdrawnHeight(depositId string) (int64, error) {
	deposits := lp.store.GetDeposits()
	value, exists := deposits.Get(depositId)
	if !exists {
		return 0, errors.New("deposit not found")
	}

	deposit, ok := value.(*launchpad.Deposit)
	if !ok {
		return 0, errors.New("invalid deposit type")
	}

	return deposit.WithdrawnHeight(), nil
}

// GetDepositWithdrawnTime returns the withdrawn time of a deposit by its ID.
// Returns 0 and error if deposit not found.
func (lp *launchpadV1) GetDepositWithdrawnTime(depositId string) (int64, error) {
	deposits := lp.store.GetDeposits()
	value, exists := deposits.Get(depositId)
	if !exists {
		return 0, errors.New("deposit not found")
	}

	deposit, ok := value.(*launchpad.Deposit)
	if !ok {
		return 0, errors.New("invalid deposit type")
	}

	return deposit.WithdrawnTime(), nil
}

// GetDepositCreatedHeight returns the created height of a deposit by its ID.
// Returns 0 and error if deposit not found.
func (lp *launchpadV1) GetDepositCreatedHeight(depositId string) (int64, error) {
	deposits := lp.store.GetDeposits()
	value, exists := deposits.Get(depositId)
	if !exists {
		return 0, errors.New("deposit not found")
	}

	deposit, ok := value.(*launchpad.Deposit)
	if !ok {
		return 0, errors.New("invalid deposit type")
	}

	return deposit.CreatedHeight(), nil
}

// GetDepositCreatedAt returns the created time of a deposit by its ID.
// Returns 0 and error if deposit not found.
func (lp *launchpadV1) GetDepositCreatedAt(depositId string) (int64, error) {
	deposits := lp.store.GetDeposits()
	value, exists := deposits.Get(depositId)
	if !exists {
		return 0, errors.New("deposit not found")
	}

	deposit, ok := value.(*launchpad.Deposit)
	if !ok {
		return 0, errors.New("invalid deposit type")
	}

	return deposit.CreatedAt(), nil
}

// GetDepositEndTime returns the end time of a deposit by its ID.
// Returns 0 and error if deposit not found.
func (lp *launchpadV1) GetDepositEndTime(depositId string) (int64, error) {
	deposits := lp.store.GetDeposits()
	value, exists := deposits.Get(depositId)
	if !exists {
		return 0, errors.New("deposit not found")
	}

	deposit, ok := value.(*launchpad.Deposit)
	if !ok {
		return 0, errors.New("invalid deposit type")
	}

	return deposit.EndTime(), nil
}

// GetRewardManagerCount returns the total number of reward managers.
func (lp *launchpadV1) GetRewardManagerCount() int64 {
	managers := lp.store.GetProjectTierRewardManagers()
	return int64(managers.Size())
}

// GetRewardManagerIDs returns a paginated list of project tier IDs (reward manager keys).
// Returns empty slice if offset is negative or limit is non-positive.
func (lp *launchpadV1) GetRewardManagerIDs(offset, limit int64) []string {
	if offset < 0 || limit <= 0 {
		return []string{}
	}

	managers := lp.store.GetProjectTierRewardManagers()
	managerIds := make([]string, 0, limit)
	currentIndex := int64(0)
	collected := int64(0)

	managers.Iterate("", "", func(key string, value any) bool {
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

// GetRewardManager retrieves a reward manager by project tier ID.
// Returns a cloned reward manager to prevent external modification.
// Returns nil and error if reward manager not found.
func (lp *launchpadV1) GetRewardManager(projectTierId string) (*launchpad.RewardManager, error) {
	managers := lp.store.GetProjectTierRewardManagers()
	value, exists := managers.Get(projectTierId)
	if !exists {
		return nil, errors.New("reward manager not found")
	}

	manager, ok := value.(*launchpad.RewardManager)
	if !ok {
		return nil, errors.New("invalid reward manager type")
	}

	return manager.Clone(), nil
}

// GetRewardManagerDistibuteAmountPerSecondX128 returns the distribute amount per second (Q128) of a reward manager.
// Returns 0 and error if reward manager not found.
func (lp *launchpadV1) GetRewardManagerDistibuteAmountPerSecondX128(projectTierId string) (*uint256.Uint, error) {
	manager, err := lp.GetRewardManager(projectTierId)
	if err != nil {
		return uint256.NewUint(0), err
	}

	return manager.DistributeAmountPerSecondX128().Clone(), nil
}

// GetRewardManagerAccumulatedRewardPerDepositX128 returns the accumulated reward per deposit (Q128) of a reward manager.
// Returns 0 and error if reward manager not found.
func (lp *launchpadV1) GetRewardManagerAccumulatedRewardPerDepositX128(projectTierId string) (*uint256.Uint, error) {
	manager, err := lp.GetRewardManager(projectTierId)
	if err != nil {
		return uint256.NewUint(0), err
	}

	return manager.AccumulatedRewardPerDepositX128().Clone(), nil
}

// GetRewardManagerTotalDistributeAmount returns the total distribute amount of a reward manager.
// Returns 0 and error if reward manager not found.
func (lp *launchpadV1) GetRewardManagerTotalDistributeAmount(projectTierId string) (int64, error) {
	manager, err := lp.GetRewardManager(projectTierId)
	if err != nil {
		return 0, err
	}

	return manager.TotalDistributeAmount(), nil
}

// GetRewardManagerTotalClaimedAmount returns the total claimed amount of a reward manager.
// Returns 0 and error if reward manager not found.
func (lp *launchpadV1) GetRewardManagerTotalClaimedAmount(projectTierId string) (int64, error) {
	manager, err := lp.GetRewardManager(projectTierId)
	if err != nil {
		return 0, err
	}

	return manager.TotalClaimedAmount(), nil
}

// GetRewardManagerDistributeStartTime returns the distribute start time of a reward manager.
// Returns 0 and error if reward manager not found.
func (lp *launchpadV1) GetRewardManagerDistributeStartTime(projectTierId string) (int64, error) {
	manager, err := lp.GetRewardManager(projectTierId)
	if err != nil {
		return 0, err
	}

	return manager.DistributeStartTime(), nil
}

// GetRewardManagerDistributeEndTime returns the distribute end time of a reward manager.
// Returns 0 and error if reward manager not found.
func (lp *launchpadV1) GetRewardManagerDistributeEndTime(projectTierId string) (int64, error) {
	manager, err := lp.GetRewardManager(projectTierId)
	if err != nil {
		return 0, err
	}

	return manager.DistributeEndTime(), nil
}

// GetRewardManagerAccumulatedDistributeAmount returns the accumulated distribute amount of a reward manager.
// Returns 0 and error if reward manager not found.
func (lp *launchpadV1) GetRewardManagerAccumulatedDistributeAmount(projectTierId string) (int64, error) {
	manager, err := lp.GetRewardManager(projectTierId)
	if err != nil {
		return 0, err
	}

	return manager.AccumulatedDistributeAmount(), nil
}

// GetRewardManagerAccumulatedHeight returns the accumulated height of a reward manager.
// Returns 0 and error if reward manager not found.
func (lp *launchpadV1) GetRewardManagerAccumulatedHeight(projectTierId string) (int64, error) {
	manager, err := lp.GetRewardManager(projectTierId)
	if err != nil {
		return 0, err
	}

	return manager.AccumulatedHeight(), nil
}

// GetRewardManagerAccumulatedTime returns the accumulated time of a reward manager.
// Returns 0 and error if reward manager not found.
func (lp *launchpadV1) GetRewardManagerAccumulatedTime(projectTierId string) (int64, error) {
	manager, err := lp.GetRewardManager(projectTierId)
	if err != nil {
		return 0, err
	}

	return manager.AccumulatedTime(), nil
}

// GetRewardManagerRewardClaimableDuration returns the reward claimable duration of a reward manager.
// Returns 0 and error if reward manager not found.
func (lp *launchpadV1) GetRewardManagerRewardClaimableDuration(projectTierId string) (int64, error) {
	manager, err := lp.GetRewardManager(projectTierId)
	if err != nil {
		return 0, err
	}

	return manager.RewardClaimableDuration(), nil
}

// GetRewardState retrieves a reward state by project tier ID and deposit ID.
// Returns a cloned reward state to prevent external modification.
// Returns nil and error if reward manager or reward state not found.
func (lp *launchpadV1) GetRewardState(projectTierId string, depositId string) (*launchpad.RewardState, error) {
	managers := lp.store.GetProjectTierRewardManagers()
	value, exists := managers.Get(projectTierId)
	if !exists {
		return nil, errors.New("reward manager not found")
	}

	manager, ok := value.(*launchpad.RewardManager)
	if !ok {
		return nil, errors.New("invalid reward manager type")
	}

	rewards := manager.Rewards()
	rewardValue, exists := rewards.Get(depositId)
	if !exists {
		return nil, errors.New("reward state not found")
	}

	rewardState, ok := rewardValue.(*launchpad.RewardState)
	if !ok {
		return nil, errors.New("invalid reward state type")
	}

	return rewardState.Clone(), nil
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
