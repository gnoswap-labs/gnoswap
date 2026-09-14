package governance

import (
	"errors"

	"gno.land/r/gnoswap/gov/governance"
)

// ProposalResolver applies proposal business logic to a detached value.
// Mutations update its embedded Proposal, which callers must explicitly store.
type ProposalResolver struct {
	governance.Proposal
	statusResolver   *ProposalStatusResolver
	dataResolver     *ProposalDataResolver
	metadataResolver *ProposalMetadataResolver
}

// NewProposalResolver creates a pointer resolver over a copy of the proposal.
// The input value and stored proposal are not mutated by resolver operations.
func NewProposalResolver(proposal governance.Proposal) *ProposalResolver {
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
//
// Returns:
//   - int64: total vote weight
func (r *ProposalResolver) VotingTotalWeight() int64 {
	return r.statusResolver.TotalVoteWeight()
}

// IsActive determines if the proposal is currently active (can be voted on or executed).
// A proposal is considered active if it's not rejected, expired, executed, or canceled.
func (r *ProposalResolver) IsActive(current int64) bool {
	// Calculate status once and reuse to avoid redundant computations.
	status := r.statusResolver.StatusType(current)

	switch status {
	case governance.StatusRejected,
		governance.StatusExpired,
		governance.StatusExecuted,
		governance.StatusCanceled:
		return false
	case governance.StatusPassed:
		// Text proposals become inactive once they pass (no execution needed).
		return !r.IsTextType()
	default:
		// StatusUpcoming, StatusActive, StatusExecutable are considered active.
		return true
	}
}

// Validate performs comprehensive validation of the proposal data and metadata.
// This ensures all proposal components meet requirements before storage.
func (r *ProposalResolver) Validate() error {
	// Validate type-specific proposal data.
	if err := r.dataResolver.Validate(); err != nil {
		return err
	}

	// Validate proposal metadata (title and description).
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
	// Only certain proposal types can be executed.
	if !r.dataResolver.ProposalType().IsExecutable() {
		return false
	}

	return r.statusResolver.IsExecutable(current)
}

// CommunityPoolSpendTokenPath returns the token path for community pool spend proposals.
// Returns empty string for other proposal types.
func (r *ProposalResolver) CommunityPoolSpendTokenPath() string {
	communityPoolSpend, ok := r.dataResolver.CommunityPoolSpend()
	if !ok {
		return ""
	}

	return communityPoolSpend.TokenPath()
}

// Vote records a vote for this proposal and updates vote tallies.
// This is an internal method called during the voting process.
//
// Parameters:
//   - votedYes: true for a yes vote, false for a no vote
//   - weight: voting weight to apply
//
// Returns:
//   - error: voting error if the operation fails
func (r *ProposalResolver) Vote(votedYes bool, weight int64) error {
	if err := r.statusResolver.vote(votedYes, weight); err != nil {
		return err
	}
	r.Proposal = r.Proposal.WithStatus(r.statusResolver.ProposalStatus)
	return nil
}

// execute marks the proposal as executed and records execution details.
// This method validates execution conditions before proceeding.
//
// Parameters:
//   - executedAt: timestamp when execution occurred
//   - executedHeight: block height when execution occurred
//   - executedBy: address performing the execution
//
// Returns:
//   - error: proposal-not-executable or action execution error
func (r *ProposalResolver) execute(
	executedAt, executedHeight int64,
	executedBy address,
) error {
	// Verify proposal is in executable state.
	if !r.IsExecutable(executedAt) {
		return errors.New(errProposalNotExecutable)
	}

	// Mark proposal as executed.
	if err := r.statusResolver.execute(executedAt, executedHeight, executedBy); err != nil {
		return err
	}
	r.Proposal = r.Proposal.WithStatus(r.statusResolver.ProposalStatus)
	return nil
}

// cancel marks the proposal as canceled and records cancellation details.
// This method validates cancellation conditions before proceeding.
//
// Parameters:
//   - canceledAt: timestamp when proposal was canceled
//   - canceledHeight: block height when proposal was canceled
//   - canceledBy: address performing the cancellation
//
// Returns:
//   - error: cancellation error if the proposal cannot be canceled
func (r *ProposalResolver) cancel(
	canceledAt, canceledHeight int64,
	canceledBy address,
) error {
	if r.statusResolver.IsCanceled(canceledAt) {
		return errors.New(errAlreadyCanceledProposal)
	}

	if !r.statusResolver.IsUpcoming(canceledAt) {
		return errors.New(errUnableToCancelVotingProposal)
	}

	// Mark proposal as canceled.
	if err := r.statusResolver.cancel(canceledAt, canceledHeight, canceledBy); err != nil {
		return err
	}
	r.Proposal = r.Proposal.WithStatus(r.statusResolver.ProposalStatus)
	return nil
}
