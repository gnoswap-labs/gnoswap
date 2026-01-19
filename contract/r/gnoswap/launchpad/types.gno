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
	GetProjectCount() int
	GetProjectIDs(offset, count int) []string
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

	GetDepositCount() int
	GetCurrentDepositId() int64
	GetProjectTierDepositCount(projectId string, tier int64) int
	GetProjectTierDepositIDs(projectId string, tier int64, offset, count int) []string

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

	GetProjectTierRewardManagerCount() int
	GetProjectTierRewardManager(projectTierId string) (*RewardManager, error)
	GetProjectTierRewardDistributeAmountPerSecondX128(projectTierId string) (*uint256.Uint, error)
	GetProjectTierRewardAccumulatedRewardPerDepositX128(projectTierId string) (*uint256.Uint, error)
	GetProjectTierRewardTotalDistributeAmount(projectTierId string) (int64, error)
	GetProjectTierRewardTotalClaimedAmount(projectTierId string) (int64, error)
	GetProjectTierRewardDistributeStartTime(projectTierId string) (int64, error)
	GetProjectTierRewardDistributeEndTime(projectTierId string) (int64, error)
	GetProjectTierRewardAccumulatedDistributeAmount(projectTierId string) (int64, error)
	GetProjectTierRewardAccumulatedHeight(projectTierId string) (int64, error)
	GetProjectTierRewardAccumulatedTime(projectTierId string) (int64, error)
	GetProjectTierRewardClaimableDuration(projectTierId string) (int64, error)

	GetRewardState(projectTierId string, depositId string) (*RewardState, error)
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
