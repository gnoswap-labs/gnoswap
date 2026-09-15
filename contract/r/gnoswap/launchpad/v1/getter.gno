package launchpad

import (
	"errors"
	"time"

	rotree "gno.land/p/nt/bptree/rotree/v0"
	ufmt "gno.land/p/nt/ufmt/v0"

	"gno.land/p/gnoswap/uint256/v1"
	"gno.land/r/gnoswap/launchpad"
)

// GetProjects returns a read-only view of every project, keyed by project ID.
//
// Returns:
//   - projects: read-only tree keyed by project ID; project entries are cloned before being exposed.
func (lp *launchpadV1) GetProjects() *rotree.ReadOnlyTree {
	return rotree.Wrap(lp.store.GetProjects(), cloneProjectEntry)
}

// GetProjectName returns the name of a project by its ID.
// Returns empty string and error if project not found.
//
// Parameters:
//   - projectId: unique launchpad project identifier to look up.
//
// Returns:
//   - name: configured project name; empty when the project is absent.
//   - err: nil when found; non-nil when projectId is not present in state.
func (lp *launchpadV1) GetProjectName(projectId string) (string, error) {
	project, err := lp.getProject(projectId)
	if err != nil {
		return "", err
	}

	return project.Name(), nil
}

// GetProjectTokenPath returns the token path of a project by its ID.
// Returns empty string and error if project not found.
//
// Parameters:
//   - projectId: unique launchpad project identifier to look up.
//
// Returns:
//   - tokenPath: reward-token contract path configured for the project; empty when absent.
//   - err: nil when found; non-nil when projectId is not present in state.
func (lp *launchpadV1) GetProjectTokenPath(projectId string) (string, error) {
	project, err := lp.getProject(projectId)
	if err != nil {
		return "", err
	}

	return project.TokenPath(), nil
}

// GetProjectDepositAmount returns the deposit amount of a project by its ID.
// Returns 0 and error if project not found.
//
// Parameters:
//   - projectId: unique launchpad project identifier to look up.
//
// Returns:
//   - amount: project-level token amount deposited for distribution; zero when absent.
//   - err: nil when found; non-nil when projectId is not present in state.
func (lp *launchpadV1) GetProjectDepositAmount(projectId string) (int64, error) {
	project, err := lp.getProject(projectId)
	if err != nil {
		return 0, err
	}

	return project.DepositAmount(), nil
}

// GetProjectRecipient returns the recipient address of a project by its ID.
// Returns empty address and error if project not found.
//
// Parameters:
//   - projectId: unique launchpad project identifier to look up.
//
// Returns:
//   - recipient: address configured to receive the project's tokens; empty address when absent.
//   - err: nil when found; non-nil when projectId is not present in state.
func (lp *launchpadV1) GetProjectRecipient(projectId string) (address, error) {
	project, err := lp.getProject(projectId)
	if err != nil {
		return address(""), err
	}

	return project.Recipient(), nil
}

// GetProjectCondition retrieves a specific condition of a project.
// Returns nil and error if project or condition not found.
//
// Parameters:
//   - projectId: unique launchpad project identifier to look up.
//   - tokenPath: condition-token contract path used as the project's condition key.
//
// Returns:
//   - condition: matching project condition; nil when the project or condition is absent.
//   - err: nil when found; non-nil when projectId or tokenPath is not present.
func (lp *launchpadV1) GetProjectCondition(projectId string, tokenPath string) (*launchpad.ProjectCondition, error) {
	project, err := lp.getProject(projectId)
	if err != nil {
		return nil, err
	}

	conditions := project.Conditions()
	condition, exists := conditions[tokenPath]
	if !exists {
		return nil, makeErrorWithDetails(errDataNotFound, ufmt.Sprintf("condition(%s) not found", tokenPath))
	}

	return condition, nil
}

// GetProjectTiersRatios returns the tiers ratios map of a project by its ID.
// Returns nil and error if project not found.
//
// Parameters:
//   - projectId: unique launchpad project identifier to look up.
//
// Returns:
//   - ratios: map from tier duration (30, 90, or 180) to its allocation percentage; nil when the project is absent.
//   - err: nil when found; non-nil when projectId is not present in state.
func (lp *launchpadV1) GetProjectTiersRatios(projectId string) (map[int64]int64, error) {
	project, err := lp.getProject(projectId)
	if err != nil {
		return nil, err
	}

	return project.TiersRatios(), nil
}

