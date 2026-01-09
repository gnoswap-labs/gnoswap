package launchpad

import (
	u256 "gno.land/p/gnoswap/uint256"
)

// GetProjectCount returns the total number of projects.
func GetProjectCount() int {
	return getImplementation().GetProjectCount()
}

// GetProjectIDs returns a paginated list of project IDs.
func GetProjectIDs(offset, count int) []string {
	return getImplementation().GetProjectIDs(offset, count)
}

// GetProject retrieves a project by its ID.
// Returns a cloned project to prevent external modification.
func GetProject(projectId string) (*Project, error) {
	project, err := getImplementation().GetProject(projectId)
	if err != nil {
		return nil, err
	}
	if project == nil {
		return nil, nil
	}
	return project.Clone(), nil
}

// GetProjectName returns the name of a project by its ID.
func GetProjectName(projectId string) (string, error) {
	return getImplementation().GetProjectName(projectId)
}

// GetProjectTokenPath returns the token path of a project by its ID.
func GetProjectTokenPath(projectId string) (string, error) {
	return getImplementation().GetProjectTokenPath(projectId)
}

// GetProjectDepositAmount returns the deposit amount of a project by its ID.
func GetProjectDepositAmount(projectId string) (int64, error) {
	return getImplementation().GetProjectDepositAmount(projectId)
}

// GetProjectRecipient returns the recipient address of a project by its ID.
func GetProjectRecipient(projectId string) (address, error) {
	return getImplementation().GetProjectRecipient(projectId)
}

// GetProjectCondition retrieves a specific condition of a project.
// Returns a cloned condition to prevent external modification.
func GetProjectCondition(projectId string, tokenPath string) (*ProjectCondition, error) {
	condition, err := getImplementation().GetProjectCondition(projectId, tokenPath)
	if err != nil {
		return nil, err
	}
	if condition == nil {
		return nil, nil
	}
	return condition.Clone(), nil
}

// GetProjectTiersRatios returns the tiers ratios map of a project by its ID.
func GetProjectTiersRatios(projectId string) (map[int64]int64, error) {
	return getImplementation().GetProjectTiersRatios(projectId)
}

// GetProjectCreatedHeight returns the created height of a project by its ID.
func GetProjectCreatedHeight(projectId string) (int64, error) {
	return getImplementation().GetProjectCreatedHeight(projectId)
}

// GetProjectCreatedAt returns the created time of a project by its ID.
func GetProjectCreatedAt(projectId string) (int64, error) {
	return getImplementation().GetProjectCreatedAt(projectId)
}

// GetProjectTier retrieves a specific tier of a project.
// Returns a cloned tier to prevent external modification.
func GetProjectTier(projectId string, tier int64) (*ProjectTier, error) {
	projectTier, err := getImplementation().GetProjectTier(projectId, tier)
	if err != nil {
		return nil, err
	}
	if projectTier == nil {
		return nil, nil
	}
	return projectTier.Clone(), nil
}

// GetProjectTierDistributeAmountPerSecondX128 returns the distribute amount per second (Q128) of a project tier.
func GetProjectTierDistributeAmountPerSecondX128(projectId string, tier int64) (*u256.Uint, error) {
	return getImplementation().GetProjectTierDistributeAmountPerSecondX128(projectId, tier)
}

// GetProjectTierTotalDistributeAmount returns the total distribute amount of a project tier.
func GetProjectTierTotalDistributeAmount(projectId string, tier int64) (int64, error) {
	return getImplementation().GetProjectTierTotalDistributeAmount(projectId, tier)
}

// GetProjectTierTotalDepositAmount returns the total deposit amount of a project tier.
func GetProjectTierTotalDepositAmount(projectId string, tier int64) (int64, error) {
	return getImplementation().GetProjectTierTotalDepositAmount(projectId, tier)
}

// GetProjectTierTotalWithdrawAmount returns the total withdraw amount of a project tier.
func GetProjectTierTotalWithdrawAmount(projectId string, tier int64) (int64, error) {
	return getImplementation().GetProjectTierTotalWithdrawAmount(projectId, tier)
}

