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
	// Proposal storage
	HasProposalsStoreKey() bool
	GetProposals() *avl.Tree
	SetProposals(proposals *avl.Tree) error

	HasProposalNextIDStoreKey() bool
	GetProposalNextID() uint64
	SetProposalNextID(nextID uint64) error

	// HasProposal(proposalId uint64) bool
	// GetProposal(proposalId uint64) (*Proposal, bool)
	// SetProposal(proposalId uint64, proposal *Proposal) error

	// // Config storage
	// HasConfigsStoreKey() bool
	// GetConfigs() *avl.Tree
	// SetConfigs(configs *avl.Tree) error

	// HasConfigNextVersionStoreKey() bool
	// GetConfigNextVersion() uint64
	// SetConfigNextVersion(version uint64) error

	// HasConfig(version uint64) bool
	// GetConfig(version uint64) (*Config, bool)
	// SetConfig(version uint64, config *Config) error

	// // Proposal manager storage
	// HasProposalManagerStoreKey() bool
	// GetProposalManager() *ProposalManager
	// SetProposalManager(manager *ProposalManager) error

	// // Voting info storage
	// HasProposalVotesStoreKey() bool
	// GetProposalVotes() *avl.Tree
	// SetProposalVotes(votes *avl.Tree) error
}
