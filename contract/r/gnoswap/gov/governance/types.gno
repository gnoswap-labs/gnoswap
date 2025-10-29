package governance

import (
	"gno.land/p/nt/avl"
)

type IGovernance interface {
	IGovernanceManager
	IGovernanceApi
	IVoteApi
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

type IVoteApi interface {
	GetVoteWeight(proposalID int64, address address) int64
	GetVotedHeight(proposalID int64, address address) int64
	GetVotedAt(proposalID int64, address address) int64
}

type IGovernanceStore interface {
	// Counter methods
	HasConfigCounterStoreKey() bool
	GetConfigCounter() *Counter
	SetConfigCounter(counter *Counter) error
	IncrementConfigCounter() (int64, error)

	HasProposalCounterStoreKey() bool
	GetProposalCounter() *Counter
	SetProposalCounter(counter *Counter) error
	IncrementProposalCounter() (int64, error)

	// Config methods
	HasConfigsStoreKey() bool
	SetConfigs(configs *avl.Tree) error

	HasConfigStoreKey() bool
	SetConfig(version int64, config Config) error
	GetConfig(version int64) (Config, bool)

	// Proposal methods
	HasProposalsStoreKey() bool
	GetProposal(proposalID int64) (*Proposal, bool)
	SetProposal(proposalID int64, proposal *Proposal) error
	SetProposals(proposals *avl.Tree) error

	// Proposal voting info methods
	HasProposalVotingInfosStoreKey() bool
	GetProposalVotingInfos(proposalID int64) (map[string]*VotingInfo, bool)
	SetProposalVotingInfos(proposalID int64, votingInfos map[string]*VotingInfo) error

	HasProposalUserVotingInfosStoreKey() bool
	GetProposalUserVotingInfos() *avl.Tree
	SetProposalUserVotingInfos(votingInfos *avl.Tree) error

	// User proposals methods
	HasUserProposalsStoreKey() bool
	GetUserProposalIDs(user string) ([]int64, bool)
	AddUserProposal(user string, proposalID int64) error
	SetUserProposals(userProposals *avl.Tree) error
}
