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
	) (uint64, error)

	ProposeCommunityPoolSpend(
		title string,
		description string,
		tokenPath string,
		toAddress address,
		amount uint64,
	) (uint64, error)

	ProposeParameterChange(
		title string,
		description string,
		changes string,
	) (uint64, error)

	// Voting
	Vote(
		proposalId uint64,
		voteType uint8,
	) error

	// Execution
	Execute(
		proposalId uint64,
	) error

	Cancel(
		proposalId uint64,
	) error

	// Configuration
	Reconfigure(
		votingStartDelay uint64,
		votingPeriod uint64,
		votingWeightSmoothingDuration uint64,
		quorum uint64,
		proposalCreationThreshold uint64,
		executionDelay uint64,
		executionWindow uint64,
	) error
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
