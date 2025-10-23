package governance

type IGovernance interface {
	IGovernanceManager
	IGovernanceApi
}

type IGovernanceManager interface {
	// Proposal management
	ProposeText(
		title string,
		description string,
	) int64

	ProposeCommunityPoolSpend(
		title string,
		description string,
		to address,
		tokenPath string,
		amount int64,
	) int64

	ProposeParameterChange(
		title string,
		description string,
		numToExecute int64,
		executions string,
	) int64

	// Voting
	Vote(
		proposalId int64,
		yes bool,
	) string

	// Execution
	Execute(
		proposalId int64,
	) int64

	Cancel(
		proposalId int64,
	) int64

	// Configuration
	Reconfigure(
		votingStartDelay int64,
		votingPeriod int64,
		votingWeightSmoothingDuration int64,
		quorum int64,
		proposalCreationThreshold int64,
		executionDelay int64,
		executionWindow int64,
	) int64
}

type IGovernanceApi interface {
	GetProposerByProposalId(id int64) string
	GetProposalTypeByProposalId(id int64) string

	GetYeaByProposalId(id int64) int64
	GetNayByProposalId(id int64) int64


	GetProposalById(id int64) string
	GetVoteStatusFromProposalById(id int64) string
	GetVoteByAddressFromProposalById(addr address, id int64) string

	GetConfigVersionByProposalId(id int64) int64
	GetQuorumAmountByProposalId(id int64) int64
	GetTitleByProposalId(id int64) string
	GetDescriptionByProposalId(id int64) string

	GetExecutionStateByProposalId(id int64) string
	GetLatestConfig() Config
	GetConfig(configVersion int64) Config
}

type IGovernanceStore interface {
	HasGovernanceStateStoreKey() bool
	GetGovernanceState() GovernanceState
	SetGovernanceState(governanceState GovernanceState) error

	HasProposalNextIDStoreKey() bool
	GetProposalNextID() uint64
	SetProposalNextID(nextID uint64) error
}

type GovernanceState interface {
	CurrentConfigVersion() int64
}
