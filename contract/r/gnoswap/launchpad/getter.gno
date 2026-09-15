package launchpad

import (
	u256 "gno.land/p/gnoswap/uint256"
	rotree "gno.land/p/nt/bptree/rotree/v0"
)

// GetProjects returns a read-only view of every project, keyed by project ID.
// Callers paginate it themselves through IterateByOffset. Reading an entry
// yields a clone, so the view cannot mutate realm state.
//
// Returns:
//   - projects: read-only tree keyed by project ID; reading an entry yields a clone.
func GetProjects() *rotree.ReadOnlyTree {
	return getImplementation().GetProjects()
}

// GetProjectName returns the name of a project by its ID.
//
// Parameters:
//   - projectId: unique identifier of the launchpad project to inspect.
//
// Returns:
//   - name: stored project name.
//   - err: non-nil when projectId does not identify a stored project.
func GetProjectName(projectId string) (string, error) {
	return getImplementation().GetProjectName(projectId)
}

// GetProjectTokenPath returns the token path of a project by its ID.
//
// Parameters:
//   - projectId: unique identifier of the launchpad project to inspect.
//
// Returns:
//   - tokenPath: reward-token contract path configured for the project.
//   - err: non-nil when projectId does not identify a stored project.
func GetProjectTokenPath(projectId string) (string, error) {
	return getImplementation().GetProjectTokenPath(projectId)
}

// GetProjectDepositAmount returns the deposit amount of a project by its ID.
//
// Parameters:
//   - projectId: unique identifier of the launchpad project to inspect.
//
// Returns:
//   - amount: project-token amount initially allocated to the project, in token base units.
//   - err: non-nil when projectId does not identify a stored project.
func GetProjectDepositAmount(projectId string) (int64, error) {
	return getImplementation().GetProjectDepositAmount(projectId)
}

// GetProjectRecipient returns the recipient address of a project by its ID.
//
// Parameters:
//   - projectId: unique identifier of the launchpad project to inspect.
//
// Returns:
//   - recipient: address configured to receive the project's launchpad proceeds.
//   - err: non-nil when projectId does not identify a stored project.
func GetProjectRecipient(projectId string) (address, error) {
	return getImplementation().GetProjectRecipient(projectId)
}

// GetProjectCondition retrieves a specific condition of a project.
// Returns a cloned condition to prevent external modification.
//
// Parameters:
//   - projectId: unique identifier of the project containing the condition.
//   - tokenPath: token contract path used as the condition key.
//
// Returns:
//   - condition: cloned condition for the requested token; nil when the implementation returns no condition without an error.
//   - err: non-nil when the project or condition cannot be found.
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
//
// Parameters:
//   - projectId: unique identifier of the launchpad project to inspect.
//
// Returns:
//   - tiersRatios: cloned map from tier duration to its allocation ratio.
//   - err: non-nil when projectId does not identify a stored project.
func GetProjectTiersRatios(projectId string) (map[int64]int64, error) {
	tiersRatios, err := getImplementation().GetProjectTiersRatios(projectId)
	if err != nil {
		return nil, err
	}
	return cloneInt64Map(tiersRatios), nil
}

// GetProjectCreatedHeight returns the created height of a project by its ID.
//
// Parameters:
//   - projectId: unique identifier of the launchpad project to inspect.
//
// Returns:
//   - height: block height at which the project was created.
//   - err: non-nil when projectId does not identify a stored project.
func GetProjectCreatedHeight(projectId string) (int64, error) {
	return getImplementation().GetProjectCreatedHeight(projectId)
}

// GetProjectCreatedAt returns the created time of a project by its ID.
//
// Parameters:
//   - projectId: unique identifier of the launchpad project to inspect.
//
// Returns:
//   - createdAt: Unix timestamp in seconds at which the project was created.
//   - err: non-nil when projectId does not identify a stored project.
func GetProjectCreatedAt(projectId string) (int64, error) {
	return getImplementation().GetProjectCreatedAt(projectId)
}

