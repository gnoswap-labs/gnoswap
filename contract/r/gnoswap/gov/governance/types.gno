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

	// GetMaxSmoothingPeriod returns the maximum smoothing period for delegation history cleanup.
	GetMaxSmoothingPeriod() int64

	// GetOldestActiveProposalSnapshotTime returns the oldest snapshot time among active proposals.
	GetOldestActiveProposalSnapshotTime() (int64, bool)
}

type IGovernanceStore interface {
	// Counter methods
	HasConfigCounterStoreKey() bool
	GetConfigCounter() *Counter
	SetConfigCounter(counter *Counter) error

	HasProposalCounterStoreKey() bool
	GetProposalCounter() *Counter
	SetProposalCounter(counter *Counter) error

	// Config methods
	HasConfigsStoreKey() bool
	SetConfigs(configs *avl.Tree) error
	SetConfig(version int64, config Config) error
	GetConfig(version int64) (Config, bool)

	// Proposal methods
	HasProposalsStoreKey() bool
	GetProposal(proposalID int64) (*Proposal, bool)
	SetProposal(proposalID int64, proposal *Proposal) error
	SetProposals(proposals *avl.Tree) error

	// Proposal voting info methods
	HasProposalUserVotingInfosStoreKey() bool
	GetProposalUserVotingInfos() *avl.Tree
	SetProposalUserVotingInfos(votingInfos *avl.Tree) error
	GetProposalVotingInfos(proposalID int64) (*avl.Tree, bool)
	SetProposalVotingInfos(proposalID int64, votingInfos *avl.Tree) error

	// User proposals methods
	HasUserProposalsStoreKey() bool
	GetUserProposalIDs(user string) ([]int64, bool)
	SetUserProposals(userProposals *avl.Tree) error
	AddUserProposal(user string, proposalID int64) error
	RemoveUserProposal(user string, proposalID int64) error
}

// GovStakerAccessor provides an interface for accessing gov staker functionality.
// This abstraction allows for easier testing by enabling mock implementations.
type GovStakerAccessor interface {
	// GetTotalDelegationAmountAtSnapshot returns the total delegation amount at a specific snapshot time.
	GetTotalDelegationAmountAtSnapshot(snapshotTime int64) (int64, bool)

	// GetUserDelegationAmountAtSnapshot returns the user delegation amount at a specific snapshot time.
	GetUserDelegationAmountAtSnapshot(userAddr address, snapshotTime int64) (int64, bool)
}
