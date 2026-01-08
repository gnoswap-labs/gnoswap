package launchpad

import "gno.land/p/nt/avl"

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
	// Store data getters
	GetProjectCount() int64
	GetDepositCount() int64
	GetRewardManagerCount() int64
	GetCurrentDepositId() int64

	// Domain type getters (single query)
	GetProject(projectId string) (*Project, error)
	GetDeposit(depositId string) (*Deposit, error)
	GetProjectTier(projectId string, tier int64) (*ProjectTier, error)
	GetProjectCondition(projectId string, tokenPath string) (*ProjectCondition, error)
	GetRewardManager(projectTierId string) (*RewardManager, error)
	GetRewardState(projectTierId string, depositId string) (*RewardState, error)

	// Logic query getters
	GetClaimableRewardByProjectId(projectId string) (string, error)
	GetClaimableRewardByAddress(addr address) string
	GetProjectActiveStatus(projectId string) (bool, error)

	// Pagination getters
	GetProjects(offset, limit int64) []string
	GetDeposits(offset, limit int64) []string
	GetRewardManagers(offset, limit int64) []string
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
