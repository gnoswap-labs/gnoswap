package v1

import (
	"errors"
	"time"

	"gno.land/p/gnoswap/uint256"
	"gno.land/r/gnoswap/launchpad"
)

// GetProjectCount returns the total number of projects.
func (lp *launchpadV1) GetProjectCount() int {
	projects := lp.store.GetProjects()
	return projects.Size()
}

// GetProjectIDs returns a paginated list of project IDs.
// Returns empty slice if offset is negative or limit is non-positive.
func (lp *launchpadV1) GetProjectIDs(offset, count int) []string {
	if offset < 0 || count <= 0 {
		return []string{}
	}

	projects := lp.store.GetProjects()
	projectIDs := make([]string, 0)

	projects.IterateByOffset(offset, count, func(key string, value any) bool {
		projectIDs = append(projectIDs, key)
		return false
	})

	return projectIDs

}

// GetProject retrieves a project by its ID.
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

	return project, nil
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

	return condition, nil
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

	return projectTier, nil
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
func (lp *launchpadV1) GetDepositCount() int {
	deposits := lp.store.GetDeposits()
	return deposits.Size()
}

// GetCurrentDepositId returns the current deposit counter value.
func (lp *launchpadV1) GetCurrentDepositId() int64 {
	counter := lp.store.GetDepositCounter()
	return counter.Get()
}

// GetProjectTierDepositCount returns the total number of deposits for a project tier.
// Returns 0 and error if project or tier not found.
func (lp *launchpadV1) GetProjectTierDepositCount(projectId string, tier int64) int {
	projectTierID := launchpad.MakeProjectTierID(projectId, tier)

	rewardManager, err := lp.getProjectTierRewardManager(projectTierID)
	if err != nil {
		return 0
	}

	return rewardManager.Rewards().Size()
}

