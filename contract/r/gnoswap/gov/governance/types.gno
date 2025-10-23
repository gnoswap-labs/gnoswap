package governance

import (
	"gno.land/p/nt/avl"
)

type IGovernance interface {
	IGovernanceManager
	// IGovernanceGetter
	// IGovernanceApi
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

type IGovernanceGetter interface {
	// Proposal getters
	// GetProposal(proposalId uint64) (*Proposal, error)
	// GetProposals() []*Proposal
	// GetProposalsByAddress(address address) []*Proposal
	// GetProposalType(proposalId uint64) (ProposalType, error)
	// GetProposalStatus(proposalId uint64) (ProposalStatusType, error)

	// // Config getters
	// GetConfig(version uint64) (*Config, error)
}

type IGovernanceApi interface {
	// ApiGetProposals() string
	// ApiGetProposalById(proposalId uint64) string
	// ApiGetProposalVotes(proposalId uint64) string
	// ApiGetConfig() string
}

type IGovernanceStore interface {
	HasGovernanceStateStoreKey() bool
	GetGovernanceState() GovernanceState
	SetGovernanceState(governanceState GovernanceState) error

	// Proposal storage
	HasProposalsStoreKey() bool
	GetProposals() *avl.Tree
	SetProposals(proposals *avl.Tree) error

	HasProposalNextIDStoreKey() bool
	GetProposalNextID() uint64
	SetProposalNextID(nextID uint64) error
}

type GovernanceState interface {
	CurrentConfigVersion() int64
}
