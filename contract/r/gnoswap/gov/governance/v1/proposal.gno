package v1

import (
	"gno.land/r/gnoswap/gov/governance"
)

type ProposalResolver struct {
	statusResolver *ProposalStatusResolver
	dataResolver *ProposalDataResolver
	metadataResolver *ProposalMetadataResolver
}

func NewProposalResolver(
	statusResolver *ProposalStatusResolver,
	dataResolver *ProposalDataResolver,
	metadataResolver *ProposalMetadataResolver,
) *ProposalResolver {
	return &ProposalResolver{
		statusResolver: statusResolver,
		dataResolver: dataResolver,
		metadataResolver: metadataResolver,
	}
}

// IsActive determines if the proposal is currently active (can be voted on or executed).
// A proposal is considered active if it's not rejected, expired, executed, or canceled.
func (r *ProposalResolver) IsActive(proposal *governance.Proposal, current int64) bool {
	// Text proposals become inactive once they pass (no execution needed)
	if proposal.IsTextType() {
		if r.statusResolver.IsPassed(current) {
			return false
		}
	}

	// If the proposal is rejected, expired, executed, or canceled, it is not active
	if r.statusResolver.IsRejected(current) ||
		r.statusResolver.IsExpired(current) ||
		r.statusResolver.IsExecuted(current) ||
		r.statusResolver.IsCanceled(current) {
		return false
	}

	return true
}

// Validate performs comprehensive validation of the proposal data and metadata.
// This ensures all proposal components meet requirements before storage.
func (r *ProposalResolver) Validate(proposal *governance.Proposal) error {
	// Validate type-specific proposal data
	if err := r.dataResolver.Validate(proposal.Data()); err != nil {
		return err
	}

	// Validate proposal metadata (title and description)
	if err := r.metadataResolver.Validate(proposal.Metadata()); err != nil {
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
func (r *ProposalResolver) IsExecutable(proposal *governance.Proposal, current int64) bool {
	// Only certain proposal types can be executed
	if !proposal.Type().IsExecutable() {
		return false
	}

	return r.statusResolver.IsExecutable(current)
}

// CommunityPoolSpendTokenPath returns the token path for community pool spend proposals.
// Returns empty string for other proposal types.
func (r *ProposalResolver) CommunityPoolSpendTokenPath(proposal *governance.Proposal) string {
	if proposal.Data() == nil {
		return ""
	}

	return proposal.Data().CommunityPoolSpend().TokenPath()
}

// vote records a vote for this proposal and updates vote tallies.
// This is an internal method called during voting process.
func (r *ProposalResolver) vote(votedYes bool, weight int64) error {
	return r.statusResolver.vote(votedYes, weight)
}

// updateVoteStatus updates the voting status with new parameters.
// This is used for dynamic voting requirement adjustments.
func (r *ProposalResolver) updateVoteStatus(maxVotingWeight, quorum int64) error {
	return r.statusResolver.updateVoteStatus(maxVotingWeight, quorum)
}

// execute marks the proposal as executed and records execution details.
// This method validates execution conditions before proceeding.
func (r *ProposalResolver) execute(
	proposal *governance.Proposal,
	executedAt int64,
	executedHeight int64,
	executedBy address,
) error {
	// Verify proposal is in executable state
	if !r.IsExecutable(proposal, executedAt) {
		return errProposalNotExecutable
	}

	// Mark proposal as executed
	return r.statusResolver.execute(executedAt, executedHeight, executedBy)
}

// cancel marks the proposal as canceled and records cancellation details.
// This method validates cancellation conditions before proceeding.
func (r *ProposalResolver) cancel(
	proposal *governance.Proposal,
	canceledAt int64,
	canceledHeight int64,
	canceledBy address,
) error {
	if r.statusResolver.IsCanceled(canceledAt) {
		return errAlreadyCanceledProposal
	}

	if !r.statusResolver.IsUpcoming(canceledAt) {
		return errUnableToCancleVotingProposal
	}

	// Mark proposal as canceled
	return r.statusResolver.cancel(canceledAt, canceledHeight, canceledBy)
}