// GetProjectCreatedHeight returns the created height of a project by its ID.
// Returns 0 and error if project not found.
//
// Parameters:
//   - projectId: unique launchpad project identifier to look up.
//
// Returns:
//   - height: project creation block height; zero when the project is absent.
//   - err: nil when found; non-nil when projectId is not present in state.
func (lp *launchpadV1) GetProjectCreatedHeight(projectId string) (int64, error) {
	project, err := lp.getProject(projectId)
	if err != nil {
		return 0, err
	}

	return project.CreatedHeight(), nil
}

// GetProjectCreatedAt returns the created time of a project by its ID.
// Returns 0 and error if project not found.
//
// Parameters:
//   - projectId: unique launchpad project identifier to look up.
//
// Returns:
//   - createdAt: project creation timestamp in Unix seconds; zero when the project is absent.
//   - err: nil when found; non-nil when projectId is not present in state.
func (lp *launchpadV1) GetProjectCreatedAt(projectId string) (int64, error) {
	project, err := lp.getProject(projectId)
	if err != nil {
		return 0, err
	}

	return project.CreatedAt(), nil
}

// GetProjectTier retrieves a specific tier of a project.
// Returns nil and error if project or tier not found.
//
// Parameters:
//   - projectId: unique launchpad project identifier to look up.
//   - tier: tier duration in days; launchpad tiers use 30, 90, or 180.
//
// Returns:
//   - projectTier: matching project tier; nil when the project or tier is absent.
//   - err: nil when found; non-nil when projectId or tier is not present.
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
// Returns nil and error if project or tier not found.
//
// Parameters:
//   - projectId: unique launchpad project identifier to look up.
//   - tier: tier duration in days; launchpad tiers use 30, 90, or 180.
//
// Returns:
//   - amountPerSecondX128: per-second distribution rate encoded as a Q128 fixed-point value; nil when lookup fails.
//   - err: nil when found; non-nil when projectId or tier is not present.
func (lp *launchpadV1) GetProjectTierDistributeAmountPerSecondX128(projectId string, tier int64) (*uint256.Uint, error) {
	projectTier, err := lp.GetProjectTier(projectId, tier)
	if err != nil {
		return nil, err
	}

	return projectTier.DistributeAmountPerSecondX128(), nil
}

// GetProjectTierTotalDistributeAmount returns the total distribute amount of a project tier.
// Returns 0 and error if project or tier not found.
//
// Parameters:
//   - projectId: unique launchpad project identifier to look up.
//   - tier: tier duration in days; launchpad tiers use 30, 90, or 180.
//
// Returns:
//   - amount: total token amount allocated for distribution by the tier; zero when lookup fails.
//   - err: nil when found; non-nil when projectId or tier is not present.
func (lp *launchpadV1) GetProjectTierTotalDistributeAmount(projectId string, tier int64) (int64, error) {
	projectTier, err := lp.GetProjectTier(projectId, tier)
	if err != nil {
		return 0, err
	}

	return projectTier.TotalDistributeAmount(), nil
}

// GetProjectTierTotalDepositAmount returns the total deposit amount of a project tier.
// Returns 0 and error if project or tier not found.
//
// Parameters:
//   - projectId: unique launchpad project identifier to look up.
//   - tier: tier duration in days; launchpad tiers use 30, 90, or 180.
//
// Returns:
//   - amount: aggregate token amount deposited into the tier; zero when lookup fails.
//   - err: nil when found; non-nil when projectId or tier is not present.
func (lp *launchpadV1) GetProjectTierTotalDepositAmount(projectId string, tier int64) (int64, error) {
	projectTier, err := lp.GetProjectTier(projectId, tier)
	if err != nil {
		return 0, err
	}

	return projectTier.TotalDepositAmount(), nil
}

// GetProjectTierTotalWithdrawAmount returns the total withdraw amount of a project tier.
// Returns 0 and error if project or tier not found.
//
// Parameters:
//   - projectId: unique launchpad project identifier to look up.
//   - tier: tier duration in days; launchpad tiers use 30, 90, or 180.
//
// Returns:
//   - amount: aggregate token amount withdrawn from the tier; zero when lookup fails.
//   - err: nil when found; non-nil when projectId or tier is not present.
func (lp *launchpadV1) GetProjectTierTotalWithdrawAmount(projectId string, tier int64) (int64, error) {
	projectTier, err := lp.GetProjectTier(projectId, tier)
	if err != nil {
		return 0, err
	}

	return projectTier.TotalWithdrawAmount(), nil
}