// GetProjectTierDepositIDs returns a paginated list of deposit IDs for a project tier.
// Returns empty slice if offset is negative or limit is non-positive.
func (lp *launchpadV1) GetProjectTierDepositIDs(projectId string, tier int64, offset, count int) []string {
	projectTierID := launchpad.MakeProjectTierID(projectId, tier)

	rewardManager, err := lp.getProjectTierRewardManager(projectTierID)
	if err != nil {
		return []string{}
	}

	depositIDs := make([]string, 0)

	rewardManager.Rewards().IterateByOffset(offset, count, func(key string, value any) bool {
		depositIDs = append(depositIDs, key)
		return false
	})

	return depositIDs
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

// GetProjectTierRewardManagerCount returns the total number of reward managers.
func (lp *launchpadV1) GetProjectTierRewardManagerCount() int {
	managers := lp.store.GetProjectTierRewardManagers()
	return managers.Size()
}

// GetProjectTierRewardManager retrieves a reward manager by project tier ID.
// Returns nil and error if reward manager not found.
func (lp *launchpadV1) GetProjectTierRewardManager(projectTierId string) (*launchpad.RewardManager, error) {
	managers := lp.store.GetProjectTierRewardManagers()
	value, exists := managers.Get(projectTierId)
	if !exists {
		return nil, errors.New("reward manager not found")
	}

	manager, ok := value.(*launchpad.RewardManager)
	if !ok {
		return nil, errors.New("invalid reward manager type")
	}

	return manager, nil
}

// GetProjectTierRewardDistributeAmountPerSecondX128 returns the distribute amount per second (Q128) of a reward manager.
// Returns 0 and error if reward manager not found.
func (lp *launchpadV1) GetProjectTierRewardDistributeAmountPerSecondX128(projectTierId string) (*uint256.Uint, error) {
	manager, err := lp.GetProjectTierRewardManager(projectTierId)
	if err != nil {
		return uint256.NewUint(0), err
	}

	return manager.DistributeAmountPerSecondX128().Clone(), nil
}

// GetProjectTierRewardAccumulatedRewardPerDepositX128 returns the accumulated reward per deposit (Q128) of a reward manager.
// Returns 0 and error if reward manager not found.
func (lp *launchpadV1) GetProjectTierRewardAccumulatedRewardPerDepositX128(projectTierId string) (*uint256.Uint, error) {
	manager, err := lp.GetProjectTierRewardManager(projectTierId)
	if err != nil {
		return uint256.NewUint(0), err
	}

	return manager.AccumulatedRewardPerDepositX128().Clone(), nil
}

// GetProjectTierRewardTotalDistributeAmount returns the total distribute amount of a reward manager.
// Returns 0 and error if reward manager not found.
func (lp *launchpadV1) GetProjectTierRewardTotalDistributeAmount(projectTierId string) (int64, error) {
	manager, err := lp.GetProjectTierRewardManager(projectTierId)
	if err != nil {
		return 0, err
	}

	return manager.TotalDistributeAmount(), nil
}

// GetProjectTierRewardTotalClaimedAmount returns the total claimed amount of a reward manager.
// Returns 0 and error if reward manager not found.
func (lp *launchpadV1) GetProjectTierRewardTotalClaimedAmount(projectTierId string) (int64, error) {
	manager, err := lp.GetProjectTierRewardManager(projectTierId)
	if err != nil {
		return 0, err
	}

	return manager.TotalClaimedAmount(), nil
}

// GetProjectTierRewardDistributeStartTime returns the distribute start time of a reward manager.
// Returns 0 and error if reward manager not found.
func (lp *launchpadV1) GetProjectTierRewardDistributeStartTime(projectTierId string) (int64, error) {
	manager, err := lp.GetProjectTierRewardManager(projectTierId)
	if err != nil {
		return 0, err
	}

	return manager.DistributeStartTime(), nil
}

// GetProjectTierRewardDistributeEndTime returns the distribute end time of a reward manager.
// Returns 0 and error if reward manager not found.
func (lp *launchpadV1) GetProjectTierRewardDistributeEndTime(projectTierId string) (int64, error) {
	manager, err := lp.GetProjectTierRewardManager(projectTierId)
	if err != nil {
		return 0, err
	}

	return manager.DistributeEndTime(), nil
}

// GetProjectTierRewardAccumulatedDistributeAmount returns the accumulated distribute amount of a reward manager.
// Returns 0 and error if reward manager not found.
func (lp *launchpadV1) GetProjectTierRewardAccumulatedDistributeAmount(projectTierId string) (int64, error) {
	manager, err := lp.GetProjectTierRewardManager(projectTierId)
	if err != nil {
		return 0, err
	}

	return manager.AccumulatedDistributeAmount(), nil
}

// GetProjectTierRewardAccumulatedHeight returns the accumulated height of a reward manager.
// Returns 0 and error if reward manager not found.
func (lp *launchpadV1) GetProjectTierRewardAccumulatedHeight(projectTierId string) (int64, error) {
	manager, err := lp.GetProjectTierRewardManager(projectTierId)
	if err != nil {
		return 0, err
	}

	return manager.AccumulatedHeight(), nil
}

// GetProjectTierRewardAccumulatedTime returns the accumulated time of a reward manager.
// Returns 0 and error if reward manager not found.
func (lp *launchpadV1) GetProjectTierRewardAccumulatedTime(projectTierId string) (int64, error) {
	manager, err := lp.GetProjectTierRewardManager(projectTierId)
	if err != nil {
		return 0, err
	}

	return manager.AccumulatedTime(), nil
}

// GetProjectTierRewardRewardClaimableDuration returns the reward claimable duration of a reward manager.
// Returns 0 and error if reward manager not found.
func (lp *launchpadV1) GetProjectTierRewardRewardClaimableDuration(projectTierId string) (int64, error) {
	manager, err := lp.GetProjectTierRewardManager(projectTierId)
	if err != nil {
		return 0, err
	}

	return manager.RewardClaimableDuration(), nil
}

// GetRewardState retrieves a reward state by project tier ID and deposit ID.
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

	return rewardState, nil
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
