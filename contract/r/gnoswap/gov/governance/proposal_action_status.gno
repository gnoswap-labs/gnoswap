package governance

import (
	"errors"
)

var (
	errProposalNotExecutable = errors.New("proposal not executable")
)

// ProposalActionStatus tracks the execution and cancellation status of a proposal.
// This structure manages the action-related state including who performed actions and when.
type ProposalActionStatus struct {
	canceled       bool    // Whether the proposal has been canceled
	canceledAt     int64   // Timestamp when proposal was canceled
	canceledHeight int64   // Block height when proposal was canceled
	canceledBy     address // Who canceled the proposal

	executed       bool    // Whether the proposal has been executed
	executedAt     int64   // Timestamp when proposal was executed
	executedHeight int64   // Block height when proposal was executed
	executedBy     address // Who executed the proposal

	executable bool // Whether this proposal type supports execution
}

/* Getter methods */
func (p *ProposalActionStatus) Canceled() bool        { return p.canceled }
func (p *ProposalActionStatus) CanceledAt() int64     { return p.canceledAt }
func (p *ProposalActionStatus) CanceledHeight() int64 { return p.canceledHeight }
func (p *ProposalActionStatus) Executed() bool        { return p.executed }
func (p *ProposalActionStatus) ExecutedAt() int64     { return p.executedAt }
func (p *ProposalActionStatus) ExecutedHeight() int64 { return p.executedHeight }
func (p *ProposalActionStatus) Executable() bool      { return p.executable }

/* Setter methods */
func (p *ProposalActionStatus) SetCanceled(canceled bool) {
	p.canceled = canceled
}

func (p *ProposalActionStatus) SetCanceledAt(canceledAt int64) {
	p.canceledAt = canceledAt
}

func (p *ProposalActionStatus) SetCanceledHeight(canceledHeight int64) {
	p.canceledHeight = canceledHeight
}

func (p *ProposalActionStatus) SetCanceledBy(canceledBy address) {
	p.canceledBy = canceledBy
}

func (p *ProposalActionStatus) SetExecuted(executed bool) {
	p.executed = executed
}

func (p *ProposalActionStatus) SetExecutedAt(executedAt int64) {
	p.executedAt = executedAt
}

func (p *ProposalActionStatus) SetExecutedHeight(executedHeight int64) {
	p.executedHeight = executedHeight
}

func (p *ProposalActionStatus) SetExecutedBy(executedBy address) {
	p.executedBy = executedBy
}

func (p *ProposalActionStatus) SetExecutable(executable bool) {
	p.executable = executable
}

// CanceledBy returns the address that canceled the proposal.
// Only meaningful if IsCanceled() returns true.
//
// Returns:
//   - std.Address: address of the canceller
func (p *ProposalActionStatus) CanceledBy() address {
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
func (p *ProposalActionStatus) ExecutedBy() address {
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