// GetProjectTierTotalDepositCount returns the total deposit count of a project tier.
// Returns 0 and error if project or tier not found.
//
// Parameters:
//   - projectId: unique launchpad project identifier to look up.
//   - tier: tier duration in days; launchpad tiers use 30, 90, or 180.
//
// Returns:
//   - count: number of deposits recorded for the tier; zero when lookup fails.
//   - err: nil when found; non-nil when projectId or tier is not present.
func (lp *launchpadV1) GetProjectTierTotalDepositCount(projectId string, tier int64) (int64, error) {
	projectTier, err := lp.GetProjectTier(projectId, tier)
	if err != nil {
		return 0, err
	}

	return projectTier.TotalDepositCount(), nil
}

// GetProjectTierTotalWithdrawCount returns the total withdraw count of a project tier.
// Returns 0 and error if project or tier not found.
//
// Parameters:
//   - projectId: unique launchpad project identifier to look up.
//   - tier: tier duration in days; launchpad tiers use 30, 90, or 180.
//
// Returns:
//   - count: number of withdrawals recorded for the tier; zero when lookup fails.
//   - err: nil when found; non-nil when projectId or tier is not present.
func (lp *launchpadV1) GetProjectTierTotalWithdrawCount(projectId string, tier int64) (int64, error) {
	projectTier, err := lp.GetProjectTier(projectId, tier)
	if err != nil {
		return 0, err
	}

	return projectTier.TotalWithdrawCount(), nil
}

// GetProjectTierTotalCollectedAmount returns the total collected amount of a project tier.
// Returns 0 and error if project or tier not found.
//
// Parameters:
//   - projectId: unique launchpad project identifier to look up.
//   - tier: tier duration in days; launchpad tiers use 30, 90, or 180.
//
// Returns:
//   - amount: aggregate reward amount collected from the tier; zero when lookup fails.
//   - err: nil when found; non-nil when projectId or tier is not present.
func (lp *launchpadV1) GetProjectTierTotalCollectedAmount(projectId string, tier int64) (int64, error) {
	projectTier, err := lp.GetProjectTier(projectId, tier)
	if err != nil {
		return 0, err
	}

	return projectTier.TotalCollectedAmount(), nil
}

// GetProjectTierStartTime returns the start time of a project tier.
// Returns 0 and error if project or tier not found.
//
// Parameters:
//   - projectId: unique launchpad project identifier to look up.
//   - tier: tier duration in days; launchpad tiers use 30, 90, or 180.
//
// Returns:
//   - startTime: tier start timestamp in Unix seconds; zero when lookup fails.
//   - err: nil when found; non-nil when projectId or tier is not present.
func (lp *launchpadV1) GetProjectTierStartTime(projectId string, tier int64) (int64, error) {
	projectTier, err := lp.GetProjectTier(projectId, tier)
	if err != nil {
		return 0, err
	}

	return projectTier.StartTime(), nil
}

// GetProjectTierEndTime returns the end time of a project tier.
// Returns 0 and error if project or tier not found.
//
// Parameters:
//   - projectId: unique launchpad project identifier to look up.
//   - tier: tier duration in days; launchpad tiers use 30, 90, or 180.
//
// Returns:
//   - endTime: tier end timestamp in Unix seconds; zero when lookup fails.
//   - err: nil when found; non-nil when projectId or tier is not present.
func (lp *launchpadV1) GetProjectTierEndTime(projectId string, tier int64) (int64, error) {
	projectTier, err := lp.GetProjectTier(projectId, tier)
	if err != nil {
		return 0, err
	}

	return projectTier.EndTime(), nil
}

// GetDepositCount returns the total number of deposits.
//
// Returns:
//   - count: number of deposit entries currently stored.
func (lp *launchpadV1) GetDepositCount() int {
	deposits := lp.store.GetDeposits()
	return deposits.Size()
}

