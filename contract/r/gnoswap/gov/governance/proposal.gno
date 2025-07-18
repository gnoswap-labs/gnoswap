package governance

import (
	"std"
)

// ProposalType defines the different types of proposals supported by the governance system.
// Each type has different execution behavior and validation requirements.
type ProposalType string

const (
	Text               ProposalType = "TEXT"                 // Informational proposals for community discussion
	CommunityPoolSpend ProposalType = "COMMUNITY_POOL_SPEND" // Proposals to spend community pool funds
	ParameterChange    ProposalType = "PARAMETER_CHANGE"     // Proposals to modify system parameters
)

// String returns the human-readable string representation of the proposal type.
//
// Returns:
//   - string: formatted proposal type name
func (p ProposalType) String() string {
	switch p {
	case Text:
		return "Text"
	case CommunityPoolSpend:
		return "CommunityPoolSpend"
	case ParameterChange:
		return "ParameterChange"
	default:
		return "Unknown"
	}
}

// IsExecutable determines whether this proposal type can be executed.
// Text proposals are informational only and cannot be executed.
//
// Returns:
//   - bool: true if proposal type can be executed
func (p ProposalType) IsExecutable() bool {
	switch p {
	case Text:
		return false
	case CommunityPoolSpend, ParameterChange:
		return true
	default:
		return false
	}
}

// Proposal represents a governance proposal with all its associated data and state.
// This is the core structure that tracks proposal lifecycle from creation to execution.
type Proposal struct {
	id            int64               // Unique identifier for the proposal
	proposer      std.Address         // The address of the proposer
	configVersion int64               // The version of the governance config used
	status        *ProposalStatus     // Current status and voting information
	metadata      *ProposalMetadata   // Title and description
	data          *ProposalData       // Type-specific proposal data
	createdAt     int64               // Creation timestamp
	createdHeight int64               // Block height at creation
}

// ID returns the unique identifier of the proposal.
//
// Returns:
//   - int64: proposal ID
func (p *Proposal) ID() int64 {
	return p.id
}

// Type returns the type of this proposal.
//
// Returns:
//   - ProposalType: the proposal type
func (p *Proposal) Type() ProposalType {
	return p.data.ProposalType()
}

// IsTextType checks if this is a text proposal.
//
// Returns:
//   - bool: true if this is a text proposal
func (p *Proposal) IsTextType() bool {
	return p.Type() == Text
}

// IsCommunityPoolSpendType checks if this is a community pool spend proposal.
//
// Returns:
//   - bool: true if this is a community pool spend proposal
func (p *Proposal) IsCommunityPoolSpendType() bool {
	return p.Type() == CommunityPoolSpend
}

// IsParameterChangeType checks if this is a parameter change proposal.
//
// Returns:
//   - bool: true if this is a parameter change proposal
func (p *Proposal) IsParameterChangeType() bool {
	return p.Type() == ParameterChange
}

// Status returns the current status string of the proposal at the given time.
//
// Parameters:
//   - current: timestamp to check status at
//
// Returns:
//   - string: human-readable status
func (p *Proposal) Status(current int64) string {
	return p.status.StatusType(current).String()
}

// StatusType returns the current status type of the proposal at the given time.
//
// Parameters:
//   - current: timestamp to check status at
//
// Returns:
//   - ProposalStatusType: detailed status type
func (p *Proposal) StatusType(current int64) ProposalStatusType {
	return p.status.StatusType(current)
}

// IsActive determines if the proposal is currently active (can be voted on or executed).
// A proposal is considered active if it's not rejected, expired, executed, or canceled.
//
// Parameters:
//   - current: timestamp to check activity at
//
// Returns:
//   - bool: true if proposal is active
func (p *Proposal) IsActive(current int64) bool {
	// Text proposals become inactive once they pass (no execution needed)
	if p.IsTextType() {
		if p.status.IsPassed(current) {
			return false
		}
	}

	// If the proposal is rejected, expired, executed, or canceled, it is not active
	if p.status.IsRejected(current) ||
		p.status.IsExpired(current) ||
		p.status.IsExecuted(current) ||
		p.status.IsCanceled(current) {
		return false
	}

	return true
}

// IsVotingPeriod checks if the proposal is currently in its voting period.
//
// Parameters:
//   - votedAt: timestamp to check voting period at
//
// Returns:
//   - bool: true if voting is currently allowed
func (p *Proposal) IsVotingPeriod(votedAt int64) bool {
	return p.StatusType(votedAt) == StatusActive
}

// IsExecutable determines if the proposal can be executed at the given time.
// Only executable proposal types that have passed voting can be executed.
//
// Parameters:
//   - current: timestamp to check executability at
//
// Returns:
//   - bool: true if proposal can be executed
func (p *Proposal) IsExecutable(current int64) bool {
	// Only certain proposal types can be executed
	if !p.Type().IsExecutable() {
		return false
	}

	return p.status.IsExecutable(current)
}

// Validate performs comprehensive validation of the proposal data and metadata.
// This ensures all proposal components meet requirements before storage.
//
// Returns:
//   - error: validation error if any component is invalid
func (p *Proposal) Validate() error {
	// Validate type-specific proposal data
	if err := p.data.Validate(); err != nil {
		return err
	}

	// Validate proposal metadata (title and description)
	if err := p.metadata.Validate(); err != nil {
		return err
	}

	return nil
}

// Title returns the proposal title.
//
// Returns:
//   - string: proposal title
func (p *Proposal) Title() string {
	return p.metadata.Title()
}

