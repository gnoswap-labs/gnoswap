package governance

import (
	"errors"

	"gno.land/r/gnoswap/gov/governance"
)

type ProposalResolver struct {
	proposal         governance.Proposal
	statusResolver   ProposalStatusResolver
	dataResolver     ProposalDataResolver
	metadataResolver ProposalMetadataResolver
}

func MakeProposalResolver(proposal governance.Proposal) ProposalResolver {
	return ProposalResolver{
		proposal:         proposal,
		statusResolver:   MakeProposalStatusResolver(proposal.Status()),
		dataResolver:     MakeProposalDataResolver(proposal.Data()),
		metadataResolver: MakeProposalMetadataResolver(proposal.Metadata()),
	}
}

// Proposal returns the complete updated proposal value, including nested status changes.
func (r ProposalResolver) Proposal() governance.Proposal {
	proposal := r.proposal
	proposal = proposal.WithStatus(r.statusResolver.Value())
	proposal = proposal.WithData(r.dataResolver.Value())
	proposal = proposal.WithMetadata(r.metadataResolver.Value())
	return proposal
}

func (r ProposalResolver) ID() int64 {
	return r.proposal.ID()
}

func (r ProposalResolver) Type() governance.ProposalType {
	return r.proposal.Type()
}

func (r ProposalResolver) Title() string {
	return r.proposal.Title()
}

func (r ProposalResolver) Description() string {
	return r.proposal.Description()
}

func (r ProposalResolver) Proposer() address {
	return r.proposal.Proposer()
}

func (r ProposalResolver) CreatedHeight() int64 {
	return r.proposal.CreatedHeight()
}

func (r ProposalResolver) CreatedAt() int64 {
	return r.proposal.CreatedAt()
}

func (r ProposalResolver) ConfigVersion() int64 {
	return r.proposal.ConfigVersion()
}

func (r ProposalResolver) SnapshotTime() int64 {
	return r.proposal.SnapshotTime()
}

func (r ProposalResolver) Data() governance.ProposalData {
	return r.dataResolver.Value()
}

func (r ProposalResolver) StatusValue() governance.ProposalStatus {
	return r.statusResolver.Value()
}

func (r ProposalResolver) Metadata() governance.ProposalMetadata {
	return r.metadataResolver.Value()
}

func (r ProposalResolver) VotingTotalWeight() int64 {
	return r.statusResolver.TotalVoteWeight()
}

func (r ProposalResolver) IsActive(current int64) bool {
	status := r.statusResolver.StatusType(current)
	switch status {
	case governance.StatusRejected,
		governance.StatusExpired,
		governance.StatusExecuted,
		governance.StatusCanceled:
		return false
	case governance.StatusPassed:
		return r.proposal.Type() != governance.Text
	default:
		return true
	}
}

func (r ProposalResolver) Validate() error {
	if err := r.dataResolver.Validate(); err != nil {
		return err
	}
	return r.metadataResolver.Validate()
}

func (r ProposalResolver) Status(current int64) string {
	return r.statusResolver.StatusType(current).String()
}

func (r ProposalResolver) StatusType(current int64) governance.ProposalStatusType {
	return r.statusResolver.StatusType(current)
}

func (r ProposalResolver) IsVotingPeriod(votedAt int64) bool {
	return r.StatusType(votedAt) == governance.StatusActive
}

func (r ProposalResolver) IsExecutable(current int64) bool {
	if !r.dataResolver.data.ProposalType().IsExecutable() {
		return false
	}
	return r.statusResolver.IsExecutable(current)
}

func (r ProposalResolver) CommunityPoolSpendTokenPath() string {
	communityPoolSpend, ok := r.dataResolver.data.CommunityPoolSpend()
	if !ok {
		return ""
	}
	return communityPoolSpend.TokenPath()
}

// Vote returns a resolver containing the updated vote tally.
func (r ProposalResolver) Vote(votedYes bool, weight int64) (ProposalResolver, error) {
	statusResolver, err := r.statusResolver.vote(votedYes, weight)
	if err != nil {
		return r, err
	}
	r.statusResolver = statusResolver
	return r, nil
}

// execute returns a resolver containing the executed action status.
func (r ProposalResolver) execute(
	executedAt, executedHeight int64,
	executedBy address,
) (ProposalResolver, error) {
	if !r.IsExecutable(executedAt) {
		return r, errors.New(errProposalNotExecutable)
	}
	statusResolver, err := r.statusResolver.execute(executedAt, executedHeight, executedBy)
	if err != nil {
		return r, err
	}
	r.statusResolver = statusResolver
	return r, nil
}

// cancel returns a resolver containing the canceled action status.
func (r ProposalResolver) cancel(
	canceledAt, canceledHeight int64,
	canceledBy address,
) (ProposalResolver, error) {
	if r.statusResolver.IsCanceled(canceledAt) {
		return r, errors.New(errAlreadyCanceledProposal)
	}
	if !r.statusResolver.IsUpcoming(canceledAt) {
		return r, errors.New(errUnableToCancelVotingProposal)
	}
	statusResolver, err := r.statusResolver.cancel(canceledAt, canceledHeight, canceledBy)
	if err != nil {
		return r, err
	}
	r.statusResolver = statusResolver
	return r, nil
}