// GetCurrentDepositId returns the current deposit counter value.
//
// Returns:
//   - depositID: current int64 deposit counter used to generate subsequent deposit identifiers.
func (lp *launchpadV1) GetCurrentDepositId() int64 {
	counter := lp.store.GetDepositCounter()
	return counter.Get()
}

// GetProjectTierRewards returns a read-only view of a project tier's reward
// states, keyed by deposit ID. nil is returned when the project tier does not
// exist.
//
// Parameters:
//   - projectId: unique launchpad project identifier used to form the tier ID.
//   - tier: tier duration in days; launchpad tiers use 30, 90, or 180.
//
// Returns:
//   - rewards: read-only tree of reward states keyed by deposit ID; nil when the tier's reward manager lookup fails.
func (lp *launchpadV1) GetProjectTierRewards(projectId string, tier int64) *rotree.ReadOnlyTree {
	projectTierID := launchpad.MakeProjectTierID(projectId, tier)

	rewardManager, err := lp.getProjectTierRewardManager(projectTierID)
	if err != nil {
		return nil
	}
	return rotree.Wrap(rewardManager.Rewards(), cloneRewardStateEntry)
}

// GetDeposit retrieves the value payload of a deposit by its ID.
//
// Parameters:
//   - depositId: unique deposit identifier to look up.
//
// Returns:
//   - deposit: stored deposit value; zero-valued when the entry is missing or has an invalid type.
//   - err: nil for a valid stored deposit; non-nil when the entry is missing or has an invalid type.
func (lp *launchpadV1) GetDeposit(depositId string) (launchpad.Deposit, error) {
	return lp.getDepositValue(depositId)
}

// GetDepositProjectID returns the project ID of a deposit by its ID.
//
// Parameters:
//   - depositId: unique deposit identifier to look up.
//
// Returns:
//   - projectID: project identifier recorded on the deposit; empty when the entry is missing or invalid.
//   - err: nil for a valid stored deposit; non-nil when the entry is missing or has an invalid type.
func (lp *launchpadV1) GetDepositProjectID(depositId string) (string, error) {
	deposit, err := lp.getDepositValue(depositId)
	if err != nil {
		return "", err
	}
	return deposit.ProjectID(), nil
}

// GetDepositTier returns the tier of a deposit by its ID.
//
// Parameters:
//   - depositId: unique deposit identifier to look up.
//
// Returns:
//   - tier: tier duration recorded on the deposit; zero when the entry is missing or invalid.
//   - err: nil for a valid stored deposit; non-nil when the entry is missing or has an invalid type.
func (lp *launchpadV1) GetDepositTier(depositId string) (int64, error) {
	deposit, err := lp.getDepositValue(depositId)
	if err != nil {
		return 0, err
	}
	return deposit.Tier(), nil
}

// GetDepositProjectTierID returns the project tier ID of a deposit by its ID.
//
// Parameters:
//   - depositId: unique deposit identifier to look up.
//
// Returns:
//   - projectTierID: composite project-tier identifier derived from the deposit; empty when the entry is missing or invalid.
//   - err: nil for a valid stored deposit; non-nil when the entry is missing or has an invalid type.
func (lp *launchpadV1) GetDepositProjectTierID(depositId string) (string, error) {
	deposit, err := lp.getDepositValue(depositId)
	if err != nil {
		return "", err
	}
	return deposit.ProjectTierID(), nil
}

// GetDepositAmount returns the deposit amount of a deposit by its ID.
//
// Parameters:
//   - depositId: unique deposit identifier to look up.
//
// Returns:
//   - amount: GNS amount recorded on the deposit; zero when the entry is missing or invalid.
//   - err: nil for a valid stored deposit; non-nil when the entry is missing or has an invalid type.
func (lp *launchpadV1) GetDepositAmount(depositId string) (int64, error) {
	deposit, err := lp.getDepositValue(depositId)
	if err != nil {
		return 0, err
	}
	return deposit.DepositAmount(), nil
}

// GetDepositWithdrawnHeight returns the withdrawn height of a deposit by its ID.
//
// Parameters:
//   - depositId: unique deposit identifier to look up.
//
// Returns:
//   - withdrawnHeight: withdrawal block height recorded on the deposit; zero when the entry is missing or invalid.
//   - err: nil for a valid stored deposit; non-nil when the entry is missing or has an invalid type.
func (lp *launchpadV1) GetDepositWithdrawnHeight(depositId string) (int64, error) {
	deposit, err := lp.getDepositValue(depositId)
	if err != nil {
		return 0, err
	}
	return deposit.WithdrawnHeight(), nil
}