// GetProjectTier retrieves a specific tier of a project.
// Returns a cloned tier to prevent external modification.
//
// Parameters:
//   - projectId: unique identifier of the project containing the tier.
//   - tier: tier duration key, such as 30, 90, or 180.
//
// Returns:
//   - projectTier: cloned project tier; nil when the implementation supplies no tier without an error.
//   - err: non-nil when the project or tier cannot be found.
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
//
// Parameters:
//   - projectId: unique identifier of the project containing the tier.
//   - tier: tier duration key, such as 30, 90, or 180.
//
// Returns:
//   - amountPerSecondX128: project-token distribution rate per second in Q128 fixed-point units; nil when no value is available.
//   - err: non-nil when the project or tier cannot be found.
func GetProjectTierDistributeAmountPerSecondX128(projectId string, tier int64) (*u256.Uint, error) {
	amount, err := getImplementation().GetProjectTierDistributeAmountPerSecondX128(projectId, tier)
	if err != nil {
		return nil, err
	}
	if amount == nil {
		return nil, nil
	}
	return amount.Clone(), nil
}

// GetProjectTierTotalDistributeAmount returns the total distribute amount of a project tier.
//
// Parameters:
//   - projectId: unique identifier of the project containing the tier.
//   - tier: tier duration key, such as 30, 90, or 180.
//
// Returns:
//   - amount: total project-token allocation for the tier, in token base units.
//   - err: non-nil when the project or tier cannot be found.
func GetProjectTierTotalDistributeAmount(projectId string, tier int64) (int64, error) {
	return getImplementation().GetProjectTierTotalDistributeAmount(projectId, tier)
}

// GetProjectTierTotalDepositAmount returns the total deposit amount of a project tier.
//
// Parameters:
//   - projectId: unique identifier of the project containing the tier.
//   - tier: tier duration key, such as 30, 90, or 180.
//
// Returns:
//   - amount: cumulative GNS principal deposited into the tier, in base units.
//   - err: non-nil when the project or tier cannot be found.
func GetProjectTierTotalDepositAmount(projectId string, tier int64) (int64, error) {
	return getImplementation().GetProjectTierTotalDepositAmount(projectId, tier)
}

// GetProjectTierTotalWithdrawAmount returns the total withdraw amount of a project tier.
//
// Parameters:
//   - projectId: unique identifier of the project containing the tier.
//   - tier: tier duration key, such as 30, 90, or 180.
//
// Returns:
//   - amount: cumulative GNS principal withdrawn from the tier, in base units.
//   - err: non-nil when the project or tier cannot be found.
func GetProjectTierTotalWithdrawAmount(projectId string, tier int64) (int64, error) {
	return getImplementation().GetProjectTierTotalWithdrawAmount(projectId, tier)
}

// GetProjectTierTotalDepositCount returns the total deposit count of a project tier.
//
// Parameters:
//   - projectId: unique identifier of the project containing the tier.
//   - tier: tier duration key, such as 30, 90, or 180.
//
// Returns:
//   - count: cumulative number of deposits created in the tier.
//   - err: non-nil when the project or tier cannot be found.
func GetProjectTierTotalDepositCount(projectId string, tier int64) (int64, error) {
	return getImplementation().GetProjectTierTotalDepositCount(projectId, tier)
}

// GetProjectTierTotalWithdrawCount returns the total withdraw count of a project tier.
//
// Parameters:
//   - projectId: unique identifier of the project containing the tier.
//   - tier: tier duration key, such as 30, 90, or 180.
//
// Returns:
//   - count: cumulative number of withdrawals completed in the tier.
//   - err: non-nil when the project or tier cannot be found.
func GetProjectTierTotalWithdrawCount(projectId string, tier int64) (int64, error) {
	return getImplementation().GetProjectTierTotalWithdrawCount(projectId, tier)
}

// GetProjectTierTotalCollectedAmount returns the total collected amount of a project tier.
//
// Parameters:
//   - projectId: unique identifier of the project containing the tier.
//   - tier: tier duration key, such as 30, 90, or 180.
//
// Returns:
//   - amount: cumulative project-token reward collected from the tier, in token base units.
//   - err: non-nil when the project or tier cannot be found.
func GetProjectTierTotalCollectedAmount(projectId string, tier int64) (int64, error) {
	return getImplementation().GetProjectTierTotalCollectedAmount(projectId, tier)
}

// GetProjectTierStartTime returns the start time of a project tier.
//
// Parameters:
//   - projectId: unique identifier of the project containing the tier.
//   - tier: tier duration key, such as 30, 90, or 180.
//
// Returns:
//   - startTime: tier start timestamp in Unix seconds.
//   - err: non-nil when the project or tier cannot be found.
func GetProjectTierStartTime(projectId string, tier int64) (int64, error) {
	return getImplementation().GetProjectTierStartTime(projectId, tier)
}