// GetProjectTierTotalDepositCount returns the total deposit count of a project tier.
func GetProjectTierTotalDepositCount(projectId string, tier int64) (int64, error) {
	return getImplementation().GetProjectTierTotalDepositCount(projectId, tier)
}

// GetProjectTierTotalWithdrawCount returns the total withdraw count of a project tier.
func GetProjectTierTotalWithdrawCount(projectId string, tier int64) (int64, error) {
	return getImplementation().GetProjectTierTotalWithdrawCount(projectId, tier)
}

// GetProjectTierTotalCollectedAmount returns the total collected amount of a project tier.
func GetProjectTierTotalCollectedAmount(projectId string, tier int64) (int64, error) {
	return getImplementation().GetProjectTierTotalCollectedAmount(projectId, tier)
}

// GetProjectTierStartTime returns the start time of a project tier.
func GetProjectTierStartTime(projectId string, tier int64) (int64, error) {
	return getImplementation().GetProjectTierStartTime(projectId, tier)
}

// GetProjectTierEndTime returns the end time of a project tier.
func GetProjectTierEndTime(projectId string, tier int64) (int64, error) {
	return getImplementation().GetProjectTierEndTime(projectId, tier)
}

// GetDepositCount returns the total number of deposits.
func GetDepositCount() int {
	return getImplementation().GetDepositCount()
}

// GetCurrentDepositId returns the current deposit counter value.
func GetCurrentDepositId() int64 {
	return getImplementation().GetCurrentDepositId()
}

// GetProjectTierDepositCount returns the total number of deposits for a project tier.
func GetProjectTierDepositCount(projectId string, tier int64) int {
	return getImplementation().GetProjectTierDepositCount(projectId, tier)
}

// GetProjectTierDepositIDs returns a paginated list of deposit IDs for a project tier.
func GetProjectTierDepositIDs(projectId string, tier int64, offset, count int) []string {
	return getImplementation().GetProjectTierDepositIDs(projectId, tier, offset, count)
}

// GetDeposit retrieves a deposit by its ID.
// Returns a cloned deposit to prevent external modification.
func GetDeposit(depositId string) (*Deposit, error) {
	return getImplementation().GetDeposit(depositId)
}

// GetDepositProjectID returns the project ID of a deposit by its ID.
func GetDepositProjectID(depositId string) (string, error) {
	return getImplementation().GetDepositProjectID(depositId)
}

// GetDepositTier returns the tier of a deposit by its ID.
func GetDepositTier(depositId string) (int64, error) {
	return getImplementation().GetDepositTier(depositId)
}

// GetDepositProjectTierID returns the project tier ID of a deposit by its ID.
func GetDepositProjectTierID(depositId string) (string, error) {
	return getImplementation().GetDepositProjectTierID(depositId)
}

// GetDepositAmount returns the deposit amount of a deposit by its ID.
func GetDepositAmount(depositId string) (int64, error) {
	return getImplementation().GetDepositAmount(depositId)
}

// GetDepositWithdrawnHeight returns the withdrawn height of a deposit by its ID.
func GetDepositWithdrawnHeight(depositId string) (int64, error) {
	return getImplementation().GetDepositWithdrawnHeight(depositId)
}

// GetDepositWithdrawnTime returns the withdrawn time of a deposit by its ID.
func GetDepositWithdrawnTime(depositId string) (int64, error) {
	return getImplementation().GetDepositWithdrawnTime(depositId)
}

// GetDepositCreatedHeight returns the created height of a deposit by its ID.
func GetDepositCreatedHeight(depositId string) (int64, error) {
	return getImplementation().GetDepositCreatedHeight(depositId)
}

// GetDepositCreatedAt returns the created time of a deposit by its ID.
func GetDepositCreatedAt(depositId string) (int64, error) {
	return getImplementation().GetDepositCreatedAt(depositId)
}

// GetDepositEndTime returns the end time of a deposit by its ID.
func GetDepositEndTime(depositId string) (int64, error) {
	return getImplementation().GetDepositEndTime(depositId)
}

