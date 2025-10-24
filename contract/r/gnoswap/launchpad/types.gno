package launchpad

import "gno.land/p/nt/avl"

type ILaunchpad interface {
	ILaunchpadProject
	ILaunchpadDeposit
	ILaunchpadApi
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
}

type ILaunchpadApi interface {
	ApiGetProjectAndTierStatisticsByProjectId(projectId string) string
	ApiGetProjectStatisticsByProjectId(projectId string) string
	ApiGetTierStatisticsByProjectId(projectId string) string
	ApiGetProjectStatisticsByProjectTierId(tierId string) string
	ApiGetProjectActiveOf(projectId string) string
	ApiGetDepositByDepositId(depositId string) string
	ApiGetProjectRecipientRewardByProjectId(projectId string) string
	ApiGetProjectRecipientRewardByAddress(address address) string
}

type ILaunchpadStore interface {
	HasProjectsKey() bool
	GetProjects() *avl.Tree
	SetProjects(projects *avl.Tree) error

	HasProjectTierRewardManagersKey() bool
	GetProjectTierRewardManagers() *avl.Tree
	SetProjectTierRewardManagers(managers *avl.Tree) error

	HasDepositCounterKey() bool
	GetDepositCounter() Counter
	SetDepositCounter(counter Counter) error

	HasDepositsKey() bool
	GetDeposits() *avl.Tree
	SetDeposits(deposits *avl.Tree) error
}

type LaunchpadState interface {
	Projects() *avl.Tree
	ProjectTierRewardManagers() *avl.Tree
	DepositCounter() Counter
	Deposits() *avl.Tree
}

type Counter interface {
	Get() int64
	Next() int64
}