// Description returns the proposal description.
//
// Returns:
//   - string: proposal description
func (p *Proposal) Description() string {
	return p.metadata.Description()
}

// ConfigVersion returns the governance configuration version used for this proposal.
//
// Returns:
//   - int64: configuration version
func (p *Proposal) ConfigVersion() int64 {
	return p.configVersion
}

// Proposer returns the address of the proposal creator.
//
// Returns:
//   - std.Address: proposer address
func (p *Proposal) Proposer() std.Address {
	return p.proposer
}

// CreatedAt returns the creation timestamp of the proposal.
//
// Returns:
//   - int64: creation timestamp
func (p *Proposal) CreatedAt() int64 {
	return p.status.schedule.createTime
}

// VotingYesWeight returns the total weight of "yes" votes.
//
// Returns:
//   - int64: total "yes" vote weight
func (p *Proposal) VotingYesWeight() int64 {
	return p.status.voteStatus.yea
}

// VotingNoWeight returns the total weight of "no" votes.
//
// Returns:
//   - int64: total "no" vote weight
func (p *Proposal) VotingNoWeight() int64 {
	return p.status.voteStatus.nay
}

// VotingTotalWeight returns the total weight of all votes cast.
//
// Returns:
//   - int64: total vote weight
func (p *Proposal) VotingTotalWeight() int64 {
	return p.status.voteStatus.TotalVoteWeight()
}

// VotingQuorumAmount returns the minimum vote weight required for the proposal to pass.
//
// Returns:
//   - int64: quorum amount
func (p *Proposal) VotingQuorumAmount() int64 {
	return p.status.voteStatus.quorumAmount
}

// VotingMaxWeight returns the maximum possible voting weight for this proposal.
//
// Returns:
//   - int64: maximum voting weight
func (p *Proposal) VotingMaxWeight() int64 {
	return p.status.voteStatus.maxVotingWeight
}

// CommunityPoolSpendTokenPath returns the token path for community pool spend proposals.
// Returns empty string for other proposal types.
//
// Returns:
//   - string: token path or empty string
func (p *Proposal) CommunityPoolSpendTokenPath() string {
	if p.data == nil {
		return ""
	}

	return p.data.communityPoolSpend.tokenPath
}

// vote records a vote for this proposal and updates vote tallies.
// This is an internal method called during the voting process.
//
// Parameters:
//   - votedYes: true for "yes" vote, false for "no" vote
//   - weight: voting weight to apply
//
// Returns:
//   - error: voting error if operation fails
func (p *Proposal) vote(votedYes bool, weight int64) error {
	return p.status.vote(votedYes, weight)
}

// updateVoteStatus updates the voting status with new parameters.
// This is used for dynamic voting requirement adjustments.
//
// Parameters:
//   - maxVotingWeight: updated maximum voting weight
//   - quorum: updated quorum percentage
//
// Returns:
//   - error: update error if operation fails
func (p *Proposal) updateVoteStatus(maxVotingWeight, quorum int64) error {
	return p.status.updateVoteStatus(maxVotingWeight, quorum)
}

// execute marks the proposal as executed and records execution details.
// This method validates execution conditions before proceeding.
//
// Parameters:
//   - executedAt: execution timestamp
//   - executedHeight: execution block height
//   - executedBy: address of the executor
//
// Returns:
//   - error: execution error if proposal cannot be executed
func (p *Proposal) execute(executedAt int64, executedHeight int64, executedBy std.Address) error {
	// Verify proposal is in executable state
	if !p.IsExecutable(executedAt) {
		return errProposalNotExecutable
	}

	// Mark proposal as executed
	return p.status.execute(executedAt, executedHeight, executedBy)
}

// updateExecuteResult updates the execution result status.
// This is called after execution attempt to record success or failure.
//
// Parameters:
//   - success: true if execution was successful
func (p *Proposal) updateExecuteResult(success bool) {
	p.status.updateExecuteResult(success)
}

// cancel marks the proposal as canceled and records cancellation details.
// This method validates cancellation conditions before proceeding.
//
// Parameters:
//   - canceledAt: cancellation timestamp
//   - canceledHeight: cancellation block height
//   - canceledBy: address of the canceller
//
// Returns:
//   - error: cancellation error if proposal cannot be canceled
func (p *Proposal) cancel(canceledAt int64, canceledHeight int64, canceledBy std.Address) error {
	// Note: For cancellation, we check against executability which includes timing validation
	if !p.IsExecutable(canceledAt) {
		return errProposalNotExecutable
	}

	// Mark proposal as canceled
	return p.status.cancel(canceledAt, canceledHeight, canceledBy)
}

// NewProposal creates a new proposal instance with the provided parameters.
// This is the main constructor for creating governance proposals.
//
// Parameters:
//   - proposalID: unique identifier for the proposal
//   - status: proposal status containing voting and scheduling information
//   - metadata: proposal title and description
//   - data: type-specific proposal data
//   - proposerAddress: address of the proposal creator
//   - configVersion: governance configuration version
//   - createdAt: creation timestamp
//   - createdHeight: creation block height
//
// Returns:
//   - *Proposal: newly created proposal instance
func NewProposal(
	proposalID int64,
	status *ProposalStatus,
	metadata *ProposalMetadata,
	data *ProposalData,
	proposerAddress std.Address,
	configVersion int64,
	createdAt int64,
	createdHeight int64,
) *Proposal {
	return &Proposal{
		id:            proposalID,
		proposer:      proposerAddress,
		status:        status,
		metadata:      metadata,
		data:          data,
		configVersion: configVersion,
		createdAt:     createdAt,
		createdHeight: createdHeight,
	}
}
