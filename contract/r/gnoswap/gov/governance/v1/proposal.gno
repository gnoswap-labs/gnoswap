package v1

import (
	"gno.land/r/gnoswap/gov/governance"
)

type ProposalResolver struct {
	*governance.Proposal
	statusResolver   *ProposalStatusResolver
	dataResolver     *ProposalDataResolver
	metadataResolver *ProposalMetadataResolver
}

func NewProposalResolver(proposal *governance.Proposal) *ProposalResolver {
	statusResolver := NewProposalStatusResolver(proposal.Status())
	dataResolver := NewProposalDataResolver(proposal.Data())
	metadataResolver := NewProposalMetadataResolver(proposal.Metadata())
	return &ProposalResolver{
		Proposal:         proposal,
		statusResolver:   statusResolver,
		dataResolver:     dataResolver,
		metadataResolver: metadataResolver,
	}
}

// VotingTotalWeight returns total weight of all votes cast.
func (r *ProposalResolver) VotingTotalWeight() int64 {
	return r.statusResolver.TotalVoteWeight()
}

// IsActive determines if the proposal is currently active (can be voted on or executed).
// A proposal is considered active if it's not rejected, expired, executed, or canceled.
func (r *ProposalResolver) IsActive(current int64) bool {
	// Calculate status once and reuse to avoid redundant computations
	status := r.statusResolver.StatusType(current)

	switch status {
	case governance.StatusRejected,
		governance.StatusExpired,
		governance.StatusExecuted,
		governance.StatusCanceled:
		return false
	case governance.StatusPassed:
		// Text proposals become inactive once they pass (no execution needed)
		return !r.IsTextType()
	default:
		// StatusUpcoming, StatusActive, StatusExecutable are considered active
		return true
	}
}

// Validate performs comprehensive validation of the proposal data and metadata.
// This ensures all proposal components meet requirements before storage.
func (r *ProposalResolver) Validate() error {
	// Validate type-specific proposal data
	if err := r.dataResolver.Validate(); err != nil {
		return err
	}

	// Validate proposal metadata (title and description)
	if err := r.metadataResolver.Validate(); err != nil {
		return err
	}

	return nil
}

// Status returns the current status string of the proposal at the given time.
func (r *ProposalResolver) Status(current int64) string {
	return r.statusResolver.StatusType(current).String()
}

// StatusType returns the current status type of the proposal at the given time.
func (r *ProposalResolver) StatusType(current int64) governance.ProposalStatusType {
	return r.statusResolver.StatusType(current)
}

// IsVotingPeriod checks if the proposal is currently in its voting period.
func (r *ProposalResolver) IsVotingPeriod(votedAt int64) bool {
	return r.StatusType(votedAt) == governance.StatusActive
}

// IsExecutable determines if the proposal can be executed at the given time.
// Only executable proposal types that have passed voting can be executed.
func (r *ProposalResolver) IsExecutable(current int64) bool {
	// Only certain proposal types can be executed
	if !r.dataResolver.ProposalType().IsExecutable() {
		return false
	}

	return r.statusResolver.IsExecutable(current)
}

// CommunityPoolSpendTokenPath returns the token path for community pool spend proposals.
// Returns empty string for other proposal types.
func (r *ProposalResolver) CommunityPoolSpendTokenPath() string {
	if r.Data() == nil {
		return ""
	}

	return r.dataResolver.CommunityPoolSpend().TokenPath()
}

// vote records a vote for this proposal and updates vote tallies.
// This is an internal method called during voting process.
func (r *ProposalResolver) Vote(votedYes bool, weight int64) error {
	return r.statusResolver.vote(votedYes, weight)
}

// execute marks the proposal as executed and records execution details.
// This method validates execution conditions before proceeding.
func (r *ProposalResolver) execute(
	executedAt, executedHeight int64,
	executedBy address,
) error {
	// Verify proposal is in executable state
	if !r.IsExecutable(executedAt) {
		return errProposalNotExecutable
	}

	// Mark proposal as executed
	return r.statusResolver.execute(executedAt, executedHeight, executedBy)
}

// cancel marks the proposal as canceled and records cancellation details.
// This method validates cancellation conditions before proceeding.
func (r *ProposalResolver) cancel(
	canceledAt, canceledHeight int64,
	canceledBy address,
) error {
	if r.statusResolver.IsCanceled(canceledAt) {
		return errAlreadyCanceledProposal
	}

	if !r.statusResolver.IsUpcoming(canceledAt) {
		return errUnableToCancelVotingProposal
	}

	// Mark proposal as canceled
	return r.statusResolver.cancel(canceledAt, canceledHeight, canceledBy)
}