// GetProjectTierEndTime returns the end time of a project tier.
//
// Parameters:
//   - projectId: unique identifier of the project containing the tier.
//   - tier: tier duration key, such as 30, 90, or 180.
//
// Returns:
//   - endTime: tier end timestamp in Unix seconds.
//   - err: non-nil when the project or tier cannot be found.
func GetProjectTierEndTime(projectId string, tier int64) (int64, error) {
	return getImplementation().GetProjectTierEndTime(projectId, tier)
}

// GetDepositCount returns the total number of deposits.
//
// Returns:
//   - count: number of deposit records currently stored.
func GetDepositCount() int {
	return getImplementation().GetDepositCount()
}

// GetCurrentDepositId returns the current deposit counter value.
//
// Returns:
//   - depositId: current deposit counter value; it is not incremented by this read.
func GetCurrentDepositId() int64 {
	return getImplementation().GetCurrentDepositId()
}

// GetProjectTierRewards returns a read-only view of a project tier's reward
// states, keyed by deposit ID. Reading an entry yields a clone, so the view
// cannot mutate realm state. nil is returned when the project tier does not
// exist.
//
// Parameters:
//   - projectId: unique identifier of the project containing the tier.
//   - tier: tier duration key, such as 30, 90, or 180.
//
// Returns:
//   - rewards: read-only tree of reward states keyed by deposit ID; nil when the tier's reward manager is unavailable.
func GetProjectTierRewards(projectId string, tier int64) *rotree.ReadOnlyTree {
	return getImplementation().GetProjectTierRewards(projectId, tier)
}

// GetDeposit retrieves a deposit by its ID.
//
// Parameters:
//   - depositId: unique identifier of the deposit to inspect.
//
// Returns:
//   - deposit: stored deposit value.
//   - err: non-nil when depositId does not identify a stored deposit.
func GetDeposit(depositId string) (Deposit, error) {
	return getImplementation().GetDeposit(depositId)
}

// GetDepositProjectID returns the project ID of a deposit by its ID.
//
// Parameters:
//   - depositId: unique identifier of the deposit to inspect.
//
// Returns:
//   - projectId: project identifier associated with the deposit.
//   - err: non-nil when depositId does not identify a stored deposit.
func GetDepositProjectID(depositId string) (string, error) {
	return getImplementation().GetDepositProjectID(depositId)
}

// GetDepositTier returns the tier of a deposit by its ID.
//
// Parameters:
//   - depositId: unique identifier of the deposit to inspect.
//
// Returns:
//   - tier: tier duration key selected by the deposit.
//   - err: non-nil when depositId does not identify a stored deposit.
func GetDepositTier(depositId string) (int64, error) {
	return getImplementation().GetDepositTier(depositId)
}

// GetDepositProjectTierID returns the project tier ID of a deposit by its ID.
//
// Parameters:
//   - depositId: unique identifier of the deposit to inspect.
//
// Returns:
//   - projectTierId: composite project-tier identifier derived from the deposit's project and tier.
//   - err: non-nil when depositId does not identify a stored deposit.
func GetDepositProjectTierID(depositId string) (string, error) {
	return getImplementation().GetDepositProjectTierID(depositId)
}

// GetDepositAmount returns the deposit amount of a deposit by its ID.
//
// Parameters:
//   - depositId: unique identifier of the deposit to inspect.
//
// Returns:
//   - amount: GNS principal deposited, in base units.
//   - err: non-nil when depositId does not identify a stored deposit.
func GetDepositAmount(depositId string) (int64, error) {
	return getImplementation().GetDepositAmount(depositId)
}

// GetDepositWithdrawnHeight returns the withdrawn height of a deposit by its ID.
//
// Parameters:
//   - depositId: unique identifier of the deposit to inspect.
//
// Returns:
//   - height: withdrawal block height; zero when the deposit has not been withdrawn.
//   - err: non-nil when depositId does not identify a stored deposit.
func GetDepositWithdrawnHeight(depositId string) (int64, error) {
	return getImplementation().GetDepositWithdrawnHeight(depositId)
}

// GetDepositWithdrawnTime returns the withdrawn time of a deposit by its ID.
//
// Parameters:
//   - depositId: unique identifier of the deposit to inspect.
//
// Returns:
//   - withdrawnAt: withdrawal Unix timestamp in seconds; zero when the deposit has not been withdrawn.
//   - err: non-nil when depositId does not identify a stored deposit.
func GetDepositWithdrawnTime(depositId string) (int64, error) {
	return getImplementation().GetDepositWithdrawnTime(depositId)
}