// GetDepositWithdrawnTime returns the withdrawn time of a deposit by its ID.
//
// Parameters:
//   - depositId: unique deposit identifier to look up.
//
// Returns:
//   - withdrawnTime: withdrawal timestamp in Unix seconds; zero when the entry is missing or invalid.
//   - err: nil for a valid stored deposit; non-nil when the entry is missing or has an invalid type.
func (lp *launchpadV1) GetDepositWithdrawnTime(depositId string) (int64, error) {
	deposit, err := lp.getDepositValue(depositId)
	if err != nil {
		return 0, err
	}
	return deposit.WithdrawnTime(), nil
}

// GetDepositCreatedHeight returns the created height of a deposit by its ID.
//
// Parameters:
//   - depositId: unique deposit identifier to look up.
//
// Returns:
//   - createdHeight: creation block height recorded on the deposit; zero when the entry is missing or invalid.
//   - err: nil for a valid stored deposit; non-nil when the entry is missing or has an invalid type.
func (lp *launchpadV1) GetDepositCreatedHeight(depositId string) (int64, error) {
	deposit, err := lp.getDepositValue(depositId)
	if err != nil {
		return 0, err
	}
	return deposit.CreatedHeight(), nil
}

// GetDepositCreatedAt returns the created time of a deposit by its ID.
//
// Parameters:
//   - depositId: unique deposit identifier to look up.
//
// Returns:
//   - createdAt: creation timestamp in Unix seconds; zero when the entry is missing or invalid.
//   - err: nil for a valid stored deposit; non-nil when the entry is missing or has an invalid type.
func (lp *launchpadV1) GetDepositCreatedAt(depositId string) (int64, error) {
	deposit, err := lp.getDepositValue(depositId)
	if err != nil {
		return 0, err
	}
	return deposit.CreatedAt(), nil
}

// GetDepositEndTime returns the end time of a deposit by its ID.
//
// Parameters:
//   - depositId: unique deposit identifier to look up.
//
// Returns:
//   - endTime: tier end timestamp in Unix seconds; zero when the entry is missing or invalid.
//   - err: nil for a valid stored deposit; non-nil when the entry is missing or has an invalid type.
func (lp *launchpadV1) GetDepositEndTime(depositId string) (int64, error) {
	deposit, err := lp.getDepositValue(depositId)
	if err != nil {
		return 0, err
	}
	return deposit.EndTime(), nil
}

// GetTotalGNSStakedAmount returns the total amount of GNS currently staked across all launchpad deposits.
//
// Returns:
//   - amount: aggregate GNS amount currently staked across all launchpad deposits.
func (lp *launchpadV1) GetTotalGNSStakedAmount() int64 {
	return lp.store.GetTotalGNSStakedAmount()
}

// GetProjectTierRewardManagerCount returns the total number of reward managers.
//
// Returns:
//   - count: number of project-tier reward-manager entries currently stored.
func (lp *launchpadV1) GetProjectTierRewardManagerCount() int {
	managers := lp.store.GetProjectTierRewardManagers()
	return managers.Size()
}

// GetProjectTierRewardManager retrieves a reward manager by project tier ID.
// Returns nil and error if reward manager not found.
//
// Parameters:
//   - projectTierId: composite project-tier identifier whose reward manager is requested.
//
// Returns:
//   - manager: matching reward manager; nil when no entry exists or its value has an invalid type.
//   - err: nil for a valid manager; non-nil when the entry is absent or has an invalid type.
func (lp *launchpadV1) GetProjectTierRewardManager(projectTierId string) (*launchpad.RewardManager, error) {
	managers := lp.store.GetProjectTierRewardManagers()
	value := managers.Get(projectTierId)
	if value == nil {
		return nil, makeErrorWithDetails(errDataNotFound, "reward manager not found")
	}

	manager, ok := value.(*launchpad.RewardManager)
	if !ok {
		return nil, errors.New("invalid reward manager type")
	}

	return manager, nil
}