// GetProjectTierRewardManagerCount returns the total number of reward managers.
func GetProjectTierRewardManagerCount() int {
	return getImplementation().GetProjectTierRewardManagerCount()
}

// GetProjectTierRewardManager retrieves a reward manager by project tier ID.
// Returns a cloned reward manager to prevent external modification.
func GetProjectTierRewardManager(projectTierId string) (*RewardManager, error) {
	return getImplementation().GetProjectTierRewardManager(projectTierId)
}

// GetProjectTierRewardDistributeAmountPerSecondX128 returns the distribute amount per second (Q128) of a reward manager.
func GetProjectTierRewardDistributeAmountPerSecondX128(projectTierId string) (*u256.Uint, error) {
	return getImplementation().GetProjectTierRewardDistributeAmountPerSecondX128(projectTierId)
}

// GetProjectTierRewardAccumulatedRewardPerDepositX128 returns the accumulated reward per deposit (Q128) of a reward manager.
func GetProjectTierRewardAccumulatedRewardPerDepositX128(projectTierId string) (*u256.Uint, error) {
	return getImplementation().GetProjectTierRewardAccumulatedRewardPerDepositX128(projectTierId)
}

// GetProjectTierRewardTotalDistributeAmount returns the total distribute amount of a reward manager.
func GetProjectTierRewardTotalDistributeAmount(projectTierId string) (int64, error) {
	return getImplementation().GetProjectTierRewardTotalDistributeAmount(projectTierId)
}

// GetProjectTierRewardTotalClaimedAmount returns the total claimed amount of a reward manager.
func GetProjectTierRewardTotalClaimedAmount(projectTierId string) (int64, error) {
	return getImplementation().GetProjectTierRewardTotalClaimedAmount(projectTierId)
}

// GetProjectTierRewardDistributeStartTime returns the distribute start time of a reward manager.
func GetProjectTierRewardDistributeStartTime(projectTierId string) (int64, error) {
	return getImplementation().GetProjectTierRewardDistributeStartTime(projectTierId)
}

// GetProjectTierRewardDistributeEndTime returns the distribute end time of a reward manager.
func GetProjectTierRewardDistributeEndTime(projectTierId string) (int64, error) {
	return getImplementation().GetProjectTierRewardDistributeEndTime(projectTierId)
}

// GetProjectTierRewardAccumulatedDistributeAmount returns the accumulated distribute amount of a reward manager.
func GetProjectTierRewardAccumulatedDistributeAmount(projectTierId string) (int64, error) {
	return getImplementation().GetProjectTierRewardAccumulatedDistributeAmount(projectTierId)
}

// GetProjectTierRewardAccumulatedHeight returns the accumulated height of a reward manager.
func GetProjectTierRewardAccumulatedHeight(projectTierId string) (int64, error) {
	return getImplementation().GetProjectTierRewardAccumulatedHeight(projectTierId)
}

// GetProjectTierRewardAccumulatedTime returns the accumulated time of a reward manager.
func GetProjectTierRewardAccumulatedTime(projectTierId string) (int64, error) {
	return getImplementation().GetProjectTierRewardAccumulatedTime(projectTierId)
}

// GetProjectTierRewardRewardClaimableDuration returns the reward claimable duration of a reward manager.
func GetProjectTierRewardRewardClaimableDuration(projectTierId string) (int64, error) {
	return getImplementation().GetProjectTierRewardRewardClaimableDuration(projectTierId)
}

// GetRewardState retrieves a reward state by project tier ID and deposit ID.
// Returns a cloned reward state to prevent external modification.
func GetRewardState(projectTierId string, depositId string) (*RewardState, error) {
	rewardState, err := getImplementation().GetRewardState(projectTierId, depositId)
	if err != nil {
		return nil, err
	}
	if rewardState == nil {
		return nil, nil
	}
	return rewardState.Clone(), nil
}

// GetProjectActiveStatus returns whether a project is currently active.
func GetProjectActiveStatus(projectId string) (bool, error) {
	return getImplementation().GetProjectActiveStatus(projectId)
}