// GetDepositCreatedHeight returns the created height of a deposit by its ID.
//
// Parameters:
//   - depositId: unique identifier of the deposit to inspect.
//
// Returns:
//   - height: creation block height of the deposit.
//   - err: non-nil when depositId does not identify a stored deposit.
func GetDepositCreatedHeight(depositId string) (int64, error) {
	return getImplementation().GetDepositCreatedHeight(depositId)
}

// GetDepositCreatedAt returns the created time of a deposit by its ID.
//
// Parameters:
//   - depositId: unique identifier of the deposit to inspect.
//
// Returns:
//   - createdAt: deposit creation Unix timestamp in seconds.
//   - err: non-nil when depositId does not identify a stored deposit.
func GetDepositCreatedAt(depositId string) (int64, error) {
	return getImplementation().GetDepositCreatedAt(depositId)
}

// GetDepositEndTime returns the end time of a deposit by its ID.
//
// Parameters:
//   - depositId: unique identifier of the deposit to inspect.
//
// Returns:
//   - endTime: deposit lock/end Unix timestamp in seconds.
//   - err: non-nil when depositId does not identify a stored deposit.
func GetDepositEndTime(depositId string) (int64, error) {
	return getImplementation().GetDepositEndTime(depositId)
}

// GetTotalGNSStakedAmount returns the total amount of GNS currently staked across all launchpad deposits.
//
// Returns:
//   - amount: total GNS principal currently staked across launchpad deposits, in base units.
func GetTotalGNSStakedAmount() int64 {
	return getImplementation().GetTotalGNSStakedAmount()
}

// GetProjectTierRewardManagerCount returns the total number of reward managers.
//
// Returns:
//   - count: number of project-tier reward managers currently stored.
func GetProjectTierRewardManagerCount() int {
	return getImplementation().GetProjectTierRewardManagerCount()
}

// GetProjectTierRewardManager retrieves a reward manager by project tier ID.
// Returns a cloned reward manager to prevent external modification.
//
// Parameters:
//   - projectTierId: composite project-tier identifier whose manager is requested.
//
// Returns:
//   - rewardManager: cloned reward manager; nil when the implementation supplies no manager without an error.
//   - err: non-nil when projectTierId does not identify a stored reward manager.
func GetProjectTierRewardManager(projectTierId string) (*RewardManager, error) {
	rewardManager, err := getImplementation().GetProjectTierRewardManager(projectTierId)
	if err != nil {
		return nil, err
	}
	if rewardManager == nil {
		return nil, nil
	}
	return rewardManager.Clone(), nil
}

// GetProjectTierRewardDistributeAmountPerSecondX128 returns the distribute amount per second (Q128) of a reward manager.
//
// Parameters:
//   - projectTierId: composite project-tier identifier whose manager is requested.
//
// Returns:
//   - amountPerSecondX128: reward distribution rate per second in Q128 fixed-point token units; nil when no value is available.
//   - err: non-nil when projectTierId does not identify a stored reward manager.
func GetProjectTierRewardDistributeAmountPerSecondX128(projectTierId string) (*u256.Uint, error) {
	amount, err := getImplementation().GetProjectTierRewardDistributeAmountPerSecondX128(projectTierId)
	if err != nil {
		return nil, err
	}
	if amount == nil {
		return nil, nil
	}
	return amount.Clone(), nil
}

// GetProjectTierRewardAccumulatedRewardPerDepositX128 returns the accumulated reward per deposit (Q128) of a reward manager.
//
// Parameters:
//   - projectTierId: composite project-tier identifier whose manager is requested.
//
// Returns:
//   - accumulatedRewardPerDepositX128: accumulated reward index per deposited GNS unit in Q128 fixed-point units; nil when no value is available.
//   - err: non-nil when projectTierId does not identify a stored reward manager.
func GetProjectTierRewardAccumulatedRewardPerDepositX128(projectTierId string) (*u256.Uint, error) {
	amount, err := getImplementation().GetProjectTierRewardAccumulatedRewardPerDepositX128(projectTierId)
	if err != nil {
		return nil, err
	}
	if amount == nil {
		return nil, nil
	}
	return amount.Clone(), nil
}

