package launchpad

import (
	"gno.land/p/gnoswap/uint256"
	"gno.land/p/nt/avl"
)

type ILaunchpad interface {
	ILaunchpadProject
	ILaunchpadDeposit
	ILaunchpadGetter
}

type ILaunchpadProject interface {
	CreateProject(
		name string,
		tokenPath string,
		recipient address,
		depositAmount int64,
		conditionTokens string,
		conditionAmounts string,
		tier30Ratio int64,
		tier90Ratio int64,
		tier180Ratio int64,
		startTime int64,
	) string
	TransferLeftFromProjectByAdmin(projectID string, recipient address) int64
	CollectProtocolFee()
}

type ILaunchpadDeposit interface {
	DepositGns(targetProjectTierID string, depositAmount int64, referrer string) string
	CollectDepositGns(depositID string) (int64, error)
	CollectRewardByDepositId(depositID string) int64
}

type ILaunchpadGetter interface {
	GetProjectCount() int64
	GetProjectIDs(offset, limit int64) []string
	GetProject(projectId string) (*Project, error)
	GetProjectName(projectId string) (string, error)
	GetProjectTokenPath(projectId string) (string, error)
	GetProjectDepositAmount(projectId string) (int64, error)
	GetProjectRecipient(projectId string) (address, error)
	GetProjectCondition(projectId string, tokenPath string) (*ProjectCondition, error)
	GetProjectTiersRatios(projectId string) (map[int64]int64, error)
	GetProjectCreatedHeight(projectId string) (int64, error)
	GetProjectCreatedAt(projectId string) (int64, error)

	GetProjectTier(projectId string, tier int64) (*ProjectTier, error)
	GetProjectTierDistributeAmountPerSecondX128(projectId string, tier int64) (*uint256.Uint, error)
	GetProjectTierTotalDistributeAmount(projectId string, tier int64) (int64, error)
	GetProjectTierTotalDepositAmount(projectId string, tier int64) (int64, error)
	GetProjectTierTotalWithdrawAmount(projectId string, tier int64) (int64, error)
	GetProjectTierTotalDepositCount(projectId string, tier int64) (int64, error)
	GetProjectTierTotalWithdrawCount(projectId string, tier int64) (int64, error)
	GetProjectTierTotalCollectedAmount(projectId string, tier int64) (int64, error)
	GetProjectTierStartTime(projectId string, tier int64) (int64, error)
	GetProjectTierEndTime(projectId string, tier int64) (int64, error)

	GetDepositCount() int64
	GetDepositIDs(offset, limit int64) []string
	GetCurrentDepositId() int64
	GetDeposit(depositId string) (*Deposit, error)
	GetDepositProjectID(depositId string) (string, error)
	GetDepositTier(depositId string) (int64, error)
	GetDepositProjectTierID(depositId string) (string, error)
	GetDepositAmount(depositId string) (int64, error)
	GetDepositWithdrawnHeight(depositId string) (int64, error)
	GetDepositWithdrawnTime(depositId string) (int64, error)
	GetDepositCreatedHeight(depositId string) (int64, error)
	GetDepositCreatedAt(depositId string) (int64, error)
	GetDepositEndTime(depositId string) (int64, error)

	GetRewardManagerCount() int64
	GetRewardManagerIDs(offset, limit int64) []string
	GetRewardManager(projectTierId string) (*RewardManager, error)
	GetRewardManagerDistibuteAmountPerSecondX128(projectTierId string) (*uint256.Uint, error)
	GetRewardManagerAccumulatedRewardPerDepositX128(projectTierId string) (*uint256.Uint, error)
	GetRewardManagerTotalDistributeAmount(projectTierId string) (int64, error)
	GetRewardManagerTotalClaimedAmount(projectTierId string) (int64, error)
	GetRewardManagerDistributeStartTime(projectTierId string) (int64, error)
	GetRewardManagerDistributeEndTime(projectTierId string) (int64, error)
	GetRewardManagerAccumulatedDistributeAmount(projectTierId string) (int64, error)
	GetRewardManagerAccumulatedHeight(projectTierId string) (int64, error)
	GetRewardManagerAccumulatedTime(projectTierId string) (int64, error)
	GetRewardManagerRewardClaimableDuration(projectTierId string) (int64, error)

	GetRewardState(projectTierId string, depositId string) (*RewardState, error)
	GetClaimableRewardByProjectId(projectId string) (string, error)
	GetClaimableRewardByAddress(addr address) string
	GetProjectActiveStatus(projectId string) (bool, error)
}

type ILaunchpadStore interface {
	HasProjectsKey() bool
	GetProjects() *avl.Tree
	SetProjects(projects *avl.Tree) error

	HasProjectTierRewardManagersKey() bool
	GetProjectTierRewardManagers() *avl.Tree
	SetProjectTierRewardManagers(managers *avl.Tree) error

	// DepositCounter
	HasDepositCounterStoreKey() bool
	GetDepositCounter() *Counter
	SetDepositCounter(counter *Counter) error
	NextDepositID() string

	HasDepositsKey() bool
	GetDeposits() *avl.Tree
	SetDeposits(deposits *avl.Tree) error
}
