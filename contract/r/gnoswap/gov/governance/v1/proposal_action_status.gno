package governance

import (
	"errors"

	"gno.land/r/gnoswap/gov/governance"
)

type ProposalActionStatusResolver struct {
	governance.ProposalActionStatus
}

// NewProposalActionStatusResolver creates a pointer resolver over a detached action status value.
func NewProposalActionStatusResolver(status governance.ProposalActionStatus) *ProposalActionStatusResolver {
	return &ProposalActionStatusResolver{ProposalActionStatus: status}
}

// cancel marks the proposal as canceled and records cancellation details.
// This method validates that the proposal is eligible for cancellation.
//
// Parameters:
//   - canceledAt: timestamp when cancellation occurred
//   - canceledHeight: block height when cancellation occurred
//   - canceledBy: address performing the cancellation
//
// Returns:
//   - error: already canceled error if proposal action status is already canceled
func (p *ProposalActionStatusResolver) cancel(
	canceledAt, canceledHeight int64,
	canceledBy address,
) error {
	if p.Canceled() {
		return errors.New(errAlreadyCanceledProposal)
	}

	// Record cancellation details.
	p.ProposalActionStatus = p.ProposalActionStatus.WithCanceled(true)
	p.ProposalActionStatus = p.ProposalActionStatus.WithCanceledAt(canceledAt)
	p.ProposalActionStatus = p.ProposalActionStatus.WithCanceledHeight(canceledHeight)
	p.ProposalActionStatus = p.ProposalActionStatus.WithCanceledBy(canceledBy)

	return nil
}

// Execute marks the proposal as executed and records execution details.
// This method validates that the proposal is eligible for execution.
//
// Parameters:
//   - executedAt: timestamp when execution occurred
//   - executedHeight: block height when execution occurred
//   - executedBy: address performing the execution
//
// Returns:
//   - error: not executable or already canceled error if execution is not allowed
func (p *ProposalActionStatusResolver) Execute(
	executedAt, executedHeight int64,
	executedBy address,
) error {
	// Only executable proposals can be executed (text proposals cannot).
	if !p.IsExecutable() {
		return errors.New(errProposalNotExecutable)
	}

	if p.Canceled() {
		return errors.New(errAlreadyCanceledProposal)
	}

	// Record execution details.
	p.ProposalActionStatus = p.ProposalActionStatus.WithExecuted(true)
	p.ProposalActionStatus = p.ProposalActionStatus.WithExecutedAt(executedAt)
	p.ProposalActionStatus = p.ProposalActionStatus.WithExecutedHeight(executedHeight)
	p.ProposalActionStatus = p.ProposalActionStatus.WithExecutedBy(executedBy)

	return nil
}
