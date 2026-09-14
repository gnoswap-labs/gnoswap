package governance

import (
	"errors"

	"gno.land/r/gnoswap/gov/governance"
)

type ProposalActionStatusResolver struct {
	status governance.ProposalActionStatus
}

func MakeProposalActionStatusResolver(status governance.ProposalActionStatus) ProposalActionStatusResolver {
	return ProposalActionStatusResolver{status: status}
}

func (p ProposalActionStatusResolver) Value() governance.ProposalActionStatus {
	return p.status
}

func (p ProposalActionStatusResolver) Canceled() bool {
	return p.status.Canceled()
}

func (p ProposalActionStatusResolver) CanceledAt() int64 {
	return p.status.CanceledAt()
}

func (p ProposalActionStatusResolver) CanceledHeight() int64 {
	return p.status.CanceledHeight()
}

func (p ProposalActionStatusResolver) CanceledBy() address {
	return p.status.CanceledBy()
}

func (p ProposalActionStatusResolver) IsExecuted() bool {
	return p.status.IsExecuted()
}

func (p ProposalActionStatusResolver) ExecutedAt() int64 {
	return p.status.ExecutedAt()
}

func (p ProposalActionStatusResolver) ExecutedHeight() int64 {
	return p.status.ExecutedHeight()
}

func (p ProposalActionStatusResolver) ExecutedBy() address {
	return p.status.ExecutedBy()
}

func (p ProposalActionStatusResolver) IsExecutable() bool {
	return p.status.IsExecutable()
}

// cancel marks the proposal as canceled and returns the updated resolver.
func (p ProposalActionStatusResolver) cancel(
	canceledAt, canceledHeight int64,
	canceledBy address,
) (ProposalActionStatusResolver, error) {
	if p.status.Canceled() {
		return p, errors.New(errAlreadyCanceledProposal)
	}

	p.status = p.status.SetCanceled(true)
	p.status = p.status.SetCanceledAt(canceledAt)
	p.status = p.status.SetCanceledHeight(canceledHeight)
	p.status = p.status.SetCanceledBy(canceledBy)
	return p, nil
}

// Execute marks the proposal as executed and returns the updated resolver.
func (p ProposalActionStatusResolver) Execute(
	executedAt, executedHeight int64,
	executedBy address,
) (ProposalActionStatusResolver, error) {
	if !p.status.IsExecutable() {
		return p, errors.New(errProposalNotExecutable)
	}
	if p.status.Canceled() {
		return p, errors.New(errAlreadyCanceledProposal)
	}

	p.status = p.status.SetExecuted(true)
	p.status = p.status.SetExecutedAt(executedAt)
	p.status = p.status.SetExecutedHeight(executedHeight)
	p.status = p.status.SetExecutedBy(executedBy)
	return p, nil
}