// GetProjectTierRewardTotalDistributeAmount returns the total distribute amount of a reward manager.
//
// Parameters:
//   - projectTierId: composite project-tier identifier whose manager is requested.
//
// Returns:
//   - amount: total reward allocation managed for the project tier, in token base units.
//   - err: non-nil when projectTierId does not identify a stored reward manager.
func GetProjectTierRewardTotalDistributeAmount(projectTierId string) (int64, error) {
	return getImplementation().GetProjectTierRewardTotalDistributeAmount(projectTierId)
}

// GetProjectTierRewardTotalClaimedAmount returns the total claimed amount of a reward manager.
//
// Parameters:
//   - projectTierId: composite project-tier identifier whose manager is requested.
//
// Returns:
//   - amount: total reward amount claimed from the manager, in token base units.
//   - err: non-nil when projectTierId does not identify a stored reward manager.
func GetProjectTierRewardTotalClaimedAmount(projectTierId string) (int64, error) {
	return getImplementation().GetProjectTierRewardTotalClaimedAmount(projectTierId)
}

// GetProjectTierRewardDistributeStartTime returns the distribute start time of a reward manager.
//
// Parameters:
//   - projectTierId: composite project-tier identifier whose manager is requested.
//
// Returns:
//   - startTime: reward distribution start timestamp in Unix seconds.
//   - err: non-nil when projectTierId does not identify a stored reward manager.
func GetProjectTierRewardDistributeStartTime(projectTierId string) (int64, error) {
	return getImplementation().GetProjectTierRewardDistributeStartTime(projectTierId)
}

// GetProjectTierRewardDistributeEndTime returns the distribute end time of a reward manager.
//
// Parameters:
//   - projectTierId: composite project-tier identifier whose manager is requested.
//
// Returns:
//   - endTime: reward distribution end timestamp in Unix seconds.
//   - err: non-nil when projectTierId does not identify a stored reward manager.
func GetProjectTierRewardDistributeEndTime(projectTierId string) (int64, error) {
	return getImplementation().GetProjectTierRewardDistributeEndTime(projectTierId)
}

// GetProjectTierRewardAccumulatedDistributeAmount returns a legacy reward-manager field.
// The v1 reward paths do not maintain it, so normal reads return zero unless it
// was explicitly set.
//
// Parameters:
//   - projectTierId: composite project-tier identifier whose manager is requested.
//
// Returns:
//   - amount: legacy accumulated distribution amount in token base units; v1 accounting normally leaves it at zero unless explicitly set.
//   - err: non-nil when projectTierId does not identify a stored reward manager.
func GetProjectTierRewardAccumulatedDistributeAmount(projectTierId string) (int64, error) {
	return getImplementation().GetProjectTierRewardAccumulatedDistributeAmount(projectTierId)
}

// GetProjectTierRewardAccumulatedTime returns the accumulated time of a reward manager.
//
// Parameters:
//   - projectTierId: composite project-tier identifier whose manager is requested.
//
// Returns:
//   - time: last reward-accumulation timestamp in Unix seconds, or zero before accumulation.
//   - err: non-nil when projectTierId does not identify a stored reward manager.
func GetProjectTierRewardAccumulatedTime(projectTierId string) (int64, error) {
	return getImplementation().GetProjectTierRewardAccumulatedTime(projectTierId)
}

// GetProjectTierRewardClaimableDuration returns the reward claimable duration of a reward manager.
//
// Parameters:
//   - projectTierId: composite project-tier identifier whose manager is requested.
//
// Returns:
//   - duration: reward claimable window in seconds.
//   - err: non-nil when projectTierId does not identify a stored reward manager.
func GetProjectTierRewardClaimableDuration(projectTierId string) (int64, error) {
	return getImplementation().GetProjectTierRewardClaimableDuration(projectTierId)
}

// GetRewardState retrieves a reward state by project tier ID and deposit ID.
// Returns a cloned reward state to prevent external modification.
//
// Parameters:
//   - projectTierId: composite project-tier identifier containing the reward state.
//   - depositId: deposit identifier whose reward state is requested.
//
// Returns:
//   - rewardState: cloned reward state; nil when the implementation supplies no state without an error.
//   - err: non-nil when the reward manager or reward state cannot be found.
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
//
// Parameters:
//   - projectId: unique identifier of the project to inspect.
//
// Returns:
//   - active: true when the project is active at the current Unix time; false when it is inactive.
//   - err: non-nil when projectId does not identify a stored project.
func GetProjectActiveStatus(projectId string) (bool, error) {
	return getImplementation().GetProjectActiveStatus(projectId)
}
