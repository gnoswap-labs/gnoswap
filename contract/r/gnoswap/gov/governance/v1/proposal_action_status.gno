package v1

import (
	"gno.land/r/gnoswap/gov/governance"
)

type ProposalActionStatusResolver struct {
	*governance.ProposalActionStatus
}

func NewProposalActionStatusResolver(status *governance.ProposalActionStatus) *ProposalActionStatusResolver {
	return &ProposalActionStatusResolver{status}
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
//   - error: cancellation error if proposal cannot be canceled
func (p *ProposalActionStatusResolver) Cancel(canceledAt int64, canceledHeight int64, canceledBy address) error {
	// Only executable proposals can be canceled (text proposals cannot)
	if !p.IsExecutable() {
		return errProposalNotExecutable
	}

	// Record cancellation details
	p.SetCanceled(true)
	p.SetCanceledAt(canceledAt)
	p.SetCanceledHeight(canceledHeight)
	p.SetCanceledBy(canceledBy)

	return nil
}

// execute marks the proposal as executed and records execution details.
// This method validates that the proposal is eligible for execution.
//
// Parameters:
//   - executedAt: timestamp when execution occurred
//   - executedHeight: block height when execution occurred
//   - executedBy: address performing the execution
//
// Returns:
//   - error: execution error if proposal cannot be executed
func (p *ProposalActionStatusResolver) Execute(executedAt int64, executedHeight int64, executedBy address) error {
	// Only executable proposals can be executed (text proposals cannot)
	if !p.IsExecutable() {
		return errProposalNotExecutable
	}

	// Record execution details
	p.SetExecuted(true)
	p.SetExecutedAt(executedAt)
	p.SetExecutedHeight(executedHeight)
	p.SetExecutedBy(executedBy)

	return nil
}