// GetProjectTierRewardDistributeAmountPerSecondX128 returns the distribute amount per second (Q128) of a reward manager.
// Returns nil and error if reward manager not found.
//
// Parameters:
//   - projectTierId: composite project-tier identifier whose reward manager is requested.
//
// Returns:
//   - amountPerSecondX128: per-second distribution rate encoded as a Q128 fixed-point value; nil when lookup fails.
//   - err: nil when found; non-nil when the reward manager is absent or has an invalid type.
func (lp *launchpadV1) GetProjectTierRewardDistributeAmountPerSecondX128(projectTierId string) (*uint256.Uint, error) {
	manager, err := lp.GetProjectTierRewardManager(projectTierId)
	if err != nil {
		return nil, err
	}

	return manager.DistributeAmountPerSecondX128(), nil
}

// GetProjectTierRewardAccumulatedRewardPerDepositX128 returns the accumulated reward per deposit (Q128) of a reward manager.
// Returns nil and error if reward manager not found.
//
// Parameters:
//   - projectTierId: composite project-tier identifier whose reward manager is requested.
//
// Returns:
//   - accumulatedRewardPerDepositX128: accumulated reward index per deposited GNS, encoded as Q128; nil when lookup fails.
//   - err: nil when found; non-nil when the reward manager is absent or has an invalid type.
func (lp *launchpadV1) GetProjectTierRewardAccumulatedRewardPerDepositX128(projectTierId string) (*uint256.Uint, error) {
	manager, err := lp.GetProjectTierRewardManager(projectTierId)
	if err != nil {
		return nil, err
	}

	return manager.AccumulatedRewardPerDepositX128(), nil
}

// GetProjectTierRewardTotalDistributeAmount returns the total distribute amount of a reward manager.
// Returns 0 and error if reward manager not found.
//
// Parameters:
//   - projectTierId: composite project-tier identifier whose reward manager is requested.
//
// Returns:
//   - amount: total token amount allocated to the reward manager; zero when lookup fails.
//   - err: nil when found; non-nil when the reward manager is absent or has an invalid type.
func (lp *launchpadV1) GetProjectTierRewardTotalDistributeAmount(projectTierId string) (int64, error) {
	manager, err := lp.GetProjectTierRewardManager(projectTierId)
	if err != nil {
		return 0, err
	}

	return manager.TotalDistributeAmount(), nil
}

// GetProjectTierRewardTotalClaimedAmount returns the total claimed amount of a reward manager.
// Returns 0 and error if reward manager not found.
//
// Parameters:
//   - projectTierId: composite project-tier identifier whose reward manager is requested.
//
// Returns:
//   - amount: total token amount already claimed from the reward manager; zero when lookup fails.
//   - err: nil when found; non-nil when the reward manager is absent or has an invalid type.
func (lp *launchpadV1) GetProjectTierRewardTotalClaimedAmount(projectTierId string) (int64, error) {
	manager, err := lp.GetProjectTierRewardManager(projectTierId)
	if err != nil {
		return 0, err
	}

	return manager.TotalClaimedAmount(), nil
}

// GetProjectTierRewardDistributeStartTime returns the distribute start time of a reward manager.
// Returns 0 and error if reward manager not found.
//
// Parameters:
//   - projectTierId: composite project-tier identifier whose reward manager is requested.
//
// Returns:
//   - startTime: reward distribution start timestamp in Unix seconds; zero when lookup fails.
//   - err: nil when found; non-nil when the reward manager is absent or has an invalid type.
func (lp *launchpadV1) GetProjectTierRewardDistributeStartTime(projectTierId string) (int64, error) {
	manager, err := lp.GetProjectTierRewardManager(projectTierId)
	if err != nil {
		return 0, err
	}

	return manager.DistributeStartTime(), nil
}

// GetProjectTierRewardDistributeEndTime returns the distribute end time of a reward manager.
// Returns 0 and error if reward manager not found.
//
// Parameters:
//   - projectTierId: composite project-tier identifier whose reward manager is requested.
//
// Returns:
//   - endTime: reward distribution end timestamp in Unix seconds; zero when lookup fails.
//   - err: nil when found; non-nil when the reward manager is absent or has an invalid type.
func (lp *launchpadV1) GetProjectTierRewardDistributeEndTime(projectTierId string) (int64, error) {
	manager, err := lp.GetProjectTierRewardManager(projectTierId)
	if err != nil {
		return 0, err
	}

	return manager.DistributeEndTime(), nil
}

