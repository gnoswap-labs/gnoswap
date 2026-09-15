package governance

import (
	"errors"

	"gno.land/r/gnoswap/gov/governance"
)

type ProposalResolver struct {
	*governance.Proposal
	statusResolver   *ProposalStatusResolver
	dataResolver     *ProposalDataResolver
	metadataResolver *ProposalMetadataResolver
}

// NewProposalResolver wraps a persisted governance proposal and initializes
// resolvers for its status, type-specific data, and metadata.
//
// Parameters:
//   - proposal: persisted proposal to resolve
//
// Returns:
//   - *ProposalResolver: resolver backed by proposal and its nested state
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

// VotingTotalWeight returns the total weight of all votes cast by combining
// the proposal's yes and no tallies.
//
// Returns:
//   - int64: combined weight of all recorded votes
func (r *ProposalResolver) VotingTotalWeight() int64 {
	return r.statusResolver.TotalVoteWeight()
}

// IsActive determines whether the proposal is active at current.
// Upcoming, voting, and passed executable proposals are active; rejected,
// expired, executed, canceled, and passed text proposals are inactive.
//
// Parameters:
//   - current: timestamp at which the proposal status is evaluated
//
// Returns:
//   - bool: true when the proposal can still be voted on or executed at current
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

// Validate performs comprehensive validation of the proposal's type-specific
// data and metadata before the proposal is stored.
//
// Returns:
//   - error: nil when both data and metadata validate; the first validation error otherwise
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

// Status returns the current status string of the proposal at current.
//
// Parameters:
//   - current: timestamp at which the proposal status is evaluated
//
// Returns:
//   - string: human-readable status name for the proposal at current
func (r *ProposalResolver) Status(current int64) string {
	return r.statusResolver.StatusType(current).String()
}

// StatusType returns the current status type of the proposal at current.
//
// Parameters:
//   - current: timestamp at which the proposal status is evaluated
//
// Returns:
//   - governance.ProposalStatusType: lifecycle status at current
func (r *ProposalResolver) StatusType(current int64) governance.ProposalStatusType {
	return r.statusResolver.StatusType(current)
}

// IsVotingPeriod reports whether votedAt falls within the proposal's active
// voting status.
//
// Parameters:
//   - votedAt: timestamp at which voting eligibility is checked
//
// Returns:
//   - bool: true when the proposal status at votedAt is StatusActive
func (r *ProposalResolver) IsVotingPeriod(votedAt int64) bool {
	return r.StatusType(votedAt) == governance.StatusActive
}

// IsExecutable determines whether the proposal can be executed at current.
// The proposal type must support execution and its status must be executable.
//
// Parameters:
//   - current: timestamp at which execution eligibility is evaluated
//
// Returns:
//   - bool: true when this type and current lifecycle state permit execution
func (r *ProposalResolver) IsExecutable(current int64) bool {
	// Only certain proposal types can be executed
	if !r.dataResolver.ProposalType().IsExecutable() {
		return false
	}

	return r.statusResolver.IsExecutable(current)
}

// CommunityPoolSpendTokenPath returns the token path for a community pool spend proposal.
// It returns an empty string when the proposal has no community-pool spend data.
//
// Returns:
//   - string: token package path to spend, or empty string for other proposal types
func (r *ProposalResolver) CommunityPoolSpendTokenPath() string {
	if r.Data() == nil {
		return ""
	}

	communityPoolSpend := r.dataResolver.CommunityPoolSpend()
	if communityPoolSpend == nil {
		return ""
	}

	return communityPoolSpend.TokenPath()
}

// Vote records a vote for this proposal and updates its yes or no tally.
// This is an internal method called during the voting process.
//
// Parameters:
//   - votedYes: true to add weight to the yes tally; false to add it to no
//   - weight: voting weight to add to the selected tally
//
// Returns:
//   - error: nil when the selected tally is updated; an error from vote-status validation otherwise
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
		return errors.New(errProposalNotExecutable)
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
		return errors.New(errAlreadyCanceledProposal)
	}

	if !r.statusResolver.IsUpcoming(canceledAt) {
		return errors.New(errUnableToCancelVotingProposal)
	}

	// Mark proposal as canceled
	return r.statusResolver.cancel(canceledAt, canceledHeight, canceledBy)
}
