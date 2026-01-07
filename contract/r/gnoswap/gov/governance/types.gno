package governance

import (
	"gno.land/p/nt/avl"
)

type IGovernance interface {
	IGovernanceManager
	IGovernanceGetter
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

// IGovernanceGetter provides read-only access to governance data.
type IGovernanceGetter interface {
	// Store data getters
	GetLatestConfigVersion() int64
	GetCurrentProposalID() int64
	GetMaxSmoothingPeriod() int64

	// Config getters
	GetLatestConfig() Config
	GetConfig(configVersion int64) (Config, error)

	// Proposal getters
	GetProposalCount() int
	GetProposalIDs(offset, count int) []int64
	ExistsProposal(proposalID int64) bool
	GetProposal(proposalID int64) (*Proposal, error)
	GetProposerByProposalId(proposalId int64) (address, error)
	GetProposalTypeByProposalId(proposalId int64) (ProposalType, error)
	GetYeaByProposalId(proposalId int64) (int64, error)
	GetNayByProposalId(proposalId int64) (int64, error)
	GetConfigVersionByProposalId(proposalId int64) (int64, error)
	GetQuorumAmountByProposalId(proposalId int64) (int64, error)
	GetTitleByProposalId(proposalId int64) (string, error)
	GetDescriptionByProposalId(proposalId int64) (string, error)
	GetProposalStatusByProposalId(proposalId int64) (string, error)

	// Vote getters
	GetVoteStatus(proposalId int64) (quorum, maxVotingWeight, yesWeight, noWeight int64, err error)
	GetVotingInfoCount(proposalID int64) int
	GetVotingInfoAddresses(proposalID int64, offset, count int) []address
	ExistsVotingInfo(proposalID int64, addr address) bool
	GetVotingInfo(proposalID int64, addr address) (*VotingInfo, error)
	GetVoteWeight(proposalID int64, addr address) (int64, error)
	GetVotedHeight(proposalID int64, addr address) (int64, error)
	GetVotedAt(proposalID int64, addr address) (int64, error)

	// User proposal getters
	GetUserProposalCount(user address) int
	GetUserProposalIDs(user address, offset, count int) []int64

	// Active proposal query
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
	GetProposals() *avl.Tree
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