// GetProjectTierRewardAccumulatedDistributeAmount returns a legacy reward-manager field.
// The v1 reward paths do not maintain it, so normal reads return zero unless it
// was explicitly set.
//
// Parameters:
//   - projectTierId: composite project-tier identifier whose reward manager is requested.
//
// Returns:
//   - amount: legacy accumulated-distribution amount, normally zero in v1 unless explicitly set.
//   - err: nil when found; non-nil when the reward manager is absent or has an invalid type.
func (lp *launchpadV1) GetProjectTierRewardAccumulatedDistributeAmount(projectTierId string) (int64, error) {
	manager, err := lp.GetProjectTierRewardManager(projectTierId)
	if err != nil {
		return 0, err
	}

	return manager.AccumulatedDistributeAmount(), nil
}

// GetProjectTierRewardAccumulatedTime returns the accumulated time of a reward manager.
// Returns 0 and error if reward manager not found.
//
// Parameters:
//   - projectTierId: composite project-tier identifier whose reward manager is requested.
//
// Returns:
//   - accumulatedTime: timestamp in Unix seconds at which reward accumulation was last updated; zero before an update.
//   - err: nil when found; non-nil when the reward manager is absent or has an invalid type.
func (lp *launchpadV1) GetProjectTierRewardAccumulatedTime(projectTierId string) (int64, error) {
	manager, err := lp.GetProjectTierRewardManager(projectTierId)
	if err != nil {
		return 0, err
	}

	return manager.AccumulatedTime(), nil
}

// GetProjectTierRewardClaimableDuration returns the configured initial delay
// before a deposit's reward becomes claimable.
// Returns 0 and error if reward manager not found.
//
// Parameters:
//   - projectTierId: composite project-tier identifier whose reward manager is requested.
//
// Returns:
//   - duration: delay in seconds from a deposit's CreatedAt until its reward becomes claimable; each deposit's claimable time is capped at the manager's distribution end time. This value does not define post-claim expiry.
//   - err: nil when found; non-nil when the reward manager is absent or has an invalid type.
func (lp *launchpadV1) GetProjectTierRewardClaimableDuration(projectTierId string) (int64, error) {
	manager, err := lp.GetProjectTierRewardManager(projectTierId)
	if err != nil {
		return 0, err
	}

	return manager.RewardClaimableDuration(), nil
}

// GetRewardState retrieves a reward state by project tier ID and deposit ID.
// Returns nil and error if reward manager or reward state not found.
//
// Parameters:
//   - projectTierId: composite project-tier identifier whose reward manager contains the state.
//   - depositId: unique deposit identifier whose reward state is requested.
//
// Returns:
//   - rewardState: matching reward state; nil when the manager or state is absent or has an invalid type.
//   - err: nil when found; non-nil when the manager or state is absent or has an invalid type.
func (lp *launchpadV1) GetRewardState(projectTierId string, depositId string) (*launchpad.RewardState, error) {
	managers := lp.store.GetProjectTierRewardManagers()
	value := managers.Get(projectTierId)
	if value == nil {
		return nil, makeErrorWithDetails(errDataNotFound, "reward manager not found")
	}

	manager, ok := value.(*launchpad.RewardManager)
	if !ok {
		return nil, errors.New("invalid reward manager type")
	}

	rewards := manager.Rewards()
	rewardValue := rewards.Get(depositId)
	if rewardValue == nil {
		return nil, makeErrorWithDetails(errDataNotFound, "reward state not found")
	}

	rewardState, ok := rewardValue.(*launchpad.RewardState)
	if !ok {
		return nil, errors.New("invalid reward state type")
	}

	return rewardState, nil
}

// GetProjectActiveStatus returns whether a project is currently active.
// Returns false and error if project not found.
//
// Parameters:
//   - projectId: unique launchpad project identifier to look up.
//
// Returns:
//   - active: true when the project's standard 180-day tier is active at the current Unix time; false when inactive.
//   - err: nil when found; non-nil when projectId is not present in state.
func (lp *launchpadV1) GetProjectActiveStatus(projectId string) (bool, error) {
	project, err := lp.getProject(projectId)
	if err != nil {
		return false, err
	}

	currentTime := time.Now().Unix()
	return isProjectActive(project, currentTime), nil
}
