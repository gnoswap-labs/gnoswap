package governance

import "std"

// ProposalActionStatus tracks the execution and cancellation status of a proposal.
// This structure manages the action-related state including who performed actions and when.
type ProposalActionStatus struct {
	canceled       bool        // Whether the proposal has been canceled
	canceledAt     int64       // Timestamp when proposal was canceled
	canceledHeight int64       // Block height when proposal was canceled
	canceledBy     std.Address // Who canceled the proposal

	executed       bool        // Whether the proposal has been executed
	executedAt     int64       // Timestamp when proposal was executed
	executedHeight int64       // Block height when proposal was executed
	executedBy     std.Address // Who executed the proposal

	executable bool // Whether this proposal type supports execution
}

// IsCanceled returns whether the proposal has been canceled.
//
// Returns:
//   - bool: true if proposal has been canceled
func (p *ProposalActionStatus) IsCanceled() bool {
	return p.canceled
}

// CanceledBy returns the address that canceled the proposal.
// Only meaningful if IsCanceled() returns true.
//
// Returns:
//   - std.Address: address of the canceller
func (p *ProposalActionStatus) CanceledBy() std.Address {
	return p.canceledBy
}

// IsExecuted returns whether the proposal has been executed.
//
// Returns:
//   - bool: true if proposal has been executed
func (p *ProposalActionStatus) IsExecuted() bool {
	return p.executed
}

// ExecutedBy returns the address that executed the proposal.
// Only meaningful if IsExecuted() returns true.
//
// Returns:
//   - std.Address: address of the executor
func (p *ProposalActionStatus) ExecutedBy() std.Address {
	return p.executedBy
}

// IsExecutable returns whether this proposal type can be executed.
// Text proposals return false, while other types return true.
//
// Returns:
//   - bool: true if proposal type supports execution
func (p *ProposalActionStatus) IsExecutable() bool {
	return p.executable
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
func (p *ProposalActionStatus) cancel(canceledAt int64, canceledHeight int64, canceledBy std.Address) error {
	// Only executable proposals can be canceled (text proposals cannot)
	if !p.executable {
		return errProposalNotExecutable
	}

	// Record cancellation details
	p.canceled = true
	p.canceledAt = canceledAt
	p.canceledHeight = canceledHeight
	p.canceledBy = canceledBy

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
func (p *ProposalActionStatus) execute(executedAt int64, executedHeight int64, executedBy std.Address) error {
	// Only executable proposals can be executed (text proposals cannot)
	if !p.executable {
		return errProposalNotExecutable
	}

	// Record execution details
	p.executed = true
	p.executedAt = executedAt
	p.executedHeight = executedHeight
	p.executedBy = executedBy

	return nil
}

// NewProposalActionStatus creates a new action status for a proposal.
// Initializes the status with default values and the executable flag.
//
// Parameters:
//   - executable: whether this proposal type can be executed
//
// Returns:
//   - *ProposalActionStatus: new action status instance
func NewProposalActionStatus(executable bool) *ProposalActionStatus {
	return &ProposalActionStatus{
		canceled:   false,      // Proposal starts as not canceled
		executed:   false,      // Proposal starts as not executed
		executable: executable, // Set based on proposal type
	}
}
